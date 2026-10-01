;=============================================================================
;  23_misaligned_jump_repeat -- a misaligned jr executed more than once
;=============================================================================
;  The BTB used to be told to INVALIDATE the row of any branch whose target was
;  misaligned, so such a jump was never predicted.  That invalidate path was
;  removed because it put target_in(1 downto 0) -- and therefore the register
;  file read -- on the BTB write-enable, which was the critical path.
;
;  Dropping it means a misaligned jump now DOES get a BTB entry, with the
;  target truncated to bits 31:2 (the BTB cannot store the low two bits), so on
;  every execution after the first it is predicted taken to the truncated
;  address.  The claim is that this costs one wasted speculative fetch and
;  nothing else: the jump still resolves in ID, illegal_detector still raises
;  INST_ADDR_MISALIGNED with the full misaligned target as TVAL, and the
;  exception still squashes whatever was fetched speculatively.
;
;  No existing test executed a misaligned jump twice, so nothing checked that.
;  This one runs it three times and logs CAUSE and TVAL each trip -- so trips 2
;  and 3, the predicted ones, have to look exactly like trip 1.
;
;  The truncated target points at 'poison', which stores a sentinel.  If
;  speculation past the faulting jump can ever retire, word 10 comes back as
;  0xBADBAD and the whole premise is wrong.
;
;  Result map:
;    0,1  trip 1: CAUSE, TVAL      2,3  trip 2      4,5  trip 3
;    8    trips completed (3)
;   10    sentinel slot -- must stay 0
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
        add  r10, r0, r0            ; exception log pointer
        addi r5, r0, 3              ; three trips
        add  r6, r0, r0             ; completed counter
        addi r3, r0, poison+1       ; misaligned: truncates to 'poison'
        nop
        nop

loop:
        jr   r3                     ; must fault every trip, predicted or not
        addi r6, r6, 1              ; the handler returns here, IAR+4
        subi r5, r5, 1
        bnez r5, loop

        sw   32(r0), r6             ; 3
        j    end

;  Reached only if a speculative fetch of the truncated target ever retires.
poison:
        lhi  r20, 0x00BA
        ori  r20, r20, 0xDBAD
        sw   40(r0), r20            ; 0xBADBAD would mean speculation committed
        j    end

end:    j end

inst_mis_handler:
        movs2i r11, CAUSE
        sw   0(r10), r11            ; 2 every trip
        movs2i r11, TVAL
        sw   4(r10), r11            ; the full misaligned target, every trip
        addi r10, r10, 8
        movs2i r8, IAR
        addi r8, r8, 4              ; step over the faulting jr
        movi2s IAR, r8
        rfe

other_handler:
        addi r11, r0, 999           ; an unexpected cause would show up here
        sw  44(r0), r11
        movs2i r8, IAR
        addi r8, r8, 4
        movi2s IAR, r8
        rfe
