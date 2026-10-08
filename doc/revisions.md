# RTL revision record

V0 is the baseline. Each revision below states what changed, why, and what
the change did to achieved period, area and power. Achieved period is
`requested constraint − worst slack`: the period at which that netlist meets
timing. No revision changes the number of cycles a program takes: all 24 test
programs run in identical cycle counts on every version
([`../data/cycle_counts.csv`](../data/cycle_counts.csv)), so the period is the
whole performance story.

## How to read the measurements

Period and area are compared at the same 13 requested constraints
(1.00–1.60 ns, tuned script). A step reports how many of the 13 points got
faster and the median change. Power is compared at a common 500 MHz on the
two longer workloads, the mixed `20_power_bench` and the multiply-accumulate
`24_mac_loops`; each activity window covers one run of the program.

Synthesis results move with the constraint even when the RTL does not: the
same V0 RTL achieves 1.691 ns at the 1.15 ns constraint and 1.802 ns at
1.10 ns. A single point therefore says little. With 13 paired points, a
9/13 split occurs by chance about one time in four (two-sided sign test,
p ≈ 0.27); 11/13 or better (p ≈ 0.02) is treated here as a consistent effect.

Each section names the first path of the previous version's 1.0 ns report,
the starting point used during the RTL iteration. That path changes from one
constraint to the next, so the table below also counts where the first path
ends over all 21 tuned-script runs of each version.

| Version | Decode → PC/IR | EX zero flag | EX ALU result | Multiplier tree | Scoreboard | Other |
|---|---:|---:|---:|---:|---:|---:|
| V0 | 18 | — | 3 | 0 | 0 | 0 |
| V1 | 12 | 5 | 0 | 3 | 1 | 0 |
| V2 | 8 | 6 | 1 | 4 | 1 | 1 |
| V3 | 8 | 5 | 0 | 4 | 4 | 0 |
| V4 | 5 | 4 | 2 | 5 | 5 | 0 |
| V5 | 8 | 8 | 1 | 4 | 0 | 0 |
| V6 | 6 | 6 | 3 | 6 | 0 | 0 |
| V7 | 6 | 7 | 0 | 5 | 3 | 0 |

V0 is dominated by decode-to-fetch paths. From V1 onward the critical endpoints
spread across decode, the EX zero-flag register added in V1, the multiplier
and the scoreboard.

## Summary

| Step | Faster / 13 | Median period Δ | Median area Δ | 500 MHz power Δ (mixed / MAC) | Verdict |
|---|---:|---:|---:|---:|---|
| V0→V1 | **13** | **−149.3 ps** | −173 µm² | 0.0% / +0.1% | Clear speed gain; area and power unchanged |
| V1→V2 | 9 | −21.0 ps | +310 µm² | +0.2% / −0.2% | Speed within noise; area cost |
| V2→V3 | 9 | −23.7 ps | −302 µm² | **+2.1% / +2.5%** | Speed within noise; area saving; the one power cost |
| V3→V4 | 7 | −2.0 ps | +148 µm² | +0.8% / −0.2% | No speed change alone |
| V4→V5 | 8 | −12.5 ps | +35 µm² | +1.0% / +0.9% | Within noise |
| V5→V6 | 9 | −13.3 ps | −122 µm² | −0.9% / −1.1% | Within noise |
| V6→V7 | 2 | +16.0 ps | −21 µm² | −2.6% / 0.0% | Slower than V6 at 11/13; less energy per run at 13/13 |

Two comparisons outside the adjacent chain isolate the later edits:

- **V3→V7 differs only in `forwarding.vhd`**, so it tests V6's forwarding
  edit on its own. V7 is faster at 6/13 points, median +3.6 ps, area +5 µm²:
  the edit alone has no consistent effect.
- **V3→V6 carries V4, V5 and V6 together.** V6 is faster at 11/13 points,
  median −15.8 ps, at nearly the same 500 MHz power (+0.9% / −0.4%).
  Since V7 shows the
  forwarding edit does not produce this gain, it comes from the V4/V5
  edits, which are individually below the noise floor but consistent
  together.

The V4–V6 group buys about 16 ps of median period at no real cost in power
at 500 MHz. At each version's fastest netlist, though, V6 needs more area
and energy than V3 for its last 6 ps.

## V1 — branch and redirect restructuring

Previous report: [V0 timing](../evidence/synthesis/V0/new/timing_1p0.rpt),
`DP_i_fetch_i_IR_out_reg_24_` → `DP_i_fetch_i_pc_i_Y_reg_0_`.

Instruction bit 24 belongs to the source-register field; the path runs
through decode and the branch decision into the PC. V0 is dominated by this
family (18 of 21 first paths end at the PC or instruction register). The
main V1 edit computes the branch condition from the register-file value and
from forwarded EX flags in parallel, then selects the one-bit result.

V1 also contains:

- Branch correction computes taken and not-taken target mismatches
  separately, then selects a one-bit mismatch for `flush`.
- EX registers sign and zero flags derived from its selected result; those
  flags feed decode's branch decision when EX-to-ID forwarding is selected.
- The explicit MEM-to-ID forwarding path is removed. Decode retains EX-to-ID
  forwarding and uses the register file's same-cycle write/read bypass for
  the write-back value. `hazard_detection.vhd` is unchanged from V0, so the
  branch stall conditions are the same, and the cycle counts are identical.
- Exception-vector selection no longer adds `VBR + 4·cause` in the shared
  adder; it places the cause in address bits 3:2 of VBR. The two are equal
  only when VBR is 16-byte aligned, which software must now guarantee.

**Result:** faster than V0 at all 13 points, median −149.3 ps (−252.6 ps at
1.0 ns: 1.7523 → 1.4997 ns), median area −173 µm², power at 500 MHz
unchanged. The new EX zero-flag register becomes a recurring critical
endpoint in every later version (4–8 of 21 first paths).

## V2 — parallel target comparisons

Previous report: [V1 timing](../evidence/synthesis/V1/new/timing_1p0.rpt),
`DP_i_fetch_i_IR_out_reg_21_` → `DP_i_fetch_i_pc_i_Y_reg_5_`.

Instruction bit 21 is a source-register bit; the decode operand can select a
corrected branch or jump target that redirects the PC. V1 compared the
predicted target with the selected correct target. V2 compares the predicted
target with all three candidate targets in parallel, so the comparison no
longer waits for the 30-bit target selection; a one-bit selector then picks
the mismatch.

**Result:** faster at 9/13 points, median −21.0 ps, within the noise floor
(+100.0 ps at 1.0 ns: 1.4997 → 1.5997 ns). Median area +310 µm² for the extra
comparators. Decode-to-fetch first paths fall from 12 to 8 of 21.

## V3 — register sign/zero metadata

Previous report: [V2 timing](../evidence/synthesis/V2/new/timing_1p0.rpt),
`DP_i_fetch_i_IR_out_reg_30_` → `DP_i_fetch_i_pc_i_Y_reg_19_`.

Instruction bit 30 is part of the opcode; the path is instruction decode to
PC redirect. V3 stores sign and zero bits beside each integer register.
Write-back computes them from the value actually written, and the register
file bypasses them on a same-cycle read/write match. Branch decisions read
those bits instead of reducing a 32-bit register value to detect zero.

**Result:** faster at 9/13 points, median −23.7 ps, within the noise floor
(−184.3 ps at 1.0 ns: 1.5997 → 1.4154 ns). Median area −302 µm². The stored
flags are the one change in the series that costs power: +2.1% / +2.5% at
500 MHz on the mixed / MAC programs. V3 is still the best balanced revision:
its fastest netlist is within 6 ps of V6's, with 820 µm² less area and the
lowest energy × time of any version (see the [analysis](../analysis/README.md)).

## V4 — registered BTB update

Previous report: [V3 timing](../evidence/synthesis/V3/new/timing_1p0.rpt),
`DP_i_mem_access_i_rd_out_reg_i_Y_reg_1_` →
`DP_i_execute_i_boothmul_i_tree_i_register_i_2_Y_temp_reg_30_`.

The first path is MEM/WB destination index → EX forwarding select →
multiplier operand. V4 targets a different family in the same report: paths
into the BTB clock-gating enables, for example
`DP_i_fetch_i_btb_i_clk_gate_btb_table_reg_4__PC_/latch` at −0.272 ns. The
BTB write enable depended on the corrected target, including the alignment
check on its two low bits, and therefore on the register-file read. V4
registers the BTB update request before the table write and removes the
illegal-detector guards and invalidation logic from the BTB inputs.

Removing the invalidation means a misaligned jump can now be entered in the
BTB with its target truncated to bits 31:2. Test
`23_misaligned_jump_repeat` checks that the exception is still raised on
every execution. Writing the BTB one cycle later does not change any
prediction: the instruction fetched next is never the branch updating its
row, and every test runs in the same number of cycles as on V3.

**Result:** across the 13 tight runs, the reported paths ending in the BTB
fall from 133 in V3 to 95 in V4 (126 again in V7). Speed alone does not
change (7/13, median −2.0 ps; +30.2 ps at 1.0 ns: 1.4154 → 1.4456 ns), and
neither does power at 500 MHz (+0.8% / −0.2%).

## V5 — special-register index guards

Previous report: [V4 timing](../evidence/synthesis/V4/new/timing_1p0.rpt),
`DP_i_decode_i_rs2_addr_i_Y_reg_0_` →
`DP_i_execute_i_boothmul_i_tree_i_register_i_3_Y_temp_reg_28_`.

The first path is the ID/EX `rs2` index → EX forwarding select → multiplier
operand. V5 instead targets decode and hazard control: it moves
special-register index guarding out of the target-dependent exception process
into separate combinational terms.

**Result:** scoreboard first paths fall from 5 of 21 in V4 to 0 in V5. The
period change is within noise (8/13, median −12.5 ps; +26.1 ps at 1.0 ns:
1.4456 → 1.4717 ns); area and power are unchanged.

## V6 — independent forwarding requests

Previous report: [V5 timing](../evidence/synthesis/V5/new/timing_1p0.rpt),
`DP_i_decode_i_rs2_addr_i_Y_reg_0_` →
`DP_i_execute_i_boothmul_i_tree_i_register_i_3_Y_temp_reg_30_`.

The same `rs2`-index-to-multiplier route is first in V5's report. V6 replaces
the `if/elsif` EX/MEM forwarding checks with independent `if` checks for each
execute operand; the operand mux keeps EX priority when both requests are
asserted. This edit is on the reported route.

**Result:** within noise (9/13, median −13.3 ps; −62.1 ps at 1.0 ns:
1.4717 → 1.4096 ns, the fastest run of the study). V7 tests the same edit on
V3 and finds no consistent effect, so the V6 gain over V3 is not from this
edit.

## V7 — combined rollback

Previous report: [V6 timing](../evidence/synthesis/V6/new/timing_1p0.rpt),
`DP_i_mem_access_i_rd_out_reg_i_Y_reg_0_` →
`DP_i_execute_i_boothmul_i_tree_i_register_i_3_Y_temp_reg_31_`.

V7 starts again from V3, keeps V6's forwarding checks, and drops V4's
registered BTB update and V5's special-index rewrite. Apart from
`forwarding.vhd`, V7 is identical to V3. It was built as a power rollback,
when a fixed activity window, mostly filled by each program's final idle
loop, showed V4–V6 costing 6–7% power at 500 MHz. With windows that end with
the program, that cost is +0.9% / −0.4% against V3, so the rollback removes
little power.

**Result:** V7 is slower than V6 at 11/13 points (median +16.0 ps; +95.9 ps
at 1.0 ns: 1.4096 → 1.5055 ns), where the first path now ends at the EX
zero-flag register. Against V3 it is unchanged (6/13, median +3.6 ps). At
matched constraints its netlists use less energy per run than V6's at all
13 points (median −1.3 nJ mixed, −1.7 nJ MAC, about 3%).

## Outcome

- V1 is the one clear, consistent speed improvement (13/13, −149 ps median).
- V2 and V3 move the median by about 20 ps each, below the noise floor
  individually; V3 also recovers V2's area.
- V3's stored flags cost 2–2.5% power at 500 MHz; no other step costs more
  than 1%.
- V4–V6 together gain about 16 ps median over V3 at nearly the same power.
  V6's forwarding edit alone does not provide that gain.
- V7 gives up that speed gain for about 3% less energy per run than V6.

Machine-readable values are in
[`../data/same_constraint_deltas.csv`](../data/same_constraint_deltas.csv)
and [`../data/pairwise_speed_wins.csv`](../data/pairwise_speed_wins.csv).
