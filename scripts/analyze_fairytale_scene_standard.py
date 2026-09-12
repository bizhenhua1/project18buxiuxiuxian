from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from statistics import mean, median
from typing import Dict, List, Optional, Sequence, Tuple

from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "art" / "fairytales" / "manifest.json"
DEFAULT_ASSETS_ROOT = ROOT / "godot" / "assets" / "fairytales"
DEFAULT_JSON_OUT = ROOT / "art" / "fairytales" / "asset_standard_report.json"
DEFAULT_CSV_OUT = ROOT / "art" / "fairytales" / "asset_standard_report.csv"
DEFAULT_MD_OUT = ROOT / "art" / "fairytales" / "asset_standard_report.md"


REQUIRED = {
    "ground": 1,
    "cliff": 1,
    "structure": 1,
    "prop": 4,
    "enemy": 3,
}


@dataclass
class AssetStat:
    scene: str
    kind: str
    index: Optional[int]
    file: str
    width: int
    height: int
    ratio: float
    opaque_pixels: int
    fill_ratio: float
    edge_touch_pixels: int
    edge_touch_ratio: float
    bbox_x0: int
    bbox_y0: int
    bbox_x1: int
    bbox_y1: int
    bbox_w: int
    bbox_h: int
    bbox_ratio: Optional[float]
    bbox_fill_ratio: Optional[float]
    anchor_x: Optional[float]
    anchor_y: Optional[float]
    seam_lr_mean: Optional[float]
    seam_tb_mean: Optional[float]
    seam_alpha_mean: Optional[float]


def _read_json(path: Path) -> Optional[dict]:
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def _safe_ratio(w: int, h: int) -> float:
    return float(w) / float(max(1, h))


def _edge_touch_ratio(alpha: np.ndarray) -> Tuple[int, float]:
    mask = alpha > 0
    if not np.any(mask):
        return 0, 0.0
    h, w = alpha.shape
    touch = np.zeros_like(mask, dtype=bool)
    touch[0, :] = mask[0, :]
    touch[h - 1, :] = mask[h - 1, :]
    touch[:, 0] |= mask[:, 0]
    touch[:, w - 1] |= mask[:, w - 1]
    edge = int(touch.sum())
    return edge, float(edge / max(1, int(mask.sum())))


def _bbox(alpha: np.ndarray) -> Tuple[int, int, int, int, int, int, Optional[float], Optional[float]]:
    ys, xs = np.where(alpha > 0)
    if len(xs) == 0:
        return 0, 0, 0, 0, 0, 0, None, None
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    bw = x1 - x0
    bh = y1 - y0
    area = int(((alpha > 0).sum()))
    return x0, y0, x1, y1, bw, bh, float(bw) / max(1.0, float(bh)), area / float(max(1, bw * bh))


def _seam_score(rgb: np.ndarray, alpha: np.ndarray) -> Tuple[float, float, float]:
    # Compare left/right and top/bottom edges for tile seam quality.
    left = rgb[:, 0, :].astype(np.float32)
    right = rgb[:, -1, :].astype(np.float32)
    top = rgb[0, :, :].astype(np.float32)
    bottom = rgb[-1, :, :].astype(np.float32)

    l2r = np.abs(left - right)
    t2b = np.abs(top - bottom)
    seam_lr = float(l2r.mean())
    seam_tb = float(t2b.mean())

    alpha_lr = np.abs(alpha[:, 0].astype(np.float32) / 255.0 - alpha[:, -1].astype(np.float32) / 255.0)
    alpha_tb = np.abs(alpha[0, :].astype(np.float32) / 255.0 - alpha[-1, :].astype(np.float32) / 255.0)
    seam_alpha = float((alpha_lr.mean() + alpha_tb.mean()) / 2.0)

    return seam_lr, seam_tb, seam_alpha


def _load_anchor(scene_root: Path, file_name: str) -> Optional[Tuple[float, float]]:
    anchor_path = scene_root / "anchors.json"
    data = _read_json(anchor_path)
    if not data or not isinstance(data, dict):
        return None
    entry = data.get(file_name)
    if not isinstance(entry, dict):
        return None
    anchor = entry.get("anchor")
    if not (isinstance(anchor, list) and len(anchor) == 2):
        return None
    try:
        return float(anchor[0]), float(anchor[1])
    except Exception:
        return None


def _collect_file_stats(scene_key: str, scene_root: Path, kind: str, index: Optional[int] = None) -> Optional[AssetStat]:
    file_name = f"{kind}.png" if index is None else f"{kind}-{index}.png"
    path = scene_root / file_name
    if not path.exists():
        return None

    with Image.open(path) as im:
        rgba = np.array(im.convert("RGBA"), dtype=np.uint8)

    alpha = rgba[:, :, 3]
    rgb = rgba[:, :, :3]
    h, w = alpha.shape
    opaque = int((alpha > 0).sum())
    fill = opaque / float(max(1, w * h))
    edge_px, edge_ratio = _edge_touch_ratio(alpha)
    x0, y0, x1, y1, bw, bh, br, bfill = _bbox(alpha)
    seam_lr: Optional[float]
    seam_tb: Optional[float]
    seam_alpha: Optional[float]

    if kind in ("ground", "cliff"):
        seam_lr, seam_tb, seam_alpha = _seam_score(rgb, alpha)
    else:
        seam_lr = seam_tb = seam_alpha = None

    anchor = _load_anchor(scene_root, file_name)
    return AssetStat(
        scene=scene_key,
        kind=kind,
        index=index,
        file=str(path.relative_to(ROOT)),
        width=w,
        height=h,
        ratio=_safe_ratio(w, h),
        opaque_pixels=opaque,
        fill_ratio=fill,
        edge_touch_pixels=edge_px,
        edge_touch_ratio=edge_ratio,
        bbox_x0=x0,
        bbox_y0=y0,
        bbox_x1=x1,
        bbox_y1=y1,
        bbox_w=bw,
        bbox_h=bh,
        bbox_ratio=br,
        bbox_fill_ratio=bfill,
        anchor_x=anchor[0] if anchor else None,
        anchor_y=anchor[1] if anchor else None,
        seam_lr_mean=seam_lr,
        seam_tb_mean=seam_tb,
        seam_alpha_mean=seam_alpha,
    )


def _to_lookup_key(stat: AssetStat) -> str:
    return stat.kind if stat.index is None else f"{stat.kind}-{stat.index}"


def pick_default_references(scenes: Sequence[dict]) -> List[str]:
    refs = []
    seen_parent = set()
    for s in scenes:
        p = s.get("parent")
        k = s.get("id")
        if p in seen_parent or not k:
            continue
        seen_parent.add(p)
        refs.append(k)
        if len(refs) >= 6:
            break
    return refs


def build_reference_profile(measurements: Dict[str, List[AssetStat]], reference_scenes: Sequence[str]) -> Dict[str, Dict[str, Dict[str, float]]]:
    grouped: Dict[str, Dict[str, List[float]]] = defaultdict(lambda: defaultdict(list))

    for sid in reference_scenes:
        for st in measurements.get(sid, []):
            k = _to_lookup_key(st)
            grouped[k]["ratio"].append(st.ratio)
            grouped[k]["fill"].append(st.fill_ratio)
            grouped[k]["edge_ratio"].append(st.edge_touch_ratio)
            grouped[k]["bbox_ratio"].append(st.bbox_ratio or 0.0)
            grouped[k]["bbox_fill"].append(st.bbox_fill_ratio or 0.0)
            if st.seam_lr_mean is not None:
                grouped[k]["seam_lr"].append(st.seam_lr_mean)
            if st.seam_tb_mean is not None:
                grouped[k]["seam_tb"].append(st.seam_tb_mean)
            if st.seam_alpha_mean is not None:
                grouped[k]["seam_alpha"].append(st.seam_alpha_mean)

    profile: Dict[str, Dict[str, Dict[str, float]]] = {}
    for asset, metrics in grouped.items():
        profile[asset] = {}
        for metric_name, values in metrics.items():
            profile[asset][metric_name] = {
                "mean": float(mean(values)),
                "median": float(median(values)),
                "min": float(min(values)),
                "max": float(max(values)),
            }
    return profile


def collect_measurements(assets_root: Path, scenes: Sequence[dict]) -> Dict[str, List[AssetStat]]:
    out: Dict[str, List[AssetStat]] = {}
    for scene in scenes:
        key = scene["id"]
        scene_root = assets_root / key
        stats: List[AssetStat] = []

        for kind, count in REQUIRED.items():
            if count == 1:
                st = _collect_file_stats(key, scene_root, kind)
                if st:
                    stats.append(st)
            else:
                for i in range(count):
                    st = _collect_file_stats(key, scene_root, kind, i)
                    if st:
                        stats.append(st)
        out[key] = stats
    return out


def assess_scene(
    scene_key: str,
    stats: List[AssetStat],
    profile: Dict[str, Dict[str, Dict[str, float]]],
    reference_scenes: Sequence[str],
    thresholds: Dict[str, float],
) -> Dict:
    actual = { _to_lookup_key(s): s for s in stats }

    missing: List[str] = []
    for kind, count in REQUIRED.items():
        if count == 1:
            if kind not in actual:
                missing.append(f"{kind}.png")
        else:
            for i in range(count):
                key = f"{kind}-{i}"
                if key not in actual:
                    missing.append(f"{key}.png")

    issues: List[str] = []
    metric_records = {}

    for key, st in actual.items():
        base = profile.get(key, {})
        rec = {
            "ratio": st.ratio,
            "fill_ratio": st.fill_ratio,
            "edge_touch_ratio": st.edge_touch_ratio,
            "bbox_ratio": st.bbox_ratio,
            "bbox_fill_ratio": st.bbox_fill_ratio,
        }

        def diff(metric: str, sample: float, ref_metric: str = None):
            metric = metric
            return sample, None

        if "ratio" in base:
            b = base["ratio"]["median"]
            d = abs(st.ratio - b) / max(0.000001, b)
            rec["ratio_drift_vs_median"] = d
            if d > thresholds["ratio_drift"]:
                issues.append(f"{key}比例偏离基准较大: {st.ratio:.4f} vs {b:.4f}")

        if "fill" in base:
            b = base["fill"]["median"]
            d = abs(st.fill_ratio - b) / max(0.000001, b)
            rec["fill_drift_vs_median"] = d
            if d > thresholds["fill_drift"]:
                issues.append(f"{key}透明占比偏离基准较大: {st.fill_ratio:.4f} vs {b:.4f}")

        if st.edge_touch_ratio > thresholds["edge_touch_ratio"]:
            issues.append(f"{key}存在贴边像素: {st.edge_touch_ratio:.2%}")

        if st.anchor_x is not None and st.anchor_y is not None:
            if not (0.0 <= st.anchor_x <= 1.0 and 0.0 <= st.anchor_y <= 1.0):
                issues.append(f"{key}锚点越界: ({st.anchor_x:.3f},{st.anchor_y:.3f})")
            if st.anchor_y < thresholds["anchor_bottom_min"]:
                issues.append(f"{key}锚点底部偏高: {st.anchor_y:.3f}")

        if st.seam_lr_mean is not None:
            if st.seam_lr_mean > thresholds["seam_lr"]:
                issues.append(f"{key}左右接缝不连续: {st.seam_lr_mean:.2f}")
            rec["seam_lr"] = st.seam_lr_mean
            rec["seam_tb"] = st.seam_tb_mean
            rec["seam_alpha"] = st.seam_alpha_mean
            if st.seam_tb_mean is not None and st.seam_tb_mean > thresholds["seam_tb"]:
                issues.append(f"{key}上下接缝不连续: {st.seam_tb_mean:.2f}")
            if st.seam_alpha_mean is not None and st.seam_alpha_mean > thresholds["seam_alpha"]:
                issues.append(f"{key}Alpha接缝不连续: {st.seam_alpha_mean:.3f}")

        metric_records[key] = rec

    # 标准场景与非标准场景标记
    status = "ok"
    if missing or issues:
        status = "need_attention"

    return {
        "scene": scene_key,
        "status": status,
        "missing": missing,
        "issues": issues,
        "metrics": metric_records,
        "is_reference": scene_key in set(reference_scenes),
        "files": [s.file for s in stats],
    }


def _export_csv(out_path: Path, measurements: Dict[str, List[AssetStat]], scene_reports: List[dict], scenes: Sequence[dict]):
    status_map = {r["scene"]: r["status"] for r in scene_reports}
    with out_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "scene", "kind", "index", "file", "width", "height", "ratio", "fill_ratio",
            "edge_touch_ratio", "edge_touch_pixels", "bbox_ratio", "bbox_fill_ratio",
            "bbox_x0", "bbox_y0", "bbox_x1", "bbox_y1", "anchor_x", "anchor_y",
            "seam_lr", "seam_tb", "seam_alpha", "status"
        ])
        for scene in scenes:
            sid = scene["id"]
            for st in measurements.get(sid, []):
                w.writerow([
                    sid,
                    st.kind,
                    "" if st.index is None else st.index,
                    st.file,
                    st.width,
                    st.height,
                    f"{st.ratio:.6f}",
                    f"{st.fill_ratio:.6f}",
                    f"{st.edge_touch_ratio:.6f}",
                    st.edge_touch_pixels,
                    "" if st.bbox_ratio is None else f"{st.bbox_ratio:.6f}",
                    "" if st.bbox_fill_ratio is None else f"{st.bbox_fill_ratio:.6f}",
                    st.bbox_x0, st.bbox_y0, st.bbox_x1, st.bbox_y1,
                    "" if st.anchor_x is None else f"{st.anchor_x:.6f}",
                    "" if st.anchor_y is None else f"{st.anchor_y:.6f}",
                    "" if st.seam_lr_mean is None else f"{st.seam_lr_mean:.6f}",
                    "" if st.seam_tb_mean is None else f"{st.seam_tb_mean:.6f}",
                    "" if st.seam_alpha_mean is None else f"{st.seam_alpha_mean:.6f}",
                    status_map.get(sid, "missing")
                ])


def _export_md(out_path: Path, report: Dict):
    lines = ["# 童话场景资产标准差异与接缝检查报告", "", f"- 总场景数：{report['summary']['total_scenes']}", f"- 参考场景数：{len(report['summary']['reference_scenes'])}"]
    lines.append(f"- 参考场景：{', '.join(report['summary']['reference_scenes'])}")
    lines.append(f"- 通过场景：{len(report['summary']['passed'])}")
    lines.append(f"- 需要关注：{len(report['summary']['need_attention'])}")

    if report['summary']['missing_anchors']:
        lines.extend(["", "## 缺少 anchors.json", ""])
        for sid in report['summary']['missing_anchors']:
            lines.append(f"- {sid}")

    lines.extend(["", "## 需要补充的资产", ""])
    for item in report['scenes']:
        if not item['missing']:
            continue
        lines.append(f"### {item['scene']}")
        for miss in item['missing']:
            lines.append(f"- 补充：{miss}")

    lines.extend(["", "## 质量问题（按场景）", ""])
    for item in report['scenes']:
        if item['status'] != 'need_attention':
            continue
        if item['is_reference']:
            lines.append(f"### {item['scene']}（参考场景）")
        else:
            lines.append(f"### {item['scene']}")
        if item['issues']:
            for issue in item['issues']:
                lines.append(f"- {issue}")
        elif item['missing']:
            lines.append("- 缺文件")
        else:
            lines.append("- 无")

    out_path.write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(
        description="按6套基准场景，计算18套场景资产差异/比例/接缝/拼接风险"
    )
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--assets-root", default=str(DEFAULT_ASSETS_ROOT))
    parser.add_argument("--reference", action="append", help="手动指定基准场景ID（可重复），默认按每个 parent 取第一场景")
    parser.add_argument("--ratio-drift", type=float, default=0.25, help="比例差异阈值")
    parser.add_argument("--fill-drift", type=float, default=0.30, help="透明占比差异阈值")
    parser.add_argument("--edge-touch-ratio", type=float, default=0.035, help="贴边像素占比阈值")
    parser.add_argument("--anchor-bottom-min", type=float, default=0.85, help="底部锚点阈值（防止离地偏高）")
    parser.add_argument("--seam-lr", type=float, default=12.0, help="左右接缝RGB均差阈值")
    parser.add_argument("--seam-tb", type=float, default=12.0, help="上下接缝RGB均差阈值")
    parser.add_argument("--seam-alpha", type=float, default=0.12, help="接缝Alpha差值阈值")
    parser.add_argument("--out-json", default=str(DEFAULT_JSON_OUT))
    parser.add_argument("--out-csv", default=str(DEFAULT_CSV_OUT))
    parser.add_argument("--out-md", default=str(DEFAULT_MD_OUT))

    args = parser.parse_args()

    manifest = _read_json(Path(args.manifest))
    if not manifest or not isinstance(manifest.get("scenes"), list):
        raise RuntimeError("无法读取清单文件：art/fairytales/manifest.json")

    scenes: List[dict] = manifest["scenes"]

    reference_scenes = args.reference if args.reference else pick_default_references(scenes)
    reference_scenes = list(dict.fromkeys(reference_scenes))  # 去重并保持顺序

    measurements = collect_measurements(Path(args.assets_root), scenes)
    profile = build_reference_profile(measurements, reference_scenes)

    thresholds = {
        "ratio_drift": args.ratio_drift,
        "fill_drift": args.fill_drift,
        "edge_touch_ratio": args.edge_touch_ratio,
        "anchor_bottom_min": args.anchor_bottom_min,
        "seam_lr": args.seam_lr,
        "seam_tb": args.seam_tb,
        "seam_alpha": args.seam_alpha,
    }

    scene_reports = [
        assess_scene(scene["id"], measurements.get(scene["id"], []), profile, reference_scenes, thresholds)
        for scene in scenes
    ]

    passed = [r["scene"] for r in scene_reports if r["status"] == "ok"]
    need_attention = [r["scene"] for r in scene_reports if r["status"] != "ok"]
    missing_anchors = [scene["id"] for scene in scenes if not (Path(args.assets_root) / scene["id"] / "anchors.json").exists()]

    report = {
        "summary": {
            "total_scenes": len(scenes),
            "reference_scenes": reference_scenes,
            "passed": passed,
            "need_attention": need_attention,
            "missing_anchors": missing_anchors,
            "thresholds": thresholds,
            "profiles_assets": {k: {m: v for m, v in stats.items()} for k, stats in profile.items()},
        },
        "scenes": scene_reports,
    }

    out_json = Path(args.out_json)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    out_csv = Path(args.out_csv)
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    _export_csv(out_csv, measurements, scene_reports, scenes)

    out_md = Path(args.out_md)
    out_md.parent.mkdir(parents=True, exist_ok=True)
    _export_md(out_md, report)

    print(f"已生成: {out_json}")
    print(f"已生成: {out_csv}")
    print(f"已生成: {out_md}")
    print(f"通过: {len(passed)}，关注: {len(need_attention)}")


if __name__ == "__main__":
    main()
