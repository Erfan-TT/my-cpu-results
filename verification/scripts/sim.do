#=============================================================================
#  sim.do -- run ONE test in ONE memory-model mode
#
#  run_tests.tcl sets these before sourcing it; the defaults below only exist
#  so the file can be sourced by hand from verification/scripts:
#
#    t_dir         folder under ../tests/          e.g. 01_alu_rtype
#    t_name        base name of the .asm in it     e.g. alu_rtype
#    words         TB_DLX memory_size generic
#    runtime       argument to "run"
#    use_icache    true -> rocache + romem, false -> simple_iram
#    use_slow_dram true -> rwmem (2-cycle), false -> simple_dram
#    out_suffix    appended to the dump name, "" for the default mode
#    vcd_file      path for a VCD, or "" for none
#    stop_at_end   1 to stop as soon as the program has finished instead of
#                  running the whole runtime (default 0)
#
#  After the run, t_cycles holds the cycle count from reset to the program's
#  final self-loop, or "" if the program never reached one (see TB_DLX's
#  end-of-program monitor).
#
#  The TB generics are plain file names that ModelSim resolves against vsim's
#  CURRENT WORKING DIRECTORY, which is verification/scripts -- hence ../tests/.
#=============================================================================

if {![info exists t_dir]}         { set t_dir   01_alu_rtype }
if {![info exists t_name]}        { set t_name  alu_rtype }
if {![info exists words]}         { set words   512 }
if {![info exists runtime]}       { set runtime {20 us} }
if {![info exists use_icache]}    { set use_icache    false }
if {![info exists use_slow_dram]} { set use_slow_dram false }
if {![info exists out_suffix]}    { set out_suffix "" }
if {![info exists vcd_file]}      { set vcd_file "" }
if {![info exists stop_at_end]}   { set stop_at_end 0 }

set t_base  ../tests/$t_dir/$t_name
set imem      ${t_base}_imem.txt
set dmem_init ${t_base}_dmem_init.txt
set dmem_rtl  ${t_base}_dmem_rtl${out_suffix}.txt

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
set end_pc [find_end_pc $imem]

#  -t ps: the testbench clock is a generic in picoseconds, and ModelSim
#  defaults to a 1 ns resolution, at which a "ps" literal rounds to zero.
vsim -quiet -t ps \
     -gUSE_ICACHE=$use_icache \
     -gUSE_SLOW_DRAM=$use_slow_dram \
     -gmemory_size=$words \
     -gIRAM_FILE=$imem \
     -gDRAM_FILE_INIT=$dmem_init \
     -gDRAM_FILE_OUT=$dmem_rtl \
     -gEND_PC=$end_pc \
     -voptargs=+acc work.TB_DLX

if {$vcd_file ne ""} {
    # only the DUT: the memory models are testbench-side and would dominate
    # both the file size and any switching-activity number taken from it
    vcd file $vcd_file
    vcd add -r /tb_dlx/dlx_i/*
}

if {$stop_at_end && $end_pc >= 0} {
    #  "resume" makes the do-file carry on after the run that the stop ended,
    #  instead of waiting at a prompt.
    onbreak {resume}
    when -label prog_end {/tb_dlx/prog_done == '1'} { stop }
    run $runtime
    nowhen prog_end
} else {
    run $runtime
}

set t_cycles [examine -radix decimal /tb_dlx/prog_end_cycle]
if {$t_cycles < 0} {
    set t_cycles ""
    echo "  cycles: program did not reach its final self-loop"
} else {
    echo "  cycles: $t_cycles from reset to the final self-loop"
}

if {$vcd_file ne ""} { vcd flush }
quit -sim
