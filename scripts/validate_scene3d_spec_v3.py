"""Validate the design package, not runtime assets or scene visual quality.

Requires jsonschema. Deliberately does not render, benchmark or publish anything.
"""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / "docs/design"


def read(name):
    return json.loads((DESIGN / name).read_text(encoding="utf-8-sig"))


def main():
    plan = read("SCENE3D-PRODUCTION-PLAN-V3.json")
    schema = read("SCENE3D-ASSET-CONTRACT-V2.schema.json")
    examples = read("SCENE3D-ASSET-CONTRACT-V2.examples.json")
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)
    for item in examples["valid"]:
        validator.validate(item)
    for case in examples["negative_cases"]:
        item = copy.deepcopy(examples["valid"][case["base"]])
        for key, value in case["set"].items():
            target = item
            parts = key.split(".")
            for part in parts[:-1]:
                target = target[part]
            target[parts[-1]] = value
        assert not validator.is_valid(item), f"Negative fixture incorrectly passed: {case['name']}"

    task_ids = {t["id"] for t in plan["tasks"]}
    assert len(task_ids) == len(plan["tasks"])
    done = set()
    while len(done) < len(task_ids):
        ready = {t["id"] for t in plan["tasks"] if set(t["depends"]) <= done}
        assert ready - done, "Missing dependency or cyclic task graph"
        done |= ready
    assert all(t["status"] == "todo" for t in plan["tasks"]), "Documentation revision must not claim implementation"

    old_ids = set()
    for name in ("SCENE3D-ASTRA-ISSUE-LEDGER-2026-09-21.json", "SCENE3D-VISUAL-MISALIGNMENT-ISSUES-2026-09-21.json"):
        old_ids.update(i["id"] for i in read(name)["issues"])
    new_ids = {i["id"] for i in plan["issues"]}
    assert old_ids == new_ids and len(new_ids) == 21, (old_ids - new_ids, new_ids - old_ids)
    decision_text = (DESIGN / "SCENE3D-ISSUE-DECISIONS-V3.md").read_text(encoding="utf-8")
    for issue in plan["issues"]:
        assert issue["id"] in decision_text
        assert set(issue["tasks"]) <= task_ids

    scenes = plan["scenes"]
    scene_ids = {s["id"] for s in scenes}
    old_scenes = {s["scene"] for s in read("SCENE3D-LUNA-TASKS.json")["scene_assignments"]}
    assert len(scenes) == len(scene_ids) == 18 and scene_ids == old_scenes
    recipe_text = (DESIGN / "SCENE3D-SCENE-RECIPES-V3.md").read_text(encoding="utf-8")
    for s in scenes:
        assert f"## {s['recipe']}. {s['id']} " in recipe_text
        assert s["representative"] in scene_ids
        assert s["cadence_m"][0] <= s["initial_m"] <= s["cadence_m"][1]
        assert (ROOT / "godot/assets/fairytales" / s["id"] / "dressing.json").exists()
    assert {s["family"] for s in scenes} == {"interior", "cave", "garden", "street", "bridge", "stage", "clock"}

    spatial = read("SCENE3D-SPATIAL-PRESETS-V3.1.json")
    mapped = [scene for p in spatial["presets"] for scene in p["scenes"]]
    assert len(mapped) == len(set(mapped)) == 18 and set(mapped) == scene_ids
    roof_map = {"open":"open", "local_canopy":"local_canopy", "low_ceiling":"closed_low_ceiling", "vaulted":"closed_arch", "irregular_tube":"cave_shell"}
    scene_by_id = {s["id"]: s for s in scenes}
    for p in spatial["presets"]:
        for scene in p["scenes"]:
            actual = dict(p, **p.get("scene_overrides", {}).get(scene, {}))
            assert roof_map[actual["enclosure"]] == scene_by_id[scene]["roof_mode"]
    assert spatial["hanging_module"]["hanging_figure_auto_populate"] is False
    assert spatial["old_goal_audit"]["goal_system_mutated"] is False
    old_tasks = read("SCENE3D-LUNA-TASKS.json")["tasks"]
    assert all(t["status"] == "superseded" and "historical_status" in t for t in old_tasks)

    links_checked = 0
    for relative in [plan["entry"], *plan["documents"]]:
        path = ROOT / relative
        assert path.exists(), relative
        contents = path.read_text(encoding="utf-8")
        for link in re.findall(r"\]\(([^)]+)\)", contents):
            if "://" in link or link.startswith("#"):
                continue
            target = link.split("#", 1)[0]
            assert (path.parent / target).exists(), (relative, link)
            links_checked += 1
    assert (ROOT / plan["asset_schema"]).exists()
    assert plan["current_scope"] == "documentation_only"
    assert plan["image_generation_in_current_scope"] is False
    print(json.dumps({
        "scope":"specification package only; no runtime or visual validation",
        "result":"PASS", "scenes":len(scenes), "issues":len(new_ids),
        "tasks":len(task_ids), "local_links":links_checked,
        "spatial_presets":len(spatial["presets"]), "old_tasks_archived":len(old_tasks),
        "valid_fixtures":len(examples["valid"]),
        "rejected_invalid_fixtures":len(examples["negative_cases"])
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
