# DLX 5-stage pipelined CPU

This repository documents a 32-bit DLX implementation with branch prediction,
forwarding and hazard control, a pipelined Booth/Dadda multiplier, sub-word
memory operations, and precise exception state. It includes architecture
schematics, synthesis and power evidence, analysis scripts, and verification
artifacts covering eight RTL revisions.

> **Source availability:** The complete RTL is not published here because of
> university obligations. This public repository therefore focuses on the
> architecture, synthesis and power results, verification evidence, and
> reproducible analysis. The RTL can be shared privately where permitted.

The synthesis study sweeps clock constraints across V0–V7 and reports timing,
area and workload-annotated power for every implementation point.

## Processor architecture

The implementation is organized as a conventional five-stage pipeline with a
structural datapath and a separate hardwired control path:

| Stage | Main work |
|---|---|
| IF | PC selection, instruction request, BTB lookup, prediction and IF/ID state |
| ID | decode, integer/special-register access, immediate generation, branch resolution and early exception detection |
| EX | operand forwarding, ALU/compare/shift operations, Booth/Dadda multiplication and effective-address generation |
| MEM | data-memory transaction, byte/half-word selection, store formatting, alignment checks and exception commit |
| WB | ALU/load/link selection, integer-register write-back and V7 sign/zero metadata generation |

![Five-stage datapath and stage interfaces](schematics/02_datapath.svg)

The instruction and data sides use separate memory interfaces. The instruction
side supports a cache-backed mode; the data side supports byte-addressed
byte/half-word/word transfers and a handshaked slow-memory mode. Pipeline state
is held at the IF/ID, ID/EX, EX/MEM and MEM/WB boundaries.

### Control flow and prediction

Fetch selects between sequential `PC+4`, a predicted target, a decode-stage
correction, and an exception/return redirect. The BTB has 16 direct-mapped rows,
tags, targets, valid bits and 2-bit direction counters. Branches and indirect
jumps are resolved in decode, which makes the register-file-to-PC path one of
the central latency targets in the optimization sequence.

### Hazards, forwarding and long-latency execution

The control path carries decoded fields beside the instruction through the
pipeline. Forwarding covers EX→EX, MEM→EX, EX→ID branch operands,
register-file read-during-write and load→store data. A load-use dependency
stalls when the value cannot reach the immediately following EX stage. The
multiplier is internally pipelined and uses scoreboard state so independent
instructions can continue while a product is in flight.

![Control pipeline, hazards and forwarding](schematics/04_controlpath.svg)

### Memory and precise exceptions

The memory stage implements `lb`, `lbu`, `lh`, `lhu`, `lw`, `sb`, `sh` and
`sw`, including lane selection, sign/zero extension and read-modify-write store
formatting. Misaligned accesses, illegal instructions, traps and misaligned
control-flow targets are converted into a cause/value/PC bundle that travels
with the instruction until commit. The detailed decode, execute and memory
sheets are in [`schematics/`](schematics/).

The complete architectural description is in
[`doc/architecture.md`](doc/architecture.md).

## Design-space exploration

Each revision was motivated by a concrete logic chain visible in a timing
report.

| Version | Path or structure being targeted | Rationale and resulting design decision |
|---|---|---|
| V0 | Fetch instruction register → register-file read → branch decision → PC | Unoptimized reference used to locate the dominant decode/redirect path |
| V1 | Forwarding mux followed by a 32-bit branch-condition reduction | Compute forwarded and non-forwarded conditions in parallel, then select one bit; faster than V0 at all 13 tight constraints |
| V2 | Wide corrected-target mux followed by target comparison | Perform three comparisons in parallel and mux their 1-bit results; speed ordering varies and duplicated logic increases area |
| V3 | Register-file output followed by sign/zero detection | Store sign/zero metadata beside each register and generate it from the actual WB value |
| V4 | BTB update path reported in the `CLK` group | Register the update bundle; it improves the targeted group but not the binding REG2REG path and raises total power |
| V5 | Special-register index guards inside an `if/elsif` dependency chain | Compute safe index terms in parallel; only small, constraint-dependent changes result |
| V6 | EX/MEM forwarding checks serialized by priority syntax | Generate independent forwarding requests in parallel; V6 leads the speed ranking most often but retains V4's power cost |
| V7 | Ablation of V4/V5 while retaining V3 and V6 logic | Recover much of the power increase while preserving the retained datapath changes; V6 remains faster at most matched constraints |

See [`doc/revisions.md`](doc/revisions.md) for the complete rationale behind
every revision.

## Synthesis analysis

The study contains 336 Design Compiler runs. The main matched band covers 13
requested periods from 1.00 ns through 1.60 ns for every version and both
synthesis scripts. Power at 500 MHz uses a common 2.0 ns simulation period.

### Version overview

| Version | First closure | Median achieved period | Best period | Median area | First-place count | Rank range | Power at 500 MHz: multiplier / mixed |
|---|---:|---:|---:|---:|---:|---:|---:|
| V0 | 2.0 ns | 1.7730 ns | 1.6910 ns | 26,826 µm² | 0/13 | 8–8 | **4.065** / 4.394 mW |
| V1 | 1.7 ns | 1.6178 ns | 1.4997 ns | 26,662 µm² | 1/13 | 1–7 | 4.082 / **4.388** mW |
| V2 | 1.6 ns | 1.5997 ns | 1.4723 ns | 26,965 µm² | 3/13 | 1–7 | 4.083 / 4.403 mW |
| V3 | 1.7 ns | 1.5846 ns | 1.4154 ns | 26,680 µm² | 1/13 | 1–6 | 4.117 / 4.444 mW |
| V4 | 1.7 ns | 1.5726 ns | 1.4456 ns | 26,899 µm² | 1/13 | 1–7 | 4.399 / 4.696 mW |
| V5 | 1.7 ns | 1.5787 ns | 1.4569 ns | 26,797 µm² | 2/13 | 1–7 | 4.395 / 4.705 mW |
| V6 | 1.6 ns | 1.5717 ns | **1.4096 ns** | 26,722 µm² | **4/13** | 1–6 | 4.374 / 4.684 mW |
| V7 | 1.7 ns | 1.5648 ns | 1.5024 ns | 26,724 µm² | 1/13 | 1–6 | 4.084 / 4.411 mW |

### Analysis conclusions

| Finding | Evidence |
|---|---|
| The optimization sequence consistently improves on V0 latency | V1–V7 are faster than V0 at all 13 matched tight constraints |
| Speed leadership depends on the synthesis constraint | Every optimized version leads at least one point; V6 leads most often at 4/13 |
| V6 reaches the highest observed frequency | Best achieved period is 1.4096 ns; V6 and V2 first close the sampled 1.6 ns target |
| Area and latency must be selected together | V6 has the smallest observed area at or below 1.60 ns; V1 has the smallest at or below 1.70 ns |
| The equal-frequency power leader depends on workload | At 500 MHz, V0 is lowest for the multiplier workload and V1 for the mixed workload |
| V7 reverses much of the V4–V6 power increase | At 500 MHz, V7 measures 4.084 / 4.411 mW, close to the V0–V3 cluster |

### Area–latency design space

![Area–latency design space for all revisions](analysis/figures/03_area_latency_pareto_all_versions.svg)

### Power–latency design space

![Power–latency design space for all revisions](analysis/figures/05_power_latency_pareto_all_versions.svg)

Frontier markers retain their version colors. Exact version and synthesis-
constraint ownership is listed in
[`data/pareto_points.csv`](data/pareto_points.csv). The complete constraint
tables, adjacent-revision deltas and synthesis-script comparison are in
**[`analysis/README.md`](analysis/README.md)**.

## Verification

Assembly tests are checked against the software reference model. The suite
covers:

- integer arithmetic, logical operations, shifts, comparisons and immediate forms;
- signed and unsigned multiplication, dependencies and overlapping execution;
- EX/MEM forwarding, register-file bypassing, load-use stalls and scoreboarding;
- conditional branches, jumps, links, prediction and redirect behavior;
- word, byte and half-word loads/stores, sign extension and alignment handling;
- traps, illegal instructions, special registers, exception entry and return;
- mixed integration programs combining control flow, memory and multiplication.

The detailed instruction-to-test mapping is in
[`verification/CHECKLIST.md`](verification/CHECKLIST.md).

## Rebuilding the published analysis

Install the plotting dependency and run:

```text
python -m pip install -r requirements.txt
python scripts/extract_results.py
python scripts/summarize.py
python scripts/check_verification.py
python scripts/plot_results.py
```

The commands rebuild the validated synthesis tables, analysis summaries,
verification summary and figures from the archived reports. They do not
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
