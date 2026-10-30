##  Post-layout power from the activity of the post-layout simulation.
##  Run inside a run directory, see physical_design/README.md; run_power.sh
##  gives PD_WORKLOAD, PD_SAIF and PD_SIM_PERIOD for each verified workload.
##
##  Same steps as the boothmul flow. The difference is the activity file: the
##  boothmul flow recorded a VCD, the DLX flow reuses the post-synthesis
##  regression, which writes a SAIF over the program (end of reset to the
##  final self-loop) and keeps it only if the run reproduced the golden data
##  memory. A SAIF holds toggle counts, not a frequency, so the clock is set
##  to the period the simulation ran at.

set DESIGN DLX
set WL     $env(PD_WORKLOAD)
set SAIF   $env(PD_SAIF)
set PERIOD $env(PD_SIM_PERIOD)

if {![file exists $SAIF]} {
    puts "**SCRIPT-NOTE: $SAIF not found, run sim/sim_postlayout.do first"
    exit
}

restoreDesign dbs/10_final.enc.dat $DESIGN

##  same extraction as the flow, from the routed wires
setExtractRCMode -engine postRoute -effortLevel low
extractRC

##  clock of the simulation
set_interactive_constraint_modes [all_constraint_modes -active]
create_clock -name CLK -period $PERIOD -waveform [list 0 [expr {$PERIOD / 2.0}]] [get_ports CLK]
set_propagated_clock [all_clocks]
set_interactive_constraint_modes {}

##  the scope is the design instance inside the testbench. If the activity
##  cannot be read, stop: report_power would silently fall back to the
##  default activity and the number would mean something else.
if {[catch {read_activity_file -format SAIF -scope tb_dlx/dlx_i $SAIF} err]} {
    puts "**SCRIPT-NOTE: read_activity_file failed, no power report written:\n   $err"
    exit
}

report_power > reports/12_power_$WL.rpt

exit
