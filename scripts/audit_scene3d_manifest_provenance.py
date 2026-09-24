"""Summarize current provenance validity for existing scene3D manifests.

The audit is read-only.  It deliberately distinguishes v2 capture manifests
from older diagnostic/helper manifests instead of rewriting either kind.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from validate_scene3d_capture import ROOT, validate


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="tempassets/work")
    parser.add_argument(
        "--output",
        default="docs/design/SCENE3D-MANIFEST-PROVENANCE-AUDIT-2026-09-21.json",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    workspace = ROOT
    root = (workspace / args.root).resolve()
    output_path = (workspace / args.output).resolve()
    manifests = sorted(root.rglob("manifest.json"))
    total = len(manifests)
    v2 = 0
    v2_valid = 0
    v2_invalid = 0
    legacy_or_malformed = 0
    error_counts: Counter[str] = Counter()
    invalid_examples: list[dict[str, Any]] = []
    legacy_examples: list[str] = []

    for path in manifests:
        try:
            data = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, ValueError) as exc:
            legacy_or_malformed += 1
            error_counts["manifest_json_error"] += 1
            if len(legacy_examples) < 20:
                legacy_examples.append(str(path.relative_to(workspace)).replace("\\", "/"))
            continue
        if not isinstance(data, dict):
            legacy_or_malformed += 1
            error_counts["manifest_not_object"] += 1
            if len(legacy_examples) < 20:
                legacy_examples.append(str(path.relative_to(workspace)).replace("\\", "/"))
            continue
        if data.get("schema_version") != 2:
            legacy_or_malformed += 1
            error_counts["non_v2_manifest"] += 1
            if len(legacy_examples) < 20:
                legacy_examples.append(str(path.relative_to(workspace)).replace("\\", "/"))
            continue
        v2 += 1
        errors = validate(data, path.parent)
        if not errors:
            v2_valid += 1
            continue
        v2_invalid += 1
        for error in errors:
            error_counts[error] += 1
        if len(invalid_examples) < 25:
            invalid_examples.append(
                {
                    "manifest": str(path.relative_to(workspace)).replace("\\", "/"),
                    "errors": errors,
                }
            )

    report = {
        "schema_version": 1,
        "root": args.root.replace("\\", "/"),
        "manifest_count": total,
        "v2_count": v2,
        "v2_current_provenance_valid_count": v2_valid,
        "v2_current_provenance_invalid_count": v2_invalid,
        "legacy_or_malformed_count": legacy_or_malformed,
        "error_counts": dict(error_counts.most_common()),
        "invalid_examples": invalid_examples,
        "legacy_examples": legacy_examples,
        "status": "recheck_required" if v2_invalid else "pass",
        "rule": "Existing manifests are never rewritten; stale or legacy evidence remains explicitly separate from current v2 provenance.",
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"SCENE3D_MANIFEST_PROVENANCE_{report['status'].upper()} "
        f"total={total} v2={v2} valid={v2_valid} invalid={v2_invalid} legacy={legacy_or_malformed}"
    )
    return 0 if not v2_invalid else 1


if __name__ == "__main__":
    raise SystemExit(main())
