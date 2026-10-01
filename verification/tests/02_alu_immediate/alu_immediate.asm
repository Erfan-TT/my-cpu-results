;=============================================================================
;  02_alu_immediate -- I-type ALU, and the sign- vs zero-extension split
;=============================================================================
;  Checklist: A4 (addi/addui/subi/subui/andi/ori/xori), A5 (slli/srli/srai),
;             A6 (lhi).
;
;  The point of this program is the immediate path, not the ALU: addi/subi
;  sign-extend the 16-bit field, addui/subui/andi/ori/xori zero-extend it, and
;  the pairs below use the SAME immediate so a broken sign_extension.vhd shows
;  up as two adjacent words that are wrong in opposite directions.
;
;  Result map:
;    0 addi -1        1 addui 0xFFFF   2 addi +max      3 addi -min
;    4 subi -1        5 subui 0xFFFF   6 subi 1         7 andi low
;    8 andi ones      9 ori zero      10 ori mix       11 xori low
;   12 xori ones     13 lhi 0x1234    14 lhi 0xFFFF    15 lhi 0
;   16 slli 4        17 slli 0        18 slli 31       19 srli 4
;   20 srli 31       21 srai 31       22 srai 4        23 srai INT_MIN 1
;   24 addi 0        25 addui 0x8000  26 subui 0x8000  27 addi -32768
;=============================================================================

        .text

;---- operands ---------------------------------------------------------------
        lhi  r1, 0x5A5A
        ori  r1, r1, 0x0F0F         ; r1 = 0x5A5A0F0F
        addi r4, r0, -1             ; r4 = 0xFFFFFFFF
        lhi  r6, 0x8000             ; r6 = 0x80000000

;---- addi / addui : same 16-bit field, different extension ------------------
        addi  r10, r0, -1           ; sign-extended -> 0xFFFFFFFF
        sw     0(r0), r10
        addui r10, r0, 0xFFFF       ; zero-extended -> 0x0000FFFF
        sw     4(r0), r10
        addi  r10, r1, 32767        ; largest positive immediate
        sw     8(r0), r10
        addi  r10, r1, -32768       ; most negative immediate
        sw    12(r0), r10

;---- subi / subui -----------------------------------------------------------
        subi  r10, r0, -1           ; 0-(-1) -> 1
        sw    16(r0), r10
        subui r10, r0, 0xFFFF       ; 0-65535 -> 0xFFFF0001
        sw    20(r0), r10
        subi  r10, r1, 1
        sw    24(r0), r10

;---- andi / ori / xori : always zero-extended -------------------------------
        andi r10, r1, 0xFFFF        ; 0x00000F0F
        sw    28(r0), r10
        andi r10, r4, 0xFFFF        ; 0x0000FFFF, proves the upper half is 0
        sw    32(r0), r10
        ori  r10, r0, 0xFFFF        ; 0x0000FFFF
        sw    36(r0), r10
        ori  r10, r1, 0xF0F0        ; 0x5A5AFFFF
        sw    40(r0), r10
        xori r10, r1, 0xFFFF        ; 0x5A5AF0F0
        sw    44(r0), r10
        xori r10, r4, 0xFFFF        ; 0xFFFF0000
        sw    48(r0), r10

;---- lhi --------------------------------------------------------------------
        lhi  r10, 0x1234            ; 0x12340000
        sw    52(r0), r10
        lhi  r10, 0xFFFF            ; 0xFFFF0000
        sw    56(r0), r10
        lhi  r10, 0                 ; 0
        sw    60(r0), r10

;---- immediate shifts -------------------------------------------------------
        slli r10, r1, 4
        sw    64(r0), r10
        slli r10, r1, 0             ; no-op
        sw    68(r0), r10
        slli r10, r1, 31            ; only bit 0 of r1 survives
        sw    72(r0), r10
        srli r10, r1, 4
        sw    76(r0), r10
        srli r10, r4, 31            ; logical -> 1
        sw    80(r0), r10
        srai r10, r4, 31            ; arithmetic -> 0xFFFFFFFF
        sw    84(r0), r10
        srai r10, r1, 4             ; positive, so same as srli
        sw    88(r0), r10
        srai r10, r6, 1             ; INT_MIN >> 1 -> 0xC0000000
        sw    92(r0), r10

;---- the extension split once more, on a value with bit 15 set --------------
        addi  r10, r1, 0            ; identity
        sw    96(r0), r10
        addui r10, r1, 0x8000       ; + 32768
        sw   100(r0), r10
        subui r10, r1, 0x8000       ; - 32768
        sw   104(r0), r10
        addi  r10, r1, -32768       ; also - 32768, via sign extension
        sw   108(r0), r10

end:    j end
