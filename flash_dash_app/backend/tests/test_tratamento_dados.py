import io
import json
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from tratamento_dados import limparPlanilha


def test_csv_complexo_detecta_cabecalho_e_normaliza_valores():
    conteudo = (
        "Relatorio de vendas\n"
        "Gerado em 01/09/2026\n"
        "Cliente;Faturamento;Margem\n"
        "Alpha;R$ 1.234,50;25%\n"
        "Alpha;R$ 1.234,50;25%\n"
        "Beta;R$ 900,00;20%\n"
        "Total;R$ 2.134,50;\n"
    ).encode("utf-8")

    resultado = limparPlanilha(conteudo, "relatorio.csv")

    assert resultado["status"] == "success"
    assert resultado["summary"]["linha_cabecalho"] == 2
    assert resultado["summary"]["duplicatas_removidas"] == 1
    assert resultado["dados_limpos"] == [
        {"Cliente": "Alpha", "Faturamento": 1234.5, "Margem": 0.25},
        {"Cliente": "Beta", "Faturamento": 900.0, "Margem": 0.2},
    ]


def test_json_aninhado_encontra_lista_de_registros():
    conteudo = json.dumps(
        {"records": [{"cliente": {"nome": "A"}, "valor": 10}]}
    ).encode("utf-8")

    resultado = limparPlanilha(conteudo, "dados.json")

    assert resultado["status"] == "success"
    assert resultado["dados_limpos"][0]["cliente.nome"] == "A"


def test_excel_seleciona_aba_com_mais_dados():
    buffer = io.BytesIO()
    with pd.ExcelWriter(buffer, engine="openpyxl") as writer:
        pd.DataFrame({"Aviso": ["Capa"]}).to_excel(writer, index=False, sheet_name="Capa")
        pd.DataFrame({"Produto": ["A", "B"], "Valor": [10, 20]}).to_excel(
            writer, index=False, sheet_name="Dados"
        )

    resultado = limparPlanilha(buffer.getvalue(), "dados.xlsx")

    assert resultado["status"] == "success"
    assert resultado["summary"]["aba_selecionada"] == "Dados"
    assert resultado["summary"]["total_rows"] == 2


def test_parquet_e_detectado_pela_assinatura():
    buffer = io.BytesIO()
    pd.DataFrame({"x": [1, 2], "categoria": ["A", "B"]}).to_parquet(
        buffer, index=False
    )

    resultado = limparPlanilha(buffer.getvalue(), "arquivo_sem_extensao")

    assert resultado["status"] == "success"
    assert resultado["summary"]["formato"] == "Parquet"


def test_dados_pessoais_sao_pseudonimizados_preservando_repeticoes():
    conteudo = (
        "Cliente;Email;CPF;Valor\n"
        "Ana;ana@empresa.com;123.456.789-00;100\n"
        "Ana;ana@empresa.com;123.456.789-00;200\n"
        "Bruno;bruno@empresa.com;987.654.321-00;300\n"
    ).encode("utf-8")

    resultado = limparPlanilha(conteudo, "clientes.csv")

    assert resultado["status"] == "success"
    assert set(resultado["summary"]["colunas_anonimizadas"]) == {"Email", "CPF"}
    linhas = resultado["dados_limpos"]
    assert (
        linhas[0]["Email"]
        == linhas[1]["Email"]
        == "contato_0001@dados-protegidos.invalid"
    )
    assert linhas[0]["CPF"] == linhas[1]["CPF"] == "CPF_0001"
    assert linhas[2]["Email"] == "contato_0002@dados-protegidos.invalid"
    assert "ana@empresa.com" not in str(linhas)


def test_booleanos_numeros_por_extenso_e_email_sao_padronizados():
    conteudo = (
        "ativo;produto;estoque_atual;fornecedor_email\n"
        "True;Mouse;35;contato1@fornecedor.com\n"
        "Ativo;Teclado;dez;contato2@fornecedor.com\n"
        "1.0;Monitor;18;contato3@fornecedor.com\n"
        "Inativo;Webcam;zero;contato4@fornecedor.com\n"
    ).encode("utf-8")

    resultado = limparPlanilha(conteudo, "estoque.csv")

    assert resultado["status"] == "success"
    linhas = resultado["dados_limpos"]
    assert [linha["ativo"] for linha in linhas] == [True, True, True, False]
    assert [linha["estoque_atual"] for linha in linhas] == [35, 10, 18, 0]
    assert all(
        linha["fornecedor_email"].endswith("@dados-protegidos.invalid")
        for linha in linhas
    )
    assert resultado["summary"]["colunas_booleanas"] == ["ativo"]


def test_modelo_estrela_liga_dimensoes_a_tabela_fato():
    conteudo = (
        "Data;Produto;Regiao;Faturamento;Quantidade\n"
        "01/01/2026;A;Norte;100;2\n"
        "02/01/2026;B;Sul;200;3\n"
    ).encode("utf-8")

    resultado = limparPlanilha(conteudo, "vendas.csv")

    assert resultado["status"] == "success"
    modelo = resultado["modelo_estrela"]
    assert modelo["tabela_fato"]["nome"] == "FATO_ANALISE"
    assert set(modelo["tabela_fato"]["medidas"]) == {
        "Faturamento",
        "Quantidade",
    }
    assert len(modelo["tabelas_dimensao"]) == len(
        resultado["summary"]["dimensoes"]
    )
    assert all(
        relacao["cardinalidade"] == "1:N"
        for relacao in modelo["relacionamentos"]
    )


def test_identificadores_preservam_zeros_a_esquerda_e_vazios_sao_removidos():
    conteudo = (
        "codigo;produto;valor;vazia\n"
        "001;A;10;\n"
        "002;B;20;\n"
    ).encode("utf-8")

    resultado = limparPlanilha(conteudo, "produtos.csv")

    assert resultado["status"] == "success"
    assert resultado["dados_limpos"][0]["codigo"] == "001"
    assert "vazia" not in resultado["summary"]["cleaned_columns"]


def test_duplicatas_sao_removidas_depois_da_normalizacao():
    conteudo = (
        "Cliente;Valor\n"
        " Alpha ;R$ 1.000,00\n"
        "Alpha;1000,00\n"
    ).encode("utf-8")

    resultado = limparPlanilha(conteudo, "duplicadas.csv")

    assert resultado["status"] == "success"
    assert resultado["summary"]["duplicatas_removidas"] == 1
    assert resultado["summary"]["total_rows"] == 1


def test_tsv_e_csv_utf16_exportado_pelo_excel():
    tsv = "codigo\tproduto\tvalor\n001\tA\t10\n002\tB\t20\n".encode("utf-8")
    resultado_tsv = limparPlanilha(tsv, "produtos.tsv")

    utf16 = "codigo;produto;valor\n001;A;10\n002;B;20\n".encode("utf-16")
    resultado_utf16 = limparPlanilha(utf16, "produtos.csv")

    assert resultado_tsv["status"] == "success"
    assert resultado_tsv["summary"]["formato"] == "TSV"
    assert resultado_utf16["status"] == "success"
    assert resultado_utf16["summary"]["total_rows"] == 2
    assert resultado_utf16["dados_limpos"][0]["codigo"] == "001"


def test_ndjson_e_reconhecido_com_registros_aninhados():
    conteudo = (
        '{"cliente": {"nome": "Alpha"}, "valor": 10}\n'
        '{"cliente": {"nome": "Beta"}, "valor": 20}\n'
    ).encode("utf-8")

    resultado = limparPlanilha(conteudo, "dados.ndjson")

    assert resultado["status"] == "success"
    assert resultado["summary"]["formato"] == "JSON"
    assert resultado["dados_limpos"] == [
        {"cliente.nome": "Alpha", "valor": 10},
        {"cliente.nome": "Beta", "valor": 20},
    ]
