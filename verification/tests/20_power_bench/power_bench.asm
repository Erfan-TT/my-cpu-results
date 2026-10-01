;=============================================================================
;  power_bench.asm -- switching-activity / VCD workload for the DLX
;=============================================================================
;  Purpose: one self-checking program that keeps every synthesised block of the
;  CPU busy for a few thousand cycles, so a gate-level run of TB_DLX produces a
;  VCD whose switching activity is representative of the whole design rather
;  than of one corner of it.
;
;  What it touches, and why it is here:
;    - P4 adder, logic block, shifter, both comparators  (PHASE 0 and 1)
;    - Booth/Dadda multiplier, both in the overlapped case (independent work
;      issued underneath it) and in the back-to-back dependent case that
;      actually stalls                                    (PHASE 1 and 2)
;    - forwarding paths EX->EX, MEM->EX and the RF bypass (long dependency
;      chains everywhere, plus load-use pairs)
;    - byte / half-word load units                        (PHASE 2)
;    - BTB + 2-bit predictor: one perfectly predictable loop, one alternating
;      branch that mispredicts about half the time, one jal/jr call per
;      iteration, spread over several BTB index rows       (PHASE 3)
;    - special register file, illegal detector, exception PC logic (PHASE 4)
;
;  IMPORTANT -- why PHASE 0 exists.
;  register_file.vhd has no reset; it only has a VHDL signal initialiser, which
;  synthesis drops.  In a gate-level run every GPR therefore starts at 'X'.
;  Reading an un-written register poisons the ALU result, the DRAM address and
;  a large slice of the VCD -- and X nets do not toggle, so the power number
;  comes out silently LOW.  PHASE 0 writes all of r1..r31 before anything reads
;  them.  Keep it first if you edit this file.
;
;  Data map (data RAM byte addresses; the whole 512 B = 128 words that
;  dlxsim.py --compare checks by default):
;      0x000 .. 0x07F   vec_a    32 input words   <- .data, ends up in hex_init.txt
;      0x080 .. 0x0FF   vec_b    32 input words   <- .data
;      0x100 .. 0x17F   vec_out  32 result words
;      0x180 .. 0x1BF   scalar results
;      0x1C0 .. 0x1FF   exception log, 4 causes x 4 words
;
;  Build and check:
;      cd sim/scripts
;      ./assembler.sh ../asm_examples/power_bench.asm
;      python3 ../dlxsim.py ../asm_examples/power_bench.asm --dram-out ../golden.txt
;      <run the simulation>                       -> ../hex_dump.txt, ../dump.vcd
;      python3 ../dlxsim.py ../asm_examples/power_bench.asm \
;              --dram-out /dev/null --compare ../hex_dump.txt
;
;  Length knob: r28 at 'outer' is the number of outer passes.
;=============================================================================

        .text

        addi   r1, r0, vec_table
        movi2s VBR, r1
        j      main
        nop                         ; pad: special_pc substitutes CAUSE into
                                    ; PC bits 3:2, so VBR must be 16-byte aligned

vec_table:
        j  illegal_handler              ; cause 0
        j  trap_handler                 ; cause 1
        j  inst_mis_handler             ; cause 2
        j  data_mis_handler             ; cause 3

;-----------------------------------------------------------------------------
;  PHASE 0 -- write every GPR (see the note above), with wide operands so the
;  adder / logic / shifter all see real toggling.  Also a 33-deep back-to-back
;  dependency chain, i.e. EX->EX forwarding on every single instruction.
;-----------------------------------------------------------------------------
main:
        lhi  r1, 0x5A5A
        ori  r1, r1, 0x0F0F             ; 0x5A5A0F0F
        lhi  r2, 0xA5A5
        ori  r2, r2, 0xF0F0             ; 0xA5A5F0F0
        xor  r3,  r1, r2
        add  r4,  r2, r1
        sub  r5,  r1, r2
        srli r6,  r3, 3
        slli r7,  r4, 5
        or   r8,  r5, r6
        and  r9,  r7, r1
        xor  r10, r8, r2
        add  r11, r9, r3
        sub  r12, r10, r4
        srli r13, r11, 7
        slli r14, r12, 11
        or   r15, r13, r5
        and  r16, r14, r6
        xor  r17, r15, r7
        add  r18, r16, r8
        sub  r19, r17, r9
        srai r20, r18, 2
        slli r21, r19, 1
        or   r22, r20, r10
        and  r23, r21, r11
        xor  r24, r22, r12
        add  r25, r23, r13
        sub  r26, r24, r14
        srli r27, r25, 4
        slli r28, r26, 9
        or   r29, r27, r15
        and  r30, r28, r16
        xor  r31, r29, r17

        addi r28, r0, 2                 ; <-- outer passes.  Raise to lengthen the VCD.

;=============================================================================
outer:
;-----------------------------------------------------------------------------
;  PHASE 1 -- the main vector kernel, 32 iterations of 24 instructions.
;  Two loads per iteration, one store, one multiply with five independent
;  instructions issued underneath it, and a load-use pair at the top.
;-----------------------------------------------------------------------------
        addi r1, r0, vec_a
        addi r2, r0, vec_b
        addi r3, r0, vec_out
        addi r4, r0, 32
        add  r20, r0, r0                ; running checksum

loop1:
        lw   r5, 0(r1)
        lw   r6, 0(r2)
        add  r7,  r5, r6                ; load-use, straight after the load
        xor  r8,  r5, r6
        sub  r9,  r5, r6
        and  r11, r5, r6
        or   r12, r5, r6
        srli r13, r5, 3
        slli r14, r6, 5
        slt  r15, r5, r6                ; signed comparator
        sltu r16, r5, r6                ; unsigned comparator
        mult r17, r5, r6                ; Booth/Dadda, runs in the shadow
        xor  r18, r7,  r8               ; ... while these four proceed
        add  r19, r9,  r11
        sub  r21, r12, r13
        xor  r22, r14, r15
        add  r23, r16, r17              ; here the multiply result is consumed
        sw   0(r3), r23
        add  r20, r20, r23
        addi r1, r1, 4
        addi r2, r2, 4
        addi r3, r3, 4
        subi r4, r4, 1
        bnez r4, loop1                  ; taken 31x, not taken once

        sw   0(r3), r20                 ; 0x180  vector checksum

;-----------------------------------------------------------------------------
;  PHASE 2 -- the multiplier's slow path, plus the sub-word load units.
;  The two mults in the middle are immediately dependent, so this is the
;  stalling case, in contrast with the overlapped one in PHASE 1.
;-----------------------------------------------------------------------------
        addi r1, r0, vec_a
        addi r4, r0, 8
        addi r24, r0, 1
        add  r25, r0, r0

loop2:
        lw   r5, 0(r1)
        andi r6, r5, 0x00FF
        ori  r6, r6, 0x0011             ; never let the carried product hit zero
        mult r24, r24, r6               ; carried across the whole loop
        mult r12, r5, r6
        mult r12, r12, r5               ; back-to-back dependent multiply
        add  r25, r25, r12
        lb   r7,  1(r1)                 ; signed byte
        lbu  r8,  2(r1)                 ; unsigned byte
        lh   r9,  2(r1)                 ; signed half
        lhu  r11, 0(r1)                 ; unsigned half
        add  r25, r25, r7
        add  r25, r25, r8
        add  r25, r25, r9
        add  r25, r25, r11
        addi r1, r1, 4
        subi r4, r4, 1
        bnez r4, loop2

        sw   4(r3), r24                 ; 0x184
        sw   8(r3), r25                 ; 0x188

;-----------------------------------------------------------------------------
;  PHASE 3 -- branch behaviour.
;    loop3   backward branch, taken 15x out of 16    -> predictor saturates
;    beqz    alternates every iteration              -> ~50% misprediction
;    slti/bnez  flips once, halfway through          -> one late mispredict
;    jal/jr  a call and a return every iteration     -> BTB + r31 path
;  The branches sit at different PCs, so they land in different BTB rows
;  (the index is pc[6:2]).
;-----------------------------------------------------------------------------
        addi r4, r0, 16
        add  r26, r0, r0
        add  r27, r0, r0

loop3:
        andi r5, r4, 1
        beqz r5, even3
        addi r26, r26, 3
        j    cont3
even3:
        addi r27, r27, 5
cont3:
        jal  square                     ; multiply inside the callee
        add  r26, r26, r13
        slti r6, r4, 8
        bnez r6, low3
        addi r27, r27, 1
low3:
        subi r4, r4, 1
        bnez r4, loop3

        sw   12(r3), r26                ; 0x18C
        sw   16(r3), r27                ; 0x190

        subi r28, r28, 1
        bnez r28, outer
        j    exceptions

square:
        mult r13, r4, r4
        jr   r31

;-----------------------------------------------------------------------------
;  PHASE 4 -- one hit per exception cause.  Runs once, after every result is
;  already in memory, so a problem here cannot disturb the numbers above.
;  Delete the four lines between 'exceptions:' and 'movs2i' to drop it.
;-----------------------------------------------------------------------------
exceptions:
        addi r10, r0, 0x1C0             ; exception log pointer
        trap 7                          ; cause 1, tval 7
        .word 0x00000000                ; cause 0 : opcode 0 with func 0 is illegal
        lw   r19, 18(r0)                ; cause 3 : misaligned word load
        addi r3, r0, 9
        jr   r3                         ; cause 2 : misaligned jump target
        movs2i r5, STATUS               ; IE back, EXL clear
        j    end

end:    j end

illegal_handler:
        addi r11, r0, 100
        j    exc_common
trap_handler:
        addi r11, r0, 200
        j    exc_common
inst_mis_handler:
        addi r11, r0, 300
        j    exc_common
data_mis_handler:
        addi r11, r0, 400
exc_common:
        sw   0(r10), r11
        movs2i r5, CAUSE
        sw   4(r10), r5
        movs2i r5, TVAL
        sw   8(r10), r5
        movs2i r5, STATUS
        sw   12(r10), r5
        movs2i r8, IAR
        addi r10, r10, 16
        addi r8, r8, 4
        movi2s IAR, r8
        rfe

;=============================================================================
;  INPUT DATA -- this is what ends up in hex_init.txt.
;  Chosen for toggling: all-ones and all-zeros, the two checkerboards, byte
;  and half-word patterns, walking ones, the two extremes of the signed range,
;  and some unstructured values.  The a/b pairs are deliberately mismatched so
;  slt vs sltu disagree on several of them and the multiplier sees both small
;  and full-width operands.
;=============================================================================
        .data 0

vec_a:                                  ; 0x000
        .word 0x00000000, 0xFFFFFFFF, 0x5A5A5A5A, 0xA5A5A5A5
        .word 0x0000FFFF, 0xFFFF0000, 0x0F0F0F0F, 0xF0F0F0F0
        .word 0x00FF00FF, 0xFF00FF00, 0x33333333, 0xCCCCCCCC
        .word 0x80000000, 0x7FFFFFFF, 0x00000001, 0xFFFFFFFE
        .word 0x12345678, 0x87654321, 0xDEADBEEF, 0xCAFEBABE
        .word 0x00000002, 0x00000004, 0x00000008, 0x00000010
        .word 0x00010000, 0x00100000, 0x01000000, 0x10000000
        .word 0x13579BDF, 0x2468ACE0, 0xA5A50F0F, 0x5A5AF0F0

vec_b:                                  ; 0x080
        .word 0xFFFFFFFF, 0x00000000, 0xA5A5A5A5, 0x5A5A5A5A
        .word 0xFFFF0000, 0x0000FFFF, 0xF0F0F0F0, 0x0F0F0F0F
        .word 0xFF00FF00, 0x00FF00FF, 0xCCCCCCCC, 0x33333333
        .word 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF, 0x00000003
        .word 0x0BADF00D, 0x1BADB002, 0xFEEDFACE, 0x8BADF00D
        .word 0x00000003, 0x00000007, 0x0000000F, 0x0000001F
        .word 0x00008000, 0x00080000, 0x00800000, 0x08000000
        .word 0xECA86420, 0xFDB97531, 0x0F0FA5A5, 0xF0F05A5A

vec_out:                                ; 0x100
        .space 128
scalars:                                ; 0x180
        .space 64
exc_log:                                ; 0x1C0
        .space 64
