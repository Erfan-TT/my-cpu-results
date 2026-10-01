;=============================================================================
;  18_given_mult_shift -- provided example: multiply feeding a shift loop
;=============================================================================
;  The program is the provided Mult0.asm, unchanged in what it computes.  What
;  is new is that the results now reach memory.
;
;  As provided, this test verified NOTHING: Mult0.asm has no store, so both the
;  golden image and the RTL image were 512 words of zero and --compare matched
;  no matter what the multiplier or the shifter did.  The four stores below
;  make the product, the pre-shift value, the trip count and the final value
;  observable.
;
;  The shape worth keeping is the loop body: 'srli' immediately followed by
;  'bnez' on the register it just wrote, i.e. a branch whose condition comes
;  from the instruction directly in front of it, with a data-dependent exit.
;  The trip counter is therefore incremented BEFORE the srli, so that
;  adjacency is preserved.
;
;  Result map:
;    0 product 6*7          1 product + 2      2 shift trips     3 final value
;=============================================================================

        .text

        addi r1, r0, 6
        addi r2, r0, 7
        mult r3, r1, r2             ; 42
        sw    0(r0), r3
        addi r3, r3, 2              ; 44 = 0b101100
        sw    4(r0), r3
        add  r4, r0, r0             ; trip counter

shift:
        addi r4, r4, 1
        srli r3, r3, 1              ; 22, 11, 5, 2, 1, 0
        bnez r3, shift              ; condition from the instruction in front

        sw    8(r0), r4             ; 6 trips
        sw   12(r0), r3             ; 0

fine:
        j fine
