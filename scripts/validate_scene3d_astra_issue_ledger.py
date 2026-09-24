"""Validate the evidence-backed Astra handoff issue ledger.

This is intentionally read-only with respect to the ledger itself.  It checks
that the handoff is complete enough to be actionable without turning missing
evidence or guessed values into a closed issue.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


REQUIRED_ISSUE_FIELDS = {
    "id",
    "severity",
    "status",
    "family",
    "scene",
    "title",
    "evidence",
    "finding",
    "recommended_fix",
}
ALLOWED_SEVERITIES = {"blocking", "high", "medium", "low"}
FORBIDDEN_GUESS_STATUSES = {"closed", "resolved", "approved"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ledger",
        default="docs/design/SCENE3D-ASTRA-ISSUE-LEDGER-2026-09-21.json",
    )
    parser.add_argument(
        "--output",
        default="docs/design/SCENE3D-ASTRA-ISSUE-LEDGER-VALIDATION-2026-09-21.json",
    )
    return parser.parse_args()


def evidence_path(workspace: Path, raw: str) -> Path:
    # Evidence may use a markdown anchor after the real file path.
    path_text = raw.split("#", 1)[0]
    return (workspace / path_text).resolve()


def main() -> int:
    args = parse_args()
    workspace = Path(__file__).resolve().parents[1]
    ledger_path = (workspace / args.ledger).resolve()
    output_path = (workspace / args.output).resolve()

    data: dict[str, Any] = json.loads(ledger_path.read_text(encoding="utf-8"))
    issues = data.get("issues")
    order = data.get("handoff_order")
    failures: list[str] = []
    warnings: list[str] = []

    if not isinstance(issues, list) or not issues:
        failures.append("issues must be a non-empty array")
        issues = []
    if not isinstance(order, list):
        failures.append("handoff_order must be an array")
        order = []

    ids = [item.get("id") for item in issues if isinstance(item, dict)]
    duplicate_ids = sorted({item for item in ids if ids.count(item) > 1})
    if duplicate_ids:
        failures.append(f"duplicate issue ids: {duplicate_ids}")
    if any(not isinstance(item, str) or not item for item in ids):
        failures.append("every issue must have a non-empty string id")

    if set(order) != set(ids) or len(order) != len(ids):
        failures.append("handoff_order must contain every issue id exactly once")

    status_counts: Counter[str] = Counter()
    severity_counts: Counter[str] = Counter()
    evidence_missing: list[dict[str, str]] = []
    for issue in issues:
        if not isinstance(issue, dict):
            failures.append("issues contains a non-object entry")
            continue
        issue_id = issue.get("id", "<missing-id>")
        missing_fields = sorted(REQUIRED_ISSUE_FIELDS - set(issue))
        if missing_fields:
            failures.append(f"{issue_id} missing fields: {missing_fields}")
        severity = issue.get("severity")
        status = issue.get("status")
        if severity not in ALLOWED_SEVERITIES:
            failures.append(f"{issue_id} has invalid severity: {severity!r}")
        if not isinstance(status, str) or not status:
            failures.append(f"{issue_id} has invalid status")
        else:
            status_counts[status] += 1
            if status in FORBIDDEN_GUESS_STATUSES:
                failures.append(
                    f"{issue_id} is marked {status!r}; Astra must supply explicit resolution evidence"
                )
        if severity in ALLOWED_SEVERITIES:
            severity_counts[severity] += 1
        evidence = issue.get("evidence")
        if not isinstance(evidence, list) or not evidence:
            failures.append(f"{issue_id} must have at least one evidence path")
            continue
        for raw in evidence:
            if not isinstance(raw, str) or not raw:
                failures.append(f"{issue_id} has a non-string evidence path")
                continue
            path = evidence_path(workspace, raw)
            if not path.exists():
                evidence_missing.append({"issue_id": str(issue_id), "path": raw})

    if evidence_missing:
        failures.append(f"missing evidence paths: {len(evidence_missing)}")
    if data.get("current_goal_state") and "not" not in str(data["current_goal_state"]).lower():
        warnings.append("current_goal_state does not explicitly state that production is incomplete")

    report = {
        "schema_version": 1,
        "ledger": args.ledger.replace("\\", "/"),
        "issue_count": len(issues),
        "handoff_order_count": len(order),
        "status_counts": dict(sorted(status_counts.items())),
        "severity_counts": dict(sorted(severity_counts.items())),
        "evidence_missing": evidence_missing,
        "warnings": warnings,
        "failures": failures,
        "status": "pass" if not failures else "fail",
        "rule": "Only explicit evidence can close an issue; this validator never changes the ledger.",
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"SCENE3D_ASTRA_LEDGER_{report['status'].upper()} "
        f"issues={len(issues)} missing_evidence={len(evidence_missing)} failures={len(failures)}"
    )
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
