# -*- coding: utf-8 -*-
"""用 CDP Input.dispatchMouseEvent 发真实鼠标事件，复现天赋树节点真实点击是否生效。"""
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

import websocket

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9334
URL = "http://localhost:8000/index.html"

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

def click_at(ws, x, y):
    for t, extra in (("mousePressed", {"button": "left", "clickCount": 1}),
                     ("mouseReleased", {"button": "left", "clickCount": 1})):
        send(ws, "Input.dispatchMouseEvent", {"type": t, "x": x, "y": y, **extra})

def drag(ws, x, y, dx, dy, steps=6):
    send(ws, "Input.dispatchMouseEvent", {"type": "mousePressed", "x": x, "y": y, "button": "left", "clickCount": 1})
    for i in range(1, steps + 1):
        send(ws, "Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x + dx * i / steps, "y": y + dy * i / steps, "button": "left"})
    send(ws, "Input.dispatchMouseEvent", {"type": "mouseReleased", "x": x + dx, "y": y + dy, "button": "left", "clickCount": 1})

def main():
    profile = os.path.join(tempfile.gettempdir(), "talent-probe-profile")
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
        print("setup:", ev(ws, "(() => { window.__dao.setStage(12); document.getElementById('btn-talents').click(); return JSON.stringify({ open: !document.querySelector('.dao-overlay').hidden }); })()"))
        rect = ev(ws, "(() => { const b1 = document.querySelector('.tnode[data-id=\"b1\"] circle'); const r = b1.getBoundingClientRect(); return { x: r.x + r.width/2, y: r.y + r.height/2 }; })()")
        print("b1 at:", rect)
        click_at(ws, rect["x"], rect["y"])
        time.sleep(0.5)
        print("after real click b1:", ev(ws, "(async () => { const m = await import('./js/talents.js?v=dao9'); return JSON.stringify({ alloc: [...m.allocatedIds()], b1: m.allocatedIds().has('b1') }); })()"))
        # 真实点击 b2（依赖 b1 相邻）
        rect2 = ev(ws, "(() => { const c = document.querySelector('.tnode[data-id=\"b2\"] circle'); const r = c.getBoundingClientRect(); return { x: r.x + r.width/2, y: r.y + r.height/2 }; })()")
        click_at(ws, rect2["x"], rect2["y"])
        time.sleep(0.3)
        print("after real click b2:", ev(ws, "(async () => { const m = await import('./js/talents.js?v=dao9'); return JSON.stringify([...m.allocatedIds()]); })()"))
        # 再点一次 b2 = 退点
        click_at(ws, rect2["x"], rect2["y"])
        time.sleep(0.3)
        print("after dealloc b2:", ev(ws, "(async () => { const m = await import('./js/talents.js?v=dao9'); return JSON.stringify([...m.allocatedIds()]); })()"))
        # 真实拖拽：从空白处拖 60px，viewBox 应平移且不误加点
        vb0 = ev(ws, "document.getElementById('talent-svg').getAttribute('viewBox')")
        drag(ws, rect["x"] + 120, rect["y"] + 120, 60, 40)
        time.sleep(0.3)
        vb1 = ev(ws, "document.getElementById('talent-svg').getAttribute('viewBox')")
        print("drag pan:", json.dumps({"before": vb0, "after": vb1, "panned": vb0 != vb1}))
        # 拖拽落点若在节点上也不应误加点（suppressClick）
        drag(ws, rect["x"] + 40, rect["y"] + 40, -40, -40)
        time.sleep(0.3)
        print("after drag-onto-node:", ev(ws, "(async () => { const m = await import('./js/talents.js?v=dao9'); return JSON.stringify([...m.allocatedIds()]); })()"))
        # 洗髓按钮
        print("respec:", ev(ws, "(async () => { document.getElementById('talent-respec').click(); const m = await import('./js/talents.js?v=dao9'); return JSON.stringify([...m.allocatedIds()]); })()"))
        ws.close()
    finally:
        proc.kill()

if __name__ == "__main__":
    main()
