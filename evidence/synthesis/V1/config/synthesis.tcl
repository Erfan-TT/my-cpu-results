##=============================================================================
##  Synthesis of the DLX CPU, Nangate 45nm.
##
##  Run from my-dlx-cpu/syn:
##      dc_shell -f synthesis.tcl | tee synthesis.log
##
##  Each clock period gives one netlist (to be back-annotated in ../sim), one
##  SDF, one set of reports and one row in results.csv.  Those rows are the
##  points of the Pareto curve.
##=============================================================================

##-----------------------------------------------------------------------------
##  MESSAGES
##
##  VER-130 : "design already analysed, replacing it".  Expected: decode and
##            fetch both hold a byte-identical data_reg.vhd.
##  UID-401 : harmless naming notes from change_names.
##  TIM-134 : wire load model notes.
##
##  LINK-14 ("cannot resolve reference") is deliberately NOT suppressed.  On a
##  63-file design a suppressed LINK-14 turns a missing entity into an empty
##  black box, and you get clean-looking area and timing for a CPU with a hole
##  in it.  The explicit link check below catches it instead.
##-----------------------------------------------------------------------------
suppress_message VER-130
suppress_message UID-401
suppress_message TIM-134

##-----------------------------------------------------------------------------
##  VHDL-2008
##
##  The RTL is VHDL-2008 and will not analyse as VHDL-93:
##    - DLX.vhd reads its own output port (DRAM_ISSUE) in the DRAM_DATA driver
##    - special_reg_file.vhd and btb.vhd use process(all)
##    - dadda_tree.vhd declares an array of an unconstrained element type
##  ../verification/scripts/compile.do uses "vcom -2008" for the same reason.
##-----------------------------------------------------------------------------
set hdlin_vhdl_std 2008

set blockName DLX

# the clock periods of the sweep
#set periods {1.0 1.2 1.5 1.7 2.0 2.2 2.5 3.0}
#set periods {1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 3.5 4.0}
set periods {1.05 1.15 1.25 1.35 1.45 1.55}


set netlist_dir "./netlist"
set reports_dir "./reports"
file mkdir $netlist_dir
file mkdir $reports_dir

##-----------------------------------------------------------------------------
##  HELPERS
##-----------------------------------------------------------------------------

## Total synthesized cell area in um^2.
proc get_total_area {} {
    redirect -variable txt {report_area -nosplit}

    foreach line [split $txt "\n"] {
        if {[regexp {Total cell area:\s*([0-9.eE+-]+)} $line -> area]} {
            return [expr {double($area)}]
        }
    }

    error "Could not extract Total cell area from report_area"
}

##  report_power prints a number plus a unit that changes with the magnitude.
##  Normalise everything to watts so the CSV columns are comparable.
proc power_to_watts {value unit} {
    switch -- [string tolower $unit] {
        "w"   { return [expr {double($value)}] }
        "mw"  { return [expr {double($value) * 1e-3}] }
        "uw"  { return [expr {double($value) * 1e-6}] }
        "nw"  { return [expr {double($value) * 1e-9}] }
        "pw"  { return [expr {double($value) * 1e-12}] }
        default { return [expr {double($value)}] }
    }
}

##  Pull dynamic and leakage power out of report_power without going to disk.
proc get_power {} {
    redirect -variable txt {report_power -nosplit}
    set dyn  0.0
    set leak 0.0
    foreach line [split $txt "\n"] {
        if {[regexp {Total Dynamic Power\s*=\s*([0-9.eE+-]+)\s*([a-zA-Z]*)} $line -> v u]} {
            set dyn [power_to_watts $v $u]
        }
        if {[regexp {Cell Leakage Power\s*=\s*([0-9.eE+-]+)\s*([a-zA-Z]*)} $line -> v u]} {
            set leak [power_to_watts $v $u]
        }
    }
    return [list $dyn $leak]
}

##  Worst slack of the design.  Positive slack means the period was met.
proc get_worst_slack {} {
    set worst 1.0e10
    foreach_in_collection p [get_timing_paths -delay_type max -max_paths 200 -nworst 20] {
        set s [get_attribute $p slack]
        if {$s < $worst} {set worst $s }
    }
    return $worst
}

##-----------------------------------------------------------------------------
##  ANALYZE
##
##  One call, the list order is a verified dependency order: packages, then the
##  gate/adder library (each of those files carries its own configuration
##  declaration, so it must precede whatever references it), then the stages,
##  then DataPath / ControlPath, then DLX.
##-----------------------------------------------------------------------------
set FILES {
    ../common_pkg.vhd
    ../ControlPath/alu_pkg.vhd
    ../ControlPath/control_const_pkg.vhd
    ../DataPath/execute/shifter/shifter_pkg.vhd
    ../DataPath/execute/boothmul_DLX/packages/common_boothmul_pkg.vhd
    ../DataPath/execute/boothmul_DLX/packages/dadda_types_pkg.vhd
    ../DataPath/execute/boothmul_DLX/packages/wallace_math_pkg.vhd
    ../DataPath/execute/boothmul_DLX/packages/dadda_math_pkg.vhd
    ../DataPath/execute/adder/common/iv.vhd
    ../DataPath/execute/adder/common/nd2.vhd
    ../DataPath/execute/adder/common/fa.vhd
    ../DataPath/execute/adder/common/ha.vhd
    ../DataPath/execute/adder/common/mux21.vhd
    ../DataPath/execute/adder/common/mux21_generic.vhd
    ../DataPath/execute/adder/rca.vhd
    ../DataPath/execute/adder/carry_select_block.vhd
    ../DataPath/execute/adder/sum_generator.vhd
    ../DataPath/execute/adder/G_block.vhd
    ../DataPath/execute/adder/PG_elem.vhd
    ../DataPath/execute/adder/PG_block.vhd
    ../DataPath/execute/adder/carry_generator.vhd
    ../DataPath/execute/adder/P4_adder.vhd
    ../DataPath/execute/zero_and_sign_detector.vhd
    ../DataPath/decode/branch_correction/decision_unit.vhd
    ../DataPath/decode/branch_correction/branch_correction.vhd
    ../DataPath/decode/D_ff.vhd
    ../DataPath/decode/data_reg.vhd
    ../DataPath/decode/sign_extension.vhd
    ../DataPath/decode/register_file.vhd
    ../DataPath/decode/special_reg_file.vhd
    ../DataPath/decode/special_pc_logic.vhd
    ../DataPath/decode/illegal_detector.vhd
    ../DataPath/decode/decode.vhd
    ../DataPath/execute/boothmul_DLX/reg_N.vhd
    ../DataPath/execute/boothmul_DLX/booth_encoder.vhd
    ../DataPath/execute/boothmul_DLX/mux_and_shift.vhd
    ../DataPath/execute/boothmul_DLX/corrector.vhd
    ../DataPath/execute/boothmul_DLX/dadda_tree.vhd
    ../DataPath/execute/boothmul_DLX/boothmul.vhd
    ../DataPath/execute/shifter/mask_gen.vhd
    ../DataPath/execute/shifter/shifter.vhd
    ../DataPath/execute/logic.vhd
    ../DataPath/execute/comparator_and_adder.vhd
    ../DataPath/execute/enable_generator.vhd
    ../DataPath/execute/execute.vhd
    ../DataPath/fetch/data_reg.vhd
    ../DataPath/fetch/btb.vhd
    ../DataPath/fetch/fetch.vhd
    ../DataPath/mem_stage/byte_load.vhd
    ../DataPath/mem_stage/half_w_load.vhd
    ../DataPath/mem_stage/store_data_maker.vhd
    ../DataPath/mem_stage/exception_detector.vhd
    ../DataPath/mem_stage/mem_access.vhd
    ../DataPath/writeback/writeback.vhd
    ../DataPath/DataPath.vhd
    ../ControlPath/CU_HW_LUT.vhd
    ../ControlPath/en_mul_gen.vhd
    ../ControlPath/ID_EX_control_reg.vhd
    ../ControlPath/EX_MEM_control_reg.vhd
    ../ControlPath/MEM_WB_control_reg.vhd
    ../ControlPath/forwarding.vhd
    ../ControlPath/hazard_detection.vhd
    ../ControlPath/pipeline_control.vhd
    ../ControlPath/ControlPath.vhd
    ../DLX.vhd
}

##  File by file, so a failure names the file instead of dying anonymously
##  somewhere inside a 63-element list.
foreach f $FILES {
    if {![file exists $f]} {
        echo "*** MISSING: $f"
        exit 1
    }
    if {[catch {analyze -library WORK -format vhdl $f} msg]} {
        echo "*** ANALYZE FAILED: $f"
        echo "    $msg"
        exit 1
    }
}
echo "=== analyze OK: [llength $FILES] files ==="

##-----------------------------------------------------------------------------
##  RESULTS CSV
##
##  Column names match what ../syn/plot_pareto.py reads.
##-----------------------------------------------------------------------------
set csv [open "$reports_dir/results.csv" w]
puts $csv "tag,period_ns,achieved_ns,slack_ns,met,area_um2,dynamic_power,leakage_power"
flush $csv

##=============================================================================
##  THE SWEEP
##=============================================================================
foreach clockPeriod $periods {

    # 2.5 becomes 2p5, so we can use it in file names
    set tag [string map {. p} $clockPeriod]

    echo "==============================================================="
    echo "  Synthesising $blockName with clock period $clockPeriod ns"
    echo "==============================================================="

    ##-------------------------------------------------------------------------
    ##  ELABORATE + LINK
    ##-------------------------------------------------------------------------
    if {[catch {elaborate $blockName -library WORK} msg]} {
        echo "*** ELABORATE FAILED at period $clockPeriod"
        echo "    $msg"
        close $csv
        exit 1
    }
    current_design $blockName

    ##  link returns 1 on success.  With LINK-14 unsuppressed an unresolved
    ##  reference shows up here instead of silently becoming a black box.
    if {![link]} {
        echo "*** LINK FAILED at period $clockPeriod -- unresolved references"
        close $csv
        exit 1
    }

    ##  check_design once, on the first pass: floating nets, unconnected
    ##  ports, multiple drivers.  Same every period, so no need to repeat it.
    if {$clockPeriod == [lindex $periods 0]} {
        redirect $reports_dir/check_design.rpt { check_design }
    }

    ##-------------------------------------------------------------------------
    ##  DESIGN ENVIRONMENT
    ##-------------------------------------------------------------------------
    set_wire_load_model -name 5K_hvratio_1_4 -library NangateOpenCellLibrary

    ##-------------------------------------------------------------------------
    ##  CONSTRAINTS
    ##  dlx.sdc uses $clockPeriod, which is set by this loop, so the same file
    ##  gives a different constraint every time.
    ##-------------------------------------------------------------------------
    source ./dlx.sdc

    ##  DRAM_DATA is a bidirectional port and several outputs are driven from
    ##  shared nets.  Without this DC can leave two ports on one net, which
    ##  write -format verilog then emits as an assign the simulator dislikes.
    set_fix_multiple_port_nets -all -buffer_constants

    ##-------------------------------------------------------------------------
    ##  COMPILE
    ##
    ##  No "ungroup -all -flatten" here.  That line belongs to the boothmul
    ##  script, where flattening lets DC restructure the partial-product adder
    ##  chain across the encoder/mux boundary.  On a full CPU it would flatten
    ##  the register file, the BTB, the control path and the Dadda tree into
    ##  one design before compile: runtime and memory explode, report_reference
    ##  becomes meaningless, and compile_ultra already auto-ungroups whatever
    ##  is worth ungrouping.
    ##
    ##  -gate_clock is worth a lot here (every pipeline register and every
    ##  data_reg is enable-driven), but Nangate 45nm has no integrated clock
    ##  gating cell, so it can fail depending on the DC version.  Fall back.
    ##-------------------------------------------------------------------------
    if {[catch {compile_ultra -gate_clock} msg]} {
        echo "NOTE: compile_ultra -gate_clock failed, retrying without it"
        echo "      $msg"
        compile_ultra
    }

    ## final refinements
    if {[catch {compile_ultra -incremental} msg2]} {
        echo "NOTE: incremental pass skipped: $msg2"
    }

    ##-------------------------------------------------------------------------
    ##  SAVE
    ##-------------------------------------------------------------------------
    change_names -rules verilog -hierarchy

    write -format verilog -hierarchy -output $netlist_dir/${blockName}_${tag}.v
    write_sdc $netlist_dir/${blockName}_${tag}.sdc
    write_sdf $netlist_dir/${blockName}_${tag}.sdf

    ##-------------------------------------------------------------------------
    ##  REPORTS
    ##-------------------------------------------------------------------------
    redirect $reports_dir/timing_${tag}.rpt      { report_timing -max_paths 10 -nworst 2 -significant_digits 4 }
    redirect $reports_dir/constraint_${tag}.rpt  { report_constraint -all_violators -verbose }
    redirect $reports_dir/area_${tag}.rpt        { report_area -nosplit }
    redirect $reports_dir/qor_${tag}.rpt         { report_qor }
    redirect $reports_dir/reference_${tag}.rpt   { report_reference -nosplit }
    redirect $reports_dir/power_${tag}.rpt       { report_power -nosplit }
    redirect $reports_dir/clock_gating_${tag}.rpt { report_clock_gating }
    redirect $reports_dir/timing_reg2reg_${tag}.rpt \
    { report_timing -group REG2REG -max_paths 10 -nworst 2 -significant_digits 4 }

    ##-------------------------------------------------------------------------
    ##  ONE ROW OF THE PARETO CURVE
    ##-------------------------------------------------------------------------
    set slack    [get_worst_slack]
    set achieved [expr {$clockPeriod - $slack}]
    set met      [expr {$slack >= 0 ? 1 : 0}]
    set area     [get_total_area]
    set pwr      [get_power]
    set dyn      [lindex $pwr 0]
    set leak     [lindex $pwr 1]

    puts $csv [format "%s,%g,%.4f,%.4f,%d,%.2f,%.6e,%.6e" \
                   $tag $clockPeriod $achieved $slack $met $area $dyn $leak]
    flush $csv

    if {$met} {
        echo "  period $clockPeriod ns MET   slack [format %.4f $slack] ns   area [format %.2f $area] um2"
    } else {
        echo "  period $clockPeriod ns VIOLATED  slack [format %.4f $slack] ns  (achieved [format %.4f $achieved] ns)"
    }

    ##  CLEAN FOR THE NEXT PERIOD.  The analysed units stay in ./work, so the
    ##  next iteration re-elaborates without re-analysing.
    remove_design -all
}

close $csv

echo "==========================================="
echo "  synthesis sweep finished"
echo "  netlists and sdf files are in $netlist_dir"
echo "  reports are in $reports_dir"
echo "  pareto data is in $reports_dir/results.csv"
echo "==========================================="

exit
