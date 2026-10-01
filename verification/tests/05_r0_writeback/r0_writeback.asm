;=============================================================================
;  05_r0_writeback -- a discarded r0 write must not reach the RF bypass
;=============================================================================
;  Checklist: A11, C9.  Companion to 04_r0_source, which covers the EX->EX and
;  MEM->EX distances; this one is the writeback / register-file-bypass
;  distance, where the producer is in WB while the consumer is in ID.
;
;  The answer being checked is a ZERO, so word 0 carries a liveness marker
;  first: without it an image of all zeros would also be produced by a program
;  that never ran at all, and the compare could not tell the difference.
;
;  Result map:  0 marker (0x5EED), must be present
;               1 r4, must be 0 and never the discarded 10
;=============================================================================

        .text

        addi r9, r0, 24301          ; 0x5EED, liveness marker
        sw   0(r0), r9

        addi r1, r0, 5
        add  r0, r1, r1             ; result 10, must be discarded
        nop
        nop
        addi r4, r0, 0              ; producer is in WB while this is in ID
        sw   4(r0), r4
end:
        j end
