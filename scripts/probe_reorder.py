# -*- coding: utf-8 -*-
"""真实鼠标探针：验证同类型组内调序（dao10）。
1) 组内左移/右移：拖放落点在组内插入，restatQueues 不把顺序顶回；
2) 追加新卡触发重排后组内相对顺序仍保留；
3) 跨类型落点即意图与 held↔station 拖放切换不回归；
4) 道童可手动移出（拖出车道），按「清空我方」等自动入口再补位。"""
import base64
import json
import os
import subprocess
import tempfile
import time
import urllib.request

import websocket

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PORT = 9336
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

def card_rect(ws, card_id):
    return ev(ws, f"(() => {{ const el = document.querySelector('.unit-card[data-card-id=\"{card_id}\"]'); if (!el) return null; const r = el.getBoundingClientRect(); return {{ left: r.left, right: r.right, w: r.width, cy: r.y + r.height / 2 }}; }})()")

def sel_rect(ws, selector):
    return ev(ws, f"(() => {{ const el = document.querySelector('{selector}'); if (!el) return null; el.scrollIntoView({{ block: 'center' }}); const r = el.getBoundingClientRect(); return {{ x: r.x + r.width / 2, y: r.y + r.height / 2, left: r.left, w: r.width }}; }})()")

def drag(ws, x0, y0, x1, y1, steps=10):
    send(ws, "Input.dispatchMouseEvent", {"type": "mousePressed", "x": x0, "y": y0, "button": "left", "clickCount": 1})
    for i in range(1, steps + 1):
        send(ws, "Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x0 + (x1 - x0) * i / steps, "y": y0 + (y1 - y0) * i / steps, "button": "left"})
    send(ws, "Input.dispatchMouseEvent", {"type": "mouseReleased", "x": x1, "y": y1, "button": "left", "clickCount": 1})
    time.sleep(0.5)  # 间隔 >350ms，避免连续拖同一张卡触发双击切模式

def queue(ws):
    return ev(ws, "JSON.stringify(window.__dao.state.playerQueue.map(u => [u.cardId, u.mode || u.cardType]))")

def main():
    profile = os.path.join(tempfile.gettempdir(), "reorder-probe-profile")
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
        print("setup:", ev(ws, "(() => { window.__dao.setStage(12); document.getElementById('btn-talents').click(); const click = id => document.querySelector(`.tnode[data-id=\"${id}\"]`).dispatchEvent(new MouseEvent('click',{bubbles:true})); ['b1','b2'].forEach(click); document.getElementById('talent-close').click(); const p = window.__dao; p.clear(); p.place('daotong'); p.place('taomu-jian','station'); p.place('qingfeng-jian','station'); p.place('xuantie-jian','station'); return JSON.stringify({ slots: p.slots() }); })()"))
    
        # 1) 组内左移：玄铁重剑(末位) → 桃木剑(组首)左半区，应插到组内第 1 位且不被顶回
        print("before:", queue(ws))
        src = card_rect(ws, "xuantie-jian")
        dst = card_rect(ws, "taomu-jian")
        drag(ws, (src["left"] + src["right"]) / 2, src["cy"], dst["left"] + dst["w"] * 0.25, dst["cy"])
        print("after move-left:", queue(ws))
        shot(ws, "ro01_move_left.png")

        # 2) 组内右移一格（原 off-by-one 场景）：玄铁 → 桃木与青锋之间
        src = card_rect(ws, "xuantie-jian")
        dst = card_rect(ws, "qingfeng-jian")
        drag(ws, (src["left"] + src["right"]) / 2, src["cy"], dst["left"] + dst["w"] * 0.2, dst["cy"])
        print("after move-right:", queue(ws))
        shot(ws, "ro02_move_right.png")

        # 3) 追加新卡触发 restatQueues：组内相对顺序应保留
        print("after add fan:", ev(ws, "(() => { window.__dao.place('juhun-fan', 'station'); return JSON.stringify(window.__dao.state.playerQueue.map(u => [u.cardId, u.mode || u.cardType])); })()"))

        # 4) 跨类型/模式切换不回归：青锋剑拖到空手持格 → held；再拖回空法宝格 → station
        src = card_rect(ws, "qingfeng-jian")
        dst = sel_rect(ws, "#player-slots .slot.st-weapon:not(.occupied)")
        drag(ws, (src["left"] + src["right"]) / 2, src["cy"], dst["x"], dst["y"])
        print("after drag->weapon slot:", queue(ws))
        src = card_rect(ws, "qingfeng-jian")
        dst = sel_rect(ws, "#player-slots .slot.st-fabao:not(.occupied)")
        drag(ws, (src["left"] + src["right"]) / 2, src["cy"], dst["x"], dst["y"])
        print("after drag->fabao slot:", queue(ws))
        shot(ws, "ro03_mode_switch_ok.png")

        # 5) 道童手动移出：拖出车道 → 缺位保留；按「清空我方」→ 自动补位
        src = card_rect(ws, "daotong")
        pool = sel_rect(ws, "#card-pool")
        drag(ws, (src["left"] + src["right"]) / 2, src["cy"], pool["x"], pool["y"])
        print("after drag char out:", queue(ws))
        print("after clear button:", ev(ws, "(() => { document.getElementById('btn-player-clear').click(); return JSON.stringify(window.__dao.state.playerQueue.map(u => u.cardId)); })()"))
        shot(ws, "ro04_char_out_then_auto.png")
        ws.close()
    finally:
        proc.kill()

if __name__ == "__main__":
    main()
