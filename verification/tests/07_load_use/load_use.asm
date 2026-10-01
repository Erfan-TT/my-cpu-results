;=============================================================================
;  07_load_use -- the load-use hazard and the load-driven forwarding paths
;=============================================================================
;  Checklist: C4 (load-use stall at distance 1), C2/C3 at distances 2 and 3,
;             C5 (load -> store data, fw_mem_mem), plus address generation
;             that itself depends on a load.
;
;  The scoreboard gives a load's destination a count of 2, so only distance 1
;  stalls; distances 2 and 3 must come through forwarding with no bubble.  All
;  three read the same kind of value, so a wrong one is obvious.
;
;  Inputs live in the .data section, i.e. in the dmem_init image, so this test
;  also proves the initial data memory is loaded at all.
;
;  Result map:
;    0 load-use d1    1 load d2        2 load d3        3 load->store
;    4 pointer chase  5 chase x2       6 load -> branch 7 store then load
;    8 negative disp  9 disp -4       10 store at a negative displacement
;=============================================================================

        .text

        addi r1, r0, src            ; base pointer, 0x80

;---- C4: distance 1, the one case that must stall ---------------------------
        lw   r2, 0(r1)
        add  r3, r2, r0             ; 0x11223344
        sw    0(r0), r3

;---- distance 2: MEM->EX, no stall ------------------------------------------
        lw   r4, 4(r1)
        nop
        add  r5, r4, r0             ; 0xAABBCCDD
        sw    4(r0), r5

;---- distance 3: register-file bypass ---------------------------------------
        lw   r6, 8(r1)
        nop
        nop
        add  r7, r6, r0             ; 42
        sw    8(r0), r7

;---- C5: the loaded word goes straight back out as store data ---------------
        lw   r8, 12(r1)
        sw   12(r0), r8             ; 0xFFFFFFFF, via MEM->MEM forwarding

;---- the address of a load produced by the previous load --------------------
        lw   r9, 16(r1)             ; r9 = 0x88
        lw   r11, 0(r9)             ; 42
        sw   16(r0), r11
        lw   r12, 20(r1)            ; r12 = 0x98
        lw   r13, 0(r12)            ; 123
        sw   20(r0), r13

;---- a load feeding a branch condition resolved in ID -----------------------
        lw   r14, 8(r1)             ; 42, non-zero
        bnez r14, lu_taken
        addi r15, r0, 999           ; flushed, never executed
lu_taken:
        lw   r16, 0(r1)             ; 0x11223344, non-zero
        beqz r16, lu_join           ; not taken
        addi r15, r0, 7
lu_join:
        sw   24(r0), r15            ; 7

;---- store then read the same address back ----------------------------------
        addi r17, r0, 1445
        sw   64(r0), r17
        lw   r18, 64(r0)
        sw   28(r0), r18

;---- signed displacements, positive and negative ----------------------------
        addi r19, r0, 144           ; 0x90, one word past src[3]
        lw   r20, -16(r19)          ; src[0]
        sw   32(r0), r20
        lw   r21, -4(r19)           ; src[3]
        sw   36(r0), r21
        sw   -24(r19), r17          ; writes 0x78
        lw   r22, 120(r0)           ; reads it back
        sw   40(r0), r22

end:    j end

;=============================================================================
        .data 128                   ; 0x80, clear of the result block

src:    .word 0x11223344            ; 0x80
        .word 0xAABBCCDD            ; 0x84
        .word 0x0000002A            ; 0x88  = 42
        .word 0xFFFFFFFF            ; 0x8C
        .word 0x00000088            ; 0x90  -> address of src[2]
        .word 0x00000098            ; 0x94  -> address of the word below
        .word 0x0000007B            ; 0x98  = 123
