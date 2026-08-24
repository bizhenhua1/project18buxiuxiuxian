/** 关卡成长：卡面数字永远是 1 级白板，开战/布阵用本文件算出的有效值。 */

export const NODES_PER_REGION = 8;

/**
 * 全部可调参数集中于此。改这里即可重算曲线，不必改战斗逻辑。
 *
 * 设计：玩家攻/血与怪攻/血走同一套「路点指数 × 换图台阶」，
 * 怪血再乘一个很慢的漂移，Boss 路点只加血（和少量攻）。
 * 这样 T_kill ≈ 怪血 / 我方 DPS 不会出现「玩家线性、怪指数」的后期打不动。
 */
export const BALANCE = {
  /** 每一路点（stage +1）的公共底数。建议 1.08～1.12 */
  stageGrowth: 1.09,
  /** 每进入一张新图（含循环第二圈）的台阶 */
  regionGrowth: 1.35,
  /** 玩家生命相对 core 的额外每关漂移（略厚，扛怪攻） */
  playerHpDrift: 1.008,
  /** 怪攻相对 core 的每关漂移 */
  monsterAtkDrift: 1.008,
  /** 怪血相对 core 的每关漂移（略快于玩家攻 → T_kill 缓慢变长） */
  monsterHpDrift: 1.012,
  /** 每图第 8 路点（nodeIndex === 7）额外生命 */
  bossHp: 1.4,
  /** Boss 轻微加攻，避免纯木桩 */
  bossAtk: 1.08,
  /**
   * CD 软下限：cdMult = cdMin + (1 - cdMin) / (1 + stage * cdHaste)
   * stage→∞ 时逼近 cdMin，不会无限加快。
   */
  cdMin: 0.78,
  cdHaste: 0.035,
  /** 绝对地板（毫秒），防止表配错把 CD 打到 0 */
  cdHardMinMs: 500,
  /** 防御递减公式常数：减伤率 = def / (def + defBase + defPerStage×关卡)，随关卡抬升防止防御白值碾压 */
  defBase: 60,
  defPerStage: 4,
  /** 防御减伤封顶 */
  defCap: 0.75,
  /** 敌方双防成长：每关 +defGrowthPerStage 点（外防法防各加） */
  defGrowthPerStage: 0.8,
  /** 敌方双伤成长：每关 +0.8%，封顶 +10%（温和曲线，既有数值 ±15% 内） */
  dmgGrowthPerStage: 0.008,
  dmgGrowthCap: 0.10,
  /** 敌方精英暴击：stage≥critBossStage 的 Boss 带基础暴击 */
  critBossStage: 5,
  bossCritChance: 0.10,
};

export function clampStage(stage) {
  const n = Number(stage);
  if (!Number.isFinite(n) || n < 0) return 0;
  return Math.floor(n);
}

export function regionIndex(stage) {
  return Math.floor(clampStage(stage) / NODES_PER_REGION);
}

export function nodeIndex(stage) {
  return clampStage(stage) % NODES_PER_REGION;
}

export function isBossStage(stage) {
  return nodeIndex(stage) === NODES_PER_REGION - 1;
}

/** 公共核：G^stage × R^region */
export function growthCore(stage) {
  const s = clampStage(stage);
  return BALANCE.stageGrowth ** s * BALANCE.regionGrowth ** regionIndex(s);
}

export function cdMult(stage) {
  const s = clampStage(stage);
  const { cdMin, cdHaste } = BALANCE;
  return cdMin + (1 - cdMin) / (1 + s * cdHaste);
}

export function playerMult(stage) {
  const s = clampStage(stage);
  const core = growthCore(s);
  return {
    atk: core,
    hp: core * BALANCE.playerHpDrift ** s,
    cd: cdMult(s),
    core,
    region: regionIndex(s),
    node: nodeIndex(s),
    boss: false,
  };
}

export function monsterMult(stage) {
  const s = clampStage(stage);
  const core = growthCore(s);
  const boss = isBossStage(s);
  return {
    atk: core * BALANCE.monsterAtkDrift ** s * (boss ? BALANCE.bossAtk : 1),
    hp: core * BALANCE.monsterHpDrift ** s * (boss ? BALANCE.bossHp : 1),
    cd: cdMult(s),
    core,
    region: regionIndex(s),
    node: nodeIndex(s),
    boss,
  };
}

function basesOf(unit) {
  return {
    atk: unit.baseAtk ?? unit.atk ?? 1,
    hp: unit.baseHp ?? unit.maxHp ?? unit.hp ?? 1,
    cd: unit.baseCd ?? unit.cd ?? 1000,
  };
}

/**
 * @param {object} unit 卡面或单位（优先读 baseAtk/baseHp/baseCd）
 * @param {number} stage
 * @param {"player"|"enemy"} side
 */
export function effectiveStats(unit, stage, side = "player") {
  const sideNow = side || unit?.side || "player";
  const m = sideNow === "enemy" ? monsterMult(stage) : playerMult(stage);
  const b = basesOf(unit || {});
  return {
    atk: Math.max(1, Math.round(b.atk * m.atk)),
    hp: Math.max(1, Math.round(b.hp * m.hp)),
    cd: Math.max(BALANCE.cdHardMinMs, Math.round(b.cd * m.cd)),
    mult: m,
  };
}

/** 防御递减：减伤率 = def / (def + 60 + 4×关卡)，封顶 75%。与百分比减伤（dmgReduce）相乘叠加。 */
export function defReduction(def, stage) {
  const d = Math.max(0, def || 0);
  if (d <= 0) return 0;
  const s = clampStage(stage);
  return Math.min(BALANCE.defCap, d / (d + BALANCE.defBase + BALANCE.defPerStage * s));
}

/** 把有效攻/血/CD/双防快照到单位上；布阵与开战前调用。 */
export function applyEffectiveStats(unit, stage) {
  if (!unit) return unit;
  const s = clampStage(stage);
  const e = effectiveStats(unit, stage, unit.side);
  unit.atk = e.atk;
  unit.maxHp = e.hp;
  unit.hp = e.hp;
  unit.cd = e.cd;
  unit.cdLeft = e.cd;
  unit.atkMult = e.mult.atk;
  unit.hpMult = e.mult.hp;
  unit.cdMult = e.mult.cd;
  unit.stageSnap = s;
  // 双防：白板基础值；敌方随关卡温和成长（我方成长走天赋/装备 mods，在 applyPlayerMods 中叠加）
  const enemy = unit.side === "enemy";
  const defAdd = enemy ? Math.round(s * BALANCE.defGrowthPerStage) : 0;
  unit.physDef = (unit.basePhysDef || 0) + defAdd;
  unit.spellDef = (unit.baseSpellDef || 0) + defAdd;
  if (enemy) {
    // 敌方双伤成长（外/法各随自身 dmgType 生效，直接折入攻击）
    const grow = Math.min(BALANCE.dmgGrowthCap, s * BALANCE.dmgGrowthPerStage);
    if (grow > 0) unit.atk = Math.max(1, Math.round(unit.atk * (1 + grow)));
    // 精英暴击：stage≥5 的 Boss 带 10% 基础暴击
    unit.critChance = s >= BALANCE.critBossStage && isBossStage(s) ? BALANCE.bossCritChance : 0;
    unit.critDmg = 1.5;
  }
  return unit;
}

export function fmtMult(n) {
  return Number(n).toFixed(2);
}
