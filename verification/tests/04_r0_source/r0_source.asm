; does a write to r0 leak through forwarding / the RF bypass?
        addi r1, r0, 5
        add  r0, r1, r1         ; result 10, must be discarded
        add  r2, r0, r1         ; EX->EX distance : r2 must be 5
        addi r3, r0, 0          ; MEM->EX distance : r3 must be 0
        nop
        addi r4, r0, 0          ; WB / RF-bypass distance : r4 must be 0
        sw   0(r0), r2
        sw   4(r0), r3
        sw   8(r0), r4
end:
        j end
