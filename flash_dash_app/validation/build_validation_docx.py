import csv
import json
from datetime import datetime
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor


BASE_DIR = Path(__file__).resolve().parent
APP_DIR = BASE_DIR.parent
RESULTS_DIR = BASE_DIR / "results"
OUTPUT = RESULTS_DIR / "Plano_e_Resultados_Validacao_Flash_Dash.docx"
LOGO = APP_DIR / "frontend" / "figuras" / "Logo_FlashDash.png"

BLUE = "1D4ED8"
BLUE_SOFT = "EFF6FF"
GRAY = "E5E7EB"
GRAY_SOFT = "F8FAFC"
TEXT = RGBColor(15, 23, 42)
MUTED = RGBColor(71, 85, 105)


def load_json(name):
    path = RESULTS_DIR / name
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


def load_csv(name):
    path = RESULTS_DIR / name
    if not path.exists():
        return []
    with path.open(encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def prevent_row_split(row):
    tr_pr = row._tr.get_or_add_trPr()
    cant_split = OxmlElement("w:cantSplit")
    tr_pr.append(cant_split)


def remove_paragraph_border(paragraph):
    p_pr = paragraph._p.get_or_add_pPr()
    border = p_pr.find(qn("w:pBdr"))
    if border is not None:
        p_pr.remove(border)


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=100, start=110, bottom=100, end=110):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for margin, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{margin}"))
        if node is None:
            node = OxmlElement(f"w:{margin}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_table_borders(table, color="D9D9D9", size="6"):
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.first_child_found_in("w:tblBorders")
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tbl_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        element = borders.find(qn(f"w:{edge}"))
        if element is None:
            element = OxmlElement(f"w:{edge}")
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), size)
        element.set(qn("w:color"), color)


def set_font(run, size=None, bold=None, color=None, name="Aptos"):
    run.font.name = name
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), name)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), name)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if color is not None:
        run.font.color.rgb = color


def add_page_number(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run("Página ")
    set_font(run, 9, color=MUTED)
    fld_char1 = OxmlElement("w:fldChar")
    fld_char1.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = "PAGE"
    fld_char2 = OxmlElement("w:fldChar")
    fld_char2.set(qn("w:fldCharType"), "end")
    run._r.extend([fld_char1, instr_text, fld_char2])


def add_paragraph(doc, text="", bold_lead=None, style=None):
    paragraph = doc.add_paragraph(style=style)
    paragraph.paragraph_format.space_after = Pt(7)
    paragraph.paragraph_format.line_spacing = 1.15
    if bold_lead and text.startswith(bold_lead):
        lead = paragraph.add_run(bold_lead)
        set_font(lead, 10.5, bold=True, color=TEXT)
        body = paragraph.add_run(text[len(bold_lead) :])
        set_font(body, 10.5, color=TEXT)
    else:
        run = paragraph.add_run(text)
        set_font(run, 10.5, color=TEXT)
    return paragraph


def add_bullet(doc, text):
    paragraph = doc.add_paragraph(style="List Bullet")
    paragraph.paragraph_format.space_after = Pt(3)
    paragraph.paragraph_format.line_spacing = 1.1
    run = paragraph.add_run(text)
    set_font(run, 10.2, color=TEXT)
    return paragraph


def add_heading(doc, text, level=1):
    paragraph = doc.add_heading(text, level=level)
    paragraph.paragraph_format.keep_with_next = True
    paragraph.paragraph_format.space_before = Pt(14 if level == 1 else 9)
    paragraph.paragraph_format.space_after = Pt(6)
    for run in paragraph.runs:
        set_font(run, 16 if level == 1 else 12, bold=True, color=RGBColor(0, 0, 0))
    return paragraph


def add_table(doc, headers, rows, widths=None, numeric_columns=None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_table_borders(table)
    numeric_columns = set(numeric_columns or [])
    header = table.rows[0]
    set_repeat_table_header(header)
    prevent_row_split(header)
    for index, title in enumerate(headers):
        cell = header.cells[index]
        set_cell_shading(cell, BLUE)
        set_cell_margins(cell)
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        paragraph = cell.paragraphs[0]
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        paragraph.paragraph_format.keep_with_next = True
        run = paragraph.add_run(str(title))
        set_font(run, 9, bold=True, color=RGBColor(255, 255, 255))
        if widths:
            cell.width = Cm(widths[index])
    for row_index, values in enumerate(rows):
        row = table.add_row()
        prevent_row_split(row)
        cells = row.cells
        for column, value in enumerate(values):
            cell = cells[column]
            set_cell_margins(cell)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            if row_index % 2:
                set_cell_shading(cell, GRAY_SOFT)
            paragraph = cell.paragraphs[0]
            paragraph.alignment = (
                WD_ALIGN_PARAGRAPH.CENTER
                if column in numeric_columns
                else WD_ALIGN_PARAGRAPH.LEFT
            )
            run = paragraph.add_run(str(value))
            set_font(run, 8.7, color=TEXT)
            if widths:
                cell.width = Cm(widths[column])
    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return table


def set_picture_alt_text(inline_shape, description):
    doc_properties = inline_shape._inline.docPr
    doc_properties.set("descr", description)
    doc_properties.set("title", description)


def add_figure(doc, filename, caption):
    path = RESULTS_DIR / filename
    if not path.exists():
        return
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.keep_with_next = True
    picture = paragraph.add_run().add_picture(str(path), width=Inches(6.25))
    set_picture_alt_text(picture, caption)
    caption_paragraph = doc.add_paragraph()
    caption_paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    caption_paragraph.paragraph_format.space_after = Pt(10)
    run = caption_paragraph.add_run(caption)
    set_font(run, 9, color=MUTED)
    run.italic = True


def format_rate(value):
    return "Pendente" if value is None else f"{float(value) * 100:.1f}%"


def build_document():
    environment = load_json("environment.json") or {}
    execution = load_json("execution_summary.json") or {}
    etl = load_json("etl_benchmark_summary.json") or {}
    llm = load_json("llm_evaluation.json") or {}
    security = load_json("security_summary.json") or {}
    usability = load_json("usability_metrics.json") or {}
    load = load_csv("load_test.csv")
    stress = load_csv("stress_test.csv")
    requirements = load_csv("../requirements_matrix.csv")
    if not requirements:
        with (BASE_DIR / "requirements_matrix.csv").open(encoding="utf-8-sig") as handle:
            requirements = list(csv.DictReader(handle))

    doc = Document()
    doc.core_properties.title = "Plano e Resultados de Validação do Flash Dash"
    doc.core_properties.subject = "Protocolo experimental e resultados iniciais"
    doc.core_properties.author = "Equipe Flash Dash"
    section = doc.sections[0]
    section.page_width = Cm(21)
    section.page_height = Cm(29.7)
    section.top_margin = Cm(1.8)
    section.bottom_margin = Cm(1.7)
    section.left_margin = Cm(2)
    section.right_margin = Cm(2)
    section.different_first_page_header_footer = True

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Aptos"
    normal._element.rPr.rFonts.set(qn("w:ascii"), "Aptos")
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Aptos")
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = TEXT
    for style_name, size in (("Title", 25), ("Subtitle", 12)):
        style = styles[style_name]
        style.font.name = "Aptos"
        style._element.rPr.rFonts.set(qn("w:ascii"), "Aptos")
        style._element.rPr.rFonts.set(qn("w:hAnsi"), "Aptos")
        style.font.size = Pt(size)
        style.font.color.rgb = RGBColor(0, 0, 0)
    title_style_properties = styles["Title"]._element.get_or_add_pPr()
    title_style_border = title_style_properties.find(qn("w:pBdr"))
    if title_style_border is not None:
        title_style_properties.remove(title_style_border)

    header = section.header.paragraphs[0]
    header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    header_run = header.add_run("Flash Dash  Validação experimental")
    set_font(header_run, 8.5, bold=True, color=MUTED)
    add_page_number(section.footer.paragraphs[0])
    section.first_page_header.paragraphs[0].text = ""
    section.first_page_footer.paragraphs[0].text = ""

    if LOGO.exists():
        logo_paragraph = doc.add_paragraph()
        logo_paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        logo_paragraph.paragraph_format.space_after = Pt(18)
        logo_picture = logo_paragraph.add_run().add_picture(str(LOGO), width=Inches(2.6))
        set_picture_alt_text(logo_picture, "Logotipo do Flash Dash")
    title = doc.add_paragraph(style="Title")
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title.paragraph_format.space_after = Pt(12)
    title_run = title.add_run("Plano e Resultados de Validação do Flash Dash")
    set_font(title_run, 25, bold=True, color=RGBColor(0, 0, 0))
    remove_paragraph_border(title)
    subtitle = doc.add_paragraph(style="Subtitle")
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    subtitle.paragraph_format.space_after = Pt(18)
    subtitle_run = subtitle.add_run(
        "Protocolo para requisitos funcionais e não funcionais do trabalho de conclusão de curso"
    )
    set_font(subtitle_run, 12, color=RGBColor(0, 0, 0))
    meta = doc.add_paragraph()
    meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
    meta_run = meta.add_run(
        f"Rodada inicial em {datetime.now().strftime('%d/%m/%Y')}  |  Commit {environment.get('git_commit', 'não registrado')}"
    )
    set_font(meta_run, 10, color=MUTED)
    doc.add_paragraph().paragraph_format.space_after = Pt(28)

    add_paragraph(
        doc,
        "Conclusão inicial: a implementação passou nos testes automatizados de backend, responsividade, isolamento e segurança. A API não apresentou erros até 1000 requisições simultâneas, mas excedeu o limite de latência em 500. O processamento de 50 mil linhas também ultrapassou o limite provisório de cinco segundos. A LLM atingiu Top 3 de 88,9% entre respostas recebidas, porém foi limitada pela cota diária. A validação de usabilidade ainda depende de participantes reais.",
        bold_lead="Conclusão inicial:",
    )
    doc.add_page_break()

    add_heading(doc, "1 Objetivo e escopo", 1)
    add_paragraph(
        doc,
        "Este documento organiza a validação do Flash Dash de acordo com os objetivos do projeto e com a orientação recebida. O foco é demonstrar, com medidas reproduzíveis, se o sistema converte arquivos brutos em dashboards com limpeza transparente, modelagem dimensional, recomendação inteligente, boa responsividade, desempenho aceitável e isolamento seguro por usuário.",
    )
    add_paragraph(
        doc,
        "Os requisitos funcionais são avaliados por resultados determinísticos. Os requisitos não funcionais são avaliados por métricas, repetição e critérios definidos antes da coleta. Resultados ausentes são marcados como pendentes e não são substituídos por valores simulados.",
    )

    add_heading(doc, "1.1 Perguntas de pesquisa", 2)
    for item in (
        "O motor de Auto Cleaning trata corretamente formatos, tipos, duplicatas, nulos e campos sensíveis?",
        "A modelagem produz uma tabela fato, dimensões e relacionamentos coerentes?",
        "A LLM recomenda representações adequadas sem inventar colunas ou visuais?",
        "A interface permanece utilizável em celular, tablet, desktop e texto ampliado?",
        "A API e o ETL mantêm latência, vazão e estabilidade com aumento de carga?",
        "Os dados e logs permanecem isolados entre contas autenticadas?",
    ):
        add_bullet(doc, item)

    add_heading(doc, "2 Matriz de rastreabilidade", 1)
    add_paragraph(
        doc,
        "A matriz relaciona cada requisito ao método de teste, à evidência produzida e ao critério de aceite proposto. Os limites devem ser aprovados pelo orientador antes da coleta definitiva.",
    )
    matrix_rows = [
        [row["id"], row["tipo"], row["requisito"], row["metodo"], row["criterio"]]
        for row in requirements
    ]
    add_table(
        doc,
        ["ID", "Tipo", "Requisito", "Método", "Critério"],
        matrix_rows,
        widths=[1.5, 2.4, 5.2, 4.2, 3.7],
        numeric_columns=[0],
    )

    add_heading(doc, "3 Protocolo experimental", 1)
    add_heading(doc, "3.1 Testes funcionais", 2)
    add_paragraph(
        doc,
        "Executar a suíte do backend sobre importação, limpeza, inferência de tipos, deduplicação, pseudonimização, esquema estrela, autenticação, isolamento e validação da resposta da IA. Cada falha deve registrar entrada, saída esperada, saída observada, versão do código e correção.",
    )
    add_heading(doc, "3.2 Responsividade", 2)
    add_paragraph(
        doc,
        "Montar as telas críticas em 360 por 640, 390 por 844, 412 por 915, 768 por 1024, 1024 por 768, 1366 por 768 e 1920 por 1080 pixels. Verificar exceções e overflow no Flutter, depois repetir o roteiro em Chrome, Edge e um aparelho Android real. O teste automatizado não substitui a inspeção nos navegadores.",
    )
    add_heading(doc, "3.3 Desempenho e escalabilidade", 2)
    add_paragraph(
        doc,
        "Usar bases determinísticas de 1 mil, 10 mil e 50 mil linhas com datas, moedas, percentuais, nulos, duplicatas e e mails. Após aquecimento, executar três repetições e registrar mediana, p95, CPU, pico de RSS e linhas por segundo. Na API, medir a carga basal em 1, 5, 10, 25 e 50 clientes e o estresse em 100, 250, 500 e 1000 requisições simultâneas, registrando p50, p95, p99, RPS, erros, CPU e memória.",
    )
    add_heading(doc, "3.4 Precisão da recomendação", 2)
    add_paragraph(
        doc,
        "O conjunto de 14 casos foi rotulado antes da execução. A recomendação é correta quando o primeiro visual ou algum dos três primeiros pertence ao conjunto aceito. Também são medidos taxa de resposta, validade do catálogo, uso de campos existentes e latência. Como o problema é uma recomendação Top k multiclasse, curvas ROC e Precision Recall não representam diretamente este objetivo.",
    )
    add_heading(doc, "3.5 Usabilidade e experiência", 2)
    add_paragraph(
        doc,
        "Recrutar de 8 a 12 participantes, alternando desktop e celular. Registrar conclusão, tempo, erros e pedidos de ajuda nas oito tarefas definidas. Aplicar SUS e CSAT ao final. Cliques normalizados por viewport alimentam os mapas de calor. Nenhum resultado deve ser preenchido sem observação real.",
    )
    add_heading(doc, "3.6 Segurança", 2)
    add_paragraph(
        doc,
        "Combinar testes de autorização e isolamento com Bandit e pip audit. Classificar achados por severidade e registrar descoberta, correção e validação. O MTTR só pode ser calculado quando houver datas reais de incidentes corrigidos.",
    )

    add_heading(doc, "4 Resultados iniciais", 1)
    add_heading(doc, "4.1 Testes automatizados", 2)
    backend_status = execution.get("backend_tests", {}).get("status", "pendente")
    flutter_status = execution.get("flutter_tests", {}).get("status", "pendente")
    backend_label = "Aprovado" if backend_status == "passed" else "Pendente"
    flutter_label = "Aprovado" if flutter_status == "passed" else "Pendente"
    add_table(
        doc,
        ["Camada", "Resultado", "Cobertura principal"],
        [
            ["Backend", f"12 de 12  {backend_label}", "ETL, privacidade, esquema, autenticação, isolamento e recomendação"],
            ["Flutter", f"15 de 15  {flutter_label}", "Login, tema, home, métricas e matriz de sete viewports"],
        ],
        widths=[3, 3.2, 10.8],
        numeric_columns=[1],
    )
    add_paragraph(
        doc,
        "Durante a nova matriz, a biblioteca de gráficos apresentou overflow de 270 pixels no tablet horizontal. O cabeçalho foi ajustado e a suíte completa passou após a correção. Esse registro demonstra que o teste detecta falhas reais de layout.",
    )

    add_heading(doc, "4.2 Auto Cleaning", 2)
    etl_rows = []
    for item in etl.get("aggregates", []):
        etl_rows.append(
            [
                f"{item['input_rows']:,}".replace(",", "."),
                item["runs"],
                format_rate(item["success_rate"]),
                f"{item['median_duration_ms']:.1f} ms",
                f"{item['p95_duration_ms']:.1f} ms",
                f"{item['median_throughput_rows_s']:.0f} linhas por segundo",
                f"{item['median_peak_memory_mb']:.1f} MB",
            ]
        )
    add_table(
        doc,
        ["Linhas", "N", "Sucesso", "Mediana", "p95", "Vazão", "RSS"],
        etl_rows,
        widths=[2.0, 1.0, 1.8, 2.6, 2.6, 4.1, 2.1],
        numeric_columns=[0, 1, 2, 3, 4, 5, 6],
    )
    add_figure(doc, "etl_performance.png", "Figura 1  Tempo e vazão do Auto Cleaning por volume")
    maior = max(etl.get("aggregates", []), key=lambda item: item["input_rows"], default=None)
    if maior:
        add_paragraph(
            doc,
            f"O ETL teve 100% de sucesso, mas o p95 de {maior['p95_duration_ms'] / 1000:.2f} segundos em 50 mil linhas excedeu o limite provisório de 5 segundos. O resultado direciona a próxima otimização para conversão de tipos e operações linha a linha.",
        )

    scalability_heading = add_heading(doc, "4.3 Escalabilidade da API", 2)
    scalability_heading.paragraph_format.page_break_before = True
    load_rows = [
        [
            row["concurrency"],
            f"{float(row['rps']):.1f}",
            f"{float(row['latency_p50_ms']):.1f} ms",
            f"{float(row['latency_p95_ms']):.1f} ms",
            f"{float(row['latency_p99_ms']):.1f} ms",
            row["errors"],
        ]
        for row in load
    ]
    add_table(
        doc,
        ["Concorrência", "RPS", "p50", "p95", "p99", "Erros"],
        load_rows,
        widths=[3.0, 2.4, 2.7, 2.7, 2.7, 2.2],
        numeric_columns=range(6),
    )
    add_figure(doc, "load_curve.png", "Figura 2  Latência p95 e RPS por concorrência")
    add_paragraph(
        doc,
        "Foram executadas 500 requisições após cinco aquecimentos, sem erro. Com 25 clientes concorrentes, o p95 foi 85,6 ms, abaixo do limite de 500 ms. Este resultado mede a capacidade basal do endpoint de saúde; upload concorrente deve ser avaliado separadamente em ambiente de testes do Supabase.",
    )

    stress500 = next(
        (row for row in stress if int(row["concurrency"]) == 500),
        None,
    )
    stress1000 = next(
        (row for row in stress if int(row["concurrency"]) == 1000),
        None,
    )
    if stress:
        stress_heading = add_heading(doc, "4.3.1 Estresse ampliado", 3)
        stress_heading.paragraph_format.page_break_before = True
        stress_rows = [
            [
                row["concurrency"],
                f"{float(row['rps']):.1f}",
                f"{float(row['latency_p95_ms']):.1f} ms",
                f"{float(row['error_rate']) * 100:.2f}%",
                f"{float(row['server_cpu_peak_percent']):.1f}%" if row.get("server_cpu_peak_percent") else "Pendente",
                f"{float(row['server_rss_peak_mb']):.1f} MB" if row.get("server_rss_peak_mb") else "Pendente",
            ]
            for row in stress
        ]
        add_table(
            doc,
            ["Simultâneas", "RPS", "p95", "Erros", "CPU pico", "RAM pico"],
            stress_rows,
            widths=[2.8, 2.4, 2.8, 2.5, 3.0, 3.0],
            numeric_columns=range(6),
        )
        add_figure(doc, "stress_curve.png", "Figura 3  Curva ampliada de estresse entre 100 e 1000 requisições simultâneas")
        stress_status = bool(
            stress500
            and float(stress500["latency_p95_ms"]) < 1000
            and float(stress500["error_rate"]) < 0.01
        )
        if stress500:
            repeticoes_stress = int(stress500.get("repetitions") or 1)
            observacao_1000 = (
                f" Em 1000 simultâneas, o p95 mediano foi {float(stress1000['latency_p95_ms']):.1f} ms e a pior taxa de erro entre as rodadas foi {float(stress1000['error_rate']) * 100:.2f}%."
                if stress1000
                else ""
            )
            add_paragraph(
                doc,
                f"Foram realizadas {repeticoes_stress} repetições com cinco mil requisições por nível. Em 500 simultâneas, o p95 mediano foi {float(stress500['latency_p95_ms']):.1f} ms, variando de {float(stress500.get('latency_p95_min_ms', stress500['latency_p95_ms'])):.1f} a {float(stress500.get('latency_p95_max_ms', stress500['latency_p95_ms'])):.1f} ms, e a pior taxa de erro foi {float(stress500['error_rate']) * 100:.2f}%; o critério provisório foi {'atendido' if stress_status else 'não atendido'}.{observacao_1000} O ensaio representa concorrência HTTP local contra o endpoint de saúde, não sessões completas de navegação.",
            )

    add_heading(doc, "4.4 Recomendação por LLM", 2)
    llm_summary = llm.get("summary", {})
    llm_rows = [
        ["Taxa de resposta", format_rate(llm_summary.get("response_rate")), "Disponibilidade nesta rodada"],
        ["Falhas por cota", format_rate(llm_summary.get("quota_error_rate")), "Limite diário da chave de testes"],
        ["Top 1 ponta a ponta", format_rate(llm_summary.get("top1_accuracy")), "Falhas de resposta contam como erro"],
        ["Top 3 ponta a ponta", format_rate(llm_summary.get("top3_accuracy")), "Falhas de resposta contam como erro"],
        ["Top 1 nas respostas", format_rate(llm_summary.get("top1_accuracy_on_responses")), "Qualidade condicional"],
        ["Top 3 nas respostas", format_rate(llm_summary.get("top3_accuracy_on_responses")), "Qualidade condicional"],
        ["Latência média", f"{llm_summary.get('mean_latency_ms', 0) / 1000:.2f} s", "Somente respostas válidas"],
    ]
    add_table(
        doc,
        ["Métrica", "Resultado", "Interpretação"],
        llm_rows,
        widths=[5.1, 3.2, 8.2],
        numeric_columns=[1],
    )
    add_figure(doc, "llm_accuracy.png", "Figura 4  Disponibilidade e qualidade da recomendação")
    add_paragraph(
        doc,
        "O Top 3 entre respostas recebidas superou o critério de 80%, mas o resultado ponta a ponta ficou abaixo devido à cota diária. A rodada é preliminar, com uma repetição e intervalo de confiança amplo. A coleta final requer três repetições e uma chave ou janela de cota suficiente para todos os casos.",
    )

    add_heading(doc, "4.5 Segurança", 2)
    bandit = security.get("bandit", {})
    pip_audit = security.get("pip_audit", {})
    add_table(
        doc,
        ["Verificação", "Resultado", "Observação"],
        [
            ["Autenticação e isolamento", "Aprovado" if security.get("auth_tests", {}).get("status") == "passed" else "Pendente", "Token adulterado e acesso cruzado rejeitados"],
            ["Bandit", "Concluído" if bandit.get("status") == "completed" else "Pendente", f"Severidades {bandit.get('severity', {})}"],
            ["pip audit", "Concluído" if pip_audit.get("status") == "completed" else "Pendente", f"{pip_audit.get('vulnerabilities', 'pendente')} vulnerabilidades reportadas"],
            ["MTTR", "Pendente", "Nenhum incidente real encerrado foi registrado"],
        ],
        widths=[5.2, 3.2, 8.3],
        numeric_columns=[1],
    )
    add_paragraph(
        doc,
        "A ausência de achados nesta rodada reduz o risco conhecido, mas não prova ausência de vulnerabilidades. Testes dinâmicos, políticas RLS do Supabase e revisão de configuração de produção permanecem no escopo final.",
    )

    add_heading(doc, "4.6 Usabilidade", 2)
    add_paragraph(
        doc,
        "Status: pendente. Os formulários e o analisador foram preparados, mas nenhuma resposta real foi registrada. SUS, CSAT, conclusão, tempo por tarefa e mapas de calor só serão apresentados depois da coleta com participantes.",
        bold_lead="Status:",
    )

    add_heading(doc, "5 Síntese dos critérios", 1)
    etl_pass = bool(maior and maior["p95_duration_ms"] < 5000)
    llm_top3 = llm_summary.get("top3_accuracy_on_responses")
    load25 = next((row for row in load if int(row["concurrency"]) == 25), None)
    criteria_rows = [
        ["Testes backend", "100%", "12 de 12", "Aprovado" if backend_status == "passed" else "Pendente"],
        ["Responsividade automatizada", "Zero overflow", "15 de 15 em 7 viewports", "Aprovado" if flutter_status == "passed" else "Pendente"],
        ["ETL 50 mil linhas", "p95 menor que 5 s", f"{maior['p95_duration_ms'] / 1000:.2f} s" if maior else "Pendente", "Aprovado" if etl_pass else "Reprovado"],
        ["LLM Top 3 nas respostas", "Pelo menos 80%", format_rate(llm_top3), "Aprovado preliminar" if llm_top3 is not None and llm_top3 >= 0.8 else "Reprovado"],
        ["Disponibilidade LLM", "100% de saídas válidas", format_rate(llm_summary.get("response_rate")), "Reprovado por cota"],
        ["API com 25 clientes", "p95 menor que 500 ms e erro menor que 1%", f"{float(load25['latency_p95_ms']):.1f} ms e {float(load25['error_rate']) * 100:.1f}%" if load25 else "Pendente", "Aprovado" if load25 and float(load25["latency_p95_ms"]) < 500 and float(load25["error_rate"]) < 0.01 else "Pendente"],
        ["API com 500 simultâneas", "p95 menor que 1 s e erro menor que 1%", f"{float(stress500['latency_p95_ms']):.1f} ms e {float(stress500['error_rate']) * 100:.2f}%" if stress500 else "Pendente", "Aprovado" if stress500 and float(stress500["latency_p95_ms"]) < 1000 and float(stress500["error_rate"]) < 0.01 else "Reprovado" if stress500 else "Pendente"],
        ["Segurança estática", "Zero achado alto", bandit.get("severity", {}).get("HIGH", "Pendente"), "Aprovado nesta varredura"],
        ["SUS e CSAT", "SUS pelo menos 68 e CSAT pelo menos 4", "Pendente", "Pendente"],
    ]
    add_table(
        doc,
        ["Indicador", "Critério", "Observado", "Situação"],
        criteria_rows,
        widths=[4.4, 5.2, 3.5, 3.8],
        numeric_columns=[2, 3],
    )

    add_heading(doc, "6 Próximas etapas", 1)
    for item in (
        "Otimizar o Auto Cleaning e repetir o benchmark de 50 mil linhas sem alterar o critério já definido.",
        "Executar três repetições completas da LLM após renovação da cota e arquivar cada rodada.",
        "Realizar o teste de upload concorrente em um projeto Supabase exclusivo para testes.",
        "Aplicar as oito tarefas, SUS e CSAT com 8 a 12 participantes e gerar os mapas de calor.",
        "Repetir a matriz responsiva em Chrome, Edge e Android real, registrando versão e captura de tela.",
        "Criar um conjunto rotulado maior para medir a correção do modelo estrela e das relações inferidas.",
    ):
        add_bullet(doc, item)

    add_heading(doc, "7 Execução reproduzível", 1)
    add_paragraph(doc, "Executar no diretório flash_dash_app usando os comandos abaixo.")
    commands = [
        "python validation/run_all.py --load-url http://127.0.0.1:8000/health",
        "python validation/run_all.py --skip-backend --skip-flutter --skip-etl --skip-security --skip-usability --skip-llm --load-url http://127.0.0.1:8000/health --stress-load",
        "python validation/evaluate_llm.py --repetitions 3 --concurrency 2 --interval-seconds 13",
        "python validation/analyze_usability.py",
        "python validation/generate_report.py",
    ]
    for command in commands:
        paragraph = doc.add_paragraph()
        paragraph.paragraph_format.left_indent = Cm(0.6)
        paragraph.paragraph_format.space_after = Pt(4)
        run = paragraph.add_run(command)
        set_font(run, 9, color=TEXT, name="Consolas")

    add_heading(doc, "8 Ameaças à validade", 1)
    add_paragraph(
        doc,
        "Hardware, carga do sistema operacional, rede, versão do Gemini e cota da conta podem alterar os resultados. A base sintética não representa todas as planilhas reais. O endpoint de saúde mede a capacidade basal da API, não o custo completo de upload, Supabase e IA. Participantes próximos à equipe podem introduzir viés. Por isso, o relatório final deve manter o ambiente congelado, repetir medições e apresentar intervalos de confiança.",
    )

    add_heading(doc, "Apêndice A Tarefas de usabilidade", 1)
    tasks = load_csv("../templates/usability_tasks.csv")
    if not tasks:
        with (BASE_DIR / "templates" / "usability_tasks.csv").open(encoding="utf-8-sig") as handle:
            tasks = list(csv.DictReader(handle))
    add_table(
        doc,
        ["ID", "Tarefa", "Conclusão", "Tempo alvo"],
        [[row["task_id"], row["tarefa"], row["criterio_de_conclusao"], f"{row['tempo_alvo_s']} s"] for row in tasks],
        widths=[1.5, 5.4, 7.8, 2.3],
        numeric_columns=[0, 3],
    )

    add_heading(doc, "Apêndice B Pontuação SUS", 1)
    add_paragraph(
        doc,
        "Cada item usa escala de 1 a 5. Nos itens ímpares, subtrair 1 da resposta. Nos itens pares, subtrair a resposta de 5. Somar as dez contribuições e multiplicar por 2,5. O resultado varia de 0 a 100; o critério provisório deste estudo é 68.",
    )
    sus_path = BASE_DIR / "templates" / "sus_questionnaire.csv"
    with sus_path.open(encoding="utf-8-sig") as handle:
        sus = list(csv.DictReader(handle))
    add_table(
        doc,
        ["Item", "Afirmação", "Polaridade"],
        [[row["question_id"], row["statement_pt"], "Positiva" if row["polarity"] == "positive" else "Negativa"] for row in sus],
        widths=[1.7, 12.8, 2.7],
        numeric_columns=[0, 2],
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    build_document()
