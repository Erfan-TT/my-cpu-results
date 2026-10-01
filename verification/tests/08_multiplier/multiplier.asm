;=============================================================================
;  08_multiplier -- Booth / Dadda correctness on the corner operands
;=============================================================================
;  Checklist: B1.  Timing and overlap are 09_mult_parallel's job; this file is
;  only about the product being right.
;
;  mult is a 32x32 -> low 32 multiply, so signed and unsigned agree on the
;  result and the cases that matter are the ones that stress Booth recoding:
;  zero, +1 and -1 multipliers (the "+1 correction" terms), runs of 01 and 10
;  pairs (0x55555555 / 0xAAAAAAAA), the powers of two that land exactly on the
;  32-bit boundary, and INT_MIN, whose negation does not fit.
;
;  Every 'sw' sits directly on top of its mult, so each case is also a
;  dependent consumer at distance 1 -- the multiplier's stall path.
;
;  Result map:
;    0  6*7          1 (-6)*(-7)    2  6*(-7)      3 (-6)*7
;    4  6*0          5  0*6         6  x*1         7  1*x
;    8  x*(-1)       9 (-1)*(-1)   10  INT_MIN*1  11  INT_MIN*(-1)
;   12  INT_MIN^2   13  INT_MAX*2  14  2^16 sq    15  2^15 sq
;   16  0x55555555*3               17  0xAAAAAAAA*3
;   18  0x12345678*0x9ABCDEF0      19  0x9ABCDEF0 squared
;   20  0x55555555*0xAAAAAAAA
;=============================================================================

        .text

        addi r20, r0, ops
        lw   r1,  0(r20)            ; 0x80000000  INT_MIN
        lw   r2,  4(r20)            ; 0x7FFFFFFF  INT_MAX
        lw   r3,  8(r20)            ; 0xFFFFFFFF  -1
        lw   r4, 12(r20)            ; 0x00010000  2^16
        lw   r5, 16(r20)            ; 0x00008000  2^15
        lw   r6, 20(r20)            ; 0x55555555
        lw   r7, 24(r20)            ; 0xAAAAAAAA
        lw   r8, 28(r20)            ; 0x12345678
        lw   r9, 32(r20)            ; 0x9ABCDEF0
        addi r11, r0, 6
        addi r12, r0, -6
        addi r13, r0, 7
        addi r14, r0, -7
        addi r15, r0, 3
        addi r17, r0, 1
        addi r18, r0, 2

;---- sign combinations ------------------------------------------------------
        mult r16, r11, r13          ; 42
        sw    0(r0), r16
        mult r16, r12, r14          ; 42
        sw    4(r0), r16
        mult r16, r11, r14          ; -42
        sw    8(r0), r16
        mult r16, r12, r13          ; -42
        sw   12(r0), r16

;---- zero and identity, on both operand positions ---------------------------
        mult r16, r11, r0           ; 0
        sw   16(r0), r16
        mult r16, r0, r11           ; 0
        sw   20(r0), r16
        mult r16, r8, r17           ; identity
        sw   24(r0), r16
        mult r16, r17, r8           ; identity, other side
        sw   28(r0), r16

;---- the -1 multiplier: Booth's negative partial products -------------------
        mult r16, r8, r3            ; two's-complement negate
        sw   32(r0), r16
        mult r16, r3, r3            ; (-1)*(-1) = 1
        sw   36(r0), r16

;---- INT_MIN, whose negation does not fit in 32 bits ------------------------
        mult r16, r1, r17           ; 0x80000000
        sw   40(r0), r16
        mult r16, r1, r3            ; wraps back to 0x80000000
        sw   44(r0), r16
        mult r16, r1, r1            ; 2^62, low 32 bits are 0
        sw   48(r0), r16
        mult r16, r2, r18           ; INT_MAX*2 -> 0xFFFFFFFE
        sw   52(r0), r16

;---- products that fall on the 32-bit boundary ------------------------------
        mult r16, r4, r4            ; 2^32, low 32 bits are 0
        sw   56(r0), r16
        mult r16, r5, r5            ; 2^30
        sw   60(r0), r16

;---- alternating-bit operands: every Booth pair is exercised ----------------
        mult r16, r6, r15           ; 0x55555555 * 3
        sw   64(r0), r16
        mult r16, r7, r15           ; 0xAAAAAAAA * 3
        sw   68(r0), r16
        mult r16, r8, r9
        sw   72(r0), r16
        mult r16, r9, r9
        sw   76(r0), r16
        mult r16, r6, r7
        sw   80(r0), r16

end:    j end

;=============================================================================
        .data 128

ops:    .word 0x80000000            ; INT_MIN
        .word 0x7FFFFFFF            ; INT_MAX
        .word 0xFFFFFFFF            ; -1
        .word 0x00010000            ; 2^16
        .word 0x00008000            ; 2^15
        .word 0x55555555
        .word 0xAAAAAAAA
        .word 0x12345678
        .word 0x9ABCDEF0
