;=============================================================================
;  01_alu_rtype -- R-type arithmetic, logic and register-amount shifts
;=============================================================================
;  Checklist: A1 (add/addu/sub/subu), A2 (and/or/xor), A3 (sll/srl/sra).
;
;  Every case lands in one word of data memory, in order, so a --compare
;  mismatch points straight at the operation.  Each 'sw' sits immediately
;  after its producer, so the store data also travels the EX->EX forwarding
;  path for rs2.
;
;  Result map (data word -> what is being checked):
;    0 add wide      1 add signed ovf   2 add carry-out    3 addu ovf
;    4 addu          5 sub wide         6 sub borrow       7 sub signed udf
;    8 subu          9 sub self        10 and            11 and ones
;   12 or           13 or zero         14 xor            15 xor self
;   16 xor ones     17 sll 1          18 sll 0          19 sll 31
;   20 sll 35(=3)   21 srl 1          22 srl 31         23 srl 0
;   24 sra 1        25 sra 31 neg     26 sra 31 pos     27 sra 35(=3)
;   28 sra 0
;=============================================================================

        .text

;---- operands ---------------------------------------------------------------
        lhi  r1, 0x5A5A
        ori  r1, r1, 0x0F0F         ; r1 = 0x5A5A0F0F
        lhi  r2, 0xA5A5
        ori  r2, r2, 0xF0F0         ; r2 = 0xA5A5F0F0  (= ~r1)
        addi r3, r0, 1              ; r3 = 1
        addi r4, r0, -1             ; r4 = 0xFFFFFFFF
        lhi  r5, 0x7FFF
        ori  r5, r5, 0xFFFF         ; r5 = 0x7FFFFFFF  (INT_MAX)
        lhi  r6, 0x8000             ; r6 = 0x80000000  (INT_MIN)
        addi r7, r0, 31             ; r7 = 31
        addi r8, r0, 35             ; r8 = 35  -> only the low 5 bits shift
        add  r9, r0, r0             ; r9 = 0

;---- add / addu -------------------------------------------------------------
        add  r10, r1, r2            ; 0xFFFFFFFF
        sw    0(r0), r10
        add  r10, r5, r3            ; INT_MAX+1 wraps to 0x80000000
        sw    4(r0), r10
        add  r10, r4, r3            ; -1+1, carry out is discarded -> 0
        sw    8(r0), r10
        addu r10, r5, r3            ; same adder, unsigned mnemonic
        sw   12(r0), r10
        addu r10, r4, r4            ; 0xFFFFFFFE
        sw   16(r0), r10

;---- sub / subu -------------------------------------------------------------
        sub  r10, r1, r2            ; 0xB4B41E1F
        sw   20(r0), r10
        sub  r10, r9, r3            ; 0-1 borrows -> 0xFFFFFFFF
        sw   24(r0), r10
        sub  r10, r6, r3            ; INT_MIN-1 wraps to 0x7FFFFFFF
        sw   28(r0), r10
        subu r10, r9, r4            ; 0-(-1) -> 1
        sw   32(r0), r10
        sub  r10, r4, r4            ; 0
        sw   36(r0), r10

;---- and / or / xor ---------------------------------------------------------
        and  r10, r1, r2            ; complementary patterns -> 0
        sw   40(r0), r10
        and  r10, r1, r4            ; identity
        sw   44(r0), r10
        or   r10, r1, r2            ; 0xFFFFFFFF
        sw   48(r0), r10
        or   r10, r1, r9            ; identity
        sw   52(r0), r10
        xor  r10, r1, r2            ; 0xFFFFFFFF
        sw   56(r0), r10
        xor  r10, r1, r1            ; 0
        sw   60(r0), r10
        xor  r10, r1, r4            ; ones-complement -> 0xA5A5F0F0
        sw   64(r0), r10

;---- sll --------------------------------------------------------------------
        sll  r10, r1, r3            ; << 1
        sw   68(r0), r10
        sll  r10, r1, r9            ; << 0  must be a no-op
        sw   72(r0), r10
        sll  r10, r3, r7            ; 1 << 31 -> 0x80000000
        sw   76(r0), r10
        sll  r10, r1, r8            ; << 35: only B[4:0] counts, so << 3
        sw   80(r0), r10

;---- srl --------------------------------------------------------------------
        srl  r10, r2, r3            ; logical >> 1, zero fill
        sw   84(r0), r10
        srl  r10, r6, r7            ; 0x80000000 >> 31 -> 1
        sw   88(r0), r10
        srl  r10, r4, r9            ; >> 0
        sw   92(r0), r10

;---- sra --------------------------------------------------------------------
        sra  r10, r2, r3            ; arithmetic >> 1, sign fill
        sw   96(r0), r10
        sra  r10, r6, r7            ; INT_MIN >> 31 -> 0xFFFFFFFF
        sw  100(r0), r10
        sra  r10, r5, r7            ; INT_MAX >> 31 -> 0
        sw  104(r0), r10
        sra  r10, r4, r8            ; >> 35 masks to >> 3, still all ones
        sw  108(r0), r10
        sra  r10, r1, r9            ; >> 0
        sw  112(r0), r10

end:    j end
