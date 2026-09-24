"""Audit existing runtime assets for reusable roof/ceiling connection candidates.

The audit is intentionally conservative. A filename or metadata token only makes
an asset a candidate; it never marks the asset suitable for a closed scene until
the asset contract and a native screenshot prove the sockets/opening semantics.
"""
from __future__ import annotations

import json
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - the audit can still list paths
    Image = None


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOTS = [ROOT / "godot/assets", ROOT / "art/world-six"]
OUTPUT = ROOT / "docs/design/SCENE3D-ROOF-REUSE-AUDIT-2026-09-21.json"
TOKENS = ("roof", "ceiling", "arch", "拱", "顶", "wall_top", "shell")
KNOWN_NOTES = {
    "godot/assets/biomes/palace/shell.png": "完整石拱门壳候选；视觉上有连续侧墙与拱圈，但仍需SceneProfile sockets/footprints和原机位闭合证据。",
    "godot/assets/biomes/sewer/shell.png": "连续下水道拱廊候选；可作为sewer类结构参考，不自动替代童话场景的风格资产。",
    "godot/assets/biomes/crystal/shell.png": "水晶矿洞壳候选；需要验证入口到洞内的截面连续和接地能力。",
    "godot/assets/biomes/crystal/shell-v3.png": "水晶矿洞壳候选；与shell.png需要先做hash/版本去重，不能当作两个变体。",
    "godot/assets/cave/arch-a.png": "洞口拱形装饰候选；单张拱片不等于连续洞顶。",
    "godot/assets/cave/arch-b.png": "洞口拱形装饰候选；单张拱片不等于连续洞顶。",
}


def token_match(value: str) -> list[str]:
    lower = value.lower()
    return [token for token in TOKENS if token.lower() in lower]


def main() -> None:
    candidates = []
    seen = set()
    for root in ASSET_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".png", ".jpg", ".jpeg", ".json", ".tres", ".tscn"}:
                continue
            rel = path.relative_to(ROOT).as_posix()
            matches = token_match(rel)
            if path.suffix.lower() == ".json":
                try:
                    matches.extend(token_match(path.read_text(encoding="utf-8", errors="ignore")[:200000]))
                except OSError:
                    pass
            matches = sorted(set(matches))
            if not matches or rel in seen:
                continue
            seen.add(rel)
            row = {
                "path": rel,
                "matched_tokens": matches,
                "candidate_class": "existing_biome_shell_candidate" if path.name.lower().startswith("shell") else "token_match_only",
                "candidate_only": True,
                "runtime_approved": False,
                "reason": "token match has no proof of continuous top surface, sockets, opening polygon, contact or closed-scene screenshot",
            }
            if rel in KNOWN_NOTES:
                row["manual_candidate_note"] = KNOWN_NOTES[rel]
            if Image is not None and path.suffix.lower() == ".png":
                try:
                    with Image.open(path) as image:
                        rgba = image.convert("RGBA")
                        alpha = rgba.getchannel("A")
                        bounds = alpha.getbbox()
                        row["image_size_px"] = list(rgba.size)
                        row["alpha_bounds_px"] = list(bounds) if bounds else None
                        row["center_column_alpha_pixels"] = sum(
                            1 for y in range(rgba.height) if alpha.getpixel((rgba.width // 2, y)) > 8
                        )
                except OSError:
                    row["image_probe_error"] = True
            candidates.append(row)
    candidates.sort(key=lambda item: item["path"])
    payload = {
        "schema_version": 1,
        "scope": "conservative existing-asset roof/ceiling reuse audit",
        "tokens": list(TOKENS),
        "roots": [root.relative_to(ROOT).as_posix() for root in ASSET_ROOTS if root.exists()],
        "candidate_count": len(candidates),
        "runtime_approved_count": 0,
        "conclusion": "No candidate is runtime-approved by this filename/metadata audit; every candidate still needs AssetSpec and native closed-scene evidence.",
        "candidates": candidates,
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SCENE3D_ROOF_REUSE_AUDIT candidates={len(candidates)} runtime_approved=0 output={OUTPUT}")


if __name__ == "__main__":
    main()
