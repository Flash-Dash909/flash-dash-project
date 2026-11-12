import csv
import importlib.util
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


VALIDATION_DIR = Path(__file__).resolve().parent
APP_DIR = VALIDATION_DIR.parent
RESULTS_DIR = VALIDATION_DIR / "results"
INCIDENTS_PATH = VALIDATION_DIR / "templates" / "security_incidents.csv"


def _executar(comando, nome):
    processo = subprocess.run(
        comando,
        cwd=APP_DIR,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    (RESULTS_DIR / f"{nome}.txt").write_text(
        processo.stdout + "\n" + processo.stderr, encoding="utf-8"
    )
    return processo


def _mttr_horas():
    if not INCIDENTS_PATH.exists():
        return None, 0
    from datetime import datetime as dt

    tempos = []
    with INCIDENTS_PATH.open(encoding="utf-8-sig") as arquivo:
        for linha in csv.DictReader(arquivo):
            if not linha.get("discovered_at") or not linha.get("fixed_at"):
                continue
            try:
                descoberta = dt.fromisoformat(linha["discovered_at"].replace("Z", "+00:00"))
                correcao = dt.fromisoformat(linha["fixed_at"].replace("Z", "+00:00"))
                tempos.append((correcao - descoberta).total_seconds() / 3600)
            except ValueError:
                continue
    return (sum(tempos) / len(tempos), len(tempos)) if tempos else (None, 0)


def main():
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    testes = _executar(
        [sys.executable, "-m", "pytest", "backend/tests/test_auth_security.py", "-q"],
        "security_auth_tests",
    )
    resumo = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "auth_tests": {
            "status": "passed" if testes.returncode == 0 else "failed",
            "return_code": testes.returncode,
        },
        "bandit": {"status": "not_installed", "severity": {}},
        "pip_audit": {"status": "not_installed", "vulnerabilities": 0},
    }

    if importlib.util.find_spec("bandit"):
        bruto = RESULTS_DIR / "security_bandit_raw.json"
        processo = _executar(
            [
                sys.executable,
                "-m",
                "bandit",
                "-r",
                "backend/src",
                "-f",
                "json",
                "-o",
                str(bruto),
                "--exit-zero",
            ],
            "security_bandit",
        )
        severidades = {"LOW": 0, "MEDIUM": 0, "HIGH": 0}
        if bruto.exists():
            payload = json.loads(bruto.read_text(encoding="utf-8"))
            for achado in payload.get("results", []):
                nivel = achado.get("issue_severity", "LOW")
                severidades[nivel] = severidades.get(nivel, 0) + 1
        resumo["bandit"] = {
            "status": "completed" if processo.returncode == 0 else "failed",
            "severity": severidades,
        }

    if importlib.util.find_spec("pip_audit"):
        processo = _executar(
            [
                sys.executable,
                "-m",
                "pip_audit",
                "-r",
                "backend/requirements.txt",
                "-f",
                "json",
            ],
            "security_pip_audit",
        )
        vulnerabilidades = 0
        try:
            payload = json.loads(processo.stdout)
            dependencias = payload.get("dependencies", payload) if isinstance(payload, dict) else payload
            vulnerabilidades = sum(len(item.get("vulns", [])) for item in dependencias)
        except (json.JSONDecodeError, TypeError):
            pass
        resumo["pip_audit"] = {
            "status": "completed" if processo.returncode in {0, 1} else "failed",
            "vulnerabilities": vulnerabilidades,
            "return_code": processo.returncode,
        }

    mttr, amostra = _mttr_horas()
    resumo["mttr_hours"] = mttr
    resumo["mttr_sample"] = amostra
    resumo["acceptance"] = {
        "auth_isolation_passed": testes.returncode == 0,
        "no_high_bandit_findings": resumo["bandit"]["severity"].get("HIGH", 0) == 0
        if resumo["bandit"]["status"] == "completed"
        else None,
        "dependency_audit_clean": resumo["pip_audit"]["vulnerabilities"] == 0
        if resumo["pip_audit"]["status"] == "completed"
        else None,
    }
    (RESULTS_DIR / "security_summary.json").write_text(
        json.dumps(resumo, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(json.dumps(resumo, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
