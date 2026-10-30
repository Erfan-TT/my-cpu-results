##  Layout pictures of a finished run, for the report.
##  Needs the window, so not in batch: from a run directory
##
##      cd runs/pd_1p0
##      innovus -files ../../scripts/snapshots.tcl
##
##  Maximize the Innovus window when it opens, before the script reaches the
##  pictures: the GIF has the size of the layout area of the window.
##  Pictures go to outputs/pics/*.gif. Every view is wrapped in "try": a
##  command that this Innovus version does not know is skipped, and the
##  others are still written (the README lists the same views from the menus).

set DESIGN  DLX
set PIC_DIR outputs/pics
file mkdir $PIC_DIR

proc try {cmd} {
    if {[catch {uplevel #0 $cmd} err]} {
        puts "**SCRIPT-NOTE: skipped: $cmd\n   -> $err"
    }
}

##  all routing layers on or off
proc metal_layers {visible {layers {1 2 3 4 5 6 7 8 9 10}}} {
    foreach m $layers { try "setLayerPreference allM$m -isVisible $visible" }
}

proc pic {name} {
    try "fit"
    try "dumpToGIF $::PIC_DIR/$name.gif"
    puts "**SCRIPT-NOTE: $::PIC_DIR/$name.gif"
}

restoreDesign dbs/10_final.enc.dat $DESIGN
##  the layout window, as in the boothmul GUI run (its journal has "win"
##  before dumpToGIF; the batch runs, innovus -nowin, wrote no GIF)
try "win"
try "setDrawView place"

##  1. the routed layout, everything visible
pic layout_full

##  2. power grid: the ring and the stripes are the only shapes on metal9 and
##  metal10 (signals stop at metal6)
metal_layers 0
try "setLayerPreference stdCell -isVisible 0"
metal_layers 1 {9 10}
pic layout_power
metal_layers 1
try "setLayerPreference stdCell -isVisible 1"

##  3. clock tree: the clock nets selected, over the cells without routing
metal_layers 0
try "deselectAll"
foreach net [dbGet [dbGet top.nets.isClock 1 -p].name] { try "selectNet $net" }
pic layout_clock
try "deselectAll"

##  4. where each part of the design was placed, one picture each. The
##  netlist is flat except the register file: the gates are named U<n>, only
##  the flip-flops keep the name of their unit. So the stage pictures show the
##  registers of the stage (fetch includes the BTB), the register file picture
##  all of its cells.
foreach {name pattern} {
    regfile   DP_i_decode_i_reg_file_i/*
    fetch     DP_i_fetch_i_*
    decode    DP_i_decode_i_*
    execute   DP_i_execute_i_*
    memory    DP_i_mem_access_i_*
    control   CP_i_*
} {
    try "deselectAll"
    foreach inst [dbGet top.insts.name $pattern] { try "selectInst $inst" }
    pic place_$name
}
try "deselectAll"
metal_layers 1

exit
