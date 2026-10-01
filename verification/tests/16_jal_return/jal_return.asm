        addi r1, r0, 7
        mult r3, r1, r1
        sw   8(r0), r3
        jal  sub1
        sw   0(r0), r31         ; link value
        sw   4(r0), r2          ; 8
end:
        j end
sub1:
        addi r2, r1, 1
        jr   r31
