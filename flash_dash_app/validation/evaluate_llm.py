import argparse
import asyncio
import csv
import json
import math
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


VALIDATION_DIR = Path(__file__).resolve().parent
APP_DIR = VALIDATION_DIR.parent
BACKEND_SRC = APP_DIR / "backend" / "src"
RESULTS_DIR = VALIDATION_DIR / "results"
DATASET_PATH = VALIDATION_DIR / "datasets" / "llm_recommendation_cases.json"
sys.path.insert(0, str(BACKEND_SRC))

from recommendation_service import VISUAIS_PERMITIDOS, recomendar_visuais


def _wilson(successes, total, z=1.96):
    if total == 0:
        return None, None
    proportion = successes / total
    denominator = 1 + (z * z / total)
    center = (proportion + z * z / (2 * total)) / denominator
    margin = (
        z
        * math.sqrt(
            proportion * (1 - proportion) / total
            + z * z / (4 * total * total)
        )
        / denominator
    )
    return max(0.0, center - margin), min(1.0, center + margin)


class _RateLimiter:
    def __init__(self, interval_seconds):
        self.interval_seconds = max(0.0, interval_seconds)
        self.next_start = 0.0
        self.lock = asyncio.Lock()

    async def wait(self):
        if self.interval_seconds == 0:
            return
        async with self.lock:
            agora = time.monotonic()
            espera = max(0.0, self.next_start - agora)
            if espera:
                await asyncio.sleep(espera)
            self.next_start = time.monotonic() + self.interval_seconds


async def _avaliar_caso(caso, repeticao, semaforo, limitador):
    async with semaforo:
        await limitador.wait()
        inicio = time.perf_counter()
        resposta = await recomendar_visuais(
            caso["summary"],
            caso.get("sample", []),
            max_recomendacoes=3,
        )
        latencia_ms = (time.perf_counter() - inicio) * 1000

    recomendacoes = resposta.get("recomendacoes", [])
    tipos = [item.get("tipo") for item in recomendacoes]
    aceitos = set(caso["accepted_visuals"])
    dimensoes = set(caso["summary"].get("dimensoes", []))
    metricas = set(caso["summary"].get("metricas", []))
    campos_validos = bool(recomendacoes) and all(
        (item.get("dimensao") is None or item.get("dimensao") in dimensoes)
        and all(metrica in metricas for metrica in item.get("metricas", []))
        for item in recomendacoes
    )
    return {
        "case_id": caso["id"],
        "scenario": caso["scenario"],
        "repetition": repeticao,
        "status": resposta.get("status", "error"),
        "latency_ms": round(latencia_ms, 2),
        "accepted_visuals": caso["accepted_visuals"],
        "recommended_visuals": tipos,
        "top1_hit": bool(tipos and tipos[0] in aceitos),
        "top3_hit": bool(aceitos.intersection(tipos[:3])),
        "valid_catalog": bool(tipos) and all(
            tipo in VISUAIS_PERMITIDOS for tipo in tipos
        ),
        "valid_fields": campos_validos,
        "error_type": resposta.get("error_type", ""),
        "message": resposta.get("message", ""),
    }


async def _executar(casos, repeticoes, concorrencia, intervalo):
    semaforo = asyncio.Semaphore(max(1, concorrencia))
    limitador = _RateLimiter(intervalo)
    tarefas = [
        _avaliar_caso(caso, repeticao, semaforo, limitador)
        for repeticao in range(1, repeticoes + 1)
        for caso in casos
    ]
    return await asyncio.gather(*tarefas)


def _media(valores):
    return sum(valores) / len(valores) if valores else None


def main():
    parser = argparse.ArgumentParser(description="Avalia recomendacoes Gemini")
    parser.add_argument("--repetitions", type=int, default=1)
    parser.add_argument("--concurrency", type=int, default=2)
    parser.add_argument(
        "--interval-seconds",
        type=float,
        default=13,
        help="Intervalo entre chamadas; 13 s respeita o limite gratuito de 5/min.",
    )
    parser.add_argument("--dataset", type=Path, default=DATASET_PATH)
    parser.add_argument(
        "--recompute-only",
        action="store_true",
        help="Recalcula o resumo usando o JSON existente sem chamar a API.",
    )
    args = parser.parse_args()

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    casos = json.loads(args.dataset.read_text(encoding="utf-8"))
    resultado_existente = RESULTS_DIR / "llm_evaluation.json"
    if args.recompute_only:
        if not resultado_existente.exists():
            raise SystemExit("Nao existe resultado anterior para recalcular.")
        payload_existente = json.loads(resultado_existente.read_text(encoding="utf-8"))
        resultados = payload_existente.get("results", [])
        repeticoes_registradas = payload_existente.get("summary", {}).get(
            "repetitions", 1
        )
    else:
        resultados = asyncio.run(
            _executar(
                casos,
                max(1, args.repetitions),
                max(1, args.concurrency),
                max(0, args.interval_seconds),
            )
        )
        repeticoes_registradas = max(1, args.repetitions)
    for item in resultados:
        if "error_type" not in item:
            mensagem = item.get("message", "")
            item["error_type"] = (
                "quota" if "RESOURCE_EXHAUSTED" in mensagem or "429" in mensagem else ""
            )
    total = len(resultados)
    respostas_validas = sum(item["status"] == "success" for item in resultados)
    top1 = sum(item["top1_hit"] for item in resultados)
    top3 = sum(item["top3_hit"] for item in resultados)
    catalogo = sum(item["valid_catalog"] for item in resultados)
    campos = sum(item["valid_fields"] for item in resultados)
    ci_top1 = _wilson(top1, total)
    ci_top3 = _wilson(top3, total)
    ci_top1_respostas = _wilson(top1, respostas_validas)
    ci_top3_respostas = _wilson(top3, respostas_validas)
    erros_cota = sum(item.get("error_type") == "quota" for item in resultados)
    latencias = [
        item["latency_ms"] for item in resultados if item["status"] == "success"
    ]
    resumo = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model": "gemini-2.5-flash",
        "cases": len(casos),
        "repetitions": repeticoes_registradas,
        "attempts": total,
        "request_interval_seconds": max(0, args.interval_seconds),
        "response_rate": respostas_validas / total if total else 0,
        "quota_error_rate": erros_cota / total if total else 0,
        "top1_accuracy": top1 / total if total else 0,
        "top1_ci95": list(ci_top1),
        "top3_accuracy": top3 / total if total else 0,
        "top3_ci95": list(ci_top3),
        "top1_accuracy_on_responses": top1 / respostas_validas
        if respostas_validas
        else 0,
        "top1_responses_ci95": list(ci_top1_respostas),
        "top3_accuracy_on_responses": top3 / respostas_validas
        if respostas_validas
        else 0,
        "top3_responses_ci95": list(ci_top3_respostas),
        "valid_catalog_rate": catalogo / total if total else 0,
        "valid_fields_rate": campos / total if total else 0,
        "mean_latency_ms": _media(latencias),
        "note": "Falhas de resposta contam como erro nas metricas Top-k.",
    }
    (RESULTS_DIR / "llm_evaluation.json").write_text(
        json.dumps({"summary": resumo, "results": resultados}, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    with (RESULTS_DIR / "llm_evaluation.csv").open(
        "w", newline="", encoding="utf-8-sig"
    ) as arquivo:
        campos_csv = [
            "case_id",
            "scenario",
            "repetition",
            "status",
            "latency_ms",
            "accepted_visuals",
            "recommended_visuals",
            "top1_hit",
            "top3_hit",
            "valid_catalog",
            "valid_fields",
            "error_type",
            "message",
        ]
        writer = csv.DictWriter(arquivo, fieldnames=campos_csv)
        writer.writeheader()
        for item in resultados:
            linha = dict(item)
            linha["accepted_visuals"] = " | ".join(item["accepted_visuals"])
            linha["recommended_visuals"] = " | ".join(item["recommended_visuals"])
            writer.writerow(linha)
    print(json.dumps(resumo, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
