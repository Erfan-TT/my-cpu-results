#=============================================================================
#  run_tests.tcl -- the DLX regression
#
#  Run from my-dlx-cpu/verification/scripts:
#
#      vsim -c -do run_tests.tcl                     whole suite
#      vsim -c -do "set only 08;  source run_tests.tcl; quit -f"   one test
#      vsim -c -do "set only mult; source run_tests.tcl; quit -f"  by name
#      vsim -c -do "set vcd 1; set only 20_power_bench; source run_tests.tcl; quit -f"
#      WORDS=256 vsim -c -do run_tests.tcl
#
#  Knobs, all optional, all settable before sourcing this file:
#      only        substring filter on the test folder name
#      words       memory image size; default $env(WORDS), else the per-test
#                  value from testlist.tcl
#      recompile   0 to skip compile.do and reuse ../work  (default 1)
#      vcd         1 to dump <test>/<name>.vcd for each run (default 0)
#      run_skipped 1 to also run the entries marked skip    (default 0)
#      stop_at_end 1 to end each run when the program reaches its final
#                  self-loop instead of running the whole runtime (default 0)
#      fresh       1 to start ../results/rtl_results.csv empty instead of
#                  merging this run into it                  (default 0)
#
#  Each test is four steps:
#      1. dlxasm.pl, via assembler.sh, writes <name>_imem.txt and
#         <name>_dmem_init.txt
#      2. dlxsim.py, the golden model, writes <name>_dmem_golden.txt
#      3. the RTL runs and writes <name>_dmem_rtl[_mode].txt
#      4. dlxsim.py --compare diffs 3 against 2
#  Steps 1 and 2 both take -w <words>, and step 3 gets the same number as the
#  TB_DLX memory_size generic, so all three agree by construction.
#
#  Step 3 also reports the cycle count from reset to the program's final
#  self-loop.  Verdicts and cycles are merged into ../results/rtl_results.csv.
#=============================================================================

source testlist.tcl

if {![info exists only]}        { set only "" }
if {![info exists recompile]}   { set recompile 1 }
if {![info exists vcd]}         { set vcd 0 }
if {![info exists run_skipped]} { set run_skipped 0 }
if {![info exists stop_at_end]} { set stop_at_end 0 }
if {![info exists fresh]}       { set fresh 0 }
if {![info exists words]} {
    if {[info exists ::env(WORDS)]} { set words $::env(WORDS) } else { set words "" }
}
if {$words ne "" && (![string is integer -strict $words] || $words < 1)} {
    error "words must be a positive integer, got '$words'"
}

set MODE_NAME {
    ff {simple_iram + simple_dram}
    fs {simple_iram + rwmem}
    cf {rocache/romem + simple_dram}
    cs {rocache/romem + rwmem}
}

proc mode_generics {mode} {
    switch -- $mode {
        ff { return {false false} }
        fs { return {false true}  }
        cf { return {true  false} }
        cs { return {true  true}  }
        default { error "unknown mode '$mode'" }
    }
}

#-----------------------------------------------------------------------------
#  Run an external command, echoing its output, and report whether it worked.
#  exec raises on a non-zero exit status, which is exactly how dlxsim.py
#  reports a mismatch, so catch is the pass/fail signal.
#-----------------------------------------------------------------------------
proc step {label cmd} {
    puts "  $label"
    # 2>@1 folds stderr into stdout.  Without it Tcl's exec raises on ANY
    # stderr output, and dlxasm.pl warns there about mnemonics this CPU does
    # not decode -- which would turn a warning into a failed test.
    set rc [catch {exec {*}$cmd 2>@1} out]
    foreach line [split $out "\n"] {
        if {[string trim $line] ne ""} { puts "      $line" }
    }
    return [expr {$rc == 0}]
}

#-----------------------------------------------------------------------------
#  Merge rows into a CSV instead of overwriting it, so a partial run (one test,
#  one corner, one workload) keeps every other row.  Rows are keyed on their
#  first two fields; a rerun replaces its own rows in place, new rows go last.
#  "set fresh 1" before sourcing starts the file empty instead.
#-----------------------------------------------------------------------------
proc merge_csv {path header rows fresh} {
    set order {}
    set lines [dict create]
    if {!$fresh && [file exists $path]} {
        set f [open $path r]
        gets $f
        while {[gets $f ln] >= 0} {
            if {[string trim $ln] eq ""} { continue }
            set k [join [lrange [split $ln ","] 0 1] ","]
            if {![dict exists $lines $k]} { lappend order $k }
            dict set lines $k $ln
        }
        close $f
    }
    foreach ln $rows {
        set k [join [lrange [split $ln ","] 0 1] ","]
        if {![dict exists $lines $k]} { lappend order $k }
        dict set lines $k $ln
    }
    set f [open $path w]
    puts $f $header
    foreach k $order { puts $f [dict get $lines $k] }
    close $f
}

#-----------------------------------------------------------------------------
if {$recompile} {
    puts "\n### compiling the design ###"
    if {[catch {source compile.do} msg]} {
        puts "compile.do failed: $msg"
        return
    }
}

set results {}
set n_pass 0
set n_fail 0
set n_skip 0

foreach t $TESTS {
    set dir [dict get $t dir]
    if {$only ne "" && [string first $only $dir] < 0} { continue }

    set skip 0
    if {[dict exists $t skip]} { set skip [dict get $t skip] }
    if {$skip && !$run_skipped} {
        lappend results [list $dir - SKIP [dict get $t note]]
        incr n_skip
        continue
    }

    # the folder holds exactly one .asm, and it names the test
    set asms [glob -nocomplain ../tests/$dir/*.asm]
    if {[llength $asms] != 1} {
        lappend results [list $dir - FAIL "expected one .asm in ../tests/$dir, found [llength $asms]"]
        incr n_fail
        continue
    }
    set asm   [lindex $asms 0]
    set name  [file rootname [file tail $asm]]
    set base  ../tests/$dir/$name

    set w [expr {$words ne "" ? $words : [dict get $t words]}]
    set runtime [dict get $t runtime]
    set modes   [dict get $t modes]
    set expect  {}
    if {[dict exists $t expect]} { set expect [dict get $t expect] }

    puts "\n=============================================================="
    puts "  $dir   ($name, $w words)"
    puts "  [dict get $t note]"
    puts "=============================================================="

    puts "  1. assembling"
    if {![step "   dlxasm.pl" [list ./assembler.sh -w $w $asm]]} {
        lappend results [list $dir - FAIL "assembly failed"]
        incr n_fail
        continue
    }

    puts "  2. golden model"
    if {![step "   dlxsim.py" \
            [list python3 ../../sim/dlxsim.py $asm -w $w --dram-out ${base}_dmem_golden.txt]]} {
        lappend results [list $dir - FAIL "golden model failed"]
        incr n_fail
        continue
    }

    foreach mode $modes {
        lassign [mode_generics $mode] ic sd
        set suffix [expr {$mode eq "ff" ? "" : "_$mode"}]
        set why ""
        if {[dict exists $expect $mode]} { set why [dict get $expect $mode] }

        puts "  3. RTL, mode $mode  ([dict get $MODE_NAME $mode])"
        set ::t_dir         $dir
        set ::t_name        $name
        set ::words         $w
        set ::runtime       $runtime
        set ::use_icache    $ic
        set ::use_slow_dram $sd
        set ::out_suffix    $suffix
        set ::vcd_file      [expr {$vcd ? "${base}${suffix}.vcd" : ""}]
        set ::stop_at_end   $stop_at_end
        set ::t_cycles      ""

        if {[catch {source sim.do} msg]} {
            puts "      simulation failed: $msg"
            lappend results [list $dir $mode FAIL "simulation failed"]
            incr n_fail
            continue
        }

        set cyc $::t_cycles

        puts "  4. comparing"
        set ok [step "   dlxsim.py --compare" \
                  [list python3 ../../sim/dlxsim.py $asm -w $w \
                        --dram-out ${base}_dmem_scratch.txt \
                        --compare ${base}_dmem_rtl${suffix}.txt]]

        file delete -force ${base}_dmem_scratch.txt

        if {$ok} {
            if {$why ne ""} {
                lappend results [list $dir $mode XPASS "expected to fail but passed: $why" $cyc]
                incr n_fail
            } else {
                lappend results [list $dir $mode PASS "" $cyc]
                incr n_pass
            }
        } else {
            if {$why ne ""} {
                lappend results [list $dir $mode XFAIL $why $cyc]
                incr n_skip
            } else {
                lappend results [list $dir $mode FAIL "dmem mismatch" $cyc]
                incr n_fail
            }
        }
    }
}

puts "\n=============================================================="
puts "  SUMMARY"
puts "=============================================================="
foreach r $results {
    lassign $r dir mode verdict why cyc
    puts [format "  %-6s %-26s %-4s %7s  %s" $verdict $dir $mode $cyc $why]
}
set csv_rows {}
foreach r $results {
    lassign $r dir mode verdict why cyc
    lappend csv_rows "$dir,$mode,$verdict,$cyc,\"$why\""
}
file mkdir ../results
merge_csv ../results/rtl_results.csv "test,mode,verdict,cycles,note" $csv_rows $fresh
puts ""
puts "  cycles: from reset to the final self-loop, blank if never reached"
puts "  results merged into ../results/rtl_results.csv"
puts "  $n_pass passed, $n_fail failed, $n_skip skipped or expected-fail"
puts ""
if {$n_fail > 0} { puts "  *** REGRESSION FAILED ***" } else { puts "  all good" }
