#!/usr/bin/env python3
"""Build KPI metrics for one experiment run."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd


REQUIRED_RAW_COLUMNS = {
    "frame.time_epoch",
    "frame.len",
    "ip.src",
    "ip.dst",
    "ip.proto",
    "tcp.srcport",
    "tcp.dstport",
    "tcp.flags.syn",
    "tcp.flags.ack",
}


def load_metadata(path: Path) -> dict[str, str]:
    metadata: dict[str, str] = {}
    if not path.exists():
        return metadata
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        metadata[key] = value
    return metadata


def mqtt_metrics(path: Path) -> dict[str, float | int | str]:
    df = pd.read_csv(path)
    total = int(len(df))
    success = int((df["status"] == "success").sum()) if total else 0
    latency = pd.to_numeric(df.get("latency_ms"), errors="coerce")
    return {
        "mqtt_total_messages": total,
        "mqtt_success_messages": success,
        "mqtt_success_rate": (success / total * 100.0) if total else 0.0,
        "mqtt_latency_mean_ms": float(latency.mean()) if latency.notna().any() else np.nan,
        "mqtt_latency_median_ms": float(latency.median()) if latency.notna().any() else np.nan,
        "mqtt_latency_p95_ms": float(latency.quantile(0.95)) if latency.notna().any() else np.nan,
        "mqtt_failed_messages": total - success,
    }


def traffic_metrics(path: Path, broker_host: str, mqtt_port: int) -> tuple[dict[str, float | int], pd.DataFrame]:
    df = pd.read_csv(path)
    missing = REQUIRED_RAW_COLUMNS - set(df.columns)
    if missing:
        raise SystemExit(f"raw flow missing columns: {sorted(missing)}")

    numeric_cols = [
        "frame.time_epoch",
        "frame.len",
        "ip.proto",
        "tcp.srcport",
        "tcp.dstport",
        "tcp.flags.syn",
        "tcp.flags.ack",
    ]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    df["timestamp"] = pd.to_datetime(df["frame.time_epoch"], unit="s", utc=True, errors="coerce")
    df = df.dropna(subset=["timestamp"]).set_index("timestamp").sort_index()

    to_broker = (
        (df["ip.proto"] == 6)
        & (df["ip.dst"] == broker_host)
        & (df["tcp.dstport"] == mqtt_port)
    )
    syn_to_broker = to_broker & (df["tcp.flags.syn"] == 1) & (df["tcp.flags.ack"] == 0)
    tcp_to_broker = df[to_broker]
    syn_df = df[syn_to_broker]

    per_second = pd.DataFrame(
        {
            "tcp_pkt_rate": tcp_to_broker.resample("1s").size(),
            "tcp_byte_rate": tcp_to_broker["frame.len"].resample("1s").sum(),
            "syn_rate": syn_df.resample("1s").size(),
        }
    ).fillna(0)

    metrics = {
        "tcp_packets_to_broker": int(len(tcp_to_broker)),
        "tcp_bytes_to_broker": int(tcp_to_broker["frame.len"].sum()) if len(tcp_to_broker) else 0,
        "syn_packets_to_broker": int(len(syn_df)),
        "syn_rate_mean": float(per_second["syn_rate"].mean()) if len(per_second) else 0.0,
        "syn_rate_peak": float(per_second["syn_rate"].max()) if len(per_second) else 0.0,
        "tcp_pkt_rate_mean": float(per_second["tcp_pkt_rate"].mean()) if len(per_second) else 0.0,
        "tcp_pkt_rate_peak": float(per_second["tcp_pkt_rate"].max()) if len(per_second) else 0.0,
    }
    return metrics, per_second


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze one MQTT DoS experiment run.")
    parser.add_argument("--run-dir", required=True, help="Experiment directory.")
    parser.add_argument("--broker-host", default=None)
    parser.add_argument("--mqtt-port", type=int, default=None)
    args = parser.parse_args()

    run_dir = Path(args.run_dir)
    metadata = load_metadata(run_dir / "metadata.env")
    broker_host = args.broker_host or metadata.get("BROKER_CAPTURE_HOST") or metadata.get("BROKER_HOST")
    mqtt_port = args.mqtt_port or int(metadata.get("MQTT_PORT", "1883"))
    if not broker_host:
        raise SystemExit("broker host not provided and not found in metadata.env")

    result: dict[str, object] = {
        "run_id": metadata.get("RUN_ID", run_dir.name),
        "scenario": metadata.get("SCENARIO", "unknown"),
        "deployment_mode": metadata.get("DEPLOYMENT_MODE", "unknown"),
        "broker_host": metadata.get("BROKER_HOST", broker_host),
        "broker_capture_host": broker_host,
        "mqtt_port": mqtt_port,
    }

    mqtt_log = run_dir / "mqtt_client.csv"
    raw_flow = run_dir / "raw_flow.csv"

    if mqtt_log.exists():
        result.update(mqtt_metrics(mqtt_log))
    else:
        print(f"[WARN] missing MQTT log: {mqtt_log}")

    if raw_flow.exists():
        traffic, per_second = traffic_metrics(raw_flow, broker_host, mqtt_port)
        result.update(traffic)
        per_second.to_csv(run_dir / "timeseries_metrics.csv", index_label="window_start")
    else:
        print(f"[WARN] missing raw flow: {raw_flow}")

    out_json = run_dir / "metrics.json"
    out_csv = run_dir / "metrics.csv"
    out_json.write_text(json.dumps(result, indent=2, allow_nan=True), encoding="utf-8")
    pd.DataFrame([result]).to_csv(out_csv, index=False)
    print(f"[OK] metrics saved: {out_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
