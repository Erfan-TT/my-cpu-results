# Workload-annotated power evidence

The published power numbers are Design Compiler estimates for synthesized
Nangate 45 nm netlists. Gate-level simulation supplies switching activity for
two assembly workloads: `08_multiplier` and `20_power_bench`. Design Compiler
reads that activity and reports dynamic power and leakage. These are pre-layout
estimates; placed wiring, a clock tree and extracted parasitics are yet not included.

## What is archived

- [`../V0/`](../V0/) through [`../V7/`](../V7/) contain each version's
  `final_results.csv`, including simulation period, total power, activity
  coverage and gate-regression status for every synthesis point. Each also
  contains `gate_results.csv` with the individual test verdicts.
- [`results/`](results/) contains the example run's SAIF manifest, power reports
  and merged tables. Its scripts are under [`scripts/`](scripts/).
- The public comparison at a common 2.0 ns simulation period is
  [`../../../data/fixed_frequency_power.csv`](../../../data/fixed_frequency_power.csv).

The scripts reference unpublished netlists, SDF files, testbench and RTL.
They document the original flow but cannot rerun it from this repository.

## Comparing power

Every version has a 2.0 ns synthesis point that meets timing. Its two power
measurements use a 2.0 ns activity-simulation period (500 MHz), so the
equal-frequency table compares the same requested synthesis point and workload
rate. The reported SAIF annotation coverage is 100% for both workloads at those
points.

The sweep's other power measurements use the recorded `sim_period_ns`; this
period is the horizontal coordinate in the power–latency plot. Values at
different simulation periods should not be compared as if they were measured
at one frequency. The exact period and power are available per point in
[`../../../data/synthesis_runs.csv`](../../../data/synthesis_runs.csv).

## Gate-regression status and limits

The archived `final_results.csv` files record `gate_status=pass` for all eight
versions at all 21 synthesis points, with zero reported failures. V0 and
V4–V6 have 22 passes per point; V1–V3 and V7 have 21. Every point also has
one documented skip (`19_given_all_general`). The corresponding per-test
verdicts are in each version's `gate_results.csv`. These are functional
gate-level regressions, not proof of post-layout timing closure. The separate
archived RTL results are checked by
[`../../../scripts/check_verification.py`](../../../scripts/check_verification.py).

The example simulation driver provides independent switches for SDF annotation during functional tests and activity workloads. By default, `saif_sdf=0`, so activity is generated without SDF delays. The published tables use `saif_sdf=0` because the clock-gating cell `CLKGATETST_X1` contains negative hold constraints that can trigger hold violations in post-synthesis simulation, where CTS has not yet been implemented and clock arrival times are therefore not physically representative. Since all design versions are evaluated using the same setup, this systematic effect cancels out in relative comparisons.

Therefore, The figures are useful for comparing
the reported pre-layout estimates under the stated workloads and periods.
