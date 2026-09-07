"""Run native sample checks, retain exact logs, and verify original asset provenance."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
TESTS = ("test_routes", "test_sky", "test_interaction", "test_spaces", "test_battle", "test_world", "test_battle_ui", "test_navigation", "test_journey", "test_home", "test_continuous_battle", "test_tile_routes")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", default=shutil.which("godot.exe"))
    parser.add_argument("--render", action="store_true", help="Also run real-GPU sample capture; opens a temporary game window")
    args = parser.parse_args()
    if not args.engine:
        parser.error("Godot not found; pass --engine with the tested executable")
    engine = Path(args.engine)
    consoles = sorted(engine.parent.glob("*_console.exe"))
    if consoles:
        engine = consoles[0]
    output = ROOT / "godot/captures/validation"
    output.mkdir(parents=True, exist_ok=True)
    report = {"engine": str(engine), "checks": [], "assets": 0, "source_hashes": {}}
    imported = subprocess.run([str(engine), "--headless", "--editor", "--path", str(ROOT / "godot"), "--quit"], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    import_log = imported.stdout + imported.stderr
    (output / "import.log").write_text(import_log, encoding="utf-8")
    report["import_passed"] = imported.returncode == 0 and "ERROR:" not in import_log
    for source in ("world-demo.html", "js/corridor.js", "js/world-fog.js"):
        report["source_hashes"][source] = hashlib.sha256((ROOT / source).read_bytes()).hexdigest()
    maps = json.loads((ROOT / "godot/data/world_samples.json").read_text(encoding="utf-8"))
    if maps["sha256"] != report["source_hashes"]["world-demo.html"]:
        raise RuntimeError("Original world source changed; regenerate reference samples before comparison")
    manifest = json.loads((ROOT / "godot/assets/manifest.json").read_text(encoding="utf-8"))
    for entry in manifest["files"]:
        source = (ROOT / entry["source"]).read_bytes()
        destination = (ROOT / entry["destination"]).read_bytes()
        if source != destination or hashlib.sha256(source).hexdigest() != entry["sha256"]:
            raise RuntimeError("Asset provenance mismatch: " + entry["source"])
        report["assets"] += 1
    generated = json.loads((ROOT / "godot/assets/generated-manifest.json").read_text(encoding="utf-8-sig"))
    for entry in generated["files"]:
        source = (ROOT / entry["source"]).read_bytes()
        destination = (ROOT / entry["destination"]).read_bytes()
        if source != destination or hashlib.sha256(source).hexdigest() != entry["sha256"]:
            raise RuntimeError("Generated asset provenance mismatch: " + entry["source"])
        if not (ROOT / entry["prompt"]).read_text(encoding="utf-8").strip():
            raise RuntimeError("Missing generated asset prompt")
    report["generated_assets"] = len(generated["files"])
    prepared = json.loads((ROOT / "godot/assets/prepared/manifest.json").read_text(encoding="utf-8"))
    for path, expected in prepared["inputs"].items():
        if hashlib.sha256((ROOT / "godot" / path.removeprefix("res://")).read_bytes()).hexdigest() != expected:
            raise RuntimeError("Prepared art is stale; run tests/bake_forest_art.gd: " + path)
    if hashlib.sha256((ROOT / "godot/assets/prepared/forest_art.res").read_bytes()).hexdigest() != prepared["output_sha256"]:
        raise RuntimeError("Prepared art output hash mismatch")
    specs = [(test, True) for test in TESTS] + [("test_prepared_art", True)]
    if args.render:
        specs.append(("capture_modules", False))
        specs.append(("capture_journey", False))
        specs.append(("capture_home", False))
        specs.append(("capture_continuous_battle", False))
        specs.append(("capture_ui_review", False))
        specs.append(("test_tile_routes", False))
    for name, headless in specs:
        cmd = [str(engine), "--path", str(ROOT / "godot")]
        if headless:
            cmd.append("--headless")
        cmd += ["--script", f"res://tests/{name}.gd"]
        began = time.monotonic()
        result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
        log = result.stdout + result.stderr
        (output / (name + ".log")).write_text(log, encoding="utf-8")
        passed = result.returncode == 0 and "PASS" in log and "ERROR:" not in log
        report["checks"].append({"name": name, "passed": passed, "exit_code": result.returncode, "seconds": round(time.monotonic()-began, 3)})
        print(("PASS " if passed else "FAIL ") + name, flush=True)
    passed = report["import_passed"] and all(check["passed"] for check in report["checks"])
    report["passed"] = passed
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Verified {report['assets']} unchanged assets. Report: {output / 'report.json'}", flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
