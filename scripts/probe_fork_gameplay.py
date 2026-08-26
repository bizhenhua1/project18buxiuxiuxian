# -*- coding: utf-8 -*-
"""模拟真实玩法探针：连续战斗胜利 -> 观察赶路/岔路触发/天空，最后刷新复现用户报告。"""
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
PORT = 9345
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
        return {"error": str(r["exceptionDetails"].get("exception", {}).get("description", ""))[:300]}
    return r.get("result", {}).get("value")


def shot(ws, name):
    r = send(ws, "Page.captureScreenshot", {"format": "png"})
    path = os.path.join(OUT, name)
    with open(path, "wb") as f:
        f.write(base64.b64decode(r["data"]))
    print("shot:", path)


SNAP = """(() => {
  const s = (typeof __corridorSnap === 'function') ? __corridorSnap() : __corridorSnap;
  const panel = document.querySelector('.corridor-fork-panel');
  return { camZ: Math.round(s.camZ), theme: s.themeId, fork: s.fork, traveling: s.traveling,
           panelVisible: panel ? !panel.hidden : null };
})()"""


def main():
    os.makedirs(OUT, exist_ok=True)
    profile = os.path.join(tempfile.gettempdir(), "fork-gameplay-probe")
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
        if not ws_url:
            raise SystemExit("no cdp tab")
        ws = websocket.create_connection(ws_url, timeout=60)
        send(ws, "Page.enable")
        send(ws, "Runtime.enable")
        send(ws, "Page.navigate", {"url": URL})
        time.sleep(3)
        # 清档从头开始，模拟一个全新玩家
        ev(ws, "(() => { for (let i = localStorage.length - 1; i >= 0; i--) { const k = localStorage.key(i); if (k && (k.startsWith('dao-') || k.startsWith('save'))) localStorage.removeItem(k); } location.reload(); return 1; })()")
        time.sleep(3)
        ev(ws, "window.__errs=[];window.addEventListener('error',e=>__errs.push(String((e.error&&e.error.stack)||e.message)));1")

        ev(ws, "(() => { document.getElementById('btn-player-fill').click(); const s=document.getElementById('speed-select'); s.value='4'; s.dispatchEvent(new Event('change')); return 1; })()")

        for round_i in range(1, 11):
            ev(ws, "window.__dao.start(); 1")
            time.sleep(0.4)
            ev(ws, "(() => { const p = window.__dao; for (const u of [...p.state.enemyQueue]) p.hit(u.uid, 99999); return 1; })()")
            # 等待战斗结算 + 赶路动画；期间轮询岔路状态
            fork_seen = None
            for _ in range(60):
                time.sleep(0.5)
                snap = ev(ws, SNAP)
                if isinstance(snap, dict) and snap.get("fork") == "choosing":
                    fork_seen = snap
                    shot(ws, f"probe-fork-round{round_i}.png")
                    ev(ws, "(() => { const b = document.querySelector('.corridor-fork-panel button'); if (b) b.click(); return 1; })()")
                if isinstance(snap, dict) and not snap.get("traveling") and snap.get("fork") == "hidden":
                    battle_done = ev(ws, "!window.__dao.state.running")
                    if battle_done:
                        break
            state = ev(ws, SNAP)
            errs = ev(ws, "(window.__errs||[]).slice(0,3)")
            print(f"round {round_i}: snap={json.dumps(state, ensure_ascii=False)} forkSeen={bool(fork_seen)} errs={errs}")

        shot(ws, "probe-before-reload.png")
        # 模拟用户刷新
        ev(ws, "location.reload(); 1")
        time.sleep(4)
        shot(ws, "probe-after-reload.png")
        snap = ev(ws, SNAP)
        errs = ev(ws, "(window.__errs||[])") or []
        print("after reload:", json.dumps(snap, ensure_ascii=False), "errs:", errs)
        ws.close()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except Exception:
            proc.kill()


if __name__ == "__main__":
    main()
