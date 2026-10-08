# Comparison methodology

## Synthesis matrix

Eight RTL snapshots, V0 through V7, were synthesized with Synopsys Design
Compiler against the Nangate OpenCell 45 nm library. Every version has two
script arms:

- `old`: plain synthesis flow;
- `new`: REG2REG path weighting, critical range and incremental optimization.

Each version/script combination contains the same 21 requested clock
constraints. The matched comparison band is 1.00–1.60 ns in 0.05 ns steps;
the relaxed points extend the Pareto plots and the 500 MHz power comparison.
The [revision record](revisions.md) names the first path of the previous
version's 1.0 ns `new`-script report and counts first-path endpoints over all
21 `new`-script runs. Version rankings and PPA plots also use `new`; the
script comparison pairs `new` with `old`.

## Extracted metrics

For requested period `T`, achieved period is reconstructed from the worst
reported timing-group slack:

```text
achieved period = T - minimum reported group slack
```

This is the period at which that netlist meets timing, whether or not it met
the requested `T`. Every netlist is therefore described by its achieved
period, and its area and power belong to that period.

Cell area is read from `report_qor`. The extraction script validates both values
against the archived `results.csv` files.

Workload power comes from switching-activity-annotated, pre-layout Design
Compiler analysis. Each total-power value is paired with `sim_period_ns`, the
clock period used for its activity simulation. The run-level CSV also retains
the derived `total_mW × sim_period_ns` energy-per-cycle columns and, since
each activity window covers exactly one run of the program, the energy per
run, `total_mW × sim_period_ns × window_cycles`. These are
pre-layout estimates for the archived workloads, not measured silicon power;
the [power evidence notes](../evidence/power/methodology/README.md) describe
how the activity is produced.

Cycle counts run from the end of reset to the cycle at which fetch enters the
program's final `j`-to-itself loop. A passive monitor in the testbench records
them; it does not change the processor.
[`../data/cycle_counts.csv`](../data/cycle_counts.csv) joins the RTL counts of
every version.

## Comparisons

- Timing ranks and pairwise counts use identical requested constraints.
- Adjacent revision deltas use `later − earlier` at each matched constraint.
  With 13 pairs, a split of 9/13 or less is consistent with chance
  (two-sided sign test p ≈ 0.27); 11/13 or more (p ≈ 0.02) is reported as a
  consistent effect.
- Power is compared at one simulation period (500 MHz), or as energy per
  run when periods differ. Energy × time multiplies energy per run by the
  program's run time, `cycles × achieved period`.
- A version's fastest netlist is reported with that netlist's own area and
  power, never with values from other netlists.
- Area Pareto points use achieved period and cell area.
- Power Pareto points use SAIF simulation period and total power.
- Pareto plots use all tuned-script versions and all 21 constraints.
- Matched-speed area tables select observed points without interpolation.

`pareto_points.csv` records the version, synthesis constraint and frontier
membership for every plotted point.

## Rebuilding

The rebuild commands are in the [main README](../README.md#repository-map).
`extract_results.py`, `summarize.py` and `check_verification.py` use only the
Python standard library; `plot_results.py` needs the package in
`requirements.txt`.
