import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

import recommendation_service


class _Resposta:
    text = """```json
    {"recomendacoes":[
      {"tipo":"line chart","confianca":1.7,"justificativa":"Serie temporal",
       "dimensao":"Data","metricas":["Faturamento","Campo inventado"]},
      {"tipo":"Visual inexistente","confianca":0.8,"dimensao":"Data",
       "metricas":["Faturamento"]}
    ]}
    ```"""


class _Modelos:
    async def generate_content(self, **kwargs):
        assert kwargs["model"] == "gemini-2.5-flash"
        return _Resposta()


class _AsyncClient:
    models = _Modelos()


class _Client:
    aio = _AsyncClient()


def test_recomendacao_restringe_visual_e_colunas(monkeypatch):
    monkeypatch.setattr(recommendation_service, "client", _Client())

    resultado = asyncio.run(
        recommendation_service.recomendar_visuais(
            {
                "dimensoes": ["Data", "Produto"],
                "metricas": ["Faturamento"],
                "colunas_data": ["Data"],
            }
        )
    )

    assert resultado["status"] == "success"
    assert resultado["recomendacoes"] == [
        {
            "tipo": "Grafico de Linha",
            "confianca": 1.0,
            "justificativa": "Serie temporal",
            "dimensao": "Data",
            "metricas": ["Faturamento"],
        }
    ]


def test_recomendacao_informa_chave_ausente(monkeypatch):
    monkeypatch.setattr(recommendation_service, "client", None)

    resultado = asyncio.run(recommendation_service.recomendar_visuais({}))

    assert resultado["status"] == "error"
    assert resultado["recomendacoes"] == []
