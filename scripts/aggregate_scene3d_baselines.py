"""Aggregate six P02 baseline manifests without treating counts as visual approval."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from math import isclose
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from validate_scene3d_capture import validate  # noqa: E402

THEMES = ["forest", "crystal", "swamp", "sewer", "whale", "palace"]

ROLE_COLORS = {
    "structure": (255, 0, 0),
    "dressing": (255, 255, 0),
    "root_cover": (255, 0, 255),
    "actor": (0, 102, 255),
    "ground": (0, 255, 0),
}


def _same_numbers(left, right, tolerance=1e-4):
    return isinstance(left, list) and isinstance(right, list) and len(left) == len(right) and all(
        isclose(float(a), float(b), abs_tol=tolerance, rel_tol=tolerance) for a, b in zip(left, right)
    )


def mask_metrics(mask_dir: Path) -> dict:
    role = Image.open(mask_dir / "role-id.png").convert("RGB")
    depth = Image.open(mask_dir / "depth.png").convert("L")
    width, height = role.size
    pixels = list(role.getdata())
    depth_pixels = list(depth.getdata())
    counts = {}
    for name, color in ROLE_COLORS.items():
        counts[name] = sum(pixel == color for pixel in pixels)
    rois = {"left": (0, int(width * .3), 0, height), "middle": (int(width * .3), int(width * .7), 0, height), "right": (int(width * .7), width, 0, height)}
    vertical = {"top": (0, width, 0, int(height * .35)), "mid": (0, width, int(height * .35), int(height * .70)), "ground": (0, width, int(height * .70), height)}
    roi_counts = {"horizontal": {}, "vertical": {}}
    for group, definitions in [("horizontal", rois), ("vertical", vertical)]:
        for roi_name, (x0, x1, y0, y1) in definitions.items():
            values = []
            for y in range(y0, y1):
                values.extend(pixels[y * width + x0:y * width + x1])
            roi_counts[group][roi_name] = {name: sum(pixel == color for pixel in values) for name, color in ROLE_COLORS.items()}
    depth_bands = {"0_10m": 0, "10_30m": 0, "30m_plus": 0}
    for value in depth_pixels:
        metres = value / 255.0 * 20.0
        if value == 0: continue
        if metres < 10.0: depth_bands["0_10m"] += 1
        elif metres < 30.0: depth_bands["10_30m"] += 1
        else: depth_bands["30m_plus"] += 1
    return {"viewport": [width, height], "role_pixel_counts": counts, "roi_pixel_counts": roi_counts, "depth_encoding": "grayscale_value/255*20m", "depth_band_pixels": depth_bands}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="directory containing one theme directory per baseline")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--masks-root", type=Path, help="directory containing same-theme role-id/depth diagnostic manifests")
    args = parser.parse_args()
    root = args.root.resolve()
    scenes = []
    errors = []
    for theme in THEMES:
        manifest_path = root / theme / "manifest.json"
        if not manifest_path.is_file():
            errors.append(f"missing manifest: {theme}")
            continue
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"invalid manifest {theme}: {exc}")
            continue
        # The provenance validator expects the manifest's settings/images to be
        # relative to each run directory, so validate at that directory.
        validation = validate(manifest, manifest_path.parent)
        if validation:
            errors.extend(f"{theme}: {item}" for item in validation)
        mask_manifest = None
        mask_validation = []
        mask_data = None
        if args.masks_root:
            mask_path = args.masks_root.resolve() / theme / "manifest.json"
            if not mask_path.is_file():
                mask_validation.append("missing role/depth mask manifest")
            else:
                try:
                    mask_data = json.loads(mask_path.read_text(encoding="utf-8-sig"))
                    for capture in mask_data.get("captures", []):
                        image_path = mask_path.parent / str(capture.get("file", ""))
                        if not image_path.is_file(): mask_validation.append(f"missing mask image: {image_path.name}")
                        elif capture.get("sha256") != __import__("hashlib").sha256(image_path.read_bytes()).hexdigest(): mask_validation.append(f"mask hash mismatch: {image_path.name}")
                    base_capture = manifest.get("captures", [{}])[0]
                    if not _same_numbers(mask_data.get("camera_transform"), base_capture.get("camera_transform")): mask_validation.append("mask camera transform differs from beauty capture")
                    if not _same_numbers(mask_data.get("projection_matrix"), base_capture.get("projection_matrix")): mask_validation.append("mask projection differs from beauty capture")
                    if mask_data.get("seed") != manifest.get("captures", [{}])[0].get("seed"): mask_validation.append("mask seed differs from beauty capture")
                    if mask_data.get("branch") != manifest.get("captures", [{}])[0].get("branch"): mask_validation.append("mask branch differs from beauty capture")
                    if mask_data.get("viewport") != manifest.get("captures", [{}])[0].get("viewport"): mask_validation.append("mask viewport differs from beauty capture")
                    if not mask_validation: mask_manifest = str(mask_path.relative_to(ROOT)).replace("\\", "/")
                except (OSError, json.JSONDecodeError) as exc:
                    mask_validation.append(f"invalid mask manifest: {exc}")
            errors.extend(f"{theme}: {item}" for item in mask_validation)
        scenes.append({
            "theme": theme,
            "manifest": str(manifest_path.relative_to(ROOT)).replace("\\", "/"),
            "captures": manifest.get("captures", []),
            "provenance_valid": not validation,
            "role_metrics_source": "world3d_stage projected scene records",
            "depth_occlusion_masks": mask_manifest or "pending",
            "mask_metrics": mask_metrics(mask_path.parent) if mask_manifest else None,
            "mask_provenance_valid": not mask_validation if args.masks_root else False,
        })
    output = {
        "schema_version": 1,
        "scope": "six accepted 3D baseline captures; no user visual acceptance",
        "themes": THEMES,
        "scenes": scenes,
        "provenance_errors": errors,
        "measurement_status": "role_id_and_depth_masks_verified; visual_review_pending" if args.masks_root and not errors else "preliminary_role_counts; depth_and_ID_masks_pending",
        "rule": "sprite counts and brightness never substitute for role/depth masks or visual review",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"P02_BASELINE_AGGREGATE themes={len(scenes)} provenance_errors={len(errors)} depth_masks={'verified' if args.masks_root and not errors else 'pending'}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
