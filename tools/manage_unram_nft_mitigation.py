#!/usr/bin/env python3
"""Kelola rule nftables sementara untuk eksperimen mitigasi MQTT UNRAM."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if check and proc.returncode != 0:
        raise SystemExit(f"Command failed ({proc.returncode}): {' '.join(cmd)}\n{proc.stdout}")
    return proc


def ssh(host: str, user: str, command: str, check: bool = True) -> subprocess.CompletedProcess:
    return run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=5",
            f"{user}@{host}",
            command,
        ],
        check=check,
    )


def apply_rule(host: str, user: str, port: int, limit: int, burst: int):
    command = (
        "sudo -n nft delete table inet mqtt_mitigation 2>/dev/null || true; "
        "sudo -n nft add table inet mqtt_mitigation; "
        "sudo -n nft 'add chain inet mqtt_mitigation input { type filter hook input priority 0; policy accept; }'; "
        f"sudo -n nft add rule inet mqtt_mitigation input tcp dport {port} 'tcp flags & (syn|ack) == syn' "
        f"limit rate {limit}/second burst {burst} packets accept; "
        f"sudo -n nft add rule inet mqtt_mitigation input tcp dport {port} 'tcp flags & (syn|ack) == syn' drop; "
        "sudo -n nft list table inet mqtt_mitigation"
    )
    proc = ssh(host, user, command)
    print(proc.stdout)


def remove_rule(host: str, user: str):
    command = (
        "sudo -n nft delete table inet mqtt_mitigation 2>/dev/null || true; "
        "sudo -n nft list table inet mqtt_mitigation 2>/dev/null || echo mitigation_removed"
    )
    proc = ssh(host, user, command)
    print(proc.stdout)


def status(host: str, user: str):
    proc = ssh(host, user, "sudo -n nft list table inet mqtt_mitigation 2>/dev/null || echo mitigation_not_active", check=False)
    print(proc.stdout)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("action", choices=["apply", "remove", "status"])
    ap.add_argument("--host", default="172.16.10.44")
    ap.add_argument("--user", default="indra")
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--limit", type=int, default=20)
    ap.add_argument("--burst", type=int, default=30)
    args = ap.parse_args()

    if args.action == "apply":
        apply_rule(args.host, args.user, args.port, args.limit, args.burst)
    elif args.action == "remove":
        remove_rule(args.host, args.user)
    else:
        status(args.host, args.user)


if __name__ == "__main__":
    main()
