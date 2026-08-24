import {
  MAX_STAGE,
  capAt,
  createEmptyQueue,
  livingUnits,
  insertUnit,
  removeUnit,
  moveUnit,
  clearQueue,
  findUnitByUid,
} from "./grid.js?v=dao7";
import { PLAYER_LIBRARY, ENEMY_LIBRARY, fieldCardType, createUnit, getCard, resetCombatState } from "./unit.js?v=dao7";
import { tick, resolveShot, checkWinner, processDeaths, applyDamage } from "./combat.js?v=dao7";
import { applyEffectiveStats, fmtMult, playerMult, monsterMult, isBossStage } from "./balance.js?v=dao7";
import {
  talentMods,
  talentPoints,
  spentPoints,
  slotTable,
  mergeMods,
  applyPlayerMods,
  applyQueueEffects,
  reconcile,
} from "./talents.js?v=dao7";
import { equipMods, addItem, rarityById } from "./equipment.js?v=dao7";
import { rollLoot, rollCaptures, addBeast, beastCount } from "./loot.js?v=dao7";
import { initTalentUI, openTalentPanel } from "./talent-ui.js?v=dao7";
import { initBagUI, openBagPanel } from "./bag-ui.js?v=dao7";
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
} from "./ui.js?v=dao7";
import {
  NODES_PER_REGION,
  nodeIndexOf,
  regionOf,
} from "./map.js?v=dao7";
import { createCorridor, STAGE_STEP } from "./corridor.js?v=canvas27";

const PROGRESS_KEY = "dao-progress-v1";

function loadProgress() {
  try {
    const raw = JSON.parse(localStorage.getItem(PROGRESS_KEY) || "null");
    if (raw && Number.isFinite(raw.unlockStage)) {
      return { unlockStage: Math.max(0, Math.floor(raw.unlockStage)), wins: Math.max(0, raw.wins | 0) };
    }
  } catch { /* 损坏则从头开始 */ }
  return { unlockStage: 0, wins: 0 };
}

const progress = loadProgress();

const state = {
  playerQueue: createEmptyQueue(),
  enemyQueue: createEmptyQueue(),
  running: false,
  battleStartTs: 0,
  battleEndTs: 0,
  speed: 1,
  winner: null,
  selectedUid: null,
  unlockStage: progress.unlockStage,
  focusStage: progress.unlockStage,
  wins: progress.wins,
  cardSkin: "skin2",
  killedEnemies: [],
  bloodPact: false,
};

function saveProgress() {
  try {
    localStorage.setItem(PROGRESS_KEY, JSON.stringify({ unlockStage: state.unlockStage, wins: state.wins }));
  } catch { /* 静默 */ }
}

// 天赋+装备聚合修正（变更时刷新缓存）
let mods = mergeMods(talentMods(), equipMods());
reconcile(state.unlockStage);

function refreshMods() {
  mods = mergeMods(talentMods(), equipMods());
}

function currentSlots() {
  return slotTable(mods);
}

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
let pendingReviveTimer = 0;

function cap() {
  return capAt(state.unlockStage);
}

function playerStage() {
  return state.unlockStage;
}

function enemyStage() {
  return Number.isFinite(state.focusStage) ? state.focusStage : state.unlockStage;
}

function makeUnit(id, side, index = 0, mode = "station") {
  const unit = createUnit(id, side, index, side === "enemy" ? enemyStage() : playerStage(), mode);
  if (side === "player") applyPlayerMods(unit, mods);
  return unit;
}

function restatQueues() {
  for (const u of state.playerQueue) {
    applyEffectiveStats(u, playerStage());
    applyPlayerMods(u, mods);
  }
  applyQueueEffects(state.playerQueue, mods);
  state.bloodPact = !!mods.bloodPact;
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
    // 跳字按伤害类型分色：外伤暖色、法伤冷紫；暴击加大字带「暴」标
    if (ev.type === "damage") {
      const kind = `dmg${ev.dmgType === "spell" ? " spell" : ""}${ev.crit ? " crit" : ""}`;
      spawnFloat(ev.unit, `-${ev.amount}`, kind, at);
    }
    if (ev.type === "heal") spawnFloat(ev.unit, `+${ev.amount}`, "heal", at);
    if (ev.type === "buff") spawnFloat(ev.unit, ev.amount ? "▲" : "▲0", "buff", at);
    if (ev.type === "revive") spawnFloat(ev.unit, "重聚", "revive");
  }
}

/** 结算一批事件：死亡后处理（幡叠层/收服记录/血契回血）再统一跳字。 */
function settle(events, at = null) {
  const extra = processDeaths(state, events);
  applyImpact([...events, ...extra], at);
}

const LOOT_LOG_MAX = 8;

function pushLootLog(html) {
  const box = document.getElementById("loot-log");
  if (!box) return;
  const line = document.createElement("div");
  line.className = "loot-line";
  line.innerHTML = html;
  box.prepend(line);
  while (box.childElementCount > LOOT_LOG_MAX) box.lastElementChild.remove();
}

/** 胜利结算：掉落装备 + 收服御兽。 */
function settleVictory() {
  const boss = isBossStage(enemyStage());
  const items = rollLoot(enemyStage(), boss, mods.luckPct);
  for (const item of items) {
    addItem(item);
    pushLootLog(`掉落 <b style="color:${rarityById(item.rarity).color}">${item.name}</b>`);
  }
  const caught = rollCaptures(state.killedEnemies, mods.capturePct + mods.luckPct * 0.5);
  for (const id of caught) {
    addBeast(id);
    const card = getCard(id);
    pushLootLog(`收服 <b class="loot-beast">${card ? card.name : id}</b>（共 ${beastCount(id)} 只）`);
  }
  if (caught.length) buildPool(poolRoot);
  refreshMods();
  syncMetaButtons();
  return { items, caught };
}

function clearPendingRevive() {
  if (pendingReviveTimer) {
    clearTimeout(pendingReviveTimer);
    pendingReviveTimer = 0;
  }
}

/** 战败/平局后原地复位：我方满血复活、敌方按当前关卡重填，可直接再战。 */
function reviveAfterDefeat() {
  pendingReviveTimer = 0;
  if (state.running || corridorTraveling) return;
  for (const u of state.playerQueue) resetCombatState(u);
  fillEnemyPreset();
  restatQueues();
  state.winner = null;
  setStatus("战败：已在当前路点原地休整，可调整阵容/天赋/装备后重新开战", "lose");
  syncButtons();
  paint();
}

function finishIfNeeded() {
  if (inflight > 0 || !state.running) return false;
  checkWinner(state);
  if (!state.winner) return false;
  state.running = false;
  // 战斗结束清除未完成的重聚计时
  for (const u of state.playerQueue) u.reviveLeft = 0;
  let msg =
    state.winner === "player" ? "胜利：敌方无存活（只剩尸体也算输）" :
    state.winner === "enemy" ? "失败：我方无存活" : "平局：双方均无存活";
  const kind = state.winner === "player" ? "win" : state.winner === "enemy" ? "lose" : "draw";
  if (state.winner === "player") {
    state.wins += 1;
    const { items, caught } = settleVictory();
    const bits = [];
    if (items.length) bits.push(`掉落 ${items.map((it) => it.name).join("、")}`);
    if (caught.length) bits.push(`收服 ${caught.map((id) => getCard(id)?.name || id).join("、")}`);
    if (bits.length) msg += ` · ${bits.join("；")}`;
    saveProgress();
  }
  state.battleEndTs = performance.now();
  setStatus(msg, kind);
  syncButtons();
  if (state.winner === "player") queueTravelThenNextStage();
  else {
    corridor?.setMoving?.(false);
    clearPendingRevive();
    pendingReviveTimer = setTimeout(reviveAfterDefeat, 1200);
  }
  return true;
}

function launchShot(shot) {
  if (shot.style === "heal") {
    playCardAnim(shot.from.uid, "atk", shot.to.uid);
    playCardAnim(shot.to.uid, "heal");
    settle(resolveShot(shot));
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
      settle(evs, hit);
    },
  });
}

function applyEvents(events) {
  const batch = [];
  for (const ev of events) {
    if (ev.type === "shot") {
      launchShot(ev);
      continue;
    }
    if (ev.type === "cast" && ev.kind === "heal") {
      playCardAnim(ev.from.uid, "atk", ev.to.uid);
      playCardAnim(ev.to.uid, "heal");
    }
    batch.push(ev);
  }
  if (batch.length) settle(batch);
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

/** 敌方出战数：纯关卡驱动——第 0 关 5 只，每 2 关 +1，受 capAt 封顶（后期 10），与玩家天赋/装备无关。 */
function enemyCount() {
  const stage = enemyStage();
  return Math.min(capAt(stage), 5 + Math.floor(stage / 2));
}

function fillEnemyPreset() {
  const roster = ENEMY_LIBRARY.map((c) => c.id);
  const wish = [];
  const n = enemyCount();
  for (let i = 0; i < n; i++) wish.push(roster[i % roster.length]);
  fillQueue(state.enemyQueue, "enemy", wish);
}

function fillEnemyRandom() {
  clearQueue(state.enemyQueue);
  const n = enemyCount();
  for (let i = 0; i < n; i++) {
    const card = ENEMY_LIBRARY[Math.floor(Math.random() * ENEMY_LIBRARY.length)];
    insertUnit(state.enemyQueue, makeUnit(card.id, "enemy", i), i, n);
  }
}

function fillPlayerDemo() {
  // 一键布阵尊重格位：道童 + 法宝填满法宝格；有手持格则从重到轻持法宝（重量预算内）；再补法术
  const slots = currentSlots();
  clearQueue(state.playerQueue);
  const put = (id, mode = null) => {
    if (state.playerQueue.length >= cap()) return false;
    const card = getCard(id);
    if (!card) return false;
    const res = resolvePlacement(card, null, mode);
    if (res.error) return false;
    insertUnit(state.playerQueue, makeUnit(id, "player", state.playerQueue.length, res.mode), state.playerQueue.length, cap());
    return true;
  };
  put("daotong");
  const fabaos = PLAYER_LIBRARY.filter((c) => c.cardType === "fabao");
  for (let i = 0; i < slots.fabao; i++) put(fabaos[i % fabaos.length].id, "station");
  if (slots.hand > 0) {
    const heavyFirst = [...fabaos].sort((a, b) => (b.weight || 0) - (a.weight || 0));
    for (const c of heavyFirst) put(c.id, "held");
  }
  if (slots.mind > 0) {
    for (const c of PLAYER_LIBRARY.filter((cc) => cc.cardType === "spell")) put(c.id);
  }
  restatQueues();
}

/**
 * 上阵校验 + 入位模式：位置上限 + 格位类型 + 重量预算 + 御兽持有数。
 * 法宝默认入法宝格（station）；法宝格满且手持格有余（含重量预算）则自动入手持（held）。
 * wantMode 可强制指定（双击切换/一键布阵/调试钩子用）。返回 { mode } 或 { error }。
 */
function resolvePlacement(card, ignoreUid = null, wantMode = null) {
  const q = state.playerQueue.filter((u) => u && u.uid !== ignoreUid);
  if (q.length >= cap()) return { error: `已达上限 ${cap()} 位` };
  const slots = currentSlots();
  const type = fieldCardType(card, "player");
  const cnt = (t) => q.filter((u) => u.cardType === t).length;
  if (type === "char") {
    if (cnt("char") >= 1) return { error: "道童只能上场一位" };
    return { mode: "" };
  }
  if (type === "fabao") {
    const heldUnits = q.filter((u) => u.cardType === "fabao" && u.mode === "held");
    const station = cnt("fabao") - heldUnits.length;
    const wUsed = heldUnits.reduce((s, u) => s + (u.weight || 0), 0);
    const heldError =
      slots.hand <= 0
        ? "手持格未开：先修「体修·两手蛮力」"
        : heldUnits.length >= slots.hand
          ? `手持格已满（${slots.hand}）`
          : wUsed + (card.weight || 0) > slots.weight
            ? `重量超限：${wUsed}+${card.weight} > ${slots.weight}（力量预算）`
            : null;
    const stationError =
      station >= slots.fabao ? `法宝格已满（${slots.fabao}），可修「器道·多宝」扩容` : null;
    if (wantMode === "held") return heldError ? { error: heldError } : { mode: "held" };
    if (wantMode === "station") return stationError ? { error: stationError } : { mode: "station" };
    if (!stationError) return { mode: "station" };
    if (!heldError) return { mode: "held" };
    return { error: `${stationError}；${heldError}` };
  }
  if (type === "spell") {
    if (slots.mind <= 0) return { error: "识海格未开：先修「法修·识海开窍」" };
    if (cnt("spell") >= slots.mind) return { error: `识海格已满（${slots.mind}）` };
  }
  if (type === "beast") {
    if (slots.beast <= 0) return { error: "兽栏格未开：先修「御兽·兽栏」" };
    if (cnt("beast") >= slots.beast) return { error: `兽栏格已满（${slots.beast}）` };
    const fielded = q.filter((u) => u.cardId === card.id && u.cardType === "beast").length;
    if (fielded >= beastCount(card.id)) return { error: `「${card.name}」仅收服了 ${beastCount(card.id)} 只` };
  }
  return { mode: "" };
}

function placeError(card, ignoreUid = null) {
  return resolvePlacement(card, ignoreUid).error || null;
}

/** 布阵期双击场上法宝：held ↔ station 切换（校验目标格位余量与重量预算）。 */
function toggleFabaoMode(unit) {
  if (!canEdit() || !unit || unit.cardType !== "fabao") return;
  const want = unit.mode === "held" ? "station" : "held";
  const res = resolvePlacement(getCard(unit.cardId), unit.uid, want);
  if (res.error) {
    setStatus(`切换失败：${res.error}`, "warn");
    return;
  }
  unit.mode = want;
  restatQueues();
  setStatus(
    `${unit.name} 已切换为${want === "held" ? "手持：不占承伤位、继承攻速暴击，主动技封印" : "法术操控：独立血条，被击毁后自行重聚"}`,
    "idle",
  );
  paint();
}

function startBattle() {
  if (corridorTraveling) return;
  if (livingUnits(state.playerQueue).length === 0) {
    setStatus("请先把卡牌插入我方队列", "warn");
    return;
  }
  const hasHeld = state.playerQueue.some(
    (u) => u.cardType === "spell" || (u.cardType === "fabao" && u.mode === "held"),
  );
  const hasChar = state.playerQueue.some((u) => u.cardType === "char");
  if (hasHeld && !hasChar) {
    setStatus("手持法宝与识海法术系于道童一身：请先上道童", "warn");
    return;
  }
  clearPendingRevive();
  if (livingUnits(state.enemyQueue).length === 0) fillEnemyPreset();
  state.killedEnemies = [];
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
  clearPendingRevive();
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
  clearPendingRevive();
  const atCap = state.unlockStage >= MAX_STAGE;
  state.unlockStage += 1;
  state.focusStage = state.unlockStage;
  state.winner = null;
  saveProgress();
  syncMetaButtons();
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
  const slotEl = e.target?.closest?.(".slot");
  if (slotEl?.dataset.tipHtml) {
    showCardTip(slotEl.dataset.tipHtml, e.clientX, e.clientY);
    return;
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

let lastTapUid = 0;
let lastTapTs = 0;

function onPointerDownLane(e) {
  hideCardTip();
  const card = e.target.closest(".unit-card");
  if (card) {
    state.selectedUid = Number(card.dataset.uid);
    paint();
    if (!canEdit() || card.dataset.side !== "player") return;
    const unit = findUnitByUid([state.playerQueue], state.selectedUid);
    if (!unit) return;
    // 布阵期双击场上法宝：held ↔ station 切换（pointerdown 上 preventDefault 会吞原生 dblclick，手动检测）
    const now = performance.now();
    if (unit.uid === lastTapUid && now - lastTapTs < 350 && unit.cardType === "fabao") {
      lastTapUid = 0;
      toggleFabaoMode(unit);
      return;
    }
    lastTapUid = unit.uid;
    lastTapTs = now;
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
  const ok = drag.kind === "move" || !placeError(getCard(drag.cardId));
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
      const res = resolvePlacement(getCard(drag.cardId));
      if (res.error) {
        setStatus(res.error, "warn");
      } else {
        insertUnit(state.playerQueue, makeUnit(drag.cardId, "player", 0, res.mode), index, cap());
        restatQueues();
      }
    } else if (drag.kind === "move") {
      const unit = findUnitByUid([state.playerQueue], drag.uid);
      if (unit) moveUnit(state.playerQueue, unit, index);
    }
  } else if (drag?.kind === "move") {
    const unit = findUnitByUid([state.playerQueue], drag.uid);
    if (unit && canEdit()) {
      removeUnit(state.playerQueue, unit);
      restatQueues();
    }
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

// ==== 修行：天赋树 + 行囊 ====

function syncMetaButtons() {
  const btn = document.getElementById("btn-talents");
  if (btn) {
    const left = talentPoints(state.unlockStage) - spentPoints();
    btn.textContent = `道途天赋${left > 0 ? ` · 悟性余 ${left}` : ""}`;
    btn.classList.toggle("has-points", left > 0);
  }
}

/** 天赋/装备变更后的统一刷新：重聚合 → 重算队列 → 重绘。 */
function onMetaChange() {
  refreshMods();
  // 格位收缩后可能出现超编（如洗髓掉手持格）：超编 held 优先转 station（法宝格有空），转不了才退回卡池
  const slots = currentSlots();
  const removed = [];
  const converted = [];
  let station = 0;
  for (const u of [...state.playerQueue]) {
    if (u.cardType === "fabao" && u.mode === "station" && ++station > slots.fabao) {
      station -= 1;
      removeUnit(state.playerQueue, u);
      removed.push(u);
    }
  }
  let held = 0;
  let weight = 0;
  for (const u of [...state.playerQueue]) {
    if (u.cardType !== "fabao" || u.mode !== "held") continue;
    held += 1;
    weight += u.weight || 0;
    if (held <= slots.hand && weight <= slots.weight) continue;
    held -= 1;
    weight -= u.weight || 0;
    if (station < slots.fabao) {
      station += 1;
      u.mode = "station";
      converted.push(u);
    } else {
      removeUnit(state.playerQueue, u);
      removed.push(u);
    }
  }
  const cnt = { spell: 0, beast: 0 };
  for (const u of [...state.playerQueue]) {
    if (u.cardType === "spell" && ++cnt.spell > slots.mind) {
      removeUnit(state.playerQueue, u);
      removed.push(u);
    } else if (u.cardType === "beast" && ++cnt.beast > slots.beast) {
      removeUnit(state.playerQueue, u);
      removed.push(u);
    }
  }
  const notes = [];
  if (converted.length) notes.push(`${converted.map((u) => u.name).join("、")} 转为法术操控`);
  if (removed.length) notes.push(`${removed.map((u) => u.name).join("、")} 已回到卡池`);
  if (notes.length) setStatus(`格位变动：${notes.join("；")}`, "warn");
  restatQueues();
  syncMetaButtons();
  paint();
}

initTalentUI({ getStage: () => state.unlockStage, onChange: onMetaChange });
initBagUI({ onChange: onMetaChange });
document.getElementById("btn-talents")?.addEventListener("click", () => {
  if (state.running) return;
  openTalentPanel();
});
document.getElementById("btn-bag")?.addEventListener("click", () => {
  if (state.running) return;
  openBagPanel();
});

document.addEventListener("contextmenu", (e) => e.preventDefault());
document.addEventListener("selectstart", (e) => e.preventDefault());
document.addEventListener("dragstart", (e) => e.preventDefault());

window.addEventListener("resize", () => paint());

fillEnemyPreset();
setStatus("布阵中：拖到我方一排插入", "idle");
syncButtons();
syncSkinButtons();
syncMetaButtons();
paint();
requestAnimationFrame(() => paint());

// 调试钩子（与走廊 __corridorSet 同类，供自动化验收）
window.__dao = {
  state,
  mods: () => mods,
  slots: () => currentSlots(),
  setStage(n) {
    state.unlockStage = Math.max(0, Math.floor(n));
    state.focusStage = state.unlockStage;
    saveProgress();
    fillEnemyPreset();
    restatQueues();
    syncMetaButtons();
    paint();
  },
  place(id, mode = null) {
    const card = getCard(id);
    if (!card) return "unknown card";
    const res = resolvePlacement(card, null, mode);
    if (res.error) return res.error;
    insertUnit(state.playerQueue, makeUnit(id, "player", 0, res.mode), state.playerQueue.length, cap());
    restatQueues();
    paint();
    return "ok";
  },
  toggleMode(uid) {
    const unit = findUnitByUid([state.playerQueue], uid);
    if (unit) toggleFabaoMode(unit);
    return unit ? unit.mode : "not found";
  },
  /** 定向打一发：验证外/法伤按防御结算与 dmgReduce 乘算叠加（验收用） */
  hit(uid, amount, dmgType = "phys") {
    const unit = findUnitByUid([state.playerQueue, state.enemyQueue], uid);
    if (!unit) return "not found";
    const before = unit.hp + (unit.shield || 0);
    const events = applyDamage(unit, amount, dmgType);
    settle(events);
    paint();
    return { dealt: before - (unit.hp + (unit.shield || 0)), hp: unit.hp, shield: unit.shield, status: unit.status };
  },
  clear() {
    clearQueue(state.playerQueue);
    paint();
  },
  start: () => startBattle(),
};
