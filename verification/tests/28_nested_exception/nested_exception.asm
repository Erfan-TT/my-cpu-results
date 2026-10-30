;=============================================================================
;  28_nested_exception -- an exception raised inside a handler
;=============================================================================
;  Checklist F11 and F12.
;
;  F11.  The hardware has no special case for an exception taken while EXL is
;  already 1: the commit overwrites IAR, CAUSE and TVAL and stacks the STATUS
;  bits again (PIE <- IE, IE <- 0, EXL <- 1).  A handler that wants to cause
;  or survive a nested exception therefore saves IAR and STATUS first and
;  restores them before its own rfe.  This program does exactly that:
;     main         trap 7                    STATUS 1 -> 6  (PIE=1 EXL=1 IE=0)
;     trap handler saves IAR/STATUS, then a misaligned lw (cause 3)
;                                            STATUS 6 -> 2  (PIE=0 EXL=1 IE=0)
;     data handler logs, rfe                 STATUS 2 -> 0  (IE <- PIE = 0)
;     trap handler restores STATUS = 6 and IAR, rfe
;                                            STATUS 6 -> 5  (IE <- PIE = 1)
;  Every STATUS value on the way is stored, so the golden model checks the
;  stacking at each step.
;
;  F12.  When the trap commits in MEM, the two loads behind it are squashed.
;  The second is still in ID at that moment, and without the scoreboard flush
;  on commit (special_pc_sel) it would leave r21 marked busy for two cycles.
;  The trap's vector entry is a branch on r21, in ID two cycles after the
;  commit, so a missed flush shows up as a hazard stall right there.
;  check_timing.py looks for that stall in the VCD.  r21 also checks the squash:
;  if either load wrote r21 before the vector entry read it, the branch would
;  fall through to the next entry and other_handler would mark word 11.
;
;  Result map:
;    0 STATUS in the trap handler (6)    1 CAUSE there (1)    2 TVAL there (7)
;    3 CAUSE nested (3)                  4 TVAL nested (3)    5 IAR nested (lw_bad)
;    6 STATUS nested (2)                 7 STATUS after the nested rfe (0)
;    8 STATUS back in main (5)           9 nested returns (1)
;   10 r21 after the trap returns (0x123, the loads ran once, after the trap)
;   11 unexpected cause, must stay 0
;=============================================================================

        .text
        addi   r1, r0, vec_table
        movi2s VBR, r1
        j      main
        nop                         ; pad: VBR must be 16-byte aligned

vec_table:
        j     other_handler         ; cause 0, illegal
        beqz  r21, trap_handler     ; cause 1, trap -- see F12 above
        j     other_handler         ; cause 2, misaligned target
        j     dmis_handler          ; cause 3, misaligned data

main:
        add  r21, r0, r0            ; stays 0 until the loads below retire
        add  r26, r0, r0            ; nested returns
        addi r22, r0, 0x123
        sw   60(r0), r22            ; what the loads behind the trap read
        nop
        nop
        trap 7
        lw   r21, 60(r0)            ; squashed at the commit, runs after rfe
        lw   r21, 60(r0)            ; in ID at the commit
        movs2i r11, STATUS
        sw   32(r0), r11            ; 5
        sw   36(r0), r26            ; 1
        sw   40(r0), r21            ; 0x123
        j    end

trap_handler:
        movs2i r24, IAR             ; save the outer state
        movs2i r25, STATUS
        sw   0(r0), r25             ; 6
        movs2i r11, CAUSE
        sw   4(r0), r11             ; 1
        movs2i r11, TVAL
        sw   8(r0), r11             ; 7
        addi r12, r0, 2
lw_bad: lw   r13, 1(r12)            ; address 3: nested DATA_ADDR_MISALIGNED
        addi r26, r26, 1            ; the nested handler returns here
        movs2i r11, STATUS
        sw   28(r0), r11            ; 0
        movi2s STATUS, r25          ; restore the outer state
        addi r24, r24, 4            ; and step over the trap
        movi2s IAR, r24
        rfe

dmis_handler:
        movs2i r11, CAUSE
        sw   12(r0), r11            ; 3
        movs2i r11, TVAL
        sw   16(r0), r11            ; 3
        movs2i r8, IAR
        sw   20(r0), r8             ; lw_bad
        movs2i r11, STATUS
        sw   24(r0), r11            ; 2
        addi r8, r8, 4
        movi2s IAR, r8
        rfe

other_handler:
        addi r11, r0, 999
        sw   44(r0), r11
        movs2i r8, IAR
        addi r8, r8, 4
        movi2s IAR, r8
        rfe

end:    j end
