#!/usr/bin/env python3
"""Aggregate and compare multiple experiment runs."""

from __future__ import annotations

import argparse
import json
from itertools import product
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import mannwhitneyu


DEFAULT_KPIS = [
    "mqtt_success_rate",
    "mqtt_latency_median_ms",
    "mqtt_latency_p95_ms",
    "syn_rate_mean",
    "syn_rate_peak",
]


def cliffs_delta(a: pd.Series, b: pd.Series) -> float:
    x = pd.to_numeric(a, errors="coerce").dropna().to_numpy()
    y = pd.to_numeric(b, errors="coerce").dropna().to_numpy()
    if len(x) == 0 or len(y) == 0:
        return np.nan
    greater = 0
    lower = 0
    for xv, yv in product(x, y):
        if xv > yv:
            greater += 1
        elif xv < yv:
            lower += 1
    return (greater - lower) / (len(x) * len(y))


def load_metrics(root: Path) -> pd.DataFrame:
    rows = []
    for metrics_path in sorted(root.glob("*/metrics.json")):
        rows.append(json.loads(metrics_path.read_text(encoding="utf-8")))
    if not rows:
        raise SystemExit(f"no metrics.json files found under {root}")
    return pd.DataFrame(rows)


def compare(df: pd.DataFrame, scenario_a: str, scenario_b: str, kpis: list[str]) -> pd.DataFrame:
    rows = []
    a = df[df["scenario"] == scenario_a]
    b = df[df["scenario"] == scenario_b]
    for kpi in kpis:
        if kpi not in df.columns:
            continue
        av = pd.to_numeric(a[kpi], errors="coerce").dropna()
        bv = pd.to_numeric(b[kpi], errors="coerce").dropna()
        if len(av) == 0 or len(bv) == 0:
            p_value = np.nan
        else:
            p_value = float(mannwhitneyu(av, bv, alternative="two-sided").pvalue)
        rows.append(
            {
                "comparison": f"{scenario_a} vs {scenario_b}",
                "kpi": kpi,
                f"{scenario_a}_median": float(av.median()) if len(av) else np.nan,
                f"{scenario_b}_median": float(bv.median()) if len(bv) else np.nan,
                "mann_whitney_p": p_value,
                "cliffs_delta": cliffs_delta(av, bv),
                f"{scenario_a}_n": int(len(av)),
                f"{scenario_b}_n": int(len(bv)),
            }
        )
    return pd.DataFrame(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Aggregate MQTT DoS experiment metrics.")
    parser.add_argument("--experiments-dir", default="experiments")
    parser.add_argument("--output-dir", default="metrics")
    parser.add_argument("--kpi", action="append", dest="kpis", help="KPI column to compare.")
    args = parser.parse_args()

    experiments_dir = Path(args.experiments_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    df = load_metrics(experiments_dir)
    df.to_csv(output_dir / "summary.csv", index=False)

    kpis = args.kpis or DEFAULT_KPIS
    comparisons = []
    scenario_pairs = [
        ("normal", "syn_flood"),
        ("syn_flood", "syn_flood_rate_limit"),
    ]
    for a, b in scenario_pairs:
        if a in set(df["scenario"]) and b in set(df["scenario"]):
            comparisons.append(compare(df, a, b, kpis))

    if comparisons:
        comparison_df = pd.concat(comparisons, ignore_index=True)
    else:
        comparison_df = pd.DataFrame()
    comparison_df.to_csv(output_dir / "comparisons.csv", index=False)

    report = [
        "# MQTT DoS Rate Limiting Analysis",
        "",
        "## Runs",
        "",
        df.to_markdown(index=False),
        "",
        "## Comparisons",
        "",
        comparison_df.to_markdown(index=False) if not comparison_df.empty else "No complete scenario pairs found.",
        "",
    ]
    (output_dir / "analysis_report.txt").write_text("\n".join(report), encoding="utf-8")
    print(f"[OK] summary saved under: {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
