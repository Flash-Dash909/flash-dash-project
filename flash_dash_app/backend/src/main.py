import io
import ipaddress
import json
import os
import re
import socket
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse, urlunparse

import httpx
import pandas as pd
from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, StreamingResponse
from pydantic import BaseModel
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import LongTable, PageBreak, Paragraph, SimpleDocTemplate, TableStyle
from starlette.concurrency import run_in_threadpool

from db_repository import delete_dashboard, delete_fonte, get_dashboard, get_dashboards, get_fonte, get_fontes, get_logs_etl, save, save_dashboard, update_source_model
from ia_service import analisar_dados_com_ia, conversar_com_ia
from login import router as login_router
from recommendation_service import recomendar_visuais
from tratamento_dados import limparPlanilha
from auth_service import usuario_autenticado
from data_modeling import (
    VALID_CARDINALITIES,
    combine_sources,
    validate_relationships,
)

MAX_UPLOAD_BYTES = 50 * 1024 * 1024
HEALTH_PAYLOAD = b'{"status":"ok","service":"flash-dash-api","version":"1.0"}'

app = FastAPI(title="Flash Dash API")
app.include_router(login_router, prefix="/auth", tags=["Autenticacao"])
configured_origins = [
    item.strip()
    for item in os.getenv("CORS_ORIGINS", "").split(",")
    if item.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=configured_origins,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


class ChatPayload(BaseModel):
    mensagem: str
    contexto_dashboard: list


class UrlFontePayload(BaseModel):
    url: str
    nome: str | None = None
    fonte_tipo: str = "url"
    usuario_id: str | None = None


class DashboardPayload(BaseModel):
    dashboard_id: str | None = None
    titulo: str
    graficos_config: list
    metricas_calculadas: list | None = None
    fonte_ids: list[str] | None = None
    usuario_id: str | None = None


class RecommendationPayload(BaseModel):
    summary: dict
    amostra: list | None = None
    max_recomendacoes: int = 3


class CombineSourcesPayload(BaseModel):
    fonte_ids: list[str]
    nome: str = "Modelo combinado"
    relacionamentos: list[dict] | None = None


class StarModelPayload(BaseModel):
    modelo_estrela: dict


def _contexto_ia(resultado: dict) -> dict:
    contexto = dict(resultado)
    registros = resultado.get("dados_limpos") or resultado.get("dados_brutos") or []
    contexto["dados_limpos"] = registros[:100]
    contexto["dados_brutos"] = registros[:100]
    contexto["amostra_limitada"] = len(registros) > 100
    return contexto


def _nome_seguro(nome: str, padrao: str = "dados") -> str:
    base = re.sub(r"[^A-Za-z0-9_-]+", "_", Path(nome).stem).strip("_")
    return base or padrao


def _validar_url_publica(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise HTTPException(400, "Informe uma URL HTTP ou HTTPS valida.")
    if parsed.hostname.lower() in {"localhost", "localhost.localdomain"}:
        raise HTTPException(400, "URLs locais nao sao permitidas.")
    try:
        for item in socket.getaddrinfo(parsed.hostname, None):
            ip = ipaddress.ip_address(item[4][0])
            if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved:
                raise HTTPException(400, "A URL precisa apontar para um endereco publico.")
    except socket.gaierror as exc:
        raise HTTPException(400, "Nao foi possivel localizar o endereco informado.") from exc


def _url_download(url: str, fonte_tipo: str) -> str:
    parsed = urlparse(url)
    tipo = fonte_tipo.lower()
    if tipo == "google_sheets":
        match = re.search(r"/spreadsheets/d/([^/]+)", parsed.path)
        if match:
            gid = parse_qs(parsed.query).get("gid", ["0"])[0]
            return f"https://docs.google.com/spreadsheets/d/{match.group(1)}/export?format=csv&gid={gid}"
    if tipo == "google_drive_link":
        match = re.search(r"/file/d/([^/]+)", parsed.path)
        file_id = match.group(1) if match else parse_qs(parsed.query).get("id", [None])[0]
        if file_id:
            return f"https://drive.google.com/uc?export=download&id={file_id}"
    if tipo in {"onedrive_link", "sharepoint_link"}:
        query = parse_qs(parsed.query)
        query["download"] = ["1"]
        return urlunparse(parsed._replace(query=urlencode(query, doseq=True)))
    return url


def _nome_resposta(response: httpx.Response, nome: str | None) -> str:
    if nome and Path(nome).suffix:
        return Path(nome).name
    disposition = response.headers.get("content-disposition", "")
    match = re.search(r"filename\*?=(?:UTF-8''|\")?([^\";]+)", disposition, re.I)
    if match:
        return Path(match.group(1)).name
    candidato = Path(urlparse(str(response.url)).path).name
    if Path(candidato).suffix:
        return candidato
    content_type = response.headers.get("content-type", "").lower()
    extensao = ".xlsx" if "spreadsheet" in content_type or "excel" in content_type else ".json" if "json" in content_type else ".csv"
    return f"{_nome_seguro(nome or 'fonte_remota')}{extensao}"


async def _processar(conteudo: bytes, nome: str, fonte_tipo: str, content_type: str, usuario_id: str | None):
    if len(conteudo) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "O arquivo excede o limite de 50 MB.")
    if not conteudo:
        raise HTTPException(422, "A fonte enviada esta vazia.")
    resultado = await run_in_threadpool(
        limparPlanilha,
        conteudo,
        nome,
        fonte_tipo,
        content_type,
    )
    if resultado.get("status") == "error":
        raise HTTPException(422, resultado.get("message", "Nao foi possivel tratar os dados."))
    insight = await run_in_threadpool(analisar_dados_com_ia, _contexto_ia(resultado))
    fonte = await run_in_threadpool(save, resultado, insight, nome, usuario_id)
    if not fonte:
        raise HTTPException(502, "Os dados foram tratados, mas nao puderam ser salvos.")
    return {"status": "sucesso", "insight_da_ia": insight, "dados_planilha": resultado, "fonte": fonte}


@app.get("/")
async def home():
    return {
        "status": "online",
        "message": "Flash Dash API esta funcionando!",
    }


@app.api_route("/health", methods=["GET", "HEAD"], include_in_schema=False)
async def health():
    return Response(
        content=HEALTH_PAYLOAD,
        media_type="application/json",
        headers={"Cache-Control": "no-store"},
    )


@app.post("/recomendar-visuais")
async def recomendar_visuais_api(
    payload: RecommendationPayload,
    usuario_id: str = Depends(usuario_autenticado),
):
    return await recomendar_visuais(
        payload.summary,
        payload.amostra,
        payload.max_recomendacoes,
    )


@app.post("/chat-ia")
async def chat_com_ia(
    payload: ChatPayload,
    usuario_id: str = Depends(usuario_autenticado),
):
    resposta = await conversar_com_ia(
        payload.mensagem,
        payload.contexto_dashboard,
    )
    return {"status": "success", "resposta": resposta}


@app.post("/analisar-planilha")
async def analisar_rota(
    file: UploadFile = File(...),
    fonte_tipo: str = Form("arquivo"),
    usuario_id: str = Depends(usuario_autenticado),
):
    conteudo = await file.read(MAX_UPLOAD_BYTES + 1)
    return await _processar(conteudo, file.filename or "fonte_sem_nome.csv", fonte_tipo, file.content_type or "", usuario_id)


@app.post("/analisar-url")
async def analisar_url(
    payload: UrlFontePayload,
    usuario_id: str = Depends(usuario_autenticado),
):
    _validar_url_publica(payload.url)
    url = _url_download(payload.url, payload.fonte_tipo)
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=30) as client:
            async with client.stream("GET", url, headers={"User-Agent": "Flash-Dash/1.0"}) as response:
                response.raise_for_status()
                partes, tamanho = [], 0
                async for parte in response.aiter_bytes():
                    tamanho += len(parte)
                    if tamanho > MAX_UPLOAD_BYTES:
                        raise HTTPException(413, "A fonte remota excede o limite de 50 MB.")
                    partes.append(parte)
                conteudo = b"".join(partes)
                nome = _nome_resposta(response, payload.nome)
                content_type = response.headers.get("content-type", "")
    except HTTPException:
        raise
    except httpx.HTTPError as exc:
        raise HTTPException(400, f"Nao foi possivel baixar a fonte: {exc}") from exc
    return await _processar(conteudo, nome, payload.fonte_tipo, content_type, usuario_id)


@app.get("/fontes-dados")
async def listar_fontes_api(usuario_id: str = Depends(usuario_autenticado)):
    return await run_in_threadpool(get_fontes, usuario_id)


@app.get("/fontes-dados/{fonte_id}")
async def buscar_fonte_api(fonte_id: str, usuario_id: str = Depends(usuario_autenticado)):
    fonte = await run_in_threadpool(get_fonte, fonte_id, usuario_id)
    if not fonte:
        raise HTTPException(404, "Fonte nao encontrada.")
    return fonte


@app.put("/fontes-dados/{fonte_id}/modelo")
async def atualizar_modelo_fonte_api(
    fonte_id: str,
    payload: StarModelPayload,
    usuario_id: str = Depends(usuario_autenticado),
):
    modelo = dict(payload.modelo_estrela)
    relacionamentos = modelo.get("relacionamentos")
    if not isinstance(relacionamentos, list):
        raise HTTPException(422, "O modelo precisa conter uma lista de relacionamentos.")

    fonte_atual = await run_in_threadpool(get_fonte, fonte_id, usuario_id)
    if not fonte_atual:
        raise HTTPException(404, "Fonte nao encontrada.")
    summary = fonte_atual.get("summary") or {}
    fontes_origem = (
        summary.get("fontes_origem", []) if isinstance(summary, dict) else []
    )

    try:
        if len(fontes_origem) >= 2:
            if not relacionamentos:
                raise ValueError(
                    "Um modelo com varias fontes precisa manter ao menos uma relacao."
                )
            fontes = []
            for origem_id in fontes_origem:
                origem = await run_in_threadpool(
                    get_fonte,
                    str(origem_id),
                    usuario_id,
                )
                if not origem:
                    raise ValueError(
                        f"A fonte de origem '{origem_id}' nao esta mais disponivel."
                    )
                fontes.append(origem)
            relacionamentos = await run_in_threadpool(
                validate_relationships,
                fontes,
                relacionamentos,
            )
            if not any(item.get("ativa", True) for item in relacionamentos):
                raise ValueError("Mantenha ao menos uma relacao ativa no modelo.")
        else:
            for index, item in enumerate(relacionamentos):
                if not isinstance(item, dict):
                    raise ValueError(
                        f"A relacao {index + 1} possui formato invalido."
                    )
                cardinalidade = str(item.get("cardinalidade") or "").upper()
                if cardinalidade not in VALID_CARDINALITIES:
                    raise ValueError(
                        "Use apenas cardinalidades 1:1, 1:N ou N:N."
                    )
                if not all(
                    str(item.get(field) or "").strip()
                    for field in (
                        "origem",
                        "destino",
                        "chave_origem",
                        "chave_destino",
                    )
                ):
                    raise ValueError(
                        f"Preencha as tabelas e chaves da relacao {index + 1}."
                    )
        modelo["relacionamentos"] = relacionamentos
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc

    fonte = await run_in_threadpool(
        update_source_model,
        fonte_id,
        modelo,
        usuario_id,
    )
    if not fonte:
        raise HTTPException(404, "Fonte nao encontrada ou modelo nao atualizado.")
    return {"status": "success", "fonte": fonte}


@app.delete("/fontes-dados/{fonte_id}")
async def excluir_fonte_api(fonte_id: str, usuario_id: str = Depends(usuario_autenticado)):
    if not await run_in_threadpool(delete_fonte, fonte_id, usuario_id):
        raise HTTPException(500, "Nao foi possivel excluir a fonte.")
    return {"status": "success"}


@app.post("/fontes-dados/combinar")
async def combinar_fontes_api(
    payload: CombineSourcesPayload,
    usuario_id: str = Depends(usuario_autenticado),
):
    ids = list(dict.fromkeys(str(item) for item in payload.fonte_ids if str(item).strip()))
    if len(ids) < 2:
        raise HTTPException(400, "Selecione pelo menos duas fontes diferentes.")
    if len(ids) > 8:
        raise HTTPException(400, "Combine no maximo oito fontes por modelo.")

    fontes = []
    for fonte_id in ids:
        fonte = await run_in_threadpool(get_fonte, fonte_id, usuario_id)
        if not fonte:
            raise HTTPException(404, f"Fonte '{fonte_id}' nao encontrada.")
        fontes.append(fonte)

    try:
        resultado = await run_in_threadpool(
            combine_sources,
            fontes,
            payload.relacionamentos,
            payload.nome.strip() or "Modelo combinado",
        )
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc

    insight = await run_in_threadpool(analisar_dados_com_ia, _contexto_ia(resultado))
    fonte = await run_in_threadpool(
        save,
        resultado,
        insight,
        f"{payload.nome.strip() or 'Modelo combinado'}.modelo",
        usuario_id,
    )
    if not fonte:
        raise HTTPException(502, "O modelo foi criado, mas nao pode ser salvo.")
    return {
        "status": "sucesso",
        "insight_da_ia": insight,
        "dados_planilha": resultado,
        "fonte": fonte,
    }


def _dataframe_fonte(fonte: dict) -> pd.DataFrame:
    registros = fonte.get("dados_limpos") or fonte.get("dados_brutos") or []
    if not isinstance(registros, list):
        raise HTTPException(422, "Esta fonte nao possui registros tabulares.")
    return pd.DataFrame(registros)


def _formatar_planilhas_excel(writer: pd.ExcelWriter) -> None:
    """Aplica um formato legivel sem percorrer todo o arquivo exportado."""
    header_fill = PatternFill("solid", fgColor="2563EB")
    header_font = Font(color="FFFFFF", bold=True)

    for worksheet in writer.book.worksheets:
        worksheet.freeze_panes = "A2"
        worksheet.sheet_view.showGridLines = False
        worksheet.auto_filter.ref = worksheet.dimensions
        worksheet.row_dimensions[1].height = 24
        worksheet.sheet_properties.pageSetUpPr.fitToPage = True
        worksheet.page_setup.orientation = "landscape"
        worksheet.page_setup.fitToWidth = 1
        worksheet.page_setup.fitToHeight = 0

        for cell in worksheet[1]:
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center")

        sample_limit = min(worksheet.max_row, 201)
        for column_index in range(1, worksheet.max_column + 1):
            values = (
                worksheet.cell(row=row_index, column=column_index).value
                for row_index in range(1, sample_limit + 1)
            )
            width = max((len(str(value)) for value in values if value is not None), default=8)
            worksheet.column_dimensions[get_column_letter(column_index)].width = min(
                max(width + 2, 10),
                45,
            )


def _pdf_tabela(df: pd.DataFrame, titulo: str) -> bytes:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=landscape(A4), leftMargin=8 * mm, rightMargin=8 * mm, topMargin=10 * mm, bottomMargin=10 * mm)
    styles = getSampleStyleSheet()
    max_rows = 5000
    visible = df.head(max_rows).fillna("")
    story = [Paragraph(titulo, styles["Title"])]
    if len(df) > max_rows:
        story.append(
            Paragraph(
                f"O PDF exibe as primeiras {max_rows} de {len(df)} linhas. "
                "Use a exportacao Excel para obter o conjunto completo.",
                styles["BodyText"],
            )
        )
    columns = list(df.columns)
    for start in range(0, len(columns), 10):
        group = columns[start : start + 10]
        if start:
            story.append(PageBreak())
        if len(columns) > 10:
            story.append(
                Paragraph(
                    f"Colunas {start + 1} a {start + len(group)} de {len(columns)}",
                    styles["Heading2"],
                )
            )
        rows = [
            [str(value)[:80] for value in row]
            for row in visible[group].itertuples(index=False, name=None)
        ]
        table = LongTable([group, *rows], repeatRows=1)
        table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2563EB")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 6),
            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#CBD5E1")),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FAFC")]),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ]))
        story.append(table)
    doc.build(story)
    return buffer.getvalue()


@app.get("/fontes-dados/{fonte_id}/exportar")
def exportar_fonte_api(fonte_id: str, formato: str = "csv", usuario_id: str = Depends(usuario_autenticado)):
    fonte = get_fonte(fonte_id, usuario_id)
    if not fonte:
        raise HTTPException(404, "Fonte nao encontrada.")
    df = _dataframe_fonte(fonte)
    formato = formato.lower()
    buffer = io.BytesIO()
    media_type = "application/octet-stream"
    if formato == "csv":
        buffer.write(df.to_csv(index=False).encode("utf-8-sig"))
        media_type = "text/csv"
    elif formato in {"xlsx", "excel"}:
        with pd.ExcelWriter(buffer, engine="openpyxl") as writer:
            df.to_excel(writer, index=False, sheet_name="Dados tratados")
            _formatar_planilhas_excel(writer)
        formato = "xlsx"
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    elif formato == "json":
        buffer.write(df.to_json(orient="records", force_ascii=False, indent=2).encode("utf-8"))
        media_type = "application/json"
    elif formato == "parquet":
        df.to_parquet(buffer, index=False)
    elif formato == "pdf":
        buffer.write(_pdf_tabela(df, fonte.get("nome_arquivo", "Dados tratados")))
        media_type = "application/pdf"
    else:
        raise HTTPException(400, "Formato suportado: csv, xlsx, json, parquet ou pdf.")
    buffer.seek(0)
    nome = f"{_nome_seguro(fonte.get('nome_arquivo', 'dados'))}_tratado.{formato}"
    return StreamingResponse(buffer, media_type=media_type, headers={"Content-Disposition": f'attachment; filename="{nome}"'})


@app.post("/salvar-dashboard")
async def salvar_dashboard_api(
    payload: DashboardPayload,
    usuario_id: str = Depends(usuario_autenticado),
):
    dashboard = await run_in_threadpool(
        save_dashboard,
        payload.titulo,
        payload.graficos_config,
        usuario_id,
        payload.metricas_calculadas or [],
        payload.dashboard_id,
        payload.fonte_ids or [],
    )
    if not dashboard:
        raise HTTPException(502, "Falha ao comunicar com o banco.")
    return {
        "status": "success",
        "message": "Dashboard salvo na nuvem!",
        "dashboard": dashboard,
    }


@app.get("/listar-dashboards")
async def listar_dashboards_api(usuario_id: str = Depends(usuario_autenticado)):
    return await run_in_threadpool(get_dashboards, usuario_id)


@app.delete("/dashboards/{dashboard_id}")
async def excluir_dashboard_api(
    dashboard_id: str,
    usuario_id: str = Depends(usuario_autenticado),
):
    if not await run_in_threadpool(delete_dashboard, dashboard_id, usuario_id):
        raise HTTPException(500, "Falha ao excluir dashboard.")
    return {"status": "success", "message": "Dashboard excluido com sucesso!"}


@app.get("/dashboards/{dashboard_id}/exportar")
def exportar_dashboard_api(dashboard_id: str, formato: str = "xlsx", usuario_id: str = Depends(usuario_autenticado)):
    dashboard = get_dashboard(dashboard_id, usuario_id)
    if not dashboard:
        raise HTTPException(404, "Dashboard nao encontrado.")
    formato = formato.lower()
    if formato == "json":
        conteudo = json.dumps(dashboard, ensure_ascii=False, indent=2, default=str).encode("utf-8")
        media_type = "application/json"
    elif formato in {"xlsx", "excel"}:
        buffer, usados = io.BytesIO(), set()
        with pd.ExcelWriter(buffer, engine="openpyxl") as writer:
            for indice, visual in enumerate(dashboard.get("graficos_config") or []):
                dados = visual.get("dados") or visual.get("chartData") or []
                if not isinstance(dados, list) or not dados:
                    continue
                nome = _nome_seguro(str(visual.get("titulo") or f"Visual {indice + 1}"))[:31] or f"Visual {indice + 1}"
                original, contador = nome, 2
                while nome in usados:
                    sufixo = f"_{contador}"
                    nome = f"{original[:31-len(sufixo)]}{sufixo}"
                    contador += 1
                usados.add(nome)
                pd.DataFrame(dados).to_excel(writer, index=False, sheet_name=nome)
            if not usados:
                pd.DataFrame([{"Dashboard": dashboard.get("titulo", "Flash Dash")}]).to_excel(writer, index=False, sheet_name="Resumo")
            _formatar_planilhas_excel(writer)
        conteudo, formato = buffer.getvalue(), "xlsx"
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    else:
        raise HTTPException(400, "Formato suportado: xlsx ou json.")
    nome = f"{_nome_seguro(dashboard.get('titulo', 'dashboard'))}.{formato}"
    return StreamingResponse(io.BytesIO(conteudo), media_type=media_type, headers={"Content-Disposition": f'attachment; filename="{nome}"'})


@app.get("/listar-logs-etl")
async def listar_logs_etl_api(usuario_id: str = Depends(usuario_autenticado)):
    return await run_in_threadpool(get_logs_etl, usuario_id)
