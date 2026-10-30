"""check_timing.py -- the checklist rows a memory dump cannot see.

Reads the VCDs of 26_btb_hysteresis and 28_nested_exception and checks, cycle
by cycle, what the CPU did rather than what it computed:

  D3/D4/D12  every execution of branches hb and wb: was it predicted taken
             (take_t while it is fetched), and was it a misprediction
             (flush_t while it is in ID)?  Compared with the table in the
             header of btb_hysteresis.asm.
  F12        the trap's vector entry, a branch on r21, must reach ID with no
             hazard stall, although a squashed load to r21 was in ID when the
             trap committed (special_pc_sel_t).

Make the VCDs first, from this directory:
    vsim -c -do "set vcd 1; set only 26_; source run_tests.tcl; quit -f"
    vsim -c -do "set vcd 1; set only 28_; set recompile 0; source run_tests.tcl; quit -f"
then:
    python3 check_timing.py
Exit status 0 when every check passes.
"""
import re
import sys

TESTS = "../tests"
NOP_WORD = 0x54000000          # what fetch puts in IR on a bubble or a flush

SIGS = {
    "clk":   ("dlx_i", "CLK"),
    "rst":   ("dlx_i", "RST"),
    "if_pc": ("dlx_i", "IRAM_ADDRESS"),
    "id_pc": ("dlx_i.dp_i", "pc_decode_t"),      # bits 31:2, byte-indexed
    "ir":    ("dlx_i.dp_i", "IR_t"),
    "take":  ("dlx_i.dp_i.fetch_i", "take_t"),
    "flush": ("dlx_i", "flush_t"),
    "stall": ("dlx_i.cp_i", "hazard_stall_t"),
    "commit": ("dlx_i", "special_pc_sel_t"),
}


def labels(list_path):
    out = {}
    for line in open(list_path, encoding="latin-1"):
        m = re.match(r"\s*\d+\s+([0-9a-f]{8})\s+(?:[0-9a-f]{8})?\s*(\w+):", line)
        if m:
            out[m.group(2)] = int(m.group(1), 16)
    return out


def cycles(vcd_path):
    """One dict per clock cycle after reset: every signal's value just before
    the rising edge that ends the cycle (None for X/U/Z)."""
    want = {(s.lower(), n.lower()): k for k, (s, n) in SIGS.items()}
    idmap, scope = {}, []
    cur = {k: {} for k in SIGS}
    samples, prev_clk = [], "0"
    with open(vcd_path, encoding="latin-1") as f:
        for line in f:
            line = line.strip()
            if line.startswith("$scope"):
                scope.append(line.split()[2])
            elif line.startswith("$upscope"):
                scope.pop()
            elif line.startswith("$var"):
                p = line.split()
                bit = int(p[5].strip("[]")) if len(p) > 6 and p[5].startswith("[") else 0
                key = (".".join(scope[1:]).lower(), p[4].lower())
                if key in want:
                    idmap.setdefault(p[3], []).append((want[key], bit))
            elif line.startswith("$enddefinitions"):
                break
        pending = []
        for line in f:
            line = line.strip()
            if not line or line[0] == "$":
                continue
            if line[0] == "#":
                # apply the previous time step; on a rising clock edge, sample
                # first, so nothing that changes at the edge is in the sample
                if any(k == "clk" and v == "1" for k, _, v in pending) and prev_clk == "0":
                    samples.append({s: dict(b) for s, b in cur.items()})
                for k, bit, val in pending:
                    cur[k][bit] = val
                    if k == "clk":
                        prev_clk = val
                pending = []
                continue
            if line[0] in "01xzXZ":
                for k, bit in idmap.get(line[1:], []):
                    pending.append((k, bit, line[0]))
    missing = [k for k in SIGS if not any(k == x for v in idmap.values() for x, _ in v)]
    if missing:
        sys.exit(f"{vcd_path}: signals not in the VCD: {', '.join(missing)}")

    def num(bits):
        if not bits or any(b not in "01" for b in bits.values()):
            return None
        return sum(1 << i for i, b in bits.items() if b == "1")

    rows = [{k: num(b) for k, b in s.items()} for s in samples]
    start = next(i for i, r in enumerate(rows) if r["rst"] == 0)
    return rows[start:]


def occurrences(cyc, addr):
    """Executions of the instruction at addr: runs of consecutive cycles in
    which it sits in ID (a stall stretches one run), bubbles excluded."""
    runs, run = [], []
    for c, r in enumerate(cyc):
        if r["id_pc"] == addr and r["ir"] not in (None, NOP_WORD):
            run.append(c)
        elif run:
            runs.append(run)
            run = []
    if run:
        runs.append(run)
    return runs


FAILS = []


def check(ok, what):
    print(f"    {'ok  ' if ok else 'FAIL'}  {what}")
    if not ok:
        FAILS.append(what)


def branch(cyc, name, addr, expect):
    """expect: list of (predicted_taken, mispredicted), one per execution."""
    print(f"  {name} at 0x{addr:x}")
    print("    trip  cycle  predicted  mispredict")
    occ = occurrences(cyc, addr)
    got = []
    for n, run in enumerate(occ, 1):
        c0 = run[0]
        fetched = [c for c in range(c0 - 1, max(c0 - 4, -1), -1) if cyc[c]["if_pc"] == addr]
        pred = cyc[fetched[0]]["take"] if fetched else None
        flush = int(any(cyc[c]["flush"] == 1 for c in run))
        got.append((pred, flush))
        print(f"    {n:4}  {c0 + 1:5}  {'T ' if pred else 'NT' if pred == 0 else '? ':>9}"
              f"  {'yes' if flush else 'no':>10}")
    check(len(got) == len(expect), f"{name}: {len(expect)} executions (saw {len(got)})")
    for n, (g, e) in enumerate(zip(got, expect), 1):
        check(g == e, f"{name} trip {n}: predicted {'T' if e[0] else 'NT'}, "
                      f"mispredict {'yes' if e[1] else 'no'}")


def btb():
    base = f"{TESTS}/26_btb_hysteresis/btb_hysteresis"
    print(f"\n26_btb_hysteresis  ({base}.vcd)")
    lab, cyc = labels(base + ".list"), cycles(base + ".vcd")
    T, N = 1, 0
    #       trip:  1        2        3        4        5        6        7        8
    branch(cyc, "hb (D3, D4, D12)", lab["hb"],
           [(N, 1), (T, 0), (T, 0), (T, 1), (T, 0), (T, 0), (T, 0), (T, 0)])
    branch(cyc, "wb (weak state)", lab["wb"], [(N, 1), (T, 1), (N, 1)])


def nested():
    base = f"{TESTS}/28_nested_exception/nested_exception"
    print(f"\n28_nested_exception  ({base}.vcd)")
    lab, cyc = labels(base + ".list"), cycles(base + ".vcd")
    entry = lab["vec_table"] + 4            # VBR + (cause 1 << 2)
    commits = [c for c, r in enumerate(cyc) if r["commit"] == 1]
    occ = occurrences(cyc, entry)
    print(f"  exception commits at cycles {[c + 1 for c in commits]}")
    check(len(occ) == 1, f"trap vector entry 0x{entry:x} executed once (saw {len(occ)})")
    if occ and commits:
        run = occ[0]
        first = commits[0]
        print(f"  trap commit at cycle {first + 1}, vector entry in ID at cycle {run[0] + 1}"
              f" for {len(run)} cycle(s)")
        check(all(cyc[c]["stall"] == 0 for c in run),
              "F12: no hazard stall on the vector entry (scoreboard flushed on commit)")
        check(len(run) == 1, "F12: the vector entry spends one cycle in ID")


if __name__ == "__main__":
    btb()
    nested()
    print()
    if FAILS:
        print(f"{len(FAILS)} check(s) failed")
        sys.exit(1)
    print("all timing checks passed")
