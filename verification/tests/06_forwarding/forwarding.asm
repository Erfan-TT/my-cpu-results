;=============================================================================
;  06_forwarding -- every forwarding path, and the cases that must NOT forward
;=============================================================================
;  Checklist: C1 (EX->EX), C2 (MEM->EX), C3 (register-file read-during-write
;  bypass), C7 (link_bit and SP_read cancellation), C8 (no forwarding out of a
;  store or a branch), C10 (special-register scoreboard).
;  Load-use and load->store are in 07_load_use; the EX->ID branch path is in
;  10_branches.
;
;  Each distance is written the same way -- 100 + 7 = 107, then + 7 = 114 --
;  so all four of the first results must read 114.  A missing forward gives a
;  stale operand and a visibly different number, not a near miss.
;
;  Result map:
;    0 EX->EX rs1     1 EX->EX rs2     2 MEM->EX rs1    3 MEM->EX rs2
;    4 RF bypass      5 5-deep chain   6 store data     7 read after store
;    8 read after a taken branch       9 r31 after jr  10 r31 at distance 1
;   11 movs2i VBR    12 movs2i IAR
;=============================================================================

        .text

        addi r1, r0, 100
        addi r2, r0, 7

;---- C1: EX->EX, distance 1 -------------------------------------------------
        add  r3, r1, r2             ; 107
        add  r4, r3, r2             ; rs1 comes from EX  -> 114
        sw    0(r0), r4
        add  r5, r1, r2             ; 107
        add  r6, r2, r5             ; rs2 comes from EX  -> 114
        sw    4(r0), r6

;---- C2: MEM->EX, distance 2 ------------------------------------------------
        add  r7, r1, r2
        nop
        add  r8, r7, r2             ; rs1 comes from MEM -> 114
        sw    8(r0), r8
        add  r9, r1, r2
        nop
        add  r11, r2, r9            ; rs2 comes from MEM -> 114
        sw   12(r0), r11

;---- C3: register-file read-during-write bypass, distance 3 -----------------
        add  r12, r1, r2
        nop
        nop
        add  r13, r12, r2           ; producer is in WB  -> 114
        sw   16(r0), r13

;---- back-to-back chain: forwarding on every single instruction -------------
        addi r14, r0, 1
        add  r14, r14, r14          ; 2
        add  r14, r14, r14          ; 4
        add  r14, r14, r14          ; 8
        add  r14, r14, r14          ; 16
        sw   20(r0), r14

;---- C8: a store writes no register, so nothing may be forwarded from it ----
        addi r15, r0, 55
        sw   24(r0), r15            ; rs2 = r15 forwarded into the store
        add  r16, r15, r0           ; r15 is still 55, not the store address
        sw   28(r0), r16

;---- C8: a branch writes no register either ---------------------------------
        addi r17, r0, 3
        beqz r0, fw_cont            ; always taken
        addi r17, r0, 99            ; must be flushed, never executed
fw_cont:
        add  r18, r17, r0           ; still 3
        sw   32(r0), r18

;---- C7: the link value, not the ALU output ---------------------------------
;  jal writes r31 through the link path.  fw_sub reads r31 one instruction
;  later, so whatever the forwarding network hands over has to be PC+4 of the
;  jal -- which is the address of the 'sw 36' below, where jr returns to.
        jal  fw_sub
        sw   36(r0), r31            ; reached by the jr, stores its own address
        j    fw_after
fw_sub:
        add  r19, r31, r0           ; r31 at forwarding distance 1
        sw   40(r0), r19
        jr   r31
fw_after:

;---- C7 / C10: the special-register scoreboard ------------------------------
;  movs2i must not read the special register file before movi2s has written
;  it; the SP scoreboard holds the reader for two cycles.  Forwarding into a
;  movs2i's rs2 is cancelled, because that field is an SR index, not a GPR.
        addi r20, r0, 672
        movi2s VBR, r20
        movs2i r21, VBR             ; must see 672
        sw   44(r0), r21
        movi2s IAR, r1
        movs2i r22, IAR             ; must see 100
        sw   48(r0), r22

end:    j end
