import argparse
import asyncio
from collections import Counter
import csv
import json
import re
import statistics
import time
from datetime import datetime, timezone
from pathlib import Path

import httpx

try:
    import psutil
except ImportError:  # A medicao HTTP continua valida sem telemetria do processo.
    psutil = None


VALIDATION_DIR = Path(__file__).resolve().parent
RESULTS_DIR = VALIDATION_DIR / "results"


def _percentil(valores, percentil):
    if not valores:
        return None
    ordenados = sorted(valores)
    indice = (len(ordenados) - 1) * percentil
    inferior = int(indice)
    superior = min(inferior + 1, len(ordenados) - 1)
    peso = indice - inferior
    return ordenados[inferior] * (1 - peso) + ordenados[superior] * peso


async def _requisicao(client, url, semaforo):
    async with semaforo:
        inicio = time.perf_counter()
        try:
            resposta = await client.get(url)
            sucesso = 200 <= resposta.status_code < 300
            erro = None if sucesso else f"http_{resposta.status_code}"
            return (time.perf_counter() - inicio) * 1000, sucesso, erro
        except httpx.TimeoutException:
            return (time.perf_counter() - inicio) * 1000, False, "timeout"
        except httpx.ConnectError:
            return (time.perf_counter() - inicio) * 1000, False, "connection"
        except httpx.HTTPError:
            return (time.perf_counter() - inicio) * 1000, False, "transport"


async def _monitorar_processo(pid, parar, amostras):
    if not pid or psutil is None:
        return
    try:
        processo = psutil.Process(pid)
        processo.cpu_percent(None)
    except (psutil.Error, OSError):
        return
    while not parar.is_set():
        await asyncio.sleep(0.1)
        try:
            amostras.append(
                {
                    "cpu_percent": processo.cpu_percent(None),
                    "rss_mb": processo.memory_info().rss / 1024**2,
                }
            )
        except (psutil.Error, OSError):
            return


async def _cenario(client, url, concorrencia, requisicoes, server_pid=None):
    semaforo = asyncio.Semaphore(concorrencia)
    parar_monitor = asyncio.Event()
    recursos = []
    monitor = asyncio.create_task(
        _monitorar_processo(server_pid, parar_monitor, recursos)
    )
    inicio = time.perf_counter()
    try:
        resultados = await asyncio.gather(
            *[_requisicao(client, url, semaforo) for _ in range(requisicoes)]
        )
    finally:
        parar_monitor.set()
        await monitor
    duracao = time.perf_counter() - inicio
    latencias_todas = [item[0] for item in resultados]
    latencias = [item[0] for item in resultados if item[1]] or latencias_todas
    sucessos = sum(item[1] for item in resultados)
    erros = Counter(item[2] for item in resultados if item[2])
    return {
        "concurrency": concorrencia,
        "requests": requisicoes,
        "successes": sucessos,
        "errors": requisicoes - sucessos,
        "error_rate": (requisicoes - sucessos) / requisicoes,
        "duration_s": round(duracao, 3),
        "rps": round(requisicoes / duracao, 2),
        "latency_mean_ms": round(statistics.mean(latencias), 2),
        "latency_p50_ms": round(_percentil(latencias, 0.50), 2),
        "latency_p95_ms": round(_percentil(latencias, 0.95), 2),
        "latency_p99_ms": round(_percentil(latencias, 0.99), 2),
        "timeout_errors": erros["timeout"],
        "connection_errors": erros["connection"],
        "http_errors": sum(
            quantidade
            for tipo, quantidade in erros.items()
            if tipo and tipo.startswith("http_")
        ),
        "transport_errors": erros["transport"],
        "server_cpu_peak_percent": (
            round(max(item["cpu_percent"] for item in recursos), 2)
            if recursos
            else None
        ),
        "server_rss_peak_mb": (
            round(max(item["rss_mb"] for item in recursos), 2)
            if recursos
            else None
        ),
    }


async def _executar(url, concorrencias, requisicoes, timeout, server_pid=None):
    maximo = max(concorrencias)
    limites = httpx.Limits(
        max_connections=maximo,
        max_keepalive_connections=min(maximo, 500),
    )
    async with httpx.AsyncClient(
        timeout=httpx.Timeout(timeout),
        limits=limites,
        trust_env=False,
    ) as client:
        for _ in range(5):
            resposta = await client.get(url)
            resposta.raise_for_status()
        resultados = []
        for concorrencia in concorrencias:
            item = await _cenario(
                client,
                url,
                concorrencia,
                requisicoes,
                server_pid,
            )
            resultados.append(item)
            print(
                f"Carga {concorrencia}: p95={item['latency_p95_ms']} ms, "
                f"RPS={item['rps']}, erros={item['errors']}"
            )
        return resultados


def _agrupar_repeticoes(resultados, repeticoes):
    agregados = []
    for concorrencia in sorted({item["concurrency"] for item in resultados}):
        itens = [
            item for item in resultados if item["concurrency"] == concorrencia
        ]

        def mediana(campo, casas=2):
            valores = [item[campo] for item in itens if item[campo] is not None]
            return round(statistics.median(valores), casas) if valores else None

        requisicoes = int(statistics.median(item["requests"] for item in itens))
        erros = max(item["errors"] for item in itens)
        agregados.append(
            {
                "concurrency": concorrencia,
                "requests": requisicoes,
                "successes": requisicoes - erros,
                "errors": erros,
                "error_rate": round(max(item["error_rate"] for item in itens), 6),
                "duration_s": mediana("duration_s", 3),
                "rps": mediana("rps"),
                "latency_mean_ms": mediana("latency_mean_ms"),
                "latency_p50_ms": mediana("latency_p50_ms"),
                "latency_p95_ms": mediana("latency_p95_ms"),
                "latency_p99_ms": mediana("latency_p99_ms"),
                "timeout_errors": max(item["timeout_errors"] for item in itens),
                "connection_errors": max(
                    item["connection_errors"] for item in itens
                ),
                "http_errors": max(item["http_errors"] for item in itens),
                "transport_errors": max(
                    item["transport_errors"] for item in itens
                ),
                "server_cpu_peak_percent": max(
                    (
                        item["server_cpu_peak_percent"]
                        for item in itens
                        if item["server_cpu_peak_percent"] is not None
                    ),
                    default=None,
                ),
                "server_rss_peak_mb": max(
                    (
                        item["server_rss_peak_mb"]
                        for item in itens
                        if item["server_rss_peak_mb"] is not None
                    ),
                    default=None,
                ),
                "repetitions": repeticoes,
                "latency_p95_min_ms": round(
                    min(item["latency_p95_ms"] for item in itens), 2
                ),
                "latency_p95_max_ms": round(
                    max(item["latency_p95_ms"] for item in itens), 2
                ),
            }
        )
    return agregados


def main():
    parser = argparse.ArgumentParser(description="Teste de carga HTTP")
    parser.add_argument("--url", default="http://127.0.0.1:8000/health")
    parser.add_argument("--concurrency", default="1,5,10,25,50")
    parser.add_argument("--requests", type=int, default=100)
    parser.add_argument("--timeout", type=float, default=10)
    parser.add_argument("--server-pid", type=int)
    parser.add_argument("--output-prefix", default="load_test")
    parser.add_argument("--label", default="baseline_http")
    parser.add_argument("--repetitions", type=int, default=1)
    args = parser.parse_args()
    concorrencias = [int(valor) for valor in args.concurrency.split(",")]
    if not concorrencias or min(concorrencias) < 1:
        parser.error("Os valores de concorrencia devem ser inteiros positivos.")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.output_prefix):
        parser.error("output-prefix aceita apenas letras, numeros, _ e -.")
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    repeticoes = max(1, args.repetitions)
    resultados_brutos = []
    try:
        for repeticao in range(1, repeticoes + 1):
            print(f"Repeticao {repeticao}/{repeticoes}")
            rodada = asyncio.run(
                _executar(
                    args.url,
                    concorrencias,
                    max(1, args.requests),
                    args.timeout,
                    args.server_pid,
                )
            )
            for item in rodada:
                resultados_brutos.append({"repetition": repeticao, **item})
    except (httpx.HTTPError, OSError) as exc:
        (RESULTS_DIR / f"{args.output_prefix}_error.txt").write_text(
            str(exc), encoding="utf-8"
        )
        raise SystemExit(f"Servidor indisponivel para o teste de carga: {exc}")

    resultados = _agrupar_repeticoes(resultados_brutos, repeticoes)

    with (RESULTS_DIR / f"{args.output_prefix}.csv").open(
        "w", newline="", encoding="utf-8-sig"
    ) as arquivo:
        writer = csv.DictWriter(arquivo, fieldnames=resultados[0].keys())
        writer.writeheader()
        writer.writerows(resultados)
    with (RESULTS_DIR / f"{args.output_prefix}_raw.csv").open(
        "w", newline="", encoding="utf-8-sig"
    ) as arquivo:
        writer = csv.DictWriter(
            arquivo, fieldnames=resultados_brutos[0].keys()
        )
        writer.writeheader()
        writer.writerows(resultados_brutos)
    (RESULTS_DIR / f"{args.output_prefix}.json").write_text(
        json.dumps(
            {
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "label": args.label,
                "url": args.url,
                "warmup_requests": 5,
                "requests_per_level": max(1, args.requests),
                "repetitions": repeticoes,
                "concurrency_semantics": "requisicoes HTTP simultaneas",
                "client_max_connections": max(concorrencias),
                "server_pid": args.server_pid,
                "results": resultados,
                "raw_results": resultados_brutos,
            },
            indent=2,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
