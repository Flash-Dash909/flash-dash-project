import argparse
import csv
import gc
import json
import os
import statistics
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pandas as pd


VALIDATION_DIR = Path(__file__).resolve().parent
APP_DIR = VALIDATION_DIR.parent
RESULTS_DIR = VALIDATION_DIR / "results"
sys.path.insert(0, str(APP_DIR / "backend" / "src"))

from tratamento_dados import limparPlanilha


def _percentil(valores, percentil):
    if not valores:
        return None
    ordenados = sorted(valores)
    indice = (len(ordenados) - 1) * percentil
    inferior = int(indice)
    superior = min(inferior + 1, len(ordenados) - 1)
    peso = indice - inferior
    return ordenados[inferior] * (1 - peso) + ordenados[superior] * peso


def _gerar_csv(total_linhas):
    duplicadas = max(1, total_linhas // 100)
    unicas = max(1, total_linhas - duplicadas)
    inicio = datetime(2025, 1, 1)
    linhas = []
    for indice in range(unicas):
        valor = 1000 + (indice % 5000) * 1.37
        linhas.append(
            {
                "Data": (inicio + timedelta(days=indice % 730)).strftime("%d/%m/%Y"),
                "Cliente": f"Cliente {indice % 1000:04d}",
                "Produto": f"Produto {indice % 80:03d}",
                "Regiao": "" if indice % 53 == 0 else ["Norte", "Sul", "Leste", "Oeste"][indice % 4],
                "Faturamento": f"R$ {valor:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."),
                "Quantidade": (indice % 30) + 1,
                "Margem": f"{10 + indice % 35}%",
                "Email": f"cliente{indice % 1000}@example.com",
            }
        )
    linhas.extend(dict(linhas[indice % unicas]) for indice in range(duplicadas))
    df = pd.DataFrame(linhas[:total_linhas])
    return df.to_csv(index=False, sep=";").encode("utf-8")


def _medir(conteudo, tamanho, repeticao):
    gc.collect()
    amostras_rss = []
    parar = threading.Event()
    try:
        import psutil

        processo = psutil.Process(os.getpid())

        def amostrar_memoria():
            while not parar.wait(0.01):
                amostras_rss.append(processo.memory_info().rss)

        thread = threading.Thread(target=amostrar_memoria, daemon=True)
        thread.start()
    except ImportError:
        thread = None
    cpu_inicio = time.process_time()
    inicio = time.perf_counter()
    resultado = limparPlanilha(conteudo, f"benchmark_{tamanho}.csv")
    duracao = time.perf_counter() - inicio
    cpu = time.process_time() - cpu_inicio
    parar.set()
    if thread is not None:
        thread.join(timeout=1)
    resumo = resultado.get("summary", {})
    return {
        "input_rows": tamanho,
        "repetition": repeticao,
        "status": resultado.get("status"),
        "duration_ms": round(duracao * 1000, 2),
        "cpu_ms": round(cpu * 1000, 2),
        "peak_rss_mb": round(max(amostras_rss) / 1024 / 1024, 2)
        if amostras_rss
        else None,
        "throughput_rows_s": round(tamanho / duracao, 2) if duracao else 0,
        "output_rows": resumo.get("total_rows"),
        "duplicates_removed": resumo.get("duplicatas_removidas"),
        "nulls_before": resumo.get("nulos_antes"),
        "nulls_after": resumo.get("nulos_depois"),
        "anonymized_columns": len(resumo.get("colunas_anonimizadas", [])),
        "message": resultado.get("message", ""),
    }


def main():
    parser = argparse.ArgumentParser(description="Benchmark do Auto-Cleaning")
    parser.add_argument("--sizes", default="1000,10000,50000")
    parser.add_argument("--repetitions", type=int, default=3)
    args = parser.parse_args()
    tamanhos = [int(valor) for valor in args.sizes.split(",") if valor.strip()]
    repeticoes = max(1, args.repetitions)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    limparPlanilha(_gerar_csv(200), "aquecimento.csv")
    resultados = []
    for tamanho in tamanhos:
        conteudo = _gerar_csv(tamanho)
        for repeticao in range(1, repeticoes + 1):
            resultado = _medir(conteudo, tamanho, repeticao)
            resultados.append(resultado)
            print(
                f"ETL {tamanho} linhas [{repeticao}/{repeticoes}]: "
                f"{resultado['duration_ms']} ms"
            )

    with (RESULTS_DIR / "etl_benchmark.csv").open(
        "w", newline="", encoding="utf-8-sig"
    ) as arquivo:
        writer = csv.DictWriter(arquivo, fieldnames=resultados[0].keys())
        writer.writeheader()
        writer.writerows(resultados)

    agregados = []
    for tamanho in tamanhos:
        grupo = [item for item in resultados if item["input_rows"] == tamanho]
        duracoes = [item["duration_ms"] for item in grupo]
        vazoes = [item["throughput_rows_s"] for item in grupo]
        memorias = [item["peak_rss_mb"] for item in grupo if item["peak_rss_mb"] is not None]
        agregados.append(
            {
                "input_rows": tamanho,
                "runs": len(grupo),
                "success_rate": sum(item["status"] == "success" for item in grupo) / len(grupo),
                "median_duration_ms": statistics.median(duracoes),
                "p95_duration_ms": _percentil(duracoes, 0.95),
                "median_throughput_rows_s": statistics.median(vazoes),
                "median_peak_memory_mb": statistics.median(memorias) if memorias else None,
            }
        )
    resumo = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "warmup_rows": 200,
        "aggregates": agregados,
    }
    (RESULTS_DIR / "etl_benchmark_summary.json").write_text(
        json.dumps(resumo, indent=2, ensure_ascii=False), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
