;=============================================================================
;  21_store_subword -- sb and sh
;=============================================================================
;  Checklist: E10 (sub-word stores), E11 (read-modify-write of the containing
;  word), E12 (only the low byte / half of the source register is stored),
;  F5 (a misaligned sh faults, an odd-addressed sb does not).
;
;  A sub-word store is the one memory operation that has to PRESERVE what it
;  does not write.  So every target word below starts from a recognisable
;  pattern in the .data image, and the dump shows the merge directly: a word
;  that comes back as 0x000000xx means the memory overwrote instead of merging,
;  and a word whose byte landed in the wrong lane means the byte address or
;  store_size did not reach the memory intact.
;
;  The source register is always wide (0xDEADBE01 and friends) so that a path
;  which forgets to mask down to the low byte / half is visible too.
;
;  Data map:
;    0x00..0x27  targets, pre-loaded from .data and modified in place
;    0x40..0x6F  read-backs
;    0x80..0x8F  exception log: marker, CAUSE, TVAL, STATUS
;
;  Result map:
;    word  0  sb into lane 0        1  lane 1        2  lane 2     3  lane 3
;          4  sh into the high half 5  sh into the low half
;          6  four sb building one word
;          7  two sh building one word
;          8  sb whose data came from a load    9  sh, same
;         16  lb  of lane 0        17  lbu of lane 0
;         18  lb  of an untouched lane (sign extended)
;         19  sb at an odd address, read back    20 lbu of lane 0 of word 1
;         21  lh  of the stored half             22 lhu of it
;         23  lh  of the untouched half
;         24  the four-sb word     25 the two-sh word
;         26  the load-fed sb word 27 the load-fed sh word
;         32  handler marker (400)  33 CAUSE (3)  34 TVAL (0x11)  35 STATUS
;=============================================================================

        .text

        addi   r1, r0, vec_table
        movi2s VBR, r1
        j      main
        nop                         ; pad: special_pc substitutes CAUSE into
                                    ; PC bits 3:2, so VBR must be 16-byte aligned

vec_table:
        j  exc_handler                  ; cause 0, illegal
        j  exc_handler                  ; cause 1, trap
        j  exc_handler                  ; cause 2, misaligned target
        j  exc_handler                  ; cause 3, misaligned data

main:
        lhi  r1, 0xDEAD
        ori  r1, r1, 0xBE01             ; 0xDEADBE01 -- only 0x01 / 0xBE01 may reach memory

;---- one sb into each lane of its own word ----------------------------------
        sb    0(r0), r1                 ; 0xAAAAAAAA -> 0x01AAAAAA
        sb    5(r0), r1                 ; 0xBBBBBBBB -> 0xBB01BBBB   (odd address, legal)
        sb   10(r0), r1                 ; 0xCCCCCCCC -> 0xCCCC01CC
        sb   15(r0), r1                 ; 0xDDDDDDDD -> 0xDDDDDD01

;---- one sh into each half --------------------------------------------------
        sh   16(r0), r1                 ; 0xEEEEEEEE -> 0xBE01EEEE
        sh   22(r0), r1                 ; 0x11111111 -> 0x1111BE01

;---- four sb building a single word, each right after its producer ----------
;  Each store's data is forwarded EX->EX into the masking path.
        addi r7, r0, 1
        sb   24(r0), r7
        addi r7, r0, 2
        sb   25(r0), r7
        addi r7, r0, 3
        sb   26(r0), r7
        addi r7, r0, 4
        sb   27(r0), r7                 ; 0x22222222 -> 0x01020304

;---- two sh building a single word ------------------------------------------
        ori  r8, r0, 0xF00D             ; 0x0000F00D
        sh   28(r0), r8
        lhi  r9, 0xFFFF
        ori  r9, r9, 0xBEEF             ; 0xFFFFBEEF -- upper half must be dropped
        sh   30(r0), r9                 ; 0x33333333 -> 0xF00DBEEF

;---- store data coming straight out of a load (MEM->MEM forwarding) ---------
        lw   r5, 40(r0)                 ; 0x8899AABB
        sb   32(r0), r5                 ; 0x44444444 -> 0xBB444444
        lw   r6, 40(r0)
        sh   38(r0), r6                 ; 0x55555555 -> 0x5555AABB

;---- read the merged words back ---------------------------------------------
        lb   r11, 0(r0)                 ; 0x01
        sw   64(r0), r11
        lbu  r11, 0(r0)                 ; 0x01
        sw   68(r0), r11
        lb   r11, 1(r0)                 ; 0xAA, untouched -> sign extended
        sw   72(r0), r11
        lb   r11, 5(r0)                 ; 0x01 at an odd address
        sw   76(r0), r11
        lbu  r11, 4(r0)                 ; 0xBB, the lane sb must not have touched
        sw   80(r0), r11
        lh   r12, 16(r0)                ; 0xBE01 -> sign extended
        sw   84(r0), r12
        lhu  r12, 16(r0)                ; 0x0000BE01
        sw   88(r0), r12
        lh   r12, 18(r0)                ; 0xEEEE, untouched half
        sw   92(r0), r12
        lw   r13, 24(r0)                ; 0x01020304
        sw   96(r0), r13
        lw   r13, 28(r0)                ; 0xF00DBEEF
        sw  100(r0), r13
        lw   r13, 32(r0)                ; 0xBB444444
        sw  104(r0), r13
        lw   r13, 36(r0)                ; 0x5555AABB
        sw  108(r0), r13

;---- alignment: sb never faults, sh on an odd address does ------------------
        addi r10, r0, 128               ; exception log pointer
        sb   17(r0), r1                 ; odd address, perfectly legal
        sh   17(r0), r1                 ; odd address -> DATA_ADDR_MISALIGNED

end:    j end

exc_handler:
        addi r14, r0, 400
        sw   0(r10), r14
        movs2i r15, CAUSE
        sw   4(r10), r15
        movs2i r15, TVAL
        sw   8(r10), r15
        movs2i r15, STATUS
        sw  12(r10), r15
        movs2i r16, IAR
        addi r16, r16, 4                ; skip the faulting store
        movi2s IAR, r16
        rfe

;=============================================================================
        .data 0

targ:   .word 0xAAAAAAAA                ; 0x00  sb lane 0
        .word 0xBBBBBBBB                ; 0x04  sb lane 1
        .word 0xCCCCCCCC                ; 0x08  sb lane 2
        .word 0xDDDDDDDD                ; 0x0C  sb lane 3
        .word 0xEEEEEEEE                ; 0x10  sh high half
        .word 0x11111111                ; 0x14  sh low half
        .word 0x22222222                ; 0x18  four sb
        .word 0x33333333                ; 0x1C  two sh
        .word 0x44444444                ; 0x20  sb fed by a load
        .word 0x55555555                ; 0x24  sh fed by a load
src:    .word 0x8899AABB                ; 0x28  source word
