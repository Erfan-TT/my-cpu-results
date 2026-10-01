        addi r1, r0, 6          ; 0x00
        addi r2, r0, 7          ; 0x04
        mult r3, r1, r2         ; 0x08 42
        add  r4, r3, r1         ; 0x0c 48
        sub  r5, r4, r2         ; 0x10 41
        sw   0(r0), r3          ; 0x14
        sw   4(r0), r4          ; 0x18
        sw   8(r0), r5          ; 0x1c
        lw   r6, 0(r0)          ; 42  (load-use follows)
        add  r7, r6, r5         ; 83
        sw   12(r0), r7
        mult r8, r7, r2         ; 581 (mult straight after a load result)
        sw   16(r0), r8
end:
        j end

; end-to-end cross-check: arithmetic, multiply, load/store

