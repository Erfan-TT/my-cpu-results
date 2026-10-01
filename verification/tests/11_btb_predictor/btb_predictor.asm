;=============================================================================
;  11_btb_predictor -- BTB rows, prediction, and recovery from a mispredict
;=============================================================================
;  Checklist: D3/D4 (cold miss then warm hit), D5 (a loop re-entered, so its
;  branch is already saturated the second time round), D6/D7 (mispredicts in
;  both directions), D8 (two branches that alias to the same BTB row), D9 (one
;  jalr instruction whose target changes between executions).
;
;  The BTB is 16 rows indexed by pc[5:2], so two branches whose addresses
;  differ by 64 bytes share a row.  The two loops below are placed with
;  '.text' at fixed addresses precisely so their bnez instructions land at
;  0x48 and 0x88 -- both index 2 -- and evict each other on every alternation.
;  The gaps are NOP-padded by the assembler and never executed.
;
;  A data-memory dump cannot see a prediction, only its consequences: if the
;  BTB hands out a wrong target, or a mispredict is not flushed and repaired,
;  the trip counts below come out wrong.  For the hit/miss rates themselves,
;  watch take/flush in the waveform.
;
;  Result map:
;    0 loop A trips (12)       1 loop B trips (12)     2 re-entered loop (10)
;    3 alternating, odd (8)    4 alternating, even (8) 5 changing jalr target
;=============================================================================

        .text 0
        j    main

;-----------------------------------------------------------------------------
;  Loop A: its bnez sits at 0x48.
;-----------------------------------------------------------------------------
        .text 0x40
loopA:  addi r6, r6, 1              ; 0x40
        subi r5, r5, 1              ; 0x44
        bnez r5, loopA              ; 0x48  -> BTB row (0x48>>2) mod 16 = 2
        j    retA                   ; 0x4C

;-----------------------------------------------------------------------------
;  Loop B: its bnez sits at 0x88, exactly 64 bytes after loop A's, so it maps
;  to the same BTB row and the two keep evicting one another.
;-----------------------------------------------------------------------------
        .text 0x80
loopB:  addi r9, r9, 1              ; 0x80
        subi r7, r7, 1              ; 0x84
        bnez r7, loopB              ; 0x88  -> BTB row 2 as well
        j    retB                   ; 0x8C

;-----------------------------------------------------------------------------
        .text 0x90
main:
        add  r6, r0, r0
        add  r9, r0, r0
        add  r26, r0, r0
        addi r4, r0, 4              ; four alternations between A and B
alt:
        addi r5, r0, 3
        j    loopA
retA:
        addi r7, r0, 3
        j    loopB
retB:
        subi r4, r4, 1
        bnez r4, alt
        sw    0(r0), r6             ; 12
        sw    4(r0), r9             ; 12

;---- D3/D4/D5: the same inner loop entered twice ----------------------------
;  First entry is a cold BTB miss on every trip until the row is allocated;
;  the second entry starts with the row already saturated at "strongly taken".
        addi r13, r0, 2
        add  r12, r0, r0
reenter:
        addi r11, r0, 5
inner:  addi r12, r12, 1
        subi r11, r11, 1
        bnez r11, inner
        subi r13, r13, 1
        bnez r13, reenter
        sw    8(r0), r12            ; 10

;---- D6/D7: a branch that alternates every trip -----------------------------
;  Worst case for a 2-bit counter: whatever it predicts, it is wrong about
;  half the time, so both arms have to be repaired correctly.
        addi r14, r0, 16
        add  r15, r0, r0
        add  r16, r0, r0
altb:   andi r17, r14, 1
        beqz r17, alt_even
        addi r15, r15, 1            ; odd trips
        j    alt_next
alt_even:
        addi r16, r16, 1            ; even trips
alt_next:
        subi r14, r14, 1
        bnez r14, altb
        sw   12(r0), r15            ; 8
        sw   16(r0), r16            ; 8

;---- D9: one jalr instruction, two different targets ------------------------
;  The BTB records a JR/JALR target too.  The second pass must not jump to
;  the target cached from the first.
        addi r24, r0, jt_a
        addi r25, r0, 2
jrl:    jalr r24
        addi r24, r0, jt_b          ; next time round, somewhere else
        subi r25, r25, 1
        bnez r25, jrl
        sw   20(r0), r26            ; 1 + 10 = 11
        j    end

jt_a:   addi r26, r26, 1
        jr   r31
jt_b:   addi r26, r26, 10
        jr   r31

end:    j end
