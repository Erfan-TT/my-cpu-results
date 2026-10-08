# Workload-annotated power evidence

The power numbers are Design Compiler estimates for the synthesized Nangate
45 nm netlists. Gate-level simulation of three assembly programs supplies the
switching activity (SAIF), and Design Compiler reads it back to report dynamic
power and leakage. They are pre-layout estimates: placed wiring, a clock tree
and extracted parasitics are not yet included.

## Workloads and activity window

| Workload | Cycles | What it exercises |
|---|---:|---|
| `20_power_bench` | 2,819 | every block: ALU, shifter, multiplier, loads/stores, branches, BTB, exceptions |
| `24_mac_loops` | 4,283 | multiply-accumulate loops: dot products, a FIR filter, Horner polynomials |
| `08_multiplier` | 79 | multiplier corner operands; short, so its window is noisy |

Each program ends in a `j` to itself. A passive monitor in the testbench
records the cycle at which fetch enters that loop, and the activity window
runs from the end of reset to 8 cycles after it, so the activity is one run of
the program and not the idle loop that follows. Every version runs each
program in the same number of cycles, so power × window is the energy of the
same work on every version.

Each netlist is simulated at its own achieved period, rounded up to 10 ps;
the 2.0 ns netlists of all eight versions are therefore all simulated at
500 MHz, which is the equal-frequency comparison. Values at different
simulation periods should not be compared as if they were measured at one
frequency.

## What is archived

- [`../V0/`](../V0/) through [`../V7/`](../V7/), per synthesis point:
  `final_results.csv` (simulation period, power, SAIF coverage, cycles,
  window and energy per workload, gate-level status), `gate_results.csv`
  (per-test gate-level verdicts and cycles) and `saif_manifest.csv` (cycles
  and window length per SAIF).
- [`results/`](results/): the complete V7 run, including every Design
  Compiler power and SAIF-coverage report. The scripts that produced it are
  under [`scripts/`](scripts/); they need the withheld netlists, testbench
  and RTL to run.

## Gate-level regression and limits

All 24 programs pass at gate level for all eight versions at all 21 synthesis
points (504 passes per version). The runs are zero-delay, without SDF: they
check the netlist's logic at its achieved period, and timing is covered by
static timing analysis. SDF is also left off for the activity runs, because
the clock-gating cell `CLKGATETST_X1` carries negative hold constraints that
cause hold violations before clock-tree synthesis.

The gate-level cycle counts equal the RTL counts, except on V3–V7 for
`07_load_use`, `10_branches`, `11_btb_predictor` and `14_exceptions_full`,
which differ by one or two cycles. These archived runs seeded the register
file's zero flags to 0, while the RTL starts them at 1, so a branch on a
register that had not yet been written went the other way. Every verdict
still passes, and the three power workloads match the RTL count exactly; the
current [`scripts/sim_gate.do`](scripts/sim_gate.do) seeds the flags as the
RTL does.
