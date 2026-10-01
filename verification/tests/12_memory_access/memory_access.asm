;=============================================================================
;  12_memory_access -- word, half-word and byte access, and endianness
;=============================================================================
;  Checklist: E1 (lw/sw round trip, register base, positive and negative
;  displacements), E2 (lb/lbu on all four lanes), E3 (lh/lhu on both halves,
;  sign vs zero extension), E4 (store then load the same address).
;
;  DLX is big-endian here: byte address 0 of a word is its MOST significant
;  byte, and half-word address 0 is the upper half.  Half of this file exists
;  to pin that down, because a byte-order slip shows up as plausible-looking
;  values in the wrong lanes.
;
;  Words 64..67 come from the .data section, so a wrong or missing dmem_init
;  image fails here rather than silently reading zeros.
;
;  Result map:
;    0,1 scratch words written by the test itself
;    4 lb0    5 lb1    6 lb2    7 lb3          (signed)
;    8 lbu0   9 lbu1  10 lbu2  11 lbu3         (zero extended)
;   12 lh0   13 lh2   14 lhu0  15 lhu2
;   16 lb of 0x01020304 lane 0  17 lane 3      (endianness, spelled out)
;   18 lw from the init image   19 lb of it    20 lh high  21 lhu low
;   22 register-base store/load 23 negative displacement
;   24 positive displacement    25 store then load the same address
;   26 last word of the init image
;=============================================================================

        .text

;---- a word with four distinguishable bytes ---------------------------------
        lhi  r1, 0x1188
        ori  r1, r1, 0xF344         ; 0x1188F344
        sw    0(r0), r1

        lb   r2, 0(r0)              ; 0x11 -> 0x00000011
        sw   16(r0), r2
        lb   r2, 1(r0)              ; 0x88 -> 0xFFFFFF88
        sw   20(r0), r2
        lb   r2, 2(r0)              ; 0xF3 -> 0xFFFFFFF3
        sw   24(r0), r2
        lb   r2, 3(r0)              ; 0x44 -> 0x00000044
        sw   28(r0), r2

        lbu  r3, 0(r0)              ; 0x00000011
        sw   32(r0), r3
        lbu  r3, 1(r0)              ; 0x00000088
        sw   36(r0), r3
        lbu  r3, 2(r0)              ; 0x000000F3
        sw   40(r0), r3
        lbu  r3, 3(r0)              ; 0x00000044
        sw   44(r0), r3

        lh   r4, 0(r0)              ; 0x1188 -> 0x00001188
        sw   48(r0), r4
        lh   r4, 2(r0)              ; 0xF344 -> 0xFFFFF344
        sw   52(r0), r4
        lhu  r5, 0(r0)              ; 0x00001188
        sw   56(r0), r5
        lhu  r5, 2(r0)              ; 0x0000F344
        sw   60(r0), r5

;---- endianness, spelled out ------------------------------------------------
        lhi  r6, 0x0102
        ori  r6, r6, 0x0304         ; 0x01020304
        sw    4(r0), r6
        lb   r7, 4(r0)              ; must be 1, the most significant byte
        sw   64(r0), r7
        lb   r7, 7(r0)              ; must be 4, the least significant byte
        sw   68(r0), r7

;---- data that was never written by this program ----------------------------
        addi r8, r0, mem            ; 0x100
        lw   r9, 0(r8)              ; 0x7F80017E, straight from dmem_init
        sw   72(r0), r9
        lb   r11, 0(r8)             ; 0x7F -> 0x0000007F
        sw   76(r0), r11
        lh   r12, 0(r8)             ; 0x7F80 -> 0x00007F80
        sw   80(r0), r12
        lhu  r13, 2(r8)             ; 0x0000017E
        sw   84(r0), r13

;---- addressing modes -------------------------------------------------------
        addi r14, r0, 160           ; 0xA0, a free scratch address
        addi r15, r0, 1985
        sw    0(r14), r15           ; register base, zero displacement
        lw   r16, 0(r14)
        sw   88(r0), r16

        addi r17, r0, 268           ; 0x10C, past the init block
        lw   r18, -4(r17)           ; reads 0x108
        sw   92(r0), r18
        lw   r19, 4(r8)             ; positive displacement off the base
        sw   96(r0), r19

;---- a store and the load right behind it -----------------------------------
        addi r20, r0, -1
        sw  164(r0), r20
        lw   r21, 164(r0)
        sw  100(r0), r21

        lw   r22, 12(r8)            ; 0xDEADBEEF
        sw  104(r0), r22

end:    j end

;=============================================================================
        .data 256                   ; 0x100

mem:    .word 0x7F80017E            ; 0x100
        .word 0x8000FFFF            ; 0x104
        .word 0x00FF0001            ; 0x108
        .word 0xDEADBEEF            ; 0x10C
