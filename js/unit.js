import { applyEffectiveStats } from "./balance.js?v=dao1";

let uidSeq = 1;

const ART = "assets/style-e";

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
    tags: spec.tags || [],
    ...spec,
  };
}

/** 卡牌类型中文名（卡池/提示用） */
export const CARD_TYPE_NAMES = {
  char: "主角",
  fabao: "法宝",
  weapon: "武器",
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
    skill: "none",
    skillText: "主角，攻守均衡，单体攻击最左存活。手持武器与识海法术都系于他一身",
  }),
  card({
    id: "taomu-jian",
    name: "桃木剑",
    icon: "🗡️",
    pool: "player",
    theme: "crimson",
    tags: ["sword"],
    art: `${ART}/style-e-artifact-taomu-jian.png`,
    hp: 22,
    atk: 14,
    cd: 900,
    skill: "none",
    skillText: "攻高血薄，冷却短。属剑类：修出剑心后参与剑阵连携",
  }),
  card({
    id: "waci-yin",
    name: "瓦瓷印",
    icon: "🪨",
    pool: "player",
    theme: "steel",
    art: `${ART}/style-e-artifact-waci-yin.png`,
    hp: 42,
    atk: 6,
    cd: 1700,
    skill: "shield",
    skillText: "行动时获得护盾再攻击最左",
  }),
  card({
    id: "masuo",
    name: "麻索",
    icon: "🪢",
    pool: "player",
    theme: "amber",
    art: `${ART}/style-e-artifact-masuo.png`,
    hp: 28,
    atk: 5,
    cd: 1600,
    skill: "haste",
    skillText: "加速队列左右相邻友军冷却",
  }),
  card({
    id: "tongjing",
    name: "铜镜",
    icon: "🪞",
    pool: "player",
    theme: "violet",
    art: `${ART}/style-e-artifact-tongjing.png`,
    hp: 26,
    atk: 8,
    cd: 1500,
    ranged: true,
    atkType: "beam",
    skill: "splash",
    skillText: "光线，打最左并溅射其身后 2 张",
  }),
  card({
    id: "xiaohulu",
    name: "小葫芦",
    icon: "🫙",
    pool: "player",
    theme: "mint",
    art: `${ART}/style-e-artifact-xiaohulu.png`,
    hp: 32,
    atk: 5,
    cd: 1500,
    skill: "heal",
    skillText: "优先治疗伤员；全满则打对方最左存活单位",
  }),
  card({
    id: "juhun-fan",
    name: "聚魂幡",
    icon: "🚩",
    pool: "player",
    theme: "violet",
    tags: ["fan"],
    art: "",
    hp: 30,
    atk: 6,
    cd: 1500,
    skill: "none",
    skillText: "敌我任意单位死亡时幡叠 1 层魂力，每层攻击+8%。克送死复活流",
  }),
  // ==== 武器（手持格专用，重量受体修力量预算约束，不占承伤位）====
  card({
    id: "qingfeng-jian",
    name: "青锋剑",
    icon: "⚔️",
    pool: "player",
    cardType: "weapon",
    weight: 2,
    tags: ["sword"],
    theme: "steel",
    hp: 20,
    atk: 12,
    cd: 1000,
    skill: "none",
    skillText: "轻剑（重量2）。手持不占承伤位；属剑类可入剑阵",
  }),
  card({
    id: "xuantie-jian",
    name: "玄铁重剑",
    icon: "🗡",
    pool: "player",
    cardType: "weapon",
    weight: 3,
    tags: ["sword"],
    theme: "steel",
    hp: 34,
    atk: 22,
    cd: 1800,
    skill: "none",
    skillText: "重剑（重量3）。高锋利高重量；属剑类可入剑阵",
  }),
  card({
    id: "kaishan-fu",
    name: "开山斧",
    icon: "🪓",
    pool: "player",
    cardType: "weapon",
    weight: 4,
    theme: "crimson",
    hp: 40,
    atk: 30,
    cd: 2400,
    skill: "none",
    skillText: "巨斧（重量4）。极重极狠，冷却极长",
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
    skillText: "脆皮，冷却极快",
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
    skillText: "光线啄击最左",
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
    skillText: "皮厚攻低",
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
    skillText: "冲撞最左",
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
    skill: "splash",
    skillText: "光线打最左，并溅射其身后 2 张",
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
    skillText: "均衡低级怪",
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
    skill: "shield",
    skillText: "最肉，行动时叠一层护盾",
  }),
];

export const CARD_LIBRARY = [...PLAYER_LIBRARY, ...ENEMY_LIBRARY];

export function getCard(id) {
  return CARD_LIBRARY.find((c) => c.id === id);
}

/** 满血、满冷却（环未蓄力）、清护盾，开战/布阵/重置共用。 */
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
  return unit;
}

export function createUnit(cardId, side, index = 0, stage = 0) {
  const card = getCard(cardId);
  if (!card) throw new Error(`未知卡牌: ${cardId}`);
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
    cardType: fieldCardType(card, side),
    weight: card.weight || 0,
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
  const holdNote = unit.cardType === "weapon" ? "（手持，不占承伤位）" : unit.cardType === "spell" ? "（识海，无血量不可被攻击）" : "";
  return [
    `${unit.icon} ${unit.name}（${unit.side === "player" ? "我方" : "敌方"} · ${typeName}）${dead ? " · 尸体" : ""}`,
    `队列第 ${unit.index + 1} 位${role}${holdNote}`,
    `状态 ${dead ? "尸体" : "存活"}    生命 ${unit.hp}/${unit.maxHp}${baseHp}    护盾 ${unit.shield}`,
    `攻击 ${unit.atk}${baseAtk}    冷却 ${cdSec}s    ${dead ? "冷却已停" : `剩余 ${left}s`}`,
    `技能：${unit.skillText}`,
  ].join("\n");
}
