# Verification archive

The assembly programs, their generated images, the reference results, the
archived V7 RTL results and the original regression scripts. The RTL,
testbench and reference-model sources are withheld, so the HDL simulations
cannot be rerun from here, but every archived result can be checked.

```text
verification/
  CHECKLIST.md          instruction and feature coverage, test by test
  scripts/              the original assembly and regression flow
  tests/<test name>/
    *.asm               assembly program
    *.list              assembler listing
    *_imem.txt          instruction image
    *_dmem_init.txt     initial data image
    *_dmem_golden.txt   reference final data memory
    *_dmem_rtl*.txt     archived RTL final data memory, per memory mode
```

## Method

Each program is assembled, executed by the software reference model, and run
on the RTL with the same images; the final data memory of the RTL must equal
the reference word for word. The 24 programs cover:

- integer arithmetic, logic, shifts and signed/unsigned comparisons;
- immediate extension and architectural-zero behaviour;
- pipelined multiplication, dependencies and overlapping execution;
- forwarding, load-use stalls, store-data forwarding and scoreboarding;
- conditional branches, jumps, links and branch-prediction recovery;
- byte, half-word and word loads/stores with alignment handling;
- traps, illegal instructions, special registers and exception return;
- mixed programs, including two switching-activity workloads
  (`20_power_bench`, `24_mac_loops`).

[`CHECKLIST.md`](CHECKLIST.md) maps each feature to its program and marks the
properties that a final memory image cannot show.

Every run also reports its cycle count, from the end of reset to the program's
final self-loop. All eight versions give identical counts for every program
([`../data/cycle_counts.csv`](../data/cycle_counts.csv)); the per-version RTL
results are in [`../evidence/rtl/`](../evidence/rtl/), and the gate-level
regression of every synthesized netlist in
[`../evidence/power/`](../evidence/power/).

## Known mismatches

`11_btb_predictor` and `16_jal_return` are archived as expected mismatches in
I-cache mode (`cf`): a PC redirect that arrives during an instruction-cache
refill fetches the wrong line in the testbench's cache model.

## Checking the archive

```text
python scripts/check_verification.py
```

It compares every archived RTL image with its reference image, confirms the
two expected mismatches, and rebuilds the cycle-count table. It does not run
an HDL simulator.
