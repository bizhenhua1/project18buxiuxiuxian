import { applyEffectiveStats } from "./balance.js?v=dao6";

let uidSeq = 1;

const ART = "assets/style-e";

// ---------------------------------------------------------------------------
// 法宝归一化：重量映射数值 + 双模式（手持 held / 法术操控 station）
// ---------------------------------------------------------------------------

/** 重量→数值映射系数：血 ×(1+w×0.25)、攻 ×(1+w×0.18)、CD ×(1+w×0.12)。 */
export const WEIGHT_HP_STEP = 0.25;
export const WEIGHT_ATK_STEP = 0.18;
export const WEIGHT_CD_STEP = 0.12;
/** 手持模式额外攻击加成 ×(1+w×0.06)：举得动 = 打得狠。 */
export const HELD_WEIGHT_ATK_STEP = 0.06;
/** held 法宝血量并入主角的基础比例（%），天赋 mergeHeldHpPct 在此之上叠加。 */
export const HELD_HP_MERGE_BASE = 30;
/** 主动技（手持时封印，退化为普攻）；幡叠层/剑阵连携为被动技，两种模式都生效。 */
export const ACTIVE_SKILLS = new Set(["heal", "shield", "haste"]);

function card(spec) {
  return {
    face: 1,
    lv: 1,
    icon: spec.icon || "•",
    ranged: false,
    atkType: spec.atkType || (spec.ranged ? "ranged" : "melee"),
    skill: "none",
    kind: spec.pool === "enemy" ? "monster" : "artifact",
    cardType: spec.cardType || (spec.pool === "enemy" ? "monster" : "fabao"),
    weight: spec.weight || 0,
    reviveMs: spec.reviveMs || 0,
    // 伤害二元化：外伤 phys / 法伤 spell（识海法术默认法伤）；治疗/护盾无类型
    dmgType: spec.dmgType || (spec.cardType === "spell" ? "spell" : "phys"),
    // 防御二元化：外防/法防白板（多数 0~小值，坦克型给防御）
    physDef: spec.physDef || 0,
    spellDef: spec.spellDef || 0,
    tags: spec.tags || [],
    ...spec,
  };
}

/**
 * 法宝卡：base 为基准三围（按「映射后 ≈ 原手感数值」回推），
 * 卡面数值 = 基准 × 重量映射，避免归一化造成平衡大崩。
 */
function fabao(spec) {
  const { base, weight } = spec;
  return card({
    ...spec,
    cardType: "fabao",
    hp: Math.round(base.hp * (1 + weight * WEIGHT_HP_STEP)),
    atk: Math.round(base.atk * (1 + weight * WEIGHT_ATK_STEP)),
    cd: Math.round(base.cd * (1 + weight * WEIGHT_CD_STEP)),
  });
}

/** 卡牌类型中文名（卡池/提示用） */
export const CARD_TYPE_NAMES = {
  char: "主角",
  fabao: "法宝",
  spell: "法术",
  beast: "御兽",
  monster: "妖兽",
};

/** 上阵后的实际类型：敌方卡被我方收服后以御兽身份上场。 */
export function fieldCardType(cardDef, side) {
  if (side === "player" && cardDef.pool === "enemy") return "beast";
  return cardDef.cardType || (cardDef.pool === "enemy" ? "monster" : "fabao");
}

/** 我方可选：主角 + 5 件低级法宝。卡池只显示这些。 */
export const PLAYER_LIBRARY = [
  card({
    id: "daotong",
    name: "道童",
    icon: "🧙",
    pool: "player",
    kind: "char",
    cardType: "char",
    theme: "gold",
    art: `${ART}/style-e-char-daotong.png`,
    hp: 48,
    atk: 10,
    cd: 1400,
    dmgType: "phys",
    physDef: 2,
    spellDef: 2,
    skill: "none",
    skillText: "主角，攻守均衡，单体攻击最左存活（外伤）。手持法宝与识海法术都系于他一身",
  }),
  fabao({
    id: "taomu-jian",
    name: "桃木剑",
    icon: "🗡️",
    pool: "player",
    theme: "crimson",
    tags: ["sword"],
    art: `${ART}/style-e-artifact-taomu-jian.png`,
    weight: 1,
    reviveMs: 4500,
    base: { hp: 17.6, atk: 11.86, cd: 803.6 },
    skill: "none",
    skillText: "攻高血薄，冷却短。属剑类：修出剑心后参与剑阵连携（被动，手持照常生效）",
  }),
  fabao({
    id: "waci-yin",
    name: "瓦瓷印",
    icon: "🪨",
    pool: "player",
    theme: "steel",
    art: `${ART}/style-e-artifact-waci-yin.png`,
    weight: 3,
    reviveMs: 7000,
    base: { hp: 24, atk: 3.9, cd: 1250 },
    dmgType: "spell",
    physDef: 6,
    spellDef: 6,
    skill: "shield",
    skillText: "主动技：行动时获得护盾再攻击最左（法伤；手持时封印，退化为普攻）。印身厚重，自带双防",
  }),
  fabao({
    id: "masuo",
    name: "麻索",
    icon: "🪢",
    pool: "player",
    theme: "amber",
    art: `${ART}/style-e-artifact-masuo.png`,
    weight: 1,
    reviveMs: 4000,
    base: { hp: 22.4, atk: 4.24, cd: 1428.6 },
    skill: "haste",
    skillText: "主动技：加速队列左右相邻友军冷却（手持时封印，退化为普攻）",
  }),
  fabao({
    id: "tongjing",
    name: "铜镜",
    icon: "🪞",
    pool: "player",
    theme: "violet",
    art: `${ART}/style-e-artifact-tongjing.png`,
    weight: 2,
    reviveMs: 5500,
    base: { hp: 17.33, atk: 5.88, cd: 1209.7 },
    dmgType: "spell",
    ranged: true,
    atkType: "beam",
    skill: "splash",
    skillText: "镜光法伤，打最左并溅射其身后 2 张（攻击形态，两种模式都生效）",
  }),
  fabao({
    id: "xiaohulu",
    name: "小葫芦",
    icon: "🫙",
    pool: "player",
    theme: "mint",
    art: `${ART}/style-e-artifact-xiaohulu.png`,
    weight: 2,
    reviveMs: 5500,
    base: { hp: 21.33, atk: 3.68, cd: 1209.7 },
    dmgType: "spell",
    skill: "heal",
    skillText: "主动技：优先治疗伤员，全满则以灵气打对方最左（法伤；手持时封印，退化为普攻）",
  }),
  fabao({
    id: "juhun-fan",
    name: "聚魂幡",
    icon: "🚩",
    pool: "player",
    theme: "violet",
    tags: ["fan"],
    art: "",
    weight: 2,
    reviveMs: 6000,
    base: { hp: 20, atk: 4.41, cd: 1209.7 },
    dmgType: "spell",
    skill: "none",
    skillText: "被动：敌我任意单位死亡时幡叠 1 层魂力，每层攻击+8%（手持照常叠层）。魂噬为法伤，克送死复活流",
  }),
  fabao({
    id: "qingfeng-jian",
    name: "青锋剑",
    icon: "⚔️",
    pool: "player",
    tags: ["sword"],
    theme: "steel",
    weight: 2,
    reviveMs: 5000,
    base: { hp: 13.33, atk: 8.82, cd: 806.5 },
    skill: "none",
    skillText: "轻剑：锋利趁手。属剑类可入剑阵（被动，手持照常生效）",
  }),
  fabao({
    id: "xuantie-jian",
    name: "玄铁重剑",
    icon: "🗡",
    pool: "player",
    tags: ["sword"],
    theme: "steel",
    weight: 3,
    reviveMs: 7500,
    base: { hp: 19.43, atk: 14.29, cd: 1323.5 },
    skill: "none",
    skillText: "重剑：高锋利高重量。属剑类可入剑阵（被动，手持照常生效）",
  }),
  fabao({
    id: "kaishan-fu",
    name: "开山斧",
    icon: "🪓",
    pool: "player",
    theme: "crimson",
    weight: 4,
    reviveMs: 9000,
    base: { hp: 20, atk: 17.44, cd: 1621.6 },
    skill: "none",
    skillText: "巨斧：极重极狠，冷却极长。手持时重量加成最高",
  }),
  // ==== 法术（识海格专用，无血量、不占承伤位、不可被攻击）====
  card({
    id: "lihuo-shu",
    name: "离火术",
    icon: "🔥",
    pool: "player",
    cardType: "spell",
    spellKind: "fireball",
    theme: "crimson",
    atkType: "beam",
    hp: 10,
    atk: 9,
    cd: 2600,
    skill: "none",
    skillText: "识海法术：烈焰席卷敌方全体可承伤单位",
  }),
  card({
    id: "bingfu-jue",
    name: "冰缚诀",
    icon: "❄️",
    pool: "player",
    cardType: "spell",
    spellKind: "bind",
    theme: "steel",
    atkType: "beam",
    hp: 10,
    atk: 8,
    cd: 2200,
    skill: "none",
    skillText: "识海法术：冰缚敌方最左，延迟其行动 1.4 秒并造成 40% 伤害",
  }),
  card({
    id: "tianlei-yin",
    name: "天雷引",
    icon: "⚡",
    pool: "player",
    cardType: "spell",
    spellKind: "bolt",
    theme: "gold",
    atkType: "beam",
    hp: 10,
    atk: 11,
    cd: 2800,
    skill: "none",
    skillText: "识海法术：引天雷轰击敌方最左，造成 220% 伤害",
  }),
  card({
    id: "huichun-shu",
    name: "回春术",
    icon: "🌿",
    pool: "player",
    cardType: "spell",
    spellKind: "mend",
    theme: "mint",
    hp: 10,
    atk: 7,
    cd: 2400,
    skill: "none",
    skillText: "识海法术：灵雨润泽，治疗我方全体伤员 80% 攻击的生命",
  }),
];

/** 敌方：10 只低级怪物。预设/随机只抽这些。 */
export const ENEMY_LIBRARY = [
  card({
    id: "huoli",
    name: "火狸",
    icon: "🦊",
    pool: "enemy",
    theme: "crimson",
    art: `${ART}/style-e-monster-huoli.png`,
    hp: 18,
    atk: 8,
    cd: 850,
    dmgType: "spell",
    spellDef: 2,
    skillText: "妖火扑咬（法伤），脆皮，冷却极快",
  }),
  card({
    id: "caoshe",
    name: "草蛇",
    icon: "🐍",
    pool: "enemy",
    theme: "jade",
    art: `${ART}/style-e-monster-caoshe.png`,
    hp: 20,
    atk: 7,
    cd: 1000,
    skillText: "低级单体",
  }),
  card({
    id: "yewu",
    name: "野乌",
    icon: "🐦",
    pool: "enemy",
    theme: "violet",
    art: `${ART}/style-e-monster-yewu.png`,
    hp: 16,
    atk: 9,
    cd: 1100,
    ranged: true,
    atkType: "beam",
    dmgType: "spell",
    skillText: "妖光啄击最左（法伤）",
  }),
  card({
    id: "jinchan",
    name: "金蟾",
    icon: "🐸",
    pool: "enemy",
    theme: "gold",
    art: `${ART}/style-e-monster-jinchan.png`,
    hp: 36,
    atk: 5,
    cd: 1600,
    physDef: 8,
    spellDef: 2,
    skillText: "皮厚攻低，外防高",
  }),
  card({
    id: "shujing",
    name: "鼠精",
    icon: "🐀",
    pool: "enemy",
    theme: "amber",
    art: `${ART}/style-e-monster-shujing.png`,
    hp: 18,
    atk: 7,
    cd: 800,
    skillText: "极快单体",
  }),
  card({
    id: "yezhu",
    name: "野猪",
    icon: "🐗",
    pool: "enemy",
    theme: "crimson",
    art: `${ART}/style-e-monster-yezhu.png`,
    hp: 32,
    atk: 9,
    cd: 1500,
    physDef: 4,
    skillText: "冲撞最左（外伤），糙皮带外防",
  }),
  card({
    id: "xiaoqiao",
    name: "小蛟",
    icon: "🐉",
    pool: "enemy",
    theme: "jade",
    art: `${ART}/style-e-monster-xiaoqiao.png`,
    hp: 24,
    atk: 8,
    cd: 1600,
    atkType: "beam",
    dmgType: "spell",
    spellDef: 4,
    skill: "splash",
    skillText: "蛟息法伤打最左，并溅射其身后 2 张；有灵性带法防",
  }),
  card({
    id: "shanyang",
    name: "山羊",
    icon: "🐐",
    pool: "enemy",
    theme: "steel",
    art: `${ART}/style-e-monster-shanyang.png`,
    hp: 28,
    atk: 8,
    cd: 1400,
    physDef: 3,
    spellDef: 3,
    skillText: "均衡低级怪，双防各有一点",
  }),
  card({
    id: "huangfeng",
    name: "黄蜂",
    icon: "🐝",
    pool: "enemy",
    theme: "amber",
    art: `${ART}/style-e-monster-huangfeng.png`,
    hp: 14,
    atk: 8,
    cd: 900,
    ranged: true,
    atkType: "beam",
    skillText: "光线，血薄手快",
  }),
  card({
    id: "shitoujing",
    name: "石头精",
    icon: "🪨",
    pool: "enemy",
    theme: "steel",
    art: `${ART}/style-e-monster-shitoujing.png`,
    hp: 44,
    atk: 5,
    cd: 1900,
    physDef: 12,
    spellDef: 6,
    skill: "shield",
    skillText: "最肉，双防最高，行动时叠一层护盾",
  }),
];

export const CARD_LIBRARY = [...PLAYER_LIBRARY, ...ENEMY_LIBRARY];

export function getCard(id) {
  return CARD_LIBRARY.find((c) => c.id === id);
}

/** 满血、满冷却（环未蓄力）、清护盾、清重聚计时，开战/布阵/重置共用。 */
export function resetCombatState(unit) {
  if (!unit) return unit;
  unit.hp = unit.maxHp;
  unit.cdLeft = unit.cd;
  unit.shield = 0;
  unit.status = "alive";
  unit.lastTargetUid = null;
  unit.actingUntil = 0;
  unit.damageDealt = 0;
  unit.healDone = 0;
  unit.soulStacks = 0;
  unit.reviveLeft = 0;
  return unit;
}

export function createUnit(cardId, side, index = 0, stage = 0, mode = "station") {
  const card = getCard(cardId);
  if (!card) throw new Error(`未知卡牌: ${cardId}`);
  const cardType = fieldCardType(card, side);
  const unit = {
    uid: uidSeq++,
    cardId: card.id,
    name: card.name,
    icon: card.icon,
    art: card.art || "",
    theme: card.theme || "gold",
    ranged: !!card.ranged,
    atkType: card.atkType || (card.ranged ? "ranged" : "melee"),
    pool: card.pool,
    kind: card.kind || (card.pool === "enemy" ? "monster" : card.id === "daotong" ? "char" : "artifact"),
    cardType,
    // 法宝双模式：held=手持（不占承伤位、主动技封印）；station=法术操控（独立血条、击毁后自行重聚）
    mode: cardType === "fabao" ? (mode === "held" ? "held" : "station") : "",
    weight: card.weight || 0,
    baseReviveMs: card.reviveMs || 0,
    reviveMs: card.reviveMs || 0,
    reviveLeft: 0,
    critChance: 0,
    critDmg: 1.5,
    // 伤害类型与双防（applyEffectiveStats 依据 base 值快照，敌方随关卡成长，我方由 mods 叠加）
    dmgType: card.dmgType || "phys",
    basePhysDef: card.physDef || 0,
    baseSpellDef: card.spellDef || 0,
    physDef: card.physDef || 0,
    spellDef: card.spellDef || 0,
    tags: card.tags || [],
    spellKind: card.spellKind || "",
    face: card.face,
    side,
    index,
    baseAtk: card.atk,
    baseHp: card.hp,
    baseCd: card.cd,
    hp: card.hp,
    maxHp: card.hp,
    atk: card.atk,
    cd: card.cd,
    cdLeft: card.cd,
    shield: 0,
    skill: card.skill,
    skillText: card.skillText,
    status: "alive",
    lv: card.lv ?? card.face ?? 1,
    lastTargetUid: null,
    actingUntil: 0,
    damageDealt: 0,
    healDone: 0,
    // 天赋/装备驱动的战斗修正（applyPlayerMods 会覆写我方单位）
    soulStacks: 0,
    thorns: 0,
    dmgReduce: 0,
    splashN: 2,
    splashMult: 0.5,
    healBoost: 0,
    shieldBoost: 0,
    swordEcho: 0,
    fanPerStack: 0.08,
  };
  applyEffectiveStats(unit, stage);
  return resetCombatState(unit);
}

export function unitDesc(unit) {
  if (!unit) return "从卡池拖到我方这一排插入。队列左对齐，最左是对方集火点。";
  const cdSec = (unit.cd / 1000).toFixed(1);
  const left = Math.max(0, unit.cdLeft / 1000).toFixed(2);
  const dead = unit.status === "corpse";
  const role = dead ? "（尸体，仍占原位）" : unit.index === 0 ? "（队列最左格）" : "";
  const baseAtk = unit.baseAtk != null ? `（白板 ${unit.baseAtk}）` : "";
  const baseHp = unit.baseHp != null ? `（白板 ${unit.baseHp}）` : "";
  const typeName = CARD_TYPE_NAMES[unit.cardType] || "法宝";
  const holdNote =
    unit.cardType === "fabao" && unit.mode === "held"
      ? "（手持，不占承伤位，主动技封印）"
      : unit.cardType === "fabao"
        ? `（操控，击毁后 ${(unit.reviveMs / 1000).toFixed(1)}s 原位重聚）`
        : unit.cardType === "spell"
          ? "（识海，无血量不可被攻击）"
          : "";
  return [
    `${unit.icon} ${unit.name}（${unit.side === "player" ? "我方" : "敌方"} · ${typeName}）${dead ? " · 尸体" : ""}`,
    `队列第 ${unit.index + 1} 位${role}${holdNote}`,
    `状态 ${dead ? "尸体" : "存活"}    生命 ${unit.hp}/${unit.maxHp}${baseHp}    护盾 ${unit.shield}`,
    `攻击 ${unit.atk}${baseAtk}（${unit.dmgType === "spell" ? "法伤" : "外伤"}）    冷却 ${cdSec}s    ${dead ? "冷却已停" : `剩余 ${left}s`}`,
    `外防 ${unit.physDef || 0}    法防 ${unit.spellDef || 0}${unit.critChance > 0 ? `    暴击 ${Math.round(unit.critChance * 100)}% / 暴伤 ${Math.round((unit.critDmg || 1.5) * 100)}%` : ""}`,
    `技能：${unit.skillText}`,
  ].join("\n");
}
