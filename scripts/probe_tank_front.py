# -*- coding: utf-8 -*-
"""真实鼠标探针：验证可承伤区自由排序（dao12）——法宝可挡在主角前面当肉盾。
1) 把 station 法宝拖到道童前面：顺序生效，格位底纹随占位单位变化；
2) 开战后敌方集火最前的法宝而非道童；
3) 胜利推关 / 战败复位后玩家排序保持（ensureCharFielded 只补位不重排）；
4) 道童与法宝多次互换均不被顶回；
5) 落点即意图：held 法宝正压可承伤区格位＝切 station 且落在该位置；
   识海法术（无模式）拖到最左会被归回右侧分组；空格位模式切换拖放不回归。"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

import websocket

sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # 悬浮文案含 ☯ 等字符，GBK 控制台会炸

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

def card_rect(ws, card_id):
    return ev(ws, f"(() => {{ const el = document.querySelector('.unit-card[data-card-id=\"{card_id}\"]'); if (!el) return null; const r = el.getBoundingClientRect(); return {{ left: r.left, right: r.right, w: r.width, cy: r.y + r.height / 2 }}; }})()")

def sel_rect(ws, selector):
    return ev(ws, f"(() => {{ const el = document.querySelector('{selector}'); if (!el) return null; el.scrollIntoView({{ block: 'center' }}); const r = el.getBoundingClientRect(); return {{ x: r.x + r.width / 2, y: r.y + r.height / 2 }}; }})()")

def drag(ws, x0, y0, x1, y1, steps=10):
    send(ws, "Input.dispatchMouseEvent", {"type": "mousePressed", "x": x0, "y": y0, "button": "left", "clickCount": 1})
    for i in range(1, steps + 1):
        send(ws, "Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x0 + (x1 - x0) * i / steps, "y": y0 + (y1 - y0) * i / steps, "button": "left"})
    send(ws, "Input.dispatchMouseEvent", {"type": "mouseReleased", "x": x1, "y": y1, "button": "left", "clickCount": 1})
    time.sleep(0.5)  # 间隔 >350ms，避免连续拖同一张卡触发双击切模式

def queue(ws):
    return ev(ws, "JSON.stringify(window.__dao.state.playerQueue.map(u => [u.cardId, u.mode || u.cardType]))")

def slot_types(ws):
    return ev(ws, "[...document.querySelectorAll('#player-slots .slot')].map(s => (s.className.match(/st-(\\w+)/) || [])[1]).join(',')")

def drag_before(ws, src_id, dst_id):
    """把 src 卡拖到 dst 卡的左半区（插到其前面）。"""
    src = card_rect(ws, src_id)
    dst = card_rect(ws, dst_id)
    drag(ws, (src["left"] + src["right"]) / 2, src["cy"], dst["left"] + dst["w"] * 0.25, dst["cy"])

def main():
    profile = os.path.join(tempfile.gettempdir(), "tankfront-probe-profile")
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
        # 体修 b1/b2 开手持格、法修 f1/f2 开识海格；上道童 + 2 station 剑 + 1 held 剑 + 1 法术
        print("setup:", ev(ws, "(() => { window.__dao.setStage(12); document.getElementById('btn-talents').click(); const click = id => document.querySelector(`.tnode[data-id=\"${id}\"]`).dispatchEvent(new MouseEvent('click',{bubbles:true})); ['b1','b2','f1','f2'].forEach(click); document.getElementById('talent-close').click(); const p = window.__dao; p.clear(); p.place('daotong'); p.place('taomu-jian','station'); p.place('qingfeng-jian','station'); p.place('xuantie-jian','held'); p.place('lihuo-shu'); return JSON.stringify({ slots: p.slots() }); })()"))
        print("default queue:", queue(ws), "| slots:", slot_types(ws))

        # 1) 把 station 桃木剑拖到道童前面：顺序生效，格位底纹跟着占位单位走
        drag_before(ws, "taomu-jian", "daotong")
        print("[1] fabao before char:", queue(ws), "| slots:", slot_types(ws))
        shot(ws, "tf01_fabao_front.png")

        # 悬浮空格位说明仍正常弹出
        tip = ev(ws, "(() => { const slot = document.querySelector('#player-slots .slot.usable:not(.occupied)'); if (!slot) return 'no empty slot'; const r = slot.getBoundingClientRect(); slot.dispatchEvent(new MouseEvent('pointermove', { bubbles: true, clientX: r.left + r.width / 2, clientY: r.top + r.height / 2 })); const t = document.getElementById('card-tip'); return JSON.stringify({ hidden: t.hidden, text: t.textContent.replace(/\\s+/g, ' ').slice(0, 60) }); })()")
        print("[1] slot tip:", tip)
        shot(ws, "tf02_slot_tip.png")

        # 2) 开战：敌方应集火最前的桃木剑而非道童
        print("[2] start:", ev(ws, "(() => { const p = window.__dao; p.setStage(0); p.state.enemyQueue.splice(3); const order = p.state.playerQueue.map(u=>u.cardId); p.start(); return JSON.stringify({ orderKept: order, enemies: p.state.enemyQueue.length, running: p.state.running }); })()"))
        print("[2] focus:", ev(ws, "(async () => { const s = window.__dao.state; const taomu = s.playerQueue.find(u=>u.cardId==='taomu-jian'); const char = s.playerQueue.find(u=>u.cardType==='char'); const t0 = Date.now(); while (Date.now() - t0 < 12000) { if (taomu.hp < taomu.maxHp || taomu.status==='corpse') break; await new Promise(r=>setTimeout(r,80)); } const foes = s.enemyQueue.filter(u=>u.status==='alive'); return JSON.stringify({ taomuHurt: taomu.hp < taomu.maxHp, charUntouched: char.hp === char.maxHp, enemyFocusTaomu: foes.every(u=>u.lastTargetUid===null||u.lastTargetUid===taomu.uid) }); })()"))
        shot(ws, "tf03_enemy_focus_fabao.png")

        # 3a) 胜利推关后排序保持（travel + applyNextStageSpawn 不重排）
        print("[3a] victory+next:", ev(ws, "(async () => { const p = window.__dao; const t0 = Date.now(); while (Date.now() - t0 < 40000) { if (p.state.unlockStage === 1 && !p.state.running) { await new Promise(r=>setTimeout(r,300)); return JSON.stringify({ stage: p.state.unlockStage, queue: p.state.playerQueue.map(u=>u.cardId), fabaoStillFirst: p.state.playerQueue[0].cardId === 'taomu-jian' }); } await new Promise(r=>setTimeout(r,150)); } return JSON.stringify({ timeout: true, winner: p.state.winner, stage: p.state.unlockStage }); })()"))
        shot(ws, "tf04_after_victory.png")

        # 3b) 战败复位后排序保持（reviveAfterDefeat + ensureCharFielded 不重排）
        print("[3b] defeat setup:", ev(ws, "(() => { const p = window.__dao; p.setStage(20); p.start(); return JSON.stringify({ running: p.state.running, enemies: p.state.enemyQueue.length }); })()"))
        print("[3b] after revive:", ev(ws, "(async () => { const p = window.__dao; const t0 = Date.now(); while (Date.now() - t0 < 30000) { if (!p.state.running && !p.state.winner && p.state.playerQueue.every(u=>u.status==='alive')) { return JSON.stringify({ queue: p.state.playerQueue.map(u=>u.cardId), fabaoStillFirst: p.state.playerQueue[0].cardId === 'taomu-jian', outcome: document.getElementById('outcome')?.textContent.slice(0, 30) }); } await new Promise(r=>setTimeout(r,150)); } return JSON.stringify({ timeout: true, winner: p.state.winner, running: p.state.running }); })()"))
        shot(ws, "tf05_after_defeat_revive.png")

        # 4) 道童拖回最前、再互换多次：每次都按落点生效、不被顶回
        drag_before(ws, "daotong", "taomu-jian")
        print("[4] char back to front:", queue(ws))
        drag_before(ws, "taomu-jian", "daotong")
        print("[4] fabao front again:", queue(ws))
        drag_before(ws, "daotong", "taomu-jian")
        print("[4] char front again:", queue(ws), "| slots:", slot_types(ws))
        shot(ws, "tf06_swap_stable.png")

        # 5a) held 法宝正压可承伤区格位（道童位）＝切 station 且落在该位置（落点即意图）
        drag_before(ws, "xuantie-jian", "daotong")
        print("[5a] held->station at front:", queue(ws))

        # 5c) 识海法术（无模式可切）拖到最左：不可承伤单位被归回右侧分组
        drag_before(ws, "lihuo-shu", "xuantie-jian")
        print("[5c] spell stays right:", queue(ws))

        # 5b) 模式切换拖放不回归：青锋剑拖到空手持格 → held；再拖回空法宝格 → station
        src = card_rect(ws, "qingfeng-jian")
        dst = sel_rect(ws, "#player-slots .slot.st-weapon:not(.occupied)")
        drag(ws, (src["left"] + src["right"]) / 2, src["cy"], dst["x"], dst["y"])
        print("[5b] drag->weapon slot:", queue(ws))
        src = card_rect(ws, "qingfeng-jian")
        dst = sel_rect(ws, "#player-slots .slot.st-fabao:not(.occupied)")
        drag(ws, (src["left"] + src["right"]) / 2, src["cy"], dst["x"], dst["y"])
        print("[5b] drag->fabao slot:", queue(ws))
        shot(ws, "tf07_mode_switch_ok.png")
        ws.close()
    finally:
        proc.kill()

if __name__ == "__main__":
    main()
