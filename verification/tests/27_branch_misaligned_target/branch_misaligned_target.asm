;=============================================================================
;  27_branch_misaligned_target -- a conditional branch with a misaligned target
;=============================================================================
;  Checklist F10.  illegal_detector checks the target in ID and only when the
;  branch is taken: a taken branch to a misaligned target raises
;  INST_ADDR_MISALIGNED (cause 2, TVAL = target), a not-taken one does nothing.
;
;  Part 1: four branches of different kinds with misaligned targets, none of
;  them taken.  None may fault.
;
;  Part 2: one bnez in a loop of four trips, taken (and so faulting) only on
;  trip 2.  The handler logs CAUSE, TVAL and IAR and returns past the branch.
;  The faulting trip may leave the branch in the BTB with its target
;  truncated to bits 31:2, so trips 3 and 4 can be predicted taken towards
;  'poison'; that misprediction has to be repaired in ID, not raised and not
;  retired.
;
;  'poison' stores a sentinel: word 10 comes back non-zero only if a fetch
;  from the truncated target ever retires.
;
;  Result map:
;    0 part 1 reached its end (1)    1 loop trips completed (4)
;    2 exceptions taken (1)          3 CAUSE (2)
;    4 TVAL (poison+2)               5 IAR (address of mb)
;   10 sentinel, must stay 0        11 unexpected cause, must stay 0
;=============================================================================

        .text
        addi   r1, r0, vec_table
        movi2s VBR, r1
        j      main
        nop                         ; pad: VBR must be 16-byte aligned

vec_table:
        j  other_handler            ; cause 0, illegal
        j  other_handler            ; cause 1, trap
        j  inst_mis_handler         ; cause 2, misaligned target
        j  other_handler            ; cause 3, misaligned data

main:
        add  r7, r0, r0             ; exceptions taken
        addi r1, r0, 5
        addi r2, r0, -5
        nop
        nop

;---- part 1: not taken, misaligned target, no exception ----------------------
        beqz r1, poison+1
        bnez r0, poison+2
        bltz r1, poison+3
        bgtz r2, poison+2
        addi r20, r0, 1
        sw   0(r0), r20             ; 1

;---- part 2: the same branch, taken once ---------------------------------------
        addi r5, r0, 4              ; trips
        add  r2, r0, r0             ; trip number
        add  r6, r0, r0             ; trips completed
loop:
        addi r2, r2, 1
        seqi r4, r2, 2              ; 1 only on trip 2
        nop
        nop
mb:     bnez r4, poison+2           ; faults on trip 2 only
        addi r6, r6, 1              ; the handler returns here, IAR+4
        subi r5, r5, 1
        bnez r5, loop

        sw   4(r0), r6              ; 4
        sw   8(r0), r7              ; 1
        j    end

;  Reached only if a fetch from the truncated target ever retires.
poison:
        lhi  r20, 0x00BA
        ori  r20, r20, 0xDBAD
        sw   40(r0), r20
        j    end

end:    j end

inst_mis_handler:
        addi r7, r7, 1
        movs2i r11, CAUSE
        sw   12(r0), r11            ; 2
        movs2i r11, TVAL
        sw   16(r0), r11            ; poison+2
        movs2i r8, IAR
        sw   20(r0), r8             ; mb
        addi r8, r8, 4              ; step over the faulting branch
        movi2s IAR, r8
        rfe

other_handler:
        addi r11, r0, 999
        sw   44(r0), r11
        movs2i r8, IAR
        addi r8, r8, 4
        movi2s IAR, r8
        rfe
