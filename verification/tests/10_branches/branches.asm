;=============================================================================
;  10_branches -- every branch and jump, both outcomes, and the ID condition
;=============================================================================
;  Checklist: D1 (beqz/bnez/bltz/blez/bgtz/bgez against a negative, a zero and
;  a positive operand -- 18 outcomes), D2 (j / jal / jr / jalr and the link
;  value), D10 (the branch operand produced 1, 2 and 3 instructions earlier),
;  D11 (back-to-back taken branches), plus a backward loop.
;
;  Prediction behaviour is 11_btb_predictor's job.  Here each branch is
;  executed once, so every one of them is a BTB cold miss.
;
;  The shape of a case is always the same four instructions:
;        addi r10, r0, 1      ; assume taken
;        b??  rX, L
;        addi r10, r0, 0      ; only reached when NOT taken
;    L:  sw   N(r0), r10
;  so every result word is 1 for taken and 0 for not taken.
;
;  Result map (word : branch / operand):
;     0 beqz -5   1 beqz 0   2 beqz +5      3 bnez -5   4 bnez 0   5 bnez +5
;     6 bltz -5   7 bltz 0   8 bltz +5      9 blez -5  10 blez 0  11 blez +5
;    12 bgtz -5  13 bgtz 0  14 bgtz +5     15 bgez -5  16 bgez 0  17 bgez +5
;    18 condition at distance 1   19 at distance 3   20 at distance 4
;    21 backward loop trip count  22 jal link    23 reached past j
;    24 jalr link                 25 jalr callee ran     26 back-to-back
;=============================================================================

        .text

        addi r1, r0, -5             ; negative
        add  r2, r0, r0             ; zero
        addi r3, r0, 5              ; positive

;---- beqz -------------------------------------------------------------------
        addi r10, r0, 1
        beqz r1, e0
        addi r10, r0, 0
e0:     sw    0(r0), r10
        addi r10, r0, 1
        beqz r2, e1
        addi r10, r0, 0
e1:     sw    4(r0), r10
        addi r10, r0, 1
        beqz r3, e2
        addi r10, r0, 0
e2:     sw    8(r0), r10

;---- bnez -------------------------------------------------------------------
        addi r10, r0, 1
        bnez r1, n0
        addi r10, r0, 0
n0:     sw   12(r0), r10
        addi r10, r0, 1
        bnez r2, n1
        addi r10, r0, 0
n1:     sw   16(r0), r10
        addi r10, r0, 1
        bnez r3, n2
        addi r10, r0, 0
n2:     sw   20(r0), r10

;---- bltz -------------------------------------------------------------------
        addi r10, r0, 1
        bltz r1, l0
        addi r10, r0, 0
l0:     sw   24(r0), r10
        addi r10, r0, 1
        bltz r2, l1
        addi r10, r0, 0
l1:     sw   28(r0), r10
        addi r10, r0, 1
        bltz r3, l2
        addi r10, r0, 0
l2:     sw   32(r0), r10

;---- blez -------------------------------------------------------------------
        addi r10, r0, 1
        blez r1, le0
        addi r10, r0, 0
le0:    sw   36(r0), r10
        addi r10, r0, 1
        blez r2, le1
        addi r10, r0, 0
le1:    sw   40(r0), r10
        addi r10, r0, 1
        blez r3, le2
        addi r10, r0, 0
le2:    sw   44(r0), r10

;---- bgtz -------------------------------------------------------------------
        addi r10, r0, 1
        bgtz r1, g0
        addi r10, r0, 0
g0:     sw   48(r0), r10
        addi r10, r0, 1
        bgtz r2, g1
        addi r10, r0, 0
g1:     sw   52(r0), r10
        addi r10, r0, 1
        bgtz r3, g2
        addi r10, r0, 0
g2:     sw   56(r0), r10

;---- bgez -------------------------------------------------------------------
        addi r10, r0, 1
        bgez r1, ge0
        addi r10, r0, 0
ge0:    sw   60(r0), r10
        addi r10, r0, 1
        bgez r2, ge1
        addi r10, r0, 0
ge1:    sw   64(r0), r10
        addi r10, r0, 1
        bgez r3, ge2
        addi r10, r0, 0
ge2:    sw   68(r0), r10

;---- D10: where the condition comes from -----------------------------------
;  The branch resolves in ID.  At distance 1 the producer is still in EX and
;  its zero/sign flags are forwarded EX->ID; at distance 3 and beyond the
;  register file bypass covers it.  Distance 2 is the hole -- see
;  22_branch_operand_hazard, which owns that case.
;
;  r5 is deliberately NON-zero before each producer, so a stale read gives a
;  different answer instead of the same one by luck.
        addi r5, r0, 7
        addi r10, r0, 1
        add  r5, r0, r0             ; zero, produced right before the branch
        beqz r5, d1
        addi r10, r0, 0
d1:     sw   72(r0), r10            ; distance 1

        addi r5, r0, 7
        addi r10, r0, 1
        add  r5, r0, r0
        nop
        nop
        beqz r5, d3
        addi r10, r0, 0
d3:     sw   76(r0), r10            ; distance 3

        addi r5, r0, 7
        addi r10, r0, 1
        add  r5, r0, r0
        nop
        nop
        nop
        beqz r5, d4
        addi r10, r0, 0
d4:     sw   80(r0), r10            ; distance 4

;---- a backward branch, ten trips -------------------------------------------
        addi r11, r0, 10
        add  r12, r0, r0
bloop:  addi r12, r12, 1
        subi r11, r11, 1
        bnez r11, bloop
        sw   84(r0), r12            ; 10

;---- D2: jal / jr, j over dead code -----------------------------------------
        jal  bsub
        sw   88(r0), r31            ; the link value is this instruction's own address
        j    bskip
        addi r13, r0, 777           ; must never execute
bskip:
        addi r14, r0, 5
        sw   92(r0), r14
        j    balr
bsub:
        addi r15, r0, 1
        jr   r31

;---- D2: jalr / jr through a register target --------------------------------
balr:
        addi r16, r0, balr_sub
        jalr r16                    ; target register produced right before it
        sw   96(r0), r31            ; jalr links too
        j    bend
balr_sub:
        addi r17, r0, 2
        jr   r31
bend:
        sw  100(r0), r17            ; 2, proves the callee ran

;---- D11: a taken branch landing directly on another branch -----------------
        add  r18, r0, r0
        beqz r18, bb1
        addi r18, r0, 99            ; dead
bb1:    beqz r18, bb2
        addi r18, r0, 88            ; dead
bb2:    addi r18, r18, 3
        sw  104(r0), r18            ; 3

end:    j end
