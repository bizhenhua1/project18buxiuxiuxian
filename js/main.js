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
  reindex,
} from "./grid.js?v=dao9";
import { PLAYER_LIBRARY, ENEMY_LIBRARY, CARD_TYPE_NAMES, fieldCardType, createUnit, getCard, resetCombatState } from "./unit.js?v=dao9";
import { tick, resolveShot, checkWinner, processDeaths, applyDamage } from "./combat.js?v=dao9";
import { applyEffectiveStats, fmtMult, playerMult, monsterMult, isBossStage } from "./balance.js?v=dao9";
import {
  talentMods,
  talentPoints,
  spentPoints,
  slotTable,
  mergeMods,
  applyPlayerMods,
  applyQueueEffects,
  reconcile,
} from "./talents.js?v=dao9";
import { equipMods, addItem, rarityById } from "./equipment.js?v=dao9";
import { rollLoot, rollCaptures, addBeast, beastCount } from "./loot.js?v=dao9";
import { initTalentUI, openTalentPanel } from "./talent-ui.js?v=dao9";
import { initBagUI, openBagPanel } from "./bag-ui.js?v=dao9";
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
} from "./ui.js?v=dao9";
import {
  NODES_PER_REGION,
  nodeIndexOf,
  regionOf,
} from "./map.js?v=dao9";
import { createCorridor, STAGE_STEP } from "./corridor.js?v=canvas27";

const PROGRESS_KEY = "dao-progress-v1";

function loadProgress() {
  try {
    const raw = JSON.parse(localStorage.getItem(PROGRESS_KEY) || "null");
    if (raw && Number.isFinite(raw.unlockStage)) {
      const wins = Math.max(0, raw.wins | 0);
      // 旧档无 clearedStage：合法进度每推一关恰有一胜，用胜场推导已打赢的最高路点
      const clearedRaw = Number.isFinite(raw.clearedStage) ? Math.floor(raw.clearedStage) : wins - 1;
      // 合法性钳制：前沿关卡最多为「已打赢路点 + 1」。免战连点「下一关」灌大的
      // unlockStage（敌方成长按指数曲线放大到几万血）在这里被清洗回合法进度。
      const unlockStage = Math.max(0, Math.min(Math.floor(raw.unlockStage), clearedRaw + 1));
      const clearedStage = Math.max(-1, Math.min(clearedRaw, unlockStage));
      return { unlockStage, wins, clearedStage };
    }
  } catch { /* 损坏则从头开始 */ }
  return { unlockStage: 0, wins: 0, clearedStage: -1 };
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
  clearedStage: progress.clearedStage,
  cardSkin: "skin2",
  killedEnemies: [],
  bloodPact: false,
};

function saveProgress() {
  try {
    localStorage.setItem(PROGRESS_KEY, JSON.stringify({
      unlockStage: state.unlockStage,
      wins: state.wins,
      clearedStage: state.clearedStage,
    }));
  } catch { /* 静默 */ }
}

// 清理性迁移：钳制后的进度立即回写，污染存档（unlockStage 远超胜场）只清洗这一次
saveProgress();

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

/** 队列排型序：本体 → 法宝(操控) → 手持 → 识海 → 兽栏，与格位底纹顺序一致。 */
function typeRank(u) {
  if (u.cardType === "char") return 0;
  if (u.cardType === "fabao") return u.mode === "held" ? 2 : 1;
  if (u.cardType === "spell") return 3;
  if (u.cardType === "beast") return 4;
  return 5;
}

/** 自动归位：按格位排型稳定排序（同类保持相对顺序），拖放不依赖精确插入位置。 */
function sortPlayerQueue() {
  state.playerQueue.sort((a, b) => typeRank(a) - typeRank(b));
  reindex(state.playerQueue);
}

function restatQueues() {
  sortPlayerQueue();
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
  const charFell = state.playerQueue.some((u) => u.cardType === "char" && u.status === "corpse");
  let msg =
    state.winner === "player" ? "胜利：敌方无存活（只剩尸体也算输）" :
    state.winner === "enemy" ? (charFell ? "失败：道童陨落即战败（其余单位随之收兵）" : "失败：我方无存活") :
    "平局：双方均无存活";
  const kind = state.winner === "player" ? "win" : state.winner === "enemy" ? "lose" : "draw";
  if (state.winner === "player") {
    state.wins += 1;
    state.clearedStage = Math.max(state.clearedStage, state.unlockStage);
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

/** 手动推关须先打赢当前路点：免战连点会把指数成长的敌方数值灌爆并永久入档。 */
function canAdvanceStage() {
  return state.unlockStage <= state.clearedStage;
}

function nextStage() {
  if (!canEdit()) return;
  if (!canAdvanceStage()) {
    setStatus("需先打赢当前路点才能推进（战败可原地重整再战）", "warn");
    return;
  }
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
    ["btn-next", editing && canAdvanceStage()],
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

const SLOT_TYPE_NAMES = {
  char: "本体格",
  fabao: "法宝格",
  weapon: "手持格",
  spell: "识海格",
  beast: "兽栏格",
  monster: "妖兽格",
  locked: "封印之位",
};

/** 指针落点 → 我方格位（格位行不收指针事件，按横向最近的格位几何判定）。 */
function slotDropTarget(clientX) {
  const els = [...(lanes.playerSlots?.querySelectorAll(".slot") || [])];
  let best = null;
  let bestDist = Infinity;
  let bestIndex = -1;
  els.forEach((el, i) => {
    const r = el.getBoundingClientRect();
    const d = clientX < r.left ? r.left - clientX : clientX > r.right ? clientX - r.right : 0;
    if (d < bestDist) {
      bestDist = d;
      best = el;
      bestIndex = i;
    }
  });
  if (!best) return null;
  const type = (best.className.match(/st-(\w+)/) || [])[1] || "locked";
  return { el: best, type, index: bestIndex };
}

/** 落点即意图：卡牌类型 × 落点格位类型 → 入阵模式（法宝格=station、手持格=held）或错误。 */
function dropIntent(card, slotType) {
  const type = fieldCardType(card, "player");
  if (!slotType || slotType === "locked") return { error: "落点是封印之位，修习对应道途可解锁" };
  if (type === "fabao") {
    if (slotType === "fabao") return { mode: "station" };
    if (slotType === "weapon") return { mode: "held" };
    return { error: `法宝请拖到法宝格或手持格（落点是${SLOT_TYPE_NAMES[slotType] || slotType}）` };
  }
  const wantSlot = { char: "char", spell: "spell", beast: "beast" }[type];
  if (!wantSlot || slotType !== wantSlot) {
    return {
      error: `${CARD_TYPE_NAMES[type] || "该卡"}请拖到${SLOT_TYPE_NAMES[wantSlot] || "对应格位"}（落点是${SLOT_TYPE_NAMES[slotType] || slotType}）`,
    };
  }
  return { mode: "" };
}

function clearDropHint() {
  document.querySelectorAll(".drop-hint, .drop-bad").forEach((el) => el.classList.remove("drop-hint", "drop-bad"));
}

/** 悬停预览：高亮将落入的格位（占用位连带高亮其上的卡），不合法用警示色。 */
function showDropHint(hit, ok) {
  clearDropHint();
  if (!hit) return;
  const cls = ok ? "drop-hint" : "drop-bad";
  hit.el.classList.add(cls);
  const unit = state.playerQueue[hit.index];
  if (unit) {
    lanes.playerCards?.querySelector(`.unit-card[data-uid="${unit.uid}"]`)?.classList.add(cls);
  }
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
  clearDropHint();
  const lane = laneFromPoint(e.clientX, e.clientY);
  if (!lane || lane.dataset.side !== "player" || !canEdit()) return;
  const hit = slotDropTarget(e.clientX);
  if (drag.kind === "new") {
    // 新卡：落点即意图——预览将落入的格位与合法性，不再显示插入光标
    const card = getCard(drag.cardId);
    const intent = hit ? dropIntent(card, hit.type) : { error: "no-slot" };
    const ok = !intent.error && !resolvePlacement(card, null, intent.mode || null).error;
    showDropHint(hit, ok);
    drag.ok = ok;
    return;
  }
  // 场上移动：保留插入光标（同类内定序），法宝落到异模式格位时预览切换合法性
  const index = hitInsertIndex(lane, state.playerQueue, e.clientX);
  const unit = findUnitByUid([state.playerQueue], drag.uid);
  let ok = true;
  if (unit && unit.cardType === "fabao" && hit && (hit.type === "fabao" || hit.type === "weapon")) {
    const want = hit.type === "weapon" ? "held" : "station";
    if (want !== unit.mode) ok = !resolvePlacement(getCard(unit.cardId), unit.uid, want).error;
  }
  showInsertCaret(lanes, "player", index, state.playerQueue, ok);
  showDropHint(hit, ok);
  drag.insertAt = index;
  drag.ok = ok;
}

function onPointerUp(e) {
  window.removeEventListener("pointermove", onPointerMove);
  hideInsertCaret(lanes);
  clearDropHint();
  const lane = laneFromPoint(e.clientX, e.clientY);
  if (drag?.ghost) drag.ghost.remove();
  setCardsPickable(true);

  if (canEdit() && lane && lane.dataset.side === "player") {
    const hit = slotDropTarget(e.clientX);
    if (drag.kind === "new") {
      const card = getCard(drag.cardId);
      const intent = hit ? dropIntent(card, hit.type) : { error: "请拖到我方格位区域" };
      const res = intent.error ? intent : resolvePlacement(card, null, intent.mode || null);
      if (res.error) {
        setStatus(`未入阵：${res.error}，卡牌已回卡池`, "warn");
      } else {
        // 插到队首再经 restatQueues 排型：自动归位到正确格位（同类中靠左）
        insertUnit(state.playerQueue, makeUnit(drag.cardId, "player", 0, res.mode), 0, cap());
        restatQueues();
      }
    } else if (drag.kind === "move") {
      const unit = findUnitByUid([state.playerQueue], drag.uid);
      if (unit) {
        moveUnit(state.playerQueue, unit, hitInsertIndex(lane, state.playerQueue, e.clientX));
        // 场上法宝拖到异模式格位 = held↔station 切换（与双击同一套校验）
        if (unit.cardType === "fabao" && hit && (hit.type === "fabao" || hit.type === "weapon")) {
          const want = hit.type === "weapon" ? "held" : "station";
          if (want !== unit.mode) {
            const res = resolvePlacement(getCard(unit.cardId), unit.uid, want);
            if (res.error) setStatus(`切换失败：${res.error}`, "warn");
            else unit.mode = want;
          }
        }
        restatQueues();
      }
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
    // 调试跳关同步已打赢进度，否则加载钳制会把跳关后的存档清洗回去
    state.clearedStage = Math.max(state.clearedStage, state.unlockStage - 1);
    saveProgress();
    fillEnemyPreset();
    restatQueues();
    syncMetaButtons();
    syncButtons();
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
