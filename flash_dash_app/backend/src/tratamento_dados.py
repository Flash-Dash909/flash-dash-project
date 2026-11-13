import io
import csv
import json
import re
import unicodedata
from pathlib import Path

import numpy as np
import pandas as pd


MAX_ROWS = 250_000
MAX_COLUMNS = 500
SUPPORTED_EXTENSIONS = {
    "csv",
    "tsv",
    "txt",
    "xlsx",
    "xls",
    "json",
    "ndjson",
    "parquet",
}


def _extensao(nome_arquivo):
    return Path(nome_arquivo or "").suffix.lower().replace(".", "")


def _detectar_extensao(conteudo, nome_arquivo, content_type=""):
    inicio = conteudo[:16]
    texto_inicial = conteudo[:2048].lstrip()

    if inicio.startswith(b"PAR1"):
        return "parquet"
    if inicio.startswith(b"PK\x03\x04"):
        return "xlsx"
    if inicio.startswith(bytes.fromhex("D0CF11E0A1B11AE1")):
        return "xls"
    if texto_inicial.startswith((b"{", b"[")):
        return "json"

    ext = _extensao(nome_arquivo)
    if ext in SUPPORTED_EXTENSIONS:
        return ext

    tipo = (content_type or "").lower()
    if "parquet" in tipo:
        return "parquet"
    if "spreadsheet" in tipo or "excel" in tipo:
        return "xlsx"
    if "json" in tipo:
        return "json"
    if "tab-separated" in tipo:
        return "tsv"
    return "csv"


def _ler_csv_flex(conteudo_arquivo, separador=None):
    ultimo_erro = None
    for encoding in (
        "utf-8-sig",
        "utf-8",
        "utf-16",
        "utf-16-le",
        "utf-16-be",
        "cp1252",
        "latin-1",
    ):
        try:
            texto = conteudo_arquivo.decode(encoding)
            separador_detectado = separador
            if separador_detectado is None:
                linhas = [linha for linha in texto.splitlines()[:40] if linha.strip()]
                amostra = "\n".join(linhas)
                try:
                    separador_detectado = csv.Sniffer().sniff(
                        amostra,
                        delimiters=";,\t|",
                    ).delimiter
                except csv.Error:
                    candidatos = [";", "\t", ",", "|"]
                    pontuacoes = {
                        candidato: (
                            sum(linha.count(candidato) for linha in linhas),
                            sum(linha.count(candidato) > 0 for linha in linhas),
                        )
                        for candidato in candidatos
                    }
                    separador_detectado = max(
                        candidatos,
                        key=lambda candidato: (
                            pontuacoes[candidato][1],
                            pontuacoes[candidato][0],
                        ),
                    )
                    if pontuacoes[separador_detectado][0] == 0:
                        separador_detectado = r"\s+"
            if separador_detectado != r"\s+":
                try:
                    return pd.read_csv(
                        io.StringIO(texto),
                        sep=separador_detectado,
                        header=None,
                        dtype=object,
                        engine="c",
                        keep_default_na=False,
                        na_values=[""],
                    )
                except pd.errors.ParserError:
                    linhas_csv = list(
                        csv.reader(io.StringIO(texto), delimiter=separador_detectado)
                    )
                    largura = max((len(linha) for linha in linhas_csv), default=0)
                    return pd.DataFrame(
                        [linha + [None] * (largura - len(linha)) for linha in linhas_csv]
                    )
            return pd.read_csv(io.StringIO(texto), sep=r"\s+", engine="python", header=None, dtype=object, on_bad_lines="skip")
        except (UnicodeDecodeError, pd.errors.ParserError) as exc:
            ultimo_erro = exc

    raise ValueError(f"Não foi possível interpretar o arquivo delimitado: {ultimo_erro}")


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
        for chave in ("data", "items", "results", "records", "rows", "value"):
            if isinstance(payload.get(chave), list):
                return pd.json_normalize(payload[chave])
        return pd.json_normalize([payload])

    raise ValueError("JSON precisa conter um objeto, uma lista ou linhas NDJSON.")


def _pontuar_tabela(df):
    if df.empty:
        return 0
    preenchidas = int(df.notna().sum().sum())
    return preenchidas + len(df) * max(1, len(df.columns))


def _ler_excel(conteudo_arquivo):
    abas = pd.read_excel(io.BytesIO(conteudo_arquivo), sheet_name=None, header=None)
    abas_validas = {
        nome: tabela
        for nome, tabela in abas.items()
        if not tabela.dropna(how="all").dropna(axis=1, how="all").empty
    }
    if not abas_validas:
        raise ValueError("O arquivo Excel não possui abas com dados.")
    nome_aba, tabela = max(abas_validas.items(), key=lambda item: _pontuar_tabela(item[1]))
    return tabela, nome_aba, list(abas_validas)


def _ler_arquivo(conteudo_arquivo, nome_arquivo, content_type=""):
    ext = _detectar_extensao(conteudo_arquivo, nome_arquivo, content_type)
    metadata = {"extensao_detectada": ext}

    if ext == "csv":
        return _ler_csv_flex(conteudo_arquivo), "CSV", metadata
    if ext == "tsv":
        return _ler_csv_flex(conteudo_arquivo, separador="\t"), "TSV", metadata
    if ext == "txt":
        return _ler_csv_flex(conteudo_arquivo), "TXT delimitado", metadata
    if ext in ("xlsx", "xls"):
        tabela, aba, abas = _ler_excel(conteudo_arquivo)
        metadata.update({"aba_selecionada": aba, "abas_detectadas": abas})
        return tabela, "Excel", metadata
    if ext in ("json", "ndjson"):
        return _json_para_dataframe(conteudo_arquivo), "JSON", metadata
    if ext == "parquet":
        return pd.read_parquet(io.BytesIO(conteudo_arquivo)), "Parquet", metadata

    raise ValueError("Formato de arquivo não suportado.")


def _texto_limpo(valor):
    if pd.isna(valor):
        return ""
    return re.sub(r"\s+", " ", str(valor).replace("\u00a0", " ")).strip()


def _detectar_linha_cabecalho(df_raw):
    melhor_indice = None
    melhor_pontuacao = float("-inf")
    limite = min(30, len(df_raw))

    for indice in range(limite):
        valores = [_texto_limpo(valor) for valor in df_raw.iloc[indice].tolist()]
        preenchidos = [valor for valor in valores if valor]
        if len(preenchidos) < 2:
            continue
        textos = sum(not _parece_numero(valor) for valor in preenchidos)
        proporcao_texto = textos / len(preenchidos)
        if proporcao_texto < 0.5:
            continue
        unicidade = len(set(valor.casefold() for valor in preenchidos)) / len(preenchidos)
        cobertura = len(preenchidos) / max(1, len(valores))
        pontuacao = textos * 2 + unicidade * 3 + cobertura * 4 - indice * 0.08
        if pontuacao > melhor_pontuacao:
            melhor_indice = indice
            melhor_pontuacao = pontuacao

    return melhor_indice


def _parece_numero(valor):
    texto = _texto_limpo(valor)
    if not texto:
        return False
    texto = re.sub(r"[R$€£¥%\s]", "", texto)
    texto = texto.strip("()")
    texto = texto.replace(".", "").replace(",", ".")
    try:
        float(texto)
        return True
    except ValueError:
        return False


def _normalizar_nome_coluna(valor, indice):
    texto = _texto_limpo(valor) or f"coluna_{indice + 1}"
    texto = unicodedata.normalize("NFKC", texto)
    return texto[:120]


def _deduplicar_colunas(colunas):
    contagem = {}
    resultado = []
    for coluna in colunas:
        chave = coluna.casefold()
        contagem[chave] = contagem.get(chave, 0) + 1
        sufixo = contagem[chave]
        resultado.append(coluna if sufixo == 1 else f"{coluna}_{sufixo}")
    return resultado


def _preparar_dataframe(df_raw):
    df_raw = df_raw.dropna(how="all").dropna(axis=1, how="all")
    if df_raw.empty:
        raise ValueError("A fonte enviada não possui linhas válidas.")
    if len(df_raw) > MAX_ROWS:
        raise ValueError(f"A fonte excede o limite de {MAX_ROWS:,} linhas.")
    if len(df_raw.columns) > MAX_COLUMNS:
        raise ValueError(f"A fonte excede o limite de {MAX_COLUMNS} colunas.")

    cabecalho_gerado = isinstance(df_raw.columns, pd.RangeIndex) or all(
        str(coluna).isdigit() for coluna in df_raw.columns
    )
    indice_cabecalho = _detectar_linha_cabecalho(df_raw) if cabecalho_gerado else None

    if indice_cabecalho is not None:
        nomes = df_raw.iloc[indice_cabecalho].tolist()
        if indice_cabecalho > 0:
            anterior = [_texto_limpo(valor) for valor in df_raw.iloc[indice_cabecalho - 1].tolist()]
            if sum(bool(valor) for valor in anterior) >= 2:
                grupos = pd.Series(anterior, dtype="object").replace("", None).ffill().tolist()
                nomes = [
                    (
                        f"{grupo} - {_texto_limpo(nome)}"
                        if grupo
                        and _texto_limpo(nome)
                        and grupo.casefold() != _texto_limpo(nome).casefold()
                        else (_texto_limpo(nome) or grupo)
                    )
                    for grupo, nome in zip(grupos, nomes)
                ]
        df = df_raw.iloc[indice_cabecalho + 1 :].copy()
    elif cabecalho_gerado:
        nomes = [f"coluna_{indice + 1}" for indice in range(len(df_raw.columns))]
        df = df_raw.copy()
    else:
        nomes = list(df_raw.columns)
        df = df_raw.copy()

    colunas = [_normalizar_nome_coluna(nome, idx) for idx, nome in enumerate(nomes)]
    df.columns = _deduplicar_colunas(colunas)
    df = df.dropna(how="all").dropna(axis=1, how="all").reset_index(drop=True)
    return df, indice_cabecalho


def _normalizar_valor(valor):
    if pd.isna(valor):
        return None
    if not isinstance(valor, str):
        return valor

    texto = _texto_limpo(valor)
    if not texto:
        return None
    if texto.casefold() in {
        "n/a",
        "na",
        "n.d.",
        "nd",
        "null",
        "none",
        "nan",
        "sem dado",
        "sem dados",
        "nao informado",
        "não informado",
    }:
        return None
    booleanos = {
        "sim": True,
        "yes": True,
        "verdadeiro": True,
        "true": True,
        "não": False,
        "nao": False,
        "no": False,
        "falso": False,
        "false": False,
    }
    if texto.casefold() in booleanos:
        return booleanos[texto.casefold()]

    negativo = texto.startswith("(") and texto.endswith(")")
    percentual = "%" in texto
    numero = re.sub(r"[R$€£¥%\s]", "", texto).strip("()")
    if not re.fullmatch(r"[+-]?[\d.,]+", numero):
        return texto

    if "," in numero and "." in numero:
        if numero.rfind(",") > numero.rfind("."):
            numero = numero.replace(".", "").replace(",", ".")
        else:
            numero = numero.replace(",", "")
    elif "," in numero:
        if re.fullmatch(r"[+-]?\d{1,3}(,\d{3})+", numero):
            numero = numero.replace(",", "")
        else:
            numero = numero.replace(",", ".")
    elif re.fullmatch(r"[+-]?\d{1,3}(\.\d{3})+", numero):
        numero = numero.replace(".", "")

    try:
        resultado = float(numero)
        if negativo:
            resultado *= -1
        if percentual:
            resultado /= 100
        return resultado
    except ValueError:
        return texto


def _numero_por_extenso(valor):
    if not isinstance(valor, str):
        return None
    texto = (
        unicodedata.normalize("NFKD", valor)
        .encode("ascii", "ignore")
        .decode()
        .casefold()
        .replace("-", " ")
    )
    tokens = [token for token in re.findall(r"[a-z]+", texto) if token != "e"]
    if not tokens:
        return None

    unidades = {
        "zero": 0,
        "um": 1,
        "uma": 1,
        "dois": 2,
        "duas": 2,
        "tres": 3,
        "quatro": 4,
        "cinco": 5,
        "seis": 6,
        "sete": 7,
        "oito": 8,
        "nove": 9,
        "dez": 10,
        "onze": 11,
        "doze": 12,
        "treze": 13,
        "quatorze": 14,
        "catorze": 14,
        "quinze": 15,
        "dezesseis": 16,
        "dezasseis": 16,
        "dezessete": 17,
        "dezoito": 18,
        "dezenove": 19,
        "vinte": 20,
        "trinta": 30,
        "quarenta": 40,
        "cinquenta": 50,
        "sessenta": 60,
        "setenta": 70,
        "oitenta": 80,
        "noventa": 90,
        "cem": 100,
        "cento": 100,
        "duzentos": 200,
        "duzentas": 200,
        "trezentos": 300,
        "trezentas": 300,
        "quatrocentos": 400,
        "quatrocentas": 400,
        "quinhentos": 500,
        "quinhentas": 500,
        "seiscentos": 600,
        "seiscentas": 600,
        "setecentos": 700,
        "setecentas": 700,
        "oitocentos": 800,
        "oitocentas": 800,
        "novecentos": 900,
        "novecentas": 900,
    }
    escalas = {
        "mil": 1_000,
        "milhao": 1_000_000,
        "milhoes": 1_000_000,
    }
    if any(token not in unidades and token not in escalas and token != "menos" for token in tokens):
        return None

    negativo = tokens and tokens[0] == "menos"
    if negativo:
        tokens = tokens[1:]
    atual = 0
    total = 0
    for token in tokens:
        if token in escalas:
            escala = escalas[token]
            parcela = atual or 1
            total += parcela * escala
            atual = 0
        else:
            atual += unidades[token]
    resultado = total + atual
    return -resultado if negativo else resultado


def _normalizar_booleano(valor):
    if valor is None or pd.isna(valor):
        return False, None
    if isinstance(valor, (bool, np.bool_)):
        return True, bool(valor)
    if isinstance(valor, (int, float, np.integer, np.floating)):
        if float(valor) in {0.0, 1.0}:
            return True, bool(int(valor))
        return False, None

    texto = (
        unicodedata.normalize("NFKD", _texto_limpo(valor))
        .encode("ascii", "ignore")
        .decode()
        .casefold()
    )
    positivos = {
        "1",
        "sim",
        "yes",
        "y",
        "verdadeiro",
        "true",
        "ativo",
        "ativa",
        "active",
        "habilitado",
        "habilitada",
        "ligado",
        "ligada",
    }
    negativos = {
        "0",
        "nao",
        "no",
        "n",
        "falso",
        "false",
        "inativo",
        "inativa",
        "inactive",
        "desabilitado",
        "desabilitada",
        "desligado",
        "desligada",
    }
    if re.fullmatch(r"1(?:\.0+)?", texto):
        return True, True
    if re.fullmatch(r"0(?:\.0+)?", texto):
        return True, False
    if texto in positivos:
        return True, True
    if texto in negativos:
        return True, False
    return False, None


def _remover_cabecalhos_repetidos(df):
    if df.empty:
        return df, 0
    nomes = [str(coluna).casefold().strip() for coluna in df.columns]

    def repetido(linha):
        iguais = sum(
            _texto_limpo(valor).casefold() == nomes[indice]
            for indice, valor in enumerate(linha.tolist())
        )
        return iguais >= max(2, int(len(nomes) * 0.6))

    mascara = df.apply(repetido, axis=1)
    return df.loc[~mascara].copy(), int(mascara.sum())


def _remover_totais(df):
    if df.empty:
        return df, 0
    padrao = re.compile(r"^(subtotal|total|total geral|grand total|total geral:)\s*$", re.I)
    candidatas = list(df.columns[: min(3, len(df.columns))])
    mascara = pd.Series(False, index=df.index)
    for coluna in candidatas:
        mascara |= df[coluna].map(lambda valor: bool(padrao.match(_texto_limpo(valor))))
    return df.loc[~mascara].copy(), int(mascara.sum())


def _inferir_tipos(df):
    colunas_data = []
    colunas_booleanas = []
    for coluna in df.columns:
        nome_normalizado = unicodedata.normalize("NFKD", coluna).encode(
            "ascii", "ignore"
        ).decode().casefold()
        identificador = any(
            token in re.split(r"[^a-z0-9]+", nome_normalizado)
            for token in (
                "id",
                "codigo",
                "cod",
                "cpf",
                "cnpj",
                "rg",
                "cep",
                "matricula",
                "telefone",
            )
        )
        serie = (
            df[coluna].map(
                lambda valor: None
                if pd.isna(valor) or _texto_limpo(valor) == ""
                else _texto_limpo(valor)
            )
            if identificador
            else df[coluna].map(_normalizar_valor)
        )
        preenchidos = serie.dropna()
        if preenchidos.empty:
            df[coluna] = serie
            continue

        tokens_nome = set(re.split(r"[^a-z0-9]+", nome_normalizado))
        nome_booleano = bool(
            tokens_nome
            & {
                "ativo",
                "ativa",
                "active",
                "status",
                "habilitado",
                "habilitada",
                "flag",
                "booleano",
            }
        )
        booleanos_reconhecidos = preenchidos.map(_normalizar_booleano)
        taxa_booleana = booleanos_reconhecidos.map(lambda item: item[0]).mean()
        possui_booleano_textual = preenchidos.map(
            lambda valor: isinstance(valor, str)
            and _normalizar_booleano(valor)[0]
            and not re.fullmatch(r"[01](?:\.0+)?", _texto_limpo(valor))
        ).any()
        if taxa_booleana >= 0.9 and (nome_booleano or possui_booleano_textual):
            df[coluna] = serie.map(
                lambda valor: (
                    _normalizar_booleano(valor)[1]
                    if _normalizar_booleano(valor)[0]
                    else None
                )
            ).astype("boolean")
            colunas_booleanas.append(coluna)
            continue

        if preenchidos.map(lambda valor: isinstance(valor, bool)).mean() >= 0.9:
            df[coluna] = serie.astype("boolean")
            colunas_booleanas.append(coluna)
            continue

        def converter_numero_escrito(valor):
            convertido = _numero_por_extenso(valor)
            return valor if convertido is None else convertido

        serie_numerica = serie.map(converter_numero_escrito)
        numerica = pd.to_numeric(serie_numerica, errors="coerce")
        if not identificador and numerica[serie.notna()].notna().mean() >= 0.85:
            df[coluna] = numerica
            continue

        candidata_data = any(
            token in nome_normalizado
            for token in ("data", "date", "mes", "ano", "periodo", "hora", "time")
        )
        amostra_texto = preenchidos.astype(str).head(200)
        possui_separador_data = amostra_texto.str.contains(
            r"\d\s*[-/:]\s*\d|\b(?:jan|fev|feb|mar|abr|apr|mai|may|jun|jul|ago|aug|set|sep|out|oct|nov|dez|dec)\b",
            regex=True,
            case=False,
        ).mean() >= 0.75
        if not identificador and (candidata_data or possui_separador_data):
            convertida = pd.to_datetime(serie, errors="coerce", dayfirst=True)
            limite = 0.75 if candidata_data else 0.9
            if convertida[serie.notna()].notna().mean() >= limite:
                df[coluna] = convertida.map(
                    lambda valor: valor.isoformat() if pd.notna(valor) else None
                )
                colunas_data.append(coluna)
                continue

        df[coluna] = serie.map(lambda valor: _texto_limpo(valor) if valor is not None else None)

    return df, colunas_data, colunas_booleanas


def _preencher_dimensoes_mescladas(df):
    preenchidas = []
    numericas = set(df.select_dtypes(include="number").columns)
    if not numericas:
        return df, preenchidas

    for coluna in list(df.columns[: min(3, len(df.columns))]):
        if coluna in numericas:
            continue
        taxa_nula = df[coluna].isna().mean()
        if 0.05 <= taxa_nula <= 0.7 and df[coluna].notna().sum() >= 2:
            df[coluna] = df[coluna].ffill()
            preenchidas.append(coluna)
    return df, preenchidas


def _nome_normalizado(valor):
    return (
        unicodedata.normalize("NFKD", str(valor))
        .encode("ascii", "ignore")
        .decode()
        .casefold()
        .replace("-", "_")
        .replace(" ", "_")
    )


def _anonimizar_dados_sensiveis(df):
    marcadores = {
        "cpf": "CPF",
        "cnpj": "CNPJ",
        "rg": "RG",
        "email": "EMAIL",
        "e_mail": "EMAIL",
        "telefone": "TELEFONE",
        "celular": "TELEFONE",
        "phone": "TELEFONE",
        "endereco": "ENDERECO",
        "address": "ENDERECO",
        "cep": "CEP",
    }
    anonimizadas = []
    for coluna in df.columns:
        nome = _nome_normalizado(coluna)
        marcador = next(
            (
                prefixo
                for termo, prefixo in marcadores.items()
                if nome == termo or nome.startswith(f"{termo}_") or nome.endswith(f"_{termo}")
            ),
            None,
        )
        if marcador is None:
            continue

        mapa = {}

        def pseudonimo(valor):
            if valor is None or pd.isna(valor) or _texto_limpo(valor) == "":
                return None
            chave = _texto_limpo(valor).casefold()
            if chave not in mapa:
                indice = len(mapa) + 1
                mapa[chave] = (
                    f"contato_{indice:04d}@dados-protegidos.invalid"
                    if marcador == "EMAIL"
                    else f"{marcador}_{indice:04d}"
                )
            return mapa[chave]

        df[coluna] = df[coluna].map(pseudonimo)
        anonimizadas.append(coluna)
    return df, anonimizadas


def _identificador_tabela(valor):
    nome = re.sub(r"[^A-Za-z0-9]+", "_", _nome_normalizado(valor)).strip("_")
    return nome.upper()[:48] or "DIMENSAO"


def _gerar_modelo_estrela(dimensoes, metricas):
    tabelas_dimensao = []
    relacionamentos = []
    chaves_fato = []
    for dimensao in dimensoes:
        identificador = _identificador_tabela(dimensao)
        chave_dimensao = f"ID_{identificador}"
        chave_fato = f"FK_{identificador}"
        tabelas_dimensao.append(
            {
                "nome": f"DIM_{identificador}",
                "chave_primaria": chave_dimensao,
                "atributos": [dimensao],
            }
        )
        chaves_fato.append(chave_fato)
        relacionamentos.append(
            {
                "origem": f"DIM_{identificador}",
                "destino": "FATO_ANALISE",
                "chave_origem": chave_dimensao,
                "chave_destino": chave_fato,
                "cardinalidade": "1:N",
                "ativa": True,
                "origem_inferencia": "heuristica",
            }
        )
    return {
        "tabela_fato": {
            "nome": "FATO_ANALISE",
            "chave_primaria": "ID_FATO",
            "chaves_estrangeiras": chaves_fato,
            "medidas": list(metricas),
        },
        "tabelas_dimensao": tabelas_dimensao,
        "relacionamentos": relacionamentos,
    }


def _serializar_dataframe(df):
    seguro = df.astype(object).where(pd.notna(df), None)
    return seguro.to_dict(orient="records")


def limparPlanilha(
    conteudo_arquivo,
    nome_arquivo,
    fonte_tipo="arquivo",
    content_type="",
):
    try:
        logs_etl = []
        df_raw, formato_detectado, metadata = _ler_arquivo(
            conteudo_arquivo,
            nome_arquivo,
            content_type,
        )
        linhas_brutas = len(df_raw)
        colunas_brutas = len(df_raw.columns)
        nulos_antes = int(df_raw.isna().sum().sum())
        logs_etl.append(
            {
                "fase": "Extração",
                "icone": "upload",
                "descricao": (
                    f"Fonte '{nome_arquivo}' carregada como {formato_detectado}: "
                    f"{linhas_brutas} linhas e {colunas_brutas} colunas."
                ),
            }
        )

        df, linha_cabecalho = _preparar_dataframe(df_raw)
        df, cabecalhos_repetidos = _remover_cabecalhos_repetidos(df)
        df, linhas_total = _remover_totais(df)

        df, colunas_data, colunas_booleanas = _inferir_tipos(df)
        df, colunas_preenchidas = _preencher_dimensoes_mescladas(df)
        df, colunas_anonimizadas = _anonimizar_dados_sensiveis(df)
        antes_duplicadas = len(df)
        df = df.drop_duplicates().reset_index(drop=True)
        duplicadas = antes_duplicadas - len(df)
        df = df.dropna(how="all").reset_index(drop=True)

        logs_etl.append(
            {
                "fase": "Transformação: Estrutura",
                "icone": "cleaning",
                "descricao": (
                    f"Cabeçalho detectado na linha {(linha_cabecalho if linha_cabecalho is not None else 0) + 1}; "
                    f"{cabecalhos_repetidos} cabeçalhos repetidos, {linhas_total} totais "
                    f"e {duplicadas} duplicatas removidos."
                ),
            }
        )
        logs_etl.append(
            {
                "fase": "Transformação: Tipos",
                "icone": "text_format",
                "descricao": (
                    "Moedas, percentuais, números, booleanos e datas foram normalizados. "
                    f"Datas detectadas: {len(colunas_data)}; dimensões preenchidas: "
                    f"{len(colunas_preenchidas)}."
                ),
            }
        )

        colunas_categoricas = df.select_dtypes(
            include=["object", "string", "category", "bool", "boolean"]
        ).columns.tolist()
        colunas_numericas = df.select_dtypes(include="number").columns.tolist()
        modelo_estrela = _gerar_modelo_estrela(
            colunas_categoricas,
            colunas_numericas,
        )
        logs_etl.append(
            {
                "fase": "Transformação: Privacidade",
                "icone": "security",
                "descricao": (
                    f"{len(colunas_anonimizadas)} colunas sensíveis foram "
                    "pseudonimizadas de forma determinística."
                ),
            }
        )
        logs_etl.append(
            {
                "fase": "Modelagem (Schema)",
                "icone": "schema",
                "descricao": (
                    f"Motor detectou {len(colunas_categoricas)} dimensões e "
                    f"{len(colunas_numericas)} métricas."
                ),
            }
        )

        chart_data = []
        if colunas_categoricas and colunas_numericas:
            dimensao = colunas_categoricas[0]
            metrica = colunas_numericas[0]
            agrupado = (
                df.groupby(dimensao, dropna=False)[metrica]
                .sum(min_count=1)
                .fillna(0)
                .sort_values(ascending=False)
                .head(8)
            )
            cores = ["#1E293B", "#748AA1", "#3B82F6", "#10B981", "#F59E0B"]
            chart_data = [
                {
                    "label": str(rotulo),
                    "value": float(valor),
                    "color": cores[indice % len(cores)],
                }
                for indice, (rotulo, valor) in enumerate(agrupado.items())
            ]

        dados_limpos = _serializar_dataframe(df)
        nulos_depois = int(df.isna().sum().sum())
        logs_etl.append(
            {
                "fase": "Carga",
                "icone": "check_circle",
                "descricao": f"Tabela final pronta: {len(df)} linhas e {len(df.columns)} colunas.",
            }
        )

        return {
            "status": "success",
            "summary": {
                "total_rows": len(df),
                "total_columns": len(df.columns),
                "original_rows": linhas_brutas,
                "original_columns": colunas_brutas,
                "cleaned_columns": list(df.columns),
                "dimensoes": colunas_categoricas,
                "metricas": colunas_numericas,
                "colunas_data": colunas_data,
                "colunas_booleanas": colunas_booleanas,
                "colunas_anonimizadas": colunas_anonimizadas,
                "formato": formato_detectado,
                "fonte_tipo": fonte_tipo,
                "linha_cabecalho": linha_cabecalho,
                "linhas_removidas": linhas_brutas - len(df),
                "duplicatas_removidas": duplicadas,
                "nulos_antes": nulos_antes,
                "nulos_depois": nulos_depois,
                **metadata,
            },
            "etl_logs": logs_etl,
            "modelo_estrela": modelo_estrela,
            "chart_data": chart_data,
            "dados_brutos": dados_limpos,
            "dados_limpos": dados_limpos,
        }
    except Exception as exc:
        return {"status": "error", "message": str(exc)}
