;=============================================================================
;  03_set_compare -- all 22 set-compares, signed against unsigned
;=============================================================================
;  Checklist: A7 (R-type signed), A8 (R-type unsigned), A9 (I-type signed),
;             A10 (I-type unsigned).
;
;  These are the instructions this CPU got wrong twice: the four R-type
;  unsigned compares were missing from CU_HW_LUT's func case and trapped as
;  illegal, and the four I-type unsigned ones decoded to the SIGNED ALU op, so
;  every result was inverted.  Both bugs are invisible unless a test compares
;  a value whose sign bit is set against a small positive one -- which is what
;  every block below does.
;
;  Blocks, in order:
;    words  0..9   R-type, -1 vs 1       (signed: less; unsigned: greater)
;    words 10..19  R-type, 1 vs 1        (the equality boundary)
;    words 20..23  R-type, INT_MIN vs INT_MAX  (signed and unsigned disagree)
;    words 24..33  I-type, -1 vs 1
;    words 34..43  I-type, 1 vs 1
;    words 44..47  I-type, the immediate's own extension
;
;  Within a block the order is always:
;    seq sne slt sgt sle sge sltu sgtu sleu sgeu
;=============================================================================

        .text

        addi r1, r0, -1             ; 0xFFFFFFFF : -1 signed, 4294967295 unsigned
        addi r2, r0, 1
        lhi  r3, 0x8000             ; INT_MIN
        lhi  r4, 0x7FFF
        ori  r4, r4, 0xFFFF         ; INT_MAX
;---- R-type, -1 vs 1 ---------------------------------------------
        seq    r10, r1, r2
        sw     0(r0), r10
        sne    r10, r1, r2
        sw     4(r0), r10
        slt    r10, r1, r2
        sw     8(r0), r10
        sgt    r10, r1, r2
        sw    12(r0), r10
        sle    r10, r1, r2
        sw    16(r0), r10
        sge    r10, r1, r2
        sw    20(r0), r10
        sltu   r10, r1, r2
        sw    24(r0), r10
        sgtu   r10, r1, r2
        sw    28(r0), r10
        sleu   r10, r1, r2
        sw    32(r0), r10
        sgeu   r10, r1, r2
        sw    36(r0), r10

;---- R-type, 1 vs 1 : the equality boundary ----------------------
        seq    r10, r2, r2
        sw    40(r0), r10
        sne    r10, r2, r2
        sw    44(r0), r10
        slt    r10, r2, r2
        sw    48(r0), r10
        sgt    r10, r2, r2
        sw    52(r0), r10
        sle    r10, r2, r2
        sw    56(r0), r10
        sge    r10, r2, r2
        sw    60(r0), r10
        sltu   r10, r2, r2
        sw    64(r0), r10
        sgtu   r10, r2, r2
        sw    68(r0), r10
        sleu   r10, r2, r2
        sw    72(r0), r10
        sgeu   r10, r2, r2
        sw    76(r0), r10

;---- R-type, INT_MIN vs INT_MAX : signed and unsigned disagree ---
        slt    r10, r3, r4
        sw    80(r0), r10
        sltu   r10, r3, r4
        sw    84(r0), r10
        sgt    r10, r3, r4
        sw    88(r0), r10
        sgtu   r10, r3, r4
        sw    92(r0), r10

;---- I-type, -1 vs 1 ---------------------------------------------
        seqi   r10, r1, 1
        sw    96(r0), r10
        snei   r10, r1, 1
        sw   100(r0), r10
        slti   r10, r1, 1
        sw   104(r0), r10
        sgti   r10, r1, 1
        sw   108(r0), r10
        slei   r10, r1, 1
        sw   112(r0), r10
        sgei   r10, r1, 1
        sw   116(r0), r10
        sltui  r10, r1, 1
        sw   120(r0), r10
        sgtui  r10, r1, 1
        sw   124(r0), r10
        sleui  r10, r1, 1
        sw   128(r0), r10
        sgeui  r10, r1, 1
        sw   132(r0), r10

;---- I-type, 1 vs 1 ----------------------------------------------
        seqi   r10, r2, 1
        sw   136(r0), r10
        snei   r10, r2, 1
        sw   140(r0), r10
        slti   r10, r2, 1
        sw   144(r0), r10
        sgti   r10, r2, 1
        sw   148(r0), r10
        slei   r10, r2, 1
        sw   152(r0), r10
        sgei   r10, r2, 1
        sw   156(r0), r10
        sltui  r10, r2, 1
        sw   160(r0), r10
        sgtui  r10, r2, 1
        sw   164(r0), r10
        sleui  r10, r2, 1
        sw   168(r0), r10
        sgeui  r10, r2, 1
        sw   172(r0), r10

;---- I-type, how the immediate itself is extended ----------------------------
;  slti/sgei sign-extend the field, sltui/sgeui zero-extend it, so the same
;  0xFFFF means -1 to one pair and 65535 to the other.

        slti   r10, r1, -1
        sw   176(r0), r10
        sgei   r10, r1, -1
        sw   180(r0), r10
        sltui  r10, r1, 0xFFFF
        sw   184(r0), r10
        sgeui  r10, r1, 0xFFFF
        sw   188(r0), r10

end:    j end
