"""Derive measured, review-only gates from the six role/depth baseline masks.

The output is deliberately a measurement artifact, not an approval: values are
ratios from the captured masks and keep their source theme/capture references.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


ROLES = ("structure", "dressing", "root_cover", "actor", "ground")
ROI_SIZES = {
    "horizontal": {"left": 0.30, "middle": 0.40, "right": 0.30},
    "vertical": {"top": 0.35, "mid": 0.35, "ground": 0.30},
}


def ratio_map(counts: dict, size: float) -> dict:
    return {role: round(float(counts.get(role, 0)) / size, 6) for role in ROLES}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("aggregate", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    aggregate = json.loads(args.aggregate.read_text(encoding="utf-8-sig"))
    themes = []
    for scene in aggregate.get("scenes", []):
        metrics = scene.get("mask_metrics") or {}
        viewport = metrics.get("viewport", [0, 0])
        width, height = int(viewport[0]), int(viewport[1])
        if width <= 0 or height <= 0:
            continue
        full_area = width * height
        horizontal = {}
        for name, fraction in ROI_SIZES["horizontal"].items():
            horizontal[name] = ratio_map(metrics.get("roi_pixel_counts", {}).get("horizontal", {}).get(name, {}), full_area * fraction)
        vertical = {}
        for name, fraction in ROI_SIZES["vertical"].items():
            vertical[name] = ratio_map(metrics.get("roi_pixel_counts", {}).get("vertical", {}).get(name, {}), full_area * fraction)
        depth = metrics.get("depth_band_pixels", {})
        depth_total = sum(int(v) for v in depth.values()) or 1
        themes.append({
            "theme": scene.get("theme"),
            "source_manifest": scene.get("manifest"),
            "source_mask_manifest": scene.get("depth_occlusion_masks"),
            "viewport": viewport,
            "role_coverage_ratio": ratio_map(metrics.get("role_pixel_counts", {}), full_area),
            "horizontal_roi_role_ratio": horizontal,
            "vertical_roi_role_ratio": vertical,
            "depth_band_ratio": {key: round(float(value) / depth_total, 6) for key, value in depth.items()},
        })
    output = {
        "schema_version": 1,
        "status": "measured_review_only_visual_approval_pending",
        "scope": "six baseline role/depth masks at the fixed P02 camera",
        "rule": "These ratios are diagnostic gates; they must not be copied to 18 scenes until a representative scene is visually approved.",
        "themes": themes,
        "next_use": "Compare a candidate scene with its assigned baseline family using the same camera and masks; report out-of-band roles and keep the candidate pending.",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SCENE3D_BASELINE_GATES_PASS themes={len(themes)} status={output['status']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
