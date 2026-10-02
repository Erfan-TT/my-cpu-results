# RTL revision record

V0 is the baseline. Each later section begins with the first path in the
previous snapshot's **1.0 ns tuned-script timing report**. Those reports
correspond to the synthesis flow used in the RTL iteration. A path's
startpoint and endpoint establish its boundaries; they do not prove which
individual source edit caused a timing change. Matched-constraint outcomes are
in [`analysis/`](../analysis/README.md).
The timing lines compare `1.0 ns − worst slack` for adjacent tuned-script
runs. A period change measures the whole mapped snapshot; only when the first
paths share an RTL route can it suggest what happened to that route.

## V1 — branch and redirect restructuring

Previous report: [V0 timing](../evidence/synthesis/V0/new/timing_1p0.rpt),
`DP_i_fetch_i_IR_out_reg_24_` → `DP_i_fetch_i_pc_i_Y_reg_0_`.

Instruction bit 24 belongs to the source-register field. The path reaches the
PC through decode and branch/redirect logic. The main V1 timing edit computes
branch conditions from the register-file value and forwarded EX flags in
parallel, then selects the one-bit result.

V1 contains several other RTL changes compared with V0:

- Branch correction computes taken and not-taken predicted-target mismatches
  separately, then selects a one-bit mismatch for `flush`.
- EX registers sign and zero flags derived from its selected result; those
  flags feed decode's branch decision when EX-to-ID forwarding is selected.
- The explicit MEM-to-ID forwarding path is removed. Decode retains EX-to-ID
  forwarding and uses the register file's same-cycle write/read bypass for
  the write-back value.
- Exception-vector selection changes from multiplexing operands into a shared
  adder to assembling the vector address from VBR bits and the cause field.

The V0→V1 timing difference is a result of this combined snapshot; it cannot
be attributed to the branch-condition change alone.
At the same 1.0 ns constraint, the reported achieved period changes from
**1.7523 to 1.4997 ns (−252.6 ps)**. Both first paths run from a source-register
instruction bit to a PC register bit, although the exact bit endpoints differ.

## V2 — parallel target comparisons

Previous report: [V1 timing](../evidence/synthesis/V1/new/timing_1p0.rpt),
`DP_i_fetch_i_IR_out_reg_21_` → `DP_i_fetch_i_pc_i_Y_reg_5_`.

Instruction bit 21 also belongs to the source-register field. The decode
operand can select a corrected branch or jump target, which contributes to a
PC redirect. V2 changes branch correction so the predicted target is compared
with three candidate targets in parallel; a one-bit selector chooses the
mismatch result. This targets comparison after wide target selection. The
paired results still change sign with the requested constraint.
At 1.0 ns, the reported achieved period changes from **1.4997 to 1.5997 ns
(+100.0 ps)**. The first path still ends at the PC, but its start changes from
a source-register bit to an opcode bit; this is not an exact old-path delay
comparison.

## V3 — register sign/zero metadata

Previous report: [V2 timing](../evidence/synthesis/V2/new/timing_1p0.rpt),
`DP_i_fetch_i_IR_out_reg_30_` → `DP_i_fetch_i_pc_i_Y_reg_19_`.

Instruction bit 30 is part of the opcode. This is an instruction-decode to PC
redirect path. V3 stores sign and zero bits beside each integer register.
Write-back computes them from the value actually written, and the register
file bypasses them on a same-cycle read/write match. Branch decisions use
those bits instead of reducing a 32-bit register output to detect zero.
That shortens a branch-operand cone, but the report does not isolate its
contribution to this specific opcode-to-PC path.
At 1.0 ns, the reported achieved period changes from **1.5997 to 1.4154 ns
(−184.3 ps)**. The first path moves to the multiplier, so this number does not
measure the old opcode-to-PC path by itself.

## V4 — registered BTB update

Previous report: [V3 timing](../evidence/synthesis/V3/new/timing_1p0.rpt),
`DP_i_mem_access_i_rd_out_reg_i_Y_reg_1_` →
`DP_i_execute_i_boothmul_i_tree_i_register_i_2_Y_temp_reg_30_`.

The startpoint is bit 1 of the MEM/WB destination-register index, not a MEM
data result. It can affect EX forwarding selection and hence a multiplier
operand before the Dadda-tree register. V4 does not directly change that
operand path. It registers the BTB update request before the table write and
also removes BTB-facing illegal-detector guards and invalidation logic. BTB
paths appear elsewhere in the V3 report, but they are not this first path.
The combined edits cannot be separated by this revision's result alone.
At 1.0 ns, the reported achieved period changes from **1.4154 to 1.4456 ns
(+30.2 ps)**. Both first paths end in the multiplier tree, but their launch
registers differ; this does not measure the previous route in isolation.

## V5 — special-register index guards

Previous report: [V4 timing](../evidence/synthesis/V4/new/timing_1p0.rpt),
`DP_i_decode_i_rs2_addr_i_Y_reg_0_` →
`DP_i_execute_i_boothmul_i_tree_i_register_i_3_Y_temp_reg_28_`.

The startpoint is bit 0 of the source-register index held at the ID/EX
boundary. That index participates in EX forwarding selection; the selected
operand enters the multiplier. V5 moves special-register index guarding out
of the target-dependent exception process into separate combinational terms.
The changed guards feed decode and hazard control, but do not directly rewrite
this EX forwarding-to-multiplier path.
At 1.0 ns, the reported achieved period changes from **1.4456 to 1.4717 ns
(+26.1 ps)**. The first path remains `rs2` index bit 0 to a register in the
same multiplier-tree layer, with a different destination bit. That route
family became slower in this mapped result.

## V6 — independent forwarding requests

Previous report: [V5 timing](../evidence/synthesis/V5/new/timing_1p0.rpt),
`DP_i_decode_i_rs2_addr_i_Y_reg_0_` →
`DP_i_execute_i_boothmul_i_tree_i_register_i_3_Y_temp_reg_30_`.

The same source-register-index-to-multiplier route is first in V5's report.
V6 replaces `if/elsif` EX/MEM forwarding checks with independent `if` checks
for each execute operand. The execute operand mux retains EX priority when
both requests are asserted. This directly changes control logic on the
reported route, although resynthesis prevents assigning the measured period
delta to one gate-level segment.
At 1.0 ns, the reported achieved period changes from **1.4717 to 1.4096 ns
(−62.1 ps)**. The first path moves from the `rs2` index to a MEM/WB
destination index, so the number is an overall result rather than a direct
measurement of the old `rs2` route.

## V7 — combined rollback

Previous report: [V6 timing](../evidence/synthesis/V6/new/timing_1p0.rpt),
`DP_i_mem_access_i_rd_out_reg_i_Y_reg_0_` →
`DP_i_execute_i_boothmul_i_tree_i_register_i_3_Y_temp_reg_31_`.

The MEM/WB destination-register index can select EX forwarding into the
multiplier. V7 retains V3's register metadata and V6's forwarding checks,
while removing V4's registered BTB update and V5's special-index rewrite.
It restores the earlier BTB/illegal-detector interfaces. These are not direct
edits to the reported multiplier route. V7 is a combined power-oriented
rollback, not a universal timing winner.
At 1.0 ns, the reported achieved period changes from **1.4096 to 1.5055 ns
(+95.9 ps)**. V7's first path ends at the EX zero-flag register, not the
multiplier-tree register at the end of V6's first path.

## Measured outcome

The first reported path changes from decode-to-PC control to forwarding and
multiplier input logic. A revision can target a different path present in the
same report; the first path is not a complete description of the design's
timing. Use the [adjacent deltas](../analysis/README.md) to judge each
snapshot at matched requested constraints.

Compared with V6 at the common 500 MHz point, V7's reported power is lower
for both workloads, while V6 has a lower achieved period at 11 of 13 matched
tight constraints. Machine-readable values are in
[`../data/same_constraint_deltas.csv`](../data/same_constraint_deltas.csv).
