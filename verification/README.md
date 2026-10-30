# Verification archive

The assembly programs, their memory images, the reference results, the
archived V6 RTL results and the regression scripts. The RTL, testbench and
reference-model sources are withheld, so the HDL simulations cannot be rerun
from here, but every archived result can be checked.

```text
verification/
  CHECKLIST.md          feature coverage, item by item, and how each is checked
  timing_checks.txt     output of check_timing.py on the V6 waveforms
  scripts/              the assembly, regression and waveform-check flow
  tests/<test name>/
    *.asm               assembly program (the header explains the test)
    *.list              assembler listing
    *_imem.txt          instruction image
    *_dmem_init.txt     initial data image
    *_dmem_golden.txt   reference final data memory
    *_dmem_rtl*.txt     archived RTL final data memory, per memory mode
```

## Method

Each program is assembled, executed by the software reference model, and run
on the RTL with the same images; the final data memory of the RTL must equal
the reference word for word. The memory is checked whole, so a forwarding or
stall error that produces a wrong value is caught even where the test author
did not expect it. The 27 programs cover:

- integer arithmetic, logic, shifts and signed/unsigned comparisons;
- immediate extension and architectural-zero behaviour;
- pipelined multiplication, dependencies and overlapping execution;
- forwarding, load-use stalls, store-data forwarding and scoreboarding;
- conditional branches, jumps, links, BTB allocation, hits, the 2-bit counter
  and misprediction recovery;
- byte, half-word and word loads/stores with alignment handling;
- traps, illegal instructions, misaligned targets and data, special
  registers, nested exceptions and exception return;
- mixed programs, including two switching-activity workloads
  (`20_power_bench`, `24_mac_loops`).

Two data memories are used: the zero-latency model (mode `ff`) and a model
that answers after two cycles (mode `fs`), which exercises the memory stall.
The instruction memory is always zero-latency.

[`CHECKLIST.md`](CHECKLIST.md) maps all 73 features to their programs.

## Timing checks on the waveform

A BTB that never hits, or a scoreboard that stalls one cycle too many, still
produces the right memory image. For those items `scripts/check_timing.py`
reads the VCDs of two programs cycle by cycle:

- `26_btb_hysteresis` — for every execution of two test branches, whether the
  BTB predicted taken and whether the branch was mispredicted: the cold miss,
  the hits, the hysteresis of the 2-bit counter (one not-taken does not flip
  a saturated prediction) and the weak state (it does flip a weak one);
- `28_nested_exception` — that the trap's vector entry, a branch on a
  register that a squashed load had marked busy, reaches decode without a
  stall: the scoreboard is cleared when an exception commits.

Every check passes on all eight versions (V6 output:
[`timing_checks.txt`](timing_checks.txt)).

## Results

All 32 RTL runs of V6 pass (27 programs in mode `ff`, the five that load and
store also in mode `fs`); [`../data/verification_results.csv`](../data/verification_results.csv)
lists them with their cycle counts. Every run reports its cycles from the end
of reset to the program's final self-loop. All eight versions pass all 32
runs and the waveform checks, and give identical counts except one cycle in
`27_branch_misaligned_target` (V4–V6: 78, the others 77; explained in
[`../doc/revisions.md`](../doc/revisions.md))
([`../data/cycle_counts.csv`](../data/cycle_counts.csv), per-version results
in [`../evidence/rtl/`](../evidence/rtl/)).

Every synthesized netlist of every version also passes tests 01–24 at gate
level, zero-delay, at its own achieved period (results in
[`../evidence/power/`](../evidence/power/)), and the routed V6 netlist passes
them with extracted delays and timing checks
([`../physical_design/`](../physical_design/)).

## Checking the archive

```text
python scripts/check_verification.py
```

It compares every archived RTL image with its reference image and rebuilds
the cycle-count table. It does not run an HDL simulator.
