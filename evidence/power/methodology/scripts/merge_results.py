#!/usr/bin/env python3
"""
merge_results.py -- join the three result files into one, plus a readable report.

Run from my-dlx-cpu/syn:

    python3 post_synthesis_sim/scripts/merge_results.py
    python3 post_synthesis_sim/scripts/merge_results.py --syn reports_v0/results.csv

Inputs
    reports/results.csv                              synthesis: timing, area, DC's
                                                     statistical power estimate
    post_synthesis_sim/results/gate_results.csv      post-synthesis pass/fail
    post_synthesis_sim/results/power_results.csv     back-annotated power per SAIF

Outputs
    post_synthesis_sim/results/final_results.csv     one row per corner, the file
                                                     plot_pareto.py reads
    post_synthesis_sim/results/final_report.txt      the same thing for humans

The CSV is the single source of truth; the .txt is generated from it, never
maintained beside it.
"""

import argparse
import csv
import os
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
SYN = os.path.abspath(os.path.join(HERE, "..", ".."))          # my-dlx-cpu/syn
PSS = os.path.join(SYN, "post_synthesis_sim")
RES = os.path.join(PSS, "results")


def corner_tag(period: str) -> str:
    """Rebuild synthesis.tcl's file tag from the %g-formatted period: 1 -> 1p0."""
    p = period.strip()
    if "." not in p:
        p += ".0"
    return p.replace(".", "p")


def load(path, required=True):
    if not os.path.exists(path):
        if required:
            sys.exit(f"missing input: {path}")
        return []
    with open(path, newline="") as f:
        return [r for r in csv.DictReader(f) if any(v.strip() for v in r.values())]


def fnum(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--syn", default=os.path.join(SYN, "reports", "results.csv"),
                    help="synthesis results.csv")
    ap.add_argument("--out-dir", default=RES)
    a = ap.parse_args()

    syn = load(a.syn)
    gate = load(os.path.join(RES, "gate_results.csv"), required=False)
    power = load(os.path.join(RES, "power_results.csv"), required=False)

    # ---- fold the per-test verdicts into a per-corner tally -----------------
    tally = defaultdict(lambda: {"PASS": 0, "FAIL": 0, "SKIP": 0, "fails": []})
    for r in gate:
        t = tally[r["tag"]]
        v = r.get("verdict", "").strip().upper()
        if v in t:
            t[v] += 1
        if v == "FAIL":
            t["fails"].append(r.get("test", "?"))

    # ---- power, keyed by corner then workload ------------------------------
    pw = defaultdict(dict)
    for r in power:
        pw[r["tag"]][r["workload"]] = r

    workloads = sorted({r["workload"] for r in power})

    # ---- build the joined rows ---------------------------------------------
    cols = ["tag", "period_ns", "achieved_ns", "slack_ns", "met", "area_um2",
            "sim_period_ns", "gate_pass", "gate_fail", "gate_skip", "gate_status",
            "dc_estimate_dynamic_mW", "dc_estimate_leakage_mW"]
    for w in workloads:
        cols += [f"dyn_mW_{w}", f"leak_mW_{w}", f"total_mW_{w}", f"saif_cov_{w}"]

    rows = []
    for s in syn:
        tag = s.get("tag") or corner_tag(s["period_ns"])
        t = tally.get(tag)
        p = pw.get(tag, {})

        if t is None:
            status = "not simulated"
        elif t["FAIL"]:
            status = f"FAIL ({t['FAIL']})"
        elif t["PASS"]:
            status = "pass"
        else:
            status = "no tests"

        sim_T = ""
        for w in workloads:
            if w in p:
                sim_T = p[w].get("sim_period_ns", "")
                break

        row = {
            "tag": tag,
            "period_ns": s.get("period_ns", ""),
            "achieved_ns": s.get("achieved_ns", ""),
            "slack_ns": s.get("slack_ns", ""),
            "met": s.get("met", ""),
            "area_um2": s.get("area_um2", ""),
            "sim_period_ns": sim_T,
            "gate_pass": t["PASS"] if t else "",
            "gate_fail": t["FAIL"] if t else "",
            "gate_skip": t["SKIP"] if t else "",
            "gate_status": status,
            # DC's pre-SAIF statistical estimate, in mW, kept for the comparison
            "dc_estimate_dynamic_mW": (lambda v: "" if v is None else f"{v * 1e3:.4f}")(
                fnum(s.get("dynamic_power"))),
            "dc_estimate_leakage_mW": (lambda v: "" if v is None else f"{v * 1e3:.4f}")(
                fnum(s.get("leakage_power"))),
        }
        for w in workloads:
            e = p.get(w, {})
            row[f"dyn_mW_{w}"] = e.get("dynamic_mW", "")
            row[f"leak_mW_{w}"] = e.get("leakage_mW", "")
            row[f"total_mW_{w}"] = e.get("total_mW", "")
            row[f"saif_cov_{w}"] = e.get("saif_coverage_pct", "")
        rows.append(row)

    rows.sort(key=lambda r: fnum(r["period_ns"]) or 0.0)

    os.makedirs(a.out_dir, exist_ok=True)
    out_csv = os.path.join(a.out_dir, "final_results.csv")
    with open(out_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print("wrote", out_csv)

    # ---- the human-readable twin -------------------------------------------
    L = []
    A = L.append
    A("=" * 78)
    A("  DLX -- synthesis and post-synthesis summary")
    A("=" * 78)
    A("")
    A(f"  synthesis results : {a.syn}")
    A(f"  corners           : {len(rows)}")
    A(f"  SAIF workloads    : {', '.join(workloads) if workloads else '(none yet)'}")
    A("")
    A("  Slack is the worst over ALL path groups (REG2REG is normally the one")
    A("  that binds).  achieved = constraint - slack, and is the period each")
    A("  netlist was simulated at.")
    A("")

    A("-" * 78)
    A("  TIMING AND AREA")
    A("-" * 78)
    A(f"  {'T con':>6} {'slack':>8} {'achieved':>9} {'met':>4} {'area um2':>10}  gate sim")
    for r in rows:
        A(f"  {r['period_ns']:>6} {r['slack_ns']:>8} {r['achieved_ns']:>9} "
          f"{'yes' if r['met'] == '1' else 'NO':>4} "
          f"{(fnum(r['area_um2']) or 0):>10.1f}  {r['gate_status']}")

    viol = [fnum(r["achieved_ns"]) for r in rows if r["met"] == "0" and fnum(r["achieved_ns"])]
    met = [fnum(r["period_ns"]) for r in rows if r["met"] == "1" and fnum(r["period_ns"])]
    A("")
    if viol:
        A(f"  best extrapolated period (min of T - slack over violating corners) : {min(viol):.3f} ns"
          f"   ->  {1000 / min(viol):.1f} MHz")
    if met:
        A(f"  first constraint actually met                                      : {min(met):.2f} ns"
          f"   ->  {1000 / min(met):.1f} MHz")
    A("")
    A("  The two differ because DC stops optimising once a constraint is met, so")
    A("  T - slack at an over-constrained corner is an extrapolation while the")
    A("  first met corner is a measurement.  Quote both and say which is which.")
    A("")

    if power:
        A("-" * 78)
        A("  BACK-ANNOTATED POWER  (SAIF from the gate-level simulation)")
        A("-" * 78)
        for w in workloads:
            A("")
            A(f"  workload: {w}")
            A(f"  {'T sim':>7} {'dyn mW':>9} {'leak mW':>9} {'total mW':>9} {'cov %':>7}"
              f"  {'DC estimate':>12}  ratio")
            for r in rows:
                d = fnum(r.get(f"dyn_mW_{w}"))
                if d is None:
                    continue
                est = fnum(r["dc_estimate_dynamic_mW"])
                ratio = f"{d / est:.2f}x" if est else "-"
                A(f"  {r['sim_period_ns']:>7} {d:>9.4f} "
                  f"{(fnum(r.get(f'leak_mW_{w}')) or 0):>9.4f} "
                  f"{(fnum(r.get(f'total_mW_{w}')) or 0):>9.4f} "
                  f"{(fnum(r.get(f'saif_cov_{w}')) or 0):>7.1f}"
                  f"  {(est or 0):>12.4f}  {ratio}")
        A("")
        A("  'DC estimate' is the number report_power gives with no SAIF, from")
        A("  uniform default toggle rates.  The ratio is how far that guess was")
        A("  from the measured activity -- worth one line in the report.")
        low = [(r["tag"], w, fnum(r.get(f"saif_cov_{w}")))
               for r in rows for w in workloads
               if fnum(r.get(f"saif_cov_{w}")) is not None and fnum(r.get(f"saif_cov_{w}")) < 90]
        if low:
            A("")
            A("  *** SAIF coverage below 90% on:")
            for tag, w, c in low:
                A(f"        {tag} / {w}: {c:.1f}%")
            A("      Part of those numbers is DC's estimate, not measured switching.")
        A("")

    fails = [(r["tag"], tally[r["tag"]]["fails"]) for r in rows
             if r["tag"] in tally and tally[r["tag"]]["fails"]]
    if fails:
        A("-" * 78)
        A("  POST-SYNTHESIS FAILURES")
        A("-" * 78)
        for tag, names in fails:
            A(f"  {tag}: {', '.join(names)}")
        A("")

    out_txt = os.path.join(a.out_dir, "final_report.txt")
    with open(out_txt, "w") as f:
        f.write("\n".join(L) + "\n")
    print("wrote", out_txt)
    print()
    print("\n".join(L))


if __name__ == "__main__":
    main()
