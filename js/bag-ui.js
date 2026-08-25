/** 行囊面板：左侧七部位装配区，右侧背包网格，底部详情对比与操作。 */

import {
  EQUIP_SLOTS,
  rarityById,
  slotById,
  bagItems,
  equippedItem,
  equipItem,
  unequipSlot,
  discardItem,
  itemLines,
} from "./equipment.js?v=dao12";

let overlay = null;
let hooks = { onChange: () => {} };
let selectedId = null; // 背包物品 id 或 "eq:<slotId>"

function buildOverlay() {
  overlay = document.createElement("div");
  overlay.className = "dao-overlay";
  overlay.hidden = true;
  overlay.innerHTML = `
    <div class="dao-frame bag-frame">
      <header class="dao-head">
        <h2>行囊</h2>
        <span class="dao-points" id="bag-count"></span>
        <button type="button" class="btn dao-close" id="bag-close">✕</button>
      </header>
      <div class="dao-body bag-body">
        <div class="bag-equipped">
          <h3>已装配（数值全队生效）</h3>
          <div id="equip-slots"></div>
        </div>
        <div class="bag-list">
          <h3>背包</h3>
          <div id="bag-grid" class="bag-grid"></div>
        </div>
      </div>
      <footer class="dao-foot bag-foot" id="bag-detail">点选装备查看词条</footer>
    </div>
  `;
  document.body.appendChild(overlay);
  overlay.addEventListener("pointerdown", (e) => {
    if (e.target === overlay) closeBag();
  });
  overlay.querySelector("#bag-close").addEventListener("click", closeBag);
}

function slotIconHtml(slot) {
  if (slot.art) return `<img class="chip-art" src="${slot.art}" alt="${slot.name}" draggable="false" />`;
  return `<span class="chip-icon">${slot.icon}</span>`;
}

function chipHtml(item, extraCls = "") {
  const r = rarityById(item.rarity);
  return `
    <div class="bag-chip ${extraCls}" data-item="${item.id}" style="--rc:${r.color}">
      ${slotIconHtml(slotById(item.slot))}
      <span class="chip-name">${item.name}</span>
      <span class="chip-stage">阶${item.stage + 1}</span>
    </div>
  `;
}

function render() {
  const slotsRoot = overlay.querySelector("#equip-slots");
  slotsRoot.innerHTML = EQUIP_SLOTS.map((slot) => {
    const item = equippedItem(slot.id);
    if (!item) {
      return `
        <div class="equip-slot empty" data-slot="${slot.id}">
          ${slotIconHtml(slot)}
          <span class="chip-name muted">${slot.name} · 未装配</span>
        </div>
      `;
    }
    const r = rarityById(item.rarity);
    const sel = selectedId === `eq:${slot.id}` ? " selected" : "";
    return `
      <div class="equip-slot${sel}" data-slot="${slot.id}" data-item="eq:${slot.id}" style="--rc:${r.color}">
        ${slotIconHtml(slot)}
        <span class="chip-name">${item.name}</span>
        <span class="chip-stage">阶${item.stage + 1}</span>
      </div>
    `;
  }).join("");

  const items = [...bagItems()].reverse();
  const grid = overlay.querySelector("#bag-grid");
  grid.innerHTML = items.length
    ? items.map((it) => chipHtml(it, selectedId === it.id ? "selected" : "")).join("")
    : `<p class="bag-empty">空空如也——推关击败妖兽可获掉落</p>`;
  overlay.querySelector("#bag-count").textContent = `${items.length} 件闲置`;

  for (const el of overlay.querySelectorAll(".bag-chip")) {
    el.addEventListener("click", () => {
      selectedId = el.dataset.item;
      render();
    });
  }
  for (const el of overlay.querySelectorAll(".equip-slot:not(.empty)")) {
    el.addEventListener("click", () => {
      selectedId = `eq:${el.dataset.slot}`;
      render();
    });
  }
  renderDetail();
}

function renderDetail() {
  const foot = overlay.querySelector("#bag-detail");
  if (!selectedId) {
    foot.innerHTML = "点选装备查看词条";
    return;
  }

  if (selectedId.startsWith("eq:")) {
    const slotId = selectedId.slice(3);
    const item = equippedItem(slotId);
    if (!item) {
      selectedId = null;
      foot.innerHTML = "点选装备查看词条";
      return;
    }
    foot.innerHTML = `
      <div class="detail-row">
        <strong style="color:${rarityById(item.rarity).color}">${item.name}</strong>
        <span class="detail-lines">${itemLines(item).join("　")}</span>
        <button type="button" class="btn" id="btn-unequip">卸下</button>
      </div>
    `;
    foot.querySelector("#btn-unequip").addEventListener("click", () => {
      unequipSlot(slotId);
      selectedId = null;
      hooks.onChange();
      render();
    });
    return;
  }

  const item = bagItems().find((it) => it.id === selectedId);
  if (!item) {
    selectedId = null;
    foot.innerHTML = "点选装备查看词条";
    return;
  }
  const cur = equippedItem(item.slot);
  const curHtml = cur
    ? `<span class="detail-cur">替换：<em style="color:${rarityById(cur.rarity).color}">${cur.name}</em>（${itemLines(cur).join("　")}）</span>`
    : `<span class="detail-cur muted">该部位当前未装配</span>`;
  foot.innerHTML = `
    <div class="detail-row">
      <strong style="color:${rarityById(item.rarity).color}">${item.name}</strong>
      <span class="detail-lines">${itemLines(item).join("　")}</span>
      <button type="button" class="btn primary" id="btn-equip">装备</button>
      <button type="button" class="btn" id="btn-discard">丢弃</button>
    </div>
    <div class="detail-row">${curHtml}</div>
  `;
  foot.querySelector("#btn-equip").addEventListener("click", () => {
    equipItem(item.id);
    selectedId = `eq:${item.slot}`;
    hooks.onChange();
    render();
  });
  foot.querySelector("#btn-discard").addEventListener("click", () => {
    discardItem(item.id);
    selectedId = null;
    render();
  });
}

export function initBagUI(options) {
  hooks = { ...hooks, ...options };
  buildOverlay();
}

export function openBagPanel() {
  if (!overlay) return;
  overlay.hidden = false;
  render();
}

export function closeBag() {
  if (overlay) overlay.hidden = true;
}
