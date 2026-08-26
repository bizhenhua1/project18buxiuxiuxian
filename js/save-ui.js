/** 档案管理面板：列表、新建、读档、改名、删除。 */

import {
  MAX_SLOTS,
  listSlots,
  activeSlot,
  createSlot,
  switchSlot,
  deleteSlot,
  renameSlot,
  flushActive,
} from "./saves.js?v=dao17";

let overlay = null;
let hooks = { canOpen: () => true };
let renameId = null;
let pending = null;

function formatPlayed(ts) {
  const n = Number(ts) || 0;
  if (!n) return "尚未游玩";
  const diff = Date.now() - n;
  if (diff < 60_000) return "刚刚";
  if (diff < 3600_000) return `${Math.floor(diff / 60_000)} 分钟前`;
  const d = new Date(n);
  const hm = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const that = new Date(d);
  that.setHours(0, 0, 0, 0);
  const days = Math.round((start - that) / 86400000);
  if (days === 0) return `今天 ${hm}`;
  if (days === 1) return `昨天 ${hm}`;
  return `${d.getMonth() + 1}月${d.getDate()}日 ${hm}`;
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function buildOverlay() {
  overlay = document.createElement("div");
  overlay.id = "save-panel";
  overlay.className = "dao-overlay";
  overlay.hidden = true;
  overlay.innerHTML = `
    <div class="dao-frame save-frame">
      <header class="dao-head">
        <h2>档案管理</h2>
        <span class="dao-points" id="save-active-label"></span>
        <button type="button" class="btn dao-close" id="save-close">✕</button>
      </header>
      <div class="dao-body save-body">
        <div id="save-list" class="save-list"></div>
      </div>
      <footer class="dao-foot save-foot" id="save-foot"></footer>
    </div>
  `;
  document.body.appendChild(overlay);
  overlay.addEventListener("pointerdown", (e) => {
    if (e.target === overlay) closeSavePanel();
  });
  overlay.querySelector("#save-close").addEventListener("click", closeSavePanel);
  overlay.querySelector("#save-list").addEventListener("click", onListClick);
  overlay.querySelector("#save-foot").addEventListener("click", onFootClick);
  overlay.addEventListener("keydown", onKeydown);
}

function renderFoot() {
  const foot = overlay.querySelector("#save-foot");
  if (pending?.type === "create") {
    foot.innerHTML = `
      <div class="save-confirm">
        <p>将新建空白档案并立即进入。当前进度会先写入「${escapeHtml(activeSlot()?.name || "当前档案")}」。</p>
        <div class="save-confirm-btns">
          <button type="button" class="btn" data-act="cancel-pending">取消</button>
          <button type="button" class="btn gold" data-act="confirm-create">确定新建</button>
        </div>
      </div>
    `;
    return;
  }
  if (pending?.type === "delete") {
    const last = listSlots().length === 1;
    const extra = last ? "这是最后一个档案，删除后将自动新建空白档。" : "此操作不可恢复。";
    foot.innerHTML = `
      <div class="save-confirm warn">
        <p>确定删除「${escapeHtml(pending.name)}」？${extra}</p>
        <div class="save-confirm-btns">
          <button type="button" class="btn" data-act="cancel-pending">取消</button>
          <button type="button" class="btn" data-act="confirm-delete">确定删除</button>
        </div>
      </div>
    `;
    return;
  }
  const n = listSlots().length;
  foot.innerHTML = `
    <div class="save-new-row">
      <input id="save-new-name" type="text" maxlength="16" placeholder="新档案名称，可空" autocomplete="off" />
      <button type="button" class="btn gold" data-act="ask-create" ${n >= MAX_SLOTS ? "disabled" : ""}>新建档案</button>
    </div>
    <p class="save-hint">${n >= MAX_SLOTS ? `已达上限 ${MAX_SLOTS} 档。` : "进入另一档会先自动保存当前进度；删除需确认。"}</p>
  `;
}

function renderList() {
  const slots = listSlots();
  const root = overlay.querySelector("#save-list");
  overlay.querySelector("#save-active-label").textContent =
    `当前：${activeSlot()?.name || "—"}　${slots.length}/${MAX_SLOTS}`;
  root.innerHTML = slots.map((slot) => {
    const p = slot.preview || {};
    const preview = [p.areaName, p.quest, p.realmTitle, Number.isFinite(p.coins) ? `灵石 ${p.coins}` : ""]
      .filter(Boolean)
      .join(" · ");
    const renaming = renameId === slot.id;
    const nameHtml = renaming
      ? `<input class="save-rename-input" data-id="${escapeHtml(slot.id)}" type="text" maxlength="16" value="${escapeHtml(slot.name)}" />`
      : `<span class="save-slot-name">${escapeHtml(slot.name)}</span>`;
    return `
      <article class="save-slot${slot.active ? " active" : ""}" data-id="${escapeHtml(slot.id)}">
        <div class="save-slot-head">
          ${nameHtml}
          ${slot.active ? `<span class="save-badge">当前</span>` : ""}
          <span class="save-slot-time">${formatPlayed(slot.updatedAt)}</span>
        </div>
        <p class="save-slot-preview">${escapeHtml(preview || "新的旅途")}</p>
        <div class="save-slot-actions">
          <button type="button" class="btn ${slot.active ? "" : "gold"}" data-act="enter" data-id="${escapeHtml(slot.id)}" ${slot.active ? "disabled" : ""}>${slot.active ? "使用中" : "进入"}</button>
          ${renaming
            ? `<button type="button" class="btn gold" data-act="apply-rename" data-id="${escapeHtml(slot.id)}">确定</button>
               <button type="button" class="btn" data-act="cancel-rename">取消</button>`
            : `<button type="button" class="btn" data-act="rename" data-id="${escapeHtml(slot.id)}">改名</button>`}
          <button type="button" class="btn" data-act="ask-delete" data-id="${escapeHtml(slot.id)}" data-name="${escapeHtml(slot.name)}">删除</button>
        </div>
      </article>
    `;
  }).join("");
  if (renameId) {
    const input = root.querySelector(".save-rename-input");
    input?.focus();
    input?.select();
  }
}

function render() {
  if (!overlay) return;
  flushActive();
  renderList();
  renderFoot();
}

function onListClick(e) {
  const btn = e.target.closest("[data-act]");
  if (!btn) return;
  const act = btn.dataset.act;
  const id = btn.dataset.id;
  if (act === "enter") {
    switchSlot(id);
    return;
  }
  if (act === "rename") {
    renameId = id;
    pending = null;
    render();
    return;
  }
  if (act === "cancel-rename") {
    renameId = null;
    render();
    return;
  }
  if (act === "apply-rename") {
    const input = overlay.querySelector(`.save-rename-input[data-id="${id}"]`);
    renameSlot(id, input?.value || "");
    renameId = null;
    render();
    syncSaveButtons();
    return;
  }
  if (act === "ask-delete") {
    renameId = null;
    pending = { type: "delete", id, name: btn.dataset.name || "该档案" };
    render();
  }
}

function onKeydown(e) {
  if (e.key === "Escape") {
    if (pending || renameId) {
      pending = null;
      renameId = null;
      render();
    } else {
      closeSavePanel();
    }
    return;
  }
  if (e.key !== "Enter") return;
  if (e.target.classList?.contains("save-rename-input")) {
    renameSlot(e.target.dataset.id, e.target.value || "");
    renameId = null;
    render();
    syncSaveButtons();
    return;
  }
  if (e.target.id === "save-new-name") {
    pending = { type: "create", name: e.target.value || "" };
    renameId = null;
    render();
  }
}

function onFootClick(e) {
  const btn = e.target.closest("[data-act]");
  if (!btn) return;
  const act = btn.dataset.act;
  if (act === "ask-create") {
    const name = overlay.querySelector("#save-new-name")?.value || "";
    pending = { type: "create", name };
    renameId = null;
    render();
    return;
  }
  if (act === "cancel-pending") {
    pending = null;
    render();
    return;
  }
  if (act === "confirm-create") {
    createSlot(pending?.name);
    return;
  }
  if (act === "confirm-delete" && pending?.id) {
    deleteSlot(pending.id);
    pending = null;
    render();
    syncSaveButtons();
  }
}

export function syncSaveButtons() {
  const slot = activeSlot();
  const brand = document.getElementById("btn-saves");
  if (brand) brand.textContent = slot ? `档案 · ${slot.name}` : "档案";
}

export function initSaveUI(options) {
  hooks = { ...hooks, ...options };
  buildOverlay();
  syncSaveButtons();
}

export function openSavePanel() {
  if (!overlay || (hooks.canOpen && !hooks.canOpen())) return;
  pending = null;
  renameId = null;
  overlay.hidden = false;
  render();
}

export function closeSavePanel() {
  if (overlay) overlay.hidden = true;
  pending = null;
  renameId = null;
}

export function isSavePanelOpen() {
  return !!overlay && !overlay.hidden;
}
