import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


VALIDATION_DIR = Path(__file__).resolve().parent
APP_DIR = VALIDATION_DIR.parent
REPO_DIR = APP_DIR.parent
RESULTS_DIR = VALIDATION_DIR / "results"


def _comando(nome, comando, cwd=APP_DIR, timeout=900):
    print(f"\n== {nome} ==")
    try:
        processo = subprocess.run(
            comando,
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
        saida = processo.stdout + "\n" + processo.stderr
        (RESULTS_DIR / f"{nome}.txt").write_text(saida, encoding="utf-8")
        print(saida[-2000:])
        return {
            "status": "passed" if processo.returncode == 0 else "failed",
            "return_code": processo.returncode,
        }
    except (OSError, subprocess.TimeoutExpired) as exc:
        (RESULTS_DIR / f"{nome}.txt").write_text(str(exc), encoding="utf-8")
        print(exc)
        return {"status": "error", "message": str(exc)}


def _ambiente():
    try:
        commit = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=REPO_DIR,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        commit = "indisponivel"
    memoria = None
    try:
        import psutil

        memoria = round(psutil.virtual_memory().total / 1024**3, 2)
    except ImportError:
        pass
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "git_commit": commit,
        "platform": platform.platform(),
        "python": platform.python_version(),
        "cpu": platform.processor(),
        "cpu_count": os.cpu_count(),
        "memory_gb": memoria,
    }


def main():
    parser = argparse.ArgumentParser(description="Validacao completa do Flash Dash")
    parser.add_argument("--quick", action="store_true")
    parser.add_argument("--skip-backend", action="store_true")
    parser.add_argument("--skip-flutter", action="store_true")
    parser.add_argument("--skip-etl", action="store_true")
    parser.add_argument("--skip-security", action="store_true")
    parser.add_argument("--skip-usability", action="store_true")
    parser.add_argument("--skip-llm", action="store_true")
    parser.add_argument("--llm-repetitions", type=int, default=1)
    parser.add_argument("--load-url")
    parser.add_argument("--load-server-pid", type=int)
    parser.add_argument("--load-server-workers", type=int, default=4)
    parser.add_argument("--stress-load", action="store_true")
    args = parser.parse_args()
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    (RESULTS_DIR / "environment.json").write_text(
        json.dumps(_ambiente(), indent=2, ensure_ascii=False), encoding="utf-8"
    )

    resumo_anterior = RESULTS_DIR / "execution_summary.json"
    execucao = (
        json.loads(resumo_anterior.read_text(encoding="utf-8"))
        if resumo_anterior.exists()
        else {}
    )
    if not args.skip_backend:
        execucao["backend_tests"] = _comando(
            "backend_tests",
            [
                sys.executable,
                "-m",
                "pytest",
                "-q",
                "--junitxml",
                str(RESULTS_DIR / "backend_tests.xml"),
            ],
            cwd=APP_DIR / "backend",
        )
        execucao["modeling_evaluation"] = _comando(
            "modeling_evaluation_log",
            [sys.executable, str(VALIDATION_DIR / "evaluate_data_modeling.py")],
        )
    if not args.skip_flutter:
        flutter = shutil.which("flutter") or shutil.which("flutter.bat")
        execucao["flutter_tests"] = _comando(
            "flutter_tests",
            [flutter, "test"] if flutter else ["flutter", "test"],
            cwd=APP_DIR / "frontend",
        )
    elif "flutter_tests" not in execucao:
        execucao["flutter_tests"] = {"status": "skipped"}

    tamanhos = "1000,10000" if args.quick else "1000,10000,50000"
    repeticoes = "1" if args.quick else "3"
    if not args.skip_etl:
        execucao["etl_benchmark"] = _comando(
            "etl_benchmark_log",
            [
                sys.executable,
                str(VALIDATION_DIR / "run_etl_benchmark.py"),
                "--sizes",
                tamanhos,
                "--repetitions",
                repeticoes,
            ],
        )
    if not args.skip_usability:
        execucao["usability"] = _comando(
            "usability_log",
            [sys.executable, str(VALIDATION_DIR / "analyze_usability.py")],
        )
    if not args.skip_security:
        execucao["security"] = _comando(
            "security_log",
            [sys.executable, str(VALIDATION_DIR / "run_security_scan.py")],
        )
    if args.skip_llm and "llm" not in execucao:
        execucao["llm"] = {"status": "skipped"}
    elif not args.skip_llm:
        execucao["llm"] = _comando(
            "llm_log",
            [
                sys.executable,
                str(VALIDATION_DIR / "evaluate_llm.py"),
                "--repetitions",
                str(max(1, args.llm_repetitions)),
                "--concurrency",
                "2",
                "--interval-seconds",
                "13",
            ],
            timeout=1800,
        )
    if args.load_url:
        comando_carga = [
            sys.executable,
            str(VALIDATION_DIR / "run_load_test.py"),
            "--url",
            args.load_url,
            "--requests",
            "30" if args.quick else "100",
        ]
        if args.load_server_pid:
            comando_carga.extend(["--server-pid", str(args.load_server_pid)])
        execucao["load"] = _comando(
            "load_log",
            comando_carga,
        )
        if args.stress_load:
            comando_estresse = [
                sys.executable,
                str(VALIDATION_DIR / "run_k6_stress.py"),
                "--url",
                args.load_url,
                "--concurrency",
                "100,250,500,1000",
                "--iterations",
                "1000" if args.quick else "5000",
                "--repetitions",
                "1" if args.quick else "3",
                "--output-prefix",
                "stress_test",
                "--server-workers",
                str(max(1, args.load_server_workers)),
            ]
            if args.load_server_pid:
                comando_estresse.extend(
                    ["--server-pid", str(args.load_server_pid)]
                )
            execucao["stress_load"] = _comando(
                "stress_load_log",
                comando_estresse,
                timeout=1800,
            )
    elif "load" not in execucao:
        execucao["load"] = {"status": "pending", "reason": "--load-url nao informado"}
    (RESULTS_DIR / "execution_summary.json").write_text(
        json.dumps(execucao, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    execucao["report"] = _comando(
        "report_log",
        [sys.executable, str(VALIDATION_DIR / "generate_report.py")],
    )
    (RESULTS_DIR / "execution_summary.json").write_text(
        json.dumps(execucao, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print("\nValidacao concluida. Consulte results/RELATORIO_VALIDACAO.md")


if __name__ == "__main__":
    main()
