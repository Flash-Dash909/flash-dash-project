import csv
import json
from datetime import datetime, timezone
from pathlib import Path


VALIDATION_DIR = Path(__file__).resolve().parent
RESULTS_DIR = VALIDATION_DIR / "results"


def _json(nome):
    caminho = RESULTS_DIR / nome
    if not caminho.exists():
        return None
    return json.loads(caminho.read_text(encoding="utf-8"))


def _csv(nome):
    caminho = RESULTS_DIR / nome
    if not caminho.exists():
        return []
    with caminho.open(encoding="utf-8-sig") as arquivo:
        return list(csv.DictReader(arquivo))


def _percentual(valor):
    return "pendente" if valor is None else f"{valor * 100:.1f}%"


def _numero(valor, casas=1, sufixo=""):
    return "pendente" if valor is None else f"{valor:.{casas}f}{sufixo}"


def _gerar_graficos():
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return []
    gerados = []
    etl = _json("etl_benchmark_summary.json")
    if etl and etl.get("aggregates"):
        dados = etl["aggregates"]
        tamanhos = [item["input_rows"] for item in dados]
        tempos = [item["median_duration_ms"] / 1000 for item in dados]
        vazoes = [item["median_throughput_rows_s"] for item in dados]
        figura, eixos = plt.subplots(1, 2, figsize=(10, 4))
        eixos[0].plot(tamanhos, tempos, marker="o", color="#2563EB")
        eixos[0].set_title("Tempo mediano do Auto-Cleaning")
        eixos[0].set_xlabel("Linhas")
        eixos[0].set_ylabel("Segundos")
        eixos[0].grid(alpha=0.25)
        eixos[1].plot(tamanhos, vazoes, marker="o", color="#10B981")
        eixos[1].set_title("Vazao mediana")
        eixos[1].set_xlabel("Linhas")
        eixos[1].set_ylabel("Linhas/s")
        eixos[1].grid(alpha=0.25)
        figura.tight_layout()
        figura.savefig(RESULTS_DIR / "etl_performance.png", dpi=170)
        plt.close(figura)
        gerados.append("etl_performance.png")

    carga = _csv("load_test.csv")
    if carga:
        concorrencia = [int(item["concurrency"]) for item in carga]
        p95 = [float(item["latency_p95_ms"]) for item in carga]
        rps = [float(item["rps"]) for item in carga]
        figura, eixo1 = plt.subplots(figsize=(8, 4.5))
        eixo2 = eixo1.twinx()
        eixo1.plot(concorrencia, p95, marker="o", color="#EF4444", label="p95")
        eixo2.plot(concorrencia, rps, marker="s", color="#2563EB", label="RPS")
        eixo1.set_xlabel("Clientes concorrentes")
        eixo1.set_ylabel("Latencia p95 (ms)", color="#EF4444")
        eixo2.set_ylabel("Requisicoes/s", color="#2563EB")
        eixo1.set_title("Curva de carga da API")
        eixo1.grid(alpha=0.25)
        figura.tight_layout()
        figura.savefig(RESULTS_DIR / "load_curve.png", dpi=170)
        plt.close(figura)
        gerados.append("load_curve.png")

    estresse = _csv("stress_test.csv")
    if estresse:
        concorrencia = [int(item["concurrency"]) for item in estresse]
        p95 = [float(item["latency_p95_ms"]) for item in estresse]
        rps = [float(item["rps"]) for item in estresse]
        erros = [float(item["error_rate"]) * 100 for item in estresse]
        figura, eixo1 = plt.subplots(figsize=(8, 4.5))
        eixo2 = eixo1.twinx()
        linha_p95 = eixo1.plot(
            concorrencia, p95, marker="o", color="#EF4444", label="p95"
        )[0]
        linha_rps = eixo2.plot(
            concorrencia, rps, marker="s", color="#2563EB", label="RPS"
        )[0]
        eixo1.set_xlabel("Requisicoes simultaneas")
        eixo1.set_ylabel("Latencia p95 (ms)", color="#EF4444")
        eixo2.set_ylabel("Requisicoes/s", color="#2563EB")
        eixo1.set_title("Curva ampliada de estresse da API")
        eixo1.grid(alpha=0.25)
        eixo1.legend([linha_p95, linha_rps], ["p95", "RPS"], loc="upper left")
        eixo1.text(
            0.02,
            0.82,
            f"Taxa maxima de erro: {max(erros):.2f}%",
            transform=eixo1.transAxes,
            color="#475569",
        )
        figura.tight_layout()
        figura.savefig(RESULTS_DIR / "stress_curve.png", dpi=170)
        plt.close(figura)
        gerados.append("stress_curve.png")

    llm = _json("llm_evaluation.json")
    if llm:
        resumo = llm["summary"]
        rotulos = ["Resposta", "Top-1 recebido", "Top-3 recebido", "Campos validos"]
        valores = [
            resumo["response_rate"],
            resumo.get("top1_accuracy_on_responses", resumo["top1_accuracy"]),
            resumo.get("top3_accuracy_on_responses", resumo["top3_accuracy"]),
            resumo["valid_fields_rate"],
        ]
        figura, eixo = plt.subplots(figsize=(8, 4.5))
        barras = eixo.bar(rotulos, valores, color=["#2563EB", "#10B981", "#7C3AED", "#F59E0B"])
        eixo.set_ylim(0, 1)
        eixo.set_ylabel("Proporcao")
        eixo.set_title("Qualidade da recomendacao de visuais")
        eixo.bar_label(barras, labels=[f"{valor * 100:.1f}%" for valor in valores])
        figura.tight_layout()
        figura.savefig(RESULTS_DIR / "llm_accuracy.png", dpi=170)
        plt.close(figura)
        gerados.append("llm_accuracy.png")
    return gerados


def main():
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    graficos = _gerar_graficos()
    ambiente = _json("environment.json") or {}
    execucao = _json("execution_summary.json") or {}
    etl = _json("etl_benchmark_summary.json")
    modeling = _json("modeling_evaluation.json")
    llm = _json("llm_evaluation.json")
    carga = _csv("load_test.csv")
    estresse = _csv("stress_test.csv")
    seguranca = _json("security_summary.json")
    usabilidade = _json("usability_metrics.json")

    linhas = [
        "# Relatorio de Validacao do Flash Dash",
        "",
        f"Gerado em: {datetime.now(timezone.utc).isoformat()}",
        "",
        "## Resumo executivo",
        "",
        "Este relatorio reune evidencias automatizadas do Auto-Cleaning, modelo estrela, responsividade, desempenho, escalabilidade, seguranca e recomendacao por LLM. Resultados de usabilidade permanecem pendentes ate a coleta com participantes reais.",
        "",
        "## Ambiente",
        "",
        f"- Commit: `{ambiente.get('git_commit', 'nao registrado')}`",
        f"- Sistema: {ambiente.get('platform', 'nao registrado')}",
        f"- Python: {ambiente.get('python', 'nao registrado')}",
        f"- CPU logica: {ambiente.get('cpu_count', 'nao registrado')}",
        f"- Memoria RAM: {ambiente.get('memory_gb', 'nao registrada')} GB",
        "",
        "## Testes funcionais e responsividade",
        "",
        f"- Backend: {execucao.get('backend_tests', {}).get('status', 'pendente')}",
        f"- Flutter: {execucao.get('flutter_tests', {}).get('status', 'pendente')}",
        "- Assercoes cobrem importacao, limpeza, anonimização, esquema estrela, autenticacao, isolamento e validacao da resposta da IA.",
        "- A matriz Flutter verifica viewports de celular, tablet e desktop; navegadores reais ainda devem ser registrados na rodada final.",
        "",
    ]
    if modeling:
        linhas.extend(
            [
                "## Modelagem dimensional (H2)",
                "",
                f"- Casos rotulados: {modeling['cases']}",
                f"- Acuracia estrutural: {_percentual(modeling['structural_accuracy'])}",
                f"- Precisao dos relacionamentos: {_percentual(modeling['relationship_precision'])}",
                f"- Revocacao dos relacionamentos: {_percentual(modeling['relationship_recall'])}",
                f"- Criterio de pelo menos 90%: **{'aprovado' if modeling['approved'] else 'reprovado'}**.",
                "- O conjunto inclui relacoes 1:1, 1:N, N:N, tres fontes, chaves numericas/textuais, integridade parcial e casos negativos.",
                "",
            ]
        )
    else:
        linhas.extend(
            [
                "## Modelagem dimensional (H2)",
                "",
                "A avaliacao com conjunto rotulado ainda nao foi executada.",
                "",
            ]
        )
    linhas.extend(["## Auto-Cleaning e desempenho", ""])
    if etl:
        linhas.extend(
            [
                "| Linhas | Execucoes | Sucesso | Mediana | p95 | Vazao mediana | Pico de memoria |",
                "|---:|---:|---:|---:|---:|---:|---:|",
            ]
        )
        for item in etl["aggregates"]:
            linhas.append(
                f"| {item['input_rows']} | {item['runs']} | {_percentual(item['success_rate'])} | "
                f"{item['median_duration_ms']:.1f} ms | {item['p95_duration_ms']:.1f} ms | "
                f"{item['median_throughput_rows_s']:.0f} linhas/s | {item['median_peak_memory_mb']:.1f} MB |"
            )
        linhas.extend(["", "![Desempenho ETL](etl_performance.png)", ""])
    else:
        linhas.extend(["Benchmark ainda nao executado.", ""])

    linhas.extend(["## Recomendacao por LLM", ""])
    if llm:
        resumo = llm["summary"]
        linhas.extend(
            [
                f"- Modelo: `{resumo['model']}`",
                f"- Casos/repeticoes: {resumo['cases']} / {resumo['repetitions']}",
                f"- Taxa de resposta: {_percentual(resumo['response_rate'])}",
                f"- Falhas por cota: {_percentual(resumo.get('quota_error_rate'))}",
                f"- Top-1 ponta a ponta: {_percentual(resumo['top1_accuracy'])}",
                f"- Top-3 ponta a ponta: {_percentual(resumo['top3_accuracy'])}",
                f"- Top-1 entre respostas recebidas: {_percentual(resumo.get('top1_accuracy_on_responses'))}",
                f"- Top-3 entre respostas recebidas: {_percentual(resumo.get('top3_accuracy_on_responses'))}",
                f"- Catalogo valido: {_percentual(resumo['valid_catalog_rate'])}",
                f"- Campos validos: {_percentual(resumo['valid_fields_rate'])}",
                f"- Latencia media: {_numero(resumo['mean_latency_ms'], 1, ' ms')}",
                "",
                "![Acuracia LLM](llm_accuracy.png)",
                "",
                "ROC e Precision-Recall nao sao as metricas principais deste modulo: o Flash Dash executa uma recomendacao Top-k multiclasse, nao uma classificacao binaria com limiar. Top-1, Top-3, validade e latencia representam diretamente o objetivo do sistema.",
                "",
            ]
        )
    else:
        linhas.extend(["Avaliacao ainda nao executada.", ""])

    linhas.extend(["## Escalabilidade", ""])
    if carga:
        linhas.extend(
            [
                "| Concorrencia | RPS | p50 | p95 | p99 | Erros |",
                "|---:|---:|---:|---:|---:|---:|",
            ]
        )
        for item in carga:
            linhas.append(
                f"| {item['concurrency']} | {float(item['rps']):.1f} | {float(item['latency_p50_ms']):.1f} ms | "
                f"{float(item['latency_p95_ms']):.1f} ms | {float(item['latency_p99_ms']):.1f} ms | {item['errors']} |"
            )
        linhas.extend(["", "![Curva de carga](load_curve.png)", ""])
    else:
        linhas.extend(["Teste de carga pendente; informe `--load-url` ao executor.", ""])

    linhas.extend(["### Estresse ampliado", ""])
    if estresse:
        linhas.extend(
            [
                "| Concorrencia | RPS | p50 | p95 | p99 | Erro | CPU pico | RAM pico |",
                "|---:|---:|---:|---:|---:|---:|---:|---:|",
            ]
        )
        for item in estresse:
            cpu = item.get("server_cpu_peak_percent") or "pendente"
            ram = item.get("server_rss_peak_mb") or "pendente"
            linhas.append(
                f"| {item['concurrency']} | {float(item['rps']):.1f} | {float(item['latency_p50_ms']):.1f} ms | "
                f"{float(item['latency_p95_ms']):.1f} ms | {float(item['latency_p99_ms']):.1f} ms | "
                f"{float(item['error_rate']) * 100:.2f}% | {cpu}% | {ram} MB |"
            )
        nivel_500 = next(
            (item for item in estresse if int(item["concurrency"]) == 500),
            None,
        )
        if nivel_500:
            aprovado = (
                float(nivel_500["latency_p95_ms"]) < 1000
                and float(nivel_500["error_rate"]) < 0.01
            )
            linhas.extend(
                [
                    "",
                    f"- Repeticoes por nivel: {nivel_500.get('repetitions', 1)}; cinco mil requisicoes em cada repeticao.",
                    f"- Criterio provisorio em 500 simultaneas: **{'aprovado' if aprovado else 'reprovado'}**.",
                ]
            )
        linhas.extend(
            [
                "- Este ensaio representa requisicoes HTTP simultaneas contra `/health`, nao sessoes completas de usuarios.",
                "",
                "![Curva de estresse](stress_curve.png)",
                "",
            ]
        )
    else:
        linhas.extend(["Teste ampliado de 100 a 1000 ainda nao executado.", ""])

    linhas.extend(["## Seguranca", ""])
    if seguranca:
        linhas.extend(
            [
                f"- Testes de autenticacao/isolamento: {seguranca['auth_tests']['status']}",
                f"- Bandit: {seguranca['bandit']['status']} - {seguranca['bandit']['severity']}",
                f"- Auditoria de dependencias: {seguranca['pip_audit']['status']} - {seguranca['pip_audit']['vulnerabilities']} achados",
                f"- MTTR: {_numero(seguranca.get('mttr_hours'), 1, ' horas')} (n={seguranca.get('mttr_sample', 0)})",
                "",
            ]
        )
    else:
        linhas.extend(["Varredura ainda nao executada.", ""])

    linhas.extend(["## Usabilidade e UX", ""])
    if usabilidade and usabilidade.get("status") == "complete":
        linhas.extend(
            [
                f"- Participantes: {usabilidade['participants']}",
                f"- Conclusao: {_percentual(usabilidade['completion_rate'])}",
                f"- SUS: {_numero(usabilidade['sus_mean'])}/100",
                f"- CSAT: {_numero(usabilidade['csat_mean'])}/5",
                f"- Tempo medio: {_numero(usabilidade['mean_task_time_s'], 1, ' s')}",
                "",
            ]
        )
    else:
        linhas.extend(
            [
                "Coleta pendente. Use os arquivos de `templates/` com 8 a 12 participantes; o analisador calcula conclusao, tempo, erros, SUS, CSAT e mapas de calor sem dados simulados.",
                "",
            ]
        )

    linhas.extend(
        [
            "## Conclusao provisoria",
            "",
            "Os resultados automatizados permitem avaliar a implementacao atual, mas a conclusao cientifica final exige: tres repeticoes da LLM, execucao de carga no ambiente congelado, navegadores/aparelhos reais e coleta de usabilidade. Os criterios foram definidos antes da coleta e devem permanecer inalterados na rodada definitiva.",
            "",
            "## Arquivos de evidencia",
            "",
        ]
    )
    evidencias = sorted(
        caminho.name
        for caminho in RESULTS_DIR.iterdir()
        if caminho.is_file() and caminho.name != "RELATORIO_VALIDACAO.md"
    )
    linhas.extend(f"- `{nome}`" for nome in evidencias)
    (RESULTS_DIR / "RELATORIO_VALIDACAO.md").write_text(
        "\n".join(linhas) + "\n", encoding="utf-8"
    )
    print(f"Relatorio gerado com {len(graficos)} graficos em {RESULTS_DIR}")


if __name__ == "__main__":
    main()
