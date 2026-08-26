/**
 * 多档案存档层：注册表 + 每档一份快照。
 * 运行期各子系统仍读写原来的 dao-* 键（工作副本）；
 * 切换/关闭时把工作副本收入当前档，启动时按需把当前档铺回工作副本。
 */

const REGISTRY_KEY = "dao-saves-v1";
const SLOT_PREFIX = "dao-slot-";
export const MAX_SLOTS = 16;

const LEGACY_KEYS = {
  progress: "dao-progress-v1",
  quests: "dao-quests-v1",
  idle: "dao-idle-v1",
  coins: "dao-coins-v1",
  realm: "dao-realm-v1",
  talents: "dao-talents-v1",
  bag: "dao-bag-v1",
  beasts: "dao-beasts-v1",
  lineup: "dao-lineup-v1",
};

const REGION_NAMES = ["青金仙途", "丹砂夜岭"];
const REALM_STAGES = ["炼气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"];
const CN_NUM = ["一", "二", "三", "四", "五", "六", "七", "八", "九"];
const NODES_PER_REGION = 8;

let cached = null;

function blobKey(id) {
  return `${SLOT_PREFIX}${id}`;
}

function readJson(key) {
  try {
    return JSON.parse(localStorage.getItem(key) || "null");
  } catch {
    return null;
  }
}

function writeJson(key, value) {
  try {
    if (value == null) localStorage.removeItem(key);
    else localStorage.setItem(key, JSON.stringify(value));
    return true;
  } catch {
    return false;
  }
}

function newId() {
  return `s${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
}

export function sanitizeName(name, fallback = "未名档案") {
  const s = String(name || "").replace(/\s+/g, " ").trim().slice(0, 16);
  return s || fallback;
}

function nextDefaultName(slots) {
  const used = new Set((slots || []).map((s) => s.name));
  for (let i = 1; i < 100; i++) {
    const n = `档案 ${i}`;
    if (!used.has(n)) return n;
  }
  return `档案 ${Date.now().toString(36)}`;
}

function emptySnapshot() {
  return {
    progress: { unlockStage: 0, wins: 0, clearedStage: -1 },
    quests: null,
    idle: { accruedAt: Date.now() },
    coins: { coins: 0 },
    realm: { stage: 0, layer: 0, exp: 0, totalExp: 0 },
    talents: { nodes: ["root"] },
    bag: { items: [], equipped: {} },
    beasts: {},
    lineup: { units: [] },
  };
}

function previewOf(snap) {
  const areaIndex = Number.isFinite(snap?.quests?.areaIndex)
    ? Math.max(0, Math.floor(snap.quests.areaIndex))
    : Math.floor(Math.max(0, Number(snap?.progress?.unlockStage) || 0) / NODES_PER_REGION);
  const region = REGION_NAMES[areaIndex % REGION_NAMES.length];
  const loop = Math.floor(areaIndex / REGION_NAMES.length);
  const areaName = loop > 0 ? `${region} · 循环 ${loop + 1}` : region;
  const q = snap?.quests?.current;
  const quest = q?.targetName
    ? `击杀${q.targetName} ${Math.max(0, q.have | 0)}/${Math.max(1, q.need | 0)}`
    : "新的旅途";
  const stage = Math.max(0, Math.min(REALM_STAGES.length - 1, snap?.realm?.stage | 0));
  const layer = Math.max(0, Math.min(8, snap?.realm?.layer | 0));
  const realmTitle = `${REALM_STAGES[stage]}${CN_NUM[layer]}层`;
  const coins = Math.max(0, Math.floor(Number(snap?.coins?.coins) || 0));
  const wins = Math.max(0, snap?.progress?.wins | 0);
  return { areaName, quest, realmTitle, coins, wins };
}

function hasAnyLegacy() {
  return Object.values(LEGACY_KEYS).some((k) => localStorage.getItem(k) != null);
}

function gatherLegacy() {
  const snap = {};
  for (const [field, key] of Object.entries(LEGACY_KEYS)) {
    snap[field] = readJson(key);
  }
  return snap;
}

function applySnapshotToLegacy(snap) {
  const data = snap && typeof snap === "object" ? snap : emptySnapshot();
  for (const [field, key] of Object.entries(LEGACY_KEYS)) {
    writeJson(key, data[field] == null ? null : data[field]);
  }
}

/** 上阵快照：只留 cardId / 手持或操控 / 队列下标，不写战斗态。 */
export function snapshotPlayerLineup(queue) {
  const units = [];
  const list = Array.isArray(queue) ? queue : [];
  for (let i = 0; i < list.length; i++) {
    const u = list[i];
    const cardId = String(u?.cardId || "").trim();
    if (!cardId) continue;
    units.push({
      cardId,
      mode: u.mode === "held" ? "held" : "station",
      index: Number.isFinite(u.index) ? Math.max(0, u.index | 0) : i,
    });
  }
  return { units };
}

export function persistPlayerLineup(queue) {
  return writeJson(LEGACY_KEYS.lineup, snapshotPlayerLineup(queue));
}

/** 读工作副本；损坏或空档返回 []，由调用方回退到只上道童。 */
export function loadPlayerLineup() {
  const raw = readJson(LEGACY_KEYS.lineup);
  if (raw == null) return [];
  const list = Array.isArray(raw) ? raw : raw && typeof raw === "object" && Array.isArray(raw.units) ? raw.units : null;
  if (!list) return [];
  return list
    .map((e, i) => {
      if (!e || typeof e !== "object") return null;
      const cardId = String(e.cardId || "").trim();
      if (!cardId) return null;
      const index = Number.isFinite(Number(e.index)) ? Math.max(0, Math.floor(Number(e.index))) : i;
      return { cardId, mode: e.mode === "held" ? "held" : "station", index };
    })
    .filter(Boolean)
    .sort((a, b) => a.index - b.index);
}

function readBlob(id) {
  const raw = readJson(blobKey(id));
  return raw && typeof raw === "object" ? raw : null;
}

function writeBlob(id, snap) {
  return writeJson(blobKey(id), snap);
}

function removeBlob(id) {
  try {
    localStorage.removeItem(blobKey(id));
  } catch { /* 静默 */ }
}

function readRegistry() {
  if (cached) return cached;
  const raw = readJson(REGISTRY_KEY);
  if (raw && Array.isArray(raw.slots) && raw.slots.length) {
    cached = raw;
    return cached;
  }
  return null;
}

function writeRegistry(reg) {
  cached = reg;
  writeJson(REGISTRY_KEY, reg);
}

function getRegistry() {
  return readRegistry() || migrateOrInit();
}

function makeSlotMeta(id, name, snap, now = Date.now()) {
  return {
    id,
    name,
    createdAt: now,
    updatedAt: now,
    preview: previewOf(snap),
  };
}

function migrateOrInit() {
  const now = Date.now();
  const legacy = hasAnyLegacy();
  const id = legacy ? "default" : newId();
  const name = legacy ? "默认档案" : "档案 1";
  const snap = legacy ? gatherLegacy() : emptySnapshot();
  if (!legacy) applySnapshotToLegacy(snap);
  writeBlob(id, snap);
  const registry = {
    activeId: id,
    slots: [makeSlotMeta(id, name, snap, now)],
  };
  writeRegistry(registry);
  return registry;
}

function reloadSoon() {
  location.reload();
}

export function flushActive() {
  const registry = getRegistry();
  const snap = gatherLegacy();
  writeBlob(registry.activeId, snap);
  const slot = registry.slots.find((s) => s.id === registry.activeId);
  if (slot) {
    slot.updatedAt = Date.now();
    slot.preview = previewOf(snap);
    writeRegistry(registry);
  }
  return snap;
}

export function listSlots() {
  const registry = getRegistry();
  return registry.slots.map((s) => ({ ...s, active: s.id === registry.activeId }));
}

export function activeSlot() {
  const registry = getRegistry();
  return registry.slots.find((s) => s.id === registry.activeId) || registry.slots[0] || null;
}

export function createSlot(name) {
  const registry = getRegistry();
  if (registry.slots.length >= MAX_SLOTS) {
    return { ok: false, error: `最多保存 ${MAX_SLOTS} 个档案` };
  }
  flushActive();
  const id = newId();
  const snap = emptySnapshot();
  const slot = makeSlotMeta(id, sanitizeName(name, nextDefaultName(registry.slots)), snap);
  writeBlob(id, snap);
  registry.slots.push(slot);
  registry.activeId = id;
  writeRegistry(registry);
  applySnapshotToLegacy(snap);
  reloadSoon();
  return { ok: true, id };
}

export function switchSlot(id) {
  const registry = getRegistry();
  if (id === registry.activeId) return { ok: true, same: true };
  if (!registry.slots.some((s) => s.id === id)) return { ok: false, error: "档案不存在" };
  flushActive();
  const snap = readBlob(id) || emptySnapshot();
  registry.activeId = id;
  writeRegistry(registry);
  applySnapshotToLegacy(snap);
  reloadSoon();
  return { ok: true };
}

export function deleteSlot(id) {
  const registry = getRegistry();
  const idx = registry.slots.findIndex((s) => s.id === id);
  if (idx < 0) return { ok: false, error: "档案不存在" };
  const wasActive = registry.activeId === id;
  const last = registry.slots.length === 1;
  registry.slots.splice(idx, 1);
  removeBlob(id);

  if (last) {
    const nid = newId();
    const snap = emptySnapshot();
    const slot = makeSlotMeta(nid, "档案 1", snap);
    registry.slots.push(slot);
    registry.activeId = nid;
    writeBlob(nid, snap);
    writeRegistry(registry);
    applySnapshotToLegacy(snap);
    reloadSoon();
    return { ok: true, recreated: true };
  }

  if (wasActive) {
    const next = registry.slots[Math.min(idx, registry.slots.length - 1)];
    registry.activeId = next.id;
    writeRegistry(registry);
    applySnapshotToLegacy(readBlob(next.id) || emptySnapshot());
    reloadSoon();
    return { ok: true, switched: true };
  }

  writeRegistry(registry);
  return { ok: true };
}

export function renameSlot(id, name) {
  const registry = getRegistry();
  const slot = registry.slots.find((s) => s.id === id);
  if (!slot) return { ok: false, error: "档案不存在" };
  slot.name = sanitizeName(name, slot.name);
  writeRegistry(registry);
  return { ok: true, name: slot.name };
}

function boot() {
  let registry = readRegistry();
  if (!registry) {
    migrateOrInit();
    return;
  }
  for (const slot of registry.slots) {
    if (!readBlob(slot.id)) writeBlob(slot.id, emptySnapshot());
  }
  if (!registry.slots.some((s) => s.id === registry.activeId)) {
    registry.activeId = registry.slots[0].id;
    writeRegistry(registry);
  }
  if (!hasAnyLegacy()) {
    applySnapshotToLegacy(readBlob(registry.activeId) || emptySnapshot());
  } else {
    flushActive();
  }
}

boot();
window.addEventListener("pagehide", () => flushActive());
window.addEventListener("beforeunload", () => flushActive());
