/**
 * 七部位纯数值装备系统：帽/衣/鞋/护腕/戒指/项链/玉佩。
 * 部位决定主属性主题，稀有度决定词条数量；词条与天赋走同一 mods 聚合管线。
 * 装备穿在道童身上、数值全队生效（全队本就是修士的持有物）。
 */

import { emptyMods, mergeMods } from "./talents.js?v=dao8";

const BAG_KEY = "dao-bag-v1";

/**
 * 主属性归属（dao7 重梳）：
 * 帽=生命 / 衣=外防 / 鞋=全冷却（稀有强力）/ 腕=攻击 / 戒=暴击 / 链=法伤 / 玉=法防。
 * 气运从玉佩主属性移入词条池与仙品专属。
 */
export const EQUIP_SLOTS = [
  { id: "hat", name: "束发冠", icon: "👑", main: "hpPct", mainBase: 6, art: "assets/equipment/equip-hat.png" },
  { id: "robe", name: "法衣", icon: "🥋", main: "physDef", mainBase: 8, art: "assets/equipment/equip-robe.png" },
  { id: "boots", name: "云履", icon: "👞", main: "cdPct", mainBase: 3, art: "assets/equipment/equip-boots.png" },
  { id: "bracer", name: "护腕", icon: "🥊", main: "atkPct", mainBase: 4, art: "assets/equipment/equip-bracer.png" },
  { id: "ring", name: "戒指", icon: "💍", main: "critPct", mainBase: 4, art: "assets/equipment/equip-ring.png" },
  { id: "amulet", name: "项链", icon: "📿", main: "spellPct", mainBase: 6, art: "assets/equipment/equip-amulet.png" },
  { id: "jade", name: "玉佩", icon: "🪬", main: "spellDef", mainBase: 8, art: "assets/equipment/equip-jade.png" },
];

export const RARITIES = [
  { id: "fan", name: "凡品", affixes: 0, mult: 1.0, color: "#9aa3a8" },
  { id: "ling", name: "灵品", affixes: 1, mult: 1.3, color: "#7dce8a" },
  { id: "bao", name: "宝品", affixes: 2, mult: 1.7, color: "#6fa8dc" },
  { id: "xian", name: "仙品", affixes: 3, mult: 2.2, color: "#e6b422" },
];

export const STAT_NAMES = {
  atkPct: "攻击",
  hpPct: "生命",
  cdPct: "全冷却",
  dmgReducePct: "受伤减免",
  thornsPct: "反伤",
  splashDmgPct: "溅射伤害",
  healPct: "治疗强化",
  shieldPct: "护盾强化",
  physPct: "外伤",
  spellPct: "法伤",
  physDef: "外防",
  spellDef: "法防",
  skillCdrPct: "技能冷却",
  dualDef: "阴阳护体·双防",
  capturePct: "收服概率",
  luckPct: "气运",
  weightAdd: "力量预算",
  mindSlotAdd: "识海格",
  fabaoAtkPct: "法宝攻击",
  fabaoHpPct: "法宝生命",
  beastAtkPct: "御兽攻击",
  beastHpPct: "御兽生命",
  atkSpeedPct: "攻速",
  critPct: "暴击",
  critDmgPct: "暴击伤害",
  reviveCdrPct: "重聚缩减",
};

/** 词条是否为非百分比的固定值（不随关卡放大） */
const FLAT_STATS = new Set(["weightAdd", "mindSlotAdd"]);
/** 防御点数：显示为整数点，但数值随关卡放大（公式常数也随关卡抬升） */
const DEF_STATS = new Set(["physDef", "spellDef", "dualDef"]);

export function fmtStat(stat, val) {
  const name = STAT_NAMES[stat] || stat;
  if (FLAT_STATS.has(stat) || DEF_STATS.has(stat)) return `${name}+${val}`;
  if (stat === "cdPct" || stat === "dmgReducePct" || stat === "reviveCdrPct" || stat === "skillCdrPct") return `${name} ${val}%`;
  return `${name}+${val}%`;
}

/** 词条池：favored 部位权重×3，形成部位主题偏向。 */
// dao7：普通词条池撤下全队 cdPct（保留为鞋主属性 + 仙品·踏虚的"全冷却"稀有词条），
// 换成方向性更强的攻速/技能冷却；并加入外伤/法伤/外防/法防。
const AFFIX_POOL = [
  { stat: "atkPct", base: 3, favored: ["bracer", "ring"] },
  { stat: "hpPct", base: 4, favored: ["hat", "robe"] },
  { stat: "dmgReducePct", base: 2, favored: ["robe"] },
  { stat: "thornsPct", base: 5, favored: ["robe", "bracer"] },
  { stat: "splashDmgPct", base: 6, favored: ["ring"] },
  { stat: "healPct", base: 6, favored: ["amulet"] },
  { stat: "shieldPct", base: 6, favored: ["hat"] },
  { stat: "physPct", base: 4, favored: ["bracer", "ring"] },
  { stat: "spellPct", base: 4, favored: ["amulet", "ring"] },
  { stat: "physDef", base: 5, favored: ["robe", "hat"] },
  { stat: "spellDef", base: 5, favored: ["jade", "amulet"] },
  { stat: "skillCdrPct", base: 3, favored: ["boots", "amulet"] },
  { stat: "capturePct", base: 4, favored: ["jade"] },
  { stat: "luckPct", base: 3, favored: ["jade"] },
  { stat: "fabaoAtkPct", base: 4, favored: ["bracer"] },
  { stat: "beastAtkPct", base: 4, favored: ["jade"] },
  { stat: "atkSpeedPct", base: 4, favored: ["bracer", "ring"] },
  { stat: "critPct", base: 4, favored: ["bracer", "ring"] },
  { stat: "reviveCdrPct", base: 6, favored: ["amulet"] },
];

/** 仙品专属强词条（每部位一条，必然附加）。 */
const XIAN_EXCLUSIVE = {
  hat: { stat: "hpPct", base: 10 },
  robe: { stat: "dualDef", base: 8 }, // 阴阳护体：外防/法防各+N（跨防御仙品专属）

  boots: { stat: "cdPct", base: 6 },
  bracer: { stat: "weightAdd", base: 2 },
  ring: { stat: "splashDmgPct", base: 15 },
  amulet: { stat: "mindSlotAdd", base: 1 },
  jade: { stat: "luckPct", base: 10 },
};

let itemSeq = Date.now() % 1000000;

/** 数值随掉落关卡缓慢放大（装备约占后期战力三成）。 */
function scaleVal(base, mult, stage) {
  return Math.max(1, Math.round(base * mult * (1 + stage * 0.05)));
}

export function rarityById(id) {
  return RARITIES.find((r) => r.id === id) || RARITIES[0];
}

export function slotById(id) {
  return EQUIP_SLOTS.find((s) => s.id === id) || EQUIP_SLOTS[0];
}

/** 稀有度掷点：luck（气运）整体上移品质。 */
export function rollRarity(luckPct = 0, minTier = 0) {
  const r = Math.random() * 100 - luckPct * 0.6;
  let tier;
  if (r < 2) tier = 3;
  else if (r < 12) tier = 2;
  else if (r < 38) tier = 1;
  else tier = 0;
  return RARITIES[Math.max(minTier, tier)];
}

export function makeItem({ slotId = null, rarityId = null, stage = 0, luckPct = 0, minTier = 0 } = {}) {
  const slot = slotId ? slotById(slotId) : EQUIP_SLOTS[Math.floor(Math.random() * EQUIP_SLOTS.length)];
  const rarity = rarityId ? rarityById(rarityId) : rollRarity(luckPct, minTier);
  const main = {
    stat: slot.main,
    val: FLAT_STATS.has(slot.main)
      ? Math.max(1, Math.round(slot.mainBase * rarity.mult))
      : scaleVal(slot.mainBase, rarity.mult, stage),
  };
  const affixes = [];
  const pool = AFFIX_POOL.filter((a) => a.stat !== slot.main);
  const picked = new Set();
  for (let i = 0; i < rarity.affixes && pool.length; i++) {
    const weighted = [];
    for (const a of pool) {
      if (picked.has(a.stat)) continue;
      const w = a.favored.includes(slot.id) ? 3 : 1;
      for (let k = 0; k < w; k++) weighted.push(a);
    }
    if (!weighted.length) break;
    const a = weighted[Math.floor(Math.random() * weighted.length)];
    picked.add(a.stat);
    affixes.push({
      stat: a.stat,
      val: FLAT_STATS.has(a.stat)
        ? Math.max(1, Math.round(a.base))
        : scaleVal(a.base, 0.7 * rarity.mult, stage),
    });
  }
  if (rarity.id === "xian") {
    const ex = XIAN_EXCLUSIVE[slot.id];
    affixes.push({
      stat: ex.stat,
      val: FLAT_STATS.has(ex.stat) ? ex.base : scaleVal(ex.base, 1, stage),
      exclusive: true,
    });
  }
  return {
    id: `it${itemSeq++}`,
    slot: slot.id,
    rarity: rarity.id,
    stage,
    name: `${rarity.name}·${slot.name}`,
    main,
    affixes,
  };
}

// ---------------------------------------------------------------------------
// 背包与已装配（localStorage）
// ---------------------------------------------------------------------------

let bag = { items: [], equipped: {} };

function loadBag() {
  try {
    const raw = JSON.parse(localStorage.getItem(BAG_KEY) || "null");
    if (raw && Array.isArray(raw.items)) bag = { items: raw.items, equipped: raw.equipped || {} };
  } catch { /* 损坏则重置 */ }
}
loadBag();

function saveBag() {
  try {
    localStorage.setItem(BAG_KEY, JSON.stringify(bag));
  } catch { /* 静默 */ }
}

export function bagItems() {
  return bag.items;
}

export function equippedItem(slotId) {
  return bag.equipped[slotId] || null;
}

export function equippedAll() {
  return bag.equipped;
}

export function addItem(item) {
  bag.items.push(item);
  saveBag();
}

/** 装备：原部位装备回背包。 */
export function equipItem(itemId) {
  const idx = bag.items.findIndex((it) => it.id === itemId);
  if (idx < 0) return false;
  const item = bag.items.splice(idx, 1)[0];
  const old = bag.equipped[item.slot];
  if (old) bag.items.push(old);
  bag.equipped[item.slot] = item;
  saveBag();
  return true;
}

export function unequipSlot(slotId) {
  const old = bag.equipped[slotId];
  if (!old) return false;
  delete bag.equipped[slotId];
  bag.items.push(old);
  saveBag();
  return true;
}

export function discardItem(itemId) {
  const idx = bag.items.findIndex((it) => it.id === itemId);
  if (idx < 0) return false;
  bag.items.splice(idx, 1);
  saveBag();
  return true;
}

/** 已装配的全部主属性+词条 → mods（与天赋合并）。 */
export function equipMods() {
  const out = emptyMods();
  for (const item of Object.values(bag.equipped)) {
    if (!item) continue;
    const put = (stat, val) => {
      if (stat === "weightAdd") out.weightAdd += val;
      else if (stat === "mindSlotAdd") out.mindSlotAdd += val;
      else if (stat === "dualDef") {
        out.physDef += val;
        out.spellDef += val;
      } else if (stat in out) out[stat] += val;
    };
    put(item.main.stat, item.main.val);
    for (const a of item.affixes) put(a.stat, a.val);
  }
  return out;
}

export function combinedEquipTalentMods(talentModsObj) {
  return mergeMods(talentModsObj, equipMods());
}

export function itemLines(item) {
  if (!item) return [];
  const lines = [fmtStat(item.main.stat, item.main.val) + "（主）"];
  for (const a of item.affixes) {
    lines.push(fmtStat(a.stat, a.val) + (a.exclusive ? "（仙品专属）" : ""));
  }
  return lines;
}
