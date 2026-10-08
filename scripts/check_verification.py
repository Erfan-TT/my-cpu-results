#!/usr/bin/env python3
"""Check the archived V7 final-memory evidence against the declared status,
and tabulate the RTL cycle counts of every version."""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def words(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8", errors="ignore").split()


def main() -> None:
    summary = ROOT / "data" / "verification_results.csv"
    with summary.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    counts = {"pass": 0, "xfail": 0, "skip": 0}
    problems: list[str] = []
    for row in rows:
        status = row["status"]
        counts[status] += 1
        if status == "skip":
            continue
        evidence = ROOT / "verification" / "tests" / row["test"] / row["evidence"]
        match = re.match(r"(.+)_dmem_rtl(?:_[a-z]+)?\.txt$", evidence.name)
        if not match:
            problems.append(f"cannot derive golden filename from {evidence}")
            continue
        golden = evidence.with_name(match.group(1) + "_dmem_golden.txt")
        if not evidence.exists() or not golden.exists():
            problems.append(f"missing evidence or golden file for {row['test']}/{row['mode']}")
            continue
        equal = words(evidence) == words(golden)
        if status == "pass" and not equal:
            problems.append(f"declared pass does not match: {row['test']}/{row['mode']}")
        if status == "xfail" and equal:
            problems.append(f"declared xfail unexpectedly matches: {row['test']}/{row['mode']}")
    if problems:
        raise SystemExit("verification evidence check failed:\n" + "\n".join(problems))
    print(f"verified archive: {counts['pass']} exact matches, {counts['xfail']} expected mismatches, {counts['skip']} skip")
    cycle_table()


def cycle_table() -> None:
    """Join every version's RTL results into one test x version cycle table.

    Cycles run from reset to the program's final self-loop.  The table is the
    evidence that the revisions change the clock period and nothing else."""
    versions = sorted(p.parent.name for p in (ROOT / "evidence" / "rtl").glob("V*/rtl_results.csv"))
    cycles: dict[tuple[str, str], dict[str, str]] = {}
    for version in versions:
        path = ROOT / "evidence" / "rtl" / version / "rtl_results.csv"
        with path.open(newline="", encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                if row["verdict"] == "PASS":
                    cycles.setdefault((row["test"], row["mode"]), {})[version] = row["cycles"]
    differing = [key for key, by in cycles.items() if len(set(by.values())) != 1 or len(by) != len(versions)]
    out = ROOT / "data" / "cycle_counts.csv"
    with out.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["test", "mode"] + versions)
        for (test, mode), by in sorted(cycles.items()):
            writer.writerow([test, mode] + [by.get(v, "") for v in versions])
    print(f"cycle counts: {len(cycles)} passing runs x {len(versions)} versions -> "
          f"{'identical in every version' if not differing else f'{len(differing)} differ'}")


if __name__ == "__main__":
    main()

