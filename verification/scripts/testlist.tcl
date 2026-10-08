#=============================================================================
#  testlist.tcl -- the suite
#
#  Sourced by run_tests.tcl.  One entry per test, as a Tcl dict:
#
#    dir      folder under ../tests/ ; the .asm inside it gives the test name
#    words    size of BOTH memory images, i.e. the TB_DLX memory_size generic
#    runtime  how long to run the simulation -- roughly 60 ns per executed
#             instruction plus margin; a test that has not reached its end
#             self-loop by then fails the compare for the wrong reason
#    modes    which memory-model combinations to run, from:
#               ff  simple_iram + simple_dram   (zero latency, the default)
#               fs  simple_iram + rwmem         (2-cycle data handshake)
#               cf  rocache/romem + simple_dram (instruction cache)
#               cs  rocache/romem + rwmem       (both)
#    skip     1 to leave it out of a plain run (still listed in the summary)
#    expect   "pass" or "xfail:<why>" per mode, as a dict; anything not named
#             is expected to pass
#    note     one line, printed in the summary
#=============================================================================

set TESTS {
    {dir 01_alu_rtype        words 512 runtime {20 us} modes {ff}
     note {R-type arithmetic, logic, register shifts}}

    {dir 02_alu_immediate    words 512 runtime {20 us} modes {ff}
     note {I-type ALU, sign- vs zero-extended immediates, lhi}}

    {dir 03_set_compare      words 512 runtime {30 us} modes {ff}
     note {all 22 set-compares, signed against unsigned}}

    {dir 04_r0_source        words 512 runtime {10 us} modes {ff}
     note {a discarded r0 write must not forward}}

    {dir 05_r0_writeback     words 512 runtime {10 us} modes {ff}
     note {same, at the writeback / RF-bypass distance}}

    {dir 06_forwarding       words 512 runtime {20 us} modes {ff}
     note {every forwarding path, and the ones that must not forward}}

    {dir 07_load_use         words 512 runtime {20 us} modes {ff fs}
     note {load-use stall, load->store, load-driven addresses}}

    {dir 08_multiplier       words 512 runtime {30 us} modes {ff}
     note {Booth/Dadda corner operands}}

    {dir 09_mult_parallel    words 512 runtime {30 us} modes {ff}
     note {multiply overlapped, stalling, and across a call}}

    {dir 10_branches         words 512 runtime {40 us} modes {ff}
     note {every branch and jump, both outcomes}}

    {dir 11_btb_predictor    words 512 runtime {60 us} modes {ff cf}
     expect {cf {xfail: redirect during an I-cache refill, see README}}
     note {BTB rows, aliasing, mispredict recovery, changing jr target}}

    {dir 12_memory_access    words 512 runtime {20 us} modes {ff fs}
     note {word/half/byte access and big-endian lane order}}

    {dir 13_exceptions_min   words 512 runtime {40 us} modes {ff}
     note {one hit per exception cause}}

    {dir 14_exceptions_full  words 512 runtime {60 us} modes {ff}
     note {full exception walk with handler dumps}}

    {dir 15_smoke_crosscheck words 512 runtime {10 us} modes {ff fs cf cs}
     note {short mixed program; the memory-model matrix runs here}}

    {dir 16_jal_return       words 512 runtime {10 us} modes {ff cf}
     expect {cf {xfail: redirect during an I-cache refill, see README}}
     note {jal link and jr return}}

    {dir 17_given_branch_loop words 512 runtime {80 us} modes {ff fs}
     note {provided example: 100-iteration loop, 100 loads and 100 stores}}

    {dir 18_given_mult_shift words 512 runtime {10 us} modes {ff}
     note {provided example: shift loop with bnez}}

    {dir 19_given_all_general words 512 runtime {10 us} modes {ff}
     note {provided example, made runnable: aligned loads, stores, final self-loop}}

    {dir 20_power_bench      words 512 runtime {300 us} modes {ff}
     note {switching-activity workload; run this one with a VCD}}

    {dir 21_store_subword    words 512 runtime {30 us} modes {ff fs}
     note {sb and sh: lane placement, read-modify-write, alignment}}

    {dir 22_branch_operand_hazard words 512 runtime {20 us} modes {ff}
     note {jr/jalr target and branch condition at every operand distance}}

    {dir 23_misaligned_jump_repeat words 512 runtime {20 us} modes {ff}
     note {a misaligned jr executed three times; the same exception every time}}

    {dir 24_mac_loops        words 512 runtime {120 us} modes {ff}
     note {multiply-accumulate loops; a multiplier-heavy SAIF workload}}
}
