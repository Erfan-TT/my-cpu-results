# Full synthesis comparison

This section contains the complete synthesis analysis of V0 through V7 and the
two synthesis scripts.

## Experiment inventory

| Item | Value |
|---|---|
| RTL snapshots | V0–V7 |
| Synthesis scripts | plain (`old`) and tuned (`new`) |
| Constraints per version/script | 21 |
| Total runs | 336 |
| Tight comparison band | 1.00–1.60 ns in 0.05 ns steps (13 points) |
| Tool | Synopsys Design Compiler W-2024.09-SP2 |
| Library/corner | Nangate OpenCell 45 nm, typical |

Achieved period is reconstructed as requested period minus the worst timing
group slack. Area is parsed from `report_qor`. Each derived row records its
source report in [`../data/synthesis_runs.csv`](../data/synthesis_runs.csv).

## Version overview

The median, leader counts and pairwise comparisons summarize the constraint
sweep from complementary views. The power column uses the common 500 MHz point.

| Version | First sampled closure | Median achieved period | Best observed period | Median area | First-place count | Rank range | Power at 500 MHz: multiplier / mixed |
|---|---:|---:|---:|---:|---:|---:|---:|
| V0 | 2.0 ns | 1.7730 ns | 1.6910 ns | 26,826 µm² | 0/13 | 8–8 | **4.065** / 4.394 mW |
| V1 | 1.7 ns | 1.6178 ns | 1.4997 ns | 26,662 µm² | 1/13 | 1–7 | 4.082 / **4.388** mW |
| V2 | 1.6 ns | 1.5997 ns | 1.4723 ns | 26,965 µm² | 3/13 | 1–7 | 4.083 / 4.403 mW |
| V3 | 1.7 ns | 1.5846 ns | 1.4154 ns | 26,680 µm² | 1/13 | 1–6 | 4.117 / 4.444 mW |
| V4 | 1.7 ns | 1.5726 ns | 1.4456 ns | 26,899 µm² | 1/13 | 1–7 | 4.399 / 4.696 mW |
| V5 | 1.7 ns | 1.5787 ns | 1.4569 ns | 26,797 µm² | 2/13 | 1–7 | 4.395 / 4.705 mW |
| V6 | 1.6 ns | 1.5717 ns | **1.4096 ns** | 26,722 µm² | **4/13** | 1–6 | 4.374 / 4.684 mW |
| V7 | 1.7 ns | 1.5648 ns | 1.5024 ns | 26,724 µm² | 1/13 | 1–6 | 4.084 / 4.411 mW |

![Achieved period at every constraint](figures/01_achieved_period_by_constraint.svg)

V0 is the only stable rank: it is slowest at every tight constraint. Among the
optimized snapshots, every version reaches first place somewhere, while none
remains first across the band.

## Constraint leaders

| Requested period | Fastest snapshot | Achieved period |
|---:|---:|---:|
| 1.00 ns | V6 | 1.4096 ns |
| 1.05 ns | V6 | 1.4565 ns |
| 1.10 ns | V2 | 1.4723 ns |
| 1.15 ns | V6 | 1.4817 ns |
| 1.20 ns | V6 | 1.4959 ns |
| 1.25 ns | V4 | 1.5412 ns |
| 1.30 ns | V2 | 1.5567 ns |
| 1.35 ns | V5 | 1.5787 ns |
| 1.40 ns | V1 | 1.5668 ns |
| 1.45 ns | V5 | 1.5607 ns |
| 1.50 ns | V7 | 1.5305 ns |
| 1.55 ns | V3 | 1.5594 ns |
| 1.60 ns | V2 | 1.6000 ns |

![Rank heatmap](figures/02_rank_by_constraint.svg)

Tightening or relaxing the requested period changes mapping, sizing and
restructuring decisions, producing the observed non-monotonic curves.

## Pairwise speed consistency

Each cell is the number of tight constraints, out of 13, where the row version
has a lower achieved period than the column version.

| Faster row ↓ / comparison → | V0 | V1 | V2 | V3 | V4 | V5 | V6 | V7 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| V0 | — | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| V1 | 13 | — | 4 | 2 | 2 | 4 | 1 | 2 |
| V2 | 13 | 9 | — | 4 | 3 | 5 | 3 | 4 |
| V3 | 13 | 11 | 9 | — | 6 | 6 | 2 | 7 |
| V4 | 13 | 11 | 10 | 7 | — | 5 | 4 | 6 |
| V5 | 13 | 9 | 8 | 7 | 8 | — | 4 | 7 |
| V6 | 13 | 12 | 9 | 11 | 9 | 9 | — | **11** |
| V7 | 13 | 11 | 9 | 6 | 7 | 6 | 2 | — |

All optimized versions beat V0 at every point. V6 is faster than V7 at 11 of 13
matched constraints, while the ordering among V1–V7 changes across the sweep.

## Adjacent revision effects

The speed delta is `later − earlier`.

| Step | Faster / slower constraints | Median speed delta | Speed-delta range | Median area delta | Power delta at 500 MHz: multiplier / mixed |
|---|---:|---:|---:|---:|---:|
| V0→V1 | 13 / 0 | **−149.3 ps** | −252.6 to −22.6 ps | −173 µm² | +0.017 / −0.007 mW |
| V1→V2 | 9 / 4 | −21.0 ps | −117.7 to +100.0 ps | +310 µm² | +0.001 / +0.015 mW |
| V2→V3 | 9 / 4 | −23.7 ps | −184.3 to +38.8 ps | −302 µm² | +0.033 / +0.041 mW |
| V3→V4 | 7 / 6 | −2.0 ps | −44.3 to +71.2 ps | +148 µm² | **+0.282 / +0.252 mW** |
| V4→V5 | 8 / 5 | −12.5 ps | −89.0 to +101.8 ps | +35 µm² | −0.004 / +0.010 mW |
| V5→V6 | 9 / 4 | −13.3 ps | −134.0 to +64.5 ps | −122 µm² | −0.021 / −0.021 mW |
| V6→V7 | 2 / 11 | **+16.0 ps** | −69.9 to +95.9 ps | −21 µm² | **−0.291 / −0.273 mW** |

### Interpretation by revision

- **V1 is the clearest latency improvement.** Its parallel condition evaluation
  removes the wide zero-detection logic from behind the forwarding mux. It is
  faster than V0 at all 13 matched points, lowers median area and has nearly
  unchanged power at 500 MHz.
- **V2 demonstrates a trade-off.** Parallel target comparisons sometimes win
  timing and lead three constraints, but duplicate logic raises median area and
  power relative to V1.
- **V3 removes work from the register-file read path.** Its stored sign/zero
  metadata lowers median area, while its speed and power effects remain
  constraint-dependent.
- **V4 targets the wrong timing group for frequency.** The registered BTB update
  was motivated by a `CLK`-group path, while REG2REG remained binding. Its speed
  difference changes sign across the band, while power at 500 MHz increases by
  0.282 mW and 0.252 mW for the two workloads.
- **V5 and V6 are small perturbations on top of V4.** Their speed effects reverse
  with constraint. V6 nevertheless produces the fastest single run and leads
  more constraints than any other snapshot.
- **V7 is a power-oriented ablation.** Removing the V4/V5 structures lowers
  power relative to V6 by 0.291 mW and 0.273 mW at 500 MHz. It is slower than V6
  at 11 of 13 points.

## Area–latency comparison

![Area versus achieved period](figures/03_area_latency_pareto_all_versions.svg)

This global design-space view includes all 21 tuned-script constraints for all
eight revisions. The black line connects the observed Pareto frontier, and its
filled markers retain the version colors.

There is no single area result independent of performance. Using only observed
runs, V6 has the lowest area among points achieving at most 1.60 ns
(25,895 µm²). With a 1.70 ns limit, V1 has the lowest area (25,191 µm²). The
complete matched-speed table is
[`../data/matched_speed_area.csv`](../data/matched_speed_area.csv).

## Equal-frequency power comparison

All versions close timing at the 2.0 ns target. Their power runs use the same
2.0 ns SAIF simulation period and report 100% annotation coverage.

| Version | Multiplier workload | Mixed workload |
|---|---:|---:|
| V0 | **4.065 mW** | 4.394 mW |
| V1 | 4.082 mW | **4.388 mW** |
| V2 | 4.083 mW | 4.403 mW |
| V3 | 4.117 mW | 4.444 mW |
| V4 | 4.399 mW | 4.696 mW |
| V5 | 4.395 mW | 4.705 mW |
| V6 | 4.374 mW | 4.684 mW |
| V7 | 4.084 mW | 4.411 mW |

![Equal-frequency total power at 500 MHz](figures/06_power_at_500mhz.svg)

## Power–latency comparison

![Power versus SAIF simulation period](figures/05_power_latency_pareto_all_versions.svg)

Power is plotted against `sim_period_ns`, the clock period used to generate the
annotated activity. The black line connects the observed Pareto frontier, and
its filled markers retain the version colors. Exact version and synthesis-
constraint ownership is available in
[`../data/pareto_points.csv`](../data/pareto_points.csv). The V4–V6 cluster is
separated from V0–V3/V7 on both workloads.

No revision is selected as an overall PPA winner. Selection requires a target
clock and workload; V7 is the most recent archived revision.

## Synthesis-script comparison

![Tuned versus plain script](figures/04_script_comparison.svg)

| Version | Tuned faster | Plain faster | Median tuned − plain |
|---|---:|---:|---:|
| V0 | 7/13 | 6/13 | −27.6 ps |
| V1 | 8/13 | 5/13 | −37.8 ps |
| V2 | 12/13 | 1/13 | −86.1 ps |
| V3 | 11/13 | 2/13 | −41.5 ps |
| V4 | 10/13 | 3/13 | −34.5 ps |
| V5 | 7/13 | 6/13 | −8.8 ps |
| V6 | 7/13 | 6/13 | −5.1 ps |
| V7 | 7/13 | 6/13 | −3.1 ps |

The tuned script is helpful for V2–V4 and nearly balanced for V0/V5/V6/V7.
The result is version-dependent, so the 104 points are not pooled into one
universal script effect.

## Source tables

- [`../data/synthesis_runs.csv`](../data/synthesis_runs.csv) — all 336 validated runs.
- [`../data/version_summary.csv`](../data/version_summary.csv) — per-version overview.
- [`../data/rank_by_constraint.csv`](../data/rank_by_constraint.csv) — rank heatmap input.
- [`../data/constraint_leaders.csv`](../data/constraint_leaders.csv) — fastest/slowest by constraint.
- [`../data/pairwise_speed_wins.csv`](../data/pairwise_speed_wins.csv) — pairwise counts.
- [`../data/same_constraint_deltas.csv`](../data/same_constraint_deltas.csv) — adjacent changes.
- [`../data/matched_speed_area.csv`](../data/matched_speed_area.csv) — observed area at speed limits.
- [`../data/fixed_frequency_power.csv`](../data/fixed_frequency_power.csv) — 500 MHz power comparison.
- [`../data/fixed_frequency_power_deltas.csv`](../data/fixed_frequency_power_deltas.csv) — adjacent power changes at 500 MHz.
- [`../data/pareto_points.csv`](../data/pareto_points.csv) — all plotted points and frontier membership.
- [`../data/script_comparison.csv`](../data/script_comparison.csv) — per-version script behavior.

Methodological definitions and reproduction commands are in
[`../doc/methodology.md`](../doc/methodology.md).
