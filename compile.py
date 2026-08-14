#!/usr/bin/env python3
"""
compile.py
Hitung metrik-metrik terkait serangan DoS pada broker MQTT
berdasarkan CSV hasil ekstraksi tshark (raw_flow).
"""

import argparse
import re
import numpy as np
import pandas as pd

WINDOW_SEC = 1
SMALL_PKT = 128
BURST_WIN = 10


def parse_ports(s):
    """Parse '1883,1884' -> {1883, 1884}."""
    ports = set()
    for tok in re.split(r"[,\s]+", s.strip()):
        if not tok:
            continue
        try:
            p = int(tok)
        except ValueError:
            continue
        if 0 < p < 65536:
            ports.add(p)
    return ports


def shannon_entropy(s):
    if s.empty:
        return 0.0
    c = s.value_counts()
    p = c / c.sum()
    return float(-(p * np.log2(p)).sum())


def top_fraction(s):
    if s.empty:
        return 0.0
    c = s.value_counts()
    return float(c.iloc[0] / c.sum())


def half_open(group):
    """
    Estimasi jumlah koneksi half-open:
    SYN (tanpa ACK) yang tidak pernah diikuti oleh ACK di tcp.stream yang sama.
    """
    if group.empty:
        return 0
    syn_streams = set(group.loc[
        (group["tcp.flags.syn"] == 1) & (group["tcp.flags.ack"] == 0),
        "tcp.stream"
    ].dropna())
    ack_streams = set(group.loc[
        (group["tcp.flags.ack"] == 1) & (group["tcp.flags.syn"] == 0),
        "tcp.stream"
    ].dropna())
    return len(syn_streams - ack_streams)


def compute_metrics(df, target_ports):
    # pastikan numeric
    num_cols = [
        "frame.time_epoch", "frame.len", "ip.proto",
        "tcp.srcport", "tcp.dstport",
        "tcp.flags.syn", "tcp.flags.ack", "tcp.flags.reset", "tcp.flags.fin",
        "tcp.stream",
    ]
    for c in num_cols:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")

    # jadikan timestamp sebagai index
    df["timestamp"] = pd.to_datetime(df["frame.time_epoch"], unit="s", errors="coerce")
    df = df.dropna(subset=["timestamp"]).set_index("timestamp").sort_index()

    is_tcp = df["ip.proto"] == 6
    tcp_to_target = is_tcp & df["tcp.dstport"].isin(target_ports)
    tcp_any = is_tcp & (
        df["tcp.srcport"].isin(target_ports) | df["tcp.dstport"].isin(target_ports)
    )

    tcp_df = df[tcp_to_target]
    tcp_df_any = df[tcp_any]
    all_df = tcp_df  # di sini hanya TCP yang menuju port broker

    freq = f"{WINDOW_SEC}s"

    # A. Volume trafik ke broker
    tcp_pkt_rate = tcp_df.resample(freq).size() / WINDOW_SEC
    tcp_byte_rate = tcp_df["frame.len"].resample(freq).sum() / WINDOW_SEC

    # B. Indikator TCP flood (SYN, RST, half-open, rasio SYN/ACK)
    syn_df = df[
        (df["ip.proto"] == 6) &
        (df["tcp.flags.syn"] == 1) &
        (df["tcp.flags.ack"] == 0) &
        (df["tcp.dstport"].isin(target_ports))
    ]
    syn_rate = syn_df.resample(freq).size() / WINDOW_SEC

    rst_df = df[
        (df["ip.proto"] == 6) &
        (df["tcp.flags.reset"] == 1) &
        (df["tcp.srcport"].isin(target_ports) | df["tcp.dstport"].isin(target_ports))
    ]
    rst_rate = rst_df.resample(freq).size() / WINDOW_SEC

    half_open_conn = tcp_df_any.resample(freq).apply(half_open)

    syn_ack_df = df[
        (df["ip.proto"] == 6) &
        (df["tcp.flags.syn"] == 1) &
        (df["tcp.flags.ack"] == 1) &
        (df["tcp.srcport"].isin(target_ports))
    ]
    syn_count = syn_df.resample(freq).size()
    syn_ack_count = syn_ack_df.resample(freq).size()
    syn_ack_ratio = syn_count / syn_ack_count.replace(0, np.nan)

    # C. Sumber IP (indikasi distribusi penyerang/klien)
    unique_src_ip = tcp_df["ip.src"].resample(freq).nunique()
    src_ip_entropy = tcp_df["ip.src"].resample(freq).apply(shannon_entropy)
    top_src_ip_frac = tcp_df["ip.src"].resample(freq).apply(top_fraction)

    # D. Pola waktu & ukuran paket
    avg_pkt_size = all_df["frame.len"].resample(freq).mean()

    def small_ratio(series):
        if series.empty:
            return 0.0
        small = (series <= SMALL_PKT).sum()
        return small / len(series)

    small_pkt_ratio = all_df["frame.len"].resample(freq).apply(small_ratio)

    def mean_iat(series):
        # IAT (inter-arrival time) dalam detik
        if len(series.index) < 2:
            return np.nan
        t = series.index.view("int64") / 1e9
        d = np.diff(t)
        return float(np.mean(d))

    mean_iat_series = all_df["frame.len"].resample(freq).apply(mean_iat)

    pkt_per_sec = all_df.resample(freq).size().astype(float)
    roll_max = pkt_per_sec.rolling(BURST_WIN, min_periods=1).max()
    roll_mean = pkt_per_sec.rolling(BURST_WIN, min_periods=1).mean()
    burstiness = roll_max / roll_mean.replace(0, np.nan)

    return pd.DataFrame({
        "tcp_pkt_rate_target": tcp_pkt_rate,
        "tcp_byte_rate_target": tcp_byte_rate,
        "syn_rate_target": syn_rate,
        "rst_rate_target": rst_rate,
        "half_open_conn_target": half_open_conn,
        "syn_ack_ratio_target": syn_ack_ratio,
        "unique_src_ip_tcp_target": unique_src_ip,
        "src_ip_entropy_tcp_target": src_ip_entropy,
        "top_src_ip_fraction_tcp_target": top_src_ip_frac,
        "avg_pkt_size_target": avg_pkt_size,
        "small_pkt_ratio_target": small_pkt_ratio,
        "mean_iat_target": mean_iat_series,
        "burstiness_target": burstiness,
    })


def main():
    p = argparse.ArgumentParser(
        description="Hitung metrik DoS pada broker MQTT dari CSV tshark (raw_flow)."
    )
    p.add_argument("input_csv", help="CSV input (raw_flow dari tshark).")
    p.add_argument(
        "-o", "--output_csv",
        default="mqtt_dos_metrics.csv",
        help="CSV output metrik untuk broker MQTT."
    )
    p.add_argument(
        "--ports",
        default="1883",
        help="Daftar port broker MQTT, mis: '1883' atau '1883,8883'"
    )
    args = p.parse_args()

    ports = parse_ports(args.ports)
    if not ports:
        raise SystemExit(f"Tidak ada port valid di --ports: {args.ports}")

    df = pd.read_csv(args.input_csv)
    metrics = compute_metrics(df, ports)
    metrics.to_csv(args.output_csv, index_label="window_start")

    print(f"Selesai. Metrik disimpan ke: {args.output_csv}")
    print(f"Port broker MQTT yang dianalisis: {sorted(ports)}")


if __name__ == "__main__":
    main()
