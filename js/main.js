import {
  flushActive,
  activeSlot,
  listSlots,
  createSlot,
  switchSlot,
  deleteSlot,
  renameSlot,
  persistPlayerLineup,
  loadPlayerLineup,
} from "./saves.js?v=dao18";
import {
  capAt,
  createEmptyQueue,
  livingUnits,
  insertUnit,
  removeUnit,
  moveUnit,
  clearQueue,
  findUnitByUid,
  reindex,
} from "./grid.js?v=dao12";
import { PLAYER_LIBRARY, ENEMY_LIBRARY, HELD_HP_MERGE_BASE, fieldCardType, createUnit, getCard, resetCombatState } from "./unit.js?v=dao12";
import { tick, resolveShot, checkWinner, processDeaths, applyDamage } from "./combat.js?v=dao12";
import { applyEffectiveStats, fmtMult, playerMult, monsterMult, isBossStage } from "./balance.js?v=dao13";
import {
  talentMods,
  talentPoints,
  spentPoints,
  slotTable,
  mergeMods,
  applyPlayerMods,
  applyQueueEffects,
  reconcile,
} from "./talents.js?v=dao22";
import { equipMods, addItem, rarityById } from "./equipment.js?v=dao19";
import { rollLoot, rollCaptures, addBeast, beastCount, rollIdleLoot, rollQuestLoot } from "./loot.js?v=dao19";
import { initTalentUI, openTalentPanel } from "./talent-ui.js?v=dao21";
import {
  addExp,
  breakthrough,
  canBreakthrough,
  killExp,
  realmMods,
  realmState,
  realmTitle,
  resetRealm,
  LAYER_GAIN_PCT,
  BREAK_GAIN_PCT,
} from "./realm.js?v=dao12";
import { initBagUI, openBagPanel } from "./bag-ui.js?v=dao18";
import { initSaveUI, openSavePanel, syncSaveButtons } from "./save-ui.js?v=dao18";
import {
  buildLanes,
  buildPool,
  renderBoards,
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
  playFabaoModeAnim,
  playCharHpPulse,
  rollDisplayedHp,
} from "./ui.js?v=dao26";
import {
  NODES_PER_REGION,
  regionOf,
} from "./map.js?v=dao19";
import { createCorridor, STAGE_STEP } from "./corridor.js?v=canvas42";
import {
  migrateAreaFromStage,
  areaIndex,
  areaStage,
  eliteStage,
  currentQuest,
  isEliteQuest,
  questSnapshot,
  applyKills,
  rollNextQuest,
  enterNextArea,
  setAreaIndex,
  areaGrowth,
  completedQuests,
  completeCurrentQuest,
} from "./quest.js?v=dao19";
import { claimIdle, idleRates, touchIdle } from "./idle.js?v=dao13";
import { addCoins, coinBalance, renderCoins } from "./economy.js?v=dao13";

const PROGRESS_KEY = "dao-progress-v1";

function loadProgress() {
  try {
    const raw = JSON.parse(localStorage.getItem(PROGRESS_KEY) || "null");
    if (raw && Number.isFinite(raw.unlockStage)) {
      const wins = Math.max(0, raw.wins | 0);
      const clearedRaw = Number.isFinite(raw.clearedStage) ? Math.floor(raw.clearedStage) : wins - 1;
      const unlockStage = Math.max(0, Math.floor(raw.unlockStage));
      const clearedStage = Math.max(-1, Math.floor(clearedRaw));
      return { unlockStage, wins, clearedStage };
    }
  } catch { /* 损坏则从头开始 */ }
  return { unlockStage: 0, wins: 0, clearedStage: -1 };
}

const progress = loadProgress();
migrateAreaFromStage(progress.unlockStage);

const state = {
  playerQueue: createEmptyQueue(),
  enemyQueue: createEmptyQueue(),
  running: false,
  battleStartTs: 0,
  battleEndTs: 0,
  speed: 1,
  winner: null,
  selectedUid: null,
  unlockStage: areaStage(),
  focusStage: areaStage(),
  wins: progress.wins,
  clearedStage: Math.max(progress.clearedStage, areaStage() - 1),
  cardSkin: "skin2",
  killedEnemies: [],
  bloodPact: false,
};

function syncAreaStages() {
  state.unlockStage = areaStage();
  state.focusStage = isEliteQuest() ? eliteStage() : areaStage();
}

function saveProgress() {
  try {
    localStorage.setItem(PROGRESS_KEY, JSON.stringify({
      unlockStage: state.unlockStage,
      wins: state.wins,
      clearedStage: state.clearedStage,
      areaIndex: areaIndex(),
    }));
  } catch { /* 静默 */ }
}

recoverCompletedQuest();
syncAreaStages();
saveProgress();
flushActive();

// 天赋+装备+境界聚合修正（变更时刷新缓存）
let mods = mergeMods(talentMods(), equipMods(), realmMods());
reconcile(state.unlockStage);

function refreshMods() {
  mods = mergeMods(talentMods(), equipMods(), realmMods());
}

function currentSlots() {
  return slotTable(mods);
}

const lanes = buildLanes();
const poolRoot = document.getElementById("card-pool");
buildPool(poolRoot);
const corridor = createCorridor(document.getElementById("corridor-host"), { band: true });
corridor?.setAreaTheme?.(areaIndex(), { immediate: true });
bindCorridor(corridor);

let raf = 0;
let lastTs = 0;
let drag = null;
let inflight = 0;
let corridorTraveling = false;
let pendingReviveTimer = 0;
let farmTravels = 0;

function cap() {
  return capAt(state.unlockStage);
}

function playerStage() {
  return areaStage();
}

function enemyStage() {
  return isEliteQuest() ? eliteStage() : areaStage();
}

function questTargetId() {
  return currentQuest()?.targetId || null;
}

function makeUnit(id, side, index = 0, mode = "station") {
  const unit = createUnit(id, side, index, side === "enemy" ? enemyStage() : playerStage(), mode);
  if (side === "player") applyPlayerMods(unit, mods);
  return unit;
}

/**
 * 队列排型：只把识海法术归到最右。道童 / 操控法宝 / 手持法宝 / 妖兽同组，
 * 相对顺序完全尊重玩家摆放——切换手持不改下标，绝不把武器自动抽到最右侧。
 */
function typeRank(u) {
  if (u.cardType === "spell") return 1;
  return 0;
}

/** 稳定排序仅归位识海法术；手持法宝不参与自动抽位。 */
function sortPlayerQueue() {
  state.playerQueue.sort((a, b) => typeRank(a) - typeRank(b));
  reindex(state.playerQueue);
}

/**
 * 新卡默认落位：道童插到最前；station/held 法宝与妖兽插到当前非识海区末尾
 *（手持不另开右侧分组）；识海法术仍插组头，经排型归到最右。
 */
function defaultInsertIndex(unit) {
  if (unit.cardType === "char") return 0;
  if (typeRank(unit) !== 0) return 0;
  return state.playerQueue.filter((u) => typeRank(u) === 0).length;
}

/**
 * 道童默认上阵：各自动入口（进页面 / 清空我方 / 重置布阵 / 战败复位 / 推关刷新）
 * 若阵上没有道童则自动补到最前。只在缺位时补位，绝不重排玩家已摆好的顺序。
 */
function ensureCharFielded() {
  if (state.playerQueue.some((u) => u.cardType === "char")) return;
  if (!insertUnit(state.playerQueue, makeUnit("daotong", "player", 0), 0, cap())) return;
  restatQueues();
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
  persistPlayerLineup(state.playerQueue);
}

/**
 * 从当前档工作副本还原上阵：按保存下标插入，走 resolvePlacement 校验空位与收服数。
 * 空档/损坏回退为只上道童。敌方队列不读档，仍由任务预设填充。
 */
function hydrateLineup() {
  const entries = loadPlayerLineup();
  clearQueue(state.playerQueue);
  const skipped = [];
  for (const entry of entries) {
    const card = getCard(entry.cardId);
    if (!card) {
      skipped.push(`${entry.cardId}（未知卡牌）`);
      continue;
    }
    const type = fieldCardType(card, "player");
    const wantMode = type === "fabao" ? (entry.mode === "held" ? "held" : "station") : null;
    const res = resolvePlacement(card, null, wantMode);
    if (res.error) {
      skipped.push(`${card.name}（${res.error}）`);
      continue;
    }
    const unit = makeUnit(entry.cardId, "player", state.playerQueue.length, res.mode);
    if (!insertUnit(state.playerQueue, unit, state.playerQueue.length, cap())) {
      skipped.push(`${card.name}（已达上限 ${cap()} 位）`);
    }
  }
  if (skipped.length) {
    console.warn(`[lineup] 跳过非法上阵：${skipped.join("；")}`);
  }
  ensureCharFielded();
  restatQueues();
  return skipped;
}

function paint() {
  renderBoards(state, lanes);
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

/** 击杀修为预估：本关敌方全灭时的入账总额（有效血量÷10 向上取整求和，Boss 关 ×3）。 */
function expForCurrentEnemies() {
  const base = state.enemyQueue.reduce((s, u) => s + killExp(u.maxHp), 0);
  return base * (isBossStage(enemyStage()) ? 3 : 1);
}

/** 胜利结算：掉落装备 + 收服御兽 + 修为入账（升层/圆满弹提示）。 */
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
  // 修为入账：击杀全部敌方单位的灵气（Boss 关 ×3）；升层提示走 loot-log
  const expGain = expForCurrentEnemies();
  const grew = addExp(expGain);
  const levelNote = grew.levels > 0 ? `，境界提升至 <b class="loot-realm">${realmTitle()}</b>` : "";
  const fullNote = grew.full ? "（圆满，可突破）" : "";
  pushLootLog(`修为 +${grew.gained}${grew.gained < expGain ? `（圆满溢出 ${expGain - grew.gained}）` : ""}${levelNote}${fullNote}`);
  const farmCoins = addCoins(Math.max(1, Math.round((boss ? 8 : 3) * areaGrowth())));
  if (farmCoins) pushLootLog(`灵石 +${farmCoins}`);
  if (caught.length) buildPool(poolRoot);
  refreshMods();
  renderCoins();
  syncMetaButtons();
  return { items, caught, coins: farmCoins };
}

function grantQuestRewards(quest) {
  const r = quest?.rewards || {};
  const bits = [];
  if (r.exp > 0) {
    const grew = addExp(r.exp);
    const levelNote = grew.levels > 0 ? `，境界提升至 <b class="loot-realm">${realmTitle()}</b>` : "";
    pushLootLog(`任务修为 +${grew.gained}${levelNote}`);
    bits.push(`修为 +${grew.gained}`);
  }
  if (r.coins > 0) {
    const n = addCoins(r.coins);
    if (n) {
      pushLootLog(`任务灵石 +${n}`);
      bits.push(`灵石 +${n}`);
    }
  }
  const items = rollQuestLoot(playerStage(), r.loot || 0, r.minTier || 0, mods.luckPct);
  for (const item of items) {
    addItem(item);
    pushLootLog(`任务掉落 <b style="color:${rarityById(item.rarity).color}">${item.name}</b>`);
  }
  if (items.length) bits.push(`装备 ${items.map((it) => it.name).join("、")}`);
  refreshMods();
  renderCoins();
  syncMetaButtons();
  if (items.length) buildPool(poolRoot);
  return { bits, items };
}

function applyIdleGrant(preview, label = "挂机") {
  if (!preview) return null;
  const bits = [];
  if (preview.exp > 0) {
    const grew = addExp(preview.exp);
    if (grew.gained > 0) {
      const levelNote = grew.levels > 0 ? `，境界提升至 <b class="loot-realm">${realmTitle()}</b>` : "";
      pushLootLog(`${label}修为 +${grew.gained}${levelNote}`);
      bits.push(`修为 +${grew.gained}`);
    }
  }
  if (preview.coins > 0) {
    const n = addCoins(preview.coins);
    if (n) {
      pushLootLog(`${label}灵石 +${n}`);
      bits.push(`灵石 +${n}`);
    }
  }
  const items = rollIdleLoot(playerStage(), preview.lootRolls, mods.luckPct);
  for (const item of items) {
    addItem(item);
    pushLootLog(`${label}掉落 <b style="color:${rarityById(item.rarity).color}">${item.name}</b>`);
  }
  if (items.length) bits.push(`装备 ${items.map((it) => it.name).join("、")}`);
  if (!bits.length) return null;
  refreshMods();
  renderCoins();
  syncMetaButtons();
  if (items.length) buildPool(poolRoot);
  return { bits, items, capped: preview.capped, minutes: preview.minutes };
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
  ensureCharFielded();
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
  let areaComplete = false;
  if (state.winner === "player") {
    state.wins += 1;
    state.clearedStage = Math.max(state.clearedStage, state.unlockStage);
    const { items, caught, coins } = settleVictory();
    const bits = [];
    if (items.length) bits.push(`掉落 ${items.map((it) => it.name).join("、")}`);
    if (caught.length) bits.push(`收服 ${caught.map((id) => getCard(id)?.name || id).join("、")}`);
    if (coins) bits.push(`灵石 +${coins}`);

    const killResult = applyKills(state.killedEnemies);
    const questDone = killResult.completed || currentQuest().have >= currentQuest().need;
    if (killResult.progressed && !questDone) {
      const snap = questSnapshot();
      bits.push(`任务 ${snap.targetName} ${snap.have}/${snap.need}`);
    }
    if (questDone) {
      const reward = grantQuestRewards(killResult.quest || currentQuest());
      if (reward.bits.length) bits.push(`任务完成 ${reward.bits.join(" ")}`);
      const next = rollNextQuest();
      bits.push("悟性 +1");
      pushLootLog("悟性 +1");
      areaComplete = !!next.areaComplete;
      if (areaComplete) bits.push("精英已除，即将换区");
      else {
        const nq = questSnapshot();
        bits.push(`下一任务：${nq.title} ${nq.have}/${nq.need}`);
      }
      syncMetaButtons();
    }
    if (bits.length) msg += ` · ${bits.join("；")}`;
    saveProgress();
  }
  state.battleEndTs = performance.now();
  setStatus(msg, kind);
  syncButtons();
  if (state.winner === "player") {
    if (areaComplete) queueTravelThenNextArea();
    else queueTravelThenRefill(msg, kind);
  } else {
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

function fillEnemyWish(n) {
  const roster = ENEMY_LIBRARY.map((c) => c.id);
  const target = questTargetId();
  const others = roster.filter((id) => id !== target);
  const wish = [];
  const targetCount = target ? Math.max(1, Math.ceil(n * 0.55)) : 0;
  for (let i = 0; i < targetCount && i < n; i++) wish.push(target);
  for (let i = wish.length; i < n; i++) {
    wish.push(others.length ? others[(i - targetCount) % others.length] : roster[i % roster.length]);
  }
  for (let i = wish.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [wish[i], wish[j]] = [wish[j], wish[i]];
  }
  return wish;
}

function fillEnemyPreset() {
  fillQueue(state.enemyQueue, "enemy", fillEnemyWish(enemyCount()));
}

function fillEnemyRandom() {
  clearQueue(state.enemyQueue);
  const n = enemyCount();
  const target = questTargetId();
  const others = ENEMY_LIBRARY.filter((c) => !target || c.id !== target);
  const targetCard = target ? ENEMY_LIBRARY.find((c) => c.id === target) : null;
  const targetCount = target ? Math.max(1, Math.ceil(n * 0.55)) : 0;
  for (let i = 0; i < n; i++) {
    const card = i < targetCount && targetCard
      ? targetCard
      : (others[Math.floor(Math.random() * Math.max(1, others.length))] || ENEMY_LIBRARY[0]);
    insertUnit(state.enemyQueue, makeUnit(card.id, "enemy", i), i, n);
  }
}

function fillPlayerDemo() {
  // 一键布阵：道童 + 法宝填满已开空位（法宝不另限额，只受位置上限）
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
  for (let i = 0; state.playerQueue.length < cap() && fabaos.length; i++) {
    if (!put(fabaos[i % fabaos.length].id, "station")) break;
  }
  restatQueues();
}

/**
 * 上阵校验 + 入位模式：位置上限 + 法术/御兽数量上限 + 御兽持有数。
 * 法宝不另限额，有已开空位即可上阵；重量只影响战斗数值，不拦放置。
 * 拖入空位默认操控（station）；手持只能右键/双击指定（wantMode="held"）。
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
    if (wantMode === "held") {
      const heldUnits = q.filter((u) => u.cardType === "fabao" && u.mode === "held");
      if (heldUnits.length >= slots.hand) {
        return { error: `手持已满（${slots.hand}），可修体修「两手蛮力」提高手持上限` };
      }
      return { mode: "held" };
    }
    return { mode: "station" };
  }
  if (type === "spell") {
    if (cnt("spell") >= slots.mind) return { error: `法术上阵已满（${slots.mind}），可修法修「识海开窍」提高法术上限` };
  }
  if (type === "beast") {
    if (cnt("beast") >= slots.beast) return { error: `御兽上阵已满（${slots.beast}），可修御兽「兽栏」提高御兽上限` };
    const fielded = q.filter((u) => u.cardId === card.id && u.cardType === "beast").length;
    if (fielded >= beastCount(card.id)) return { error: `「${card.name}」仅收服了 ${beastCount(card.id)} 只` };
  }
  return { mode: "" };
}

/** 布阵期右键（或双击）场上法宝：held ↔ station 切换（校验手持上限）。下标不变。 */
function toggleFabaoMode(unit) {
  if (!canEdit() || !unit || unit.cardType !== "fabao") return;
  const want = unit.mode === "held" ? "station" : "held";
  const res = resolvePlacement(getCard(unit.cardId), unit.uid, want);
  if (res.error) {
    setStatus(`切换失败：${res.error}`, "warn");
    return;
  }
  const char = state.playerQueue.find((u) => u.cardType === "char");
  const hpBefore = char ? char.maxHp : 0;
  unit.mode = want;
  restatQueues();
  setStatus(
    `${unit.name} 已切换为${want === "held" ? "手持：不占承伤位、继承攻速暴击，主动技封印" : "法术操控：独立血条，被击毁后自行重聚"}`,
    "idle",
  );
  paint();
  playFabaoModeAnim(unit.uid, want);
  if (char && hpBefore !== char.maxHp) {
    rollDisplayedHp(char.uid, hpBefore, char.maxHp);
    playCharHpPulse(char.uid);
  }
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
  ensureCharFielded();
  fillEnemyPreset();
  primeQueues();
  state.selectedUid = null;
  setStatus("布阵中：拖到我方一排插入", "idle");
  syncButtons();
  paint();
}

function refillInPlace(statusMsg, statusKind = "idle") {
  clearPendingRevive();
  for (const u of state.playerQueue) resetCombatState(u);
  syncAreaStages();
  fillEnemyPreset();
  ensureCharFielded();
  restatQueues();
  state.winner = null;
  corridor?.setMoving?.(false);
  if (statusMsg) setStatus(statusMsg, statusKind);
  syncButtons();
  paint();
}

function applyNextAreaSpawn() {
  clearPendingRevive();
  enterNextArea();
  syncAreaStages();
  reconcile(state.unlockStage);
  refreshMods();
  state.clearedStage = Math.max(state.clearedStage, state.unlockStage - 1);
  state.winner = null;
  saveProgress();
  syncMetaButtons();
  for (const u of state.playerQueue) resetCombatState(u);
  fillEnemyPreset();
  ensureCharFielded();
  restatQueues();
  corridor?.setAreaTheme?.(areaIndex(), { immediate: true });
  corridor?.setMoving?.(false);
  const region = regionOf(state.unlockStage);
  const pm = playerMult(playerStage());
  const mm = monsterMult(enemyStage());
  const rates = idleRates(areaIndex());
  setStatus(
    `进入 ${region.name} · 区域跃升 · 我攻×${fmtMult(pm.atk)} 怪血×${fmtMult(mm.hp)} · 挂机 修为${rates.expPerMin}/分 灵石${rates.coinsPerMin}/分`,
    "win",
  );
  syncButtons();
  paint();
}

function queueTravelThenRefill(statusMsg, statusKind = "idle") {
  if (corridorTraveling) {
    refillInPlace(statusMsg, statusKind);
    return;
  }
  corridorTraveling = true;
  syncButtons();
  farmTravels += 1;
  const fork = farmTravels % 3 === 0;
  const run = corridor?.travelForward?.(STAGE_STEP, fork ? { fork: true } : undefined);
  Promise.resolve(run).then(() => {
    corridorTraveling = false;
    refillInPlace(statusMsg, statusKind);
  });
}

function queueTravelThenNextArea() {
  if (corridorTraveling) return;
  corridorTraveling = true;
  setStatus("赶路中：精英已除，即将换区", "idle");
  syncButtons();
  const next = areaIndex() + 1;
  Promise.resolve(corridor?.travelForward?.(STAGE_STEP))
    .then(() => corridor?.setAreaTheme?.(next) ?? false)
    .then(() => {
      corridorTraveling = false;
      applyNextAreaSpawn();
    });
}

function recoverCompletedQuest() {
  const q = currentQuest();
  if (!q || q.have < q.need) return;
  const next = rollNextQuest();
  if (next.areaComplete) enterNextArea();
  syncAreaStages();
  saveProgress();
  reconcile(state.unlockStage);
}

function nextStage() {
  setStatus("换区需完成当前区域的精英击杀任务，无法手动跳关", "warn");
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
    ["btn-next", false],
    ["btn-advance", editing && !corridorTraveling],
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
  return { el: best, type, index: bestIndex, inside: bestDist === 0 };
}

/** 空位通用：只拦封印位。法宝拖入默认操控；手持不靠格子，由右键指定。 */
function dropIntent(card, slotType) {
  if (!slotType || slotType === "locked") return { error: "落点是封印之位（位置尚未解锁）" };
  const type = fieldCardType(card, "player");
  if (type === "fabao") return { mode: "station" };
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
  // held 法宝拳头底纹处：提示血量已按比例并入道童（比例含「法宝合身」加成）
  const fistOrb = e.target?.closest?.(".held-orb");
  if (fistOrb) {
    const unit = findUnitByUid([state.playerQueue], Number(fistOrb.closest(".unit-card")?.dataset.uid));
    if (unit && unit.cardType === "fabao" && unit.mode === "held") {
      const pct = HELD_HP_MERGE_BASE + Math.max(0, mods.mergeHeldHpPct || 0);
      const merged = Math.round((unit.maxHp * pct) / 100);
      showCardTip(
        `<strong>✊ 血量已被主角继承</strong><span class="tip-stats">${unit.name}血量 ${unit.maxHp} × ${pct}% 已并入道童（+${merged}）</span><span class="tip-desc">手持法宝不占承伤位、不可承伤，故无独立血槽；切回法术操控即恢复独立血条。</span>`,
        e.clientX,
        e.clientY,
      );
      return;
    }
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
  if (e.button !== 0) return;
  hideCardTip();
  const cardEl = e.target.closest(".pool-card");
  if (!cardEl || !canEdit()) return;
  const card = getCard(cardEl.dataset.cardId);
  beginDrag({ kind: "new", cardId: card.id, icon: card.icon, face: card.face, art: card.art }, e);
}

let lastTapUid = 0;
let lastTapTs = 0;

function onPointerDownLane(e) {
  if (e.button !== 0) return;
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
    const card = getCard(drag.cardId);
    const intent = hit ? dropIntent(card, hit.type) : { error: "no-slot" };
    const ok = !intent.error && !resolvePlacement(card, null, intent.mode || null).error;
    showDropHint(hit, ok);
    drag.ok = ok;
    return;
  }
  const index = hitInsertIndex(lane, state.playerQueue, e.clientX);
  showInsertCaret(lanes, "player", index, state.playerQueue, true);
  drag.insertAt = index;
  drag.ok = true;
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
        const unit = makeUnit(drag.cardId, "player", 0, res.mode);
        insertUnit(state.playerQueue, unit, hit.index, cap());
        restatQueues();
      }
    } else if (drag.kind === "move") {
      const unit = findUnitByUid([state.playerQueue], drag.uid);
      if (unit) {
        moveUnit(state.playerQueue, unit, hitInsertIndex(lane, state.playerQueue, e.clientX));
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
  lane.addEventListener("pointermove", updateCardTip);
  lane.addEventListener("pointerleave", hideCardTip);
}

document.getElementById("btn-start").addEventListener("click", startBattle);
document.getElementById("btn-reset").addEventListener("click", resetBattle);
document.getElementById("btn-next").addEventListener("click", nextStage);
/* 测试用：不战斗直接赶路一程，沿用与战斗相同的岔路节奏（每 3 程一岔）。 */
document.getElementById("btn-advance")?.addEventListener("click", () => {
  if (corridorTraveling || !canEdit()) return;
  corridorTraveling = true;
  syncButtons();
  farmTravels += 1;
  const fork = farmTravels % 3 === 0;
  setStatus(fork ? "赶路中：前方似有岔路" : "赶路中……", "idle");
  Promise.resolve(corridor?.travelForward?.(STAGE_STEP, fork ? { fork: true } : undefined)).then(() => {
    corridorTraveling = false;
    syncButtons();
    setStatus("已前进一程", "idle");
  });
});
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
  ensureCharFielded();
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
    const left = talentPoints() - spentPoints();
    btn.textContent = `道途天赋${left > 0 ? ` · 悟性余 ${left}` : ""}`;
    btn.classList.toggle("has-points", left > 0);
  }
}

/** 天赋/装备变更后的统一刷新：重聚合 → 重算队列 → 重绘。 */
function onMetaChange() {
  refreshMods();
  // 数量上限收缩后可能超编（如洗髓掉手持额度）：超编 held 转操控。法宝上阵不另限额。
  const slots = currentSlots();
  const removed = [];
  const converted = [];
  let held = 0;
  for (const u of [...state.playerQueue]) {
    if (u.cardType !== "fabao" || u.mode !== "held") continue;
    held += 1;
    if (held <= slots.hand) continue;
    held -= 1;
    u.mode = "station";
    converted.push(u);
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
  if (notes.length) setStatus(`上阵变动：${notes.join("；")}`, "warn");
  restatQueues();
  syncMetaButtons();
  paint();
}

initTalentUI({ getStage: () => state.unlockStage, onChange: onMetaChange });
initBagUI({ onChange: onMetaChange });
initSaveUI({ canOpen: () => canEdit() });
document.getElementById("btn-talents")?.addEventListener("click", () => {
  if (state.running) return;
  openTalentPanel();
});
document.getElementById("btn-bag")?.addEventListener("click", () => {
  if (state.running) return;
  openBagPanel();
});
document.getElementById("btn-saves")?.addEventListener("click", () => {
  if (!canEdit()) return;
  openSavePanel();
});
document.getElementById("btn-saves-rail")?.addEventListener("click", () => {
  if (!canEdit()) return;
  openSavePanel();
});
syncSaveButtons();

// ==== 境界：突破按钮 + 修为悬浮提示 ====

/** 修为悬浮详情：当前/需求、总修为、下一层（或突破）收益。 */
function realmTipHtml() {
  const r = realmState();
  const nextNote = r.canBreak
    ? `突破可入「${r.title.slice(0, 2)}」下一大境界：道童攻/血额外 ×${(1 + BREAK_GAIN_PCT / 100).toFixed(2)}，并得 1 点悟性`
    : r.full
      ? "已达当前体系巅峰"
      : `升 1 层：道童攻/血 ×${(1 + LAYER_GAIN_PCT / 100).toFixed(2)}（复利）`;
  const expLine = r.full ? "圆满（修为已停止累积）" : `${r.exp} / ${r.need}`;
  return `<strong>境界 ${r.title}</strong><span class="tip-stats">层内修为 ${expLine}　总修为 ${r.totalExp}</span><span class="tip-desc">击杀妖兽获取修为（约其血量十分之一，Boss 关三倍），胜利结算入账。${nextNote}。</span>`;
}

function onBreakthrough() {
  if (!canEdit() || !canBreakthrough()) return;
  breakthrough();
  refreshMods();
  restatQueues();
  syncMetaButtons();
  syncButtons();
  setStatus(`✨ 突破成功！晋入「${realmTitle()}」：道童攻血 +${BREAK_GAIN_PCT}%，悟性 +1`, "win");
  const box = document.getElementById("realm-box");
  if (box) {
    box.classList.remove("flash");
    void box.offsetWidth;
    box.classList.add("flash");
  }
  paint();
}

document.getElementById("btn-breakthrough")?.addEventListener("click", onBreakthrough);
const realmBox = document.getElementById("realm-box");
realmBox?.addEventListener("pointermove", (e) => showCardTip(realmTipHtml(), e.clientX, e.clientY));
realmBox?.addEventListener("pointerleave", hideCardTip);

document.addEventListener("contextmenu", (e) => {
  e.preventDefault();
  const unitEl = e.target?.closest?.(".unit-card");
  if (unitEl) {
    e.stopPropagation();
    if (!canEdit() || unitEl.dataset.side !== "player") return;
    const unit = findUnitByUid([state.playerQueue], Number(unitEl.dataset.uid));
    if (unit?.cardType === "fabao") toggleFabaoMode(unit);
    return;
  }
  const poolEl = e.target?.closest?.(".pool-card");
  if (!poolEl || !canEdit()) return;
  const card = getCard(poolEl.dataset.cardId);
  if (!card || fieldCardType(card, "player") !== "fabao") return;
  e.stopPropagation();
  const res = resolvePlacement(card, null, "held");
  if (res.error) {
    setStatus(`未能手持：${res.error}`, "warn");
    return;
  }
  const unit = makeUnit(card.id, "player", 0, "held");
  insertUnit(state.playerQueue, unit, defaultInsertIndex(unit), cap());
  restatQueues();
  setStatus(`${card.name} 已手持上场`, "idle");
  paint();
});
document.addEventListener("selectstart", (e) => {
  if (e.target?.closest?.("input, textarea")) return;
  e.preventDefault();
});
document.addEventListener("dragstart", (e) => e.preventDefault());

window.addEventListener("resize", () => paint());

function claimAndGrantIdle(force, label) {
  const preview = claimIdle(Date.now(), areaIndex(), force);
  const granted = applyIdleGrant(preview, label);
  if (granted) {
    if (!state.running) {
      const capNote = granted.capped ? "（已按 8 小时封顶）" : "";
      setStatus(`${label}：${granted.bits.join(" · ")}${capNote}`, "idle");
    }
    paint();
  }
  return granted;
}

function bindIdleLoop() {
  claimAndGrantIdle(true, "离线补领");
  setInterval(() => {
    if (document.hidden) return;
    claimAndGrantIdle(false, "挂机");
  }, 15000);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) touchIdle();
    else claimAndGrantIdle(true, "离线补领");
  });
  window.addEventListener("beforeunload", () => touchIdle());
  window.addEventListener("pagehide", () => touchIdle());
}

fillEnemyPreset();
const lineupSkipped = hydrateLineup();
setStatus("布阵中：拖到我方一排插入", "idle");
if (lineupSkipped.length) {
  setStatus(`上阵还原：跳过 ${lineupSkipped.join("；")}`, "warn");
}
flushActive();
syncButtons();
syncSkinButtons();
syncMetaButtons();
paint();
requestAnimationFrame(() => paint());
bindIdleLoop();

// 调试钩子（与走廊 __corridorSet 同类，供自动化验收）
window.__dao = {
  saves: {
    list: () => listSlots(),
    active: () => activeSlot(),
    flush: () => flushActive(),
    create: (name) => createSlot(name),
    switch: (id) => switchSlot(id),
    delete: (id) => deleteSlot(id),
    rename: (id, name) => renameSlot(id, name),
    lineup: () => loadPlayerLineup(),
  },
  lineup: () => state.playerQueue.map((u) => ({ cardId: u.cardId, mode: u.mode || "station", index: u.index })),
  state,
  mods: () => mods,
  slots: () => currentSlots(),
  setArea(n) {
    setAreaIndex(n);
    syncAreaStages();
    state.clearedStage = Math.max(state.clearedStage, state.unlockStage - 1);
    saveProgress();
    reconcile(state.unlockStage);
    refreshMods();
    fillEnemyPreset();
    restatQueues();
    corridor?.setAreaTheme?.(areaIndex(), { immediate: true });
    syncMetaButtons();
    syncButtons();
    paint();
    return questSnapshot();
  },
  setStage(n) {
    const area = Math.floor(Math.max(0, Math.floor(n)) / NODES_PER_REGION);
    return this.setArea(area);
  },
  quest: () => questSnapshot(),
  completedQuests: () => completedQuests(),
  talentPoints: () => talentPoints(),
  /** 立刻完成当前任务并 +1 悟性（验收用，不播赶路）。 */
  completeQuest() {
    const next = completeCurrentQuest();
    if (next.areaComplete) {
      enterNextArea();
      syncAreaStages();
      reconcile(state.unlockStage);
      refreshMods();
      fillEnemyPreset();
      corridor?.setAreaTheme?.(areaIndex(), { immediate: true });
    } else {
      syncAreaStages();
    }
    saveProgress();
    syncMetaButtons();
    syncButtons();
    paint();
    return {
      areaComplete: !!next.areaComplete,
      quest: questSnapshot(),
      completed: completedQuests(),
      talentPoints: talentPoints(),
      left: talentPoints() - spentPoints(),
    };
  },
  claimIdle: (force = true) => claimAndGrantIdle(!!force, "挂机"),
  addCoins(n) {
    addCoins(n);
    renderCoins();
    return coinBalance();
  },
  place(id, mode = null) {
    const card = getCard(id);
    if (!card) return "unknown card";
    const res = resolvePlacement(card, null, mode);
    if (res.error) return res.error;
    const unit = makeUnit(id, "player", 0, res.mode);
    insertUnit(state.playerQueue, unit, defaultInsertIndex(unit), cap());
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
    persistPlayerLineup(state.playerQueue);
    paint();
  },
  start: () => startBattle(),
  /** 立刻播一段岔路口赶路（2 或 3 洞口，可省略）。 */
  fork(n) {
    if (corridorTraveling) return corridor?.beginFork?.(n);
    corridorTraveling = true;
    syncButtons();
    return Promise.resolve(corridor?.beginFork?.(n)).then((ok) => {
      corridorTraveling = false;
      syncButtons();
      return ok;
    });
  },
  // ==== 境界调试钩子（验收用）====
  realm: () => realmState(),
  /** 灌修为并即时刷新收益（胜利结算走 settleVictory 同一条 addExp 链路） */
  addExp(n) {
    const r = addExp(n);
    refreshMods();
    restatQueues();
    syncMetaButtons();
    paint();
    return { ...r, ...realmState() };
  },
  breakthrough: () => {
    onBreakthrough();
    return realmState();
  },
  resetRealm: () => {
    resetRealm();
    refreshMods();
    restatQueues();
    syncMetaButtons();
    paint();
    return realmState();
  },
  expPreview: () => expForCurrentEnemies(),
};
