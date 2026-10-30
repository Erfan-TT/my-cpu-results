#=============================================================================
#  sim_postlayout.do -- simulate every routed netlist (ModelSim)
#
#  Run from physical_design/sim:
#      vsim -c -do sim_postlayout.do
#      vsim -c -do "set only pd_1p0; do sim_postlayout.do"
#  A run that already has reports/12_sim.txt is skipped, as in the boothmul
#  flow; delete that file to simulate the run again.
#
#  It reuses the post-synthesis flow unchanged
#  (syn/post_synthesis_sim/scripts/run_gate_tests.tcl), pointed at the routed
#  netlists instead of the synthesized ones:
#
#    1. every finished run (runs/<run>/outputs/DLX_routed.v) becomes one corner;
#       its period is the post-layout ACHIEVED period, clock - WNS from the
#       final timing (reports/timing/10_final.slk), the same rule as synthesis.
#       The list is written to ../results/pd_corners.csv.
#    2. phase 1: the whole test suite on each routed netlist, WITH its SDF and
#       with timing checks driving X (notifier on).  After CTS the clock tree is
#       real, so a timing-check violation here is a real finding, not the
#       pre-layout artefact the synthesis flow had to mask.
#    3. phase 2: the power workloads again, SDF annotated, each with a SAIF
#       over the program (end of reset to the final self-loop).  A SAIF is only
#       kept if that run also reproduced the golden data memory.
#
#  Results: ../results/sim/gate_results.csv (verdict and cycles per test),
#  ../results/sim/saif_manifest.csv (the SAIFs for run_power.sh),
#  ../results/saif/*.saif.
#
#  Knobs of run_gate_tests.tcl can be set before "do" (only, only_test,
#  skip_power, power_tests, notifier, ...).  notifier 0 keeps timing-check
#  violations in the transcript without letting them corrupt the run.
#=============================================================================

set pd_root [file normalize ..]
file mkdir $pd_root/results

#-----------------------------------------------------------------------------
#  1. the finished runs
#-----------------------------------------------------------------------------
proc read_kv {path} {
    set d {}
    set f [open $path r]
    while {[gets $f line] >= 0} {
        if {[llength $line] == 2} { dict set d [lindex $line 0] [lindex $line 1] }
    }
    close $f
    return $d
}

#  worst setup slack: first path of the .slk, third field "rise/fall"
proc final_wns {slk} {
    set f [open $slk r]
    gets $f
    gets $f line
    close $f
    set wns ""
    foreach s [split [lindex $line 2] "/"] {
        if {$s eq "*"} { continue }
        if {$wns eq "" || $s < $wns} { set wns $s }
    }
    return $wns
}

set corners {}
foreach run [lsort [glob -nocomplain -type d $pd_root/runs/*]] {
    set name [file tail $run]
    set slk  $run/reports/timing/10_final.slk
    if {![file exists $run/outputs/DLX_routed.v] || ![file exists $run/outputs/DLX_routed.sdf]
        || ![file exists $slk] || ![file exists $run/outputs/run_info.txt]} {
        echo "  $name: not finished, skipped"
        continue
    }
    #  already simulated (delete reports/12_sim.txt to simulate it again)
    if {[file exists $run/reports/12_sim.txt]} {
        echo "  $name: already simulated, skipped"
        continue
    }
    set clock [dict get [read_kv $run/outputs/run_info.txt] clock]
    set wns   [final_wns $slk]
    set achieved [format %.4f [expr {$clock - $wns}]]
    echo "  $name: clock $clock ns, WNS $wns ns, achieved $achieved ns"
    lappend corners "$name,$clock,$achieved"
}
if {[llength $corners] == 0} {
    echo "*** no run to simulate in $pd_root/runs -- run ../run_pd.sh first"
    quit -f
}
set f [open $pd_root/results/pd_corners.csv w]
puts $f "tag,period_ns,achieved_ns"
foreach c $corners { puts $f $c }
close $f

#-----------------------------------------------------------------------------
#  2-3. the post-synthesis regression, on the routed netlists
#-----------------------------------------------------------------------------
set csv        $pd_root/results/pd_corners.csv
set nl_pattern $pd_root/runs/%s/outputs/DLX_routed
set saif_dir   $pd_root/results/saif
set result_dir $pd_root/results/sim
set log_dir    $pd_root/results/logs
if {![info exists no_sdf]}   { set no_sdf 0 }
if {![info exists saif_sdf]} { set saif_sdf 1 }
if {![info exists notifier]} { set notifier 1 }

set here [pwd]
cd ../../syn/post_synthesis_sim/scripts
source run_gate_tests.tcl
cd $here

#-----------------------------------------------------------------------------
#  4. one line per run, as in the boothmul flow: reports/12_sim.txt holds
#     "<simulated period> <failed tests>".  A run with failures has no
#     trustworthy power: run_power.sh only uses the SAIFs that matched.
#-----------------------------------------------------------------------------
foreach c $corners {
    lassign [split $c ,] name clock achieved
    set fails 0
    set n 0
    set f [open $result_dir/gate_results.csv r]
    gets $f
    while {[gets $f line] >= 0} {
        set v [split $line ,]
        if {[lindex $v 0] ne $name} { continue }
        incr n
        if {[lindex $v 2] ne "PASS"} { incr fails }
    }
    close $f
    #  not simulated in this call (filtered out with "only")
    if {$n == 0} { continue }
    set f [open $pd_root/runs/$name/reports/12_sim.txt w]
    puts $f "$achieved $fails"
    close $f
    echo "  $name: $n tests, $fails not passed"
}

quit -f
