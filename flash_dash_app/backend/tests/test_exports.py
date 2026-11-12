import io
import sys
from pathlib import Path

import pandas as pd
from openpyxl import load_workbook

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from main import _formatar_planilhas_excel


def test_excel_export_is_filterable_and_readable():
    buffer = io.BytesIO()
    frame = pd.DataFrame(
        [
            {"Cliente": "Empresa Alfa", "Faturamento": 1250.5},
            {"Cliente": "Empresa Beta", "Faturamento": 980.0},
        ]
    )

    with pd.ExcelWriter(buffer, engine="openpyxl") as writer:
        frame.to_excel(writer, index=False, sheet_name="Dados tratados")
        _formatar_planilhas_excel(writer)

    buffer.seek(0)
    sheet = load_workbook(buffer)["Dados tratados"]

    assert sheet.freeze_panes == "A2"
    assert sheet.auto_filter.ref == "A1:B3"
    assert sheet["A1"].font.bold is True
    assert sheet["A1"].fill.fgColor.rgb.endswith("2563EB")
    assert sheet.column_dimensions["A"].width >= len("Empresa Alfa")
