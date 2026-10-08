# Evidence included in this repository

- `synthesis/V0` … `synthesis/V7` — for both synthesis scripts: the Tcl
  script, the SDC constraints, `results.csv`, timing reports (including
  dedicated REG2REG reports) and QoR reports with cell area. The extraction
  script parses timing and area from these reports and checks them against
  each `results.csv`.
- `power/V0` … `power/V7` — per synthesis point: simulation period, workload
  power, SAIF coverage and gate-level regression status
  (`final_results.csv`), and the per-test gate-level verdicts
  (`gate_results.csv`). The [power methodology notes](power/methodology/README.md)
  describe how they were produced and their limits.
- `rtl/V0` … `rtl/V7` — every version's RTL regression: verdict and cycle
  count per test and memory mode.

The assembly programs and the archived V7 RTL memory images are under
[`../verification/`](../verification/). Gate-level netlists and SDF files are
not included.
