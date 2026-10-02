# Verification archive

This directory preserves the assembly stimuli, generated program images,
reference results, archived RTL results, regression definitions and original
simulation scripts used for the DLX verification campaign.

The complete RTL, testbench and reference-model sources are not published
because of university obligations. The archived evidence can be inspected and
checked publicly; rerunning the HDL simulations requires the private source and
the original Questa/ModelSim environment.

## Included material

```text
verification/
  CHECKLIST.md          instruction and feature coverage
  scripts/              archived assembly and regression flow
  tests/
    <test name>/
      *.asm             assembly stimulus
      *.list / *.bin    assembler outputs
      *_imem.txt        instruction image
      *_dmem_init.txt   initial data image
      *_dmem_golden.txt reference final state
      *_dmem_rtl*.txt   archived RTL final state
```

## Verification method

Each directed program follows the same flow:

1. Assemble the program and create instruction/data initialization images.
2. Execute it with the software reference model.
3. Simulate the RTL with the same program and memory configuration.
4. Compare the final data-memory image against the reference output.

The comparison checks stored words. It does not by itself measure cycle counts,
stall events or branch-predictor accuracy. Therefore, testbench modification for counting total cycles, stalls, pipeline flushes, branch predictions and etc is required and is planned for the future work.

## Covered behavior

The suite exercises:

- integer arithmetic, logic, shifts and signed/unsigned comparisons;
- immediate extension and architectural-zero behavior;
- pipelined multiplication, dependencies and overlapping execution;
- forwarding, load-use stalls, store-data forwarding and scoreboarding;
- conditional branches, jumps, links and visible redirect outcomes;
- byte, half-word and word loads/stores with alignment handling;
- traps, illegal instructions, special registers and exception return;
- mixed integration programs and switching-activity workloads.

[`CHECKLIST.md`](CHECKLIST.md) maps directed test intentions and distinguishes
stored-result checks from properties that still require cycle-level evidence.

## Checking the archived results

From the repository root:

```text
python scripts/check_verification.py
```

The checker reads the declared regression expectations and compares the archived
RTL outputs with their corresponding reference outputs. It does not invoke an
HDL simulator.

The separate post-synthesis gate-level regression results for V0–V7 are under
[`../evidence/power/`](../evidence/power/), with per-test verdicts and limits
described in the [power evidence notes](../evidence/power/methodology/README.md).

## Archived simulation flow

The Tcl and do-files under `scripts/` document the original regression flow,
including per-test runtime, memory-model selection and result naming. They are
retained as methodology evidence but are not a self-contained public simulation
environment without the withheld design and testbench sources.
