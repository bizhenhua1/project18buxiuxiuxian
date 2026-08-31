/**
 * 大地图多级迷雾。
 * hidden  未开雾：阴影预览，只露岛形
 * rumor   可前往：邻接已开区域，阴影预览；可走格用迷雾闪烁提示
 * memory  记忆：踩过但不在当前格，压暗真地貌
 * sight   视野：已开启且在视野内，全亮
 *
 * 只有踩过的格入库。未开格用阴影预览岛形，不提前露地貌。
 */

export const FogLevel = {
  hidden: 0,
  rumor: 1,
  memory: 2,
  sight: 3,
};

export const FogSave = {
  version: 1,
  levels: ["hidden", "rumor", "memory", "sight"],
};

export function createFog() {
  return {
    explored: new Set(),
    lastSeen: new Map(),
  };
}

export function cellKey(c, r) {
  return `${c},${r}`;
}

export function parseKey(k) {
  const [c, r] = k.split(",").map(Number);
  return { c, r };
}

export function snapshotCell(cell) {
  return {
    base: cell.base,
    feat: cell.feat,
    h: cell.h,
    layer: cell.layer,
  };
}

export function remember(fog, cell) {
  const k = cellKey(cell.c, cell.r);
  fog.explored.add(k);
  fog.lastSeen.set(k, snapshotCell(cell));
}

export function visionRadius(playerCell) {
  let radius = 3;
  if (playerCell && playerCell.h >= 1) radius += 1;
  if (playerCell && playerCell.feat && playerCell.feat.kind === "forest") {
    radius = Math.max(1, radius - 1);
  }
  return radius;
}

function cellsOnLine(c0, r0, c1, r1) {
  const n = Math.abs(c1 - c0) + Math.abs(r1 - r0);
  const out = [];
  for (let i = 1; i < n; i++) {
    const t = i / n;
    out.push({
      c: Math.round(c0 + (c1 - c0) * t),
      r: Math.round(r0 + (r1 - r0) * t),
    });
  }
  return out;
}

export function hasLos(lookup, from, to) {
  if (from.c === to.c && from.r === to.r) return true;
  const viewerH = from.h || 0;
  for (const p of cellsOnLine(from.c, from.r, to.c, to.r)) {
    if (p.c === to.c && p.r === to.r) continue;
    const mid = lookup.get(cellKey(p.c, p.r));
    if (!mid) return false;
    if (mid.layer === "ridge") return false;
    if (mid.h > viewerH) return false;
  }
  return true;
}

export function computeSight(lookup, player, cols, rows) {
  const here = lookup.get(cellKey(player.c, player.r));
  const radius = visionRadius(here);
  const sight = new Set();
  if (!here) return sight;
  sight.add(cellKey(player.c, player.r));
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const d = Math.abs(c - player.c) + Math.abs(r - player.r);
      if (d === 0 || d > radius) continue;
      const dest = lookup.get(cellKey(c, r));
      if (!dest) continue;
      if (hasLos(lookup, here, dest)) sight.add(cellKey(c, r));
    }
  }
  return sight;
}

export function isAdjacentToSet(c, r, keys) {
  return (
    keys.has(cellKey(c + 1, r)) ||
    keys.has(cellKey(c - 1, r)) ||
    keys.has(cellKey(c, r + 1)) ||
    keys.has(cellKey(c, r - 1))
  );
}

export function levelOf(c, r, fog, sight) {
  const k = cellKey(c, r);
  const opened = fog.explored.has(k);
  if (opened && sight.has(k)) return FogLevel.sight;
  if (opened) return FogLevel.memory;
  if (sight.has(k) || isAdjacentToSet(c, r, sight)) return FogLevel.rumor;
  return FogLevel.hidden;
}

/** 视觉参数：迷雾贴在地台本体上，不用另盖一层硬边罩。 */
export function fogStyle(level, dist, radius, nearSight) {
  if (level === FogLevel.sight) {
    const t = Math.min(1, dist / Math.max(1, radius));
    return { draw: true, feat: true, bright: 1.04 - t * 0.18, sat: 1 - t * 0.22 };
  }
  if (level === FogLevel.memory) {
    const lift = nearSight ? 0.12 : 0;
    return { draw: true, feat: true, bright: 0.58 + lift, sat: 0.4 + lift };
  }
  if (level === FogLevel.rumor) {
    return { draw: true, feat: false, shroud: true, bright: 0.92, sat: 0.45 };
  }
  return { draw: true, feat: false, shroud: true, bright: 0.76, sat: 0.3 };
}

export function revealSight(fog, lookup, sight) {
  for (const k of sight) {
    const cell = lookup.get(k);
    if (cell) remember(fog, cell);
  }
}

export function toSave(fog) {
  const lastSeen = {};
  for (const [k, v] of fog.lastSeen) lastSeen[k] = v;
  return {
    version: FogSave.version,
    explored: [...fog.explored],
    lastSeen,
  };
}

export function fromSave(data) {
  const fog = createFog();
  if (!data) return fog;
  for (const k of data.explored || []) fog.explored.add(k);
  for (const [k, v] of Object.entries(data.lastSeen || {})) fog.lastSeen.set(k, v);
  return fog;
}
