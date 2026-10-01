;=============================================================================
;  09_mult_parallel -- the multiplier running alongside the rest of the pipe
;=============================================================================
;  Checklist: B2 (independent work issued under a multiply, out-of-order
;  writeback through the shadowed rd), B3 (dependent consumer at distances
;  1/2/3 -- only distance 1 may stall), B4 (back-to-back multiplies and the
;  structural hazard on the shared writeback port), B5 (a product deciding a
;  branch in ID), B6 (a multiply in flight across a jal/jr boundary).
;
;  The products themselves are trivial here on purpose; 08_multiplier already
;  proves the arithmetic.  What is under test is that the right value reaches
;  the right instruction at the right time.
;
;  Result map:
;    0 product, overlapped        1 independent work underneath it
;    2 consumer at distance 1     3 at distance 2      4 at distance 3
;    5 back-to-back A             6 back-to-back B     7 back-to-back C
;    8 dependent multiply chain   9 branch on a zero product
;   10 branch on a non-zero product          11 product across jal/jr
;   12 product as store data     13 WAW: ALU write over a multiply in flight
;   20 written through a product used as a store ADDRESS
;=============================================================================

        .text

        addi r1, r0, 6
        addi r2, r0, 7
        addi r3, r0, 3

;---- B2: the pipeline must not stop while the multiplier works --------------
        mult r4, r1, r2             ; 42, writes back out of order
        addi r5, r0, 11             ; none of these four may be delayed
        addi r6, r0, 12
        addi r7, r0, 13
        add  r8, r5, r6             ; 23
        add  r8, r8, r7             ; 36
        sw    0(r0), r4
        sw    4(r0), r8

;---- B3: the three consumer distances ---------------------------------------
        mult r9, r1, r2
        add  r11, r9, r0            ; distance 1, must stall
        sw    8(r0), r11            ; 42
        mult r12, r1, r3
        nop
        add  r13, r12, r0           ; distance 2
        sw   12(r0), r13            ; 18
        mult r14, r2, r3
        nop
        nop
        add  r15, r14, r0           ; distance 3
        sw   16(r0), r15            ; 21

;---- B4: back to back, three in a row ---------------------------------------
        mult r16, r1, r2            ; 42
        mult r17, r2, r3            ; 21
        mult r18, r1, r3            ; 18
        sw   20(r0), r16
        sw   24(r0), r17
        sw   28(r0), r18

;---- a chain where every multiply feeds the next ----------------------------
        addi r19, r0, 2
        mult r19, r19, r19          ; 4
        mult r19, r19, r19          ; 16
        mult r19, r19, r19          ; 256
        mult r19, r19, r19          ; 65536
        sw   32(r0), r19

;---- B5: the product is the branch condition, resolved in ID ----------------
        mult r20, r1, r0            ; 0
        beqz r20, mp_zero           ; must see the product, not a stale r20
        addi r21, r0, 111           ; flushed
mp_zero:
        addi r21, r0, 222
        sw   36(r0), r21
        mult r22, r1, r2            ; 42
        bnez r22, mp_nonzero
        addi r23, r0, 333           ; flushed
mp_nonzero:
        addi r23, r0, 444
        sw   40(r0), r23

;---- B6: a multiply still in flight when the subroutine returns -------------
        addi r24, r0, 9
        jal  mp_square
        sw   44(r0), r25            ; 81, completed across the jr
        j    mp_after
mp_square:
        mult r25, r24, r24
        jr   r31
mp_after:

;---- the product used as an address, and as store data ----------------------
        addi r26, r0, 4
        addi r27, r0, 20
        mult r28, r26, r27          ; 80
        sw    0(r28), r28           ; address AND data come from the multiply
        mult r29, r26, r26          ; 16
        sw   48(r0), r29

;---- WAW: an ALU write landing on a register a multiply still owns ----------
;  The multiplier writes back out of order and the scoreboard does not order
;  writes to the same destination.  The golden model retires in program order,
;  so it says 5.  A mismatch here is a design limitation worth knowing about,
;  not a bad stimulus -- see verification/README.md.
        mult r30, r1, r2            ; 42, in flight
        addi r30, r0, 5             ; overwrites it one instruction later
        sw   52(r0), r30

end:    j end
