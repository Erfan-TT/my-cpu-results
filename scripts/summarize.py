#!/usr/bin/env python3
"""Create descriptive comparisons without inferential statistics."""

from __future__ import annotations

import csv
import statistics as stats
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
VERSIONS = [f"V{i}" for i in range(8)]
TIGHT = [round(1.0 + 0.05 * i, 2) for i in range(13)]
STEPS = list(zip(VERSIONS[:-1], VERSIONS[1:]))


def number(value: str) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def load() -> list[dict[str, str]]:
    with (DATA / "synthesis_runs.csv").open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def index(rows: list[dict[str, str]]) -> dict[tuple[str, str, float], dict[str, str]]:
    return {
        (row["version"], row["script"], round(float(row["constraint_ns"]), 2)): row
        for row in rows
    }


def write(name: str, header: list[str], rows: list[list[object]]) -> None:
    with (DATA / name).open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(rows)


def pareto_members(rows: list[dict[str, str]], x_key: str, y_key: str) -> set[tuple[str, str, str]]:
    """Return identifiers for observed points not dominated on two minimized axes."""
    ordered = sorted(rows, key=lambda row: (float(row[x_key]), float(row[y_key])))
    members: set[tuple[str, str, str]] = set()
    best_y = float("inf")
    for row in ordered:
        y = float(row[y_key])
        if y < best_y:
            members.add((row["version"], row["script"], row["tag"]))
            best_y = y
    return members


def main() -> None:
    rows = load()
    by = index(rows)

    ranks: dict[tuple[float, str], int] = {}
    rank_rows: list[list[object]] = []
    leader_rows: list[list[object]] = []
    for target in TIGHT:
        ordered = sorted(
            ((float(by[(version, "new", target)]["achieved_ns"]), version) for version in VERSIONS),
            key=lambda item: (item[0], item[1]),
        )
        for rank, (_, version) in enumerate(ordered, start=1):
            ranks[(target, version)] = rank
        rank_rows.append([target] + [ranks[(target, version)] for version in VERSIONS])
        leader_rows.append([target, ordered[0][1], ordered[0][0], ordered[-1][1], ordered[-1][0]])

    write("rank_by_constraint.csv", ["constraint_ns"] + VERSIONS, rank_rows)
    write(
        "constraint_leaders.csv",
        ["constraint_ns", "fastest_version", "fastest_achieved_ns", "slowest_version", "slowest_achieved_ns"],
        leader_rows,
    )

    summary_rows: list[list[object]] = []
    for version in VERSIONS:
        tight_rows = [by[(version, "new", target)] for target in TIGHT]
        achieved = [float(row["achieved_ns"]) for row in tight_rows]
        area = [float(row["area_um2"]) for row in tight_rows]
        version_ranks = [ranks[(target, version)] for target in TIGHT]
        all_rows = sorted(
            (row for row in rows if row["version"] == version and row["script"] == "new"),
            key=lambda row: float(row["constraint_ns"]),
        )
        closure = next((row for row in all_rows if row["met"] == "1"), None)
        v0 = [float(by[("V0", "new", target)]["achieved_ns"]) for target in TIGHT]
        faster_v0 = sum(a < b for a, b in zip(achieved, v0)) if version != "V0" else ""
        slower_v0 = sum(a > b for a, b in zip(achieved, v0)) if version != "V0" else ""
        energy_mul = [number(row.get("energy_pJ_08_multiplier", "")) for row in tight_rows]
        energy_bench = [number(row.get("energy_pJ_20_power_bench", "")) for row in tight_rows]
        power_mul = [number(row.get("total_mW_08_multiplier", "")) for row in tight_rows]
        power_bench = [number(row.get("total_mW_20_power_bench", "")) for row in tight_rows]
        energy_mul = [x for x in energy_mul if x is not None]
        energy_bench = [x for x in energy_bench if x is not None]
        power_mul = [x for x in power_mul if x is not None]
        power_bench = [x for x in power_bench if x is not None]
        fixed_500 = by[(version, "new", 2.0)]
        summary_rows.append([
            version,
            closure["constraint_ns"] if closure else "",
            closure["achieved_ns"] if closure else "",
            round(stats.median(achieved), 4),
            round(min(achieved), 4),
            round(max(achieved), 4),
            round(stats.median(area), 2),
            version_ranks.count(1),
            min(version_ranks),
            max(version_ranks),
            faster_v0,
            slower_v0,
            fixed_500["total_mW_08_multiplier"],
            fixed_500["total_mW_20_power_bench"],
            round(stats.median(power_mul), 4) if power_mul else "",
            round(stats.median(power_bench), 4) if power_bench else "",
            round(stats.median(energy_mul), 4) if energy_mul else "",
            round(stats.median(energy_bench), 4) if energy_bench else "",
        ])
    write(
        "version_summary.csv",
        [
            "version", "first_closing_constraint_ns", "achieved_at_first_closure_ns",
            "median_achieved_tight_ns", "best_achieved_tight_ns", "worst_achieved_tight_ns",
            "median_area_tight_um2", "fastest_count_of_13", "best_rank", "worst_rank",
            "faster_than_V0_count", "slower_than_V0_count",
            "power_500MHz_mW_08_multiplier", "power_500MHz_mW_20_power_bench",
            "median_power_mW_08_multiplier", "median_power_mW_20_power_bench",
            "median_energy_pJ_08_multiplier", "median_energy_pJ_20_power_bench",
        ],
        summary_rows,
    )

    pairwise_rows: list[list[object]] = []
    for left in VERSIONS:
        row: list[object] = [left]
        for right in VERSIONS:
            if left == right:
                row.append("-")
                continue
            wins = sum(
                float(by[(left, "new", target)]["achieved_ns"])
                < float(by[(right, "new", target)]["achieved_ns"])
                for target in TIGHT
            )
            row.append(wins)
        pairwise_rows.append(row)
    write("pairwise_speed_wins.csv", ["row_faster_than_column"] + VERSIONS, pairwise_rows)

    delta_rows: list[list[object]] = []
    metrics = [
        ("achieved_ns", "ns"),
        ("area_um2", "um2"),
        ("total_mW_08_multiplier", "mW"),
        ("total_mW_20_power_bench", "mW"),
        ("energy_pJ_08_multiplier", "pJ"),
        ("energy_pJ_20_power_bench", "pJ"),
    ]
    for before, after in STEPS:
        for metric, unit in metrics:
            deltas = []
            for target in TIGHT:
                left = number(by[(before, "new", target)].get(metric, ""))
                right = number(by[(after, "new", target)].get(metric, ""))
                if left is not None and right is not None:
                    deltas.append(right - left)
            delta_rows.append([
                f"{before}->{after}", metric, unit, len(deltas),
                sum(value < 0 for value in deltas), sum(value > 0 for value in deltas),
                round(min(deltas), 6), round(stats.median(deltas), 6), round(max(deltas), 6),
            ])
    write(
        "same_constraint_deltas.csv",
        ["step", "metric", "unit", "constraints", "improved_count", "regressed_count",
         "min_delta", "median_delta", "max_delta"],
        delta_rows,
    )

    script_rows: list[list[object]] = []
    for version in VERSIONS:
        for metric, unit in (("achieved_ns", "ns"), ("area_um2", "um2")):
            deltas = [
                float(by[(version, "new", target)][metric]) - float(by[(version, "old", target)][metric])
                for target in TIGHT
            ]
            script_rows.append([
                version, metric, unit, len(deltas), sum(d < 0 for d in deltas),
                sum(d > 0 for d in deltas), sum(d == 0 for d in deltas),
                round(min(deltas), 6), round(stats.median(deltas), 6), round(max(deltas), 6),
            ])
    write(
        "script_comparison.csv",
        ["version", "metric", "unit", "constraints", "tuned_better_count", "plain_better_count",
         "ties", "min_tuned_minus_plain", "median_tuned_minus_plain", "max_tuned_minus_plain"],
        script_rows,
    )

    matched_rows: list[list[object]] = []
    for threshold in (1.55, 1.60, 1.70, 1.80, 2.00):
        for version in VERSIONS:
            candidates = [
                row for row in rows
                if row["version"] == version and row["script"] == "new"
                and float(row["achieved_ns"]) <= threshold
            ]
            best = min(candidates, key=lambda row: float(row["area_um2"])) if candidates else None
            matched_rows.append([
                threshold, version,
                best["area_um2"] if best else "",
                best["achieved_ns"] if best else "",
                best["constraint_ns"] if best else "",
            ])
    write(
        "matched_speed_area.csv",
        ["achieved_period_limit_ns", "version", "minimum_observed_area_um2",
         "achieved_period_ns", "source_constraint_ns"],
        matched_rows,
    )

    fixed_rows = [by[(version, "new", 2.0)] for version in VERSIONS]
    write(
        "fixed_frequency_power.csv",
        ["version", "constraint_ns", "achieved_ns", "timing_met", "area_um2",
         "sim_period_ns", "frequency_MHz", "total_mW_08_multiplier",
         "total_mW_20_power_bench", "saif_cov_08_multiplier",
         "saif_cov_20_power_bench"],
        [[
            row["version"], row["constraint_ns"], row["achieved_ns"], row["met"],
            row["area_um2"], row["sim_period_ns"],
            round(1000.0 / float(row["sim_period_ns"]), 3),
            row["total_mW_08_multiplier"], row["total_mW_20_power_bench"],
            row["saif_cov_08_multiplier"], row["saif_cov_20_power_bench"],
        ] for row in fixed_rows],
    )
    write(
        "fixed_frequency_power_deltas.csv",
        ["step", "frequency_MHz", "delta_mW_08_multiplier",
         "delta_mW_20_power_bench"],
        [[
            f"{before}->{after}", 500.0,
            round(float(by[(after, "new", 2.0)]["total_mW_08_multiplier"])
                  - float(by[(before, "new", 2.0)]["total_mW_08_multiplier"]), 6),
            round(float(by[(after, "new", 2.0)]["total_mW_20_power_bench"])
                  - float(by[(before, "new", 2.0)]["total_mW_20_power_bench"]), 6),
        ] for before, after in STEPS],
    )

    pareto_rows: list[list[object]] = []
    tuned = [row for row in rows if row["script"] == "new"]
    scopes = (("all_versions", tuned),)
    pareto_metrics = (
        ("area", "achieved_ns", "area_um2", "ns", "um2"),
        ("power_08_multiplier", "sim_period_ns", "total_mW_08_multiplier", "ns", "mW"),
        ("power_20_mixed", "sim_period_ns", "total_mW_20_power_bench", "ns", "mW"),
    )
    for scope, scope_rows in scopes:
        for metric, x_key, y_key, x_unit, y_unit in pareto_metrics:
            members = pareto_members(scope_rows, x_key, y_key)
            for row in sorted(scope_rows, key=lambda item: (float(item[x_key]), float(item[y_key]))):
                point_id = (row["version"], row["script"], row["tag"])
                pareto_rows.append([
                    scope, metric, row["version"], row["constraint_ns"],
                    row[x_key], x_unit, row[y_key], y_unit,
                    1 if point_id in members else 0,
                ])
    write(
        "pareto_points.csv",
        ["scope", "metric", "version", "constraint_ns", "x_value", "x_unit",
         "y_value", "y_unit", "on_observed_frontier"],
        pareto_rows,
    )

    print("wrote descriptive summaries")


if __name__ == "__main__":
    main()
