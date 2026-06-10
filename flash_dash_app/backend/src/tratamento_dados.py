import io
import json
from pathlib import Path

import pandas as pd


def _extensao(nome_arquivo):
    return Path(nome_arquivo or "").suffix.lower().replace(".", "")


def _ler_csv_flex(conteudo_arquivo, separador=None):
    for encoding in ("utf-8", "utf-8-sig", "latin-1"):
        try:
            return pd.read_csv(
                io.BytesIO(conteudo_arquivo),
                sep=separador,
                engine="python",
                encoding=encoding,
                header=None,
            )
        except UnicodeDecodeError:
            continue

    return pd.read_csv(
        io.BytesIO(conteudo_arquivo),
        sep=separador,
        engine="python",
        encoding="latin-1",
        header=None,
    )


def _json_para_dataframe(conteudo_arquivo):
    texto = conteudo_arquivo.decode("utf-8-sig")
    try:
        payload = json.loads(texto)
    except json.JSONDecodeError:
        linhas = [json.loads(linha) for linha in texto.splitlines() if linha.strip()]
        return pd.json_normalize(linhas)

    if isinstance(payload, list):
        return pd.json_normalize(payload)
    if isinstance(payload, dict):
        for chave in ("data", "items", "results", "records"):
            if isinstance(payload.get(chave), list):
                return pd.json_normalize(payload[chave])
        return pd.json_normalize([payload])

    raise ValueError("JSON precisa conter um objeto, lista ou linhas NDJSON.")


def _ler_arquivo(conteudo_arquivo, nome_arquivo):
    ext = _extensao(nome_arquivo)

    if ext == "csv":
        return _ler_csv_flex(conteudo_arquivo, separador=None), "CSV"
    if ext == "tsv":
        return _ler_csv_flex(conteudo_arquivo, separador="\t"), "TSV"
    if ext == "txt":
        return _ler_csv_flex(conteudo_arquivo, separador=None), "TXT delimitado"
    if ext in ("xlsx", "xls"):
        return pd.read_excel(io.BytesIO(conteudo_arquivo), header=None), "Excel"
    if ext in ("json", "ndjson"):
        return _json_para_dataframe(conteudo_arquivo), "JSON"
    if ext == "parquet":
        return pd.read_parquet(io.BytesIO(conteudo_arquivo)), "Parquet"

    raise ValueError(
        "Formato nao suportado. Use CSV, TSV, TXT, XLSX, XLS, JSON, NDJSON ou Parquet."
    )


def _tem_cabecalho_gerado(colunas):
    return all(str(coluna).isdigit() for coluna in colunas)


def _preparar_dataframe(df_raw):
    df_raw = df_raw.dropna(how="all")
    if df_raw.empty:
        raise ValueError("A fonte enviada nao possui linhas validas.")

    if _tem_cabecalho_gerado(df_raw.columns):
        primeira_linha_valida_idx = df_raw.index[0]
        novos_nomes_colunas = df_raw.loc[primeira_linha_valida_idx].fillna("")
        df = df_raw.loc[primeira_linha_valida_idx + 1 :].copy()
        df.columns = novos_nomes_colunas
    else:
        df = df_raw.copy()

    df.columns = [
        str(coluna).strip() if str(coluna).strip() else f"coluna_{idx + 1}"
        for idx, coluna in enumerate(df.columns)
    ]
    return df


def _normalizar_valor(valor):
    if not isinstance(valor, str):
        return valor

    texto = valor.strip()
    if not texto:
        return texto

    texto_num = (
        texto.replace("R$", "")
        .replace("%", "")
        .replace(" ", "")
        .strip()
    )

    if "," in texto_num and "." in texto_num:
        texto_num = texto_num.replace(".", "").replace(",", ".")
    elif "," in texto_num and texto_num.count(",") == 1:
        texto_num = texto_num.replace(",", ".")

    try:
        return float(texto_num)
    except ValueError:
        return texto


def limparPlanilha(conteudo_arquivo, nome_arquivo, fonte_tipo="arquivo"):
    try:
        logs_etl = []
        df_raw, formato_detectado = _ler_arquivo(conteudo_arquivo, nome_arquivo)

        linhas_brutas = len(df_raw)
        logs_etl.append({
            "fase": "Extracao",
            "icone": "upload",
            "descricao": (
                f"Fonte '{nome_arquivo}' carregada como {formato_detectado}. "
                f"Total de linhas brutas: {linhas_brutas}."
            ),
        })

        df = _preparar_dataframe(df_raw)

        tamanho_antes_limpeza = len(df)
        df = df.dropna(how="all").reset_index(drop=True)
        linhas_removidas_nulas = tamanho_antes_limpeza - len(df)

        if linhas_removidas_nulas > 0:
            logs_etl.append({
                "fase": "Transformacao: Limpeza",
                "icone": "cleaning",
                "descricao": f"{linhas_removidas_nulas} linhas completamente vazias foram removidas.",
            })

        tamanho_antes_total = len(df)
        if not df.empty:
            primeira_coluna = df.columns[0]
            df = df[
                ~df[primeira_coluna].astype(str).str.lower().str.contains("total", na=False)
            ]
        linhas_removidas_total = tamanho_antes_total - len(df)

        if linhas_removidas_total > 0:
            logs_etl.append({
                "fase": "Transformacao: Filtragem",
                "icone": "cleaning",
                "descricao": (
                    f"{linhas_removidas_total} linhas de subtotal/total foram ignoradas "
                    "para evitar duplicacao."
                ),
            })

        df = df.map(_normalizar_valor)
        for coluna in df.columns:
            original = df[coluna]
            valores_preenchidos = original.notna() & original.astype(str).str.strip().ne("")
            convertida = pd.to_numeric(original, errors="coerce")

            if valores_preenchidos.any():
                taxa_convertida = convertida[valores_preenchidos].notna().mean()
                if taxa_convertida >= 0.8:
                    df[coluna] = convertida

        logs_etl.append({
            "fase": "Transformacao: Padronizacao",
            "icone": "text_format",
            "descricao": "Textos, moedas, percentuais e numeros foram padronizados para analise.",
        })

        colunas_categoricas = df.select_dtypes(include=["object", "string", "category"]).columns.tolist()
        colunas_numericas = df.select_dtypes(include=["float64", "int64", "int32", "float32"]).columns.tolist()

        logs_etl.append({
            "fase": "Modelagem (Schema)",
            "icone": "schema",
            "descricao": (
                f"Motor detectou {len(colunas_categoricas)} dimensoes e "
                f"{len(colunas_numericas)} metricas."
            ),
        })

        chart_data = []
        if colunas_categoricas and colunas_numericas:
            dimensao = colunas_categoricas[0]
            metrica = colunas_numericas[0]

            df_grouped = df.groupby(dimensao, dropna=False)[metrica].sum().reset_index()
            df_grouped = df_grouped.sort_values(by=metrica, ascending=False).head(5)

            cores = ["#1E293B", "#748AA1", "#3B82F6", "#10B981", "#F59E0B"]

            for idx, (_, row) in enumerate(df_grouped.iterrows()):
                chart_data.append({
                    "label": str(row[dimensao]),
                    "value": float(row[metrica]),
                    "color": cores[idx % len(cores)],
                })

        logs_etl.append({
            "fase": "Load (Carga)",
            "icone": "check_circle",
            "descricao": f"Tabela final pronta para consumo. Linhas validas retidas: {len(df)}.",
        })

        return {
            "status": "success",
            "summary": {
                "total_rows": len(df),
                "cleaned_columns": list(df.columns),
                "dimensoes": colunas_categoricas,
                "metricas": colunas_numericas,
                "formato": formato_detectado,
                "fonte_tipo": fonte_tipo,
            },
            "etl_logs": logs_etl,
            "chart_data": chart_data,
            "dados_brutos": df.fillna("").to_dict(orient="records"),
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}
