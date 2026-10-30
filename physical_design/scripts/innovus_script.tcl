##  Place and route of the DLX, Nangate 45nm, Innovus v23.
##  Runs inside a directory runs/<name>/, see physical_design/README.md.
##  Same flow as the boothmul one; the DLX-specific parts are the netlist and
##  SDC names, the RST input delay and the IO pins.

##  the netlist and the clock: given by run_pd.sh, otherwise the defaults
##  below are used (interactive run, with a suspend after every step)
##  PD_TAG: synthesis run of the netlist, syn/netlist/DLX_<tag>.v
##  PD_CLOCK: clock of the layout; default = the period the netlist achieved
##  in synthesis (syn/reports/results.csv)
set PD_TAG    1p0
set PD_CLOCK  ""
set PD_BATCH  0
foreach var {PD_TAG PD_CLOCK PD_BATCH} {
    if {[info exists env($var)]} { set $var $env($var) }
}
if {$PD_CLOCK eq ""} {
    set fh [open ../../../syn/reports/results.csv r]
    set head [split [string trim [gets $fh]] ,]
    while {[gets $fh line] >= 0} {
        set row [split [string trim $line] ,]
        if {[lindex $row 0] eq $PD_TAG} {
            set PD_CLOCK [lindex $row [lsearch $head achieved_ns]]
        }
    }
    close $fh
}

##  inital settings based on micro lab

##  floorplan (aspect 1.0, utilization 0.6, 5 um core to die)
set FP_ASPECT      1.0
set FP_UTIL        0.60
if {[info exists env(PD_UTIL)]} { set FP_UTIL $env(PD_UTIL) }
set FP_MARGIN      5.0

##  power ring and stripes
set RING_WIDTH     0.8
set RING_SPACE     0.8
set STRIPE_WIDTH   0.8
set STRIPE_SPACE   0.8
set STRIPE_PITCH   20.0
set STRIPE_START   15.0

##  signals are routed from metal1 to metal6 (lab6: top routing layer 6),
##  metal9/metal10 are kept for the power ring and stripes
set TOP_ROUTE_LAYER 6

##  clock tree targets in ns. lab6 asked for 0.02 skew, but on this design
##  Innovus relaxes it to about 0.042 (warning IMPCCOPT-1261) on the first run, so 0.05 is a reasonable choose
set CTS_MAX_TRANS  0.05
set CTS_SKEW       0.05

##  Nangate45 names (from the LEF, the same names the lab6 GUI produced)
set SITE           FreePDK45_38x28_10R_NP_162NW_34O
set FILLER_CELLS   {FILLCELL_X32 FILLCELL_X16 FILLCELL_X8 FILLCELL_X4 FILLCELL_X2 FILLCELL_X1}
set TIE_CELLS      {LOGIC1_X1 LOGIC0_X1}
set CTS_BUFFERS    {CLKBUF_X1 CLKBUF_X2 CLKBUF_X3}

set DESIGN         DLX
set DB_DIR         dbs
set RPT_DIR        reports
set TIM_DIR        reports/timing
set OUT_DIR        outputs

file mkdir $DB_DIR $RPT_DIR $TIM_DIR $OUT_DIR


##  ---------------------------------------------------------------------------
##  small helpers
##  ---------------------------------------------------------------------------

proc banner {msg} {
    set line [string repeat "=" 70]
    puts "\n$line\n  $msg\n$line\n"
}

##  for report-only command check. If it fails, print the error and go on
proc safe {cmd} {
    if {[catch {uplevel #0 $cmd} err]} {
        puts "**SCRIPT-NOTE: report command failed, flow continues:\n   $cmd\n   -> $err"
    }
}

##  in batch only the final design is saved (about 90 MB each for the
##  multiplier, several times that for the DLX)
proc save_step {name} {
    if {$::PD_BATCH && $name ne "10_final"} { return }
    saveDesign $::DB_DIR/$name.enc
    puts "**SCRIPT-NOTE: design saved as $::DB_DIR/$name.enc"
}

##  lists of bus pin names, e.g. A[0] ... A[31]
proc bus_pins {name width} {
    set pins {}
    for {set i 0} {$i < $width} {incr i} {
        lappend pins "${name}\[$i\]"
    }
    return $pins
}


##############################################################################
##  STEP 0 - import the design
##############################################################################
banner "STEP 0 - import design: netlist + LEF + MMMC (libraries, SDC)"

puts "**SCRIPT-NOTE: netlist DLX_$PD_TAG, clock $PD_CLOCK ns, utilization $FP_UTIL"

##  the SDC of this run is the synthesis SDC with the clock of this run.
##  The DC-only lines are removed: CLK and RST must not stay ideal here
##  (CTS builds the clock tree, RST gets buffers), set_max_area is for DC.
##  The DLX SDC also has group_path -critical_range, a DC-only option (DC
##  itself drops it when it writes an SDC): it is removed, the group stays.
set fh [open ../../../syn/dlx.sdc r]
set sdc [read $fh]
close $fh
set sdc [string map [list {$clockPeriod} $PD_CLOCK] $sdc]
regsub -all -line {^(set_ideal_network|set_dont_touch_network|set_max_area).*$} $sdc "" sdc
regsub -all {\s-critical_range\s+\[expr \{[^\}]*\}\]} $sdc "" sdc

##  RST: in synthesis it is ideal and has no input delay, so here it would be
##  unconstrained: its buffer tree is built for transition only and no report
##  checks it. In the first runs the reset release took about 0.75 ns to reach
##  the IR register, more than the half period it has in the testbench, and
##  the post-layout simulation of 1p0 failed on it. The testbench releases
##  RST on the falling clock edge (sim/TB_DLX.vhd, '0' after 4 half periods),
##  so the input delay is half a period; the driver is that of the other
##  inputs.
append sdc "\nset_driving_cell -lib_cell BUF_X4 -pin Z \[get_ports RST\]\n"
append sdc "set_input_delay [expr {0.5 * $PD_CLOCK}] -clock CLK \[get_ports RST\]\n"

set fh [open $OUT_DIR/$DESIGN.sdc w]
puts $fh $sdc
close $fh

##  read later by the simulation and by collect_pd_results.py
set fh [open $OUT_DIR/run_info.txt w]
puts $fh "tag $PD_TAG"
puts $fh "clock $PD_CLOCK"
puts $fh "util $FP_UTIL"
close $fh

source ../../scripts/dlx.globals
init_design

setMultiCpuUsage -localCpu 4

##  45nm process: sets the extraction and optimization defaults
##  (without it: warning IMPEXT-3530 at extraction)
setDesignMode -process 45

##  connect the VDD/VSS pins of every cell to the nets vdd/gnd.
##  It must be done before any power routing: without it sroute finds no
##  cell pin on vdd/gnd and draws no rails (warnings IMPSR-468, IMPSR-1253).
##  The rules stay active, so cells added later get connected too.
globalNetConnect vdd -type pgpin -pin VDD -inst * -override
globalNetConnect gnd -type pgpin -pin VSS -inst * -override

##  checks on what was imported
safe "checkDesign -netlist -physicalLibrary -timingLibrary -noHtml -outfile $RPT_DIR/00_checkDesign.rpt"
safe "check_timing -verbose > $RPT_DIR/00_check_timing.rpt"

##  no signal integrity (crosstalk) in delay calculation, as in lab6
setDelayCalMode -siAware false

##  timing with zero wire load: should be close to the synthesis report
timeDesign -prePlace -outDir $TIM_DIR -prefix 00_prePlace

banner "STEP 0 done. Look at: reports/00_*.rpt, reports/timing/00_prePlace*.  "
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 1 - floorplan and IO pins
##############################################################################
banner "STEP 1 - floorplan: core size, rows, pin positions"

##  die boundary 
floorPlan -coreMarginsBy die -site $SITE -r $FP_ASPECT $FP_UTIL $FP_MARGIN $FP_MARGIN $FP_MARGIN $FP_MARGIN

##  signal routing layers, used by placement (congestion estimate),
##  optimization and the router
setDesignMode -topRoutingLayer $TOP_ROUTE_LAYER

set die  [lindex [dbGet top.fPlan.box] 0]
set core [lindex [dbGet top.fPlan.coreBox] 0]
set dieW [expr {[lindex $die 2] - [lindex $die 0]}]
set dieH [expr {[lindex $die 3] - [lindex $die 1]}]
puts "**SCRIPT-NOTE: die  box = $die  ($dieW x $dieH um)"
puts "**SCRIPT-NOTE: core box = $core"

##  IO pins, one memory interface per side, so each bus enters next to the
##  stage that uses it: instruction memory on the left (fetch), data memory
##  on the right (memory stage), CLK/RST at the bottom.
##  Left/right pins use metal3 (horizontal), top/bottom pins use metal4 (vertical) because a pin layer must run perpendicular to its side.
set pinsI [concat [bus_pins IRAM_ADDRESS 32] [bus_pins IRAM_DATA 32] IRAM_ISSUE IRAM_READY]
set pinsD [concat [bus_pins DRAM_ADDRESS 32] [bus_pins DRAM_DATA 32] \
                  DRAM_ISSUE DRAM_READNOTWRITE DRAM_READY [bus_pins store_size 2]]

##  spread every bus over 80% of its side
set spI [format %.2f [expr {0.8 * $dieH / [llength $pinsI]}]]
set spD [format %.2f [expr {0.8 * $dieH / [llength $pinsD]}]]

setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Left   -layer metal3 -spreadType center -spacing $spI -pin $pinsI
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Right  -layer metal3 -spreadType center -spacing $spD -pin $pinsD
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Bottom -layer metal4 -spreadType center -spacing 5.0  -pin {CLK RST}
editPin -snap TRACK -pin *
setPinAssignMode -pinEditInBatch false
legalizePin

safe "checkPinAssignment > $RPT_DIR/01_pins.rpt"

save_step 01_floorplan
banner "STEP 1 done. Measure die/core with the ruler (k), zoom on the pins.  "
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 2 - power planning: ring, stripes, rails
##############################################################################
banner "STEP 2 - power: rings (metal9/metal10), stripes (metal10), followpins (metal1)"

## 2a ) ring around the core, in the middle of the 5 um channel
## horizontal sides on metal9, vertical sides on metal10 (GUI: Power -> Power Planning -> Add Rings)

setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 \
    -skip_crossing_trunks none -stacked_via_top_layer metal10 -stacked_via_bottom_layer metal1 \
    -via_using_exact_crossover_size 1 -orthogonal_only true \
    -skip_via_on_pin { standardcell } -skip_via_on_wire_shape { noshape }

addRing -nets {vdd gnd} -type core_rings -follow core \
    -layer {top metal9 bottom metal9 left metal10 right metal10} \
    -width $RING_WIDTH -spacing $RING_SPACE -center 1 \
    -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None

## 2b ) vertical stripes on metal10, one vdd/gnd pair every 20 um starting 15 um from the core edge
## (GUI: Power -> Power Planning -> Add Stripes)
setAddStripeMode -stacked_via_top_layer metal10 -stacked_via_bottom_layer metal1 \
    -orthogonal_only true -skip_via_on_pin { standardcell } -skip_via_on_wire_shape { noshape }

addStripe -nets {gnd vdd} -layer metal10 -direction vertical \
    -width $STRIPE_WIDTH -spacing $STRIPE_SPACE -set_to_set_distance $STRIPE_PITCH \
    -start_from left -start_offset $STRIPE_START \
    -padcore_ring_top_layer_limit metal10 -padcore_ring_bottom_layer_limit metal1 \
    -block_ring_top_layer_limit metal10 -block_ring_bottom_layer_limit metal1 \
    -snap_wire_center_to_grid None

## No horizontal stripes. The first DLX runs also had metal9 stripes along
## the rows: a pair of them lies over a follow-pin every 20 um, blocks the via
## stacks down to it (they run parallel, and -orthogonal_only drops a via
## between parallel wires), and verifyConnectivity reported those rails open.
## The vertical stripes cross every row every 20 um, which is enough.

## 2c ) followpins: one metal1 rail on every row edge, where the VDD/VSS
## pins of the cells will sit, connected to ring and stripes with via stacks 
## (GUI: Route -> Special Route, default options)
setSrouteMode -reset
sroute -connect { blockPin padPin padRing corePin floatingStripe } \
    -layerChangeRange { metal1(1) metal10(10) } \
    -blockPinTarget { nearestTarget } -padPinPortConnect { allPort oneGeom } \
    -padPinTarget { nearestTarget } -corePinTarget { firstAfterRowEnd } \
    -floatingStripeTarget { blockring padring ring stripe ringpin blockpin followpin } \
    -allowJogging 1 -crossoverViaLayerRange { metal1(1) metal10(10) } \
    -nets { vdd gnd } -allowLayerChange 1 -blockPin useLef \
    -targetViaLayerRange { metal1(1) metal10(10) }

##  check the power grid geometry (shorts, spacing) before placing cells
safe "verify_drc -report $RPT_DIR/02_power_drc.rpt -limit 1000"

save_step 02_power
banner "STEP 2 done. Click ring/stripe/rail, check layers and vias. reports/02_power_drc.rpt.  "
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 3 - placement
##############################################################################
banner "STEP 3 - placement of the standard cells"

##  GUI: Place -> Specify -> Placement Blockage on metal1..metal8: the
##  power shapes (via stacks under the stripes) are seen as obstructions,
##  so no cell gets a pin buried under them.
##  IO pins are already placed in step 1, the placer must not move them.
setPlaceMode -reset
setPlaceMode -timingDriven true -congEffort auto -placeIOPins false \
    -prerouteAsObs {1 2 3 4 5 6 7 8}

place_design

##  constant inputs in the netlist (1'b0 / 1'b1) must not be tied straight
##  to the power rail: tie cells LOGIC0/LOGIC1 drive them instead.
setTieHiLoMode -cell $TIE_CELLS -maxFanout 8
addTieHiLo -cell $TIE_CELLS -prefix TIE

##  checks: legal placement and density, area, and now that cells sit on
##  the rails, the power connectivity of every cell
safe "checkPlace $RPT_DIR/03_checkPlace.rpt"
safe "report_area > $RPT_DIR/03_area.rpt"
safe "verifyConnectivity -type special -noAntenna -error 1000 -warning 50 -report $RPT_DIR/03_pg_connectivity.rpt"

##  timing before any optimization, Wires are now estimated from the placement,
##  so it is worse than step 0
timeDesign -preCTS        -outDir $TIM_DIR -prefix 03_place
timeDesign -preCTS -hold  -outDir $TIM_DIR -prefix 03_place

save_step 03_place
banner "STEP 3 done. Hide wires (layer panel), the cells, Design Browser / amoeba view. Comparing 03_place with 00_prePlace.  "
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 4 - pre-CTS optimization
##############################################################################
banner "STEP 4 - optDesign -preCTS"

##  the optimizer aims a little above zero slack, to keep some margin for
##  the next steps (the clock tree and the real wires only make it worse)
## telling the optimizer to not aim for zero slack, but for small positive margin
setOptMode -setupTargetSlack 0.02 -holdTargetSlack 0.02

optDesign -preCTS -outDir $TIM_DIR -prefix 04_preCTS_opt

timeDesign -preCTS -outDir $TIM_DIR -prefix 04_preCTS
safe "report_timing -max_paths 10 > $RPT_DIR/04_preCTS_setup_paths.rpt"

save_step 04_preCTS_opt
banner "STEP 4 done. Compare WNS/TNS/DRV with step 3 (reports/timing/03_* vs 04_*)"
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 5 - clock tree synthesis
##############################################################################
banner "STEP 5 - clock tree synthesis (CCOpt)"

##  the list of cells CTS may use: only clock buffers, which have balanced rise/fall delays (otherwise IMPCCOPT-1184)
create_ccopt_clock_tree_spec
puts "**SCRIPT-NOTE: clock trees: [get_ccopt_clock_trees *]"
safe "set_ccopt_property buffer_cells  {$CTS_BUFFERS}"
safe "set_ccopt_property use_inverters false"
set_ccopt_property target_max_trans $CTS_MAX_TRANS
set_ccopt_property target_skew      $CTS_SKEW

clock_opt_design -cts

##  from now on the clock is propagated: real tree delays, no more ideal
##  latency/transition from the SDC (clock_opt_design already does this, it
##  is repeated to make it visible)
set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [all_clocks]
set_interactive_constraint_modes {}

safe "report_ccopt_clock_trees -file $RPT_DIR/05_clock_trees.rpt"
safe "report_ccopt_skew_groups -file $RPT_DIR/05_skew_groups.rpt"

timeDesign -postCTS        -outDir $TIM_DIR -prefix 05_postCTS
timeDesign -postCTS -hold  -outDir $TIM_DIR -prefix 05_postCTS

save_step 05_cts
banner "STEP 5 done. Clock -> Display -> Clock Tree, reports/05_skew_groups.rpt (skew, latency)"
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 6 - post-CTS optimization
##############################################################################
banner "STEP 6 - optDesign -postCTS (setup, then hold)"

##  hold can only be fixed now: before CTS the clock was ideal, so the
##  real clock skew between flip flops was not known
optDesign -postCTS       -outDir $TIM_DIR -prefix 06_postCTS_opt
optDesign -postCTS -hold -outDir $TIM_DIR -prefix 06_postCTS_opt_hold

timeDesign -postCTS        -outDir $TIM_DIR -prefix 06_postCTS
timeDesign -postCTS -hold  -outDir $TIM_DIR -prefix 06_postCTS

save_step 06_postCTS_opt
banner "STEP 6 done. Setup and hold should both be met now"
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 7 - signal routing
##############################################################################
banner "STEP 7 - routeDesign (NanoRoute)"

##  timing driven, antenna fixing by layer jumping. signal integrity (SI) driven routing is off
##  because the flow does not do SI analysis, for now
setNanoRouteMode -routeWithTimingDriven true -routeWithSiDriven false -drouteFixAntenna true

routeDesign

##  after routing: DRC of the wires, opens/shorts of every net
safe "verify_drc -report $RPT_DIR/07_route_drc.rpt -limit 1000"
safe "verifyConnectivity -type all -noAntenna -error 1000 -warning 50 -report $RPT_DIR/07_route_connectivity.rpt"

##  parasitics now come from the real wires (cap table extraction)
setExtractRCMode -engine postRoute -effortLevel low
timeDesign -postRoute        -outDir $TIM_DIR -prefix 07_route
timeDesign -postRoute -hold  -outDir $TIM_DIR -prefix 07_route

save_step 07_route
banner "STEP 7 done. Wires per layer in the log, white X = DRC (Tools -> Violation Browser).  "
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 8 - post-route optimization
##############################################################################
banner "STEP 8 - optDesign -postRoute (setup, then hold)"

##  on chip variation analysis: launch and capture clock paths are timed
##  separately, CPPR ( common path pessimism removal) removes the pessimism on their common part in their path
setAnalysisMode -analysisType onChipVariation -cppr both

optDesign -postRoute       -outDir $TIM_DIR -prefix 08_postRoute_opt
optDesign -postRoute -hold -outDir $TIM_DIR -prefix 08_postRoute_opt_hold

timeDesign -postRoute        -outDir $TIM_DIR -prefix 08_postRoute
timeDesign -postRoute -hold  -outDir $TIM_DIR -prefix 08_postRoute

##  if hold is still violated: optDesign is heuristic, run it again by hand
##      optDesign -postRoute -hold
##      timeDesign -postRoute -hold

save_step 08_postRoute_opt
banner "STEP 8 done. No setup, hold or DRV violation should be left"
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 9 - filler cells and physical verification
##############################################################################
banner "STEP 9 - fillers, eco route, DRC / connectivity / antenna"

## fillers go in LAST, after every optimization: they fill the rows to 100% and then
## optDesign has no free site to add or resize a cell
##  ( warnings IMPOPT-310 / IMPSP-2002 "density 100%" happen when the fillers were added before optDesign -postCTS)
addFiller -cell $FILLER_CELLS -prefix FILLER

##  the fillers are added on a routed design: fix any DRC they create
##  (warning IMPSP-5217 recommends it)
ecoRoute -target

safe "checkPlace $RPT_DIR/09_checkPlace.rpt"
safe "verify_drc -report $RPT_DIR/09_drc.rpt -limit 1000"
safe "verifyConnectivity -type all -geomConnect -error 1000 -warning 50 -report $RPT_DIR/09_connectivity.rpt"
safe "verifyProcessAntenna"

save_step 09_filler
banner "STEP 9 done. checkPlace density is 100% now. DRC and connectivity reports must be clean"
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 10 - extraction, final reports and output files
##############################################################################
banner "STEP 10 - SPEF, final timing, power, area, netlist, SDF, DEF"

##  parasitic extraction ( -effortLevel low uses the cap table)
setExtractRCMode -engine postRoute -effortLevel low
extractRC
rcOut -spef $OUT_DIR/$DESIGN.spef

##  final timing, with the files that Timing -> Debug Timing can load
timeDesign -postRoute       -timingDebugReport -pathReports -drvReports -slackReports -numPaths 50 -outDir $TIM_DIR -prefix 10_final
timeDesign -postRoute -hold -timingDebugReport -pathReports -slackReports -numPaths 50 -outDir $TIM_DIR -prefix 10_final
safe "report_timing -max_paths 10 > $RPT_DIR/10_setup_paths.rpt"
safe "report_timing -early -max_paths 10 > $RPT_DIR/10_hold_paths.rpt"

##  power: default switching activity (not the SAIF of the synthesis power
##  flow, so not comparable with it). power_postlayout.tcl redoes it with the
##  activity of the post-layout simulation.
safe "report_power > $RPT_DIR/10_power.rpt"

safe "report_area > $RPT_DIR/10_area.rpt"
safe "reportGateCount -level 5 -limit 100 -outfile $RPT_DIR/10_gateCount.rpt"
safe "summaryReport -noHtml -outfile $RPT_DIR/10_summary.rpt"

##  always saved: power_postlayout.tcl restores it
save_step 10_final

##  outputs
##  netlist with the clock tree, buffers and tie cells added by Innovus
saveNetlist $OUT_DIR/${DESIGN}_routed.v
##  SDF for gate level simulation: real clock tree (no -ideal_clock_network),
##  delays recomputed per pin pair (warning SDF-808 suggests it)
safe "write_sdf -recompute_delay_calc $OUT_DIR/${DESIGN}_routed.sdf"
##  full layout in DEF
set defOutLefVia 1
set defOutLefNDR 1
safe "defOut -netlist -routing -allLayers $OUT_DIR/${DESIGN}.def"
##  layout pictures: only with a window (not in batch, innovus -nowin);
##  scripts/snapshots.tcl makes them all from dbs/10_final.enc
if {!$PD_BATCH} { safe "dumpToGIF $OUT_DIR/${DESIGN}_layout.gif" }

banner "STEP 10 done. Results in reports/ and outputs/, design in $DB_DIR/10_final.enc. resume for the corner check"
if {!$PD_BATCH} { suspend }


##############################################################################
##  STEP 11 - optional: check the other corners
##############################################################################
banner "STEP 11 - setup at typical+worst, hold at typical+best"

##  the flow optimized only the typical view. Here setup is also checked
##  with the slow library at 125 C and hold with the fast library at 0 C.
##  This only reports, it does not change the layout.
safe "set_analysis_view -setup {default worst} -hold {default best}"
safe "timeDesign -postRoute       -expandedViews -outDir $TIM_DIR -prefix 11_corners"
safe "timeDesign -postRoute -hold -expandedViews -outDir $TIM_DIR -prefix 11_corners"
safe "set_analysis_view -setup {default} -hold {default}"

banner "FLOW COMPLETE. reports/timing/11_corners* has one line per view."

if {$PD_BATCH} { exit }
