#!/usr/bin/env python3
"""Check the archived V7 final-memory evidence against the declared status."""

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


if __name__ == "__main__":
    main()

