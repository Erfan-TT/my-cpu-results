#!/usr/bin/env python3
"""Generate descriptive timing, area, and power comparison figures."""

from __future__ import annotations

import csv
import statistics as stats
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
OUT = ROOT / "analysis" / "figures"
VERSIONS = [f"V{i}" for i in range(8)]
TIGHT = [round(1.0 + 0.05 * i, 2) for i in range(13)]
COLORS = ["#4e79a7", "#f28e2b", "#e15759", "#76b7b2", "#59a14f", "#edc948", "#b07aa1", "#ff9da7"]
VERSION_COLOR = dict(zip(VERSIONS, COLORS))


def read(name: str) -> list[dict[str, str]]:
    with (DATA / name).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def save(fig: plt.Figure, stem: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT / f"{stem}.svg", bbox_inches="tight", pad_inches=0.12)
    plt.close(fig)


def pareto(rows: list[dict[str, str]], x_key: str, y_key: str) -> list[dict[str, str]]:
    """Return observed points not dominated when both axes are minimized."""
    ordered = sorted(rows, key=lambda row: (float(row[x_key]), float(row[y_key])))
    result: list[dict[str, str]] = []
    best_y = float("inf")
    for row in ordered:
        y = float(row[y_key])
        if y < best_y:
            result.append(row)
            best_y = y
    return result


def draw_frontier(ax: plt.Axes, rows: list[dict[str, str]], x_key: str, y_key: str,
                  label: str = "observed Pareto frontier") -> None:
    front = pareto(rows, x_key, y_key)
    ax.plot(
        [float(row[x_key]) for row in front],
        [float(row[y_key]) for row in front],
        color="#111111", linewidth=1.8, label=label, zorder=3,
    )
    for row in front:
        ax.scatter(
            float(row[x_key]), float(row[y_key]), s=34,
            color=VERSION_COLOR[row["version"]], edgecolors="#111111",
            linewidths=0.75, zorder=4,
        )


def style() -> None:
    plt.rcParams.update({
        "font.size": 9,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "axes.grid": True,
        "grid.alpha": 0.25,
        "figure.facecolor": "white",
        "axes.facecolor": "white",
    })


def main() -> None:
    style()
    runs = read("synthesis_runs.csv")
    new = [row for row in runs if row["script"] == "new"]
    by = {(row["version"], round(float(row["constraint_ns"]), 2)): row for row in new}

    fig, ax = plt.subplots(figsize=(10.5, 5.4))
    for version, color in zip(VERSIONS, COLORS):
        values = [float(by[(version, target)]["achieved_ns"]) for target in TIGHT]
        ax.plot(TIGHT, values, marker="o", markersize=3.5, linewidth=1.7, color=color, label=version)
    ax.plot([min(TIGHT), max(TIGHT)], [min(TIGHT), max(TIGHT)], "--", color="#777777", linewidth=1, label="meets target")
    ax.set(xlabel="requested clock constraint (ns)", ylabel="achieved period (ns)")
    ax.legend(ncol=5, frameon=False, loc="upper left")
    fig.suptitle("Achieved period at every identical synthesis constraint", y=0.98, fontsize=14)
    fig.text(0.5, 0.935, "Crossing lines are the result: no version has one constraint-independent rank.",
             color="#555555", ha="center")
    fig.tight_layout(rect=[0, 0, 1, 0.90])
    save(fig, "01_achieved_period_by_constraint")

    rank_rows = read("rank_by_constraint.csv")
    matrix = [[int(row[version]) for row in rank_rows] for version in VERSIONS]
    fig, ax = plt.subplots(figsize=(11.5, 4.5))
    image = ax.imshow(matrix, aspect="auto", cmap="YlGn_r", vmin=1, vmax=8)
    for y, version in enumerate(VERSIONS):
        for x, row in enumerate(rank_rows):
            rank = int(row[version])
            ax.text(x, y, str(rank), ha="center", va="center", fontsize=8,
                    color="white" if rank <= 2 else "#111111")
    ax.set_xticks(range(len(rank_rows)), [f"{float(row['constraint_ns']):.2f}" for row in rank_rows], rotation=45)
    ax.set_yticks(range(len(VERSIONS)), VERSIONS)
    ax.set_xlabel("requested clock constraint (ns)")
    ax.set_title("Speed rank changes with the synthesis constraint")
    ax.grid(False)
    bar = fig.colorbar(image, ax=ax, pad=0.02)
    bar.set_label("rank (1 = fastest achieved period)")
    save(fig, "02_rank_by_constraint")

    fig, ax = plt.subplots(figsize=(10.2, 5.8))
    for version, color in zip(VERSIONS, COLORS):
        version_rows = [row for row in new if row["version"] == version]
        ax.scatter(
            [float(row["achieved_ns"]) for row in version_rows],
            [float(row["area_um2"]) for row in version_rows],
            s=28, color=color, label=version, alpha=0.78,
            edgecolors="white", linewidths=0.45,
        )
    draw_frontier(ax, new, "achieved_ns", "area_um2")
    ax.set(
        title="Area–latency design space: all revisions and all constraints",
        xlabel="achieved period (ns)",
        ylabel="cell area (µm²)",
    )
    ax.legend(ncol=3, frameon=False)
    save(fig, "03_area_latency_pareto_all_versions")

    fig, ax = plt.subplots(figsize=(9.5, 5.1))
    for index, (version, color) in enumerate(zip(VERSIONS, COLORS)):
        diffs = [
            float(next(row for row in runs if row["version"] == version and row["script"] == "new" and round(float(row["constraint_ns"]), 2) == target)["achieved_ns"])
            - float(next(row for row in runs if row["version"] == version and row["script"] == "old" and round(float(row["constraint_ns"]), 2) == target)["achieved_ns"])
            for target in TIGHT
        ]
        ax.scatter([value * 1000 for value in diffs], [index] * len(diffs), color=color, s=24, alpha=0.55)
        median = stats.median(diffs) * 1000
        ax.plot([median, median], [index - 0.27, index + 0.27], color="#111111", linewidth=2.4)
    ax.axvline(0, color="#555555", linewidth=1)
    ax.set_yticks(range(len(VERSIONS)), VERSIONS)
    ax.set(title="Tuned script minus plain script, shown without pooling",
           xlabel="achieved-period difference (ps)")
    save(fig, "04_script_comparison")

    fig, axes = plt.subplots(1, 2, figsize=(12.2, 5.0), sharex=True)
    power_metrics = (
        ("total_mW_08_multiplier", "multiplier workload"),
        ("total_mW_20_power_bench", "mixed workload"),
    )
    for ax, (metric, title) in zip(axes, power_metrics):
        for version, color in zip(VERSIONS, COLORS):
            version_rows = sorted(
                (row for row in new if row["version"] == version),
                key=lambda row: float(row["sim_period_ns"]),
            )
            ax.plot(
                [float(row["sim_period_ns"]) for row in version_rows],
                [float(row[metric]) for row in version_rows],
                color=color, linewidth=0.9, alpha=0.45,
            )
            ax.scatter(
                [float(row["sim_period_ns"]) for row in version_rows],
                [float(row[metric]) for row in version_rows],
                color=color, s=22, alpha=0.72, label=version,
                edgecolors="white", linewidths=0.35,
            )
        draw_frontier(ax, new, "sim_period_ns", metric)
        ax.set_title(title)
        ax.set_xlabel("SAIF simulation period (ns)")
        ax.set_ylabel("total power (mW)")
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, ncol=5, frameon=False, loc="upper center", bbox_to_anchor=(0.5, 1.01))
    fig.suptitle("Power–latency design space: all revisions and all constraints", y=1.07, fontsize=14)
    fig.tight_layout()
    save(fig, "05_power_latency_pareto_all_versions")

    fixed = [by[(version, 2.0)] for version in VERSIONS]
    fig, axes = plt.subplots(1, 2, figsize=(11.8, 4.8), sharey=True)
    for ax, (metric, title) in zip(axes, power_metrics):
        values = [float(row[metric]) for row in fixed]
        bars = ax.bar(VERSIONS, values, color=COLORS, edgecolor="white", linewidth=0.6)
        ax.bar_label(bars, labels=[f"{value:.3f}" for value in values], padding=3, fontsize=8)
        ax.set_title(title)
        ax.set_xlabel("RTL version")
        ax.set_ylabel("total power (mW)")
        ax.set_ylim(0, 5.25)
    fig.suptitle("Equal-frequency power comparison at 500 MHz", y=1.01, fontsize=14)
    fig.tight_layout()
    save(fig, "06_power_at_500mhz")

    print(f"wrote figures to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
