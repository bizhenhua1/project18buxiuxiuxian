"""Bounded native-render smoke checks for the restored six-theme entry."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for index, theme in enumerate(["forest", "crystal", "swamp", "sewer", "whale", "palace"]):
        for mode in ["2D", "3D"]:
            folder = args.output / f"{theme}-{mode}"
            folder.mkdir(parents=True, exist_ok=True)
            command = [args.engine, "--path", str(root / "godot"), "--resolution", "1280x800",
                       "--script", "res://tests/test_original_six_recovery.gd", "--",
                       f"--theme={theme}", f"--output={folder.as_posix()}"]
            if mode == "2D":
                command.append("--2d")
            if index % 2:
                command.extend(["--two", "--right"])
            with (folder / "engine.log").open("w", encoding="utf-8") as log:
                try:
                    run = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                         timeout=150, creationflags=subprocess.CREATE_NO_WINDOW)
                    code = run.returncode
                except subprocess.TimeoutExpired:
                    code = -1
            log_text = (folder / "engine.log").read_text(encoding="utf-8", errors="replace")
            passed = (code == 0 and "ORIGINAL_SIX_RECOVERY_PASS" in log_text
                      and "SCRIPT ERROR" not in log_text and "ERROR:" not in log_text)
            results.append({"theme": theme, "mode": mode, "passed": passed, "exit_code": code,
                            "report": str(folder / "result.json"), "log": str(folder / "engine.log")})
            (args.output / "summary.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
            print(f"{theme} {mode}: {'PASS' if passed else 'FAIL'}", flush=True)
            if not passed:
                print(log_text[-4000:], flush=True)
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
