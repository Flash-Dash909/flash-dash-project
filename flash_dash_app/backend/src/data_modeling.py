import re
import unicodedata
from collections import Counter

import pandas as pd


MAX_COMBINED_ROWS = 250_000
VALID_CARDINALITIES = frozenset({"1:1", "1:N", "N:N"})
UNIQUE_KEY_THRESHOLD = 0.98
MIN_RELATIONSHIP_SCORE = 0.62
MIN_REFERENTIAL_COVERAGE = 0.35


def _normalized_name(value):
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = text.encode("ascii", "ignore").decode().casefold()
    return re.sub(r"[^a-z0-9]+", "_", text).strip("_")


def _table_name(source):
    name = source.get("nome_arquivo") or source.get("nome") or source.get("id")
    base = re.sub(r"\.[^.]+$", "", str(name or "fonte"))
    normalized = _normalized_name(base).upper()
    return re.sub(r"_+", "_", normalized)[:48] or "FONTE"


def _records(source):
    raw = source.get("dados_limpos") or source.get("dados_brutos") or []
    if not isinstance(raw, list):
        raise ValueError(f"A fonte '{source.get('nome_arquivo', 'sem nome')}' nao e tabular.")
    frame = pd.DataFrame(raw)
    if frame.empty:
        raise ValueError(f"A fonte '{source.get('nome_arquivo', 'sem nome')}' nao possui registros.")
    return frame


def _source_id(source, index=0):
    return str(source.get("id") or f"fonte_{index + 1}")


def _value_key(value):
    if value is None or (not isinstance(value, (list, dict)) and pd.isna(value)):
        return None
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        number = float(value)
        return str(int(number)) if number.is_integer() else format(number, ".15g")
    text = unicodedata.normalize("NFKC", str(value)).strip().casefold()
    return re.sub(r"\s+", " ", text) or None


def _column_subject(column, source_name):
    tokens = [token for token in _normalized_name(column).split("_") if token]
    ignored = {"id", "fk", "pk", "key", "codigo", "cod", "chave"}
    meaningful = [token for token in tokens if token not in ignored]
    if meaningful:
        aliases = {"customer": "cliente", "client": "cliente"}
        return "_".join(aliases.get(token, token) for token in meaningful)

    source_base = re.sub(r"\.[^.]+$", "", str(source_name or ""))
    source_tokens = [
        token
        for token in _normalized_name(source_base).split("_")
        if token and token not in {"dim", "fato", "dados", "tabela"}
    ]
    if source_tokens:
        token = source_tokens[-1]
        token = token[:-1] if token.endswith("s") and len(token) > 3 else token
        return {"customer": "cliente", "client": "cliente"}.get(token, token)
    return "id"


def _name_score(left_column, right_column, left_name, right_name):
    left = _normalized_name(left_column)
    right = _normalized_name(right_column)
    left_subject = _column_subject(left_column, left_name)
    right_subject = _column_subject(right_column, right_name)
    if left == right:
        if left in {"id", "codigo", "cod", "key", "chave"}:
            return 0.96 if left_subject == right_subject else 0.0
        return 1.0
    if left_subject == right_subject:
        return 0.92
    if left_subject in right_subject or right_subject in left_subject:
        return 0.72
    return 0.0


def _series_kind(series):
    values = series.dropna()
    if values.empty:
        return "empty"
    if pd.api.types.is_bool_dtype(values.dtype):
        return "boolean"
    if pd.api.types.is_datetime64_any_dtype(values.dtype):
        return "datetime"
    if pd.api.types.is_numeric_dtype(values.dtype):
        return "number"
    return "text"


def _column_profile(series):
    values = [_value_key(value) for value in series.tolist()]
    values = [value for value in values if value is not None]
    distinct = set(values)
    unique_ratio = len(distinct) / max(1, len(values))
    return {
        "values": distinct,
        "unique_ratio": unique_ratio,
        "null_ratio": 1 - (len(values) / max(1, len(series))),
        "kind": _series_kind(series),
    }


def _is_unique(profile):
    return (
        profile["unique_ratio"] >= UNIQUE_KEY_THRESHOLD
        and profile["null_ratio"] <= 0.02
    )


def _type_score(left_profile, right_profile):
    if left_profile["kind"] == right_profile["kind"]:
        return 1.0
    # Identificadores numericos podem chegar como texto em CSV e planilhas.
    if left_profile["values"] & right_profile["values"]:
        return 0.85
    return 0.0


def _candidate(left, right, left_column, right_column):
    left_profile = left["profiles"][left_column]
    right_profile = right["profiles"][right_column]
    left_values = left_profile["values"]
    right_values = right_profile["values"]
    if not left_values or not right_values:
        return None

    name_score = _name_score(
        left_column,
        right_column,
        left["name"],
        right["name"],
    )
    if name_score == 0:
        return None

    intersection = left_values & right_values
    if not intersection:
        return None

    left_coverage = len(intersection) / len(left_values)
    right_coverage = len(intersection) / len(right_values)
    left_is_one = _is_unique(left_profile)
    right_is_one = _is_unique(right_profile)
    if left_is_one and not right_is_one:
        referential_coverage = right_coverage
    elif right_is_one and not left_is_one:
        referential_coverage = left_coverage
    else:
        referential_coverage = min(left_coverage, right_coverage)

    compatibility = _type_score(left_profile, right_profile)
    if compatibility == 0:
        return None

    key_quality = max(
        left_profile["unique_ratio"],
        right_profile["unique_ratio"],
    )
    null_penalty = min(
        0.15,
        (left_profile["null_ratio"] + right_profile["null_ratio"]) * 0.20,
    )
    score = (
        name_score * 0.38
        + referential_coverage * 0.34
        + key_quality * 0.16
        + compatibility * 0.12
        - null_penalty
    )
    return {
        "left_column": str(left_column),
        "right_column": str(right_column),
        "left_profile": left_profile,
        "right_profile": right_profile,
        "left_is_one": left_is_one,
        "right_is_one": right_is_one,
        "score": score,
        "coverage": referential_coverage,
        "left_coverage": left_coverage,
        "right_coverage": right_coverage,
        "type_score": compatibility,
    }


def _relationship_from_candidate(left, right, best):
    if best["left_is_one"] and not best["right_is_one"]:
        origin, destination = left, right
        origin_key, destination_key = best["left_column"], best["right_column"]
        cardinality = "1:N"
        origin_profile = best["left_profile"]
        destination_profile = best["right_profile"]
    elif best["right_is_one"] and not best["left_is_one"]:
        origin, destination = right, left
        origin_key, destination_key = best["right_column"], best["left_column"]
        cardinality = "1:N"
        origin_profile = best["right_profile"]
        destination_profile = best["left_profile"]
    elif best["left_is_one"] and best["right_is_one"]:
        origin, destination = (
            (left, right)
            if len(left["frame"]) <= len(right["frame"])
            else (right, left)
        )
        if origin is left:
            origin_key, destination_key = best["left_column"], best["right_column"]
            origin_profile = best["left_profile"]
            destination_profile = best["right_profile"]
        else:
            origin_key, destination_key = best["right_column"], best["left_column"]
            origin_profile = best["right_profile"]
            destination_profile = best["left_profile"]
        cardinality = "1:1"
    else:
        origin, destination = left, right
        origin_key, destination_key = best["left_column"], best["right_column"]
        cardinality = "N:N"
        origin_profile = best["left_profile"]
        destination_profile = best["right_profile"]

    warnings = []
    if best["coverage"] < 0.90:
        warnings.append("Existem chaves sem correspondencia entre as fontes.")
    if origin_profile["null_ratio"] or destination_profile["null_ratio"]:
        warnings.append("A relacao possui valores nulos nas colunas de chave.")

    return {
        "fonte_origem_id": origin["id"],
        "fonte_destino_id": destination["id"],
        "origem": (
            f"DIM_{origin['table']}" if cardinality != "N:N" else origin["table"]
        ),
        "destino": f"FATO_{destination['table']}",
        "chave_origem": origin_key,
        "chave_destino": destination_key,
        "cardinalidade": cardinality,
        "ativa": True,
        "origem_inferencia": "heuristica",
        "confianca": round(best["score"], 3),
        "cobertura": round(best["coverage"], 3),
        "integridade_referencial": round(best["coverage"], 3),
        "compatibilidade_tipo": round(best["type_score"], 3),
        "avisos": warnings,
    }


def infer_relationships(sources):
    if len(sources) < 2:
        return []

    prepared = []
    for index, source in enumerate(sources):
        frame = _records(source)
        prepared.append(
            {
                "id": _source_id(source, index),
                "name": source.get("nome_arquivo") or source.get("nome") or f"Fonte {index + 1}",
                "table": _table_name(source),
                "frame": frame,
                "profiles": {
                    column: _column_profile(frame[column])
                    for column in frame.columns
                },
            }
        )

    relationships = []
    for left_index in range(len(prepared)):
        for right_index in range(left_index + 1, len(prepared)):
            left = prepared[left_index]
            right = prepared[right_index]
            best = None
            for left_column in left["frame"].columns:
                for right_column in right["frame"].columns:
                    item = _candidate(
                        left,
                        right,
                        left_column,
                        right_column,
                    )
                    if item is not None and (
                        best is None or item["score"] > best["score"]
                    ):
                        best = item

            if (
                best is None
                or best["score"] < MIN_RELATIONSHIP_SCORE
                or best["coverage"] < MIN_REFERENTIAL_COVERAGE
            ):
                continue
            relationships.append(_relationship_from_candidate(left, right, best))
    return relationships


def validate_relationships(sources, relationships):
    prepared = {}
    for index, source in enumerate(sources):
        source_id = _source_id(source, index)
        frame = _records(source)
        prepared[source_id] = {
            "id": source_id,
            "name": source.get("nome_arquivo") or source.get("nome") or source_id,
            "table": _table_name(source),
            "frame": frame,
            "profiles": {
                column: _column_profile(frame[column]) for column in frame.columns
            },
        }

    normalized = []
    seen = set()
    for index, raw in enumerate(relationships or []):
        if not isinstance(raw, dict):
            raise ValueError(f"A relacao {index + 1} possui formato invalido.")
        origin_id = str(raw.get("fonte_origem_id") or "")
        destination_id = str(raw.get("fonte_destino_id") or "")
        if origin_id == destination_id or origin_id not in prepared or destination_id not in prepared:
            raise ValueError(f"A relacao {index + 1} referencia fontes invalidas.")

        origin_key = str(raw.get("chave_origem") or "")
        destination_key = str(raw.get("chave_destino") or "")
        origin = prepared[origin_id]
        destination = prepared[destination_id]
        if origin_key not in origin["frame"].columns:
            raise ValueError(f"A chave '{origin_key}' nao existe na fonte de origem.")
        if destination_key not in destination["frame"].columns:
            raise ValueError(f"A chave '{destination_key}' nao existe na fonte de destino.")

        cardinality = str(raw.get("cardinalidade") or "").upper()
        if cardinality not in VALID_CARDINALITIES:
            raise ValueError(
                f"A cardinalidade '{cardinality}' e invalida. Use 1:1, 1:N ou N:N."
            )

        origin_profile = origin["profiles"][origin_key]
        destination_profile = destination["profiles"][destination_key]
        intersection = origin_profile["values"] & destination_profile["values"]
        if raw.get("ativa", True) and not intersection:
            raise ValueError(
                f"As chaves '{origin_key}' e '{destination_key}' nao possuem valores em comum."
            )

        origin_unique = _is_unique(origin_profile)
        destination_unique = _is_unique(destination_profile)
        if cardinality == "1:N" and not origin_unique and destination_unique:
            origin_id, destination_id = destination_id, origin_id
            origin, destination = destination, origin
            origin_key, destination_key = destination_key, origin_key
            origin_profile, destination_profile = destination_profile, origin_profile
            origin_unique, destination_unique = destination_unique, origin_unique
        if cardinality == "1:N" and not origin_unique:
            raise ValueError("Em uma relacao 1:N, a chave do lado 1 precisa ser unica.")
        if cardinality == "1:1" and not (origin_unique and destination_unique):
            raise ValueError("Uma relacao 1:1 exige chaves unicas nos dois lados.")
        if cardinality == "N:N" and (origin_unique or destination_unique):
            raise ValueError("Uma relacao N:N exige repeticoes de chave nos dois lados.")

        signature = (origin_id, destination_id, origin_key, destination_key)
        if signature in seen:
            continue
        seen.add(signature)
        coverage = (
            len(intersection) / max(1, len(destination_profile["values"]))
            if cardinality == "1:N"
            else min(
                len(intersection) / max(1, len(origin_profile["values"])),
                len(intersection) / max(1, len(destination_profile["values"])),
            )
        )
        normalized.append(
            {
                **raw,
                "fonte_origem_id": origin_id,
                "fonte_destino_id": destination_id,
                "origem": raw.get("origem") or f"DIM_{origin['table']}",
                "destino": raw.get("destino") or f"FATO_{destination['table']}",
                "chave_origem": origin_key,
                "chave_destino": destination_key,
                "cardinalidade": cardinality,
                "ativa": bool(raw.get("ativa", True)),
                "origem_inferencia": raw.get("origem_inferencia", "manual"),
                "cobertura": round(coverage, 3),
                "integridade_referencial": round(coverage, 3),
            }
        )
    return normalized


def _primary_key(frame):
    candidates = []
    for column in frame.columns:
        profile = _column_profile(frame[column])
        if not _is_unique(profile):
            continue
        normalized = _normalized_name(column)
        priority = 0 if normalized in {"id", "codigo", "chave"} or normalized.endswith("_id") else 1
        candidates.append((priority, str(column)))
    return min(candidates)[1] if candidates else None


def _select_fact_source(frames, relationships):
    scores = {}
    for source_id, frame in frames.items():
        measures = [
            column
            for column in frame.select_dtypes(include="number").columns
            if not _normalized_name(column).endswith("id")
        ]
        many_side = sum(
            1
            for item in relationships
            if item.get("cardinalidade") == "1:N"
            and str(item.get("fonte_destino_id")) == source_id
        )
        one_side = sum(
            1
            for item in relationships
            if item.get("cardinalidade") == "1:N"
            and str(item.get("fonte_origem_id")) == source_id
        )
        scores[source_id] = (
            many_side * 100 + len(measures) * 10 - one_side * 5,
            len(frame),
        )
    return max(scores, key=scores.get)


def _estimate_many_to_many(left, right, left_key, right_key):
    left_counts = Counter(_value_key(value) for value in left[left_key].tolist())
    right_counts = Counter(_value_key(value) for value in right[right_key].tolist())
    left_counts.pop(None, None)
    right_counts.pop(None, None)
    return sum(left_counts[key] * right_counts.get(key, 0) for key in left_counts)


def _serialize(frame):
    safe = frame.astype(object).where(pd.notna(frame), None)
    return safe.to_dict(orient="records")


def _chart_data(frame, dimensions, metrics):
    if not dimensions or not metrics:
        return []
    grouped = (
        frame.groupby(dimensions[0], dropna=False)[metrics[0]]
        .sum(min_count=1)
        .fillna(0)
        .sort_values(ascending=False)
        .head(8)
    )
    colors = ["#2563EB", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6"]
    return [
        {"label": str(label), "value": float(value), "color": colors[index % len(colors)]}
        for index, (label, value) in enumerate(grouped.items())
    ]


def combine_sources(sources, relationships=None, name="Modelo combinado"):
    if len(sources) < 2:
        raise ValueError("Selecione pelo menos duas fontes para criar o modelo.")

    frames = {
        _source_id(source, index): _records(source)
        for index, source in enumerate(sources)
    }
    source_by_id = {
        _source_id(source, index): source for index, source in enumerate(sources)
    }
    inferred = infer_relationships(sources)
    active_relationships = (
        inferred
        if relationships is None
        else validate_relationships(sources, relationships)
    )
    active_relationships = [item for item in active_relationships if item.get("ativa", True)]
    if not active_relationships:
        raise ValueError(
            "Nao foi encontrada uma chave compativel entre as fontes. "
            "Use colunas de identificacao com valores em comum."
        )

    fact_id = _select_fact_source(frames, active_relationships)
    combined = frames[fact_id].copy()
    connected = {fact_id}
    pending = set(frames) - connected
    used_relationships = []

    while pending:
        progress = False
        for relationship in active_relationships:
            origin_id = str(relationship.get("fonte_origem_id"))
            destination_id = str(relationship.get("fonte_destino_id"))
            if origin_id in connected and destination_id in pending:
                other_id = destination_id
                combined_key = str(relationship.get("chave_origem"))
                other_key = str(relationship.get("chave_destino"))
            elif destination_id in connected and origin_id in pending:
                other_id = origin_id
                combined_key = str(relationship.get("chave_destino"))
                other_key = str(relationship.get("chave_origem"))
            else:
                continue

            other = frames[other_id].copy()
            if combined_key not in combined.columns or other_key not in other.columns:
                continue

            cardinality = str(relationship.get("cardinalidade", "N:N"))
            if cardinality == "N:N":
                estimate = _estimate_many_to_many(combined, other, combined_key, other_key)
                if estimate > MAX_COMBINED_ROWS:
                    raise ValueError(
                        "A relacao N:N geraria linhas demais. Crie uma tabela ponte "
                        "ou escolha uma chave mais especifica."
                    )

            left_temp = "__flashdash_join_left__"
            right_temp = "__flashdash_join_right__"
            combined[left_temp] = combined[combined_key].map(_value_key)
            other[right_temp] = other[other_key].map(_value_key)
            suffix = f"__{_table_name(source_by_id[other_id]).lower()}"
            combined = combined.merge(
                other,
                how="left",
                left_on=left_temp,
                right_on=right_temp,
                suffixes=("", suffix),
                sort=False,
            ).drop(columns=[left_temp, right_temp], errors="ignore")
            if len(combined) > MAX_COMBINED_ROWS:
                raise ValueError(
                    f"A combinacao excedeu o limite de {MAX_COMBINED_ROWS:,} linhas."
                )
            connected.add(other_id)
            pending.remove(other_id)
            used_relationships.append(relationship)
            progress = True
            break

        if not progress:
            missing = ", ".join(
                source_by_id[source_id].get("nome_arquivo", source_id)
                for source_id in sorted(pending)
            )
            raise ValueError(f"As fontes sem relacionamento nao puderam ser conectadas: {missing}.")

    dimensions = combined.select_dtypes(
        include=["object", "string", "category", "bool", "boolean"]
    ).columns.tolist()
    metrics = combined.select_dtypes(include="number").columns.tolist()
    fact_source = source_by_id[fact_id]
    fact_table = f"FATO_{_table_name(fact_source)}"
    dimension_tables = []
    for source_id, source in source_by_id.items():
        if source_id == fact_id:
            continue
        relationship = next(
            (
                item
                for item in used_relationships
                if source_id
                in {
                    str(item.get("fonte_origem_id")),
                    str(item.get("fonte_destino_id")),
                }
            ),
            None,
        )
        key = None
        if relationship:
            key = (
                relationship.get("chave_origem")
                if str(relationship.get("fonte_origem_id")) == source_id
                else relationship.get("chave_destino")
            )
        dimension_tables.append(
            {
                "nome": f"DIM_{_table_name(source)}",
                "fonte_id": source_id,
                "chave_primaria": key,
                "atributos": list(frames[source_id].columns),
            }
        )

    star_model = {
        "tabela_fato": {
            "nome": fact_table,
            "fonte_id": fact_id,
            "chave_primaria": _primary_key(frames[fact_id]),
            "medidas": metrics,
        },
        "tabelas_dimensao": dimension_tables,
        "tabelas_ponte": [
            {
                "nome": (
                    "PONTE_"
                    f"{_table_name(source_by_id[str(item.get('fonte_origem_id'))])}_"
                    f"{_table_name(source_by_id[str(item.get('fonte_destino_id'))])}"
                ),
                "fonte_origem_id": str(item.get("fonte_origem_id")),
                "fonte_destino_id": str(item.get("fonte_destino_id")),
                "chave_origem": item.get("chave_origem"),
                "chave_destino": item.get("chave_destino"),
            }
            for item in used_relationships
            if item.get("cardinalidade") == "N:N"
        ],
        "relacionamentos": used_relationships,
    }
    records = _serialize(combined)
    summary = {
        "total_rows": len(combined),
        "total_columns": len(combined.columns),
        "original_rows": sum(len(frame) for frame in frames.values()),
        "original_columns": sum(len(frame.columns) for frame in frames.values()),
        "cleaned_columns": list(combined.columns),
        "dimensoes": dimensions,
        "metricas": metrics,
        "colunas_data": [],
        "colunas_booleanas": [],
        "colunas_anonimizadas": [],
        "formato": "Modelo relacional",
        "fonte_tipo": "combinacao",
        "fontes_origem": list(frames),
        "relacionamentos_fontes": used_relationships,
        "modelo_estrela": star_model,
    }
    return {
        "status": "success",
        "summary": summary,
        "etl_logs": [
            {
                "fase": "Modelagem: Relacionamentos",
                "icone": "schema",
                "descricao": (
                    f"{len(sources)} fontes conectadas por {len(used_relationships)} "
                    "relacionamento(s) validado(s)."
                ),
            },
            {
                "fase": "Carga",
                "icone": "check_circle",
                "descricao": f"Modelo '{name}' pronto: {len(combined)} linhas e {len(combined.columns)} colunas.",
            },
        ],
        "modelo_estrela": star_model,
        "chart_data": _chart_data(combined, dimensions, metrics),
        "dados_brutos": records,
        "dados_limpos": records,
    }
