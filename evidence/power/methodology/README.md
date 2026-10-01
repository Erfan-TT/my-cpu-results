# Post-synthesis simulation and back-annotated power

Two things happen here, in this order and never the other way round:

1. **Functional verification of the netlist.** Every corner's netlist runs the
   whole 22-test suite with its SDF annotated. This proves the gates do what the
   RTL did.
2. **Power.** Two workloads are re-run with a SAIF attached, and Design Compiler
   reads those SAIFs back to replace its statistical power guess with measured
   switching.

Phase 2 comes second on purpose: a netlist that fails its regression still
produces a perfectly well-formed SAIF, and a power number taken from a broken
simulation looks exactly like a good one.

## Layout

```
post_synthesis_sim/
├── NangateOpenCellLibrary.v     the standard cell models
├── scripts/
│   ├── compile_gate.do          build ../work_gate: cells + TB + memories, NO RTL
│   ├── sim_gate.do              one netlist x one test
│   ├── run_gate_tests.tcl       the driver: every corner, every test, then the SAIFs
│   ├── power_dc.tcl             DC: read each SAIF, report_power
│   └── merge_results.py         join everything into final_results.csv + .txt
├── work_gate/                   gate-level ModelSim library (created)
├── saif_reports/                <tag>__<workload>.saif
├── logs/
└── results/
    ├── gate_results.csv         per corner, per test: PASS / FAIL / SKIP
    ├── saif_manifest.csv        which SAIF belongs to which corner and period
    ├── power_results.csv        back-annotated dynamic / leakage / coverage
    ├── power_<tag>_<workload>.rpt
    ├── saif_<tag>_<workload>.rpt
    ├── final_results.csv        one row per corner -- the file to plot
    └── final_report.txt         the same, for reading
```

## How to run it

```bash
# 1. the gate-level regression + the SAIFs   (from syn/post_synthesis_sim/scripts)
vsim -c -do run_gate_tests.tcl | tee ../logs/gate.log

# without the SDF, append to the rest : 
vsim -c -do "set no_sdf 1; set saif_sdf 0; source run_gate_tests.tcl; quit -f;" | tee -a ../logs/gate.log

# skipping tests and going from after having the saif files
vsim -c -do "set saif_only 1; set recompile 0; set saif_sdf 0; source run_gate_tests.tcl; quit -f;" | tee -a ../logs/gate.log

# 2. back-annotated power                    (from syn/, so .synopsys_dc.setup is found)
dc_shell -f post_synthesis_sim/scripts/power_dc.tcl | tee post_synthesis_sim/logs/power_dc.log

# 3. join it all up                          (from syn/)
python3 post_synthesis_sim/scripts/merge_results.py
```

Useful knobs on step 1:

```bash
vsim -c -do "set only 1p0;    source run_gate_tests.tcl; quit -f"   # one corner
vsim -c -do "set only_test 08; source run_gate_tests.tcl; quit -f"  # one test
vsim -c -do "set recompile 0; source run_gate_tests.tcl; quit -f"   # reuse work_gate
vsim -c -do "set no_sdf 1;    source run_gate_tests.tcl; quit -f"   # zero-delay
vsim -c -do "set skip_power 1; source run_gate_tests.tcl; quit -f"  # regression only
```

## The three decisions the scripts encode

**Each netlist is simulated at its own achieved period**, `T_constraint - WNS`,
rounded up to the next **10 ps** (`grain_ps`). That is the fastest clock the netlist actually sustains:
slower than the constraint for a corner that missed it, faster for one that met
it. One rule covers both, and no setup check ever fires, so nothing goes X for a
timing reason. The SDF delays are absolute picoseconds fixed at synthesis, so
driving a netlist at a period other than its constraint is perfectly legitimate.

**Keep `grain_ps` fine.** A coarse grid looks like cheap safety and is not:

- It buys no margin that is not already there. For a reg-to-reg path with an
  ideal clock, `slack = T - uncertainty - Tsetup - Tcq - Tlogic`, so
  `achieved = Tcq + Tlogic + Tsetup + uncertainty`. The simulator does **not**
  apply clock uncertainty -- it uses real delays -- so the check it performs is
  `Tcq + Tlogic + Tsetup <= Tsim`, and simulating at `achieved` already leaves
  the whole 0.05 ns of `set_clock_uncertainty` as slack.
- It cannot cover the thing that actually threatens this simulation. `dlx.sdc`
  sets `set_clock_latency 0.05` and never `set_propagated_clock`, so DC gave
  every flop the same clock arrival, while the SDF carries the real clock-gate
  cell delays -- 203 ps to some flops, 466 ps to others. That ~263 ps of skew is
  far beyond any sensible grid, and it lands on **hold**, which no period margin
  fixes.
- It distorts the one curve this flow exists to produce. `sim_period_ns` is the
  frequency the SAIF power is measured at and dynamic power goes as 1/T, so on a
  50 ps grid the four corners come out understated by 0.3 % to 3.0 % depending
  on where `achieved_ns` falls between grid points. On a 10 ps grid the spread
  is 0.5 points. The bias would be harmless; the per-corner *spread* is noise in
  the power-vs-period plot.

**Physical-design margin belongs in `set_clock_uncertainty` in `dlx.sdc`, not in
this period.** It is already there at 0.05 ns, and because neither `-setup` nor
`-hold` is given it applies to both checks. What is *not* modelled is the clock
tree, which does not exist yet -- see the note on hold violations below.

**The runtimes are scaled.** `run` takes an absolute time and the runtimes in
`testlist.tcl` were written for the old 20 ns testbench clock, so every one is
multiplied by `sim_period / 20 ns`. Miss this and the program stops half way, the
compare fails for the wrong reason, and the SAIF describes a partial workload.
(Validated: all 22 tests still pass at a 1.45 ns clock with scaled runtimes.)

**The first 10 cycles are a quiet window.** Reset lasts 2 cycles and the X in
the netlist's non-reset flops takes a couple more to wash out; while it does,
every `to_integer()` in the memory models reports a metavalue. Those two message
classes are muted for the window and turned back on afterwards, so the
transcript stays readable. The total simulated time is unchanged -- the quiet
window is subtracted from the main run, not added to it. **Timing checks are
never muted**: a setup violation that repeats *after* the startup window is a
real finding and has to stay visible.

**The SAIF window excludes reset.** `power reset` is called after 20 cycles, so
the recorded activity is the steady-state workload rather than the power-up
burst, which happens once and is not representative.

## Two workloads, on purpose

`20_power_bench` is the designed switching-activity benchmark. `08_multiplier`
is a deliberately different profile — it keeps the Booth/Dadda tree busy and the
memory quiet. Reporting both lets the write-up say how much the power figure
moves with the program, instead of quoting one number as if it were a property
of the silicon.

## Timing-check violations in a pre-layout netlist

`run_gate_tests.tcl` passes `+no_notifier` by default. This is deliberate and it
is the right default here, not a way of hiding a problem.

Nangate's flops carry `$setuphold(posedge CK, ..., NOTIFIER)` and a UDP whose
state node goes **X the instant the notifier toggles**. So one timing-check
violation does not just print a line -- it corrupts the flop, and the X spreads
until the simulation produces nothing.

**Hold violations here are an artefact of running pre-layout.** This netlist has
no clock tree. Synthesis analysed hold against an *ideal* clock -- zero skew,
zero insertion delay -- and correctly reported zero hold violations for that
model. The SDF, though, carries the real cell delay of every
`SNPS_CLOCK_GATE_*`. Both `DP_i_fetch_i_npc_i_Y_reg_*` and the register-file
flops are clocked from an `ENCLK` output, so in simulation their clock arrives
later than their ungated source's, and a short data path "violates hold".
Balancing that is a clock-tree-synthesis job at place-and-route, not something
to chase now.

**Setup violations are meaningful** and stay visible in the transcript with
`+no_notifier` on; they just no longer destroy the run. If setup violations
appear at a corner's achieved period, that *is* a result worth chasing.

Set `notifier 1` to restore the default Verilog behaviour.

**How to tell a real setup violation from startup noise:** a violation on a
critical path repeats, every cycle, for the whole run. One occurrence in the
first few cycles -- inside the X-flush window, with silence afterwards -- is
startup. Check the timestamp against the clock: at half = 705 ps the rising
edges are at 705, 2115, 3525, 4935 ... ps plus 200-500 ps of clock-net
insertion delay, so an error at 5401 ps is clock cycle 4.

## SDF: when it earns its keep, and when it does not

Each phase has its own switch: `no_sdf` for the functional regression,
`saif_sdf` for the power workloads. **Pre-layout, run both zero-delay**
(`no_sdf 1`, `saif_sdf 0`, which is the default).

**Functional verification does not need SDF.** The question is "is this netlist
logically the RTL", and zero-delay answers it. Timing is signed off by static
analysis, which covers *every* path exhaustively; a simulation only reaches the
paths the stimulus happens to hit, so it is a weak timing check even annotated.

**Pre-layout, SDF does not make the power number better either.** Annotating adds
glitch activity, and glitches are real power -- but pre-layout the delays come
from the **wire load model**, a statistical guess by fanout that knows nothing
about placement. Glitch generation depends on the *relative* arrival times of the
inputs to a gate, which is precisely what a wire load model gets wrong. So an
annotated pre-layout SAIF is not obviously closer to the truth, only noisier. On
this netlist it is worse than that: the un-balanced clock gates produce enough
setup and hold violations to make the run unusable.

So the pre-layout power number is a **lower bound: measured switching activity,
glitch power excluded**. State it that way. Two things make it worth having:

- it replaces DC's default statistical estimate (uniform toggle rates) with
  activity measured from the real workload, which is the big step;
- every version is measured the *same* way, so the systematic offset cancels in
  the comparison. The ranking between RTL versions -- which is what the
  optimisation story is about -- is unaffected by the missing glitches.

**Post-layout is where SDF becomes a sign-off check**: the SDF then carries the
real clock tree, so hold checks finally mean something, and extracted RC, so both
the delays and the glitches are the ones the silicon has. That is the run that
produces the final switching activity.

Because a SAIF from a run that computed the wrong answer looks exactly like one
from a run that did not, the SAIF workloads are **compared against the golden
model** as well, and a mismatch drops the SAIF instead of feeding it to DC.

## Reading the transcript

`run_gate_tests.tcl` uses `echo`, not `puts`. In ModelSim only `echo` reaches the
`transcript` file -- `puts` goes to stdout, so with `puts` the progress and the
PASS/FAIL verdicts appear on the terminal and are missing from the file you
later go back to read.

Three message classes are dealt with up front so the transcript says something:

| message | what it is | handling |
|---|---|---|
| `vopt-2685` / `vopt-2718` TFMPC, "Missing connection for port 'QN'" | DC leaves `QN` unwired on every flop that does not use it. One pair per flop, ~4460 before simulation even starts. | `-suppress 2685,2718` |
| `NUMERIC_STD.TO_INTEGER: metavalue detected` | the netlist's non-reset flops washing out during the first cycles | muted for the startup window only |
| `vsim-8756`, negative timing check limits without delayed copies | the library was compiled without `+define+NTC` | `+define+NTC` (below) |

With those three handled, an error in the transcript is worth reading.

## Negative timing checks: compile the library with +define+NTC

`compile_gate.do` passes `+define+NTC` to `vlog`. The Nangate models carry two
versions of every timing check:

```verilog
`ifdef NTC
  $setuphold(posedge CK, negedge D, 0.1, 0.1, NOTIFIER, , ,CK_d, D_d);
`else
  $setuphold(posedge CK, negedge D, 0.1, 0.1, NOTIFIER);
`endif
```

The `NTC` form carries delayed copies of the data and reference signals, which
is what a simulator needs to represent a **negative** setup or hold limit. The
SDF of a clock-gated design contains those, and without the delayed copies vsim
says so itself at time 0:

```
(vsim-8756) Instance '...clk_gate_IR_out_reg.latch' - Negative timing check
limits detected in simulation with cells modeled without delayed copies of
data or reference signals.
```

A simulator that cannot represent a negative limit reports violations that are
not there. Set `ntc 0` to go back to the plain models; if `+define+NTC` itself
misbehaves, `vsim +no_neg_tchk` is the cruder alternative -- it clamps negative
limits to zero instead of modelling them.

## Things that will bite if they are changed

- **`DLX.vhd` must never be compiled into `work_gate`.** `TB_DLX` binds `DLX`
  through a component declaration; if the VHDL entity is in the library it wins,
  and you are silently simulating the RTL again. `compile_gate.do` leaves out
  every design file for exactly this reason.
- **`-voptargs=+acc` is required.** Without it `power add -r` cannot see the
  internal nets and the SAIF comes back nearly empty.
- **The register file has no reset**, so its flops come up X in the netlist. All
  22 test programs were checked against the golden model with three different
  power-up register patterns and none of them changes a single stored word, so
  this should not matter architecturally. It does matter to the *simulator*: X
  on a flop's D makes it toggle at arbitrary times, which trips `$setuphold`.
  `sim_gate.do` therefore seeds them to zero at time 0 (`init_rf`, on by
  default). The deposit lands on `IQ`, the UDP state node -- `Q` is driven by
  `buf(Q, IQ)` and a force there is overwritten at once.
- **Check the clock before believing anything.** `TB_DLX` reports its period at
  time 0; grep the transcript for `TB_DLX: clock period =`. If it says 20000 ps
  the `-gCLK_HALF_PERIOD_PS` override did not reach the testbench -- almost
  always a stale `TB_DLX.vhd` compiled into `work_gate` -- and every runtime in
  the run is then ~12x too short for the clock actually being used.
- **SAIF coverage below ~90 %** means a real part of the power number is DC's own
  estimate rather than measured switching. `power_dc.tcl` prints a warning and
  records the percentage as a column; say so in the report if it is low.
