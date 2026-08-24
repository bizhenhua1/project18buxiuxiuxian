/**
 * 道途天赋树：数据、点数经济、分配/洗髓、修正聚合。
 *
 * 设计要点：
 * - 悟性点 = 已通过路点数 + 已通过 Boss 数（每 8 路点 1 个 Boss）
 * - 树为放射状：中心「道基」免费，四条主干 = 体修 / 法修 / 器道 / 御兽
 * - 节点效果分两类：
 *   1) 格位类（handSlots/mindSlots/beastSlots/fabaoSlots/weightAdd）→ 改变可上阵的卡牌构成
 *   2) 数值类（各种 Pct）→ 与装备词条走同一条 mods 聚合管线
 */

import { ACTIVE_SKILLS } from "./unit.js?v=dao7";

const STORE_KEY = "dao-talents-v1";

// ---------------------------------------------------------------------------
// 树数据
// ---------------------------------------------------------------------------

const D = Math.SQRT1_2; // 0.707…，四条主干的对角方向分量

/** 放射坐标辅助：dir=[dx,dy] 单位向量，r 半径，perp 垂直偏移 */
function pos(dir, r, perp = 0) {
  const px = -dir[1];
  const py = dir[0];
  return { x: Math.round(dir[0] * r + px * perp), y: Math.round(dir[1] * r + py * perp) };
}

const TI = [-D, -D]; // 体修：左上
const FA = [D, -D]; //  法修：右上
const QI = [-D, D]; //  器道：左下
const YU = [D, D]; //   御兽：右下

function node(id, name, kind, branch, at, desc, fx) {
  return { id, name, kind, branch, x: at.x, y: at.y, desc, fx };
}

export const TREE_NODES = [
  node("root", "道基", "root", "root", { x: 0, y: 0 }, "修行之始：全队攻+2%、生命+2%（免费）", { atkPct: 2, hpPct: 2 }),

  // ---- 体修（左上）：力量 / 手持格 / 反伤 / 减伤 ----
  node("b1", "蛮力", "small", "体修", pos(TI, 70), "力量预算+3（手持武器总重量上限）", { weightAdd: 3 }),
  node("b2", "两手蛮力", "notable", "体修", pos(TI, 135), "开启手持格×2：武器捏在手里，不占承伤位；力量+2", { handSlots: 2, weightAdd: 2 }),
  node("b3", "筋骨", "small", "体修", pos(TI, 150, 62), "全队生命+6%", { hpPct: 6 }),
  node("b4", "罡体", "small", "体修", pos(TI, 215, 78), "反伤+10%：我方单位被近战命中时反弹伤害", { thornsPct: 10 }),
  node("b5", "四臂罗汉", "notable", "体修", pos(TI, 200), "手持格再+2（共4），力量+3", { handSlots: 2, weightAdd: 3 }),
  node("b6", "铁布衫", "small", "体修", pos(TI, 215, -78), "全队受到伤害-5%", { dmgReducePct: 5 }),
  node("b7", "体魄", "small", "体修", pos(TI, 280, -84), "全队生命+8%", { hpPct: 8 }),
  node("b8", "三头六臂", "keystone", "体修", pos(TI, 262), "道果：手持格再+2（共6），力量+4——六臂各持凶兵", { handSlots: 2, weightAdd: 4 }),
  node("b9", "法宝合身", "keystone", "体修", pos(TI, 322), "道果：手持法宝血量继承比例+30%（基础30%→60%），且道童金刚护体（受伤-30%）——全队一根粗血条", { mergeHeldHpPct: 30, dmgReducePct: 30 }),
  node("b10", "猿臂", "small", "体修", pos(TI, 280, 84), "攻速+6%：降低道童与手持法宝的等效冷却", { atkSpeedPct: 6 }),
  node("b11", "锐目", "small", "体修", pos(TI, 345, 88), "暴击+5%：全队出手可暴击（基础暴伤150%）", { critPct: 5 }),
  node("b12", "刚劲", "small", "体修", pos(TI, 150, -62), "外伤+8%：全队外伤类攻击增伤", { physPct: 8 }),
  node("b13", "铁骨", "small", "体修", pos(TI, 345, -92), "外防+6：全队外伤防御点数（递减减伤）", { physDef: 6 }),

  // ---- 法修（右上）：识海格 / 法伤 / 技能冷却 ----
  node("f1", "凝神", "small", "法修", pos(FA, 70), "法伤+8%：全队法伤类攻击增伤（含法术治疗强度）", { spellPct: 8 }),
  node("f2", "识海开窍", "notable", "法修", pos(FA, 135), "开启识海格×2：法术无血量、不占承伤位，按 CD 自动施放", { mindSlots: 2 }),
  node("f3", "静心", "small", "法修", pos(FA, 150, -62), "全队冷却-3%", { cdPct: 3 }),
  node("f4", "神识", "small", "法修", pos(FA, 215, -78), "识海格+1", { mindSlots: 1 }),
  node("f5", "灵台清明", "notable", "法修", pos(FA, 200), "识海格再+2，法伤+8%", { mindSlots: 2, spellPct: 8 }),
  node("f6", "咒力", "small", "法修", pos(FA, 215, 78), "法伤+10%", { spellPct: 10 }),
  node("f7", "玄妙", "small", "法修", pos(FA, 280, 84), "全队冷却-4%", { cdPct: 4 }),
  node("f8", "万法周天", "keystone", "法修", pos(FA, 262), "道果：识海格再+3（共8），法伤+20%，但全队生命-10%", { mindSlots: 3, spellPct: 20, hpPct: -10 }),
  node("f9", "凝息", "small", "法修", pos(FA, 280, -84), "技能冷却-8%：只压缩主动技与识海法术的等效 CD", { skillCdrPct: 8 }),
  node("f10", "玄盾", "small", "法修", pos(FA, 345, -88), "法防+6：全队法伤防御点数（递减减伤）", { spellDef: 6 }),

  // ---- 器道（左下）：法宝格 / 剑阵 / 幡 ----
  node("q1", "御器", "small", "器道", pos(QI, 70), "法宝攻击+6%", { fabaoAtkPct: 6 }),
  node("q2", "多宝", "notable", "器道", pos(QI, 135), "法宝格+2（基础4）", { fabaoSlots: 2 }),
  node("q3", "炼器", "small", "器道", pos(QI, 150, -62), "法宝生命+8%", { fabaoHpPct: 8 }),
  node("q4", "剑心", "notable", "器道", pos(QI, 215, 78), "剑阵解锁：任一剑类出手时，其余存活剑类各追击 30% 伤害", { swordEchoPct: 30 }),
  node("q5", "剑意", "small", "器道", pos(QI, 280, 84), "剑阵追击伤害+12%", { swordEchoPct: 12 }),
  node("q9", "淬锋", "small", "器道", pos(QI, 345, 92), "暴伤+20%：全队暴击伤害倍率提高", { critDmgPct: 20 }),
  node("q6", "幡道", "notable", "器道", pos(QI, 215, -78), "幡类每层魂力加成 8%→12%", { fanPerStackPct: 12 }),
  node("q7", "器灵", "small", "器道", pos(QI, 200), "法宝攻击+8%", { fabaoAtkPct: 8 }),
  node("q8", "万宝归宗", "keystone", "器道", pos(QI, 262), "道果：法宝格再+3（共9），法宝攻血各+10%", { fabaoSlots: 3, fabaoAtkPct: 10, fabaoHpPct: 10 }),

  // ---- 御兽（右下）：捕获 / 兽栏格 / 共鸣 ----
  node("y1", "驭心", "small", "御兽", pos(YU, 70), "收服概率+10%（基础10%）", { capturePct: 10 }),
  node("y2", "兽栏", "notable", "御兽", pos(YU, 135), "开启兽栏格×2：可上阵炼化的妖兽", { beastSlots: 2 }),
  node("y3", "兽性", "small", "御兽", pos(YU, 215, -78), "御兽攻击+8%", { beastAtkPct: 8 }),
  node("y4", "血食", "small", "御兽", pos(YU, 280, -84), "御兽生命+10%", { beastHpPct: 10 }),
  node("y5", "扩栏", "notable", "御兽", pos(YU, 200), "兽栏格再+2", { beastSlots: 2 }),
  node("y6", "共鸣", "notable", "御兽", pos(YU, 215, 78), "兽魂共鸣：场上每有一种不同御兽，全队攻+2%", { beastResonance: true }),
  node("y7", "灵契", "small", "御兽", pos(YU, 150, 62), "收服概率+12%", { capturePct: 12 }),
  node("y8", "万兽山河", "keystone", "御兽", pos(YU, 262), "道果：兽栏格再+2（共6），御兽攻血各+12%；兽王血契：御兽死亡时道童回其最大生命 20% 的血", { beastSlots: 2, beastAtkPct: 12, beastHpPct: 12, bloodPact: true }),
];

export const TREE_EDGES = [
  ["root", "b1"], ["b1", "b2"], ["b2", "b5"], ["b5", "b8"], ["b8", "b9"],
  ["b2", "b3"], ["b3", "b4"], ["b5", "b6"], ["b6", "b7"],
  ["b4", "b10"], ["b10", "b11"],
  ["b2", "b12"], ["b12", "b6"], ["b7", "b13"],
  ["root", "f1"], ["f1", "f2"], ["f2", "f5"], ["f5", "f8"],
  ["f2", "f3"], ["f2", "f4"], ["f5", "f6"], ["f6", "f7"],
  ["f4", "f9"], ["f9", "f10"],
  ["root", "q1"], ["q1", "q2"], ["q2", "q7"], ["q7", "q8"],
  ["q2", "q3"], ["q1", "q4"], ["q4", "q5"], ["q2", "q6"],
  ["q5", "q9"],
  ["root", "y1"], ["y1", "y2"], ["y2", "y5"], ["y5", "y8"],
  ["y2", "y3"], ["y3", "y4"], ["y5", "y6"], ["y1", "y7"],
  // 交叉小路：跨道途 build 的走位
  ["b3", "f3"], // 顶部：体修↔法修
  ["b6", "q3"], // 左侧：体修↔器道（反伤/炼器）
  ["q6", "y3"], // 底部：器道↔御兽（幡御双修）
  ["f6", "y7"], // 右侧：法修↔御兽
];

const NODE_MAP = new Map(TREE_NODES.map((n) => [n.id, n]));
const ADJ = new Map();
for (const [a, b] of TREE_EDGES) {
  if (!ADJ.has(a)) ADJ.set(a, []);
  if (!ADJ.has(b)) ADJ.set(b, []);
  ADJ.get(a).push(b);
  ADJ.get(b).push(a);
}

// ---------------------------------------------------------------------------
// 分配状态
// ---------------------------------------------------------------------------

let alloc = new Set(["root"]);

function load() {
  try {
    const raw = JSON.parse(localStorage.getItem(STORE_KEY) || "null");
    if (raw && Array.isArray(raw.nodes)) {
      alloc = new Set(raw.nodes.filter((id) => NODE_MAP.has(id)));
    }
  } catch { /* 损坏则重置 */ }
  alloc.add("root");
}
load();

function save() {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify({ nodes: [...alloc] }));
  } catch { /* 存储不可用时静默 */ }
}

export function allocatedIds() {
  return new Set(alloc);
}

/** 悟性总点数：每路点 1 点，每过一个 Boss（第 8 路点）额外 1 点。 */
export function talentPoints(unlockStage) {
  const s = Math.max(0, Math.floor(unlockStage || 0));
  return s + Math.floor(s / 8);
}

export function spentPoints() {
  return alloc.size - 1; // root 免费
}

export function canAllocate(id, unlockStage) {
  const n = NODE_MAP.get(id);
  if (!n || alloc.has(id)) return false;
  if (spentPoints() >= talentPoints(unlockStage)) return false;
  return (ADJ.get(id) || []).some((nb) => alloc.has(nb));
}

export function allocate(id, unlockStage) {
  if (!canAllocate(id, unlockStage)) return false;
  alloc.add(id);
  save();
  return true;
}

/** 取消单点：仅当剩余已点节点仍与道基连通时允许。 */
export function deallocate(id) {
  if (id === "root" || !alloc.has(id)) return false;
  const rest = new Set(alloc);
  rest.delete(id);
  const seen = new Set(["root"]);
  const stack = ["root"];
  while (stack.length) {
    const cur = stack.pop();
    for (const nb of ADJ.get(cur) || []) {
      if (rest.has(nb) && !seen.has(nb)) {
        seen.add(nb);
        stack.push(nb);
      }
    }
  }
  for (const nid of rest) {
    if (!seen.has(nid)) return false;
  }
  alloc = rest;
  save();
  return true;
}

export function respec() {
  alloc = new Set(["root"]);
  save();
}

/** 进度回档（如清档）后点数不足时自动洗髓。 */
export function reconcile(unlockStage) {
  if (spentPoints() > talentPoints(unlockStage)) respec();
}

// ---------------------------------------------------------------------------
// 修正聚合（与装备词条共用同一 mods 形状）
// ---------------------------------------------------------------------------

export function emptyMods() {
  return {
    atkPct: 0, hpPct: 0, cdPct: 0, dmgReducePct: 0, thornsPct: 0,
    splashDmgPct: 0, splashN: 0, healPct: 0, shieldPct: 0,
    physPct: 0, spellPct: 0, physDef: 0, spellDef: 0, skillCdrPct: 0,
    capturePct: 0, luckPct: 0, weightAdd: 0, mindSlotAdd: 0,
    fabaoAtkPct: 0, fabaoHpPct: 0, beastAtkPct: 0, beastHpPct: 0,
    swordEchoPct: 0, fanPerStackPct: 0,
    atkSpeedPct: 0, critPct: 0, critDmgPct: 0, mergeHeldHpPct: 0, reviveCdrPct: 0,
    handSlots: 0, mindSlots: 0, beastSlots: 0, fabaoSlots: 0,
    beastResonance: false, bloodPact: false,
  };
}

export function mergeMods(...sources) {
  const out = emptyMods();
  for (const src of sources) {
    if (!src) continue;
    for (const [k, v] of Object.entries(src)) {
      if (typeof v === "boolean") out[k] = out[k] || v;
      else if (typeof v === "number") out[k] = (out[k] || 0) + v;
    }
  }
  return out;
}

export function talentMods() {
  const parts = [];
  for (const id of alloc) {
    const n = NODE_MAP.get(id);
    if (n) parts.push(n.fx);
  }
  return mergeMods(...parts);
}

/** 格位表：天赋（+装备词条）决定各类型卡的可上阵数量与重量预算。 */
export function slotTable(mods) {
  return {
    fabao: 4 + (mods.fabaoSlots || 0),
    hand: mods.handSlots || 0,
    mind: (mods.mindSlots || 0) + (mods.mindSlotAdd || 0),
    beast: mods.beastSlots || 0,
    weight: mods.weightAdd || 0,
  };
}

/** held 法宝：重量额外攻加成 ×(1+w×0.06)——举得动=打得狠（与 unit.js HELD_WEIGHT_ATK_STEP 同值）。 */
const HELD_WEIGHT_ATK_STEP = 0.06;
/** held 法宝血量并入主角的基础比例（%），恒定生效；mergeHeldHpPct 在此之上叠加。 */
export const HELD_HP_MERGE_BASE = 30;

function isHeld(unit) {
  return unit.cardType === "fabao" && unit.mode === "held";
}

/**
 * 把聚合修正落到我方单位上（在 applyEffectiveStats 之后调用）。
 * 幡层加成 / 剑阵 / 反伤 / 暴击等在战斗层读取这里写入的字段。
 */
export function applyPlayerMods(unit, mods) {
  if (!unit || unit.side !== "player") return unit;
  let atkPct = mods.atkPct;
  let hpPct = mods.hpPct;
  if (unit.cardType === "fabao") {
    atkPct += mods.fabaoAtkPct;
    hpPct += mods.fabaoHpPct;
  }
  if (unit.cardType === "beast") {
    atkPct += mods.beastAtkPct;
    hpPct += mods.beastHpPct;
  }
  // 伤害二元化：外伤%/法伤% 只增益对应 dmgType（识海法术默认法伤，故 spellPct 兼容旧「法术强度」语义）
  atkPct += unit.dmgType === "spell" ? mods.spellPct : mods.physPct;
  unit.atk = Math.max(1, Math.round(unit.atk * (1 + atkPct / 100)));
  if (isHeld(unit)) {
    unit.atk = Math.max(1, Math.round(unit.atk * (1 + (unit.weight || 0) * HELD_WEIGHT_ATK_STEP)));
  }
  unit.maxHp = Math.max(1, Math.round(unit.maxHp * (1 + hpPct / 100)));
  unit.hp = unit.maxHp;
  unit.cd = Math.max(400, Math.round(unit.cd * Math.max(0.5, 1 - mods.cdPct / 100)));
  // 攻速只作用于主角与手持法宝（与全队 cdPct 区分开）：等效 CD = CD / (1 + 攻速%)
  if ((unit.cardType === "char" || isHeld(unit)) && mods.atkSpeedPct > 0) {
    unit.cd = Math.max(400, Math.round(unit.cd / (1 + mods.atkSpeedPct / 100)));
  }
  // 技能冷却只压缩主动技（heal/shield/haste，held 封印时不吃）与识海法术的等效 CD
  const hasActiveSkill =
    unit.cardType === "spell" || (ACTIVE_SKILLS.has(unit.skill) && !isHeld(unit));
  if (hasActiveSkill && mods.skillCdrPct > 0) {
    unit.cd = Math.max(400, Math.round(unit.cd / (1 + mods.skillCdrPct / 100)));
  }
  unit.cdLeft = Math.min(unit.cdLeft, unit.cd);
  // 暴击/暴伤：全队通用属性（每单位生效）
  unit.critChance = Math.max(0, Math.min(1, mods.critPct / 100));
  unit.critDmg = 1.5 + Math.max(0, mods.critDmgPct) / 100;
  // 防御二元化：白板 + 天赋/词条点数
  unit.physDef = (unit.basePhysDef || 0) + Math.max(0, mods.physDef || 0);
  unit.spellDef = (unit.baseSpellDef || 0) + Math.max(0, mods.spellDef || 0);
  // 重聚时间是法宝自身属性，仅天赋/词条「重聚缩减%」可修改
  if (unit.cardType === "fabao") {
    const cdr = Math.max(0, Math.min(80, mods.reviveCdrPct || 0));
    unit.reviveMs = Math.max(1000, Math.round((unit.baseReviveMs || 0) * (1 - cdr / 100)));
  }
  unit.dmgReduce = Math.min(0.6, mods.dmgReducePct / 100);
  unit.thorns = Math.max(0, mods.thornsPct / 100);
  unit.splashMult = 0.5 * (1 + mods.splashDmgPct / 100);
  unit.splashN = 2 + (mods.splashN || 0);
  unit.healBoost = mods.healPct / 100 + (unit.cardType === "spell" ? mods.spellPct / 100 : 0);
  unit.shieldBoost = mods.shieldPct / 100;
  unit.swordEcho = mods.swordEchoPct > 0 ? mods.swordEchoPct / 100 : 0;
  unit.fanPerStack = mods.fanPerStackPct > 0 ? mods.fanPerStackPct / 100 : 0.08;
  return unit;
}

/**
 * 整队级效果（每次重算队列数值时调用）：
 * - 兽魂共鸣：按场上不同御兽种类给全队攻加成
 * - 手持继承：held 法宝血量按比例并入道童（基础 30% 恒定生效，「法宝合身」再+30%）
 */
export function applyQueueEffects(queue, mods) {
  const resonance = mods.beastResonance
    ? new Set(queue.filter((u) => u.cardType === "beast").map((u) => u.cardId)).size * 2
    : 0;
  for (const u of queue) {
    if (u.side !== "player") continue;
    if (resonance > 0) {
      u.atk = Math.max(1, Math.round(u.atk * (1 + resonance / 100)));
    }
  }
  const mergePct = HELD_HP_MERGE_BASE + Math.max(0, mods.mergeHeldHpPct || 0);
  const char = queue.find((u) => u.cardType === "char");
  if (char) {
    const pool = queue.filter(isHeld).reduce((s, u) => s + u.maxHp, 0);
    const bonus = Math.round((pool * mergePct) / 100);
    if (bonus > 0) {
      char.maxHp += bonus;
      char.hp = char.maxHp;
    }
  }
}

export function getNode(id) {
  return NODE_MAP.get(id) || null;
}
