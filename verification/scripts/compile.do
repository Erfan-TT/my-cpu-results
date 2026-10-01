#=============================================================================
# compile.do -- build the whole DLX design into the "work" library
#
# Run from THIS directory (my-dlx-cpu/verification/scripts).  The library lands
# in verification/work; the RTL is ../../<path> (the repo root is two levels
# up) and the testbench plus its memory models are under ../../sim/.
#     ModelSim GUI : do compile.do
#     batch        : vsim -c -do compile.do -do "quit -f"
#
# Paths are written out literally: a Tcl braced list does NOT expand
# variables, so "$SRC/..." inside {} would be passed to vcom verbatim.
#
# The order below is a verified dependency order: packages first, then leaf
# entities, then the stages, then DLX, then the testbench. Files holding
# configuration declarations (mux21, rca, carry_select_block, fa, iv, nd2)
# come after the entities they configure.
#
# There is now ONE copy of the shared gate/adder library, under
# DataPath/execute/adder (+ its common/ subfolder).  It used to be duplicated
# under decode/branch_correction and execute/boothmul_DLX; both sets were
# analysed into the same work library, so whichever came last silently replaced
# the other and half the tree was dead code.  Do not reintroduce a second copy.
#
# All VHDL-2008. The provided ROCACHE_PKG / RWCACHE_PKG use the Synopsys
# std_logic_arith and std_logic_misc packages; ModelSim ships those in its
# ieee library, so no extra switch is needed.
#=============================================================================

if {[file exists ../work]} { vdel -all -lib work }
vlib ../work
vmap work ../work

set FILES {
    ../../common_pkg.vhd
    ../../ControlPath/alu_pkg.vhd
    ../../ControlPath/control_const_pkg.vhd
    ../../DataPath/execute/shifter/shifter_pkg.vhd
    ../../DataPath/execute/zero_and_sign_detector.vhd
    ../../DataPath/execute/boothmul_DLX/packages/common_boothmul_pkg.vhd
    ../../DataPath/execute/boothmul_DLX/packages/dadda_types_pkg.vhd
    ../../DataPath/execute/boothmul_DLX/packages/wallace_math_pkg.vhd
    ../../DataPath/execute/boothmul_DLX/packages/dadda_math_pkg.vhd
    ../../sim/TB_packages/rocache.vhd
    ../../sim/TB_packages/rwcache.vhd
    ../../DataPath/execute/adder/common/iv.vhd
    ../../DataPath/execute/adder/common/nd2.vhd
    ../../DataPath/execute/adder/common/fa.vhd
    ../../DataPath/execute/adder/common/ha.vhd
    ../../DataPath/execute/adder/common/mux21.vhd
    ../../DataPath/execute/adder/common/mux21_generic.vhd
    ../../DataPath/execute/adder/rca.vhd
    ../../DataPath/execute/adder/carry_select_block.vhd
    ../../DataPath/execute/adder/sum_generator.vhd
    ../../DataPath/execute/adder/G_block.vhd
    ../../DataPath/execute/adder/PG_elem.vhd
    ../../DataPath/execute/adder/PG_block.vhd
    ../../DataPath/execute/adder/carry_generator.vhd
    ../../DataPath/execute/adder/P4_adder.vhd
    ../../DataPath/decode/branch_correction/decision_unit.vhd
    ../../DataPath/decode/branch_correction/branch_correction.vhd
    ../../DataPath/decode/D_ff.vhd
    ../../DataPath/decode/data_reg.vhd
    ../../DataPath/decode/sign_extension.vhd
    ../../DataPath/decode/register_file.vhd
    ../../DataPath/decode/special_reg_file.vhd
    ../../DataPath/decode/special_pc_logic.vhd
    ../../DataPath/decode/illegal_detector.vhd
    ../../DataPath/decode/decode.vhd
    ../../DataPath/execute/boothmul_DLX/reg_N.vhd
    ../../DataPath/execute/boothmul_DLX/booth_encoder.vhd
    ../../DataPath/execute/boothmul_DLX/mux_and_shift.vhd
    ../../DataPath/execute/boothmul_DLX/corrector.vhd
    ../../DataPath/execute/boothmul_DLX/dadda_tree.vhd
    ../../DataPath/execute/boothmul_DLX/boothmul.vhd
    ../../DataPath/execute/shifter/mask_gen.vhd
    ../../DataPath/execute/shifter/shifter.vhd
    ../../DataPath/execute/logic.vhd
    ../../DataPath/execute/comparator_and_adder.vhd
    ../../DataPath/execute/enable_generator.vhd
    ../../DataPath/execute/execute.vhd
    ../../DataPath/fetch/data_reg.vhd
    ../../DataPath/fetch/btb.vhd
    ../../DataPath/fetch/fetch.vhd
    ../../DataPath/mem_stage/byte_load.vhd
    ../../DataPath/mem_stage/half_w_load.vhd
    ../../DataPath/mem_stage/store_data_maker.vhd
    ../../DataPath/mem_stage/exception_detector.vhd
    ../../DataPath/mem_stage/mem_access.vhd
    ../../DataPath/writeback/writeback.vhd
    ../../DataPath/DataPath.vhd
    ../../ControlPath/CU_HW_LUT.vhd
    ../../ControlPath/en_mul_gen.vhd
    ../../ControlPath/ID_EX_control_reg.vhd
    ../../ControlPath/EX_MEM_control_reg.vhd
    ../../ControlPath/MEM_WB_control_reg.vhd
    ../../ControlPath/forwarding.vhd
    ../../ControlPath/hazard_detection.vhd
    ../../ControlPath/pipeline_control.vhd
    ../../ControlPath/ControlPath.vhd
    ../../DLX.vhd
    ../../sim/TB_romem/rocache.vhd
    ../../sim/TB_romem/romem.vhd
    ../../sim/TB_rwmem/rwcache.vhd
    ../../sim/TB_rwmem/rwmem.vhd
    ../../sim/simple_memories/simple_dram.vhd
    ../../sim/simple_memories/simple_iram.vhd
    ../../sim/TB_DLX.vhd
}
set errors 0
foreach f $FILES {
    if {![file exists $f]} {
        echo "*** MISSING: $f"
        incr errors
        break
    }
    echo "vcom: $f"
    if {[catch {vcom -2008 -quiet $f} msg]} {
        echo "*** FAILED: $f"
        echo "    $msg"
        incr errors
        break
    }
}

if {$errors == 0} {
    echo ""
    echo "=== compile OK ==="
    echo "Next:  vsim -c -do run_tests.tcl"
    echo ""
    echo "Memory images are per test, under ../tests/<test>/ ;"
    echo "run the whole suite with:  vsim -c -do run_tests.tcl"
} else {
    echo ""
    echo "=== compile FAILED ==="
}
