import asyncio
import json
import re
import unicodedata

from ia_service import client


VISUAIS_PERMITIDOS = (
    "Tabela",
    "Matriz",
    "Cartao KPI",
    "Segmentacao",
    "Grafico de Barras",
    "Grafico de Colunas",
    "Barras Empilhadas",
    "Colunas Empilhadas",
    "Barras 100%",
    "Colunas 100%",
    "Ribbon Chart",
    "Grafico de Linha",
    "Grafico de Area",
    "Area Empilhada",
    "Area 100%",
    "Combo Linha + Coluna",
    "Dispersao",
    "Histograma",
    "Box Plot",
    "Heatmap",
    "Grafico de Pizza",
    "Grafico de Rosca",
    "Treemap",
    "Waterfall",
    "Funnel",
    "Gauge",
    "Bullet Chart",
    "Progress Bar",
    "Azure Maps",
    "Mapa Basico",
    "Mapa Preenchido",
    "Shape Map",
    "Mapa de Calor",
    "Sunburst",
    "Decomposition Tree",
    "Principais Influenciadores",
    "Narrativa Inteligente",
    "Deteccao de Anomalias",
    "Radar",
    "Sankey",
    "Network Graph",
    "Timeline/Gantt",
)


def _normalizar(valor):
    texto = unicodedata.normalize("NFKD", str(valor or ""))
    texto = texto.encode("ascii", "ignore").decode().casefold()
    return re.sub(r"[^a-z0-9]+", " ", texto).strip()


_VISUAIS_NORMALIZADOS = {_normalizar(nome): nome for nome in VISUAIS_PERMITIDOS}
_ALIASES = {
    "card": "Cartao KPI",
    "kpi": "Cartao KPI",
    "line chart": "Grafico de Linha",
    "bar chart": "Grafico de Barras",
    "column chart": "Grafico de Colunas",
    "scatter plot": "Dispersao",
    "pie chart": "Grafico de Pizza",
    "donut chart": "Grafico de Rosca",
    "funnel chart": "Funnel",
    "waterfall chart": "Waterfall",
    "gantt": "Timeline/Gantt",
    "choropleth": "Mapa Preenchido",
    "pivot table": "Matriz",
}


def _extrair_json(texto):
    bruto = str(texto or "").strip()
    bruto = re.sub(r"^```(?:json)?\s*", "", bruto, flags=re.I)
    bruto = re.sub(r"\s*```$", "", bruto)
    try:
        return json.loads(bruto)
    except json.JSONDecodeError:
        inicio_objeto, fim_objeto = bruto.find("{"), bruto.rfind("}")
        if inicio_objeto >= 0 and fim_objeto > inicio_objeto:
            return json.loads(bruto[inicio_objeto : fim_objeto + 1])
        inicio_lista, fim_lista = bruto.find("["), bruto.rfind("]")
        if inicio_lista >= 0 and fim_lista > inicio_lista:
            return json.loads(bruto[inicio_lista : fim_lista + 1])
        raise


def _campo_valido(valor, permitidos):
    indice = {_normalizar(item): item for item in permitidos}
    return indice.get(_normalizar(valor))


def _tipo_valido(valor):
    normalizado = _normalizar(valor)
    return _VISUAIS_NORMALIZADOS.get(normalizado) or _ALIASES.get(normalizado)


async def recomendar_visuais(summary, amostra=None, max_recomendacoes=3):
    if client is None:
        return {
            "status": "error",
            "fonte": "gemini",
            "message": "GEMINI_API_KEY nao configurada.",
            "recomendacoes": [],
        }

    dimensoes = [str(item) for item in summary.get("dimensoes", [])]
    metricas = [str(item) for item in summary.get("metricas", [])]
    colunas_data = [str(item) for item in summary.get("colunas_data", [])]
    limite = max(1, min(int(max_recomendacoes), 5))
    contexto = {
        "dimensoes": dimensoes,
        "metricas": metricas,
        "colunas_data": colunas_data,
        "amostra": list(amostra or [])[:8],
    }
    catalogo = list(VISUAIS_PERMITIDOS)
    prompt = f"""
Voce e a camada de recomendacao de Business Intelligence do Flash Dash.
Analise somente os metadados fornecidos e recomende ate {limite} visuais.

CATALOGO PERMITIDO (copie o nome exatamente):
{json.dumps(catalogo, ensure_ascii=False)}

DADOS DISPONIVEIS:
{json.dumps(contexto, ensure_ascii=False, default=str)}

Responda somente com JSON valido neste formato:
{{"recomendacoes":[{{"tipo":"nome do catalogo","confianca":0.0,
"justificativa":"frase curta","dimensao":"coluna existente",
"metricas":["coluna existente"]}}]}}
Nao crie colunas, nao use Markdown e nao retorne visuais fora do catalogo.
"""

    try:
        resposta = await asyncio.wait_for(
            client.aio.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
            ),
            timeout=40,
        )
        payload = _extrair_json(resposta.text)
        itens = payload if isinstance(payload, list) else payload.get("recomendacoes", [])
        recomendacoes = []
        tipos_usados = set()
        for item in itens:
            if not isinstance(item, dict):
                continue
            tipo = _tipo_valido(item.get("tipo"))
            dimensao = _campo_valido(item.get("dimensao"), dimensoes)
            metricas_validas = []
            for metrica in item.get("metricas", []):
                valida = _campo_valido(metrica, metricas)
                if valida and valida not in metricas_validas:
                    metricas_validas.append(valida)
            if not tipo or tipo in tipos_usados:
                continue
            confianca = item.get("confianca", 0)
            try:
                confianca = max(0.0, min(float(confianca), 1.0))
            except (TypeError, ValueError):
                confianca = 0.0
            recomendacoes.append(
                {
                    "tipo": tipo,
                    "confianca": confianca,
                    "justificativa": str(item.get("justificativa", "")).strip(),
                    "dimensao": dimensao,
                    "metricas": metricas_validas,
                }
            )
            tipos_usados.add(tipo)
            if len(recomendacoes) >= limite:
                break
        if not recomendacoes:
            raise ValueError("A IA nao retornou nenhum visual valido.")
        return {
            "status": "success",
            "fonte": "gemini",
            "recomendacoes": recomendacoes,
        }
    except asyncio.TimeoutError:
        return {
            "status": "error",
            "fonte": "gemini",
            "message": "A recomendacao excedeu o limite de 40 segundos.",
            "recomendacoes": [],
        }
    except Exception as exc:
        detalhe = str(exc)
        tipo_erro = (
            "quota"
            if "RESOURCE_EXHAUSTED" in detalhe or "429" in detalhe
            else "provider"
        )
        return {
            "status": "error",
            "fonte": "gemini",
            "error_type": tipo_erro,
            "message": (
                "A cota temporaria do Gemini foi atingida. Tente novamente mais tarde."
                if tipo_erro == "quota"
                else "O Gemini nao conseguiu gerar recomendacoes neste momento."
            ),
            "recomendacoes": [],
        }
