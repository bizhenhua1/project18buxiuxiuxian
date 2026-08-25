# -*- coding: utf-8 -*-
"""真实鼠标探针：境界突破（dao11）。
灌满炼气九层 → 修为封顶显示「圆满」→ 突破按钮出现 → 真实鼠标点击 →
进入筑基一层、道童攻血 ×1.02×1.10（突破那层+2% 与突破+10% 复利）、悟性 +1。"""
import base64
import json
import os
import subprocess
import tempfile
import time
import urllib.request

import websocket

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9337
URL = "http://localhost:8000/index.html"
OUT = "scripts/shots"

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
    return r.get("result", {}).get("value")

def shot(ws, name):
    r = send(ws, "Page.captureScreenshot", {"format": "png"})
    path = os.path.join(OUT, name)
    with open(path, "wb") as f:
        f.write(base64.b64decode(r["data"]))
    print("shot:", path)

def main():
    profile = os.path.join(tempfile.gettempdir(), "breakthrough-probe-profile")
    proc = subprocess.Popen([
        CHROME, "--headless=new", f"--remote-debugging-port={PORT}",
        "--remote-allow-origins=*", "--window-size=1280,800",
        "--hide-scrollbars", "--force-device-scale-factor=1",
        f"--user-data-dir={profile}", "--no-first-run", "about:blank",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws_url = None
        for _ in range(50):
            try:
                tabs = json.loads(urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json", timeout=1).read())
                pages = [t for t in tabs if t.get("type") == "page"]
                if pages:
                    ws_url = pages[0]["webSocketDebuggerUrl"]
                    break
            except Exception:
                pass
            time.sleep(0.3)
        ws = websocket.create_connection(ws_url, timeout=30)
        send(ws, "Page.enable")
        send(ws, "Runtime.enable")
        send(ws, "Page.navigate", {"url": URL})
        time.sleep(3.5)
        ev(ws, "(() => { for (let i = localStorage.length - 1; i >= 0; i--) { const k = localStorage.key(i); if (k && k.startsWith('dao-')) localStorage.removeItem(k); } location.reload(); return 1; })()")
        time.sleep(3.5)

        # 灌到炼气圆满：多灌验证圆满封顶（溢出丢弃）
        print("fill to full:", ev(ws, "(() => { const p = window.__dao; p.resetRealm(); const r = p.addExp(10000); const char = p.state.playerQueue.find(u => u.cardType === 'char'); window.__before = { maxHp: char.maxHp, atk: char.atk, talentBtn: document.getElementById('btn-talents').textContent }; return JSON.stringify({ ...r, uiNum: document.getElementById('realm-exp-num').textContent, btnVisible: !document.getElementById('btn-breakthrough').hidden, before: window.__before }); })()"))
        shot(ws, "bt01_full_button.png")

        # 圆满后修为不再累积
        print("cap check:", ev(ws, "JSON.stringify(window.__dao.addExp(500))"))

        # 真实鼠标点击「突破境界」
        r = ev(ws, "(() => { const b = document.getElementById('btn-breakthrough'); const r = b.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; })()")
        send(ws, "Input.dispatchMouseEvent", {"type": "mousePressed", "x": r["x"], "y": r["y"], "button": "left", "clickCount": 1})
        send(ws, "Input.dispatchMouseEvent", {"type": "mouseReleased", "x": r["x"], "y": r["y"], "button": "left", "clickCount": 1})
        time.sleep(0.4)
        print("after click:", ev(ws, "(() => { const p = window.__dao; const r = p.realm(); const char = p.state.playerQueue.find(u => u.cardType === 'char'); const ratio = char.maxHp / window.__before.maxHp; return JSON.stringify({ realm: r.title, stage: r.stage, layer: r.layer, exp: r.exp, btnHidden: document.getElementById('btn-breakthrough').hidden, maxHp: [window.__before.maxHp, char.maxHp], atk: [window.__before.atk, char.atk], ratio: +ratio.toFixed(4), gainOk: ratio > 1.10 && ratio < 1.14, talentBtn: [window.__before.talentBtn, document.getElementById('btn-talents').textContent], status: document.getElementById('outcome').textContent }); })()"))
        shot(ws, "bt02_after_breakthrough.png")
        ws.close()
    finally:
        proc.kill()

if __name__ == "__main__":
    main()
