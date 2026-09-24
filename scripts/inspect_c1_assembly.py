"""Bounded alpha-footprint fitting for the fixed-front C1 asset fixture.

Uses source alpha and the actual off-axis projection, not rendered screenshots.
This is a local diagnostic, not proof of arbitrary routes, lighting or gameplay.
"""
import argparse
import copy
import hashlib
import itertools
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def inspect(manifest, assets):
    # Downsample the *inspection grid*, never production source art.
    width, height = 388, 208
    x, y = np.meshgrid((np.arange(width) + .5) / width, (np.arange(height) + .5) / height)
    focal = min(830 * .86, 1552 * .72)
    rays_x = (x - .5) * 1552 / focal
    rays_y = (.48 - y) * 830 / focal
    zones = {"top": y < .18, "left": (x < .14) & (y < .8), "right": (x > .86) & (y < .8)}
    findings = []
    for view in manifest["views"]:
        covered = np.zeros((height, width), dtype=bool)
        for piece in manifest["instances"]:
            alpha = assets[piece["source"]]
            depth = -piece["position_m"][2]
            if depth <= .05:
                continue
            h = piece["canvas_height_m"]
            w = h * alpha.shape[1] / alpha.shape[0]
            px = view["camera_x_m"] + rays_x * depth
            py = view["camera_y_m"] + rays_y * depth
            u = (px - piece["position_m"][0]) / w * (-1 if piece["flip"] else 1) + piece["anchor"][0]
            v = piece["anchor"][1] - (py - piece["position_m"][1]) / h
            inside = (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
            ix = np.clip((u * alpha.shape[1]).astype(int), 0, alpha.shape[1] - 1)
            iy = np.clip((v * alpha.shape[0]).astype(int), 0, alpha.shape[0] - 1)
            covered |= inside & (alpha[iy, ix] >= 128)
        findings.append({"view": view["name"], "coverage": {k: float(covered[mask].mean()) for k, mask in zones.items()}})
    return findings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    baseline = json.loads(args.manifest.read_text(encoding="utf-8"))
    assets, hashes = {}, {}
    for piece in baseline["instances"]:
        source = piece["source"]
        path = ROOT / "godot" / source.removeprefix("res://")
        assets[source] = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3]
        hashes[source] = hashlib.sha256(path.read_bytes()).hexdigest()
    candidates = []
    # 32 explicit assembly candidates, no unbounded random retries. No image
    # deformation: position and uniform scale only; no new walls/geometry.
    for connector_x, cap_height, cap_same_depth, near_x, near_depth in itertools.product(
        [1.9, 2.2], [4.1, 4.4], [False, True], [3.65, 3.85], [2.7, 3.3]
    ):
        candidate = copy.deepcopy(baseline)
        for piece in candidate["instances"]:
            source = piece["source"]
            if "shoulder-connector" in source:
                piece["position_m"][0] = connector_x * (-1 if piece["position_m"][0] < 0 else 1)
            elif "roof-underside" in source:
                piece["canvas_height_m"] = cap_height
                if cap_same_depth:
                    piece["position_m"][2] += .7
            elif abs(piece["position_m"][2] + 2.7) < .001:
                piece["position_m"][0] = near_x * (-1 if piece["position_m"][0] < 0 else 1)
                piece["position_m"][2] = -near_depth
        findings = inspect(candidate, assets)
        score = min(value for view in findings for value in view["coverage"].values())
        candidates.append((score, candidate, findings))
    best = max(candidates, key=lambda item: item[0])
    args.output_dir.mkdir(parents=True, exist_ok=True)
    report = {
        "status": "fixture_only_not_visual_acceptance",
        "candidate_count": len(candidates),
        "method": "project original alpha into declared view samples; union structural silhouettes",
        "source_manifest": str(args.manifest), "asset_sha256": hashes,
        "inspection_grid": [388, 208], "authored_fixture_goal": .98,
        "goal_is_not_global_scene_standard": True,
        "baseline": inspect(baseline, assets), "best": best[2],
        "worst_region_coverage": best[0], "fixture_goal_met": best[0] >= .98,
        "limitations": ["sampled lateral views only", "no continuous travel proof", "no perspective camera yaw", "no overdraw/performance or gameplay clearance certification", "asset variety still insufficient"],
    }
    (args.output_dir / "coverage-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (args.output_dir / "candidate.json").write_text(json.dumps(best[1], indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"candidates": len(candidates), "worst_coverage": best[0], "fixture_goal_met": report["fixture_goal_met"]}))


if __name__ == "__main__":
    main()
