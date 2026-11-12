import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

import db_repository


class _Response:
    def __init__(self, data):
        self.data = data


class _Table:
    def __init__(self, name):
        self.name = name
        self.payload = None

    def insert(self, payload):
        self.payload = payload
        return self

    def update(self, payload):
        self.payload = payload
        return self

    def eq(self, *_args):
        return self

    def execute(self):
        return _Response([{"id": "saved-id", **self.payload}])


class _Client:
    def table(self, name):
        return _Table(name)


def test_save_returns_complete_source_contract(monkeypatch):
    monkeypatch.setattr(db_repository, "supabase_db", _Client())
    result = db_repository.save(
        {
            "summary": {"total_rows": 1},
            "dados_limpos": [{"cliente": "A", "valor": 10}],
            "etl_logs": [],
            "modelo_estrela": {"relacionamentos": []},
        },
        "Insight",
        "dados.csv",
        "user-1",
    )

    assert result["id"] == "saved-id"
    assert result["usuario_id"] == "user-1"
    assert result["dados_limpos"] == [{"cliente": "A", "valor": 10}]
    assert result["summary"]["modelo_estrela"] == {"relacionamentos": []}


def test_save_dashboard_returns_inserted_record(monkeypatch):
    monkeypatch.setattr(db_repository, "supabase_db", _Client())

    result = db_repository.save_dashboard(
        "Executivo",
        [{"tipo": "Cartao KPI"}],
        "user-1",
        [{"name": "Margem", "formula": "[Lucro] / [Receita]"}],
    )

    assert result["id"] == "saved-id"
    assert result["titulo"] == "Executivo"
    assert result["usuario_id"] == "user-1"


def test_save_dashboard_updates_and_preserves_source_ids(monkeypatch):
    monkeypatch.setattr(db_repository, "supabase_db", _Client())

    result = db_repository.save_dashboard(
        "Executivo atualizado",
        [{"tipo": "Grafico de Colunas"}],
        "user-1",
        dashboard_id="dashboard-1",
        fonte_ids=["fonte-a", "fonte-b"],
    )

    assert result["id"] == "saved-id"
    assert result["titulo"] == "Executivo atualizado"
    assert result["fonte_ids"] == ["fonte-a", "fonte-b"]
    assert result["usuario_id"] == "user-1"


def test_update_source_model_preserves_summary_and_user_scope(monkeypatch):
    monkeypatch.setattr(db_repository, "supabase_db", _Client())
    monkeypatch.setattr(
        db_repository,
        "get_fonte",
        lambda fonte_id, usuario_id: {
            "id": fonte_id,
            "usuario_id": usuario_id,
            "summary": {
                "total_rows": 3,
                "modelo_estrela": {"relacionamentos": []},
            },
            "dados_limpos": [{"cliente": "A"}],
        },
    )
    modelo = {
        "relacionamentos": [
            {
                "origem": "DIM_CLIENTE",
                "destino": "FATO_ANALISE",
                "cardinalidade": "1:N",
                "ativa": True,
            }
        ]
    }

    result = db_repository.update_source_model("fonte-1", modelo, "user-1")

    assert result["summary"]["total_rows"] == 3
    assert result["summary"]["modelo_estrela"] == modelo
    assert result["summary"]["modelo_estrela_automatico"] == {
        "relacionamentos": []
    }
    assert result["modelo_estrela"] == modelo
    assert result["dados_limpos"] == [{"cliente": "A"}]
