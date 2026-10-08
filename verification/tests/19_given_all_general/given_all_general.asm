;=============================================================================
;  19_given_all_general -- the provided all-instruction example, made runnable
;=============================================================================
;  The body between 'l1:' and the final store block is the provided example,
;  unchanged.  As provided it could not be checked:
;
;    - with every register at 0, its fifth instruction, lw r19, 63(r8), reads
;      address 63, which is misaligned.  The trap vectors to VBR + 12 = 0x0C,
;      which re-executes the andi and the same lw, so the program never got
;      past instruction 5;
;    - it ended in "j l1", so it never reached a final state;
;    - it has no stores, so the final memory image showed nothing.
;
;  So, around the unchanged body:
;    - the prologue gives every register a distinct value.  Four of them are
;      chosen so each load is aligned and inside the 2 KB data memory:
;        r8  = 1   lw  r19, 63(r8)  -> 0x40
;        r2  = 1   lb  r1, -1(r2)   -> 0x00
;        r3  = 0   sll r1, r2, r3 = 1, so slli r4 = 32 and lbu r3, 1(r4) -> 0x21
;        r12 = 1   xori r6, r12, 1 = 0, so lhu r2, 32(r6) -> 0x20
;    - "j l1" is replaced by stores of r1..r31 and the usual final self-loop.
;
;  Result map: words 64..94 (0x100..0x178) hold r1..r31.
;=============================================================================

        .text

        addi r1,  r0, 0x0101
        addi r2,  r0, 1                 ; base of lb r1, -1(r2)
        addi r3,  r0, 0                 ; shift amount of sll r1, r2, r3
        lhi  r4,  0x8000
        ori  r4,  r4, 0x0444
        addi r5,  r0, -5
        lhi  r6,  0x1234
        ori  r6,  r6, 0x5678
        addi r7,  r0, 0x0777
        addi r8,  r0, 1                 ; base of lw r19, 63(r8)
        lhi  r9,  0xFFFF
        ori  r9,  r9, 0x0009
        addi r10, r0, 10
        addi r11, r0, -11
        addi r12, r0, 1                 ; xori r6, r12, 1 -> lhu base 0
        lhi  r13, 0x0D0D
        addi r14, r0, 14
        addi r15, r0, -15
        lhi  r16, 0x7FFF
        addi r17, r0, 17
        addi r18, r0, 0x7FF8
        addi r19, r0, -19
        lhi  r20, 0xA5A5
        ori  r20, r20, 0x5A5A
        addi r21, r0, 21
        addi r22, r0, -22
        addi r23, r0, 23
        addi r24, r0, 24
        lhi  r25, 0x0F0F
        addi r26, r0, -26
        addi r27, r0, 27
        addi r28, r0, 28
        addi r29, r0, -29
        addi r30, r0, 3
        addi r31, r0, 31

;---- provided example, unchanged ---------------------------------------------
l1: 
add r9,r20,r10
addi r1,r2,#-5
and r9,r3,r10
andi r20,r9,#8
lw r19, 63(r8)
nop
ori r5, r3, #342
sge r1,r2,r10
sgei r9,r20,#6
sle r13,r2,r4
slei r1,r3,#-4
sll r1,r2,r3
slli r4,r1,#5
sne r1,r2,r3
snei r3,r5,#4
srl r5,r7,r8
srli r7,r5,#2
sub r6,r12,r15
subi r7,r9,#-30
xor r6,r12,r15
xori r6,r12,#1
addu r5,r3,r4
addui r1,r5,#250
lb r1,3-4(r2)
lbu r3,5-4(r4)
lhi r1,#-40
lhu r2,32(r6)
mult r5,r2,r4
seq r13,r1,r4
seqi r29,r20,#1
sgeu r9,r20,r10
sgeui r7,r8,#23
sgt r1,r2,r3
sgti r4,r1,#15
sgtu r5,r6,r3
sgtui r15,r3,#8
slt r5,r7,r8
slti r9,r10,#30
sltu r17,r13,r14
sltui r5,r7,#13
sra r1,r2,r3
srai r25,r26,#10
subu r13,r2,r4
subui r5,r18,#4
or r5, r3, r4
sleu r13,r2,r9
sleui r22,r30,#30
;---- end of the provided example; it ended in "j l1" -----------------------

        sw   256(r0), r1
        sw   260(r0), r2
        sw   264(r0), r3
        sw   268(r0), r4
        sw   272(r0), r5
        sw   276(r0), r6
        sw   280(r0), r7
        sw   284(r0), r8
        sw   288(r0), r9
        sw   292(r0), r10
        sw   296(r0), r11
        sw   300(r0), r12
        sw   304(r0), r13
        sw   308(r0), r14
        sw   312(r0), r15
        sw   316(r0), r16
        sw   320(r0), r17
        sw   324(r0), r18
        sw   328(r0), r19
        sw   332(r0), r20
        sw   336(r0), r21
        sw   340(r0), r22
        sw   344(r0), r23
        sw   348(r0), r24
        sw   352(r0), r25
        sw   356(r0), r26
        sw   360(r0), r27
        sw   364(r0), r28
        sw   368(r0), r29
        sw   372(r0), r30
        sw   376(r0), r31

end:    j end

;=============================================================================
        .data 0

        .word 0x8091A2B3, 0xC4D5E6F7, 0x01234567, 0x89ABCDEF   ; 0x000
        .word 0xFEDCBA98, 0x76543210, 0x0F1E2D3C, 0x4B5A6978   ; 0x010
        .word 0x9C8DFE01, 0x7A6B5C4D, 0x11223344, 0x55667788   ; 0x020
        .word 0x99AABBCC, 0xDDEEFF00, 0x13579BDF, 0x2468ACE0   ; 0x030
        .word 0xCAFEF00D, 0x0BADBEEF, 0x600DD00D, 0xFACEB00C   ; 0x040
