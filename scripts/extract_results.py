#!/usr/bin/env python3
"""Build one validated table from the archived synthesis evidence.

The script reads the reports shipped in evidence/synthesis.  It does not depend
on the original private directory layout and does not trust the derived CSVs
for timing or area: those values are parsed again from the DC reports.
"""

from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "evidence"
DATA = ROOT / "data"
VERSIONS = [f"V{i}" for i in range(8)]
ARMS = ("new", "old")


def group_slacks(path: Path) -> dict[str, float]:
    out: dict[str, float] = {}
    current = None
    for line in path.read_text(errors="ignore").splitlines():
        match = re.search(r"Path Group:\s*(\S+)", line)
        if match:
            current = match.group(1)
        match = re.search(r"^\s*slack \(\S+\)\s+(-?[\d.]+)", line)
        if match and current:
            value = float(match.group(1))
            out[current] = min(value, out.get(current, value))
    return out


def first_path(path: Path) -> tuple[str, str]:
    startpoint = endpoint = ""
    for line in path.read_text(errors="ignore").splitlines():
        if not startpoint and "Startpoint:" in line:
            startpoint = line.split("Startpoint:", 1)[1].strip()
        if not endpoint and "Endpoint:" in line:
            endpoint = line.split("Endpoint:", 1)[1].strip()
        if startpoint and endpoint:
            break
    return startpoint, endpoint


def area_from_qor(path: Path) -> float:
    text = path.read_text(errors="ignore")
    match = re.search(r"Design Area:\s*([\d.]+)", text)
    if not match:
        raise ValueError(f"Design Area not found in {path}")
    return float(match.group(1))


def metadata(path: Path) -> dict[str, str]:
    text = path.read_text(errors="ignore")
    fields = {}
    patterns = {
        "dc_version": r"^Version:\s*(.+)$",
        "operating_condition": r"Operating Conditions:\s*(\S+)",
        "library": r"Library:\s*(\S+)",
        "wire_load_mode": r"Wire Load Model Mode:\s*(\S+)",
    }
    for key, pattern in patterns.items():
        match = re.search(pattern, text, re.MULTILINE)
        fields[key] = match.group(1).strip() if match else ""
    return fields


def report_for(folder: Path, stem: str, exclude: str = "") -> Path:
    pattern = re.compile(rf"^{re.escape(stem)}(?:_old_syn)?\.rpt$")
    matches = [
        p for p in folder.glob("*.rpt")
        if pattern.match(p.name) and (not exclude or exclude not in p.name)
    ]
    if len(matches) != 1:
        raise FileNotFoundError(f"expected one report for {stem} in {folder}, found {matches}")
    return matches[0]


def load_power(version: str) -> dict[str, dict[str, str]]:
    path = EVIDENCE / "power" / version / "final_results.csv"
    if not path.exists():
        return {}
    with path.open(newline="", encoding="utf-8") as handle:
        return {row["tag"]: row for row in csv.DictReader(handle)}


def extract() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    issues: list[str] = []
    for version in VERSIONS:
        power = load_power(version)
        for arm in ARMS:
            folder = EVIDENCE / "synthesis" / version / arm
            with (folder / "results.csv").open(newline="", encoding="utf-8") as handle:
                source_rows = list(csv.DictReader(handle))
            for source in source_rows:
                tag = source["tag"]
                target = float(source["period_ns"])
                timing = report_for(folder, f"timing_{tag}", exclude="timing_reg2reg")
                timing_r2r = report_for(folder, f"timing_reg2reg_{tag}")
                qor = report_for(folder, f"qor_{tag}")

                slacks = group_slacks(timing)
                r2r_slacks = group_slacks(timing_r2r)
                if "REG2REG" not in r2r_slacks:
                    raise ValueError(f"REG2REG slack missing from {timing_r2r}")
                slacks["REG2REG"] = min(slacks.get("REG2REG", float("inf")), r2r_slacks["REG2REG"])
                binding_group = min(slacks, key=slacks.get)
                worst_slack = slacks[binding_group]
                achieved = target - worst_slack
                area = area_from_qor(qor)
                reported_achieved = float(source["achieved_ns"])
                reported_area = float(source["area_um2"])
                if abs(reported_achieved - achieved) > 0.0011:
                    issues.append(
                        f"{version}/{arm}/{tag}: results achieved={reported_achieved:.4f}, "
                        f"report achieved={achieved:.4f}"
                    )
                if abs(reported_area - area) / reported_area > 0.001:
                    issues.append(
                        f"{version}/{arm}/{tag}: results area={reported_area:.2f}, report area={area:.2f}"
                    )

                startpoint, endpoint = first_path(timing_r2r)
                row: dict[str, object] = {
                    "version": version,
                    "script": arm,
                    "tag": tag,
                    "constraint_ns": target,
                    "achieved_ns": round(achieved, 4),
                    "worst_slack_ns": worst_slack,
                    "binding_group": binding_group,
                    "met": int(worst_slack >= 0),
                    "area_um2": area,
                    "reg2reg_slack_ns": slacks.get("REG2REG", ""),
                    "clk_slack_ns": slacks.get("CLK", ""),
                    "input_slack_ns": slacks.get("INPUTS", ""),
                    "output_slack_ns": slacks.get("OUTPUTS", ""),
                    "reg2reg_startpoint": startpoint,
                    "reg2reg_endpoint": endpoint,
                    "source_timing_report": timing.relative_to(ROOT).as_posix(),
                    "source_qor_report": qor.relative_to(ROOT).as_posix(),
                }
                row.update(metadata(timing))

                if arm == "new" and tag in power:
                    p = power[tag]
                    sim_period = float(p["sim_period_ns"])
                    row["sim_period_ns"] = sim_period
                    for workload in ("08_multiplier", "20_power_bench"):
                        total_key = f"total_mW_{workload}"
                        coverage_key = f"saif_cov_{workload}"
                        if p.get(total_key):
                            total = float(p[total_key])
                            row[total_key] = total
                            row[coverage_key] = float(p[coverage_key])
                            # Power was evaluated at sim_period_ns, so this is the
                            # matching period for converting mW to pJ/cycle.
                            row[f"energy_pJ_{workload}"] = total * sim_period
                rows.append(row)

    if issues:
        raise ValueError("report validation failed:\n" + "\n".join(issues))
    return rows


def write_csv(rows: list[dict[str, object]]) -> Path:
    DATA.mkdir(exist_ok=True)
    path = DATA / "synthesis_runs.csv"
    keys: list[str] = []
    for row in rows:
        for key in row:
            if key not in keys:
                keys.append(key)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=keys)
        writer.writeheader()
        writer.writerows(sorted(rows, key=lambda r: (r["version"], r["script"], r["constraint_ns"])))
    return path


def write_manifest() -> Path:
    path = DATA / "evidence_manifest.csv"
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["path", "bytes", "sha256"])
        for item in sorted(p for p in EVIDENCE.rglob("*") if p.is_file()):
            digest = hashlib.sha256(item.read_bytes()).hexdigest()
            writer.writerow([item.relative_to(ROOT).as_posix(), item.stat().st_size, digest])
    return path


def main() -> None:
    rows = extract()
    table = write_csv(rows)
    manifest = write_manifest()
    print(f"validated and wrote {len(rows)} synthesis runs -> {table.relative_to(ROOT)}")
    print(f"hashed evidence -> {manifest.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
