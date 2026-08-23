import {
  MAX_STAGE,
  capAt,
  createEmptyQueue,
  livingUnits,
  canAdd,
  insertUnit,
  removeUnit,
  moveUnit,
  clearQueue,
  findUnitByUid,
} from "./grid.js?v=cap10";
import { PLAYER_LIBRARY, ENEMY_LIBRARY, createUnit, getCard, resetCombatState } from "./unit.js?v=growth1";
import { tick, resolveShot, checkWinner } from "./combat.js?v=cap10";
import { applyEffectiveStats, fmtMult, playerMult, monsterMult } from "./balance.js?v=growth1";
import {
  buildLanes,
  buildPool,
  renderBoards,
  renderInspect,
  renderLinks,
  renderDps,
  battleElapsedSec,
  setStatus,
  spawnFloat,
  spawnBullet,
  playCardAnim,
  bulletDuration,
  tickFx,
  fxBusy,
  clearFx,
  clearProjectiles,
  createDragGhost,
  showInsertCaret,
  hideInsertCaret,
  hitInsertIndex,
  setCardsPickable,
  showCardTip,
  hideCardTip,
  lockCardTip,
  formatCardTip,
  formatUnitTip,
  bindCorridor,
} from "./ui.js?v=cap10";
import {
  NODES_PER_REGION,
  nodeIndexOf,
  regionOf,
} from "./map.js?v=corridor1";
import { createCorridor, STAGE_STEP } from "./corridor.js?v=canvas25";

const state = {
  playerQueue: createEmptyQueue(),
  enemyQueue: createEmptyQueue(),
  running: false,
  battleStartTs: 0,
  battleEndTs: 0,
  speed: 1,
  winner: null,
  selectedUid: null,
  unlockStage: 0,
  focusStage: 0,
  wins: 0,
  cardSkin: "skin2",
};

const lanes = buildLanes();
const poolRoot = document.getElementById("card-pool");
buildPool(poolRoot);
const corridor = createCorridor(document.getElementById("corridor-host"), { band: true });
bindCorridor(corridor);

let raf = 0;
let lastTs = 0;
let drag = null;
let inflight = 0;
let corridorTraveling = false;

function cap() {
  return capAt(state.unlockStage);
}

function playerStage() {
  return state.unlockStage;
}

function enemyStage() {
  return Number.isFinite(state.focusStage) ? state.focusStage : state.unlockStage;
}

function makeUnit(id, side, index = 0) {
  return createUnit(id, side, index, side === "enemy" ? enemyStage() : playerStage());
}

function restatQueues() {
  for (const u of state.playerQueue) applyEffectiveStats(u, playerStage());
  for (const u of state.enemyQueue) applyEffectiveStats(u, enemyStage());
}

function paint() {
  renderBoards(state, lanes);
  renderInspect(state);
  renderDps(state);
  renderLinks(state);
}

function applyImpact(events, at = null) {
  for (const ev of events) {
    if (ev.type === "damage") spawnFloat(ev.unit, `-${ev.amount}`, "dmg", at);
    if (ev.type === "heal") spawnFloat(ev.unit, `+${ev.amount}`, "heal", at);
    if (ev.type === "buff") spawnFloat(ev.unit, ev.amount ? "▲" : "▲0", "buff", at);
  }
}

function finishIfNeeded() {
  if (inflight > 0 || !state.running) return false;
  checkWinner(state);
  if (!state.winner) return false;
  state.running = false;
  const msg =
    state.winner === "player" ? "胜利：敌方无存活（只剩尸体也算输）" :
    state.winner === "enemy" ? "失败：我方无存活" : "平局：双方均无存活";
  const kind = state.winner === "player" ? "win" : state.winner === "enemy" ? "lose" : "draw";
  if (state.winner === "player") state.wins += 1;
  state.battleEndTs = performance.now();
  setStatus(msg, kind);
  syncButtons();
  if (state.winner === "player") queueTravelThenNextStage();
  else corridor?.setMoving?.(false);
  return true;
}

function launchShot(shot) {
  if (shot.style === "heal") {
    playCardAnim(shot.from.uid, "atk", shot.to.uid);
    playCardAnim(shot.to.uid, "heal");
    applyImpact(resolveShot(shot));
    return;
  }
  playCardAnim(shot.from.uid, "atk", shot.to.uid);
  inflight += 1;
  let duration = bulletDuration(shot.style, shot.from.uid, shot.to.uid) / Math.max(0.25, state.speed);
  if (shot.style === "beam") duration = Math.max(120, Math.min(220, duration));
  spawnBullet({
    fromUid: shot.from.uid,
    toUid: shot.to.uid,
    style: shot.style,
    flavor: shot.from.cardId,
    secondary: !!shot.secondary,
    duration,
    onArrive: (hit) => {
      inflight = Math.max(0, inflight - 1);
      const evs = resolveShot(shot);
      const died = evs.some((e) => e.type === "death");
      playCardAnim(shot.to.uid, died ? "dead" : "hit");
      applyImpact(evs, hit);
    },
  });
}

function applyEvents(events) {
  for (const ev of events) {
    if (ev.type === "shot") {
      launchShot(ev);
      continue;
    }
    if (ev.type === "cast" && ev.kind === "heal") {
      playCardAnim(ev.from.uid, "atk", ev.to.uid);
      playCardAnim(ev.to.uid, "heal");
    }
    applyImpact([ev]);
  }
}

function loop(ts) {
  if (state.running) {
    if (!lastTs) lastTs = ts;
    const dt = Math.min(48, ts - lastTs) * state.speed;
    lastTs = ts;
    applyEvents(tick(state, dt, ts));
    tickFx(ts);
    paint();
    if (finishIfNeeded()) paint();
  } else {
    tickFx(ts);
  }
  if (state.running || fxBusy()) raf = requestAnimationFrame(loop);
}

function canEdit() {
  return !state.running && !corridorTraveling;
}

function primeQueues() {
  for (const u of [...state.playerQueue, ...state.enemyQueue]) resetCombatState(u);
}

function fillQueue(queue, side, ids) {
  clearQueue(queue);
  const limit = cap();
  for (const id of ids) {
    if (queue.length >= limit) break;
    if (!getCard(id)) continue;
    insertUnit(queue, makeUnit(id, side, queue.length), queue.length, limit);
  }
}

function fillEnemyPreset() {
  const roster = ENEMY_LIBRARY.map((c) => c.id);
  const wish = [];
  const n = cap();
  for (let i = 0; i < n; i++) wish.push(roster[i % roster.length]);
  fillQueue(state.enemyQueue, "enemy", wish);
}

function fillEnemyRandom() {
  clearQueue(state.enemyQueue);
  const n = cap();
  for (let i = 0; i < n; i++) {
    const card = ENEMY_LIBRARY[Math.floor(Math.random() * ENEMY_LIBRARY.length)];
    insertUnit(state.enemyQueue, makeUnit(card.id, "enemy", i), i, n);
  }
}

function fillPlayerDemo() {
  const arts = PLAYER_LIBRARY.filter((c) => c.id !== "daotong").map((c) => c.id);
  const wish = ["daotong"];
  const n = cap();
  for (let i = 1; i < n; i++) wish.push(arts[(i - 1) % arts.length]);
  fillQueue(state.playerQueue, "player", wish);
}

function startBattle() {
  if (corridorTraveling) return;
  if (livingUnits(state.playerQueue).length === 0) {
    setStatus("请先把卡牌插入我方队列", "warn");
    return;
  }
  if (livingUnits(state.enemyQueue).length === 0) fillEnemyPreset();
  restatQueues();
  primeQueues();
  state.running = true;
  state.battleStartTs = performance.now();
  state.battleEndTs = 0;
  state.winner = null;
  inflight = 0;
  lastTs = 0;
  clearFx();
  corridor?.setMoving?.(false);
  setStatus("战斗中：打最左存活者；尸体占位不左移", "fight");
  syncButtons();
  paint();
  cancelAnimationFrame(raf);
  raf = requestAnimationFrame(loop);
}

function resetBattle() {
  corridor?.setMoving?.(false);
  corridorTraveling = false;
  state.running = false;
  state.battleStartTs = 0;
  state.battleEndTs = 0;
  state.winner = null;
  inflight = 0;
  cancelAnimationFrame(raf);
  lastTs = 0;
  clearFx();
  clearQueue(state.playerQueue);
  fillEnemyPreset();
  primeQueues();
  state.selectedUid = null;
  setStatus("布阵中：拖到我方一排插入", "idle");
  syncButtons();
  paint();
}

function applyNextStageSpawn() {
  const atCap = state.unlockStage >= MAX_STAGE;
  state.unlockStage += 1;
  state.focusStage = state.unlockStage;
  state.winner = null;
  fillEnemyPreset();
  restatQueues();
  corridor?.setMoving?.(false);
  const region = regionOf(state.unlockStage);
  const node = nodeIndexOf(state.unlockStage);
  const capNote = atCap ? "携带已满" : `可携带 ${cap()} 张`;
  const rolled = node === 0 ? `进入 ${region.name}` : region.name;
  const pm = playerMult(playerStage());
  const mm = monsterMult(enemyStage());
  const boss = mm.boss ? " · Boss" : "";
  setStatus(
    `${rolled} · 路点 ${node + 1}/${NODES_PER_REGION}${boss} · ${capNote} · 我攻×${fmtMult(pm.atk)} 怪血×${fmtMult(mm.hp)}`,
    "idle",
  );
  syncButtons();
  paint();
}

function queueTravelThenNextStage() {
  if (corridorTraveling) return;
  corridorTraveling = true;
  setStatus("赶路中：走廊向前推进", "idle");
  syncButtons();
  const run = corridor?.travelForward?.(STAGE_STEP);
  Promise.resolve(run).then((ok) => {
    corridorTraveling = false;
    if (ok) applyNextStageSpawn();
    else {
      corridor?.setMoving?.(false);
      syncButtons();
    }
  });
}

function nextStage() {
  if (!canEdit()) return;
  queueTravelThenNextStage();
}

function syncSkinButtons() {
  for (const id of ["btn-skin1", "btn-skin2"]) {
    const el = document.getElementById(id);
    if (!el) continue;
    el.classList.toggle("on", el.dataset.skin === state.cardSkin);
  }
  document.body.dataset.cardSkin = state.cardSkin;
}

function setCardSkin(skin) {
  state.cardSkin = skin === "skin2" ? "skin2" : "skin1";
  syncSkinButtons();
  paint();
}

function syncButtons() {
  const editing = canEdit();
  const ids = [
    ["btn-start", editing],
    ["btn-enemy-preset", editing],
    ["btn-enemy-random", editing],
    ["btn-player-fill", editing],
    ["btn-player-clear", editing],
    ["btn-next", editing],
  ];
  for (const [id, on] of ids) {
    const el = document.getElementById(id);
    if (el) el.disabled = !on;
  }
}

function laneFromPoint(x, y) {
  const el = document.elementFromPoint(x, y);
  const lane = el?.closest?.(".lane");
  return lane || null;
}

function updateCardTip(e) {
  if (drag) {
    hideCardTip();
    return;
  }
  const pool = e.target?.closest?.(".pool-card");
  if (pool) {
    showCardTip(formatCardTip(getCard(pool.dataset.cardId), playerStage()), e.clientX, e.clientY);
    return;
  }
  const cardEl = e.target?.closest?.(".unit-card");
  if (cardEl) {
    const unit = findUnitByUid([state.playerQueue, state.enemyQueue], Number(cardEl.dataset.uid));
    if (unit) {
      showCardTip(formatUnitTip(unit, battleElapsedSec(state)), e.clientX, e.clientY);
      return;
    }
  }
  hideCardTip();
}

function onPointerDownPool(e) {
  hideCardTip();
  const cardEl = e.target.closest(".pool-card");
  if (!cardEl || !canEdit()) return;
  const card = getCard(cardEl.dataset.cardId);
  beginDrag({ kind: "new", cardId: card.id, icon: card.icon, face: card.face, art: card.art }, e);
}

function onPointerDownLane(e) {
  hideCardTip();
  const card = e.target.closest(".unit-card");
  if (card) {
    state.selectedUid = Number(card.dataset.uid);
    paint();
    if (!canEdit() || card.dataset.side !== "player") return;
    const unit = findUnitByUid([state.playerQueue], state.selectedUid);
    if (!unit) return;
    beginDrag({ kind: "move", uid: unit.uid, icon: unit.icon, face: unit.face, art: unit.art }, e);
    return;
  }
  state.selectedUid = null;
  paint();
}

function beginDrag(payload, e) {
  e.preventDefault();
  window.getSelection()?.removeAllRanges();
  lockCardTip(true);
  hideCardTip();
  drag = payload;
  drag.ghost = createDragGhost(payload.icon, payload.face, payload.art);
  setCardsPickable(false);
  moveGhost(e);
  window.addEventListener("pointermove", onPointerMove);
  window.addEventListener("pointerup", onPointerUp, { once: true });
}

function moveGhost(e) {
  if (!drag?.ghost) return;
  drag.ghost.style.left = `${e.clientX + 10}px`;
  drag.ghost.style.top = `${e.clientY + 10}px`;
}

function onPointerMove(e) {
  moveGhost(e);
  hideInsertCaret(lanes);
  const lane = laneFromPoint(e.clientX, e.clientY);
  if (!lane || lane.dataset.side !== "player" || !canEdit()) return;
  const index = hitInsertIndex(lane, state.playerQueue, e.clientX);
  const ignore = drag.kind === "move" ? drag.uid : null;
  const ok = drag.kind === "move" || canAdd(state.playerQueue, cap(), ignore);
  showInsertCaret(lanes, "player", index, state.playerQueue, ok);
  drag.insertAt = index;
  drag.ok = ok;
}

function onPointerUp(e) {
  window.removeEventListener("pointermove", onPointerMove);
  hideInsertCaret(lanes);
  const lane = laneFromPoint(e.clientX, e.clientY);
  if (drag?.ghost) drag.ghost.remove();
  setCardsPickable(true);

  if (canEdit() && lane && lane.dataset.side === "player") {
    const index = hitInsertIndex(lane, state.playerQueue, e.clientX);
    if (drag.kind === "new") {
      if (!canAdd(state.playerQueue, cap())) {
        setStatus(`已达携带上限 ${cap()}`, "warn");
      } else {
        insertUnit(state.playerQueue, makeUnit(drag.cardId, "player"), index, cap());
      }
    } else if (drag.kind === "move") {
      const unit = findUnitByUid([state.playerQueue], drag.uid);
      if (unit) moveUnit(state.playerQueue, unit, index);
    }
  } else if (drag?.kind === "move") {
    const unit = findUnitByUid([state.playerQueue], drag.uid);
    if (unit && canEdit()) removeUnit(state.playerQueue, unit);
  }
  drag = null;
  lockCardTip(false);
  paint();
  const under = document.elementFromPoint(e.clientX, e.clientY);
  if (under) updateCardTip({ target: under, clientX: e.clientX, clientY: e.clientY });
}

poolRoot.addEventListener("pointerdown", onPointerDownPool);
lanes.enemyLane.addEventListener("pointerdown", onPointerDownLane);
lanes.playerLane.addEventListener("pointerdown", onPointerDownLane);

poolRoot.addEventListener("pointermove", updateCardTip);
poolRoot.addEventListener("pointerleave", hideCardTip);

for (const lane of [lanes.enemyLane, lanes.playerLane]) {
  lane.addEventListener("pointerover", (e) => {
    const card = e.target.closest(".unit-card");
    if (card) renderInspect(state, Number(card.dataset.uid));
  });
  lane.addEventListener("pointermove", updateCardTip);
  lane.addEventListener("pointerleave", () => {
    hideCardTip();
    renderInspect(state);
  });
}

document.getElementById("btn-start").addEventListener("click", startBattle);
document.getElementById("btn-reset").addEventListener("click", resetBattle);
document.getElementById("btn-next").addEventListener("click", nextStage);
document.getElementById("btn-enemy-preset").addEventListener("click", () => {
  if (!canEdit()) return;
  fillEnemyPreset();
  paint();
});
document.getElementById("btn-enemy-random").addEventListener("click", () => {
  if (!canEdit()) return;
  fillEnemyRandom();
  paint();
});
document.getElementById("btn-player-fill").addEventListener("click", () => {
  if (!canEdit()) return;
  fillPlayerDemo();
  paint();
});
document.getElementById("btn-player-clear").addEventListener("click", () => {
  if (!canEdit()) return;
  clearQueue(state.playerQueue);
  paint();
});
document.getElementById("speed-select").addEventListener("change", (e) => {
  state.speed = Number(e.target.value) || 1;
});
document.getElementById("btn-skin1")?.addEventListener("click", () => setCardSkin("skin1"));
document.getElementById("btn-skin2")?.addEventListener("click", () => setCardSkin("skin2"));

document.addEventListener("contextmenu", (e) => e.preventDefault());
document.addEventListener("selectstart", (e) => e.preventDefault());
document.addEventListener("dragstart", (e) => e.preventDefault());

window.addEventListener("resize", () => paint());

fillEnemyPreset();
setStatus("布阵中：拖到我方一排插入", "idle");
syncButtons();
syncSkinButtons();
paint();
requestAnimationFrame(() => paint());
