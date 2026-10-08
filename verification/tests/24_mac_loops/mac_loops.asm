;=============================================================================
;  24_mac_loops -- multiply-accumulate workload for switching activity
;=============================================================================
;  Purpose: a power workload that keeps the Booth/Dadda multiplier busy for the
;  whole measured window.  08_multiplier checks products on corner operands and
;  reaches its final self-loop in under 100 cycles; this program loops, so the
;  activity it records is multiply-accumulate work, not the idle loop.
;
;  Five kernels, run r28 times (outer passes):
;    K1  dot product x.y, one accumulator     the add consumes each product at
;                                             distance 1 -- the stalling case
;    K2  dot product x.y, four accumulators   unrolled x4, up to four products
;                                             in flight, loads issued between
;    K3  4-tap FIR  out[n] = sum h[k]*x[n-k]  n = 3..15, four products per
;                                             output, results stored
;    K4  Horner     a3*x^3 + a2*x^2 + a1*x + a0, mult -> add -> mult chain
;    K5  element-wise x[i]*y[i]               the product goes straight to sw
;  K1 and K2 compute the same dot product two ways and must agree.  Each pass
;  folds its results into a running checksum, then adds 0x1357 to x[0], so
;  every pass multiplies different numbers.
;
;  Length knob: r28 at 'main'.  At 4 passes the program reaches its final
;  self-loop after a few thousand cycles.
;
;  Data map (data RAM byte address / word index):
;      0x000 /  0..15   vec_x     16 input words   <- .data
;      0x040 / 16..31   vec_y     16 input words   <- .data
;      0x080 / 32..35   coef      FIR taps h0..h3  <- .data
;      0x090 / 36..39   poly      a0..a3           <- .data
;      0x0A0 / 40..55   fir_out   K3, n = 0..15 (n = 0..2 stay 0)
;      0x0E0 / 56..71   poly_out  K4 at each x
;      0x120 / 72..87   prod_out  K5
;      0x160 / 88       K1 dot product, last pass
;      0x164 / 89       K2 dot product, last pass (equals word 88)
;      0x168 / 90       running checksum
;      0x16C / 91       passes completed
;=============================================================================

        .text

main:
        addi r28, r0, 4                 ; <-- outer passes, the length knob
        add  r20, r0, r0                ; running checksum
        add  r27, r0, r0                ; passes completed
        addi r3,  r0, scalars

;=============================================================================
outer:
;-----------------------------------------------------------------------------
;  K1 -- dot product, one accumulator.  The add right after each mult waits
;  for the product: the multiplier's dependent path.
;-----------------------------------------------------------------------------
        addi r1, r0, vec_x
        addi r2, r0, vec_y
        addi r4, r0, 16
        add  r10, r0, r0

k1:
        lw   r5, 0(r1)
        lw   r6, 0(r2)
        mult r7, r5, r6
        add  r10, r10, r7               ; product consumed at distance 1
        addi r1, r1, 4
        addi r2, r2, 4
        subi r4, r4, 1
        bnez r4, k1

;-----------------------------------------------------------------------------
;  K2 -- the same dot product, unrolled x4 into four accumulators.  Loads are
;  issued underneath the multiplies, and the adds come last, so up to four
;  products are in flight.
;-----------------------------------------------------------------------------
        addi r1, r0, vec_x
        addi r2, r0, vec_y
        addi r4, r0, 4
        add  r11, r0, r0
        add  r12, r0, r0
        add  r13, r0, r0
        add  r14, r0, r0

k2:
        lw   r5, 0(r1)
        lw   r6, 0(r2)
        lw   r7, 4(r1)
        lw   r8, 4(r2)
        mult r15, r5, r6
        lw   r5, 8(r1)
        lw   r6, 8(r2)
        mult r16, r7, r8
        lw   r7, 12(r1)
        lw   r8, 12(r2)
        mult r17, r5, r6
        mult r18, r7, r8
        add  r11, r11, r15
        add  r12, r12, r16
        add  r13, r13, r17
        add  r14, r14, r18
        addi r1, r1, 16
        addi r2, r2, 16
        subi r4, r4, 1
        bnez r4, k2

        add  r11, r11, r12
        add  r13, r13, r14
        add  r11, r11, r13              ; K2 result, must equal r10

;-----------------------------------------------------------------------------
;  K3 -- 4-tap FIR over x, out[n] = h0*x[n] + h1*x[n-1] + h2*x[n-2] + h3*x[n-3]
;  for n = 3..15.  The taps stay in r21..r24 for the whole kernel.
;-----------------------------------------------------------------------------
        addi r1, r0, coef
        lw   r21, 0(r1)
        lw   r22, 4(r1)
        lw   r23, 8(r1)
        lw   r24, 12(r1)
        addi r1, r0, vec_x
        addi r1, r1, 12                 ; &x[3]
        addi r2, r0, fir_out
        addi r2, r2, 12                 ; &out[3]
        addi r4, r0, 13

k3:
        lw   r5, 0(r1)
        lw   r6, -4(r1)
        lw   r7, -8(r1)
        lw   r8, -12(r1)
        mult r15, r5, r21
        mult r16, r6, r22
        mult r17, r7, r23
        mult r18, r8, r24
        add  r15, r15, r16
        add  r17, r17, r18
        add  r15, r15, r17
        sw   0(r2), r15
        add  r20, r20, r15
        addi r1, r1, 4
        addi r2, r2, 4
        subi r4, r4, 1
        bnez r4, k3

;-----------------------------------------------------------------------------
;  K4 -- Horner evaluation of a3*x^3 + a2*x^2 + a1*x + a0 at every x.  Each
;  mult needs the add before it, and each add the mult before it.
;-----------------------------------------------------------------------------
        addi r1, r0, poly
        lw   r21, 0(r1)                 ; a0
        lw   r22, 4(r1)                 ; a1
        lw   r23, 8(r1)                 ; a2
        lw   r24, 12(r1)                ; a3
        addi r1, r0, vec_x
        addi r2, r0, poly_out
        addi r4, r0, 16

k4:
        lw   r5, 0(r1)
        mult r6, r24, r5
        add  r6, r6, r23
        mult r6, r6, r5
        add  r6, r6, r22
        mult r6, r6, r5
        add  r6, r6, r21
        sw   0(r2), r6
        add  r20, r20, r6
        addi r1, r1, 4
        addi r2, r2, 4
        subi r4, r4, 1
        bnez r4, k4

;-----------------------------------------------------------------------------
;  K5 -- element-wise product, stored straight from the multiplier.
;-----------------------------------------------------------------------------
        addi r1, r0, vec_x
        addi r2, r0, vec_y
        addi r9, r0, prod_out
        addi r4, r0, 16

k5:
        lw   r5, 0(r1)
        lw   r6, 0(r2)
        mult r7, r5, r6
        sw   0(r9), r7                  ; product as store data
        xor  r20, r20, r7
        addi r1, r1, 4
        addi r2, r2, 4
        addi r9, r9, 4
        subi r4, r4, 1
        bnez r4, k5

;-----------------------------------------------------------------------------
;  end of pass: record K1/K2, fold them into the checksum, change x[0]
;-----------------------------------------------------------------------------
        sw   0(r3), r10                 ; 0x160  K1
        sw   4(r3), r11                 ; 0x164  K2
        add  r20, r20, r10
        add  r20, r20, r11
        addi r1, r0, vec_x
        lw   r5, 0(r1)
        addi r5, r5, 0x1357
        sw   0(r1), r5
        addi r27, r27, 1
        subi r28, r28, 1
        bnez r28, outer

        sw   8(r3), r20                 ; 0x168  checksum
        sw   12(r3), r27                ; 0x16C  passes

end:    j end

;=============================================================================
        .data 0

vec_x:                                  ; 0x000
        .word 0x00001234, 0xFFFFFF85, 0x7FFF0001, 0x00010001
        .word 0x80000003, 0x0000FFFF, 0x12345678, 0xFEDCBA98
        .word 0x00000007, 0x55555555, 0xAAAAAAAB, 0x0F0F0F0F
        .word 0xF0F0F0F1, 0x000003E8, 0xDEADBEEF, 0x00C0FFEE

vec_y:                                  ; 0x040
        .word 0x00000011, 0x00ABCDEF, 0xFFFF0003, 0x0000FFFE
        .word 0x00000002, 0x7FFFFFFF, 0x9ABCDEF0, 0x00000101
        .word 0xCAFEBABE, 0x33333333, 0x00000005, 0xFFFFFFFF
        .word 0x13579BDF, 0x2468ACE0, 0x0000FFFF, 0x80000001

coef:                                   ; 0x080  h0..h3
        .word 0x00000003, 0xFFFFFFFB, 0x00000007, 0x0000000B

poly:                                   ; 0x090  a0..a3
        .word 0x00000011, 0xFFFFFFFD, 0x00000005, 0x00000002

fir_out:                                ; 0x0A0
        .space 64
poly_out:                               ; 0x0E0
        .space 64
prod_out:                               ; 0x120
        .space 64
scalars:                                ; 0x160
        .space 16
