#!/usr/bin/env python3
"""Collect the place-and-route runs into results/.

    python3 collect_pd_results.py

results/pd_results.csv   one row per run: timing (typical, slow and fast
                         corners), area, checks, post-layout simulation, and
                         the synthesis values of the same netlist next to them
results/pd_power.csv     one row per run and workload: post-layout power and
                         energy per program run, with the post-synthesis power
                         of the same netlist and workload for comparison
"""

import csv
import gzip
import re
from pathlib import Path

PD = Path(__file__).resolve().parent
RUNS = PD / "runs"
RESULTS = PD / "results"
SYN = PD.parent / "syn"


def read(path):
    if not path.exists():
        return ""
    if path.suffix == ".gz":
        return gzip.open(path, "rt", errors="replace").read()
    return path.read_text(errors="replace")


def number(pattern, text, cast=float):
    m = re.search(pattern, text, re.M)
    return cast(m.group(1)) if m else None


def csv_rows(path):
    if not path.exists():
        return []
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def worst_slack(slk):
    """First path of a .slk report, third field "rise/fall"."""
    lines = slk.splitlines()
    if len(lines) < 2:
        return None
    return min(float(s) for s in lines[1].split()[2].split("/") if s != "*")


def view_wns(summary, view):
    """WNS of one view in an -expandedViews timeDesign summary."""
    return number(r"^\|%s\s*\|\s*(-?[0-9.]+)" % view, summary)


def violations(text, clean_pattern, count_pattern):
    if not text:
        return ""
    if re.search(clean_pattern, text):
        return 0
    n = number(count_pattern, text, int)
    return n if n is not None else "?"


syn = {r["tag"]: r for r in csv_rows(SYN / "reports" / "results.csv")}
syn_power = {(r["tag"], r["workload"]): r
             for r in csv_rows(SYN / "post_synthesis_sim" / "results" / "power_results.csv")}
sim = csv_rows(RESULTS / "sim" / "gate_results.csv")
manifest = {(r["tag"], r["workload"]): r for r in csv_rows(RESULTS / "sim" / "saif_manifest.csv")}

runs, power = [], []
for run in sorted(p for p in RUNS.iterdir() if p.is_dir()) if RUNS.exists() else []:
    info = dict(l.split() for l in read(run / "outputs/run_info.txt").splitlines() if len(l.split()) == 2)
    wns = worst_slack(read(run / "reports/timing/10_final.slk"))
    if not info or wns is None:
        print(f"{run.name}: not finished")
        continue
    name, tag, clock = run.name, info["tag"], float(info["clock"])
    whs = worst_slack(read(run / "reports/timing/10_final_hold.slk"))
    wns_slow = view_wns(read(run / "reports/timing/11_corners.summary.gz"), "worst")
    whs_fast = view_wns(read(run / "reports/timing/11_corners_hold.summary.gz"), "best")
    area = read(run / "reports/10_area.rpt")
    tests = [r for r in sim if r["tag"] == name]
    s = syn.get(tag, {})
    runs.append({
        "run": name, "netlist": tag, "clock_ns": clock,
        "setup_wns_ns": wns, "achieved_ns": round(clock - wns, 4),
        "hold_wns_ns": whs,
        "achieved_slow_ns": round(clock - wns_slow, 4) if wns_slow is not None else "",
        "hold_wns_fast_ns": whs_fast if whs_fast is not None else "",
        "cells": number(r"^DLX\s+(\d+)\s+[0-9.]+", area, int),
        "area_um2": number(r"^DLX\s+\d+\s+([0-9.]+)", area),
        "drc": violations(read(run / "reports/09_drc.rpt"), r"No DRC violations", r"Total Violations\s*:\s*(\d+)"),
        "connectivity": violations(read(run / "reports/09_connectivity.rpt"), r"Found no problems",
                                   r"(\d+)\s+(?:total\s+)?(?:Problem|Violation)"),
        "sim_pass": sum(r["verdict"] == "PASS" for r in tests),
        "sim_fail": sum(r["verdict"] == "FAIL" for r in tests),
        "syn_achieved_ns": s.get("achieved_ns", ""), "syn_area_um2": s.get("area_um2", ""),
    })

    for rpt in sorted((run / "reports").glob("12_power_*.rpt")):
        wl = rpt.stem[len("12_power_"):]
        text = read(rpt)
        internal = number(r"Total Internal Power:\s*([0-9.eE+-]+)", text)
        switching = number(r"Total Switching Power:\s*([0-9.eE+-]+)", text)
        leakage = number(r"Total Leakage Power:\s*([0-9.eE+-]+)", text)
        total = number(r"Total Power:\s*([0-9.eE+-]+)", text)
        m = manifest.get((name, wl), {})
        period = float(m["sim_period_ns"]) if m else None
        window = int(m["window_cycles"]) if m and m.get("window_cycles") else None
        sp = syn_power.get((tag, wl), {})
        power.append({
            "run": name, "workload": wl, "sim_period_ns": period or "",
            "internal_mW": internal, "switching_mW": switching, "leakage_mW": leakage,
            "total_mW": round(total, 4) if total is not None else None,
            "coverage": number(r"Total Nets\s*:\s*\S+\s*=\s*([0-9.]+)%", text) or "",
            "window_cycles": window or "",
            "energy_nJ": round(total * period * window / 1000, 4) if total and period and window else "",
            "syn_total_mW": sp.get("total_mW", ""), "syn_sim_period_ns": sp.get("sim_period_ns", ""),
        })

RESULTS.mkdir(exist_ok=True)
for name, rows in (("pd_results.csv", runs), ("pd_power.csv", power)):
    if rows:
        with open(RESULTS / name, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)

print(f"\n{'run':<10}{'clock':>8}{'achieved':>10}{'slow':>8}{'hold':>8}{'area':>10}"
      f"{'syn area':>10}{'DRC':>5}{'conn':>6}{'sim':>8}")
for r in runs:
    print(f"{r['run']:<10}{r['clock_ns']:>8}{r['achieved_ns']:>10}{r['achieved_slow_ns']!s:>8}"
          f"{r['hold_wns_ns']!s:>8}{r['area_um2']!s:>10}{r['syn_area_um2']!s:>10}"
          f"{r['drc']!s:>5}{r['connectivity']!s:>6}{r['sim_pass']:>4}/{r['sim_pass'] + r['sim_fail']:<3}")
if power:
    print(f"\n{'run':<10}{'workload':<18}{'period':>7}{'total mW':>10}{'syn mW':>9}{'energy nJ':>11}{'cov %':>7}")
    for p in power:
        print(f"{p['run']:<10}{p['workload']:<18}{p['sim_period_ns']!s:>7}{p['total_mW']!s:>10}"
              f"{p['syn_total_mW']!s:>9}{p['energy_nJ']!s:>11}{p['coverage']!s:>7}")
print(f"\nwritten to {RESULTS}")
