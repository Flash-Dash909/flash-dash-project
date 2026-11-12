import csv
import json
import statistics
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


VALIDATION_DIR = Path(__file__).resolve().parent
RESULTS_DIR = VALIDATION_DIR / "results"
RESPONSES_PATH = VALIDATION_DIR / "templates" / "usability_responses.csv"
HEATMAP_PATH = VALIDATION_DIR / "templates" / "heatmap_events.csv"


def _numero(valor, padrao=None):
    try:
        return float(str(valor).replace(",", "."))
    except (TypeError, ValueError):
        return padrao


def _booleano(valor):
    return str(valor).strip().casefold() in {"1", "true", "sim", "yes", "y"}


def _sus(linha):
    respostas = [_numero(linha.get(f"sus_q{indice}")) for indice in range(1, 11)]
    if any(valor is None or not 1 <= valor <= 5 for valor in respostas):
        return None
    contribuicoes = []
    for indice, valor in enumerate(respostas, start=1):
        contribuicoes.append(valor - 1 if indice % 2 else 5 - valor)
    return sum(contribuicoes) * 2.5


def _gerar_heatmaps():
    if not HEATMAP_PATH.exists():
        return []
    with HEATMAP_PATH.open(encoding="utf-8-sig") as arquivo:
        eventos = [linha for linha in csv.DictReader(arquivo) if linha.get("screen")]
    if not eventos:
        return []
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return []

    por_tela = defaultdict(list)
    for evento in eventos:
        largura = _numero(evento.get("viewport_width"))
        altura = _numero(evento.get("viewport_height"))
        x = _numero(evento.get("x"))
        y = _numero(evento.get("y"))
        if largura and altura and x is not None and y is not None:
            por_tela[evento["screen"]].append((x / largura, y / altura))
    arquivos = []
    for tela, pontos in por_tela.items():
        if not pontos:
            continue
        figura, eixo = plt.subplots(figsize=(8, 5))
        xs, ys = zip(*pontos)
        eixo.hexbin(xs, ys, gridsize=24, cmap="inferno", mincnt=1)
        eixo.set_xlim(0, 1)
        eixo.set_ylim(1, 0)
        eixo.set_title(f"Mapa de cliques - {tela}")
        eixo.set_xlabel("Posicao horizontal normalizada")
        eixo.set_ylabel("Posicao vertical normalizada")
        nome = "heatmap_" + "".join(
            caractere if caractere.isalnum() else "_" for caractere in tela.casefold()
        )
        caminho = RESULTS_DIR / f"{nome}.png"
        figura.tight_layout()
        figura.savefig(caminho, dpi=160)
        plt.close(figura)
        arquivos.append(caminho.name)
    return arquivos


def main():
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    with RESPONSES_PATH.open(encoding="utf-8-sig") as arquivo:
        linhas = [linha for linha in csv.DictReader(arquivo) if linha.get("participant_id")]
    if not linhas:
        resultado = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "status": "pending",
            "message": "Nenhuma resposta real de participante foi registrada.",
            "participants": 0,
            "heatmaps": _gerar_heatmaps(),
        }
        (RESULTS_DIR / "usability_metrics.json").write_text(
            json.dumps(resultado, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        print(resultado["message"])
        return

    participantes = sorted({linha["participant_id"] for linha in linhas})
    sucesso = sum(_booleano(linha.get("success")) for linha in linhas)
    tempos = [_numero(linha.get("time_s")) for linha in linhas]
    tempos = [valor for valor in tempos if valor is not None]
    erros = [_numero(linha.get("errors"), 0) for linha in linhas]

    sus_por_participante = {}
    csat_por_participante = defaultdict(list)
    for linha in linhas:
        participante = linha["participant_id"]
        valor_sus = _sus(linha)
        if valor_sus is not None:
            sus_por_participante[participante] = valor_sus
        valor_csat = _numero(linha.get("csat_1_5"))
        if valor_csat is not None:
            csat_por_participante[participante].append(valor_csat)

    metricas_tarefa = []
    for tarefa in sorted({linha["task_id"] for linha in linhas}):
        grupo = [linha for linha in linhas if linha["task_id"] == tarefa]
        duracoes = [_numero(linha.get("time_s")) for linha in grupo]
        duracoes = [valor for valor in duracoes if valor is not None]
        metricas_tarefa.append(
            {
                "task_id": tarefa,
                "attempts": len(grupo),
                "completion_rate": sum(_booleano(linha.get("success")) for linha in grupo) / len(grupo),
                "mean_time_s": statistics.mean(duracoes) if duracoes else None,
                "median_time_s": statistics.median(duracoes) if duracoes else None,
                "mean_errors": statistics.mean(_numero(linha.get("errors"), 0) for linha in grupo),
            }
        )
    with (RESULTS_DIR / "usability_by_task.csv").open(
        "w", newline="", encoding="utf-8-sig"
    ) as arquivo:
        writer = csv.DictWriter(arquivo, fieldnames=metricas_tarefa[0].keys())
        writer.writeheader()
        writer.writerows(metricas_tarefa)

    csat_medias = [statistics.mean(valores) for valores in csat_por_participante.values()]
    resultado = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "status": "complete",
        "participants": len(participantes),
        "task_attempts": len(linhas),
        "completion_rate": sucesso / len(linhas),
        "mean_task_time_s": statistics.mean(tempos) if tempos else None,
        "median_task_time_s": statistics.median(tempos) if tempos else None,
        "mean_errors": statistics.mean(erros) if erros else None,
        "sus_mean": statistics.mean(sus_por_participante.values()) if sus_por_participante else None,
        "sus_responses": len(sus_por_participante),
        "csat_mean": statistics.mean(csat_medias) if csat_medias else None,
        "csat_responses": len(csat_medias),
        "heatmaps": _gerar_heatmaps(),
    }
    (RESULTS_DIR / "usability_metrics.json").write_text(
        json.dumps(resultado, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(json.dumps(resultado, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
