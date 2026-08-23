# -*- coding: utf-8 -*-
"""走廊逐帧诊断：页内 rAF 循环用 canvas.toDataURL 抓连续帧，与 __corridorDebug 精确对齐。
用法: python scripts/diag_capture2.py <url> <out_dir> [n_frames] [every]
输出: out_dir/c0000.png... (连续 canvas 帧), out_dir/debug.json, out_dir/capmeta.json
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
PORT = 9335


def main():
    url = sys.argv[1]
    out_dir = sys.argv[2]
    n_frames = int(sys.argv[3]) if len(sys.argv) > 3 else 80
    every = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    os.makedirs(out_dir, exist_ok=True)

    profile = os.path.join(tempfile.gettempdir(), "corridor-diag2-profile")
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
        assert ws_url, "no debugger url"

        ws = websocket.create_connection(ws_url, timeout=120)
        ws.settimeout(120)
        mid = [0]

        def cmd(method, **params):
            mid[0] += 1
            ws.send(json.dumps({"id": mid[0], "method": method, "params": params}))
            while True:
                msg = json.loads(ws.recv())
                if msg.get("id") == mid[0]:
                    return msg.get("result", {})

        def ev(expr):
            r = cmd("Runtime.evaluate", expression=expr,
                    awaitPromise=True, returnByValue=True)
            res = r.get("result", {})
            if res.get("subtype") == "error":
                print("EVAL ERROR:", res.get("description"))
            return res.get("value")

        cmd("Page.enable")
        cmd("Runtime.enable")
        cmd("Page.navigate", url=url)
        time.sleep(2.5)
        ev("window.__corridorDebugOn = true; 1")
        time.sleep(0.2)

        recorder = """
(() => {
  const cv = document.querySelector('canvas');
  window.__cap = [];
  window.__capDone = false;
  let tick = 0;
  function rec() {
    tick++;
    if (tick %% %(every)d === 0) {
      const n = (window.__corridorDebug && window.__corridorDebug.frames.length) || 0;
      window.__cap.push({ n, png: cv.toDataURL('image/png') });
    }
    if (window.__cap.length < %(n)d) requestAnimationFrame(rec);
    else window.__capDone = true;
  }
  requestAnimationFrame(rec);
  return 'recording';
})()
""" % {"every": every, "n": n_frames}
        print(ev(recorder))
        for _ in range(240):
            if ev("window.__capDone"):
                break
            time.sleep(0.5)

        meta = []
        for i in range(n_frames):
            item = ev(f"window.__cap[{i}] && window.__cap[{i}].n")
            png = ev(f"window.__cap[{i}] && window.__cap[{i}].png.slice(22)")
            if png is None:
                break
            with open(os.path.join(out_dir, f"c{i:04d}.png"), "wb") as f:
                f.write(base64.b64decode(png))
            meta.append({"i": i, "debugIndex": (item or 0) - 1})
        dump = ev("JSON.stringify(window.__corridorDebug)")
        with open(os.path.join(out_dir, "debug.json"), "w", encoding="utf-8") as f:
            f.write(dump or "null")
        with open(os.path.join(out_dir, "capmeta.json"), "w", encoding="utf-8") as f:
            json.dump(meta, f)
        print("done:", out_dir, "captured:", len(meta))
        ws.close()
    finally:
        proc.kill()


if __name__ == "__main__":
    main()
