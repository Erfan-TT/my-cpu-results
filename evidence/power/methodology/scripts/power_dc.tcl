#=============================================================================
#  power_dc.tcl -- back-annotated power from the gate-level SAIFs
#
#  Run from my-dlx-cpu/syn  (so that .synopsys_dc.setup is found):
#
#      dc_shell -f post_synthesis_sim/scripts/power_dc.tcl \
#               | tee post_synthesis_sim/logs/power_dc.log
#
#  Reads post_synthesis_sim/results/saif_manifest.csv, which run_gate_tests.tcl
#  writes, and for each entry:
#
#      read the netlist -> link -> re-create the clock at the SIMULATED period
#      -> read_saif -> report_saif (coverage) -> report_power
#
#  The clock is re-created at the period the simulation actually ran at, not at
#  the synthesis constraint.  With good SAIF coverage it barely matters -- DC
#  uses the annotated toggle rates directly -- but it decides what happens on
#  the nets that were NOT annotated, and it keeps the frequency in the report
#  consistent with the frequency the activity was measured at.
#
#  Coverage is written out alongside the power.  Below about 90% a meaningful
#  part of the number is DC's own estimate rather than measured switching, and
#  the report should say so.  That column is the credibility of the result.
#=============================================================================

set PSS       ./post_synthesis_sim
set MANIFEST  $PSS/results/saif_manifest.csv
set OUT_CSV   $PSS/results/power_results.csv
set RPT_DIR   $PSS/results
set NETLIST   ./netlist

if {![file exists $MANIFEST]} {
    echo "*** $MANIFEST not found -- run run_gate_tests.tcl first"
    exit 1
}

file mkdir $RPT_DIR

##-----------------------------------------------------------------------------
##  helpers
##-----------------------------------------------------------------------------

proc read_manifest {path} {
    set f [open $path r]
    set lines [split [string trim [read $f]] "\n"]
    close $f
    set head [split [string trim [lindex $lines 0]] ","]
    set rows {}
    foreach ln [lrange $lines 1 end] {
        set ln [string trim $ln]
        if {$ln eq ""} { continue }
        set d {}
        foreach k $head v [split $ln ","] { dict set d [string trim $k] [string trim $v] }
        lappend rows $d
    }
    return $rows
}

##  Pull one number out of a redirected report.
proc grab {txt pat {dflt ""}} {
    if {[regexp $pat $txt -> v]} { return $v }
    return $dflt
}

##  report_power prints its units on the same line as the value, and which unit
##  it picks depends on the magnitude.  Normalise everything to milliwatts.
proc to_mW {value unit} {
    if {$value eq ""} { return "" }
    switch -- $unit {
        W    { return [expr {$value * 1e3}] }
        mW   { return [expr {$value * 1.0}] }
        uW   { return [expr {$value / 1e3}] }
        nW   { return [expr {$value / 1e6}] }
        pW   { return [expr {$value / 1e9}] }
        default { return $value }
    }
}

##-----------------------------------------------------------------------------
set rows [read_manifest $MANIFEST]
echo "[llength $rows] SAIF file(s) in $MANIFEST"

set out [open $OUT_CSV w]
puts $out "tag,workload,sim_period_ns,constraint_ns,dynamic_mW,leakage_mW,total_mW,saif_coverage_pct"
flush $out

foreach row $rows {
    set tag      [dict get $row tag]
    set workload [dict get $row workload]
    set saif     [dict get $row saif_path]
    set T        [dict get $row sim_period_ns]
    set con      [dict get $row constraint_ns]

    ##  the manifest paths are relative to post_synthesis_sim/scripts
    set saif_abs [file normalize [file join $PSS/scripts $saif]]

    echo ""
    echo "=============================================================="
    echo "  $tag / $workload   simulated at $T ns"
    echo "=============================================================="

    if {![file exists $saif_abs]} {
        echo "  *** missing $saif_abs -- skipped"
        continue
    }

    set nl $NETLIST/DLX_${tag}.v
    if {![file exists $nl]} {
        echo "  *** missing $nl -- skipped"
        continue
    }

    ##  Fresh design every time: read_saif annotation is sticky, and carrying it
    ##  from one corner into the next is the classic way to publish the same
    ##  number twice.
    if {[catch {remove_design -designs} msg]} { echo "  (remove_design: $msg)" }

    if {[catch {read_verilog $nl} msg]} {
        echo "  *** read_verilog failed: $msg"
        continue
    }
    current_design DLX
    if {![link]} {
        echo "  *** link failed for $tag"
        continue
    }

    create_clock -name CLK -period $T [get_ports CLK]
    set_clock_uncertainty 0.05 [get_clocks CLK]

    ##  -instance_name is the path of the DUT inside the SAIF's own hierarchy:
    ##  the testbench is tb_dlx and the instance in it is dlx_i.
    if {[catch {read_saif -input $saif_abs -instance_name tb_dlx/dlx_i} msg]} {
        echo "  *** read_saif failed: $msg"
        continue
    }

    redirect -variable saif_txt { report_saif -hier -missing }
    redirect $RPT_DIR/saif_${tag}_${workload}.rpt { echo $saif_txt }

    ##  report_saif prints a per-design annotation percentage; take the first.
    set cov [grab $saif_txt {([0-9]+\.[0-9]+)%} ""]
    if {$cov eq ""} { set cov [grab $saif_txt {([0-9]+)%} ""] }

    redirect -variable pwr_txt { report_power -analysis_effort medium -nosplit }
    redirect $RPT_DIR/power_${tag}_${workload}.rpt { echo $pwr_txt }

    set dyn_v  [grab $pwr_txt {Total Dynamic Power\s*=\s*([0-9.eE+-]+)}]
    set dyn_u  [grab $pwr_txt {Total Dynamic Power\s*=\s*[0-9.eE+-]+\s*(\w+)}]
    set leak_v [grab $pwr_txt {Cell Leakage Power\s*=\s*([0-9.eE+-]+)}]
    set leak_u [grab $pwr_txt {Cell Leakage Power\s*=\s*[0-9.eE+-]+\s*(\w+)}]

    set dyn  [to_mW $dyn_v  $dyn_u]
    set leak [to_mW $leak_v $leak_u]
    set tot  ""
    if {$dyn ne "" && $leak ne ""} { set tot [expr {$dyn + $leak}] }

    echo [format "  dynamic %s mW   leakage %s mW   total %s mW   saif coverage %s%%" \
              $dyn $leak $tot $cov]
    if {$cov ne "" && $cov < 90} {
        echo "  *** SAIF coverage is only ${cov}% -- a real part of this number is"
        echo "      DC's own estimate, not measured switching.  Say so in the report."
    }

    puts $out "$tag,$workload,$T,$con,$dyn,$leak,$tot,$cov"
    flush $out
}

close $out
echo ""
echo "=============================================================="
echo "  wrote $OUT_CSV"
echo "  per-run reports in $RPT_DIR/power_<tag>_<workload>.rpt"
echo "  next: python3 post_synthesis_sim/scripts/merge_results.py   (from syn/)"
echo "=============================================================="
exit
