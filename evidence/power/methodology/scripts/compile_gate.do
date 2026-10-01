#=============================================================================
#  compile_gate.do -- build the GATE-LEVEL ModelSim library
#
#  Run from my-dlx-cpu/syn/post_synthesis_sim/scripts:
#      vsim -c -do compile_gate.do -do "quit -f"
#  run_gate_tests.tcl sources it automatically unless $recompile is 0.
#
#  What goes in, and what deliberately does not:
#
#    IN   NangateOpenCellLibrary.v   the standard cell models
#    IN   the VHDL packages the testbench and the memory models need
#    IN   the memory models and TB_DLX itself
#    OUT  every RTL design file, including DLX.vhd
#
#  That last line is the whole point.  TB_DLX instantiates DLX through a
#  component declaration, which ModelSim binds to work.DLX.  If DLX.vhd were
#  in this library it would win and you would be simulating the RTL again
#  without noticing.  The DLX module arrives from the Verilog netlist, which
#  run_gate_tests.tcl vlog's into this same library once per corner.
#
#  The library lives in ../work_gate, separate from the RTL ../../../verification/work,
#  so the two flows cannot contaminate each other.
#=============================================================================

if {[file exists ../work_gate]} { vdel -all -lib ../work_gate }
vlib ../work_gate
vmap work ../work_gate

set LIB_V ../NangateOpenCellLibrary.v

if {![file exists $LIB_V]} {
    error "cell library not found: $LIB_V"
}
#  +define+NTC selects the library's negative-timing-check models, the ones
#  that carry delayed copies of the data and reference signals:
#
#      `ifdef NTC
#        $setuphold(posedge CK, negedge D, 0.1, 0.1, NOTIFIER, , ,CK_d, D_d);
#      `else
#        $setuphold(posedge CK, negedge D, 0.1, 0.1, NOTIFIER);
#
#  Without it vsim says so itself, at time 0:
#
#      (vsim-8756) Instance '...clk_gate_IR_out_reg.latch' - Negative timing
#      check limits detected in simulation with cells modeled without delayed
#      copies of data or reference signals.
#
#  The SDF of a clock-gated design does contain negative limits, and a
#  simulator that cannot represent them reports violations that are not there.
#  Set ntc 0 in run_gate_tests.tcl to go back to the plain models.
if {![info exists ::ntc]} { set ::ntc 1 }
set lib_args [list -quiet -work work]
if {$::ntc} { lappend lib_args +define+NTC }
lappend lib_args $LIB_V

echo "vlog: $LIB_V  [expr {$::ntc ? "(+define+NTC)" : "(plain models)"}]"
if {[catch {eval vlog $lib_args} msg]} {
    echo "*** FAILED to compile the cell library"
    echo "    $msg"
    error "compile_gate.do aborted"
}

#-----------------------------------------------------------------------------
#  VHDL side.  Dependency order: packages, then the models, then the TB.
#  Paths are relative to this directory (syn/post_synthesis_sim/scripts), so
#  ../../.. is the repository root.
#-----------------------------------------------------------------------------
set VHD {
    ../../../common_pkg.vhd
    ../../../sim/TB_packages/rocache.vhd
    ../../../sim/TB_packages/rwcache.vhd
    ../../../sim/TB_romem/rocache.vhd
    ../../../sim/TB_romem/romem.vhd
    ../../../sim/TB_rwmem/rwcache.vhd
    ../../../sim/TB_rwmem/rwmem.vhd
    ../../../sim/simple_memories/simple_dram.vhd
    ../../../sim/simple_memories/simple_iram.vhd
    ../../../sim/TB_DLX.vhd
}

foreach f $VHD {
    if {![file exists $f]} {
        echo "*** MISSING: $f"
        error "compile_gate.do aborted"
    }
    echo "vcom: $f"
    if {[catch {vcom -2008 -quiet $f} msg]} {
        echo "*** FAILED: $f"
        echo "    $msg"
        error "compile_gate.do aborted"
    }
}

echo ""
echo "=== gate-level library ready in ../work_gate ==="
echo "    the DLX module is NOT in it yet; run_gate_tests.tcl vlog's one"
echo "    netlist per corner before each batch of simulations."
echo ""
