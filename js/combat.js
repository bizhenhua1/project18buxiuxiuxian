import {
  livingUnits,
  leftmost,
  markCorpse,
  queueNeighbors,
  unitsBehind,
} from "./grid.js?v=cap10";

const RANGED_IDS = new Set(["tongjing", "yewu", "huangfeng"]);

/** 永远打对方当前最左边的存活单位，跳过尸体。 */
export function findTarget(enemyQueue) {
  return leftmost(enemyQueue);
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

export function applyDamage(target, amount) {
  const events = [];
  if (!target || target.status === "corpse" || target.hp <= 0) return events;
  let rest = Math.max(0, Math.round(amount));
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
  events.push({ type: "damage", unit: target, amount: Math.round(amount), dealt });
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

export function act(attacker, state, now) {
  const events = [];
  if (!attacker || attacker.status === "corpse" || attacker.hp <= 0) return events;

  const foes = foeQueue(attacker, state);
  const allies = allyQueue(attacker, state);

  attacker.actingUntil = now + 180;
  attacker.cdLeft = attacker.cd;

  if (attacker.skill === "heal") {
    const wounded = lowestHpAlly(attacker, allies);
    if (wounded) {
      const heal = Math.round(attacker.atk * 1.4);
      attacker.lastTargetUid = wounded.uid;
      events.push({ type: "cast", kind: "heal", from: attacker, to: wounded });
      const heals = applyHeal(wounded, heal);
      const gained = heals.reduce((s, ev) => s + (ev.type === "heal" ? ev.amount : 0), 0);
      attacker.healDone = (attacker.healDone || 0) + gained;
      events.push(...heals);
      return events;
    }
  }

  if (attacker.skill === "shield") {
    const gain = Math.round(attacker.maxHp * 0.18);
    attacker.shield += gain;
    events.push({ type: "buff", unit: attacker, amount: gain });
  }

  if (attacker.skill === "haste") {
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
  events.push({
    type: "shot",
    style,
    from: attacker,
    to: target,
    amount: attacker.atk,
    secondary: false,
  });
  if (attacker.skill === "splash") {
    for (const extra of unitsBehind(foes, target, 2)) {
      events.push({
        type: "shot",
        style,
        from: attacker,
        to: extra,
        amount: attacker.atk * 0.5,
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
  const hits = applyDamage(shot.to, shot.amount);
  const dealt = hits.reduce((s, ev) => s + (ev.type === "damage" ? (ev.dealt || 0) : 0), 0);
  if (shot.from) shot.from.damageDealt = (shot.from.damageDealt || 0) + dealt;
  events.push(...hits);
  return events;
}

export function tick(state, dt, now) {
  const events = [];
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

export function checkWinner(state) {
  const pAlive = livingUnits(state.playerQueue).length;
  const eAlive = livingUnits(state.enemyQueue).length;
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
