;=============================================================================
;  22_branch_operand_hazard -- operands read in the ID stage
;=============================================================================
;  Branches and jumps resolve in ID, and two different things are read there.
;
;  The CONDITION (beqz/bnez/bltz/...) goes through decision_unit, which takes
;  the zero/sign flags and, when fw_ex_id_rs1 is set, the EX/MEM flags instead
;  of recomputing them from the register.  With the one-cycle stall
;  hazard_detection inserts for a branch whose rs1 is still in flight, that
;  covers every distance.
;
;  The TARGET of jr/jalr is the register VALUE, not a flag, so it needs its own
;  path.  It used to have none -- branch_correction's mux_1 took register_in
;  straight off the register file -- and a jr or jalr whose target register was
;  written one or two instructions earlier jumped to the stale value.  decode
;  now muxes register_in to the EX/MEM result under the same fw_ex_id_rs1 that
;  already selects the flags, which closes both distances.  decision_unit keeps
;  the raw RF_out1, so the condition path does not pay for the mux.
;
;  This file is what pinned that bug and is what proves it stays fixed.  Every
;  case is written so a stale read is VISIBLE: the register is pre-loaded with
;  a second, valid address, so a stale read lands on a block that records 0
;  rather than silently re-running the setup and converging anyway.  That is
;  exactly how the bug hid -- a jr to a stale 0 restarts the program, and an
;  idempotent program then produces the right memory image on its next pass.
;  Keep that property if you add a case here.
;
;  All seven words must read 1.
;
;  Result map:
;    0 jr target, distance 1     1 jr target, distance 2   2 jr target, d 3
;    3 jalr target, distance 1
;    4 condition, distance 1     5 condition, distance 2   6 condition, d 3
;    7 branch on a LOADED zero      8 on a loaded negative   9 on a loaded
;      non-zero read from address 0
;
;  Words 7-9 exist because the flags stored beside a register have to describe
;  the value that was WRITTEN to it.  For a load that is the loaded data, not
;  the ALU output -- and the ALU output on a load is the effective ADDRESS.
;  Each case is built so the address and the value disagree about being zero or
;  negative, so taking the flags from the wrong one flips the branch:
;    7  value 0        at address 128  (non-zero)  -> beqz must be taken
;    8  value negative at address 132  (positive)  -> bltz must be taken
;    9  value 1        at address 0    (zero)      -> beqz must NOT be taken
;  Loads never forward into ID (forwarding.vhd cancels on RM), so all three
;  read the stored flags, whatever the distance.
;=============================================================================

        .text

;---- jr target, produced one instruction earlier ----------------------------
        addi r1, r0, bad_a          ; what a stale read returns
        addi r1, r0, good_a         ; what it must return
        jr   r1
        nop
bad_a:  addi r10, r0, 0
        j    join_a
good_a: addi r10, r0, 1
join_a: sw    0(r0), r10

;---- jr target, produced two instructions earlier ---------------------------
        addi r2, r0, bad_b
        addi r2, r0, good_b
        nop
        jr   r2
        nop
bad_b:  addi r11, r0, 0
        j    join_b
good_b: addi r11, r0, 1
join_b: sw    4(r0), r11

;---- jr target, produced three instructions earlier -------------------------
        addi r3, r0, bad_c
        addi r3, r0, good_c
        nop
        nop
        jr   r3
        nop
bad_c:  addi r12, r0, 0
        j    join_c
good_c: addi r12, r0, 1
join_c: sw    8(r0), r12

;---- jalr target, produced one instruction earlier --------------------------
        addi r4, r0, bad_d
        addi r4, r0, good_d
        jalr r4
        nop
bad_d:  addi r13, r0, 0
        j    join_d
good_d: addi r13, r0, 1
join_d: sw   12(r0), r13

;---- branch condition, produced one instruction earlier ---------------------
;  The EX flags are forwarded, so this one should already be right.
        addi r5, r0, 7              ; stale value is non-zero
        addi r14, r0, 1
        add  r5, r0, r0             ; fresh value is zero
        beqz r5, join_e
        addi r14, r0, 0
join_e: sw   16(r0), r14

;---- branch condition, produced two instructions earlier --------------------
        addi r6, r0, 7
        addi r15, r0, 1
        add  r6, r0, r0
        nop
        beqz r6, join_f
        addi r15, r0, 0
join_f: sw   20(r0), r15

;---- branch condition, produced three instructions earlier ------------------
        addi r7, r0, 7
        addi r16, r0, 1
        add  r7, r0, r0
        nop
        nop
        beqz r7, join_g
        addi r16, r0, 0
join_g: sw   24(r0), r16


;---- the flags stored beside a register must describe the LOADED value ------
        addi r24, r0, 1
        lw   r21, 128(r0)           ; value 0, from a non-zero address
        nop
        nop
        beqz r21, ld_zero
        add  r24, r0, r0
ld_zero:
        sw   28(r0), r24            ; 1 if the flags came from the value

        addi r25, r0, 1
        lw   r22, 132(r0)           ; value 0xFFFFFFFF, from a positive address
        nop
        nop
        bltz r22, ld_neg
        add  r25, r0, r0
ld_neg:
        sw   32(r0), r25

        addi r26, r0, 1
        lw   r23, 0(r0)             ; value 1 (stored by case 0), address zero
        nop
        nop
        beqz r23, ld_bad            ; must NOT be taken
        j    ld_join
ld_bad: add  r26, r0, r0
ld_join:
        sw   36(r0), r26

end:    j end

;=============================================================================
        .data 128

        .word 0x00000000            ; 0x80
        .word 0xFFFFFFFF            ; 0x84
