# Evidence included in this repository

`synthesis/V0` through `synthesis/V7` contain the exact synthesis configuration
files and the compact primary reports used by the extraction script:

- both synthesis Tcl scripts and SDC constraints;
- `results.csv` for each script arm;
- timing reports, including dedicated REG2REG reports;
- QoR reports containing cell area;
- post-synthesis power result tables.

Assembly tests, reference outputs, and archived RTL memory results are included
under `verification/`. The RTL and testbench are not published because of
university obligations and may be shared privately where permitted.

Generated gate-level netlists and SDF files are intentionally excluded. The
complete local archive is about 3.06 GB; copying it into a normal Git repository
would add hundreds of generated multi-megabyte files without being necessary to
reconstruct the published tables. The timing and area numbers here are parsed
from the included primary reports, not copied from the previous public summary.
