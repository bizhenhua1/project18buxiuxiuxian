# -*- coding: utf-8 -*-
"""Headless Chrome CDP 截图/驱动脚本。
用法: python scripts/cdp_shot.py <url> <plan.json> [--out-dir DIR]
plan 是动作数组: {"wait": ms} | {"shot": "name.png"} | {"eval": "js"} | {"key": "KeyW", "down": true/false}
"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

import websocket

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9333


def main():
    url = sys.argv[1]
    plan = json.loads(open(sys.argv[2], encoding="utf-8-sig").read())
    out_dir = sys.argv[4] if len(sys.argv) > 4 else "shots"
    os.makedirs(out_dir, exist_ok=True)

    profile = os.path.join(tempfile.gettempdir(), "corridor-cdp-profile")
    proc = subprocess.Popen([
        CHROME, "--headless=new", f"--remote-debugging-port={PORT}",
        "--remote-allow-origins=*",
        "--window-size=1280,800", "--hide-scrollbars", "--force-device-scale-factor=1",
        f"--user-data-dir={profile}", "--no-first-run", "about:blank",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws_url = None
        for _ in range(50):
            try:
                tabs = json.loads(urllib.request.urlopen(
                    f"http://127.0.0.1:{PORT}/json", timeout=1).read())
                pages = [t for t in tabs if t.get("type") == "page"]
                if pages:
                    ws_url = pages[0]["webSocketDebuggerUrl"]
                    break
            except Exception:
                pass
            time.sleep(0.2)
        if not ws_url:
            print("FAIL: no debugger url")
            sys.exit(1)

        ws = websocket.create_connection(ws_url, timeout=30)
        mid = [0]

        def cmd(method, **params):
            mid[0] += 1
            ws.send(json.dumps({"id": mid[0], "method": method, "params": params}))
            while True:
                msg = json.loads(ws.recv())
                if msg.get("id") == mid[0]:
                    return msg.get("result", {})

        cmd("Page.enable")
        cmd("Runtime.enable")
        cmd("Page.captureScreenshot", format="png")  # 预热，首次捕获很慢
        t_nav = time.time()
        cmd("Page.navigate", url=url)

        for step in plan:
            if "wait" in step:
                time.sleep(step["wait"] / 1000.0)
            elif "wait_until" in step:  # 距 navigate 的绝对毫秒
                dt = step["wait_until"] / 1000.0 - (time.time() - t_nav)
                if dt > 0:
                    time.sleep(dt)
            elif "shot" in step:
                r = cmd("Page.captureScreenshot", format="png")
                path = os.path.join(out_dir, step["shot"])
                with open(path, "wb") as f:
                    f.write(base64.b64decode(r["data"]))
                print("shot:", path, f"t={time.time() - t_nav:.2f}s")
            elif "eval" in step:
                r = cmd("Runtime.evaluate", expression=step["eval"],
                        awaitPromise=True, returnByValue=True)
                v = r.get("result", {}).get("value")
                if v is not None:
                    print("eval:", json.dumps(v, ensure_ascii=False)[:500])
            elif "key" in step:
                typ = "keyDown" if step.get("down", True) else "keyUp"
                cmd("Input.dispatchKeyEvent", type=typ, code=step["key"],
                    key=step["key"].replace("Key", ""), windowsVirtualKeyCode=0)
        ws.close()
    finally:
        proc.kill()


if __name__ == "__main__":
    main()
