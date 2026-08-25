import {
  livingUnits,
  leftmostTargetable,
  isTargetable,
  markCorpse,
  queueNeighbors,
  unitsBehind,
} from "./grid.js?v=dao12";
import { ACTIVE_SKILLS } from "./unit.js?v=dao12";
import { defReduction } from "./balance.js?v=dao12";

const RANGED_IDS = new Set(["tongjing", "yewu", "huangfeng"]);

/** 手持（held）法宝：主动技封印，退化为普攻；被动技照常。 */
function skillSealed(unit) {
  return unit.cardType === "fabao" && unit.mode === "held" && ACTIVE_SKILLS.has(unit.skill);
}

/** 暴击掷点：全队通用属性（critChance 每单位生效，敌方精英 Boss 也可带）。 */
function rollCrit(unit) {
  return (unit.critChance || 0) > 0 && Math.random() < unit.critChance;
}

/** 永远打对方当前最左边的「可承伤」存活单位（跳过尸体、法术、手持武器）。 */
export function findTarget(enemyQueue) {
  return leftmostTargetable(enemyQueue);
}

function lowestHpAlly(attacker, allyQueue) {
  const allies = livingUnits(allyQueue).filter((u) => u.uid !== attacker.uid && u.hp < u.maxHp);
  if (!allies.length) return null;
  allies.sort((a, b) => a.hp / a.maxHp - b.hp / b.maxHp || a.index - b.index);
  return allies[0];
}

function shotStyle(unit) {
  if (unit.atkType === "beam" || unit.atkType === "ranged" || unit.atkType === "melee") return unit.atkType;
  if (unit.ranged || RANGED_IDS.has(unit.cardId)) return "ranged";
  if (unit.skill === "splash") return "ranged";
  return "melee";
}

/** 幡类：魂力层数放大攻击。其余单位原样返回。 */
function attackAmount(unit) {
  let a = unit.atk;
  if ((unit.soulStacks || 0) > 0 && unit.tags?.includes("fan")) {
    a *= 1 + unit.soulStacks * (unit.fanPerStack || 0.08);
  }
  return a;
}

/**
 * 伤害结算：先按 dmgType 走对应防御的递减公式，再乘 dmgReduce（相乘叠加），最后过护盾。
 * dmgType: "phys"（外伤→外防）| "spell"（法伤→法防）| null（无类型，如真实伤害，不吃防御）。
 */
export function applyDamage(target, amount, dmgType = null) {
  const events = [];
  if (!target || target.status === "corpse" || target.hp <= 0) return events;
  const def = dmgType === "spell" ? target.spellDef : dmgType === "phys" ? target.physDef : 0;
  const defRed = defReduction(def, target.stageSnap || 0);
  let rest = Math.max(0, Math.round(amount * (1 - defRed) * (1 - (target.dmgReduce || 0))));
  if (rest <= 0) return events;
  let dealt = 0;
  if (target.shield > 0) {
    const absorbed = Math.min(target.shield, rest);
    target.shield -= absorbed;
    rest -= absorbed;
    dealt += absorbed;
  }
  if (rest > 0) {
    const hpHit = Math.min(Math.max(0, target.hp), rest);
    target.hp -= rest;
    dealt += hpHit;
  }
  events.push({ type: "damage", unit: target, amount: Math.round(amount), dealt, dmgType });
  if (target.hp <= 0) {
    markCorpse(target);
    events.push({ type: "death", unit: target });
  }
  return events;
}

export function applyHeal(target, amount) {
  const events = [];
  if (!target || target.status === "corpse") return events;
  const heal = Math.max(0, Math.round(amount));
  const before = target.hp;
  target.hp = Math.min(target.maxHp, target.hp + heal);
  const gained = target.hp - before;
  if (gained <= 0) return events;
  events.push({ type: "heal", unit: target, amount: gained });
  return events;
}

function foeQueue(attacker, state) {
  return attacker.side === "player" ? state.enemyQueue : state.playerQueue;
}

function allyQueue(attacker, state) {
  return attacker.side === "player" ? state.playerQueue : state.enemyQueue;
}

/** 识海法术：无血量、不占承伤位，按 CD 自动施放。 */
function castSpell(attacker, foes, allies) {
  const events = [];
  const power = attackAmount(attacker);

  if (attacker.spellKind === "mend") {
    const wounded = livingUnits(allies).filter((u) => u.uid !== attacker.uid && u.hp < u.maxHp);
    if (wounded.length) {
      events.push({ type: "cast", kind: "heal", from: attacker, to: wounded[0] });
      for (const u of wounded) {
        const heals = applyHeal(u, power * 0.8 * (1 + (attacker.healBoost || 0)));
        const gained = heals.reduce((s, ev) => s + (ev.type === "heal" ? ev.amount : 0), 0);
        attacker.healDone = (attacker.healDone || 0) + gained;
        events.push(...heals);
      }
      return events;
    }
    // 全满则轰击最左，避免空转
  }

  const target = findTarget(foes);
  if (!target) return events;
  attacker.lastTargetUid = target.uid;

  // 全队暴击：识海法术施放同样掷点（一次施放共享一次掷点）
  const crit = rollCrit(attacker);
  const critMult = crit ? attacker.critDmg || 1.5 : 1;

  if (attacker.spellKind === "fireball") {
    const all = livingUnits(foes).filter(isTargetable);
    all.forEach((foe, i) => {
      events.push({ type: "shot", style: "beam", from: attacker, to: foe, amount: power * critMult, crit, secondary: i > 0 });
    });
    return events;
  }
  if (attacker.spellKind === "bind") {
    target.cdLeft += 1400;
    events.push({ type: "buff", unit: target, amount: 0 });
    events.push({ type: "shot", style: "beam", from: attacker, to: target, amount: power * 0.4 * critMult, crit, secondary: false });
    return events;
  }
  if (attacker.spellKind === "bolt") {
    events.push({ type: "shot", style: "beam", from: attacker, to: target, amount: power * 2.2 * critMult, crit, secondary: false });
    return events;
  }
  // mend 落空或未知法术：普通一击
  events.push({ type: "shot", style: "beam", from: attacker, to: target, amount: power * critMult, crit, secondary: false });
  return events;
}

export function act(attacker, state, now) {
  const events = [];
  if (!attacker || attacker.status === "corpse" || attacker.hp <= 0) return events;

  const foes = foeQueue(attacker, state);
  const allies = allyQueue(attacker, state);

  attacker.actingUntil = now + 180;
  attacker.cdLeft = attacker.cd;

  if (attacker.cardType === "spell") {
    return castSpell(attacker, foes, allies);
  }

  const sealed = skillSealed(attacker);

  if (!sealed && attacker.skill === "heal") {
    const wounded = lowestHpAlly(attacker, allies);
    if (wounded) {
      const heal = Math.round(attacker.atk * 1.4 * (1 + (attacker.healBoost || 0)));
      attacker.lastTargetUid = wounded.uid;
      events.push({ type: "cast", kind: "heal", from: attacker, to: wounded });
      const heals = applyHeal(wounded, heal);
      const gained = heals.reduce((s, ev) => s + (ev.type === "heal" ? ev.amount : 0), 0);
      attacker.healDone = (attacker.healDone || 0) + gained;
      events.push(...heals);
      return events;
    }
  }

  if (!sealed && attacker.skill === "shield") {
    const gain = Math.round(attacker.maxHp * 0.18 * (1 + (attacker.shieldBoost || 0)));
    attacker.shield += gain;
    events.push({ type: "buff", unit: attacker, amount: gain });
  }

  if (!sealed && attacker.skill === "haste") {
    const near = queueNeighbors(allies, attacker);
    for (const u of near) u.cdLeft = Math.max(80, u.cdLeft - u.cd * 0.28);
    events.push({ type: "buff", unit: attacker, amount: near.length });
  }

  const target = findTarget(foes);
  if (!target) {
    attacker.lastTargetUid = null;
    return events;
  }
  attacker.lastTargetUid = target.uid;
  const style = shotStyle(attacker);
  const crit = rollCrit(attacker);
  const critMult = crit ? attacker.critDmg || 1.5 : 1;
  events.push({
    type: "shot",
    style,
    from: attacker,
    to: target,
    amount: attackAmount(attacker) * critMult,
    crit,
    secondary: false,
  });
  if (attacker.skill === "splash") {
    const n = attacker.splashN ?? 2;
    const mult = attacker.splashMult ?? 0.5;
    for (const extra of unitsBehind(foes, target, n).filter(isTargetable)) {
      events.push({
        type: "shot",
        style,
        from: attacker,
        to: extra,
        amount: attackAmount(attacker) * mult * critMult,
        crit,
        secondary: true,
      });
    }
  }
  // 剑阵连携（被动，手持剑照常参与）：剑类出手时，其余存活剑类各补一段追击
  if ((attacker.swordEcho || 0) > 0 && attacker.tags?.includes("sword")) {
    for (const ally of livingUnits(allies)) {
      if (ally.uid === attacker.uid || !ally.tags?.includes("sword")) continue;
      const echoCrit = rollCrit(ally);
      events.push({
        type: "shot",
        style: shotStyle(ally),
        from: ally,
        to: target,
        amount: attackAmount(ally) * attacker.swordEcho * (echoCrit ? ally.critDmg || 1.5 : 1),
        crit: echoCrit,
        secondary: true,
      });
    }
  }
  return events;
}

export function resolveShot(shot) {
  const events = [];
  if (shot.style === "heal") {
    const heals = applyHeal(shot.to, shot.amount);
    const gained = heals.reduce((s, ev) => s + (ev.type === "heal" ? ev.amount : 0), 0);
    if (shot.from) shot.from.healDone = (shot.from.healDone || 0) + gained;
    events.push(...heals);
    return events;
  }
  // 伤害类型取自出手者（外伤/法伤各走对应防御）
  const dmgType = shot.dmgType || (shot.from && shot.from.dmgType) || "phys";
  const hits = applyDamage(shot.to, shot.amount, dmgType);
  const dealt = hits.reduce((s, ev) => s + (ev.type === "damage" ? (ev.dealt || 0) : 0), 0);
  if (shot.from) shot.from.damageDealt = (shot.from.damageDealt || 0) + dealt;
  if (shot.crit) {
    for (const ev of hits) {
      if (ev.type === "damage") ev.crit = true;
    }
  }
  events.push(...hits);
  // 反伤：近战命中后按承伤者 thorns 比例反弹给攻击者
  if (
    shot.style === "melee" &&
    dealt > 0 &&
    (shot.to.thorns || 0) > 0 &&
    shot.from &&
    shot.from.status === "alive" &&
    shot.from.hp > 0
  ) {
    const reflect = Math.round(dealt * shot.to.thorns);
    if (reflect > 0) {
      // 反伤定为外伤
      const back = applyDamage(shot.from, reflect, "phys");
      const rDealt = back.reduce((s, ev) => s + (ev.type === "damage" ? (ev.dealt || 0) : 0), 0);
      shot.to.damageDealt = (shot.to.damageDealt || 0) + rDealt;
      events.push(...back);
    }
  }
  return events;
}

/** 道童阵亡则其手持（held）法宝与识海法术随之消散（尸体占位）；操控（station）法宝不受影响。 */
function collapseOrphans(queue) {
  const events = [];
  const living = livingUnits(queue);
  if (!living.length) return events;
  const hasChar = living.some((u) => u.cardType === "char");
  if (hasChar) return events;
  for (const u of living) {
    if (u.cardType === "spell" || (u.cardType === "fabao" && u.mode === "held")) {
      markCorpse(u);
      events.push({ type: "death", unit: u });
    }
  }
  return events;
}

/**
 * 死亡后处理（主流程在事件结算后调用）：
 * - 幡：敌我任意死亡，场上所有存活幡叠 1 层魂力
 * - 操控法宝：被击毁后启动重聚计时（经过自身 reviveMs 原位满血复活）
 * - 御兽收服：记录被击杀的敌方妖兽
 * - 兽王血契：我方御兽死亡时为道童回血
 * 返回附加事件（治疗跳字等）。
 */
export function processDeaths(state, events) {
  const extra = [];
  for (const ev of events) {
    if (ev.type !== "death") continue;
    // station 法宝自行复活：死亡次数不影响重聚时长，仅天赋/词条「重聚缩减」可修改
    if (
      ev.unit.side === "player" &&
      ev.unit.cardType === "fabao" &&
      ev.unit.mode === "station" &&
      (ev.unit.reviveMs || 0) > 0
    ) {
      ev.unit.reviveLeft = ev.unit.reviveMs;
    }
    for (const q of [state.playerQueue, state.enemyQueue]) {
      for (const u of q) {
        if (u.status === "alive" && u.hp > 0 && u.tags?.includes("fan")) {
          u.soulStacks = (u.soulStacks || 0) + 1;
          extra.push({ type: "buff", unit: u, amount: u.soulStacks });
        }
      }
    }
    if (ev.unit.side === "enemy" && ev.unit.pool === "enemy") {
      (state.killedEnemies ||= []).push(ev.unit.cardId);
    }
    if (ev.unit.side === "player" && ev.unit.cardType === "beast" && state.bloodPact) {
      const char = state.playerQueue.find((u) => u.cardType === "char" && u.status === "alive" && u.hp > 0);
      if (char) {
        const heals = applyHeal(char, ev.unit.maxHp * 0.2);
        extra.push(...heals);
      }
    }
  }
  return extra;
}

export function tick(state, dt, now) {
  const events = [];
  events.push(...collapseOrphans(state.playerQueue));
  // 操控法宝重聚：计时走完则原位满血复活（护盾清零、冷却重蓄）
  for (const u of state.playerQueue) {
    if (!u || u.status !== "corpse" || (u.reviveLeft || 0) <= 0) continue;
    u.reviveLeft -= dt;
    if (u.reviveLeft <= 0) {
      u.reviveLeft = 0;
      u.status = "alive";
      u.hp = u.maxHp;
      u.shield = 0;
      u.cdLeft = u.cd;
      u.lastTargetUid = null;
      events.push({ type: "revive", unit: u });
    }
  }
  const all = [...livingUnits(state.playerQueue), ...livingUnits(state.enemyQueue)];
  all.sort((a, b) => a.uid - b.uid);

  for (const unit of all) {
    if (unit.status === "corpse" || unit.hp <= 0) continue;
    unit.cdLeft -= dt;
    if (unit.cdLeft <= 0) {
      events.push(...act(unit, state, now));
    }
  }
  return events;
}

/** 我方还有「重聚中」的法宝时不判负：战斗继续直到重聚回归或主角侧真正无人。 */
export function hasPendingRevive(queue) {
  return queue.some((u) => u && u.status === "corpse" && (u.reviveLeft || 0) > 0);
}

export function checkWinner(state) {
  const pAlive = livingUnits(state.playerQueue).length;
  const eAlive = livingUnits(state.enemyQueue).length;
  // 主角阵亡即战败：道童一倒直接判负（敌方同刻恰好全灭则算平局），
  // 不再等其余存活单位或重聚中的法宝；无道童的阵容仍走「全灭才判负」旧规则。
  const char = state.playerQueue.find((u) => u && u.cardType === "char");
  if (char && char.status === "corpse") {
    state.winner = eAlive === 0 ? "draw" : "enemy";
    return;
  }
  if (pAlive === 0 && hasPendingRevive(state.playerQueue)) {
    state.winner = null;
    return;
  }
  if (pAlive === 0 && eAlive === 0) state.winner = "draw";
  else if (pAlive === 0) state.winner = "enemy";
  else if (eAlive === 0) state.winner = "player";
  else state.winner = null;
}

export function collectTargetPairs(state) {
  const pairs = [];
  const sides = [
    [livingUnits(state.playerQueue), state.enemyQueue],
    [livingUnits(state.enemyQueue), state.playerQueue],
  ];
  for (const [units, foes] of sides) {
    const focus = findTarget(foes);
    for (const u of units) {
      let t = null;
      const allies = u.side === "player" ? state.playerQueue : state.enemyQueue;
      if (u.skill === "heal") t = lowestHpAlly(u, allies);
      if (!t) t = focus;
      if (t) pairs.push({ from: u, to: t });
    }
  }
  return pairs;
}
