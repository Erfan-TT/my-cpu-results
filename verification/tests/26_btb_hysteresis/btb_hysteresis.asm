;=============================================================================
;  26_btb_hysteresis -- BTB allocation, hits and the 2-bit counter
;=============================================================================
;  Checklist: D3 (cold miss), D4 (hit once the row is allocated), D12 (one
;  not-taken does not flip a saturated prediction), and the other half of the
;  same rule: from the weak state one not-taken does flip it.
;
;  btb.vhd allocates a conditional branch only when it is taken, with the
;  counter at "10" (weakly taken).  Taken counts up, not-taken counts down,
;  both saturating, and the counter MSB is the prediction.
;
;  Branch hb (phase 1) is taken on every trip except trip 4 of 8:
;     trip              1    2    3    4    5    6    7    8
;     counter before    -    10   11   11   10   11   11   11
;     predicted         NT   T    T    T    T    T    T    T
;     outcome           T    T    T    NT   T    T    T    T
;     mispredict        x              x
;  Trip 1 is the cold miss, trips 2-3 the hits, trip 5 the hysteresis check:
;  still predicted taken although trip 4 was not taken.
;
;  Branch wb (phase 2) goes taken, not taken, taken:
;     counter before    -    10   01
;     predicted         NT   T    NT
;     outcome           T    NT   T
;     mispredict        x    x    x
;
;  A data dump cannot see a prediction, only which arm each trip took.  The
;  predictions are read off the VCD by check_timing.py: take_t while the
;  branch is fetched, flush_t while it is in ID.  The producers of r3 sit
;  three instructions ahead of each branch, so no operand stall blurs that.
;
;  hb, wb and the loop branches are all inside the first 64 bytes of their
;  phase, so none of them shares a BTB row (index pc[5:2]) with another
;  branch that runs between two of its trips.
;
;  Result map:
;    0 phase 1 taken trips (7)       1 phase 1 not-taken trips (1)
;    2 phase 2 taken trips (2)       3 phase 2 not-taken trips (1)
;=============================================================================

        .text
        addi r1, r0, 8              ; trips
        add  r2, r0, r0             ; trip number
        add  r10, r0, r0            ; taken
        add  r11, r0, r0            ; not taken
p1:
        addi r2, r2, 1
        subi r3, r2, 4              ; zero only on trip 4
        nop
        nop
hb:     bnez r3, p1_t               ; taken except on trip 4
        addi r11, r11, 1
        j    p1_next
p1_t:   addi r10, r10, 1
p1_next:
        subi r1, r1, 1
        bnez r1, p1
        sw   0(r0), r10             ; 7
        sw   4(r0), r11             ; 1

        addi r1, r0, 3
        add  r2, r0, r0
        add  r12, r0, r0
        add  r13, r0, r0
p2:
        addi r2, r2, 1
        andi r3, r2, 1              ; 1 on odd trips
        nop
        nop
wb:     bnez r3, p2_t               ; taken, not taken, taken
        addi r13, r13, 1
        j    p2_next
p2_t:   addi r12, r12, 1
p2_next:
        subi r1, r1, 1
        bnez r1, p2
        sw   8(r0), r12             ; 2
        sw   12(r0), r13            ; 1

end:    j end
