# Processor architecture

## Overview

The processor is a 32-bit, five-stage DLX implementation with separate
instruction and data interfaces. The datapath is structural and the control
path is hardwired. Its main extensions beyond a basic pipeline are:

- a 16-entry branch target buffer with 2-bit direction counters;
- forwarding into both execute and decode-stage branch logic;
- a pipelined Booth/Dadda multiplier with scoreboard tracking;
- byte, half-word and word memory operations;
- special registers and precise exception state;
- optional handshaked instruction and data memory models.

The complete structural view is shown in the
[`datapath schematic`](../schematics/02_datapath.svg), with detailed stage
sheets in [`schematics/`](../schematics/).

## Pipeline organization

| Stage | Primary work | Pipeline boundary |
|---|---|---|
| IF | PC selection, instruction request, BTB lookup and prediction | IF/ID |
| ID | instruction decode, register reads, immediate generation, branch resolution and early exception detection | ID/EX |
| EX | operand forwarding, ALU/compare/shift operations, multiplication and effective-address generation | EX/MEM |
| MEM | data-memory access, alignment checking, load/store formatting and exception commit | MEM/WB |
| WB | ALU/load/link selection and architectural register update | register file |

The pipeline registers carry both data and decoded control fields. Flush, stall
and write-enable decisions are produced by the control path and applied at the
stage boundaries.

## Fetch and control flow

Fetch chooses among the sequential address, a predicted target, a decode-stage
correction and an exception or return address. The instruction interface exposes
an address, returned instruction word, issue signal and ready handshake.

The branch target buffer contains 16 direct-mapped entries indexed by PC bits.
Each entry stores a tag, target, validity state, branch type and a 2-bit direction
counter. Conditional branches and register-indirect jumps are resolved in
decode, allowing incorrect predictions to be corrected before the instruction
reaches execute.

The fetch structure and BTB are shown in
[`03_fetch.svg`](../schematics/03_fetch.svg).

## Decode and register state

Decode extracts source and destination fields, forms signed or zero-extended
immediates, reads the integer and special-register files, and generates the
control bundle passed into ID/EX.

Later revisions store sign and zero metadata beside each integer register. The
metadata is generated from the actual write-back value and participates in
same-cycle write/read bypassing. This removes a 32-bit sign/zero reduction from
the decode-to-PC timing path.

Decode details, branch correction and exception inputs are shown in
[`05_decode.svg`](../schematics/05_decode.svg).

## Hazards and forwarding

The forwarding network covers:

- EX-to-EX forwarding for both ALU operands;
- MEM-to-EX forwarding for both ALU operands;
- EX-to-ID forwarding for branch-condition evaluation;
- register-file read-during-write bypassing;
- forwarding of loaded or computed values into store data;
- dependencies involving the special-register file.

A load followed immediately by a dependent execute-stage consumer produces a
load-use stall because the loaded value is not yet available. Branch and jump
operands are checked separately because they are consumed in decode rather than
execute.

The control pipeline, dependency checks and forwarding requests are shown in
[`04_controlpath.svg`](../schematics/04_controlpath.svg).

## Execute and multiplication

The execute stage contains the arithmetic/logic unit, comparison logic, shifter,
effective-address adder and multiplier operand routing. Forwarding multiplexers
select the newest available value before the functional units.

Multiplication uses Booth recoding and a Dadda reduction tree. The multiplier is
internally pipelined, so independent instructions can continue through the main
pipeline while a product is in flight. Scoreboard state tracks destination
ownership and prevents dependent consumers from reading an unavailable result.

The execute datapath is shown in
[`06_execute.svg`](../schematics/06_execute.svg).

## Memory system

The data interface is byte addressed and supports:

| Loads | Stores |
|---|---|
| `lb`, `lbu`, `lh`, `lhu`, `lw` | `sb`, `sh`, `sw` |

Byte and half-word loads select the addressed lane and apply sign or zero
extension. Sub-word stores preserve the unaffected bytes through
read-modify-write formatting. Word and half-word alignment is checked before an
architectural update is allowed.

The interface can operate with a direct memory model or a handshaked slow-memory
model. Instruction and data transactions are independent.

Memory formatting, alignment and MEM/WB state are shown in
[`07_memory.svg`](../schematics/07_memory.svg).

## Exceptions and special registers

The implemented exception classes include illegal instructions, explicit traps,
misaligned control-flow targets and misaligned data accesses. The exception
bundle carries the cause, fault value and instruction address with the affected
instruction until the commit point.

The special-register state includes the vector base, cause, fault value,
interrupted address and status information. Exception entry redirects fetch to
the vector table and records the interrupted context; return-from-exception
restores the saved control state and resumes execution.

## Revision relationship

V0 through V7 share this overall organization. The revisions change selected
timing structures—primarily decode/redirect logic, register metadata, BTB update
state and forwarding-request generation—without changing the five-stage
architectural model. The rationale and measured effect of each snapshot are in
[`revisions.md`](revisions.md), and the full comparison is in
[`../analysis/README.md`](../analysis/README.md).

## Public-source scope

The schematics, synthesis evidence, analysis and verification artifacts are
published. Complete RTL and testbench sources are withheld because of university
obligations and can be shared privately only where permitted.
