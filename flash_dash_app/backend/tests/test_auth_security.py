import sys
from pathlib import Path

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

import auth_service
import main


def test_token_assinado_identifica_usuario(monkeypatch):
    monkeypatch.setenv("APP_SECRET", "segredo-de-teste-com-tamanho-suficiente")

    token = auth_service.criar_token("usuario-a")

    assert auth_service.verificar_token(token) == "usuario-a"


def test_token_adulterado_e_rejeitado(monkeypatch):
    monkeypatch.setenv("APP_SECRET", "segredo-de-teste-com-tamanho-suficiente")
    token = auth_service.criar_token("usuario-a")
    corpo, assinatura = token.split(".", 1)
    token_adulterado = f"{corpo}.{assinatura[:-1]}x"

    with pytest.raises(HTTPException) as erro:
        auth_service.verificar_token(token_adulterado)

    assert erro.value.status_code == 401


def test_header_bearer_e_obrigatorio():
    with pytest.raises(HTTPException) as erro:
        auth_service.usuario_autenticado(None)

    assert erro.value.status_code == 401


def test_logs_exigem_sessao_e_usam_usuario_do_token(monkeypatch):
    monkeypatch.setenv("APP_SECRET", "segredo-de-teste-com-tamanho-suficiente")
    usuarios_consultados = []

    def buscar_logs(usuario_id):
        usuarios_consultados.append(usuario_id)
        return [{"usuario_id": usuario_id}]

    monkeypatch.setattr(main, "get_logs_etl", buscar_logs)
    client = TestClient(main.app)

    sem_sessao = client.get("/listar-logs-etl")
    assert sem_sessao.status_code == 401

    token = auth_service.criar_token("usuario-logado")
    resposta = client.get(
        "/listar-logs-etl?usuario_id=outra-conta",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert resposta.status_code == 200
    assert resposta.json() == [{"usuario_id": "usuario-logado"}]
    assert usuarios_consultados == ["usuario-logado"]


def test_modelo_manual_e_validado_e_normalizado_antes_de_salvar(monkeypatch):
    monkeypatch.setenv("APP_SECRET", "segredo-de-teste-com-tamanho-suficiente")
    fontes = {
        "combinada": {
            "id": "combinada",
            "summary": {"fontes_origem": ["clientes", "vendas"]},
        },
        "clientes": {
            "id": "clientes",
            "nome_arquivo": "clientes.csv",
            "dados_brutos": [{"id": "C1"}, {"id": "C2"}],
        },
        "vendas": {
            "id": "vendas",
            "nome_arquivo": "vendas.csv",
            "dados_brutos": [
                {"cliente_id": "C1", "valor": 10},
                {"cliente_id": "C1", "valor": 20},
                {"cliente_id": "C2", "valor": 30},
            ],
        },
    }
    saved = {}

    def buscar_fonte(fonte_id, usuario_id):
        assert usuario_id == "usuario-modelo"
        return fontes.get(fonte_id)

    def salvar_modelo(fonte_id, modelo, usuario_id):
        saved["modelo"] = modelo
        return {"id": fonte_id, "modelo_estrela": modelo}

    monkeypatch.setattr(main, "get_fonte", buscar_fonte)
    monkeypatch.setattr(main, "update_source_model", salvar_modelo)
    token = auth_service.criar_token("usuario-modelo")
    client = TestClient(main.app)
    payload = {
        "modelo_estrela": {
            "relacionamentos": [
                {
                    "fonte_origem_id": "vendas",
                    "fonte_destino_id": "clientes",
                    "origem": "FATO_VENDAS",
                    "destino": "DIM_CLIENTES",
                    "chave_origem": "cliente_id",
                    "chave_destino": "id",
                    "cardinalidade": "1:N",
                    "ativa": True,
                }
            ]
        }
    }

    response = client.put(
        "/fontes-dados/combinada/modelo",
        headers={"Authorization": f"Bearer {token}"},
        json=payload,
    )

    assert response.status_code == 200
    relationship = saved["modelo"]["relacionamentos"][0]
    assert relationship["fonte_origem_id"] == "clientes"
    assert relationship["fonte_destino_id"] == "vendas"
    assert relationship["chave_origem"] == "id"
    assert relationship["chave_destino"] == "cliente_id"


def test_modelo_manual_invalido_nao_e_salvo(monkeypatch):
    monkeypatch.setenv("APP_SECRET", "segredo-de-teste-com-tamanho-suficiente")
    fontes = {
        "combinada": {
            "id": "combinada",
            "summary": {"fontes_origem": ["clientes", "vendas"]},
        },
        "clientes": {
            "id": "clientes",
            "nome_arquivo": "clientes.csv",
            "dados_brutos": [{"id": "C1"}, {"id": "C2"}],
        },
        "vendas": {
            "id": "vendas",
            "nome_arquivo": "vendas.csv",
            "dados_brutos": [
                {"cliente_id": "C1"},
                {"cliente_id": "C1"},
            ],
        },
    }

    monkeypatch.setattr(
        main,
        "get_fonte",
        lambda fonte_id, usuario_id: fontes.get(fonte_id),
    )
    monkeypatch.setattr(
        main,
        "update_source_model",
        lambda *_: pytest.fail("Um modelo invalido nao pode ser salvo."),
    )
    token = auth_service.criar_token("usuario-modelo")
    client = TestClient(main.app)

    response = client.put(
        "/fontes-dados/combinada/modelo",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "modelo_estrela": {
                "relacionamentos": [
                    {
                        "fonte_origem_id": "clientes",
                        "fonte_destino_id": "vendas",
                        "origem": "DIM_CLIENTES",
                        "destino": "FATO_VENDAS",
                        "chave_origem": "id",
                        "chave_destino": "cliente_id",
                        "cardinalidade": "N:N",
                        "ativa": True,
                    }
                ]
            }
        },
    )

    assert response.status_code == 422
    assert "N:N exige repeticoes" in response.json()["detail"]
