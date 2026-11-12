import argparse
import csv
import json
import os
import platform
import shutil
import statistics
import subprocess
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from threading import Event, Thread

try:
    import psutil
except ImportError:  # A medicao HTTP continua valida sem telemetria.
    psutil = None


VALIDATION_DIR = Path(__file__).resolve().parent
RESULTS_DIR = VALIDATION_DIR / "results"
SCRIPT = VALIDATION_DIR / "k6_single_level.js"


def _metric(summary, name, field, default=0.0):
    metric = summary.get("metrics", {}).get(name, {})
    values = metric.get("values", metric)
    value = values.get(field, default)
    return default if value is None else float(value)


def _wait_until_ready(url, attempts=20, interval=0.25):
    last_error = None
    for _ in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                if 200 <= response.status < 300:
                    return
                last_error = f"status HTTP {response.status}"
        except (OSError, urllib.error.URLError) as exc:
            last_error = str(exc)
        time.sleep(interval)
    raise SystemExit(f"Servidor indisponivel antes do teste: {last_error}")


def _warm_up(url, requests):
    for _ in range(requests):
        _wait_until_ready(url, attempts=1, interval=0)


def _monitor_process_tree(pid, stop, samples):
    if not pid or psutil is None:
        return
    known = {}
    while not stop.is_set():
        try:
            root = psutil.Process(pid)
            processes = [root, *root.children(recursive=True)]
        except (psutil.Error, OSError):
            return
        cpu = 0.0
        rss = 0
        for process in processes:
            try:
                if process.pid not in known:
                    process.cpu_percent(None)
                    known[process.pid] = process
                    continue
                tracked = known[process.pid]
                cpu += tracked.cpu_percent(None)
                rss += tracked.memory_info().rss
            except (psutil.Error, OSError):
                continue
        if known:
            samples.append(
                {
                    "cpu_percent": cpu / max(1, os.cpu_count() or 1),
                    "rss_mb": rss / 1024**2,
                }
            )
        stop.wait(0.1)


def main():
    parser = argparse.ArgumentParser(description="Teste de estresse com k6")
    parser.add_argument("--url", default="http://127.0.0.1:8000/health")
    parser.add_argument("--concurrency", default="100,250,500,1000")
    parser.add_argument("--iterations", type=int, default=5000)
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--warmup-requests", type=int, default=5)
    parser.add_argument("--cooldown-seconds", type=float, default=2.0)
    parser.add_argument("--server-workers", type=int, default=4)
    parser.add_argument("--server-pid", type=int)
    parser.add_argument("--p95-limit-ms", type=float, default=1000)
    parser.add_argument("--error-limit", type=float, default=0.01)
    parser.add_argument("--output-prefix", default="k6_stress_test")
    args = parser.parse_args()

    executable = shutil.which("k6")
    if not executable:
        raise SystemExit("k6 nao foi encontrado no PATH.")
    levels = [int(item) for item in args.concurrency.split(",")]
    if not levels or min(levels) < 1:
        raise SystemExit("Informe concorrencias inteiras positivas.")
    for level in levels:
        if args.iterations < level or args.iterations % level:
            raise SystemExit(
                "O total de requisicoes deve ser divisivel por cada nivel de "
                "concorrencia e nao pode ser menor que ele."
            )

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    _wait_until_ready(args.url)
    raw_rows = []
    for level in levels:
        for repetition in range(1, max(1, args.repetitions) + 1):
            if raw_rows:
                time.sleep(max(0, args.cooldown_seconds))
            _wait_until_ready(args.url)
            _warm_up(args.url, max(0, args.warmup_requests))
            raw_path = RESULTS_DIR / (
                f".{args.output_prefix}_{level}_{repetition}_raw.json"
            )
            env = {
                **os.environ,
                "TARGET_URL": args.url,
                "VIRTUAL_USERS": str(level),
                "ITERATIONS_PER_USER": str(args.iterations // level),
            }
            command = [
                executable,
                "run",
                "--quiet",
                "--summary-export",
                str(raw_path),
                str(SCRIPT),
            ]
            process = subprocess.Popen(
                command,
                cwd=VALIDATION_DIR,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            resource_samples = []
            monitor_stop = Event()
            monitor = Thread(
                target=_monitor_process_tree,
                args=(args.server_pid, monitor_stop, resource_samples),
                daemon=True,
            )
            monitor.start()
            stdout, stderr = process.communicate()
            monitor_stop.set()
            monitor.join(timeout=2)
            if not raw_path.exists():
                raise SystemExit(
                    f"k6 falhou na concorrencia {level}: "
                    f"{stderr.strip() or stdout.strip()}"
                )
            summary = json.loads(raw_path.read_text(encoding="utf-8"))
            requests = int(_metric(summary, "http_reqs", "count"))
            error_rate = _metric(summary, "http_req_failed", "rate", None)
            if error_rate is None:
                error_rate = _metric(summary, "http_req_failed", "value")
            raw_rows.append(
                {
                    "repetition": repetition,
                    "concurrency": level,
                    "requests": requests,
                    "errors": round(requests * error_rate),
                    "transport_errors": int(
                        _metric(summary, "transport_failures", "count")
                    ),
                    "status_errors": int(
                        _metric(summary, "unexpected_statuses", "count")
                    ),
                    "error_rate": round(error_rate, 6),
                    "rps": round(_metric(summary, "http_reqs", "rate"), 2),
                    "latency_mean_ms": round(
                        _metric(summary, "http_req_duration", "avg"), 2
                    ),
                    "latency_p50_ms": round(
                        _metric(summary, "http_req_duration", "med"), 2
                    ),
                    "latency_p95_ms": round(
                        _metric(summary, "http_req_duration", "p(95)"), 2
                    ),
                    "latency_p99_ms": round(
                        _metric(summary, "http_req_duration", "p(99)"), 2
                    ),
                    "server_cpu_peak_percent": (
                        round(
                            max(
                                item["cpu_percent"]
                                for item in resource_samples
                            ),
                            2,
                        )
                        if resource_samples
                        else None
                    ),
                    "server_rss_peak_mb": (
                        round(
                            max(item["rss_mb"] for item in resource_samples),
                            2,
                        )
                        if resource_samples
                        else None
                    ),
                }
            )
            raw_path.unlink(missing_ok=True)

    rows = []
    for level in levels:
        samples = [item for item in raw_rows if item["concurrency"] == level]

        def median(field):
            return round(statistics.median(item[field] for item in samples), 2)

        p95_max = max(item["latency_p95_ms"] for item in samples)
        error_max = max(item["error_rate"] for item in samples)
        row = {
            "concurrency": level,
            "requests": args.iterations,
            "repetitions": len(samples),
            "errors": max(item["errors"] for item in samples),
            "transport_errors": max(
                item["transport_errors"] for item in samples
            ),
            "status_errors": max(item["status_errors"] for item in samples),
            "error_rate": error_max,
            "rps": median("rps"),
            "latency_mean_ms": median("latency_mean_ms"),
            "latency_p50_ms": median("latency_p50_ms"),
            "latency_p95_ms": median("latency_p95_ms"),
            "latency_p99_ms": median("latency_p99_ms"),
            "latency_p95_min_ms": min(
                item["latency_p95_ms"] for item in samples
            ),
            "latency_p95_max_ms": p95_max,
            "server_cpu_peak_percent": max(
                (
                    item["server_cpu_peak_percent"]
                    for item in samples
                    if item["server_cpu_peak_percent"] is not None
                ),
                default=None,
            ),
            "server_rss_peak_mb": max(
                (
                    item["server_rss_peak_mb"]
                    for item in samples
                    if item["server_rss_peak_mb"] is not None
                ),
                default=None,
            ),
            "p95_pass": p95_max < args.p95_limit_ms,
            "error_pass": error_max < args.error_limit,
            "approved": (
                p95_max < args.p95_limit_ms and error_max < args.error_limit
            ),
        }
        rows.append(row)
        print(
            f"k6 {level}: p95 mediano={row['latency_p95_ms']} ms, "
            f"p95 maximo={p95_max} ms, RPS={row['rps']}, "
            f"erros={row['errors']}, aprovado={row['approved']}"
        )

    target = next((item for item in rows if item["concurrency"] == 500), None)
    result = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "tool": "k6",
        "url": args.url,
        "iterations_per_level": args.iterations,
        "repetitions": max(1, args.repetitions),
        "execution": {
            "executor": "per-vu-iterations",
            "server_workers": args.server_workers,
            "warmup_requests": max(0, args.warmup_requests),
            "cooldown_seconds": max(0, args.cooldown_seconds),
        },
        "environment": {
            "platform": platform.platform(),
            "logical_cpus": os.cpu_count(),
            "python": platform.python_version(),
            "k6": subprocess.run(
                [executable, "version"],
                capture_output=True,
                text=True,
                check=False,
            ).stdout.strip(),
        },
        "success_criteria": {
            "target_concurrency": 500,
            "p95_limit_ms": args.p95_limit_ms,
            "error_rate_limit": args.error_limit,
        },
        "h5_approved": bool(target and target["approved"]),
        "results": rows,
        "raw_results": raw_rows,
    }
    (RESULTS_DIR / f"{args.output_prefix}.json").write_text(
        json.dumps(result, indent=2), encoding="utf-8"
    )
    with (RESULTS_DIR / f"{args.output_prefix}.csv").open(
        "w", newline="", encoding="utf-8-sig"
    ) as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    if target is None or not target["approved"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
