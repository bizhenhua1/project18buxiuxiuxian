# -*- coding: utf-8 -*-
"""用 CDP Input.dispatchMouseEvent 发真实鼠标事件，验证拖放「落点即意图」：
法宝拖到手持格→held、拖到法宝格→station、非法格位→提示回池；
入阵后按格位排型自动归位（同类靠左）；拖动中悬停高亮出现。"""
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
PORT = 9335
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

def rect_of(ws, selector):
    """元素中心视口坐标；池卡可能滚出视口，先滚到可见再取。"""
    return ev(ws, f"(() => {{ const el = document.querySelector(\"{selector}\"); if (!el) return null; el.scrollIntoView({{ block: 'center' }}); const r = el.getBoundingClientRect(); return {{ x: r.x + r.width/2, y: r.y + r.height/2 }}; }})()")

def drag_real(ws, x0, y0, x1, y1, steps=8, mid_eval=None):
    """真实鼠标拖放：按下→分步移动→（中途可评估悬停态）→松开。返回中途评估结果。"""
    send(ws, "Input.dispatchMouseEvent", {"type": "mousePressed", "x": x0, "y": y0, "button": "left", "clickCount": 1})
    for i in range(1, steps + 1):
        send(ws, "Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x0 + (x1 - x0) * i / steps, "y": y0 + (y1 - y0) * i / steps, "button": "left"})
    hover = ev(ws, mid_eval) if mid_eval else None
    send(ws, "Input.dispatchMouseEvent", {"type": "mouseReleased", "x": x1, "y": y1, "button": "left", "clickCount": 1})
    return hover

def queue_state(ws):
    return ev(ws, "JSON.stringify(window.__dao.state.playerQueue.map(u => [u.cardId, u.cardType, u.mode || '', u.index]))")

def main():
    profile = os.path.join(tempfile.gettempdir(), "dragdrop-probe-profile")
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
        # 开手持格（体修 b1/b2：手持 2 格、重量 5）并上道童
        print("setup:", ev(ws, "(() => { window.__dao.setStage(12); document.getElementById('btn-talents').click(); const click = id => document.querySelector(`.tnode[data-id=\"${id}\"]`).dispatchEvent(new MouseEvent('click',{bubbles:true})); ['b1','b2'].forEach(click); document.getElementById('talent-close').click(); window.__dao.place('daotong'); return JSON.stringify({ slots: window.__dao.slots(), queue: window.__dao.state.playerQueue.length }); })()"))

        # 1) 真实拖放：青锋剑（法宝）→ 手持格 → 应以 held 入阵，且拖动中出现高亮
        src = rect_of(ws, ".pool-card[data-card-id='qingfeng-jian']")
        dst = rect_of(ws, "#player-slots .slot.st-weapon")
        hover = drag_real(ws, src["x"], src["y"], dst["x"], dst["y"],
                          mid_eval="JSON.stringify({ hint: !!document.querySelector('#player-slots .slot.st-weapon.drop-hint'), bad: !!document.querySelector('#player-slots .slot.drop-bad') })")
        time.sleep(0.3)
        print("drag fabao->weapon hover:", hover)
        print("after held drop:", queue_state(ws), "| heldBadge:", ev(ws, "!!document.querySelector('.unit-card.held .held-badge')"))
        shot(ws, "dd01_drop_held.png")

        # 2) 真实拖放：桃木剑 → 法宝格 → station，且排型自动归位（char, station, held）
        src = rect_of(ws, ".pool-card[data-card-id='taomu-jian']")
        dst = rect_of(ws, "#player-slots .slot.st-fabao:not(.occupied)")
        drag_real(ws, src["x"], src["y"], dst["x"], dst["y"])
        time.sleep(0.3)
        print("after station drop:", queue_state(ws))
        shot(ws, "dd02_drop_station_sorted.png")

        # 3) 非法落点：离火术（识海法术，识海格未开）→ 手持格 → 警示高亮 + 回池 + 状态栏提示
        src = rect_of(ws, ".pool-card[data-card-id='lihuo-shu']")
        dst = rect_of(ws, "#player-slots .slot.st-weapon:not(.occupied)")
        hover = drag_real(ws, src["x"], src["y"], dst["x"], dst["y"],
                          mid_eval="JSON.stringify({ bad: !!document.querySelector('#player-slots .slot.drop-bad'), hint: !!document.querySelector('#player-slots .slot.drop-hint') })")
        time.sleep(0.3)
        print("drag spell->weapon hover:", hover)
        print("after invalid drop:", queue_state(ws), "| status:", ev(ws, "document.getElementById('outcome')?.textContent"))
        shot(ws, "dd03_invalid_back_to_pool.png")

        # 4) 场上法宝拖到异模式格位 = held↔station 切换：把 held 青锋剑拖到空法宝格
        src = rect_of(ws, ".unit-card.held")
        dst = rect_of(ws, "#player-slots .slot.st-fabao:not(.occupied)")
        drag_real(ws, src["x"], src["y"], dst["x"], dst["y"])
        time.sleep(0.3)
        print("after move held->fabao slot:", queue_state(ws))
        shot(ws, "dd04_move_mode_switch.png")
        ws.close()
    finally:
        proc.kill()

if __name__ == "__main__":
    main()
