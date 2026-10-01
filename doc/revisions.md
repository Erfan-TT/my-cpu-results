# RTL revision rationale

The version sequence records the timing hypothesis behind each archived RTL
snapshot. Later snapshots inherit earlier structures unless the entry says
otherwise.

## V0 — structural baseline

V0 is the original five-stage implementation. Its dominant REG2REG path begins
at the fetch instruction register, passes through register-file access and
decode/branch logic, and ends in the fetch PC state. This establishes the main
optimization theme: shorten the ID-stage decision and redirect chain.

## V1 — parallel branch-condition evaluation

The branch decision originally selected the forwarded or register-file operand
and only then performed a 32-bit zero/sign reduction. That serializes a wide mux
and a reduction tree on the path to the PC.

V1 computes both candidate condition sets in parallel: one from the
register-file value and one from the already available forwarded ALU flags. A
single-bit selection chooses the result at the end. This changes
“mux, then compare” into “compare in parallel, then mux one bit.” It is the
clearest timing improvement in the sequence.

## V2 — parallel corrected-target comparisons

Misprediction detection originally selected a wide corrected target and then
compared that result with the predicted address. V2 duplicates the comparisons
for the possible target sources and selects a 1-bit comparison result.

The structural idea is similar to V1, but the cost is three comparator cones.
By this snapshot, the targeted chain is not consistently dominant, so some
constraints improve while others regress and median area rises.

## V3 — sign/zero metadata in the register file

The remaining decode path still contained a 32-bit zero detector after the
register-file read. V3 stores two metadata bits beside each integer register:
sign and zero. Those bits are produced from the actual write-back value, not
from EX flags, because a load's EX result is its address rather than the loaded
data.

The metadata array initializes to “sign=0, zero=1” so an unwritten architectural
register and its flags agree. Same-cycle write/read bypassing is applied to the
metadata as well as the 32-bit value.

## V4 — registered BTB update

The BTB update path appeared at the top of an early timing report, so V4 captures
the update request—branch PC, target, taken state and type bits—in a register and
applies it on the following cycle. Related `illegal_detector` guards were also
removed in the same snapshot.

The important post-analysis finding is that this path belongs to the `CLK`
clock-gating group, not the REG2REG group that limits clock period. V4 can improve
the path it targeted without improving achieved frequency. The additional
clocked state also produces the largest power increase in the series. Because
the register and guard removal were introduced together, their individual
power contributions are not isolated here.

## V5 — parallel special-register index guards

Special-register `rs2`/`rd` safety checks were nested inside a priority
`if/elsif` chain whose inputs included a register-file-dependent target. Those
fields feed hazard and stall decisions. V5 computes the out-of-range and
safe-field terms concurrently from the instruction and control fields, removing
the avoidable serialized dependency.

The logic transformation is reasonable, but the measured speed, area and power
differences are small and reverse with constraint.

## V6 — parallel forwarding requests

The forwarding unit tested EX-stage and MEM-stage producers with `if/elsif`,
which expresses a priority encoder. V6 computes the requests with independent
`if` statements because the final operand muxes already implement the required
selection priority.

This removes an avoidable comparison dependency. The effect is not uniform,
but V6 leads four of the 13 tight constraints, closes the sampled 1.6 ns target,
and produces the fastest individual run. It still contains V4's registered BTB
structure and associated power cost.

## V7 — retained datapath changes, BTB/index ablation

V7 starts from V6, keeps V3's sign/zero metadata and V6's parallel forwarding,
and removes the V4 registered-BTB structure together with the V5 index rewrite.

The resulting snapshot restores the lower power cluster on both workloads. V6
is faster at 11 of 13 matched tight constraints.

## Result tables

The complete paired-by-constraint results and per-version discussion are in
[`../analysis/README.md`](../analysis/README.md). Machine-readable adjacent
deltas are in
[`../data/same_constraint_deltas.csv`](../data/same_constraint_deltas.csv).
