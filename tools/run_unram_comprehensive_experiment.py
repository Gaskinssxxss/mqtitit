#!/usr/bin/env python3
"""Runner pengujian komprehensif MQTT DoS UNRAM.

Runner ini menjalankan skenario baseline dan SYN flood bertingkat dari attacker
lokal melalui interface VPN. Setiap run menghasilkan folder sendiri berisi data
mentah dan ringkasan:

- metadata.env
- capture.pcapng
- capture_raw_flow.csv
- metrics.csv
- prober.csv
- attack.log
- summary.txt
"""

from __future__ import annotations

import argparse
import csv
import os
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
OUT_ROOT = ROOT / "output" / "unram_experiments_comprehensive"


@dataclass(frozen=True)
class Scenario:
    code: str
    name: str
    rate_pps: int
    mitigated: bool = False


def run(cmd: list[str], *, cwd: Path = ROOT, timeout: int | None = None, check: bool = True, capture: bool = True):
    kwargs = {
        "cwd": str(cwd),
        "text": True,
        "timeout": timeout,
    }
    if capture:
        kwargs["stdout"] = subprocess.PIPE
        kwargs["stderr"] = subprocess.STDOUT
    proc = subprocess.run(cmd, **kwargs)
    if check and proc.returncode != 0:
        out = proc.stdout if capture else ""
        raise RuntimeError(f"Command failed ({proc.returncode}): {' '.join(cmd)}\n{out}")
    return proc


def check_ready(broker_host: str, broker_port: int, server_user: str, iface: str):
    checks = [
        (["ip", "-br", "addr", "show", iface], "VPN/interface tidak aktif"),
        (["nc", "-vz", "-w", "5", broker_host, str(broker_port)], "Port broker MQTT tidak bisa diakses"),
        (
            [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=5",
                f"{server_user}@{broker_host}",
                "systemctl is-active mosquitto",
            ],
            "SSH/server broker tidak siap atau Mosquitto tidak aktif",
        ),
    ]
    for cmd, msg in checks:
        proc = run(cmd, check=False)
        if proc.returncode != 0:
            print(proc.stdout or "", end="")
            raise SystemExit(f"[ERR] {msg}")


def mqtt_publish_once(broker_host: str, broker_port: int, topic: str, message: str, timeout_s: int) -> tuple[int, int]:
    start = time.time()
    proc = subprocess.run(
        [
            "timeout",
            str(timeout_s),
            "mosquitto_pub",
            "-h",
            broker_host,
            "-p",
            str(broker_port),
            "-t",
            topic,
            "-m",
            message,
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    rtt_ms = int((time.time() - start) * 1000)
    return proc.returncode, rtt_ms


def run_prober(out_csv: Path, broker_host: str, broker_port: int, duration: int, interval: float, timeout_s: int, run_id: str):
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    end = time.time() + duration
    seq = 0
    with out_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["timestamp_ms", "seq", "exit_code", "rtt_ms"])
        while time.time() < end:
            seq += 1
            ts_ms = int(time.time() * 1000)
            code, rtt_ms = mqtt_publish_once(
                broker_host,
                broker_port,
                f"unram/mqtt-dos/{run_id}",
                f"{run_id}-{seq}-{ts_ms}",
                timeout_s,
            )
            writer.writerow([ts_ms, seq, code, rtt_ms])
            f.flush()
            time.sleep(interval)


def start_capture(capture_file: Path, iface: str, broker_host: str, broker_port: int, duration: int):
    cmd = [
        "tshark",
        "-i",
        iface,
        "-a",
        f"duration:{duration}",
        "-f",
        f"host {broker_host} and tcp port {broker_port}",
        "-w",
        str(capture_file),
    ]
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=str(ROOT))


def start_attack(log_file: Path, iface: str, broker_host: str, broker_port: int, rate_pps: int, duration: int):
    if rate_pps <= 0:
        return None
    count = max(1, rate_pps * duration)
    interval_us = max(1, int(1_000_000 / rate_pps))
    cmd = [
        "hping3",
        "-I",
        iface,
        "-S",
        "-p",
        str(broker_port),
        "-i",
        f"u{interval_us}",
        "-c",
        str(count),
        "-q",
        broker_host,
    ]
    f = log_file.open("w", encoding="utf-8")
    f.write("COMMAND=" + " ".join(cmd) + "\n")
    f.flush()
    proc = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT, text=True, cwd=str(ROOT))
    proc._log_file_handle = f  # type: ignore[attr-defined]
    return proc


def wait_proc(proc, timeout: int, name: str):
    try:
        out, _ = proc.communicate(timeout=timeout)
        return proc.returncode, out or ""
    except subprocess.TimeoutExpired:
        proc.send_signal(signal.SIGINT)
        try:
            out, _ = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            out, _ = proc.communicate(timeout=5)
        return proc.returncode, out or f"{name} timeout"


def extract_and_compile(run_dir: Path, broker_port: int):
    capture = run_dir / "capture.pcapng"
    raw = run_dir / "capture_raw_flow.csv"
    metrics = run_dir / "metrics.csv"
    extract_log = run_dir / "extract.log"
    compile_log = run_dir / "compile.log"

    with extract_log.open("w", encoding="utf-8") as f:
        proc = subprocess.run(
            [
                "tshark",
                "-r",
                str(capture),
                "-T",
                "fields",
                "-e",
                "frame.time_epoch",
                "-e",
                "frame.len",
                "-e",
                "ip.src",
                "-e",
                "ip.dst",
                "-e",
                "ip.proto",
                "-e",
                "tcp.srcport",
                "-e",
                "tcp.dstport",
                "-e",
                "udp.srcport",
                "-e",
                "udp.dstport",
                "-e",
                "tcp.flags",
                "-e",
                "tcp.flags.syn",
                "-e",
                "tcp.flags.ack",
                "-e",
                "tcp.flags.reset",
                "-e",
                "tcp.flags.fin",
                "-e",
                "tcp.stream",
                "-e",
                "mqtt.msgtype",
                "-e",
                "mqtt.clientid",
                "-e",
                "mqtt.topic",
                "-E",
                "header=y",
                "-E",
                "separator=,",
            ],
            stdout=raw.open("w", encoding="utf-8"),
            stderr=f,
            text=True,
            cwd=str(ROOT),
        )
        if proc.returncode != 0:
            raise RuntimeError(f"extract failed for {run_dir}")

    proc = run(
        [sys.executable, str(ROOT / "compile.py"), str(raw), "-o", str(metrics), "--ports", str(broker_port)],
        check=False,
    )
    compile_log.write_text(proc.stdout or "", encoding="utf-8")
    if proc.returncode != 0:
        raise RuntimeError(f"compile failed for {run_dir}\n{proc.stdout}")


def summarize(run_dir: Path, scenario: Scenario, broker_host: str, broker_port: int):
    prober = pd.read_csv(run_dir / "prober.csv")
    metrics = pd.read_csv(run_dir / "metrics.csv")
    raw_rows = sum(1 for _ in (run_dir / "capture_raw_flow.csv").open(encoding="utf-8")) - 1
    capture_bytes = (run_dir / "capture.pcapng").stat().st_size

    total = len(prober)
    ok = int((prober["exit_code"] == 0).sum()) if total else 0
    fail = total - ok
    success = (ok / total * 100) if total else 0.0
    rtt_avg = float(prober["rtt_ms"].mean()) if total else 0.0
    rtt_p95 = float(prober["rtt_ms"].quantile(0.95)) if total else 0.0
    rtt_max = int(prober["rtt_ms"].max()) if total else 0

    def mean_max(col: str):
        if col not in metrics.columns:
            return 0.0, 0.0
        s = pd.to_numeric(metrics[col], errors="coerce").dropna()
        if s.empty:
            return 0.0, 0.0
        return float(s.mean()), float(s.max())

    fields = {
        "scenario_code": scenario.code,
        "scenario_name": scenario.name,
        "rate_pps": scenario.rate_pps,
        "mitigated": str(scenario.mitigated).lower(),
        "broker_host": broker_host,
        "broker_port": broker_port,
        "prober_messages": total,
        "prober_ok": ok,
        "prober_fail": fail,
        "prober_success_rate": f"{success:.2f}",
        "rtt_avg_ms": f"{rtt_avg:.2f}",
        "rtt_p95_ms": f"{rtt_p95:.2f}",
        "rtt_max_ms": rtt_max,
        "raw_rows": raw_rows,
        "pcap_bytes": capture_bytes,
    }
    for col in [
        "tcp_pkt_rate_target",
        "tcp_byte_rate_target",
        "syn_rate_target",
        "rst_rate_target",
        "half_open_conn_target",
        "syn_ack_ratio_target",
        "unique_src_ip_tcp_target",
        "burstiness_target",
    ]:
        avg, mx = mean_max(col)
        fields[f"{col}_mean"] = f"{avg:.4f}"
        fields[f"{col}_max"] = f"{mx:.4f}"

    lines = [f"{k}={v}" for k, v in fields.items()]
    (run_dir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return fields


def post_health(broker_host: str, broker_port: int, server_user: str) -> bool:
    nc = run(["nc", "-vz", "-w", "5", broker_host, str(broker_port)], check=False)
    ssh = run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=5",
            f"{server_user}@{broker_host}",
            "systemctl is-active mosquitto",
        ],
        check=False,
    )
    return nc.returncode == 0 and ssh.returncode == 0 and "active" in (ssh.stdout or "")


def run_one(args, scenario: Scenario, rep: int):
    run_id = f"{args.batch_id}_{scenario.code}_r{rep}"
    run_dir = OUT_ROOT / args.batch_id / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    metadata = {
        "batch_id": args.batch_id,
        "run_id": run_id,
        "scenario_code": scenario.code,
        "scenario_name": scenario.name,
        "rate_pps": scenario.rate_pps,
        "mitigated": str(scenario.mitigated).lower(),
        "broker_host": args.broker_host,
        "broker_port": args.broker_port,
        "iface": args.iface,
        "duration": args.duration,
        "capture_duration": args.capture_duration,
        "prober_interval": args.prober_interval,
    }
    (run_dir / "metadata.env").write_text("\n".join(f"{k}={v}" for k, v in metadata.items()) + "\n", encoding="utf-8")

    print(f"[RUN] {run_id} ({scenario.name}, rate={scenario.rate_pps} pps)")
    cap = start_capture(run_dir / "capture.pcapng", args.iface, args.broker_host, args.broker_port, args.capture_duration)
    time.sleep(args.capture_warmup)
    attack = start_attack(run_dir / "attack.log", args.iface, args.broker_host, args.broker_port, scenario.rate_pps, args.attack_duration)
    try:
        run_prober(run_dir / "prober.csv", args.broker_host, args.broker_port, args.duration, args.prober_interval, args.publish_timeout, run_id)
    finally:
        if attack is not None:
            wait_proc(attack, max(5, args.attack_duration + 10), "attack")
            log_f = getattr(attack, "_log_file_handle", None)
            if log_f:
                log_f.close()
        wait_proc(cap, max(5, args.capture_duration + 10), "capture")

    extract_and_compile(run_dir, args.broker_port)
    summary = summarize(run_dir, scenario, args.broker_host, args.broker_port)
    ok = post_health(args.broker_host, args.broker_port, args.server_user)
    (run_dir / "post_health.txt").write_text(f"post_health_ok={str(ok).lower()}\n", encoding="utf-8")
    if not ok:
        raise SystemExit(f"[STOP] Health check gagal setelah {run_id}. Pengujian dihentikan.")
    print(
        "[OK] "
        f"success={summary['prober_success_rate']}% "
        f"syn_mean={summary['syn_rate_target_mean']} "
        f"half_open_mean={summary['half_open_conn_target_mean']} "
        f"rtt_avg={summary['rtt_avg_ms']}ms"
    )
    time.sleep(args.cooldown)
    return summary


def write_batch_summary(batch_dir: Path, summaries: list[dict]):
    out = batch_dir / "all_runs_summary.csv"
    keys = list(summaries[0].keys()) if summaries else []
    with out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(summaries)

    df = pd.DataFrame(summaries)
    numeric_cols = [
        "rate_pps",
        "prober_messages",
        "prober_ok",
        "prober_fail",
        "prober_success_rate",
        "rtt_avg_ms",
        "rtt_p95_ms",
        "rtt_max_ms",
        "raw_rows",
        "pcap_bytes",
        "tcp_pkt_rate_target_mean",
        "tcp_pkt_rate_target_max",
        "syn_rate_target_mean",
        "syn_rate_target_max",
        "half_open_conn_target_mean",
        "half_open_conn_target_max",
        "syn_ack_ratio_target_mean",
        "syn_ack_ratio_target_max",
        "burstiness_target_mean",
        "burstiness_target_max",
    ]
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    agg = (
        df.groupby(["scenario_code", "scenario_name", "rate_pps", "mitigated"], dropna=False)[numeric_cols[1:]]
        .agg(["mean", "std", "min", "max"])
        .reset_index()
    )
    agg.to_csv(batch_dir / "scenario_aggregate.csv", index=False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--broker-host", default="172.16.10.44")
    ap.add_argument("--broker-port", type=int, default=1883)
    ap.add_argument("--server-user", default="indra")
    ap.add_argument("--iface", default="unram")
    ap.add_argument("--batch-id", default=time.strftime("%Y%m%d_%H%M%S_unram_comprehensive"))
    ap.add_argument("--duration", type=int, default=30)
    ap.add_argument("--attack-duration", type=int, default=30)
    ap.add_argument("--capture-duration", type=int, default=40)
    ap.add_argument("--capture-warmup", type=int, default=3)
    ap.add_argument("--prober-interval", type=float, default=0.75)
    ap.add_argument("--publish-timeout", type=int, default=3)
    ap.add_argument("--cooldown", type=int, default=8)
    ap.add_argument("--repetitions", type=int, default=3)
    ap.add_argument("--include-high", action="store_true")
    ap.add_argument(
        "--rates",
        default=None,
        help="Daftar rate pps eksplisit, misalnya '0,10,15,25'. Jika diisi, --include-high diabaikan.",
    )
    ap.add_argument("--mitigated", action="store_true", help="Label seluruh skenario sebagai skenario mitigasi.")
    args = ap.parse_args()

    check_ready(args.broker_host, args.broker_port, args.server_user, args.iface)
    if args.rates:
        rates = [int(x.strip()) for x in args.rates.split(",") if x.strip()]
        scenarios = []
        for rate in rates:
            if rate == 0:
                code = "M0_baseline" if args.mitigated else "S0_baseline"
                name = "Baseline dengan rate limiting" if args.mitigated else "Baseline normal"
            else:
                code = f"M_syn_{rate}pps" if args.mitigated else f"S_syn_{rate}pps"
                name = f"SYN flood {rate} pps dengan rate limiting" if args.mitigated else f"SYN flood {rate} pps"
            scenarios.append(Scenario(code, name, rate, args.mitigated))
    else:
        scenarios = [
            Scenario("S0_baseline", "Baseline normal", 0, args.mitigated),
            Scenario("S1_syn_low", "SYN flood rendah", 10, args.mitigated),
            Scenario("S2_syn_medium", "SYN flood sedang", 25, args.mitigated),
        ]
        if args.include_high:
            scenarios.append(Scenario("S3_syn_high", "SYN flood tinggi terkendali", 50, args.mitigated))

    batch_dir = OUT_ROOT / args.batch_id
    batch_dir.mkdir(parents=True, exist_ok=True)
    summaries = []
    for scenario in scenarios:
        for rep in range(1, args.repetitions + 1):
            summaries.append(run_one(args, scenario, rep))
            write_batch_summary(batch_dir, summaries)
    write_batch_summary(batch_dir, summaries)
    print(f"[DONE] batch_dir={batch_dir}")


if __name__ == "__main__":
    main()
