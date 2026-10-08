#=============================================================================
#  run_gate_tests.tcl -- the post-synthesis regression, corner by corner
#
#  Run from my-dlx-cpu/syn/post_synthesis_sim/scripts:
#
#      vsim -c -do run_gate_tests.tcl
#      vsim -c -do "set only 1p0; source run_gate_tests.tcl; quit -f"
#      vsim -c -do "set recompile 0; source run_gate_tests.tcl; quit -f"
#
#  Knobs, all optional, set before sourcing:
#      only        substring filter on the corner tag, e.g. 1p0
#      only_test   substring filter on the test folder name
#      recompile   0 to reuse ../work_gate                     (default 1)
#      no_sdf      1 to run the FUNCTIONAL regression zero-delay instead of
#                  SDF-annotated.  Zero-delay is the honest default for proving
#                  the netlist is logically the RTL: timing is signed off by
#                  static analysis, which covers every path, while a simulation
#                  only ever exercises the paths the stimulus happens to hit.
#                  It also sidesteps the pre-layout hold artefacts.
#                  (default 1, as used for the published runs)
#      saif_sdf    1 to annotate the SDF for the SAIF workloads.  OFF by default
#                  PRE-LAYOUT, on purpose.  Annotating does add glitch activity,
#                  which is real power -- but pre-layout those glitches come out
#                  of the wire LOAD MODEL, a statistical guess by fanout that
#                  knows nothing about placement.  Glitch generation depends on
#                  the *relative* arrival times of the inputs to a gate, which
#                  is exactly what a wire load model gets wrong.  So the number
#                  is not obviously closer to the truth, only noisier -- and on
#                  this netlist the un-balanced clock gates make the run
#                  unusable anyway.  Turn it on after place-and-route, where the
#                  SDF carries a real clock tree and extracted RC.   (default 0)
#      csv         path to the synthesis results               (default ../../reports/results.csv)
#      skip_power  1 to skip the SAIF workloads                (default 0)
#      power_tests SAIF workloads, a list of test folders
#                  (default {20_power_bench 08_multiplier 24_mac_loops}).
#                  "set power_tests 24_mac_loops" runs one workload alone.
#      saif_to_end 1 to end each SAIF window when the program reaches its
#                  final self-loop, so the activity is the program and not
#                  the idle loop after it; 0 for a fixed window of the scaled
#                  runtime                                   (default 1)
#      fresh       1 to start gate_results.csv and saif_manifest.csv empty
#                  instead of merging this run into them      (default 0).
#                  Merging keeps the rows of every test, corner and workload
#                  this run did not touch.
#      notifier    1 to let timing-check violations drive flops to X.  Off by
#                  default: this is a PRE-LAYOUT netlist with no clock tree, so
#                  its hold violations are an artefact, not a result.  See the
#                  long note in sim_gate.do.                  (default 0)
#      init_rf     0 to leave the register file X at power-up  (default 1)
#      ntc         0 to compile the cell library without +define+NTC.  Leave it
#                  on: the SDF of a clock-gated design carries negative timing
#                  check limits, and without the library's delayed-signal
#                  models vsim cannot represent them and invents violations
#                  (it warns about this itself, vsim-8756).   (default 1)
#      grain_ps    granularity the simulation period is rounded UP to, in ps
#                  (default 10).  Keep it fine.  sim_period_ns is the frequency
#                  the SAIF power is measured at, and dynamic power goes as
#                  1/T, so a coarse grid adds a per-corner error of 0 to 3% to
#                  the power-vs-period curve depending on where achieved_ns
#                  happens to fall between grid points.  Margin is not needed
#                  here either: DC's achieved_ns already contains the 0.05 ns
#                  set_clock_uncertainty, and the simulator does not apply
#                  uncertainty, so simulating at achieved_ns leaves that whole
#                  0.05 ns as slack.  Physical-design margin belongs in
#                  set_clock_uncertainty in dlx.sdc, not in this period.
#
#     saif_only   after having the saif files, to avoid rerunning tests, and continue from that place
#
#  For every row of the synthesis results.csv:
#
#    1. work out the corner tag (1p0, 2p5, ...) and the simulation period
#    2. vlog that netlist into ../work_gate, replacing the previous DLX
#    3. assemble + golden-model each test, run it on the NETLIST with SDF,
#       diff the data memory against the golden dump
#    4. re-run the power workloads with a SAIF attached; by default each SAIF
#       window runs from the end of reset to the program's final self-loop
#
#  Every run also records the cycle count from reset to that self-loop:
#  gate_results.csv per test, saif_manifest.csv per workload together with
#  the length of the SAIF window in cycles.
#
#  The simulation period is the ACHIEVED period, T_constraint - WNS, rounded up
#  to 10 ps.  That is the fastest clock the netlist really sustains: for a
#  corner that missed its constraint it is slower than the constraint, for one
#  that met it, it is faster.  One rule, both cases, and no setup violations.
#
#  The runtimes in testlist.tcl were written for the 20 ns testbench clock, so
#  they are scaled by (sim_period / 20 ns).  Miss this and the program stops
#  half way through, the compare fails for the wrong reason, and the SAIF
#  describes a partial workload.
#=============================================================================

source ../../../verification/scripts/testlist.tcl

if {![info exists only]}       { set only "" }
if {![info exists only_test]}  { set only_test "" }
if {![info exists recompile]}  { set recompile 1 }
if {![info exists no_sdf]}     { set no_sdf 1 }
if {![info exists saif_sdf]}   { set saif_sdf 0 }
if {![info exists skip_power]} { set skip_power 0 }
if {![info exists csv]}        { set csv ../../reports/results.csv }
if {![info exists notifier]}   { set notifier 0 }
if {![info exists init_rf]}    { set init_rf 1 }
if {![info exists grain_ps]}   { set grain_ps 10 }
if {![info exists ntc]}        { set ntc 1 }
if {![info exists saif_only]} {set saif_only 0 }
if {![info exists power_tests]} { set power_tests {20_power_bench 08_multiplier 24_mac_loops} }
if {![info exists saif_to_end]} { set saif_to_end 1 }
if {![info exists fresh]}       { set fresh 0 }

#  Workloads that get a SAIF.  20_power_bench is the designed switching-activity
#  benchmark, 08_multiplier and 24_mac_loops deliberately different profiles,
#  so the report can say how much the power number moves with the program
#  instead of quoting one figure as if it were a property of the silicon.
set POWER_TESTS $power_tests

set RTL_TB_PERIOD 20.0   ;# ns, the clock testlist.tcl runtimes assume

set NETLIST_DIR ../../netlist
set SAIF_DIR    ../saif_reports
set RESULT_DIR  ../results
set LOG_DIR     ../logs

foreach d [list $SAIF_DIR $RESULT_DIR $LOG_DIR] {
    file mkdir $d
}

#-----------------------------------------------------------------------------
#  helpers
#-----------------------------------------------------------------------------

#  synthesis.tcl builds its file tag with [string map {. p} $clockPeriod] on the
#  literal from the periods list, but results.csv writes the period with %g, so
#  1.0 comes back as "1".  Rebuild the tag the same way, restoring the ".0".
proc corner_tag {period} {
    if {[string first "." $period] < 0} { set period "${period}.0" }
    return [string map {. p} $period]
}

#  "20 us" -> 20000.0 ns
proc to_ns {t} {
    set t [string trim $t]
    if {![regexp {^([0-9.]+)\s*([munp]?s)$} $t -> v u]} {
        error "cannot parse a time out of '$t'"
    }
    switch -- $u {
        s  { return [expr {$v * 1e9}] }
        ms { return [expr {$v * 1e6}] }
        us { return [expr {$v * 1e3}] }
        ns { return [expr {$v * 1.0}] }
        ps { return [expr {$v / 1e3}] }
    }
}

#  Round a period in ns UP to the next whole multiple of $grain ps.  The half
#  period then lands on a whole number of ps for any even grain, which is what
#  the CLK_HALF_PERIOD_PS generic needs.
proc round_up {ns grain} {
    set ps [expr {ceil(($ns * 1000.0) / double($grain)) * $grain}]
    return [expr {$ps / 1000.0}]
}

proc step {label cmd} {
    echo "  $label"
    # 2>@1 folds stderr into stdout: Tcl's exec raises on ANY stderr output and
    # dlxasm.pl warns there, which would turn a warning into a failed test.
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

proc read_csv {path} {
    if {![file exists $path]} { error "synthesis results not found: $path" }
    set f [open $path r]
    set lines [split [string trim [read $f]] "\n"]
    close $f
    set head [split [string trim [lindex $lines 0]] ","]
    set rows {}
    foreach ln [lrange $lines 1 end] {
        set ln [string trim $ln]
        if {$ln eq ""} { continue }
        set vals [split $ln ","]
        set d {}
        foreach k $head v $vals { dict set d [string trim $k] [string trim $v] }
        lappend rows $d
    }
    return $rows
}

#-----------------------------------------------------------------------------
if {$recompile} {
    echo "\n### building the gate-level library ###"
    set ::ntc $ntc
    if {[catch {source compile_gate.do} msg]} {
        echo "compile_gate.do failed: $msg"
        return
    }
}

set rows [read_csv $csv]
echo "\n[llength $rows] corner(s) in $csv"

set summary {}
set manifest {}
set n_pass 0
set n_fail 0
set n_skip 0

foreach row $rows {
    set period [dict get $row period_ns]
    if {[dict exists $row tag]} {
        set tag [dict get $row tag]
    } else {
        set tag [corner_tag $period]
    }
    if {$only ne "" && [string first $only $tag] < 0} { continue }

    set achieved [dict get $row achieved_ns]
    set T        [round_up $achieved $grain_ps]
    set half_ps  [expr {int(round($T * 500.0))}]   ;# T ns -> half period in ps
    set scale    [expr {$T / $RTL_TB_PERIOD}]

    set nl  $NETLIST_DIR/DLX_${tag}.v
    set sdf $NETLIST_DIR/DLX_${tag}.sdf

    echo "\n=============================================================="
    echo "  corner $tag   constraint $period ns   achieved $achieved ns"
    echo "  (achieved rounded up to the next $grain_ps ps)"
    echo "  simulating at $T ns  (half period $half_ps ps, runtimes x [format %.4f $scale])"
    echo "=============================================================="

    if {![file exists $nl]} {
        echo "  *** no netlist $nl -- corner skipped"
        lappend summary [list $tag - SKIP "no netlist"]
        incr n_skip
        continue
    }
    if {!$no_sdf && ![file exists $sdf]} {
        echo "  *** no $sdf -- falling back to a zero-delay run for this corner"
    }

    #  Replace the DLX module in the library with this corner's netlist.
    echo "  vlog: $nl"
    if {[catch {vlog -quiet -work work $nl} msg]} {
        echo "  *** vlog failed: $msg"
        lappend summary [list $tag - FAIL "vlog failed"]
        incr n_fail
        continue
    }

    set have_sdf [file exists $sdf]
    set use_sdf      [expr {$no_sdf   ? "" : [expr {$have_sdf ? $sdf : ""}]}]
    set use_sdf_saif [expr {$saif_sdf ? [expr {$have_sdf ? $sdf : ""}] : ""}]

    #-------------------------------------------------------------------------
    #  phase 1 : functional regression on the netlist
    #-------------------------------------------------------------------------
    
if {!$saif_only} {
    
    foreach t $TESTS {
        set dir [dict get $t dir]
        if {$only_test ne "" && [string first $only_test $dir] < 0} { continue }

        set skip 0
        if {[dict exists $t skip]} { set skip [dict get $t skip] }
        if {$skip} {
            lappend summary [list $tag $dir SKIP [dict get $t note]]
            incr n_skip
            continue
        }

        set asms [glob -nocomplain ../../../verification/tests/$dir/*.asm]
        if {[llength $asms] != 1} {
            lappend summary [list $tag $dir FAIL "expected one .asm, found [llength $asms]"]
            incr n_fail
            continue
        }
        set asm  [lindex $asms 0]
        set name [file rootname [file tail $asm]]
        set base ../../../verification/tests/$dir/$name
        set w    [dict get $t words]

        set rt_ns [expr {[to_ns [dict get $t runtime]] * $scale}]
        if {$rt_ns < 100} { set rt_ns 100 }

        echo "\n  --- $tag / $dir  (total [format %.0f $rt_ns] ns at $T ns) ---"

        if {![step "assembling" [list perl ../../../sim/assembler/dlxasm.pl \
                -o ${base}.bin -list ${base}.list \
                -mem ${base}_imem.txt -datamem ${base}_dmem_init.txt \
                -memsize $w $asm]]} {
            lappend summary [list $tag $dir FAIL "assembly failed"]
            incr n_fail
            continue
        }
        file delete -force ${base}.bin.hdr

        if {![step "golden model" [list python3 ../../../sim/dlxsim.py $asm -w $w \
                --dram-out ${base}_dmem_golden.txt]]} {
            lappend summary [list $tag $dir FAIL "golden model failed"]
            incr n_fail
            continue
        }

        set ::g_dir     $dir
        set ::g_name    $name
        set ::g_words   $w
        set ::g_half_ps $half_ps
        #  10 cycles of startup: reset is 2, the X flush takes a couple more.
        set q_ns [expr {10.0 * $T}]
        set ::g_quiet   [format "%.0f ns" $q_ns]
        set ::g_runtime [format "%.0f ns" [expr {$rt_ns > $q_ns ? $rt_ns - $q_ns : $rt_ns}]]
        set ::g_sdf     $use_sdf
        set ::g_suffix  "_$tag"
        set ::g_saif     ""
        set ::g_settle   ""
        set ::g_notifier $notifier
        set ::g_init_rf  $init_rf
        set ::g_stop_at_end 0
        set ::g_cycles   ""

        if {[catch {source sim_gate.do} msg]} {
            echo "      gate simulation failed: $msg"
            lappend summary [list $tag $dir FAIL "simulation failed"]
            incr n_fail
            continue
        }

        set ok [step "comparing" [list python3 ../../../sim/dlxsim.py $asm -w $w \
                    --dram-out ${base}_dmem_scratch.txt \
                    --compare ${base}_dmem_gate_${tag}.txt]]
        file delete -force ${base}_dmem_scratch.txt

        if {$ok} {
            lappend summary [list $tag $dir PASS "" $::g_cycles]
            incr n_pass
        } else {
            lappend summary [list $tag $dir FAIL "dmem mismatch" $::g_cycles]
            incr n_fail
        }
    }
}

    #-------------------------------------------------------------------------
    #  phase 2 : the SAIF workloads
    #
    #  Deliberately after phase 1.  A netlist that fails its regression still
    #  produces a perfectly well-formed SAIF, and a power number taken from a
    #  broken simulation looks exactly like a good one.
    #-------------------------------------------------------------------------
    if {$skip_power} { continue }

    foreach dir $POWER_TESTS {
        set entry ""
        foreach t $TESTS { if {[dict get $t dir] eq $dir} { set entry $t } }
        if {$entry eq ""} {
            echo "  *** $dir is not in testlist.tcl -- no SAIF for it"
            continue
        }
        set asms [glob -nocomplain ../../../verification/tests/$dir/*.asm]
        if {[llength $asms] != 1} { continue }
        set asm  [lindex $asms 0]
        set name [file rootname [file tail $asm]]
        set w    [dict get $entry words]

        set rt_ns   [expr {[to_ns [dict get $entry runtime]] * $scale}]
        set settle  [expr {20.0 * $T}]      ;# 20 cycles: reset is 4, plus fill
        set runtime [format "%.0f ns" [expr {$rt_ns > $settle ? $rt_ns - $settle : $rt_ns}]]
        set saif    $SAIF_DIR/${tag}__${dir}.saif

        echo "\n  --- SAIF  $tag / $dir  (settle [format %.0f $settle] ns, then $runtime,\
 [expr {$use_sdf_saif eq "" ? "zero-delay" : "SDF annotated"}]) ---"

        set ::g_dir     $dir
        set ::g_name    $name
        set ::g_words   $w
        set ::g_half_ps $half_ps
        set ::g_runtime $runtime
        set ::g_sdf     $use_sdf_saif
        set ::g_suffix  "_${tag}_saif"
        set ::g_saif     $saif
        set ::g_settle   [format "%.0f ns" $settle]
        set ::g_quiet    ""
        set ::g_notifier $notifier
        set ::g_init_rf  $init_rf
        set ::g_stop_at_end $saif_to_end
        set ::g_cycles   ""
        set ::g_window_cycles ""

        if {[catch {source sim_gate.do} msg]} {
            echo "      SAIF run failed: $msg"
            continue
        }
        #  The SAIF run executes the same program, so it can be checked the
        #  same way.  Switching activity from a run that computed the wrong
        #  answer is worthless, and it looks exactly like activity that is not.
        set sbase ../../../verification/tests/$dir/$name
        set ok [step "verifying the SAIF run" \
                  [list python3 ../../../sim/dlxsim.py $asm -w $w \
                        --dram-out ${sbase}_dmem_saifscratch.txt \
                        --compare ${sbase}_dmem_gate_${tag}_saif.txt]]
        file delete -force ${sbase}_dmem_saifscratch.txt
        if {!$ok} {
            echo "      *** the SAIF workload did NOT reproduce the golden result."
            echo "          The power number from it would be meaningless; skipped."
            lappend summary [list $tag "SAIF:$dir" FAIL "workload mismatch"]
            incr n_fail
            continue
        }

        if {[file exists $saif]} {
            echo "      saif -> $saif   (workload verified)"
            lappend manifest [list $tag $dir $saif $T $period $::g_cycles $::g_window_cycles]
        } else {
            echo "      *** no SAIF produced; does this ModelSim have 'power add'?"
        }
    }
}

#-----------------------------------------------------------------------------
#  outputs
#-----------------------------------------------------------------------------
set csv_rows {}
foreach r $summary {
    lassign $r tag dir verdict why cyc
    lappend csv_rows "$tag,$dir,$verdict,\"$why\",$cyc"
}
merge_csv $RESULT_DIR/gate_results.csv "tag,test,verdict,note,cycles" $csv_rows $fresh

#  %g turns the rounded-up period back into 1.6 instead of 1.6000000000000001.
#  A skip_power run has no SAIFs and leaves the manifest alone.
if {!$skip_power} {
    set csv_rows {}
    foreach r $manifest {
        lassign $r tag dir path T period cyc win
        lappend csv_rows "$tag,$dir,$path,[format %g $T],$period,$cyc,$win"
    }
    merge_csv $RESULT_DIR/saif_manifest.csv \
        "tag,workload,saif_path,sim_period_ns,constraint_ns,cycles,window_cycles" \
        $csv_rows $fresh
}

echo "\n=============================================================="
echo "  SUMMARY"
echo "=============================================================="
foreach r $summary {
    lassign $r tag dir verdict why cyc
    echo [format "  %-6s %-6s %-28s %7s  %s" $verdict $tag $dir $cyc $why]
}
echo ""
echo "  $n_pass passed, $n_fail failed, $n_skip skipped"
echo "  $RESULT_DIR/gate_results.csv   (merged; cycles from reset to the final self-loop)"
echo "  $RESULT_DIR/saif_manifest.csv   ([llength $manifest] SAIF file(s))"
echo ""
if {$n_fail > 0} {
    echo "  *** POST-SYNTHESIS REGRESSION FAILED ***"
} else {
    echo "  all good -- next: dc_shell -f post_synthesis_sim/scripts/power_dc.tcl  (from syn/)"
}
