/**
 * 程序化任务：每个区域 3～5 个普通击杀任务 + 1 个精英击杀任务。
 * 完成精英才换区；区域内可重复刷，打赢不再自动推路点。
 * 存档 localStorage `dao-quests-v1`。
 */

import { NODES_PER_REGION, BALANCE } from "./balance.js?v=dao13";
import { ENEMY_LIBRARY } from "./unit.js?v=dao13";

const STORE_KEY = "dao-quests-v1";

const NORMAL_MIN = 3;
const NORMAL_MAX = 5;
const ELITE_IDS = ["jinchan", "yezhu", "xiaoqiao", "shitoujing", "shanyang"];

let data = null;

function mulberry32(seed) {
  let a = seed | 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function seedFrom(...parts) {
  let h = 2166136261;
  const text = parts.join(":");
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function pick(list, rng) {
  if (!list.length) return null;
  return list[Math.floor(rng() * list.length)];
}

function areaMult(areaIndex) {
  return BALANCE.regionGrowth ** Math.max(0, areaIndex | 0);
}

function enemyById(id) {
  return ENEMY_LIBRARY.find((c) => c.id === id) || ENEMY_LIBRARY[0];
}

function rollRewards(areaIndex, elite, rng) {
  const g = areaMult(areaIndex);
  const expJitter = 0.85 + rng() * 0.3;
  const coinJitter = 0.85 + rng() * 0.3;
  return {
    exp: Math.max(1, Math.round((elite ? 90 : 32) * g * expJitter)),
    coins: Math.max(1, Math.round((elite ? 48 : 14) * g * coinJitter)),
    loot: elite || rng() < 0.55 ? 1 : 0,
    minTier: elite ? 1 : 0,
  };
}

function rollNeed(areaIndex, elite, rng) {
  const bump = Math.floor(Math.max(0, areaIndex) * (elite ? 4 : 2));
  if (elite) return 12 + Math.floor(rng() * 9) + bump;
  return 6 + Math.floor(rng() * 7) + bump;
}

function rollTarget(elite, rng) {
  const pool = elite
    ? ENEMY_LIBRARY.filter((c) => ELITE_IDS.includes(c.id))
    : ENEMY_LIBRARY;
  return pick(pool.length ? pool : ENEMY_LIBRARY, rng);
}

function makeQuest(areaIndex, kind, slot, rng) {
  const elite = kind === "elite";
  const target = rollTarget(elite, rng);
  const need = rollNeed(areaIndex, elite, rng);
  return {
    id: `q-${areaIndex}-${kind}-${slot}-${target.id}-${need}`,
    kind,
    type: "kill",
    targetId: target.id,
    targetName: target.name,
    need,
    have: 0,
    rewards: rollRewards(areaIndex, elite, rng),
  };
}

function legacyStagePoints() {
  try {
    const raw = JSON.parse(localStorage.getItem("dao-progress-v1") || "null");
    const s = Math.max(0, Math.floor(Number(raw?.unlockStage) || 0));
    return s + Math.floor(s / 8);
  } catch {
    return 0;
  }
}

/** 旧档无计数时：按本区已交任务估算，且不低于旧路点公式，避免掉点或突然灌点。 */
function deriveCompleted(areaIndex, normalsDone) {
  const areas = Math.max(0, Math.floor(areaIndex || 0));
  const done = Math.max(0, Math.floor(normalsDone || 0));
  return Math.max(areas * 5 + done, areas * 9, legacyStagePoints());
}

function defaultData(areaIndex = 0, totalQuestsCompleted = null) {
  const idx = Math.max(0, Math.floor(areaIndex || 0));
  const rng = mulberry32(seedFrom("area", idx, Date.now()));
  const normalTotal = NORMAL_MIN + Math.floor(rng() * (NORMAL_MAX - NORMAL_MIN + 1));
  const completed = totalQuestsCompleted == null
    ? deriveCompleted(idx, 0)
    : Math.max(0, Math.floor(totalQuestsCompleted || 0));
  return {
    areaIndex: idx,
    normalTotal,
    normalsDone: 0,
    current: makeQuest(idx, "normal", 0, rng),
    totalQuestsCompleted: completed,
  };
}

function sanitizeQuest(raw, areaIndex) {
  if (!raw || raw.type !== "kill") return null;
  const target = enemyById(raw.targetId);
  const need = Math.max(1, Math.floor(Number(raw.need) || 0));
  const have = Math.max(0, Math.min(need, Math.floor(Number(raw.have) || 0)));
  const rewards = raw.rewards && typeof raw.rewards === "object"
    ? {
      exp: Math.max(0, Math.floor(Number(raw.rewards.exp) || 0)),
      coins: Math.max(0, Math.floor(Number(raw.rewards.coins) || 0)),
      loot: Math.max(0, Math.floor(Number(raw.rewards.loot) || 0)),
      minTier: Math.max(0, Math.floor(Number(raw.rewards.minTier) || 0)),
    }
    : rollRewards(areaIndex, raw.kind === "elite", () => 0.5);
  return {
    id: String(raw.id || `q-${areaIndex}-${raw.kind || "normal"}`),
    kind: raw.kind === "elite" ? "elite" : "normal",
    type: "kill",
    targetId: target.id,
    targetName: target.name,
    need,
    have,
    rewards,
  };
}

function load() {
  try {
    const raw = JSON.parse(localStorage.getItem(STORE_KEY) || "null");
    if (!raw) return null;
    const areaIndex = Math.max(0, Math.floor(Number(raw.areaIndex) || 0));
    const normalTotal = Math.max(NORMAL_MIN, Math.min(NORMAL_MAX, Math.floor(Number(raw.normalTotal) || NORMAL_MIN)));
    const normalsDone = Math.max(0, Math.min(normalTotal, Math.floor(Number(raw.normalsDone) || 0)));
    const current = sanitizeQuest(raw.current, areaIndex);
    if (!current) return defaultData(areaIndex);
    const totalQuestsCompleted = raw.totalQuestsCompleted != null
      ? Math.max(0, Math.floor(Number(raw.totalQuestsCompleted) || 0))
      : deriveCompleted(areaIndex, normalsDone);
    return { areaIndex, normalTotal, normalsDone, current, totalQuestsCompleted };
  } catch {
    return null;
  }
}

function save() {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(data));
  } catch { /* 静默 */ }
}

function ensure() {
  if (data) return data;
  data = load() || defaultData(0);
  save();
  return data;
}

export function migrateAreaFromStage(unlockStage) {
  const stage = Math.max(0, Math.floor(Number(unlockStage) || 0));
  const areaIndex = Math.floor(stage / NODES_PER_REGION);
  const existing = load();
  if (existing && Number.isFinite(existing.areaIndex)) {
    data = existing;
    save();
    return data;
  }
  data = defaultData(areaIndex);
  save();
  return data;
}

export function areaIndex() {
  return ensure().areaIndex;
}

export function areaStage() {
  return ensure().areaIndex * NODES_PER_REGION;
}

export function eliteStage() {
  return areaStage() + NODES_PER_REGION - 1;
}

export function currentQuest() {
  return ensure().current;
}

export function isEliteQuest() {
  return ensure().current?.kind === "elite";
}

export function questSnapshot() {
  const q = ensure();
  const cur = q.current;
  const slot = cur.kind === "elite" ? q.normalTotal + 1 : q.normalsDone + 1;
  const total = q.normalTotal + 1;
  return {
    areaIndex: q.areaIndex,
    stage: areaStage(),
    eliteStage: eliteStage(),
    normalTotal: q.normalTotal,
    normalsDone: q.normalsDone,
    slot,
    total,
    kind: cur.kind,
    title: `击杀${cur.targetName}`,
    targetId: cur.targetId,
    targetName: cur.targetName,
    have: cur.have,
    need: cur.need,
    ratio: cur.need > 0 ? cur.have / cur.need : 0,
    rewards: cur.rewards,
    done: cur.have >= cur.need,
    totalQuestsCompleted: q.totalQuestsCompleted || 0,
  };
}

export function applyKills(ids) {
  const q = ensure();
  const cur = q.current;
  let gained = 0;
  for (const id of ids || []) {
    if (id === cur.targetId && cur.have < cur.need) {
      cur.have += 1;
      gained += 1;
    }
  }
  if (!gained) return { progressed: false, completed: false, quest: cur };
  save();
  return {
    progressed: true,
    completed: cur.have >= cur.need,
    quest: cur,
  };
}

/** 已完成的普通+精英任务数（悟性进度来源）。 */
export function completedQuests() {
  return Math.max(0, Math.floor(ensure().totalQuestsCompleted || 0));
}

/** 当前任务已完成后：生成下一普通/精英，或标记本区精英已完成。 */
export function rollNextQuest() {
  const q = ensure();
  const finished = q.current;
  q.totalQuestsCompleted = completedQuests() + 1;
  if (finished.kind === "elite") {
    save();
    return { areaComplete: true, quest: finished };
  }
  q.normalsDone = Math.min(q.normalTotal, q.normalsDone + 1);
  const rng = mulberry32(seedFrom("next", q.areaIndex, q.normalsDone, finished.id, Date.now()));
  if (q.normalsDone >= q.normalTotal) {
    q.current = makeQuest(q.areaIndex, "elite", q.normalTotal, rng);
  } else {
    q.current = makeQuest(q.areaIndex, "normal", q.normalsDone, rng);
  }
  save();
  return { areaComplete: false, quest: q.current };
}

export function enterNextArea() {
  const prev = ensure();
  data = defaultData(prev.areaIndex + 1, completedQuests());
  save();
  return data;
}

export function setAreaIndex(n) {
  const idx = Math.max(0, Math.floor(n || 0));
  data = defaultData(idx, idx * 5);
  save();
  return data;
}

/** 调试：把当前任务标完成并滚到下一环（悟性 +1）。 */
export function completeCurrentQuest() {
  const q = ensure();
  q.current.have = q.current.need;
  save();
  return rollNextQuest();
}

export function areaGrowth(areaIndexVal = areaIndex()) {
  return areaMult(areaIndexVal);
}
