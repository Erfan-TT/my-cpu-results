# Comparison methodology

## Synthesis matrix

Eight RTL snapshots, V0 through V7, were synthesized with Synopsys Design
Compiler against the Nangate OpenCell 45 nm library. Every version has two
script arms:

- `old`: plain synthesis flow;
- `new`: REG2REG path weighting, critical range and incremental optimization.

Each version/script combination contains the same 21 requested clock
constraints. The matched comparison band is 1.00–1.60 ns in 0.05 ns steps;
the relaxed points are retained for timing closure and Pareto plots.
The [revision record](revisions.md) uses the previous version's 1.0 ns
`new`-script report for its path startpoint and endpoint. Version rankings
and PPA plots also use `new`; the script comparison pairs `new` with `old`.

## Extracted metrics

For requested period `T`, achieved period is reconstructed from the worst
reported timing-group slack:

```text
achieved period = T - minimum reported group slack
```

Cell area is read from `report_qor`. The extraction script validates both values
against the archived `results.csv` files.

Workload power comes from switching-activity-annotated, pre-layout Design
Compiler analysis. Each total-power value is paired with `sim_period_ns`, the
clock period used for its activity simulation. The run-level CSV also retains
the derived `total_mW × sim_period_ns` energy-per-cycle columns. These are
estimates for two programs, not post-layout or measured silicon power. At the
common 2.0 ns point, the archived tables show gate-regression `pass` for
all eight versions; see the
[power evidence notes](../evidence/power/methodology/README.md).

## Comparisons

- Timing ranks and pairwise counts use identical requested constraints.
- Adjacent revision deltas use `later − earlier` at each matched constraint.
- Area Pareto points use achieved period and cell area.
- Power Pareto points use SAIF simulation period and total power.
- Pareto plots use all tuned-script versions and all 21 constraints.
- Matched-speed area tables select observed points without interpolation.

`pareto_points.csv` records the version, synthesis constraint and frontier
membership for every plotted point.

## Rebuilding the published analysis

From the repository root:

```text
python scripts/extract_results.py
python scripts/summarize.py
python scripts/check_verification.py
python scripts/plot_results.py
```

The first three commands use only the Python standard library. Figure generation
requires the package in `requirements.txt`. These commands reconstruct the
published tables and figures from the included reports; the unpublished RTL and
proprietary EDA environment are required to rerun synthesis or simulation.
