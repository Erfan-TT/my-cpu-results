# Evidence included in this repository

`synthesis/V0` through `synthesis/V7` contain archived synthesis configuration
files and the reports used by the extraction script:

- both synthesis Tcl scripts and SDC constraints;
- `results.csv` for each script arm;
- timing reports, including dedicated REG2REG reports;
- QoR reports containing cell area.

Power result tables and per-test gate-simulation verdicts for the tuned-script
points are under `power/V0` through `power/V7`. The
[power methodology notes](power/methodology/README.md) describe their
verification status and limits.

Assembly tests, reference outputs, and archived RTL memory results are included
under `verification/`. The RTL and testbench are not published because of
university obligations and may be shared privately where permitted.

Generated gate-level netlists and SDF files are excluded. The timing and area
numbers in the derived tables are parsed from the included reports and checked
against each script arm's `results.csv`.
