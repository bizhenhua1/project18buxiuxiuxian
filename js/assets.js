/**
 * 统一静态资源 URL 解析：相对站点根（index.html 所在目录），
 * 规范化 `..` 段、统一 cache-bust，避免各模块各自拼路径。
 */

/** @param {string} path 相对站点根的路径，如 assets/equipment/equip-hat.png */
export function assetUrl(path, ver = null) {
  const norm = path.replace(/\\/g, "/").replace(/^\/+/, "");
  const url = new URL(norm, document.baseURI);
  /* 折叠 pathname 中的 .. / .，避免 cloudsea/../forest 等在部分静态服上 404 */
  const parts = url.pathname.split("/").filter(Boolean);
  const out = [];
  for (const p of parts) {
    if (p === ".") continue;
    if (p === "..") { out.pop(); continue; }
    out.push(p);
  }
  url.pathname = "/" + out.join("/");
  if (ver) url.searchParams.set("v", String(ver));
  else url.searchParams.delete("v");
  return url.href;
}
