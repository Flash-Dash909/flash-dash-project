import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from data_modeling import (
    combine_sources,
    infer_relationships,
    validate_relationships,
)


def _sources():
    return [
        {
            "id": "clientes",
            "nome_arquivo": "clientes.xlsx",
            "dados_brutos": [
                {"id": "001", "cliente": "Alpha", "regiao": "Norte"},
                {"id": "002", "cliente": "Beta", "regiao": "Sul"},
            ],
        },
        {
            "id": "vendas",
            "nome_arquivo": "vendas.csv",
            "dados_brutos": [
                {"customer_id": "001", "faturamento": 100.0},
                {"customer_id": "001", "faturamento": 50.0},
                {"customer_id": "002", "faturamento": 80.0},
            ],
        },
    ]


def test_infers_primary_foreign_key_and_cardinality():
    relationships = infer_relationships(_sources())

    assert len(relationships) == 1
    relationship = relationships[0]
    assert relationship["fonte_origem_id"] == "clientes"
    assert relationship["fonte_destino_id"] == "vendas"
    assert relationship["chave_origem"] == "id"
    assert relationship["chave_destino"] == "customer_id"
    assert relationship["cardinalidade"] == "1:N"
    assert relationship["confianca"] >= 0.8


def test_combines_sources_without_losing_fact_rows():
    result = combine_sources(_sources(), name="Vendas e clientes")

    assert result["status"] == "success"
    assert result["summary"]["total_rows"] == 3
    assert result["summary"]["fonte_tipo"] == "combinacao"
    assert result["summary"]["metricas"] == ["faturamento"]
    assert result["dados_limpos"][0]["cliente"] == "Alpha"
    assert result["modelo_estrela"]["tabela_fato"]["fonte_id"] == "vendas"
    assert len(result["modelo_estrela"]["relacionamentos"]) == 1


def test_rejects_sources_without_compatible_key():
    sources = [
        {"id": "a", "nome_arquivo": "a.csv", "dados_brutos": [{"produto": "A"}]},
        {"id": "b", "nome_arquivo": "b.csv", "dados_brutos": [{"cidade": "X"}]},
    ]

    with pytest.raises(ValueError, match="chave compativel"):
        combine_sources(sources)


def test_infers_one_to_one_relationship():
    sources = [
        {
            "id": "contas",
            "nome_arquivo": "contas.csv",
            "dados_brutos": [{"id": "A1"}, {"id": "A2"}],
        },
        {
            "id": "perfis",
            "nome_arquivo": "perfis.csv",
            "dados_brutos": [
                {"conta_id": "A1", "cidade": "Fortaleza"},
                {"conta_id": "A2", "cidade": "Recife"},
            ],
        },
    ]

    relationships = infer_relationships(sources)

    assert len(relationships) == 1
    assert relationships[0]["cardinalidade"] == "1:1"
    assert relationships[0]["cobertura"] == 1.0


def test_infers_many_to_many_and_creates_bridge_metadata():
    sources = [
        {
            "id": "canais_a",
            "nome_arquivo": "canais_a.csv",
            "dados_brutos": [
                {"campanha_id": "C1", "canal": "Email"},
                {"campanha_id": "C1", "canal": "Social"},
                {"campanha_id": "C2", "canal": "Email"},
            ],
        },
        {
            "id": "publicos",
            "nome_arquivo": "publicos.csv",
            "dados_brutos": [
                {"campanha_id": "C1", "publico": "Ativo"},
                {"campanha_id": "C1", "publico": "Novo"},
                {"campanha_id": "C2", "publico": "Ativo"},
            ],
        },
    ]

    relationships = infer_relationships(sources)
    result = combine_sources(sources)

    assert relationships[0]["cardinalidade"] == "N:N"
    assert len(result["modelo_estrela"]["tabelas_ponte"]) == 1


def test_builds_three_source_star_without_dimension_false_positive():
    sources = [
        {
            "id": "clientes",
            "nome_arquivo": "clientes.csv",
            "dados_brutos": [
                {"id": "C1", "cliente": "Alpha"},
                {"id": "C2", "cliente": "Beta"},
            ],
        },
        {
            "id": "produtos",
            "nome_arquivo": "produtos.csv",
            "dados_brutos": [
                {"id": "P1", "produto": "Notebook"},
                {"id": "P2", "produto": "Mouse"},
            ],
        },
        {
            "id": "vendas",
            "nome_arquivo": "vendas.csv",
            "dados_brutos": [
                {"cliente_id": "C1", "produto_id": "P1", "faturamento": 100},
                {"cliente_id": "C1", "produto_id": "P2", "faturamento": 50},
                {"cliente_id": "C2", "produto_id": "P1", "faturamento": 80},
            ],
        },
    ]

    relationships = infer_relationships(sources)
    result = combine_sources(sources)

    pairs = {
        (item["fonte_origem_id"], item["fonte_destino_id"])
        for item in relationships
    }
    assert pairs == {("clientes", "vendas"), ("produtos", "vendas")}
    assert result["modelo_estrela"]["tabela_fato"]["fonte_id"] == "vendas"
    assert len(result["modelo_estrela"]["tabelas_dimensao"]) == 2
    assert result["summary"]["total_rows"] == 3


def test_does_not_connect_generic_ids_from_different_subjects():
    sources = [
        {
            "id": "clientes",
            "nome_arquivo": "clientes.csv",
            "dados_brutos": [{"id": 1}, {"id": 2}],
        },
        {
            "id": "produtos",
            "nome_arquivo": "produtos.csv",
            "dados_brutos": [{"id": 1}, {"id": 2}],
        },
    ]

    assert infer_relationships(sources) == []


def test_reports_partial_referential_integrity():
    sources = [
        {
            "id": "clientes",
            "nome_arquivo": "clientes.csv",
            "dados_brutos": [{"id": 1}, {"id": 2}],
        },
        {
            "id": "vendas",
            "nome_arquivo": "vendas.csv",
            "dados_brutos": [
                {"cliente_id": "1"},
                {"cliente_id": "1"},
                {"cliente_id": "3"},
            ],
        },
    ]

    relationship = infer_relationships(sources)[0]

    assert relationship["cardinalidade"] == "1:N"
    assert relationship["integridade_referencial"] == 0.5
    assert relationship["avisos"]


def test_normalizes_reversed_manual_one_to_many_relationship():
    sources = _sources()
    manual = [
        {
            "fonte_origem_id": "vendas",
            "fonte_destino_id": "clientes",
            "chave_origem": "customer_id",
            "chave_destino": "id",
            "cardinalidade": "1:N",
            "ativa": True,
        }
    ]

    relationship = validate_relationships(sources, manual)[0]
    result = combine_sources(sources, manual)

    assert relationship["fonte_origem_id"] == "clientes"
    assert relationship["fonte_destino_id"] == "vendas"
    assert result["summary"]["total_rows"] == 3


def test_rejects_manual_relationship_with_invalid_cardinality():
    manual = [
        {
            "fonte_origem_id": "clientes",
            "fonte_destino_id": "vendas",
            "chave_origem": "id",
            "chave_destino": "customer_id",
            "cardinalidade": "N:N",
        }
    ]

    with pytest.raises(ValueError, match="N:N exige repeticoes"):
        validate_relationships(_sources(), manual)
