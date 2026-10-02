# DLX 5-stage pipelined CPU

This repository documents a 32-bit DLX implementation with branch prediction,
forwarding and hazard control, a pipelined Booth/Dadda multiplier, byte, half-word
and word memory operations, and exception handling. It includes architecture
schematics, synthesis and power evidence, analysis scripts, and verification
artifacts for eight RTL snapshots, V0–V7.

The complete RTL is not published here because of university obligations.
This public repository therefore focuses on the
architecture, synthesis and power results, verification evidence, and
reproducible analysis. The RTL can be shared privately where permitted.

The synthesis study sweeps clock constraints across V0–V7 and reports timing
and area for both synthesis scripts. Workload-annotated power is available for
the tuned-script points.

## Processor architecture

The implementation is organized as a five-stage pipeline with a
structural datapath and a separate hardwired control path:

| Stage | Main work |
|---|---|
| IF | PC selection, instruction request, BTB lookup, prediction and IF/ID state |
| ID | decode, integer/special-register access, immediate generation, branch resolution and early exception detection |
| EX | operand forwarding, ALU/compare/shift operations, Booth/Dadda multiplication and effective-address generation |
| MEM | data-memory transaction, byte/half-word selection, store formatting, alignment checks and exception commit |
| WB | Register-file write-port signals; sign/zero metadata generation in V3–V7 |

![Five-stage datapath and stage interfaces](schematics/02_datapath.svg)

The instruction and data sides use separate memory interfaces. The instruction
side supports a cache-backed mode; the data side supports byte-addressed
byte/half-word/word transfers and a handshaked slow-memory mode. Pipeline state
is held at the IF/ID, ID/EX, EX/MEM and MEM/WB boundaries.

### Branch prediction and jumps

Fetch selects among sequential `PC+4`, a BTB prediction, a decode-stage
correction, and an exception or return address. The BTB has 16 direct-mapped
rows with tags, targets, valid bits and 2-bit direction counters. Branches and indirect
jumps are resolved in decode, making decode-to-PC control a recurring timing
concern in the synthesis reports.

### Hazards, forwarding and long-latency execution

The control path carries decoded fields beside the instruction through the
pipeline. Forwarding covers EX→EX, MEM→EX, EX→ID branch operands,
register-file read-during-write and load→store data. A load-use dependency
stalls when the value cannot reach the immediately following EX stage. The
multiplier is internally pipelined and uses scoreboard state so independent
instructions can continue while a product is in flight.

![Control pipeline, hazards and forwarding](schematics/04_controlpath.svg)

### Memory and exceptions

The memory stage implements `lb`, `lbu`, `lh`, `lhu`, `lw`, `sb`, `sh` and
`sw`. It selects load lanes, extends loaded bytes and half-words, and sizes
store data. The memory model merges sub-word stores into the addressed word.
Misaligned accesses, illegal instructions, traps and misaligned control-flow
targets are converted into a cause/value/PC bundle that travels with the
instruction to exception commit. Detailed stage sheets are in
[`schematics/`](schematics/).

More architectural detail is in
[`doc/architecture.md`](doc/architecture.md).

## Design-space exploration

V0 is the baseline. Each row starts with the first path in the **previous
version's 1.0 ns tuned-script report**, the synthesis flow used for the RTL
iteration. The RTL change is stated separately; some edits did not directly
alter the reported path.

| Revision | Previous path: start → end | RTL meaning | Change in this revision |
|---|---|---|---|
| V1 | [V0](evidence/synthesis/V0/new/timing_1p0.rpt): IF instruction bit 24 → PC bit 0 | Source-register selection and branch/redirect control reach the PC. | Parallelize branch-condition evaluation; also change forwarding, redirect comparison and exception-vector logic. |
| V2 | [V1](evidence/synthesis/V1/new/timing_1p0.rpt): IF instruction bit 21 → PC bit 5 | Source-register address feeds decode branch/redirect logic. | Compare predicted address with three candidate targets in parallel, then select a one-bit mismatch. |
| V3 | [V2](evidence/synthesis/V2/new/timing_1p0.rpt): IF instruction bit 30 → PC bit 19 | Instruction decode and branch correction feed the PC redirect. | Store and bypass sign/zero metadata, removing zero detection from a branch-operand cone; the exact reported opcode-to-PC path is not isolated. |
| V4 | [V3](evidence/synthesis/V3/new/timing_1p0.rpt): MEM/WB destination bit 1 → multiplier tree register bit 30 | WB bypass/forwarding can affect an EX multiplier operand. | Register BTB updates and remove BTB-facing guards; neither directly edits this multiplier route. |
| V5 | [V4](evidence/synthesis/V4/new/timing_1p0.rpt): ID/EX `rs2` index bit 0 → multiplier tree register bit 28 | Source-register index selects EX forwarding and multiplier input. | Move special-register index guards outside exception priority logic; no direct edit to EX forwarding. |
| V6 | [V5](evidence/synthesis/V5/new/timing_1p0.rpt): ID/EX `rs2` index bit 0 → multiplier tree register bit 30 | `rs2` comparison selects the forwarded multiplier operand. | Make EX and MEM forwarding requests independent before the operand mux. |
| V7 | [V6](evidence/synthesis/V6/new/timing_1p0.rpt): MEM/WB destination bit 0 → multiplier tree register bit 31 | WB destination comparison selects a forwarded multiplier operand. | Remove V4/V5 structures while retaining V3/V6; no direct edit to this multiplier route. |

See [`doc/revisions.md`](doc/revisions.md) for the complete rationale behind
every revision.

## Synthesis analysis

The study contains 336 Design Compiler runs. The main matched band covers 13
requested periods from 1.00 ns through 1.60 ns for every version and both
synthesis scripts. The overview below uses tuned-script results; its period
and area extrema come from the 13-point band. First closure considers all 21
constraints. Power at 500 MHz uses a common 2.0 ns simulation period.

### Version overview

| Version | First closure | Best period | Median area | Power at 500 MHz: multiplier / mixed |
|---|---:|---:|---:|---:|
| V0 | 2.0 ns | 1.6910 ns | 26,826 µm² | **4.065** / 4.394 mW |
| V1 | 1.7 ns | 1.4997 ns | 26,662 µm² | 4.082 / **4.388** mW |
| V2 | 1.6 ns | 1.4723 ns | 26,965 µm² | 4.083 / 4.403 mW |
| V3 | 1.7 ns | 1.4154 ns | 26,680 µm² | 4.117 / 4.444 mW |
| V4 | 1.7 ns | 1.4456 ns | 26,899 µm² | 4.399 / 4.696 mW |
| V5 | 1.7 ns | 1.4569 ns | 26,797 µm² | 4.395 / 4.705 mW |
| V6 | 1.6 ns | **1.4096 ns** | 26,722 µm² | 4.374 / 4.684 mW |
| V7 | 1.7 ns | 1.5024 ns | 26,724 µm² | 4.084 / 4.411 mW |

### Analysis conclusions

| Finding | Evidence |
|---|---|
| The optimization sequence consistently improves on V0 latency | V1–V7 are faster than V0 at all 13 matched tight constraints |
| Speed leadership depends on the synthesis constraint | Every optimized version leads at least one point; V6 leads most often at 4/13 |
| V6 reaches the highest observed frequency | Best achieved period is 1.4096 ns; V6 and V2 first close the sampled 1.6 ns target |
| Area and latency must be selected together | V6 has the smallest observed area at or below 1.60 ns; V1 has the smallest at or below 1.70 ns |
| The lowest reported 500 MHz power depends on workload | V0 is lowest for the multiplier program and V1 for the mixed program; the V0–V1 differences are only 0.017 / 0.007 mW |
| V7 reverses much of the V4–V6 power increase | At 500 MHz, V7 measures 4.084 / 4.411 mW, close to the V0–V3 cluster |

### Area–latency design space

![Area–latency design space for all revisions](analysis/figures/03_area_latency_pareto_all_versions.svg)

### Power–latency design space

![Power–latency design space for all revisions](analysis/figures/05_power_latency_pareto_all_versions.svg)

Here the horizontal coordinate is the activity-simulation period, as recorded
in the power table, rather than the achieved synthesis period used in the area
plot.

Frontier markers retain their version colors. Exact version and synthesis-
constraint ownership is listed in
[`data/pareto_points.csv`](data/pareto_points.csv). The complete constraint
tables, adjacent-revision deltas and synthesis-script comparison are in
**[`analysis/README.md`](analysis/README.md)**.

## Verification

Archived assembly-test results are checked against the software reference
model's final memory images. The programs exercise:

- integer arithmetic, logical operations, shifts, comparisons and immediate forms;
- signed and unsigned multiplication, dependencies and overlapping execution;
- EX/MEM forwarding, register-file bypassing, load-use stalls and scoreboarding;
- conditional branches, jumps, links and architecturally visible redirects;
- word, byte and half-word loads/stores, sign extension and alignment handling;
- traps, illegal instructions, special registers, exception entry and return;
- mixed integration programs combining control flow, memory and multiplication.

The detailed instruction-to-test mapping is in
[`verification/CHECKLIST.md`](verification/CHECKLIST.md).

The archived gate-level functional regression reports `pass` for all eight
versions at all 21 tuned-script synthesis points, with zero reported failures.
Per-test verdicts and the documented skip are described in the
[power evidence notes](evidence/power/methodology/README.md); these results do not establish
post-layout timing closure.

## Rebuilding the published analysis

Install the plotting dependency and run:

```text
python -m pip install -r requirements.txt
python scripts/extract_results.py
python scripts/summarize.py
python scripts/check_verification.py
python scripts/plot_results.py
```

The commands rebuild the synthesis tables, analysis summaries and figures,
and check the archived verification results. They do not
resynthesize or simulate the processor because the RTL and proprietary EDA
environment are not part of the public repository. See
[`doc/methodology.md`](doc/methodology.md) for metric definitions.

## Repository map

- [`schematics/`](schematics/) — editable and publication-ready architecture sheets.
- [`verification/`](verification/) — assembly tests and archived verification results.
- [`analysis/`](analysis/) — complete synthesis comparison and figures.
- [`evidence/`](evidence/) — synthesis configuration, timing/QoR reports and power tables.
- [`data/`](data/) — validated run-level and derived descriptive tables.
- [`scripts/`](scripts/) — extraction, summarization, verification and plotting tools.

## Next work planned

- Instrument the private HDL testbench with passive counters for total and
  retired cycles, stalls, pipeline flushes, branch predictions and
  mispredictions, forwarding selections, memory waits, and multiplier
  activity. Export per-test CSV summaries and selected waveform evidence
  without changing the synthesized processor.
- Run the existing assembly suite and a small set of representative kernels
  through the instrumented testbench to report CPI and event counts alongside
  the existing functional results.
- Add a dedicated write-back schematic and a V7-specific schematic delta.
- Add place-and-route, extracted parasitics and multi-corner timing.
- Re-run activity-based power analysis after layout.
