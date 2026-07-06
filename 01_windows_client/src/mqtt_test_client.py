#!/usr/bin/env python3
"""
MQTT test client for the MQTT DoS/rate limiting experiment.

Runs one subscriber and one publisher in the same process. Each published
message carries a sequence number and send timestamp; latency is measured when
the subscriber receives the same message back through the broker.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import queue
import signal
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path

import paho.mqtt.client as mqtt


@dataclass
class Config:
    broker_host: str
    mqtt_port: int
    topic: str
    qos: int
    interval_ms: int
    timeout_sec: float
    duration: float
    scenario: str
    run_id: str
    output: Path
    client_id_prefix: str


def env(name: str, default: str) -> str:
    return os.environ.get(name, default)


def parse_args() -> Config:
    parser = argparse.ArgumentParser(description="Run MQTT publish/subscribe latency test.")
    parser.add_argument("--broker-host", default=env("BROKER_HOST", "127.0.0.1"))
    parser.add_argument("--mqtt-port", type=int, default=int(env("MQTT_PORT", "1883")))
    parser.add_argument("--topic", default=env("MQTT_TOPIC", "unram/iot/suhu"))
    parser.add_argument("--qos", type=int, choices=[0, 1, 2], default=int(env("MQTT_QOS", "1")))
    parser.add_argument("--interval-ms", type=int, default=int(env("MQTT_INTERVAL_MS", "1000")))
    parser.add_argument("--timeout-sec", type=float, default=float(env("MQTT_TIMEOUT_SEC", "5")))
    parser.add_argument("--duration", type=float, default=float(env("EXPERIMENT_DURATION", "60")))
    parser.add_argument("--scenario", default=env("SCENARIO", "normal"))
    parser.add_argument("--run-id", default=env("RUN_ID", time.strftime("%Y%m%d_%H%M%S")))
    parser.add_argument("--client-id-prefix", default=env("MQTT_CLIENT_ID_PREFIX", "unram-test"))
    parser.add_argument("--output", default=env("MQTT_CLIENT_LOG", "mqtt_client.csv"))
    args = parser.parse_args()

    if args.interval_ms <= 0:
        raise SystemExit("--interval-ms must be positive")
    if args.duration <= 0:
        raise SystemExit("--duration must be positive")
    if args.timeout_sec <= 0:
        raise SystemExit("--timeout-sec must be positive")

    return Config(
        broker_host=args.broker_host,
        mqtt_port=args.mqtt_port,
        topic=args.topic,
        qos=args.qos,
        interval_ms=args.interval_ms,
        timeout_sec=args.timeout_sec,
        duration=args.duration,
        scenario=args.scenario,
        run_id=args.run_id,
        output=Path(args.output),
        client_id_prefix=args.client_id_prefix,
    )


def make_client(client_id: str) -> mqtt.Client:
    try:
        return mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id)
    except AttributeError:
        return mqtt.Client(client_id=client_id)


def main() -> int:
    cfg = parse_args()
    cfg.output.parent.mkdir(parents=True, exist_ok=True)

    received: "queue.Queue[dict]" = queue.Queue()
    stop = False

    def handle_signal(_signum, _frame):
        nonlocal stop
        stop = True

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    run_suffix = uuid.uuid4().hex[:8]
    sub = make_client(f"{cfg.client_id_prefix}-sub-{run_suffix}")
    pub = make_client(f"{cfg.client_id_prefix}-pub-{run_suffix}")

    def on_message(_client, _userdata, msg):
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return
        received.put(payload)

    sub.on_message = on_message

    sub.connect(cfg.broker_host, cfg.mqtt_port, keepalive=30)
    sub.subscribe(cfg.topic, qos=cfg.qos)
    sub.loop_start()

    pub.connect(cfg.broker_host, cfg.mqtt_port, keepalive=30)
    pub.loop_start()

    fieldnames = [
        "run_id",
        "scenario",
        "seq",
        "topic",
        "payload_value",
        "send_epoch_ns",
        "recv_epoch_ns",
        "latency_ms",
        "status",
        "error",
    ]

    sent_by_seq: dict[int, int] = {}
    deadline = time.monotonic() + cfg.duration
    next_send = time.monotonic()
    seq = 0

    with cfg.output.open("w", newline="", encoding="utf-8") as fp:
        writer = csv.DictWriter(fp, fieldnames=fieldnames)
        writer.writeheader()

        while not stop and time.monotonic() < deadline:
            now = time.monotonic()
            if now < next_send:
                time.sleep(min(0.05, next_send - now))
                continue

            seq += 1
            send_ns = time.time_ns()
            payload_value = 25.0 + (seq % 100) / 10.0
            payload = {
                "run_id": cfg.run_id,
                "scenario": cfg.scenario,
                "seq": seq,
                "sent_epoch_ns": send_ns,
                "sensor": "suhu",
                "value": payload_value,
                "unit": "C",
            }
            sent_by_seq[seq] = send_ns

            try:
                info = pub.publish(cfg.topic, json.dumps(payload), qos=cfg.qos)
                info.wait_for_publish(timeout=cfg.timeout_sec)
                if not info.is_published():
                    raise TimeoutError("publish timeout")
            except Exception as exc:  # noqa: BLE001 - log experiment failure reason
                writer.writerow(
                    {
                        "run_id": cfg.run_id,
                        "scenario": cfg.scenario,
                        "seq": seq,
                        "topic": cfg.topic,
                        "payload_value": payload_value,
                        "send_epoch_ns": send_ns,
                        "recv_epoch_ns": "",
                        "latency_ms": "",
                        "status": "publish_failed",
                        "error": str(exc),
                    }
                )
                fp.flush()
                next_send += cfg.interval_ms / 1000.0
                continue

            recv_payload = None
            recv_deadline = time.monotonic() + cfg.timeout_sec
            while time.monotonic() < recv_deadline:
                try:
                    candidate = received.get(timeout=0.1)
                except queue.Empty:
                    continue
                if candidate.get("run_id") == cfg.run_id and candidate.get("seq") == seq:
                    recv_payload = candidate
                    break

            if recv_payload is None:
                writer.writerow(
                    {
                        "run_id": cfg.run_id,
                        "scenario": cfg.scenario,
                        "seq": seq,
                        "topic": cfg.topic,
                        "payload_value": payload_value,
                        "send_epoch_ns": send_ns,
                        "recv_epoch_ns": "",
                        "latency_ms": "",
                        "status": "receive_timeout",
                        "error": "message not received before timeout",
                    }
                )
            else:
                recv_ns = time.time_ns()
                sent_ns = int(recv_payload.get("sent_epoch_ns", sent_by_seq[seq]))
                writer.writerow(
                    {
                        "run_id": cfg.run_id,
                        "scenario": cfg.scenario,
                        "seq": seq,
                        "topic": cfg.topic,
                        "payload_value": payload_value,
                        "send_epoch_ns": sent_ns,
                        "recv_epoch_ns": recv_ns,
                        "latency_ms": (recv_ns - sent_ns) / 1_000_000,
                        "status": "success",
                        "error": "",
                    }
                )

            fp.flush()
            next_send += cfg.interval_ms / 1000.0

    pub.loop_stop()
    sub.loop_stop()
    pub.disconnect()
    sub.disconnect()
    print(f"[OK] MQTT client log saved: {cfg.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
