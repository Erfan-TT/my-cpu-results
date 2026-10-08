#=============================================================================
#  sim_gate.do -- ONE gate-level simulation: one netlist, one test
#
#  run_gate_tests.tcl sets these before sourcing; the defaults let you source
#  the file by hand from syn/post_synthesis_sim/scripts.
#
#    g_dir        test folder under ../../../verification/tests/
#    g_name       base name of the .asm in it
#    g_words      TB_DLX memory_size generic
#    g_half_ps    CLK_HALF_PERIOD_PS generic, e.g. 725   <-- HALF, in ps
#    g_runtime    how long to run, already scaled to g_half, e.g. "1410 ns"
#    g_sdf        path to the .sdf, or "" for a zero-delay run
#    g_suffix     appended to the dump name, e.g. "_1p0"
#    g_saif       path for a backward SAIF, or "" for none
#    g_settle     time to run before "power reset", e.g. "30 ns"
#    g_quiet      time to run with the numeric_std warnings muted, e.g. "15 ns".
#                 The netlist's non-reset flops come up X and take a couple of
#                 cycles to flush; while they do, every to_integer() in the
#                 memory models shouts.  The RTL run makes 43 of these and still
#                 MATCHes, so they are startup noise -- but at gate level there
#                 are thousands and they bury anything real.
#    g_notifier   0 to pass +no_notifier, so a timing-check violation is still
#                 reported but does NOT drive the flop to X   (default 0)
#    g_init_rf    1 to deposit 0 into the register-file flops at time 0
#                 (they have no reset in the RTL)             (default 1)
#    g_stop_at_end 1 to end the run (and the SAIF window) when the program
#                 reaches its final self-loop, see TB_DLX's end-of-program
#                 monitor; g_runtime is then only the upper bound (default 0)
#
#  Outputs, set after the run:
#    g_cycles         cycles from reset to the final self-loop, "" if never
#    g_window_cycles  length of the SAIF window in cycles, "" without a SAIF
#
#  Why SDF and the TB clock are independent:  the delays in the .sdf are
#  absolute picoseconds, fixed at synthesis.  The testbench clock is a free
#  choice.  run_gate_tests.tcl drives every netlist at ITS OWN achieved period
#  (T_constraint - WNS), which is the fastest clock that netlist actually
#  sustains, so no setup check fires and nothing goes X for a timing reason.
#=============================================================================

if {![info exists g_dir]}     { set g_dir     01_alu_rtype }
if {![info exists g_name]}    { set g_name    alu_rtype }
if {![info exists g_words]}   { set g_words   512 }
if {![info exists g_half_ps]} { set g_half_ps 10000 }
if {![info exists g_runtime]} { set g_runtime {20 us} }
if {![info exists g_sdf]}     { set g_sdf     "" }
if {![info exists g_suffix]}  { set g_suffix  "" }
if {![info exists g_saif]}    { set g_saif    "" }
if {![info exists g_settle]}   { set g_settle  "" }
if {![info exists g_quiet]}    { set g_quiet    "" }
if {![info exists g_notifier]} { set g_notifier 0 }
if {![info exists g_init_rf]}  { set g_init_rf  1 }
if {![info exists g_stop_at_end]} { set g_stop_at_end 0 }
set g_cycles        ""
set g_window_cycles ""

set g_base ../../../verification/tests/$g_dir/$g_name

#  The program ends in a "j" to itself, which always encodes as 0BFFFFFC.
#  Its line in the instruction image is its word address.  -1 if absent.
proc find_end_pc {imem} {
    set f [open $imem r]
    set i 0
    set pc -1
    while {[gets $f line] >= 0} {
        if {[string toupper [string trim $line]] eq "0BFFFFFC"} {
            set pc [expr {4 * $i}]
            break
        }
        incr i
    }
    close $f
    return $pc
}
set g_end_pc [find_end_pc ${g_base}_imem.txt]

set vsim_cmd [list vsim -quiet -t 1ps]

#  Nangate's flops carry $setuphold(..., NOTIFIER) and a UDP that goes X the
#  moment the notifier toggles.  Pre-layout that is the wrong default: this
#  netlist has NO clock tree, synthesis analysed hold against an ideal clock
#  (zero skew, and it reported zero hold violations), while the SDF contains
#  the real delay of every SNPS_CLOCK_GATE cell.  A gated flop therefore sees
#  its clock later than its ungated source, short paths "violate hold", the
#  notifier fires, and one X eats the whole simulation.  +no_notifier keeps the
#  violations in the transcript -- where a genuine SETUP problem is still
#  visible -- without letting them corrupt the data.
if {!$g_notifier} {
    lappend vsim_cmd +no_notifier
}

if {$g_sdf ne ""} {
    # the DUT instance inside TB_DLX is dlx_i
    lappend vsim_cmd -sdfmax /tb_dlx/dlx_i=$g_sdf
}

lappend vsim_cmd \
    -gCLK_HALF_PERIOD_PS=$g_half_ps \
    -gUSE_ICACHE=false \
    -gUSE_SLOW_DRAM=false \
    -gmemory_size=$g_words \
    -gIRAM_FILE=${g_base}_imem.txt \
    -gDRAM_FILE_INIT=${g_base}_dmem_init.txt \
    -gDRAM_FILE_OUT=${g_base}_dmem_gate${g_suffix}.txt \
    -gEND_PC=$g_end_pc

#  +acc keeps the internal nets visible.  "power add -r" cannot see them
#  otherwise and the SAIF comes out nearly empty.
#  2685/2718 are TFMPC: "Too few port connections ... Missing connection for
#  port 'QN'".  DC leaves QN unwired on every flop that does not use it, so the
#  netlist produces one pair per flop -- about 4460 warnings before the
#  simulation has even started, which buries everything real.  Nothing is
#  actually unconnected that should be connected.
lappend vsim_cmd -suppress 2685,2718
lappend vsim_cmd -voptargs=+acc work.TB_DLX

echo "  vsim: half period $g_half_ps ps, sdf [expr {$g_sdf eq "" ? "none" : $g_sdf}]"
eval $vsim_cmd

#-----------------------------------------------------------------------------
#  The register file has no reset in the RTL -- only a VHDL initialiser, which
#  does not survive synthesis -- so all 32x32 bits plus the zero/sign flags come
#  up X in the netlist.  Every test program was checked against the golden model
#  with three different power-up register patterns and none of them changes a
#  stored word, so the ARCHITECTURE does not care.  The simulator does: X on a
#  flop's D makes it toggle at arbitrary times, that trips $setuphold, and with
#  notifiers on it spreads.  Seed them to zero, which is what the RTL
#  simulation had.
#
#  The deposit has to land on IQ, the UDP's state node: Q is driven by
#  buf(Q, IQ) and a force on it would be overwritten immediately.
#-----------------------------------------------------------------------------
if {$g_init_rf} {
    set rf {}
    foreach pat {/tb_dlx/dlx_i/*reg_file*_reg_*/IQ
                 /tb_dlx/dlx_i/*/*reg_file*_reg_*/IQ
                 /tb_dlx/dlx_i/*/*/*reg_file*_reg_*/IQ} {
        foreach s [find signals -r $pat] { lappend rf $s }
    }
    set rf [lsort -unique $rf]
    foreach s $rf { force -deposit $s 1'b0 0 }
    echo "  register file seeded to 0: [llength $rf] flop(s)"
    #  V3 onward keeps a zero flag beside every register.  The RTL starts it
    #  at '1' -- an all-zero register IS zero -- so seed the same here, or
    #  every unwritten register would claim to be non-zero and a branch on it
    #  would go the other way than in the RTL simulation.  (The sign flag has
    #  no flop of its own: synthesis merges it with data bit 31.)
    set zf {}
    foreach pat {/tb_dlx/dlx_i/*reg_file_sign_zero_bits_reg_*__0_/IQ
                 /tb_dlx/dlx_i/*/*reg_file_sign_zero_bits_reg_*__0_/IQ
                 /tb_dlx/dlx_i/*/*/*reg_file_sign_zero_bits_reg_*__0_/IQ} {
        foreach s [find signals -r $pat] { lappend zf $s }
    }
    set zf [lsort -unique $zf]
    foreach s $zf { force -deposit $s 1'b1 0 }
    if {[llength $zf] > 0} {
        echo "  register zero flags seeded to 1: [llength $zf] flop(s)"
    }
    if {[llength $rf] == 0} {
        echo "  *** none found -- check the instance path with:"
        echo "      find signals -r /tb_dlx/dlx_i/*reg_file*"
    }
}

#-----------------------------------------------------------------------------
#  Startup window.  Reset lasts 2 clock cycles and the X in the non-reset flops
#  takes a couple more to wash out; until it does, every to_integer() in the
#  memory models reports a metavalue.  Mute those two message classes for the
#  window, then turn them back on so anything that happens later is visible.
#  Timing checks are NOT muted here -- a setup violation that repeats after the
#  startup window is a real finding and must stay in the transcript.
#-----------------------------------------------------------------------------
proc quiet_numeric {on} {
    set v [expr {$on ? 1 : 0}]
    catch {set ::NumericStdNoWarnings $v}
    catch {set ::StdArithNoWarnings   $v}
}

if {$g_saif ne ""} {
    #  Collect switching on the DUT only.  The memory models are testbench
    #  furniture; their activity is not part of this chip and would skew both
    #  the file size and the number.
    power add -r /tb_dlx/dlx_i/*

    if {$g_settle ne ""} {
        quiet_numeric 1
        run $g_settle
        quiet_numeric 0
        #  Throw away the reset phase.  It is a burst of activity that never
        #  happens again and it is not representative of the workload.
        power reset
    }
    set c0 [examine -radix decimal /tb_dlx/counter]
    if {$g_stop_at_end && $g_end_pc >= 0} {
        #  End the window at the program's final self-loop.  "resume" makes
        #  the do-file carry on after the run that the stop ended.
        onbreak {resume}
        when -label prog_end {/tb_dlx/prog_done == '1'} { stop }
        run $g_runtime
        nowhen prog_end
        if {[examine /tb_dlx/prog_done] ne "1"} {
            echo "  *** the program never reached its final self-loop;"
            echo "      the SAIF window is the whole runtime"
        }
    } else {
        run $g_runtime
    }
    set g_window_cycles [expr {[examine -radix decimal /tb_dlx/counter] - $c0}]
    echo "  SAIF window: $g_window_cycles cycles"
    power report -all -bsaif $g_saif
} else {
    if {$g_quiet ne ""} {
        quiet_numeric 1
        run $g_quiet
        quiet_numeric 0
    }
    run $g_runtime
}

set g_cycles [examine -radix decimal /tb_dlx/prog_end_cycle]
if {$g_cycles < 0} {
    set g_cycles ""
    echo "  cycles: program did not reach its final self-loop"
} else {
    echo "  cycles: $g_cycles from reset to the final self-loop"
}

quit -sim
