; pc = 0
    nop ; aligning the VBR to 4 bit zero
    addi r1, r0, vector_base
    movi2s vbr, r1
    j main
    
vector_base:
    j illegal_instruction_handler ; vbr equal to 16, with cause zero
    j trap_handler
    j misaligned_inst_addr_handler
    j misaligned_load_addr_handler


main:
    add r10, r0, r0 ; initialize memory index : r10
    addi r2, r0, 5
    addi r3, r2, 4

    jr r3
    
    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    j 11
    
    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    beqz r0, 18

    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    ;sb f1, f2, f3 ; illegal instruction that will assembeled, should raise exception

    .word 0x00000000 ; illegal instruction

    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    movi2s r30, r2 ; r30 with 30 register index, max rd is 4

    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    movs2i r2, r30

    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    sw 0(r10), r2 ; should put 5 there still, no moving from sp_reg
    addi r10, r10, 4

    trap 2

    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    trap 7

    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    trap 5

    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    lw r19, 18(r0)

    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    lh r19, 17(r0)

    addi r12, r0, 65535 ;   putting 0xFFFFFFFF, seperating between exception results
    sw 0(r10), r12
    addi r10, r10, 4

    movs2i r11, STATUS
    sw 0(r10), r11 ; the rfe should return the IE back into one

    j end

end:
    j end




misaligned_inst_addr_handler:

    movs2i r5, VBR
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r5, STATUS
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r5, CAUSE
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r5, TVAL
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r8, IAR
    sw 0(r10), r8
    addi r10, r10, 4

    addi r8, r8, 4
    movi2s IAR, r8 ; skiping back
    rfe


illegal_instruction_handler:

    movs2i r5, VBR
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r5, STATUS
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r5, CAUSE
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r5, TVAL
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r8, IAR
    sw 0(r10), r8
    addi r10, r10, 4

    addi r8, r8, 4
    movi2s IAR, r8 ; skiping back
    rfe

    
trap_handler: 

    movs2i r5, VBR
    sw 0(r10), r5
    addi r10, r10, 4

    movs2i r5, STATUS
    sw 0(r10), r5
    addi r10, r10, 4

    movs2i r5, CAUSE
    sw 0(r10), r5
    addi r10, r10, 4

    movs2i r8, IAR ; r8 holds the pc of trap instruction
    sw 0(r10), r8
    addi r10, r10, 4

    movs2i r5, TVAL
    sw 0(r10), r5
    addi r10, r10, 4

    subi r9, r5, 7
    beqz r9, trap_7

    subi r9, r5, 5
    beqz r9, trap_5
    
    addi r8, r8, 4 ; continuing back to the program if none of the trap numbers where there
    movi2s IAR, r8 ; skiping back
    rfe

trap_7:
    addi r15, r0, 1
    addi r16, r15, 6
    mult r16, r16, r15 ; result is 7, checking against multiplying 1 to 7
    sw 0(r10), r16
    addi r10, r10, 4

    addi r8, r8, 4 ; continuing back to the program
    movi2s IAR, r8 ; skiping back
    rfe

trap_5:
    addi r16, r0, 5
    sw 0(r10), r16
    addi r10, r10, 4

    addi r8, r8, 4 ; continuing back to the program
    movi2s IAR, r8 ; skiping back
    rfe

    

misaligned_load_addr_handler: 

    movs2i r5, VBR
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r5, STATUS
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r5, CAUSE
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r5, TVAL
    sw 0(r10), r5
    addi r10, r10, 4
    movs2i r8, IAR
    sw 0(r10), r8
    addi r10, r10, 4

    addi r8, r8, 4
    movi2s IAR, r8 ; skiping back
    rfe

