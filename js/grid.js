/** 可见车道按 10 张 1:2 竖卡紧密无重叠定宽。开局携带仍可以是 8。 */
export const SLOT_COUNT = 10;
export const VISIBLE_SLOTS = 10;

/** 关卡 0 起：每关 +1 可携带上限。
 * 第一版：双方可上阵上限锁定 10 个位置（8→9→10 封顶，永不叠卡）。 */
export const UNLOCK_CAPS = [8, 9, 10];
export const MAX_STAGE = UNLOCK_CAPS.length - 1;
export const MAX_CAP = 10;
export const MAX_UNITS = MAX_CAP;
export const MAX_SLOTS = MAX_CAP;

export function capAt(stage) {
  const i = Math.max(0, Math.min(MAX_STAGE, stage));
  return UNLOCK_CAPS[i];
}

export function createEmptyQueue() {
  return [];
}

export function reindex(queue) {
  queue.forEach((u, i) => {
    if (u) u.index = i;
  });
  return queue;
}

export function isAlive(u) {
  return !!(u && u.status === "alive" && u.hp > 0);
}

export function isCorpse(u) {
  return !!(u && u.status === "corpse");
}

export function livingUnits(queue) {
  return queue.filter(isAlive);
}

export function corpses(queue) {
  return queue.filter(isCorpse);
}

/** 当前最左边的存活单位（跳过尸体）。 */
export function leftmost(queue) {
  return livingUnits(queue)[0] || null;
}

/** 法术与手持（held）法宝不占承伤位：敌方集火跳过它们；操控（station）法宝有独立血条可被集火。 */
export function isTargetable(u) {
  if (!u) return false;
  if (u.cardType === "spell") return false;
  if (u.cardType === "fabao" && u.mode === "held") return false;
  return true;
}

/** 最左可承伤的存活单位（集火目标）。 */
export function leftmostTargetable(queue) {
  return livingUnits(queue).find(isTargetable) || null;
}

export function markCorpse(unit) {
  if (!unit) return unit;
  unit.hp = 0;
  unit.shield = 0;
  unit.status = "corpse";
  unit.cdLeft = unit.cd;
  unit.lastTargetUid = null;
  return unit;
}

export function clearQueue(queue) {
  queue.length = 0;
  return queue;
}

export function findUnitByUid(queues, uid) {
  for (const q of queues) {
    const hit = q.find((u) => u && u.uid === uid);
    if (hit) return hit;
  }
  return null;
}

export function queueOf(state, side) {
  return side === "player" ? state.playerQueue : state.enemyQueue;
}

export function canAdd(queue, cap, ignoreUid = null) {
  const n = queue.filter((u) => u && u.uid !== ignoreUid).length;
  return n < cap;
}

export function insertUnit(queue, unit, index, cap, ignoreUid = null) {
  if (!canAdd(queue, cap, ignoreUid)) return false;
  const i = Math.max(0, Math.min(queue.length, index));
  queue.splice(i, 0, unit);
  reindex(queue);
  return true;
}

export function removeUnit(queue, unit) {
  if (!unit) return;
  const i = queue.findIndex((u) => u && u.uid === unit.uid);
  if (i >= 0) queue.splice(i, 1);
  reindex(queue);
}

export function moveUnit(queue, unit, index) {
  const from = queue.findIndex((u) => u && u.uid === unit.uid);
  if (from < 0) return false;
  queue.splice(from, 1);
  const i = Math.max(0, Math.min(queue.length, index));
  queue.splice(i, 0, unit);
  reindex(queue);
  return true;
}

/** 队列相邻（左右各一张），用于加速等。 */
export function queueNeighbors(queue, unit) {
  const i = queue.findIndex((u) => u && u.uid === unit.uid);
  if (i < 0) return [];
  return [queue[i - 1], queue[i + 1]].filter(isAlive);
}

/** 目标身后的若干张，用于溅射。 */
export function unitsBehind(queue, unit, n = 2) {
  const i = queue.findIndex((u) => u && u.uid === unit.uid);
  if (i < 0) return [];
  return queue.slice(i + 1, i + 1 + n).filter(isAlive);
}

export const CARD_GAP = 4;

/**
 * 用 10 张紧排反推卡宽。
 * align: start=贴上沿（敌方靠近窗口顶），end=贴下沿（我方靠近窗口底）。
 */
export function measureCardSize(width, height, align = "start") {
  const pad = 6;
  const innerW = Math.max(80, width - pad * 2);
  const maxH = Math.max(80, height - pad * 2);
  const gap = CARD_GAP;
  let cardW = (innerW - (SLOT_COUNT - 1) * gap) / SLOT_COUNT;
  let cardH = cardW * 2;
  if (cardH > maxH) {
    cardH = maxH;
    cardW = cardH / 2;
  }
  const packW = SLOT_COUNT * cardW + (SLOT_COUNT - 1) * gap;
  const top = align === "end" ? height - pad - cardH : pad;
  return { pad, gap, cardW, cardH, packW, top, innerW, align };
}

/**
 * 左对齐紧密排布。≤10 不重叠；>10 在 packW 内整体水平重叠。
 */
export function computeLaneLayout(count, width, height, align = "start") {
  const m = measureCardSize(width, height, align);
  const items = [];
  if (count <= 0) return items;

  const stacked = count > SLOT_COUNT;
  const step = stacked ? (m.packW - m.cardW) / (count - 1) : m.cardW + m.gap;

  for (let i = 0; i < count; i++) {
    items.push({
      left: m.pad + i * step,
      width: m.cardW,
      top: m.top,
      height: m.cardH,
      z: 10 + i,
      stacked,
    });
  }
  return items;
}
