; Compact exception exercise -- one hit per cause, plus both illegal
; special-register indices.  Every handler dumps marker/CAUSE/TVAL/STATUS/IAR
; and returns with IAR+4, so the run is fully checkable against dlxsim.py.
;
; NOTE: the FP mnemonics (addf, multf, ...) are NOT usable as "illegal
; instruction" here -- they all assemble to opcode 0x01, which this ISA uses
; for bltz, so they execute as a branch.  Use sb/sh/lf/sf/itlb or a .word.
        addi r1, r0, vector_base
        movi2s VBR, r1
        j main
        nop                         ; pad: special_pc substitutes CAUSE into
                                    ; PC bits 3:2, so VBR must be 16-byte aligned

vector_base:
        j illegal_handler           ; cause 0
        j trap_handler              ; cause 1
        j inst_mis_handler          ; cause 2
        j data_mis_handler          ; cause 3

main:
        add  r10, r0, r0            ; dump pointer

        trap 7                      ; cause 1, tval 7
        .word 0x00000000            ; cause 0 : opcode 0 with func 0 is illegal
        lw   r19, 18(r0)            ; cause 3, tval 18
        addi r3, r0, 9
        jr   r3                     ; cause 2, tval 9

        movi2s r30, r1              ; cause 0 : SR write index 30 >= 5
        movs2i r4,  r30             ; cause 0 : SR read  index 30 >= 5

        movs2i r5, STATUS           ; after all returns: IE back, EXL clear
        sw  0(r10), r5
        addi r10, r10, 4
        j end
end:
        j end

illegal_handler:
        addi r11, r0, 100
        j    common
trap_handler:
        addi r11, r0, 200
        j    common
inst_mis_handler:
        addi r11, r0, 300
        j    common
data_mis_handler:
        addi r11, r0, 400
common:
        sw  0(r10), r11
        addi r10, r10, 4
        movs2i r5, CAUSE
        sw  0(r10), r5
        addi r10, r10, 4
        movs2i r5, TVAL
        sw  0(r10), r5
        addi r10, r10, 4
        movs2i r5, STATUS
        sw  0(r10), r5
        addi r10, r10, 4
        movs2i r8, IAR
        sw  0(r10), r8
        addi r10, r10, 4
        addi r8, r8, 4
        movi2s IAR, r8
        RFE
