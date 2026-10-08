# DLX functional verification checklist

The rows map test intentions to assembly programs. A named program means its
archived final-memory image can be checked against the reference; it does not
prove every internal event in the row occurred.

The original flow assembled each program, generated a reference memory image
with `dlxsim.py`, and compared it with the RTL final-memory image. The public
checker repeats the archived word-for-word comparison. Internal timing events
such as stalls and predictions need counters, assertions or waveforms; they
are marked **cycles** below.

---

## A. Datapath and ALU

| # | What | Test |
|---|---|---|
| A1 | `add` `addu` `sub` `subu`, incl. carry-out discarded and signed overflow wrap | 01_alu_rtype |
| A2 | `and` `or` `xor` | 01_alu_rtype |
| A3 | `sll` `srl` `sra` by register, amounts 0 / 1 / 31 / >31 (only `B[4:0]` counts), sign fill | 01_alu_rtype |
| A4 | `addi` `subi` sign-extend vs `addui` `subui` `andi` `ori` `xori` zero-extend, same 16-bit field | 02_alu_immediate |
| A5 | `slli` `srli` `srai` | 02_alu_immediate |
| A6 | `lhi` | 02_alu_immediate |
| A7 | R-type signed compares `seq sne slt sgt sle sge` | 03_set_compare |
| A8 | R-type unsigned compares `sltu sgtu sleu sgeu` | 03_set_compare |
| A9 | I-type signed compares | 03_set_compare |
| A10 | I-type unsigned compares, and the immediate's own extension | 03_set_compare |
| A11 | `r0` reads as zero; a write to `r0` is discarded | 04_r0_source, 05_r0_writeback |

## B. Multiplier

| # | What | Test |
|---|---|---|
| B1 | Booth/Dadda product: sign combinations, 0, ±1, INT_MIN, 2^15 and 2^16 squared, alternating-bit operands | 08_multiplier |
| B2 | independent instructions issued underneath a multiply; out-of-order writeback through the shadowed `rd` | 09_mult_parallel |
| B3 | dependent consumers at distances 1 / 2 / 3; exact stalls need cycle evidence | 09_mult_parallel; **cycles** |
| B4 | three back-to-back multiplies (structural hazard on the shared writeback, `shift_bit`) | 09_mult_parallel |
| B5 | a product as a branch condition resolved in ID | 09_mult_parallel |
| B6 | a multiply still in flight across a `jal` / `jr` boundary | 09_mult_parallel |
| B7 | a product used as a store address and as store data | 09_mult_parallel |
| B8 | WAW: an ALU write landing on a register a multiply still owns | 09_mult_parallel |

## C. Hazards and forwarding

| # | What | Test |
|---|---|---|
| C1 | EX→EX, `rs1` and `rs2` | 06_forwarding |
| C2 | MEM→EX, `rs1` and `rs2` | 06_forwarding |
| C3 | register-file read-during-write bypass (distance 3) | 06_forwarding |
| C4 | dependent load use at distance 1; exact stall count needs cycle evidence | 07_load_use; **cycles** |
| C5 | load → store data (`fw_mem_mem`) | 07_load_use |
| C6 | EX→ID forwarding of the branch condition flags | 10_branches (words 18–20) |
| C7 | forwarding cancelled for `link_bit` (jal/jalr) and `SP_read` (movs2i) | 06_forwarding |
| C8 | nothing forwards out of a store or a branch (`WF = 0`) | 06_forwarding |
| C9 | a discarded `r0` write must not forward at any distance | 04_r0_source, 05_r0_writeback |
| C10 | special-register scoreboard: `movi2s` then `movs2i` of the same SR | 06_forwarding |
| C11 | an address computed from a loaded value (pointer chase) | 07_load_use |
| C12 | a `jr`/`jalr` target register written 1 or 2 instructions earlier | 22_branch_operand_hazard, and in situ in 10_branches / 13_exceptions_min |
| C13 | a branch condition register written 1, 2 or 3 instructions earlier | 22_branch_operand_hazard |

## D. Control flow and branch prediction

| # | What | Test |
|---|---|---|
| D1 | `beqz bnez bltz blez bgtz bgez` against a negative, a zero and a positive operand — all 18 outcomes | 10_branches |
| D2 | `j`, `jal`, `jr`, `jalr`, and the link value | 10_branches |
| D3 | BTB cold miss on a branch's first execution | **cycles** — 11_btb_predictor |
| D4 | BTB hit once the row is allocated | **cycles** — 11_btb_predictor |
| D5 | loop re-entry; predictor state needs cycle evidence | 11_btb_predictor; **cycles** |
| D6 | mispredict-taken, repaired | 11_btb_predictor |
| D7 | mispredict-not-taken, repaired | 11_btb_predictor |
| D8 | two branches 64 bytes apart aliasing to the same BTB row (16 rows, index `pc[5:2]`) | 11_btb_predictor |
| D9 | one `jalr` whose target changes between executions | 11_btb_predictor |
| D10 | branch operand produced 1, 2 and 3 instructions earlier (there is no MEM→ID path, so distance 2 has to stall) | 10_branches |
| D11 | a taken branch landing directly on another branch | 10_branches |
| D12 | 2-bit hysteresis: a single not-taken must not flip a saturated prediction | **cycles** — not covered |

## E. Memory

| # | What | Test |
|---|---|---|
| E1 | `lw` / `sw` round trip; register base; positive and negative displacements | 12_memory_access, 07_load_use |
| E2 | `lb` / `lbu` on all four lanes, big-endian order | 12_memory_access |
| E3 | `lh` / `lhu` on both halves, sign vs zero extension | 12_memory_access |
| E4 | store then load the same address | 12_memory_access, 07_load_use |
| E5 | initial data memory is actually loaded from the `dmem_init` image | 12_memory_access, 07_load_use, 08_multiplier |
| E6 | a faulting access must not write memory | 13_exceptions_min |
| E7 | `USE_SLOW_DRAM=true`, the 2-cycle RWMEM handshake | mode `fs`: 07, 12, 15, 17 |
| E8 | `USE_ICACHE=true`, ROCACHE + ROMEM | mode `cf`: 11, 15, 16 |
| E9 | both at once | mode `cs`: 15 |
| E10 | `sb` / `sh` into each lane, with the rest of the word preserved | 21_store_subword |
| E11 | only the low byte / half of the source register is stored | 21_store_subword |
| E12 | a sub-word store is read-modify-write: the memory merges, it does not overwrite | 21_store_subword |
| E13 | the data bus carries a BYTE address; `store_size` + `ADDR[1:0]` pick the lane | 21_store_subword, 12_memory_access |

## F. Exceptions and special registers

| # | What | Test |
|---|---|---|
| F1 | illegal opcode / func → cause 0, `TVAL` = IR | 13_exceptions_min, 14_exceptions_full |
| F2 | `movi2s` / `movs2i` with an SR index ≥ 5 → cause 0 | 13_exceptions_min, 14_exceptions_full |
| F3 | `trap N` → cause 1, `TVAL` = zero-extended 26-bit field | 13_exceptions_min, 14_exceptions_full |
| F4 | taken jump to a misaligned target → cause 2, `TVAL` = target | 13_exceptions_min, 14_exceptions_full |
| F5 | misaligned `lw`/`sw`, and `lh`/`lhu` on an odd address → cause 3, `TVAL` = address | 13_exceptions_min, 14_exceptions_full |
| F6 | dispatch to the vector-table entry for each cause (`VBR + (cause << 2)` for a 16-byte-aligned VBR; see F13) | 13_exceptions_min, 14_exceptions_full |
| F7 | `IAR` holds the faulting PC; `rfe` returns to it | 13_exceptions_min, 14_exceptions_full |
| F8 | `STATUS` IE/EXL/PIE stacked on entry, restored by `rfe` | 14_exceptions_full |
| F9 | an odd-addressed `sb` does not fault; a misaligned `sh` raises cause 3 | 21_store_subword |
| F10 | not-taken branch with a misaligned target: no exception, BTB row invalidated (V0–V3, V7; V4–V6 remove the invalidation, see 23_misaligned_jump_repeat) | **not covered** |
| F11 | an exception raised inside a handler | **not covered** |
| F12 | scoreboard flushed on commit (`special_pc_sel`) | **cycles** — not covered |
| F13 | **VBR must be 16-byte aligned (V1 onward).** `branch_correction` builds the handler address by *substituting* CAUSE into PC bits 3:2 (`VBR_in(31 downto 4) & CAUSE_mem`), not by adding it. Nothing checks this, and a misaligned VBR silently dispatches to the wrong handler | every exception test aligns its table; nothing tests the violation |

## G. Integration

| # | What | Test |
|---|---|---|
| G1 | reset, first fetch from address 0 | every test |
| G2 | mixed program, differential against the golden model | 15_smoke_crosscheck, 17_given_branch_loop, 18_given_mult_shift, 19_given_all_general |
| G3 | I-cache-mode branch/jump redirects | 16_jal_return and 11_btb_predictor, mode `cf` — archived expected mismatches |
| G4 | long workload for switching activity | 20_power_bench, 24_mac_loops (multiplier-heavy) |
| G5 | stored results are compared as complete memory images | `scripts/check_verification.py` |
| G6 | cycles from reset to the final self-loop, per test and version | `data/cycle_counts.csv` |

---

## Gaps, in one place

- **D3**, **D4**, **D12** and **F12** concern internal predictor or pipeline
  events. Their exact behavior needs counters, assertions or waveforms.
- **F10** (misaligned target on a *not-taken* branch) and **F11** (nested
  exception) have no program yet.
- **F13**: nothing enforces or tests the 16-byte VBR alignment the hardware
  requires.
- **G3** has two archived expected mismatches in `cf` mode; see
  [`../data/verification_results.csv`](../data/verification_results.csv).
