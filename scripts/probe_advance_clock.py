# -*- coding: utf-8 -*-
"""验证"直接前进"按钮与岔路两段计时：普通一程 +2h，岔路一程 +4h。"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

import websocket

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9347
URL = "http://127.0.0.1:8765/index.html"
OUT = "shots"

mid = 0


def send(ws, method, params=None):
    global mid
    mid += 1
    ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
    while True:
        msg = json.loads(ws.recv())
        if msg.get("id") == mid:
            return msg.get("result", {})


def ev(ws, expr):
    r = send(ws, "Runtime.evaluate", {"expression": expr, "returnByValue": True, "awaitPromise": True})
    if "exceptionDetails" in r:
        return {"error": str(r["exceptionDetails"])[:300]}
    return r.get("result", {}).get("value")


def shot(ws, name):
    r = send(ws, "Page.captureScreenshot", {"format": "png"})
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(base64.b64decode(r["data"]))
    print("shot:", name)


SNAP = "JSON.stringify((() => { const s = __corridorSnap(); return { camZ: Math.round(s.camZ), hour: s.hour, fork: s.fork, traveling: s.traveling }; })())"


def main():
    os.makedirs(OUT, exist_ok=True)
    profile = os.path.join(tempfile.gettempdir(), "advance-clock-probe")
    if os.path.isdir(profile):
        import shutil
        shutil.rmtree(profile, ignore_errors=True)
    proc = subprocess.Popen([
        CHROME, "--headless=new", f"--remote-debugging-port={PORT}",
        "--remote-allow-origins=*", "--window-size=1280,800", "--hide-scrollbars",
        f"--user-data-dir={profile}", "--no-first-run", "about:blank",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws_url = None
        for _ in range(60):
            try:
                tabs = json.loads(urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json", timeout=1).read())
                pages = [t for t in tabs if t.get("type") == "page"]
                if pages:
                    ws_url = pages[0]["webSocketDebuggerUrl"]
                    break
            except Exception:
                pass
            time.sleep(0.3)
        ws = websocket.create_connection(ws_url, timeout=60)
        send(ws, "Page.enable")
        send(ws, "Runtime.enable")
        send(ws, "Page.navigate", {"url": URL})
        time.sleep(3.5)
        ev(ws, "(() => { for (let i = localStorage.length - 1; i >= 0; i--) { const k = localStorage.key(i); if (k && k.startsWith('dao-')) localStorage.removeItem(k); } location.reload(); return 1; })()")
        time.sleep(3.5)

        print("start:", ev(ws, SNAP))
        btn = ev(ws, "!!document.getElementById('btn-advance') && !document.getElementById('btn-advance').disabled")
        print("btn-advance clickable:", btn)

        for i in range(1, 7):
            ev(ws, "document.getElementById('btn-advance').click(); 1")
            chosen = False
            for _ in range(50):
                time.sleep(0.5)
                s = json.loads(ev(ws, SNAP))
                if s["fork"] == "choosing" and not chosen:
                    print(f"  travel {i}: fork choosing, hour={s['hour']}")
                    shot(ws, f"advance-fork-{i}.png")
                    ev(ws, "document.querySelector('.corridor-fork-panel button').click(); 1")
                    chosen = True
                if not s["traveling"] and s["fork"] == "hidden":
                    break
            s = json.loads(ev(ws, SNAP))
            print(f"travel {i}: hour={s['hour']} camZ={s['camZ']} (forked={chosen})")
        shot(ws, "advance-final.png")
        ws.close()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except Exception:
            proc.kill()


if __name__ == "__main__":
    main()
