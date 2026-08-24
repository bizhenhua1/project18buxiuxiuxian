import { SLOT_COUNT, MAX_STAGE, capAt, livingUnits, leftmostTargetable, corpses, computeLaneLayout, measureCardSize } from "./grid.js?v=dao1";
import { PLAYER_LIBRARY, ENEMY_LIBRARY, CARD_TYPE_NAMES, unitDesc } from "./unit.js?v=dao1";
import { collectTargetPairs } from "./combat.js?v=dao1";
import { NODES_PER_REGION, nodeIndexOf, regionOf, renderMap } from "./map.js?v=dao1";
import { effectiveStats, fmtMult, monsterMult, playerMult } from "./balance.js?v=dao1";
import { talentMods, slotTable, mergeMods } from "./talents.js?v=dao1";
import { equipMods } from "./equipment.js?v=dao1";
import { ownedBeasts } from "./loot.js?v=dao1";

let sceneCorridor = null;

export function bindCorridor(corridor) {
  sceneCorridor = corridor;
}

const layoutCache = { player: [], enemy: [] };

export function buildLanes() {
  return {
    enemyLane: document.getElementById("enemy-lane"),
    playerLane: document.getElementById("player-lane"),
    enemySlots: document.getElementById("enemy-slots"),
    playerSlots: document.getElementById("player-slots"),
    enemyCards: document.getElementById("enemy-cards"),
    playerCards: document.getElementById("player-cards"),
    enemyCaret: document.getElementById("enemy-caret"),
    playerCaret: document.getElementById("player-caret"),
  };
}

function poolCardEl(card, badge = "") {
  const el = document.createElement("div");
  const kind = card.kind || (card.id === "daotong" ? "char" : "artifact");
  el.className = `pool-card kind-${kind} type-${card.cardType || "fabao"}`;
  el.dataset.cardId = card.id;
  const thumb = card.art
    ? `<div class="pool-thumb"><img class="art-${kind}" src="${card.art}" alt="${card.name}" draggable="false" /></div>`
    : `<div class="icon">${card.icon}</div>`;
  const typeName = CARD_TYPE_NAMES[card.cardType] || "法宝";
  const wt = card.cardType === "weapon" ? ` · 重${card.weight}` : "";
  el.innerHTML = `
    ${thumb}
    <div class="title">${card.name}</div>
    <div class="size">${typeName}${wt}${badge}</div>
    <div class="meta">攻${card.atk} 血${card.hp} · ${(card.cd / 1000).toFixed(1)}s</div>
  `;
  return el;
}

function poolSection(root, title, hint = "") {
  const el = document.createElement("div");
  el.className = "pool-sec";
  el.innerHTML = `<span>${title}</span>${hint ? `<em>${hint}</em>` : ""}`;
  root.appendChild(el);
}

export function buildPool(root) {
  root.innerHTML = "";
  const chars = PLAYER_LIBRARY.filter((c) => c.cardType === "char" || c.cardType === "fabao");
  const weapons = PLAYER_LIBRARY.filter((c) => c.cardType === "weapon");
  const spells = PLAYER_LIBRARY.filter((c) => c.cardType === "spell");

  poolSection(root, "主角 · 法宝");
  for (const card of chars) root.appendChild(poolCardEl(card));

  poolSection(root, "武器", "体修开手持格后可持");
  for (const card of weapons) root.appendChild(poolCardEl(card));

  poolSection(root, "法术", "法修开识海格后可挂");
  for (const card of spells) root.appendChild(poolCardEl(card));

  const owned = ownedBeasts();
  const beastIds = Object.keys(owned).filter((id) => owned[id] > 0);
  if (beastIds.length) {
    poolSection(root, "御兽", "战斗收服所得");
    for (const id of beastIds) {
      const card = ENEMY_LIBRARY.find((c) => c.id === id);
      if (card) root.appendChild(poolCardEl(card, ` ×${owned[id]}`));
    }
  }
}

function refreshPoolStats(stage) {
  const root = document.getElementById("card-pool");
  if (!root) return;
  for (const el of root.querySelectorAll(".pool-card")) {
    const card =
      PLAYER_LIBRARY.find((c) => c.id === el.dataset.cardId) ||
      ENEMY_LIBRARY.find((c) => c.id === el.dataset.cardId);
    if (!card) continue;
    const e = effectiveStats(card, stage, "player");
    const meta = el.querySelector(".meta");
    if (meta) meta.textContent = `攻${e.atk} 血${e.hp} · ${(e.cd / 1000).toFixed(1)}s`;
  }
}

function laneAlign(side) {
  return side === "enemy" ? "start" : "end";
}

// ==== 类型化格位：美术框 + 悬浮说明 ====

const SLOT_ART = {
  char: "assets/slots/slot-char.png",
  fabao: "assets/slots/slot-fabao.png",
  weapon: "assets/slots/slot-weapon.png",
  spell: "assets/slots/slot-spell.png",
  beast: "assets/slots/slot-beast.png",
  monster: "assets/slots/slot-monster.png",
  locked: "assets/slots/slot-locked.png",
  plain: "assets/slots/slot-plain.png",
};

const SLOT_TAGS = {
  char: "本体",
  fabao: "法宝",
  weapon: "手持",
  spell: "识海",
  beast: "兽栏",
  monster: "妖兽",
  locked: "封印",
  plain: "空位",
};

function currentModsUi() {
  return mergeMods(talentMods(), equipMods());
}

function laneCapacity(state, slots) {
  return Math.min(
    capAt(state.unlockStage),
    1 + slots.fabao + slots.hand + slots.mind + slots.beast,
  );
}

/**
 * 排出一条队列的 10 个格位类型：
 * - 已占用位按占用者类型（卡牌覆盖其上，仅作衬底）
 * - 空位按「剩余容量」依次排类型（本体→法宝→手持→识海→兽栏）
 * - 容量之外一律封印
 */
function slotPlan(state, side, slots, capacity) {
  const plan = [];
  if (side === "enemy") {
    // 敌方规模纯关卡驱动（见 main.enemyCount），格位即当前队列规模
    const q = state.enemyQueue;
    for (let i = 0; i < SLOT_COUNT; i++) {
      plan.push(i < q.length ? "monster" : "locked");
    }
    return plan;
  }
  const q = state.playerQueue;
  const cnt = (t) => q.filter((u) => u.cardType === t).length;
  for (const u of q) plan.push(u.cardType in SLOT_ART ? u.cardType : "fabao");
  const rest = [];
  if (cnt("char") < 1) rest.push("char");
  for (let i = cnt("fabao"); i < slots.fabao; i++) rest.push("fabao");
  for (let i = cnt("weapon"); i < slots.hand; i++) rest.push("weapon");
  for (let i = cnt("spell"); i < slots.mind; i++) rest.push("spell");
  for (let i = cnt("beast"); i < slots.beast; i++) rest.push("beast");
  while (plan.length < SLOT_COUNT) plan.push(rest.length ? rest.shift() : "locked");
  return plan.slice(0, SLOT_COUNT);
}

/** 封印格提示：列出还能通过哪些道途开格。 */
function lockedTipHtml(state, slots, capacity) {
  const ways = [];
  if (slots.hand <= 0) ways.push("体修「两手蛮力」开手持格");
  if (slots.mind <= 0) ways.push("法修「识海开窍」开识海格");
  if (slots.beast <= 0) ways.push("御兽「兽栏」开兽栏格");
  ways.push("器道「多宝／万宝归宗」扩法宝格");
  const capMax = capAt(state.unlockStage);
  const capNote = capacity >= capMax
    ? `位置上限 ${capMax} 已全部开启（随关卡解锁，封顶 10）`
    : `已开格位 ${capacity}/${capMax}（上限随关卡解锁提升）`;
  return `<strong>🔒 封印之位</strong><span class="tip-stats">${capNote}</span><span class="tip-desc">修习道途天赋可解开封印：${ways.join("；")}。</span>`;
}

function slotTipHtml(type, state, slots, capacity) {
  const q = state.playerQueue;
  const cnt = (t) => q.filter((u) => u.cardType === t).length;
  if (type === "char") {
    return `<strong>🧘 本体格</strong><span class="tip-stats">全队仅此一位</span><span class="tip-desc">道童本尊之位。手持武器与识海法术皆系于他一身：道童若阵亡，武器与法术随之消散。</span>`;
  }
  if (type === "fabao") {
    return `<strong>☯ 法宝格 ${cnt("fabao")}/${slots.fabao}</strong><span class="tip-stats">可放入：法宝（幡、剑等子类）</span><span class="tip-desc">法宝有独立血量、自走出手。幡类吞魂叠层、剑类可入剑阵。修「器道·多宝／万宝归宗」扩容。</span>`;
  }
  if (type === "weapon") {
    const used = q.filter((u) => u.cardType === "weapon").reduce((s, u) => s + (u.weight || 0), 0);
    return `<strong>✊ 手持格 ${cnt("weapon")}/${slots.hand}</strong><span class="tip-stats">重量 ${used}/${slots.weight} · 只能放武器</span><span class="tip-desc">武器捏在道童手中：不占承伤位、不会被集火，但受力量预算（重量）约束。体修天赋可增手增力，「法宝合身」可把武器血量并入道童。</span>`;
  }
  if (type === "spell") {
    return `<strong>👁 识海格 ${cnt("spell")}/${slots.mind}</strong><span class="tip-stats">只能放法术</span><span class="tip-desc">识海中温养的法术：无血量、不可被攻击，按冷却自动施放。法修天赋可拓识海、增法术强度。</span>`;
  }
  if (type === "beast") {
    return `<strong>🐾 兽栏格 ${cnt("beast")}/${slots.beast}</strong><span class="tip-stats">只能放收服的妖兽</span><span class="tip-desc">战斗胜利时有概率收服被击杀的妖兽（基础10%+天赋/气运）。收服后从卡池「御兽」分区上阵。</span>`;
  }
  if (type === "monster") {
    return `<strong>👹 妖兽格</strong><span class="tip-stats">敌方出战 ${state.enemyQueue.length} 只</span><span class="tip-desc">妖兽规模随路程增长：第 1 关 5 只，每推进 2 关多 1 只，最多 10 只。</span>`;
  }
  return lockedTipHtml(state, slots, capacity);
}

function renderSlots(slotRoot, layerEl, side, state) {
  if (!slotRoot || !layerEl) return;
  const box = layerEl.getBoundingClientRect();
  const slots = slotTable(currentModsUi());
  const capacity = laneCapacity(state, slots);
  const plan = slotPlan(state, side, slots, capacity);
  const occupied = side === "enemy" ? state.enemyQueue.length : state.playerQueue.length;
  const wUsed = state.playerQueue
    .filter((u) => u.cardType === "weapon")
    .reduce((s, u) => s + (u.weight || 0), 0);
  const sig = `${Math.round(box.width)}x${Math.round(box.height)}|${plan.join(",")}|${occupied}|${state.unlockStage}|${wUsed}`;
  if (slotRoot.dataset.sig === sig && slotRoot.childElementCount === SLOT_COUNT) return;
  slotRoot.dataset.sig = sig;
  const m = measureCardSize(box.width, box.height, laneAlign(side));
  slotRoot.className = `slot-row tight ${side}`;
  slotRoot.innerHTML = "";
  slotRoot.style.left = `${m.pad}px`;
  slotRoot.style.top = `${m.top}px`;
  slotRoot.style.bottom = "auto";
  slotRoot.style.width = `${m.packW}px`;
  slotRoot.style.height = `${m.cardH}px`;
  for (let i = 0; i < SLOT_COUNT; i++) {
    const type = plan[i] || "locked";
    const isOccupied = i < occupied;
    const slot = document.createElement("div");
    slot.className = `slot st-${type}${isOccupied ? " occupied" : type === "locked" ? " locked" : " usable"}`;
    slot.style.width = `${m.cardW}px`;
    slot.style.height = `${m.cardH}px`;
    slot.style.marginRight = i < SLOT_COUNT - 1 ? `${m.gap}px` : "0";
    slot.innerHTML = `
      <img class="slot-art" src="${SLOT_ART[type]}" alt="" draggable="false" />
      ${isOccupied ? "" : `<span class="slot-tag">${SLOT_TAGS[type]}</span>`}
    `;
    if (!isOccupied) slot.dataset.tipHtml = slotTipHtml(type, state, slots, capacity);
    slotRoot.appendChild(slot);
  }
}

function artKind(unit) {
  if (unit.kind) return unit.kind;
  if (unit.pool === "enemy") return "monster";
  if (unit.cardId === "daotong") return "char";
  return "artifact";
}

function artHtml(unit, dead) {
  if (unit.art) {
    return `<img class="art-img art-${artKind(unit)}" src="${unit.art}" alt="${unit.name}" draggable="false" />`;
  }
  return `<div class="icon">${dead ? "🪦" : unit.icon}</div>`;
}

function cardInnerHtml(unit, i, dead, isFocus, skin) {
  const hpPct = dead ? 0 : (100 * unit.hp) / unit.maxHp;
  const chargeLeft = dead ? 100 : Math.max(0, Math.min(100, (100 * unit.cdLeft) / unit.cd));
  const badge = dead
    ? `<div class="corpse-badge">尸体</div>`
    : isFocus
      ? `<div class="focus-badge">集火</div>`
      : "";
  if (skin === "skin2") {
    const chargePct = dead ? 0 : Math.max(0, Math.min(100, 100 * (1 - unit.cdLeft / unit.cd)));
    const hp = dead ? 0 : Math.max(0, Math.round(unit.hp));
    const fillRatio = dead ? 0 : Math.max(0, Math.min(1, unit.hp / unit.maxHp));
    const shOn = !dead && unit.shield > 0;
    const shRatio = shOn ? Math.max(0, Math.min(1, unit.shield / unit.maxHp)) : 0;
    const sh = shOn ? Math.round(unit.shield) : 0;
    const lv = unit.lv || unit.face || 1;
    const liquidLow = fillRatio > 0 && fillRatio <= 0.3 ? " low" : "";
    return `
      <div class="s2-lv">${lv}级</div>
      ${badge}
      <div class="s2-art">${artHtml(unit, dead)}</div>
      <div class="s2-name">${unit.name}</div>
      <div class="s2-orb">
        <svg class="s2-ring" viewBox="0 0 36 36" aria-hidden="true">
          <circle class="s2-track" cx="18" cy="18" r="15.6" pathLength="100" />
          <circle class="s2-fill" cx="18" cy="18" r="15.6" pathLength="100"
            stroke-dasharray="${chargePct.toFixed(1)} 100" transform="rotate(-90 18 18)" />
        </svg>
        <div class="s2-disk">
          <div class="s2-liquid${liquidLow}" style="--hp:${fillRatio.toFixed(3)}"></div>
          <div class="s2-shield" style="--sh:${shRatio.toFixed(3)}" ${shOn ? "" : "hidden"}></div>
          <div class="s2-readout">
            <small class="s2-sh-num" ${shOn ? "" : "hidden"}>${sh}</small>
            <span class="s2-hp-num">${hp}</span>
          </div>
        </div>
        <div class="s2-sh-mark" title="护盾 ${sh}" ${shOn ? "" : "hidden"}></div>
      </div>
    `;
  }

  const shPct = !dead && unit.shield > 0 ? Math.min(100, (100 * unit.shield) / unit.maxHp) : 0;
  return `
    <div class="charge-mask" style="height:${chargeLeft}%"></div>
    ${badge}
    <div class="portrait">
      <div class="art-win">${artHtml(unit, dead)}</div>
      <div class="name">${unit.name}</div>
    </div>
    <div class="idx">#${i + 1}</div>
    <div class="hp-track${hpPct > 0 && hpPct <= 30 ? " low" : ""}">
      <span class="hp-fill" style="width:${hpPct}%"></span>
      <span class="sh-fill" style="width:${shPct}%" ${shPct > 0 ? "" : "hidden"}></span>
    </div>
  `;
}

function cardClassName(unit, i, pos, selectedUid, focusUid, skinId) {
  const dead = unit.status === "corpse";
  const isFocus = !dead && unit.uid === focusUid;
  const job = unit.theme || "gold";
  return [
    "unit-card",
    skinId,
    unit.side,
    `face-${unit.face}`,
    `job-${job}`,
    `kind-${artKind(unit)}`,
    pos.stacked ? "stacked" : "",
    unit.actingUntil > performance.now() ? "acting" : "",
    unit.uid === selectedUid ? "selected" : "",
    isFocus ? "focus" : "",
    dead ? "corpse" : "",
  ]
    .filter(Boolean)
    .join(" ");
}

function patchCardStats(card, unit, dead, skinId) {
  const hpPct = dead ? 0 : (100 * unit.hp) / unit.maxHp;
  const fillRatio = dead ? 0 : Math.max(0, Math.min(1, unit.hp / unit.maxHp));
  const chargeLeft = dead ? 100 : Math.max(0, Math.min(100, (100 * unit.cdLeft) / unit.cd));
  const chargePct = dead ? 0 : Math.max(0, Math.min(100, 100 * (1 - unit.cdLeft / unit.cd)));
  const shOn = !dead && unit.shield > 0;
  const shRatio = shOn ? Math.max(0, Math.min(1, unit.shield / unit.maxHp)) : 0;
  if (skinId === "skin2") {
    const liquid = card.querySelector(".s2-liquid");
    const shield = card.querySelector(".s2-shield");
    const num = card.querySelector(".s2-hp-num");
    const shNum = card.querySelector(".s2-sh-num");
    const shMark = card.querySelector(".s2-sh-mark");
    const ring = card.querySelector(".s2-fill");
    if (liquid) {
      liquid.style.setProperty("--hp", fillRatio.toFixed(3));
      liquid.classList.toggle("low", fillRatio > 0 && fillRatio <= 0.3);
    }
    if (shield) {
      shield.style.setProperty("--sh", shRatio.toFixed(3));
      shield.hidden = !shOn;
    }
    if (num) num.textContent = String(dead ? 0 : Math.max(0, Math.round(unit.hp)));
    if (shNum) {
      shNum.textContent = shOn ? String(Math.round(unit.shield)) : "";
      shNum.hidden = !shOn;
    }
    if (shMark) {
      shMark.hidden = !shOn;
      shMark.title = shOn ? `护盾 ${Math.round(unit.shield)}` : "";
    }
    if (ring) ring.setAttribute("stroke-dasharray", `${chargePct.toFixed(1)} 100`);
    return;
  }
  const fill = card.querySelector(".hp-fill");
  const shFill = card.querySelector(".sh-fill");
  const track = card.querySelector(".hp-track");
  const mask = card.querySelector(".charge-mask");
  if (fill) fill.style.width = `${hpPct}%`;
  if (shFill) {
    shFill.style.width = `${shRatio * 100}%`;
    shFill.hidden = !shOn;
  }
  if (track) track.classList.toggle("low", hpPct > 0 && hpPct <= 30);
  if (mask) mask.style.height = `${chargeLeft}%`;
}

function renderCardLayer(layer, queue, side, selectedUid, focusUid, skin) {
  if (!layer) return [];
  const box = layer.getBoundingClientRect();
  const items = computeLaneLayout(queue.length, box.width, box.height, laneAlign(side));
  layoutCache[side] = items;
  const skinId = skin === "skin2" ? "skin2" : "skin1";
  const keep = new Set();

  queue.forEach((unit, i) => {
    const pos = items[i];
    if (!pos) return;
    const uid = String(unit.uid);
    keep.add(uid);
    const dead = unit.status === "corpse";
    const isFocus = !dead && unit.uid === focusUid;
    const kind = artKind(unit);
    const cardId = String(unit.cardId || "");
    let card = layer.querySelector(`.unit-card[data-uid="${uid}"]`);
    const rebuild =
      !card ||
      card.dataset.uid !== uid ||
      card.dataset.kind !== kind ||
      card.dataset.cardId !== cardId ||
      card.dataset.skin !== skinId ||
      card.dataset.dead !== String(dead) ||
      card.dataset.idx !== String(i) ||
      card.dataset.focus !== String(isFocus) ||
      card.dataset.shield !== String(unit.shield || 0);
    if (!card) {
      card = document.createElement("div");
      layer.appendChild(card);
    }
    card.dataset.uid = uid;
    card.dataset.kind = kind;
    card.dataset.cardId = cardId;
    card.dataset.side = unit.side;
    card.dataset.index = String(i);
    card.dataset.skin = skinId;
    card.dataset.dead = String(dead);
    card.dataset.idx = String(i);
    card.dataset.focus = String(isFocus);
    card.dataset.shield = String(unit.shield || 0);
    const keepAnim = ["atk-anim", "hit-anim", "hit-dead", "heal-anim"].filter((c) => card.classList.contains(c));
    card.className = cardClassName(unit, i, pos, selectedUid, focusUid, skinId);
    for (const c of keepAnim) card.classList.add(c);
    card.style.left = `${pos.left}px`;
    card.style.top = `${pos.top}px`;
    card.style.width = `${pos.width}px`;
    card.style.height = `${pos.height}px`;
    let z = pos.z;
    if (isFocus) z = 55;
    if (unit.uid === selectedUid) z = 70;
    card.style.zIndex = String(z);
    if (rebuild) card.innerHTML = cardInnerHtml(unit, i, dead, isFocus, skinId);
    patchCardStats(card, unit, dead, skinId);
  });

  for (const el of [...layer.querySelectorAll(".unit-card")]) {
    if (!keep.has(el.dataset.uid)) el.remove();
  }
  return items;
}

export function renderUnlock(state) {
  const cap = capAt(state.unlockStage);
  const label = document.getElementById("unlock-label");
  const stage = document.getElementById("unlock-stage");
  const bar = document.getElementById("unlock-bar");
  const hint = document.getElementById("unlock-hint");
  if (label) label.textContent = `可携带 ${state.playerQueue.length}/${cap}`;
  const region = regionOf(state.unlockStage);
  const node = nodeIndexOf(state.unlockStage);
  const focus = Number.isFinite(state.focusStage) ? state.focusStage : state.unlockStage;
  const pm = playerMult(state.unlockStage);
  const mm = monsterMult(focus);
  if (stage) {
    stage.textContent = `关卡 ${state.unlockStage + 1} · ${region.name} ${node + 1}/${NODES_PER_REGION}`;
  }
  if (bar) bar.style.width = `${(100 * cap) / capAt(MAX_STAGE)}%`;
  if (hint) {
    const boss = mm.boss ? "Boss " : "";
    hint.textContent =
      `我方攻×${fmtMult(pm.atk)} 血×${fmtMult(pm.hp)}　${boss}敌军攻×${fmtMult(mm.atk)} 血×${fmtMult(mm.hp)}。回打旧路点只削弱敌军。携带上限仍到 ${MAX_STAGE + 1} 关封顶。`;
  }
  const wins = document.getElementById("win-count");
  if (wins) wins.textContent = `胜利 ${state.wins} 次`;
  renderSlotSummary(state);
  refreshPoolStats(state.unlockStage);
}

/** 左栏格位摘要：天赋+装备决定各类型格位数量。 */
export function renderSlotSummary(state) {
  const el = document.getElementById("slot-summary");
  if (!el) return;
  const slots = slotTable(mergeMods(talentMods(), equipMods()));
  const q = state.playerQueue;
  const cnt = (t) => q.filter((u) => u.cardType === t).length;
  const wUsed = q.filter((u) => u.cardType === "weapon").reduce((s, u) => s + (u.weight || 0), 0);
  const parts = [
    `法宝 ${cnt("fabao")}/${slots.fabao}`,
    slots.hand > 0 ? `手持 ${cnt("weapon")}/${slots.hand}（重 ${wUsed}/${slots.weight}）` : "手持 未开",
    slots.mind > 0 ? `识海 ${cnt("spell")}/${slots.mind}` : "识海 未开",
    slots.beast > 0 ? `兽栏 ${cnt("beast")}/${slots.beast}` : "兽栏 未开",
  ];
  el.textContent = `格位：${parts.join(" · ")}`;
}

export function renderBoards(state, lanes) {
  const cap = capAt(state.unlockStage);
  const eFocus = leftmostTargetable(state.enemyQueue);
  const pFocus = leftmostTargetable(state.playerQueue);
  renderSlots(lanes.enemySlots, lanes.enemyCards, "enemy", state);
  renderSlots(lanes.playerSlots, lanes.playerCards, "player", state);
  const skin = state.cardSkin === "skin2" ? "skin2" : "skin1";
  if (lanes.enemyCards) lanes.enemyCards.dataset.skin = skin;
  if (lanes.playerCards) lanes.playerCards.dataset.skin = skin;
  renderCardLayer(lanes.enemyCards, state.enemyQueue, "enemy", state.selectedUid, eFocus?.uid, skin);
  renderCardLayer(lanes.playerCards, state.playerQueue, "player", state.selectedUid, pFocus?.uid, skin);

  const eCount = document.getElementById("enemy-count");
  const pCount = document.getElementById("player-count");
  if (eCount) {
    eCount.textContent = `${livingUnits(state.enemyQueue).length} 存活 / ${corpses(state.enemyQueue).length} 尸体`;
  }
  if (pCount) {
    pCount.textContent = `${livingUnits(state.playerQueue).length} 存活 / ${corpses(state.playerQueue).length} 尸体`;
  }
  renderUnlock(state);
  renderMap(state, sceneCorridor);
}

export function hitInsertIndex(laneEl, queue, clientX) {
  if (!laneEl) return 0;
  if (!queue.length) return 0;
  const cards = [...laneEl.querySelectorAll(".unit-card")];
  for (const card of cards) {
    const r = card.getBoundingClientRect();
    if (clientX < r.left + r.width / 2) return Number(card.dataset.index);
  }
  return queue.length;
}

export function showInsertCaret(lanes, side, index, queue, ok) {
  const lane = side === "player" ? lanes.playerLane : lanes.enemyLane;
  const caret = side === "player" ? lanes.playerCaret : lanes.enemyCaret;
  const layer = side === "player" ? lanes.playerCards : lanes.enemyCards;
  if (!caret || !lane || !layer) return;
  const box = layer.getBoundingClientRect();
  const items = layoutCache[side] || [];
  let x;
  if (!items.length || index <= 0) x = 10;
  else if (index >= items.length) {
    const last = items[items.length - 1];
    x = last.left + last.width + 4;
  } else {
    x = items[index].left - 3;
  }
  caret.hidden = false;
  caret.classList.toggle("bad", !ok);
  caret.style.left = `${x}px`;
  const row = items[0];
  caret.style.top = row ? `${row.top}px` : "10px";
  caret.style.height = row ? `${row.height}px` : `${Math.max(40, box.height - 16)}px`;
}

export function hideInsertCaret(lanes) {
  if (lanes.playerCaret) lanes.playerCaret.hidden = true;
  if (lanes.enemyCaret) lanes.enemyCaret.hidden = true;
}

let tipLocked = false;

function tipEl() {
  return document.getElementById("card-tip");
}

function placeTip(x, y) {
  const el = tipEl();
  if (!el || el.hidden) return;
  const pad = 8;
  const r = el.getBoundingClientRect();
  let left = x + 16;
  let top = y - r.height - 12;
  if (top < pad) top = y + 18;
  if (left + r.width > window.innerWidth - pad) left = x - r.width - 12;
  if (left < pad) left = pad;
  if (top + r.height > window.innerHeight - pad) top = window.innerHeight - r.height - pad;
  el.style.left = `${left}px`;
  el.style.top = `${top}px`;
}

export function formatCardTip(card, stage = 0) {
  if (!card) return "";
  const e = effectiveStats(card, stage, "player");
  const scaled = e.atk !== card.atk || e.hp !== card.hp;
  const now = scaled
    ? `<span class="tip-stats">当前 攻 ${e.atk}　血 ${e.hp}　CD ${(e.cd / 1000).toFixed(1)}s</span>`
    : "";
  const typeName = CARD_TYPE_NAMES[card.cardType] || "法宝";
  const wt = card.cardType === "weapon" ? `（重量 ${card.weight}）` : "";
  return `<strong>${card.name} · ${typeName}${wt}</strong><span class="tip-stats">白板 攻 ${card.atk}　血 ${card.hp}　CD ${(card.cd / 1000).toFixed(1)}s</span>${now}<span class="tip-desc">${card.skillText}</span>`;
}

export function formatUnitTip(unit, elapsedSec = 0) {
  if (!unit) return "";
  const dead = unit.status === "corpse";
  const cd = dead ? "冷却已停" : `CD ${(Math.max(0, unit.cdLeft) / 1000).toFixed(2)}s / ${(unit.cd / 1000).toFixed(1)}s`;
  const dealt = Math.round(unit.damageDealt || 0);
  const sec = Math.max(0.1, elapsedSec || 0.1);
  const dps = (dealt / sec).toFixed(1);
  const out = dealt > 0 || (unit.healDone || 0) > 0
    ? `<span class="tip-stats">输出 ${dealt}　DPS ${dps}${unit.healDone ? `　治疗 ${Math.round(unit.healDone)}` : ""}</span>`
    : "";
  const mult =
    unit.atkMult != null
      ? `<span class="tip-stats">关卡 攻×${fmtMult(unit.atkMult)}　血×${fmtMult(unit.hpMult)}</span>`
      : "";
  return `<strong>${unit.name}${dead ? " · 尸体" : ""}</strong><span class="tip-stats">攻 ${unit.atk}　血 ${unit.hp}/${unit.maxHp}${unit.shield ? `　盾 ${unit.shield}` : ""}　${cd}</span>${mult}${out}<span class="tip-desc">${unit.skillText}</span>`;
}

export function hideCardTip() {
  const el = tipEl();
  if (el) el.hidden = true;
}

export function lockCardTip(on) {
  tipLocked = !!on;
  if (tipLocked) hideCardTip();
}

export function showCardTip(html, x, y) {
  if (tipLocked || !html) {
    hideCardTip();
    return;
  }
  const el = tipEl();
  if (!el) return;
  el.innerHTML = html;
  el.hidden = false;
  placeTip(x, y);
}

export function battleElapsedSec(state) {
  if (!state?.battleStartTs) return 0;
  const end = state.running ? performance.now() : (state.battleEndTs || state.battleStartTs);
  return Math.max(0.1, (end - state.battleStartTs) / 1000);
}

function fmtDps(n) {
  return n >= 100 ? n.toFixed(0) : n.toFixed(1);
}

export function renderDps(state) {
  const box = document.getElementById("dps-board");
  if (!box) return;
  if (!state.battleStartTs) {
    box.innerHTML = `<p class="dps-empty">开战后再统计输出</p>`;
    return;
  }
  const sec = battleElapsedSec(state);
  const players = [...state.playerQueue].sort((a, b) => (b.damageDealt || 0) - (a.damageDealt || 0) || a.index - b.index);
  const pDmg = players.reduce((s, u) => s + (u.damageDealt || 0), 0);
  const pHeal = players.reduce((s, u) => s + (u.healDone || 0), 0);
  const eDmg = state.enemyQueue.reduce((s, u) => s + (u.damageDealt || 0), 0);
  const rows = players.map((u) => {
    const dmg = Math.round(u.damageDealt || 0);
    return `<div class="dps-row${u.status === "corpse" ? " dead" : ""}"><span>${u.name}</span><span>${dmg}</span><span>${fmtDps(dmg / sec)}</span></div>`;
  }).join("");
  const healLine = pHeal > 0 ? `<div class="dps-heal">我方治疗 ${Math.round(pHeal)}</div>` : "";
  box.innerHTML = `
    <div class="dps-head"><span>单位</span><span>总伤</span><span>DPS</span></div>
    ${rows || `<p class="dps-empty">我方无人出手</p>`}
    <div class="dps-sum">我方合计 ${Math.round(pDmg)}　DPS ${fmtDps(pDmg / sec)}</div>
    ${healLine}
    <div class="dps-enemy">敌方合计 ${Math.round(eDmg)}　DPS ${fmtDps(eDmg / sec)}</div>
  `;
}

export function renderInspect(state, hoverUid = null) {
  const box = document.getElementById("inspect");
  if (!box) return;
  const all = [...state.playerQueue, ...state.enemyQueue];
  const uid = hoverUid ?? state.selectedUid;
  const unit = all.find((u) => u.uid === uid) || null;
  box.textContent = unitDesc(unit);
}

export function setStatus(text, kind = "") {
  const mid = document.getElementById("battle-status");
  const out = document.getElementById("outcome");
  if (mid) mid.textContent = text;
  if (out) {
    out.textContent = text;
    out.className = `outcome ${kind}`;
  }
}

export function cardCenter(uid) {
  const el = document.querySelector(`.unit-card[data-uid="${uid}"]`);
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
}

export function renderLinks(_state) {
  const svg = document.getElementById("link-layer");
  if (svg) svg.innerHTML = "";
  return;
  const overlayRect = svg.getBoundingClientRect();
  let pairs = collectTargetPairs(state);
  if (!state.running) {
    pairs = pairs.filter((p) => p.from.uid === state.selectedUid);
  }
  const selected = pairs.filter((p) => p.from.uid === state.selectedUid);
  const rest = pairs.filter((p) => p.from.uid !== state.selectedUid);

  const draw = (pair, strong) => {
    const a = cardCenter(pair.from.uid);
    const b = cardCenter(pair.to.uid);
    if (!a || !b) return "";
    const x1 = a.x - overlayRect.left;
    const y1 = a.y - overlayRect.top;
    const x2 = b.x - overlayRect.left;
    const y2 = b.y - overlayRect.top;
    const color = pair.from.side === "player" ? "#7dce8a" : "#e07a72";
    const op = strong ? 0.95 : 0.18;
    const w = strong ? 2.6 : 1;
    return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-opacity="${op}" stroke-width="${w}" />`;
  };

  svg.setAttribute("viewBox", `0 0 ${overlayRect.width} ${overlayRect.height}`);
  svg.innerHTML = rest.map((p) => draw(p, false)).join("") + selected.map((p) => draw(p, true)).join("");
}

const flying = [];
const floats = [];
let floatSeq = 0;

function fxLayer() {
  return document.getElementById("float-layer");
}

function quadBezier(a, c, b, t) {
  const u = 1 - t;
  return u * u * a + 2 * u * t * c + t * t * b;
}

export function spawnFloat(unit, text, kind, at = null) {
  if (!unit) return;
  const pos = at || cardCenter(unit.uid);
  if (!pos) return;
  const n = floatSeq++;
  const ox = ((n % 5) - 2) * 10 + (Math.random() * 16 - 8);
  const oy = (n % 3) * -5;
  const el = document.createElement("div");
  el.className = `float-num ${kind}`;
  el.textContent = text;
  el.style.left = `${pos.x + ox}px`;
  el.style.top = `${pos.y + oy}px`;
  el.style.opacity = "1";
  fxLayer()?.appendChild(el);
  floats.push({
    el,
    born: performance.now(),
    dur: 780,
    hopX: (Math.random() * 2 - 1) * 22,
    spin: (Math.random() * 2 - 1) * 8,
  });
}

const CARD_ANIMS = ["atk-anim", "hit-anim", "hit-dead", "heal-anim"];

export function playCardAnim(uid, kind, towardUid = null) {
  const el = document.querySelector(`.unit-card[data-uid="${uid}"]`);
  if (!el) return;
  if (kind === "atk" && towardUid != null) {
    const from = cardCenter(uid);
    const to = cardCenter(towardUid);
    if (from && to) {
      const dx = to.x - from.x;
      const dy = to.y - from.y;
      const len = Math.hypot(dx, dy) || 1;
      const px = 8;
      el.style.setProperty("--atk-x", `${(dx / len) * px}px`);
      el.style.setProperty("--atk-y", `${(dy / len) * px}px`);
    }
  }
  el.classList.remove(...CARD_ANIMS);
  void el.offsetWidth;
  if (kind === "atk") el.classList.add("atk-anim");
  else if (kind === "dead") el.classList.add("hit-anim", "hit-dead");
  else if (kind === "heal") el.classList.add("heal-anim");
  else el.classList.add("hit-anim");
  clearTimeout(el._animTimer);
  el._animTimer = setTimeout(() => el.classList.remove(...CARD_ANIMS), kind === "dead" ? 260 : 220);
}

export function clearProjectiles() {
  for (const b of flying) {
    b.dead = true;
    b.el?.remove();
  }
  flying.length = 0;
  document.querySelectorAll(".bullet, .beam-ray").forEach((el) => el.remove());
}

export function clearFx() {
  clearProjectiles();
  for (const f of floats) f.el.remove();
  floats.length = 0;
  fxLayer()?.replaceChildren();
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function easeOutQuad(t) {
  return 1 - (1 - t) * (1 - t);
}

export function bulletDuration(style, fromUid, toUid) {
  const a = cardCenter(fromUid);
  const b = cardCenter(toUid);
  const dist = a && b ? Math.hypot(b.x - a.x, b.y - a.y) : 180;
  if (style === "beam") return 180;
  if (style === "melee") return Math.max(280, Math.min(450, 300 + dist * 0.38));
  if (style === "heal") return 0;
  return Math.max(480, Math.min(720, 500 + dist * 0.55));
}

export function spawnBullet({ fromUid, toUid, style, flavor = "", secondary = false, duration, onArrive }) {
  const layer = fxLayer();
  const from = cardCenter(fromUid);
  const to = cardCenter(toUid);
  if (!layer || !from || !to) {
    onArrive?.();
    return;
  }

  const el = document.createElement("div");
  el.className = `bullet ${style}${flavor ? ` ${flavor}` : ""}${secondary ? " secondary" : ""}`;
  if (style === "ranged") {
    const trail = document.createElement("span");
    trail.className = "bullet-trail";
    el.appendChild(trail);
  }
  if (style === "beam") {
    const ray = document.createElement("div");
    ray.className = "beam-ray";
    const spark = document.createElement("span");
    spark.className = "beam-spark";
    el.appendChild(ray);
    el.appendChild(spark);
  }
  layer.appendChild(el);

  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const len = Math.hypot(dx, dy) || 1;
  const arc = style === "melee" ? Math.min(68, Math.max(24, len * 0.24)) : 0;

  flying.push({
    el,
    from,
    to,
    fromUid,
    toUid,
    style,
    secondary,
    arc,
    len,
    dx,
    dy,
    start: performance.now(),
    dur: style === "beam"
      ? Math.max(120, Math.min(220, duration || 180))
      : Math.max(260, duration || bulletDuration(style, fromUid, toUid)),
    onArrive,
    done: false,
    hitDone: false,
  });
}

function tickBullets(now) {
  for (let i = flying.length - 1; i >= 0; i--) {
    const b = flying[i];
    if (b.done) {
      flying.splice(i, 1);
      continue;
    }
    const liveFrom = cardCenter(b.fromUid);
    const liveTo = cardCenter(b.toUid);
    if (liveFrom) b.from = liveFrom;
    if (liveTo) b.to = liveTo;
    const t = Math.min(1, (now - b.start) / b.dur);
    const e = b.style === "melee" ? easeOutQuad(t) : t;
    let x;
    let y;
    const ang = Math.atan2(b.to.y - b.from.y, b.to.x - b.from.x);
    if (b.style === "beam") {
      const len = Math.hypot(b.to.x - b.from.x, b.to.y - b.from.y) || 1;
      x = b.to.x;
      y = b.to.y;
      const flash = t < 0.12 ? t / 0.12 : t < 0.62 ? 1 : 1 - (t - 0.62) / 0.38;
      b.el.style.left = `${b.from.x}px`;
      b.el.style.top = `${b.from.y}px`;
      b.el.style.width = `${len}px`;
      b.el.style.opacity = String(Math.max(0, flash));
      b.el.style.transform = `rotate(${ang}rad)${b.secondary ? " scaleY(0.7)" : ""}`;
      const spark = b.el.querySelector(".beam-spark");
      if (spark) spark.style.left = `${Math.min(1, t) * 100}%`;
      if (t >= 0.68 && !b.hitDone) {
        b.hitDone = true;
        b.onArrive?.({ x: b.to.x, y: b.to.y });
      }
      if (t < 1) continue;
      b.el.remove();
      b.done = true;
      flying.splice(i, 1);
      continue;
    }
    if (b.style === "melee") {
      const cpx = (b.from.x + b.to.x) / 2 + (-b.dy / b.len) * b.arc;
      const cpy = (b.from.y + b.to.y) / 2 + (b.dx / b.len) * b.arc;
      x = quadBezier(b.from.x, cpx, b.to.x, e);
      y = quadBezier(b.from.y, cpy, b.to.y, e);
    } else {
      x = lerp(b.from.x, b.to.x, e);
      y = lerp(b.from.y, b.to.y, e);
    }
    const scale = b.secondary ? 0.72 : 1;
    if (b.style === "ranged") {
      b.el.style.transform = `translate(-50%, -50%) rotate(${ang}rad) scale(${scale})`;
    } else {
      b.el.style.transform = `translate(-50%, -50%) scale(${scale})`;
    }
    b.el.style.left = `${x}px`;
    b.el.style.top = `${y}px`;
    if (t < 1) continue;
    const hit = { x, y };
    b.el.remove();
    b.done = true;
    flying.splice(i, 1);
    b.onArrive?.(hit);
  }
}

function tickFloats(now) {
  for (let i = floats.length - 1; i >= 0; i--) {
    const f = floats[i];
    const t = Math.min(1, (now - f.born) / f.dur);
    let scale = 1;
    if (t < 0.11) scale = 0.4 + (t / 0.11) * 0.9;
    else if (t < 0.26) scale = 1.3 - ((t - 0.11) / 0.15) * 0.3;
    else scale = 1;
    let rise;
    if (t < 0.36) rise = easeOutQuad(t / 0.36) * 54;
    else if (t < 0.58) rise = 54 - ((t - 0.36) / 0.22) * 20;
    else rise = 34 + ((t - 0.58) / 0.42) * 8;
    const drift = (f.hopX || 0) * easeOutQuad(t);
    const rot = (f.spin || 0) * (1 - t * 0.35);
    const opacity = t < 0.08 ? t / 0.08 : t < 0.55 ? 1 : 1 - (t - 0.55) / 0.45;
    f.el.style.transform = `translate(calc(-50% + ${drift}px), ${-rise}px) rotate(${rot}deg) scale(${scale})`;
    f.el.style.opacity = String(Math.max(0, opacity));
    if (t >= 1) {
      f.el.remove();
      floats.splice(i, 1);
    }
  }
}

export function tickFx(now = performance.now()) {
  tickBullets(now);
  tickFloats(now);
}

export function fxBusy() {
  return flying.length > 0 || floats.length > 0;
}

export function createDragGhost(icon, face = 1, art = "") {
  const g = document.createElement("div");
  g.className = "ghost";
  g.style.width = `${Math.max(52, 40 + face * 8)}px`;
  const vis = art
    ? `<img class="ghost-art" src="${art}" alt="" draggable="false" />`
    : `<span>${icon}</span>`;
  g.innerHTML = `${vis}<small>插入队列</small>`;
  document.body.appendChild(g);
  return g;
}

export function setCardsPickable(on) {
  document.querySelectorAll(".unit-card").forEach((el) => {
    el.style.pointerEvents = on ? "auto" : "none";
  });
}
