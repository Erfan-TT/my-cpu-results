##=============================================================================
##  Constraints for the DLX CPU, Nangate 45nm.
##
##  Sourced by synthesis.tcl inside the foreach loop, once for every period of
##  the sweep.  The variable clockPeriod comes from that loop, so this same
##  file gives a different constraint every time.
##
##  DLX port list (from DLX.vhd):
##    in    : CLK, RST, IRAM_READY, IRAM_DATA[31:0], DRAM_READY
##    out   : IRAM_ADDRESS[31:0], IRAM_ISSUE,
##            DRAM_ADDRESS[31:0], DRAM_ISSUE, DRAM_READNOTWRITE
##    inout : DRAM_DATA[31:0]
##=============================================================================

##-----------------------------------------------------------------------------
##  CLOCK
##-----------------------------------------------------------------------------
create_clock -name CLK -period $clockPeriod [get_ports CLK]

set_clock_uncertainty 0.05 [get_clocks CLK]
set_clock_transition  0.05 [get_clocks CLK]
set_clock_latency     0.05 [get_clocks CLK]

##  Before place and route the clock and the reset are ideal: we do not want
##  the tool to buffer them or to try to fix their timing.
##  RST is a synchronous reset (it is sampled inside rising_edge(clk) in
##  data_reg and everywhere else), so it is NOT false-pathed -- it is only
##  taken out of the I/O budget below.
set_dont_touch_network [get_ports CLK]
set_ideal_network      [get_ports CLK]
set_dont_touch_network [get_ports RST]
set_ideal_network      [get_ports RST]

##-----------------------------------------------------------------------------
##  PORT GROUPS
##
##  all_inputs includes the inout DRAM_DATA, and so does all_outputs -- that is
##  what we want for the delays, DRAM_DATA is timed in both directions.
##
##  CLK and RST are both removed from the driven set.  The original file
##  removed only CLK, which left RST declared ideal and dont_touch while also
##  receiving a driving cell and an input delay: two contradictory statements
##  about the same port.
##-----------------------------------------------------------------------------
set clk_port    [get_ports CLK]
set rst_port    [get_ports RST]

set data_inputs [remove_from_collection \
                    [remove_from_collection [all_inputs] $clk_port] \
                    $rst_port]

##-----------------------------------------------------------------------------
##  DRIVE AND LOAD
##-----------------------------------------------------------------------------
set_driving_cell -lib_cell BUF_X4 -pin Z $data_inputs
set_load 0.05 [all_outputs]

##-----------------------------------------------------------------------------
##  I/O DELAYS
##
##  set_input_delay / set_output_delay model time spent OUTSIDE this block.
##  Here there is no outside: TB_romem and TB_rwmem are behavioral VHDL with no
##  timing spec, so any number is a modeling assumption rather than a measured
##  one.  The question is therefore not "which value is correct" but "which
##  value is safe", and the answer is: small.
##
##  Almost every top-level path is register-to-port or port-to-register with
##  little logic in between.  IRAM_ADDRESS, DRAM_ADDRESS, DRAM_ISSUE and
##  DRAM_READNOTWRITE come straight off pipeline registers; IRAM_DATA and the
##  read side of DRAM_DATA go into registers.  Only IRAM_READY / DRAM_READY
##  reach real combinational logic (the stall and hazard path).  The critical
##  path of this design is internal: Dadda tree, ALU, forwarding muxes.
##
##  So a budget that is too small merely leaves the interface paths loose, and
##  the internal path still sets the frequency -- no harm done.  A budget that
##  is too large makes the interface artificially critical and DC starts
##  spending area fixing a path that does not exist in the real system, which
##  bends the Pareto curve around an invented number.
##
##  10% each way is about an SRAM's clock-to-Q on the input side and its setup
##  on the output side at these periods, and is small enough that it cannot
##  hijack the result.  Fractions of the period rather than fixed nanoseconds,
##  so the budget stays proportional across the whole sweep.
##
##  Whether this guess matters at all is answered by the path groups below:
##  check the per-group critical path in report_qor after the first run.
##-----------------------------------------------------------------------------
set_input_delay  [expr {0.10 * $clockPeriod}] -clock CLK $data_inputs
set_output_delay [expr {0.10 * $clockPeriod}] -clock CLK [all_outputs]

#### just to run the below 1 ns clks for evidence that they suck
# set_input_delay  0.1 -clock CLK $data_inputs
# set_output_delay 0.1 -clock CLK [all_outputs]

##-----------------------------------------------------------------------------
##  PATH GROUPS
##
##  Constrain the three kinds of path separately so report_qor prints a
##  critical path per group.  This is what tells you whether the I/O delays
##  above are load-bearing:
##
##    - if INPUTS and OUTPUTS sit comfortably below REG2REG, the assumption is
##      irrelevant and the internal logic is setting the frequency, which is
##      the expected outcome for this design
##    - if either of them is the worst group, the invented number is driving
##      the result and is worth revisiting
##
##  Grouping also helps compile_ultra: it optimises the worst path of every
##  group rather than pouring all its effort into one global critical path.
##-----------------------------------------------------------------------------
## critical range sets the limit of the paths to be taken into account for optimization and also reporting.
## here for example, any path within the 0.25*clk of the worst in this group, be taken into account, so the DC would also optimises those paths as well
## the weight is to give this group more priority than the others (they are the default 1 weight)
## its good because currently the reg2reg is the critical path
group_path -name REG2REG -from [all_registers] -to [all_registers] -critical_range [expr {0.25 * $clockPeriod}] -weight 5.0
#group_path -name REG2REG -from [all_registers] -to [all_registers]
group_path -name INPUTS  -from [all_inputs]
group_path -name OUTPUTS -to   [all_outputs]

##-----------------------------------------------------------------------------
##  DESIGN RULES
##-----------------------------------------------------------------------------
set_max_transition 0.20 [current_design]

## the 45 ns nandgate library has default_fanout_load equal to 1.0, so the max fanout setting would optimize 
## the forwarding select signals were passed to many muxes, need to set the fanout max here so DC optimize those loads
#set_max_fanout 12 [current_design]

##  Minimum-area target: keeps DC shrinking area once timing is met, which is
##  what puts each period on the lower edge of the Pareto curve.  This is
##  affordable now that the design is no longer flattened before compile.
set_max_area 0
