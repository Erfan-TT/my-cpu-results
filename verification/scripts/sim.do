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

set t_base  ../tests/$t_dir/$t_name
set imem      ${t_base}_imem.txt
set dmem_init ${t_base}_dmem_init.txt
set dmem_rtl  ${t_base}_dmem_rtl${out_suffix}.txt

#  -t ps: the testbench clock is a generic in picoseconds, and ModelSim
#  defaults to a 1 ns resolution, at which a "ps" literal rounds to zero.
vsim -quiet -t ps \
     -gUSE_ICACHE=$use_icache \
     -gUSE_SLOW_DRAM=$use_slow_dram \
     -gmemory_size=$words \
     -gIRAM_FILE=$imem \
     -gDRAM_FILE_INIT=$dmem_init \
     -gDRAM_FILE_OUT=$dmem_rtl \
     -voptargs=+acc work.TB_DLX

if {$vcd_file ne ""} {
    # only the DUT: the memory models are testbench-side and would dominate
    # both the file size and any switching-activity number taken from it
    vcd file $vcd_file
    vcd add -r /tb_dlx/dlx_i/*
}

run $runtime

if {$vcd_file ne ""} { vcd flush }
quit -sim
