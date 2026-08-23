import { applyEffectiveStats } from "./balance.js?v=growth1";

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
    ...spec,
  };
}

/** 我方可选：主角 + 5 件低级法宝。卡池只显示这些。 */
export const PLAYER_LIBRARY = [
  card({
    id: "daotong",
    name: "道童",
    icon: "🧙",
    pool: "player",
    kind: "char",
    theme: "gold",
    art: `${ART}/style-e-char-daotong.png`,
    hp: 48,
    atk: 10,
    cd: 1400,
    skill: "none",
    skillText: "主角，攻守均衡，单体攻击最左存活",
  }),
  card({
    id: "taomu-jian",
    name: "桃木剑",
    icon: "🗡️",
    pool: "player",
    theme: "crimson",
    art: `${ART}/style-e-artifact-taomu-jian.png`,
    hp: 22,
    atk: 14,
    cd: 900,
    skill: "none",
    skillText: "攻高血薄，冷却短",
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
  return [
    `${unit.icon} ${unit.name}（${unit.side === "player" ? "我方" : "敌方"}）${dead ? " · 尸体" : ""}`,
    `队列第 ${unit.index + 1} 位${role}`,
    `状态 ${dead ? "尸体" : "存活"}    生命 ${unit.hp}/${unit.maxHp}${baseHp}    护盾 ${unit.shield}`,
    `攻击 ${unit.atk}${baseAtk}    冷却 ${cdSec}s    ${dead ? "冷却已停" : `剩余 ${left}s`}`,
    `技能：${unit.skillText}`,
  ].join("\n");
}
