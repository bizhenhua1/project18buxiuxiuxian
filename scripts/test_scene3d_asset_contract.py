"""Small regression test for the conservative AssetSpec validator."""
import hashlib
import json
import tempfile
from pathlib import Path

from validate_scene3d_asset_contract import validate

ROOT = Path(__file__).resolve().parents[1]
TEXTURE = ROOT / "godot/assets/fairytales/red_cottage/ground.png"


def bundle():
    return {
        "asset_request": {
            "request_id": "test",
            "scene_id": "red_cottage",
            "physical_family": "interior",
            "role": "prop",
            "why_existing_assets_fail": "synthetic request used to verify the validator contract",
            "required_sockets": [],
            "size_source": "synthetic",
            "alpha_requirements": "clean",
            "opening_requirements": "none",
            "footprint_requirements": "triangle",
            "view_angles": ["front"],
            "palette_reference": ["ground.png"],
            "source_prompt_path": "synthetic.prompt.txt",
            "blocking_tasks": ["P03A"],
            "status": "awaiting_asset"
        },
        "asset_spec": {
            "id": "test-ground",
            "texture": "res://assets/fairytales/red_cottage/ground.png",
            "sha256": hashlib.sha256(TEXTURE.read_bytes()).hexdigest(),
            "role": "prop",
            "size_m": [10.0, 10.0],
            "anchor_uv": [0.5, 1.0],
            "footprints_m": [[[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]]],
            "opening_uv": [],
            "contact": "ground_surface",
            "sockets_m": {},
            "variant_family": "test",
            "mirror_allowed": True,
            "height_band_m": [0.0, 0.0],
            "status": "annotated"
        }
    }


def main():
    valid = bundle()
    assert validate(valid) == []
    invalid = json.loads(json.dumps(valid))
    invalid["asset_spec"]["footprints_m"] = []
    assert any("footprints_m" in message for message in validate(invalid))
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "bundle.json"
        path.write_text(json.dumps(valid), encoding="utf-8")
    print("ASSET_CONTRACT_TEST_PASS valid_case_and_missing_footprint_case")


if __name__ == "__main__":
    main()
