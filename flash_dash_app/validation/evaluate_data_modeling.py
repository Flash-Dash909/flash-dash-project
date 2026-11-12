import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


VALIDATION_DIR = Path(__file__).resolve().parent
BACKEND_SRC = VALIDATION_DIR.parent / "backend" / "src"
DATASET = VALIDATION_DIR / "datasets" / "modeling_cases.json"
RESULTS_DIR = VALIDATION_DIR / "results"

sys.path.insert(0, str(BACKEND_SRC))

from data_modeling import combine_sources, infer_relationships  # noqa: E402


def _signature(item):
    return (
        str(item["fonte_origem_id"]),
        str(item["fonte_destino_id"]),
        str(item["chave_origem"]),
        str(item["chave_destino"]),
        str(item["cardinalidade"]),
    )


def main():
    cases = json.loads(DATASET.read_text(encoding="utf-8"))
    rows = []
    expected_total = 0
    predicted_total = 0
    true_positives = 0
    structural_passes = 0

    for case in cases:
        predicted_items = infer_relationships(case["sources"])
        predicted = {_signature(item) for item in predicted_items}
        expected = {tuple(item) for item in case["expected"]}
        intersection = expected & predicted
        expected_total += len(expected)
        predicted_total += len(predicted)
        true_positives += len(intersection)

        structural_ok = False
        error = None
        if expected:
            try:
                result = combine_sources(case["sources"])
                model = result["modelo_estrela"]
                structural_ok = (
                    bool(model["tabela_fato"])
                    and len(model["relacionamentos"]) == len(expected)
                )
            except ValueError as exc:
                error = str(exc)
        else:
            structural_ok = not predicted

        exact = predicted == expected
        structural_passes += int(structural_ok)
        rows.append(
            {
                "case": case["id"],
                "expected": len(expected),
                "predicted": len(predicted),
                "true_positives": len(intersection),
                "exact_match": exact,
                "structural_validity": structural_ok,
                "error": error or "",
            }
        )

    case_accuracy = sum(item["exact_match"] for item in rows) / len(rows)
    precision = true_positives / predicted_total if predicted_total else 1.0
    recall = true_positives / expected_total if expected_total else 1.0
    structural_accuracy = structural_passes / len(rows)
    approved = (
        case_accuracy == 1.0
        and precision == 1.0
        and recall == 1.0
        and structural_accuracy == 1.0
    )
    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "cases": len(rows),
        "case_accuracy": round(case_accuracy, 4),
        "relationship_precision": round(precision, 4),
        "relationship_recall": round(recall, 4),
        "structural_accuracy": round(structural_accuracy, 4),
        "success_criteria": {
            "case_accuracy": 1.0,
            "relationship_precision": 1.0,
            "relationship_recall": 1.0,
            "structural_accuracy": 1.0,
        },
        "approved": approved,
        "results": rows,
    }

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    (RESULTS_DIR / "modeling_evaluation.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    with (RESULTS_DIR / "modeling_evaluation.csv").open(
        "w", newline="", encoding="utf-8-sig"
    ) as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(
        "Modelagem: "
        f"casos={len(rows)}, acuracia={case_accuracy:.1%}, "
        f"precisao={precision:.1%}, recall={recall:.1%}, "
        f"estrutura={structural_accuracy:.1%}, aprovado={approved}"
    )
    raise SystemExit(0 if approved else 1)


if __name__ == "__main__":
    main()
