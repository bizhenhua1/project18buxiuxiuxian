/** 天赋树面板：SVG 放射树，点选加点/退点，洗髓，悟性统计。 */

import {
  TREE_NODES,
  TREE_EDGES,
  allocatedIds,
  talentPoints,
  spentPoints,
  canAllocate,
  allocate,
  deallocate,
  respec,
  getNode,
} from "./talents.js?v=dao7";

const BRANCH_COLORS = {
  root: "#e6c46a",
  体修: "#d98a6a",
  法修: "#7ab7d9",
  器道: "#c9a54f",
  御兽: "#8fce8a",
};

let overlay = null;
let hooks = { getStage: () => 0, onChange: () => {} };

/* 视图（缩放/平移）状态：模块级保存，render 重建 innerHTML 不影响 svg 自身的 viewBox，
   面板重开/加点重渲染均保留上次视角。 */
const DEFAULT_VIEW = { x: -360, y: -352, w: 720, h: 704 };
const MIN_W = DEFAULT_VIEW.w / 2.5; // 最大放大 2.5×
const MAX_W = DEFAULT_VIEW.w / 0.5; // 最小缩小 0.5×
let view = { ...DEFAULT_VIEW };
let suppressClick = false;

function nodeRadius(kind) {
  if (kind === "keystone") return 19;
  if (kind === "notable") return 14;
  if (kind === "root") return 15;
  return 10;
}

function buildOverlay() {
  overlay = document.createElement("div");
  overlay.className = "dao-overlay";
  overlay.hidden = true;
  overlay.innerHTML = `
    <div class="dao-frame talent-frame">
      <header class="dao-head">
        <h2>道途天赋</h2>
        <span class="dao-points" id="talent-points"></span>
        <button type="button" class="btn dao-respec" id="talent-respec">洗髓（免费重置）</button>
        <button type="button" class="btn dao-view-reset" id="talent-view-reset">复位视图</button>
        <button type="button" class="btn dao-close" id="talent-close">✕</button>
      </header>
      <div class="dao-body talent-body">
        <svg id="talent-svg" viewBox="-360 -352 720 704" preserveAspectRatio="xMidYMid meet"></svg>
      </div>
      <footer class="dao-foot" id="talent-info">悬停节点查看说明；点击加点，再点已点的末梢节点可退点。滚轮缩放，拖拽平移。</footer>
    </div>
  `;
  document.body.appendChild(overlay);
  overlay.addEventListener("pointerdown", (e) => {
    if (e.target === overlay) close();
  });
  overlay.querySelector("#talent-close").addEventListener("click", close);
  overlay.querySelector("#talent-respec").addEventListener("click", () => {
    respec();
    hooks.onChange();
    render();
  });
  overlay.querySelector("#talent-view-reset").addEventListener("click", () => {
    view = { ...DEFAULT_VIEW };
    applyView();
  });
  bindViewControls(overlay.querySelector("#talent-svg"));
}

function applyView() {
  const svg = overlay.querySelector("#talent-svg");
  svg.setAttribute("viewBox", `${view.x} ${view.y} ${view.w} ${view.h}`);
}

function clientToSvg(svg, clientX, clientY) {
  const ctm = svg.getScreenCTM();
  if (!ctm) return null;
  return new DOMPoint(clientX, clientY).matrixTransform(ctm.inverse());
}

function bindViewControls(svg) {
  // 滚轮缩放（触控板双指捏合表现为 ctrlKey+wheel，同样走这里）
  svg.addEventListener("wheel", (e) => {
    e.preventDefault();
    const p = clientToSvg(svg, e.clientX, e.clientY);
    if (!p) return;
    const factor = Math.exp(-e.deltaY * (e.ctrlKey ? 0.01 : 0.0018));
    const targetW = Math.min(MAX_W, Math.max(MIN_W, view.w / factor));
    const z = view.w / targetW;
    view.x = p.x - (p.x - view.x) / z;
    view.y = p.y - (p.y - view.y) / z;
    view.w = targetW;
    view.h = targetW * (DEFAULT_VIEW.h / DEFAULT_VIEW.w);
    applyView();
  }, { passive: false });

  // 拖拽平移：移动超过 5px 才算拖拽，拖拽结束后拦截随之而来的 click，避免误触加点
  let drag = null;
  svg.addEventListener("pointerdown", (e) => {
    if (e.button !== 0) return;
    const ctm = svg.getScreenCTM();
    if (!ctm) return;
    suppressClick = false;
    drag = {
      id: e.pointerId,
      cx: e.clientX,
      cy: e.clientY,
      vx: view.x,
      vy: view.y,
      unitsPerPx: 1 / ctm.a,
      moved: false,
    };
    // 不能在 pointerdown 就 setPointerCapture：指针被 svg 捕获后，浏览器把后续
    // pointerup 与合成的 click 都重定向到捕获元素（svg），节点上的 click 监听
    // 永远收不到——表现为"点天赋节点没反应"。改为拖拽真正启动（≥5px）时再捕获。
  });
  svg.addEventListener("pointermove", (e) => {
    if (!drag || e.pointerId !== drag.id) return;
    const dx = e.clientX - drag.cx;
    const dy = e.clientY - drag.cy;
    if (!drag.moved && Math.hypot(dx, dy) < 5) return;
    if (!drag.moved) {
      try {
        svg.setPointerCapture(e.pointerId);
      } catch { /* 合成事件的 pointerId 未注册时会抛错，忽略 */ }
    }
    drag.moved = true;
    svg.classList.add("dragging");
    view.x = drag.vx - dx * drag.unitsPerPx;
    view.y = drag.vy - dy * drag.unitsPerPx;
    applyView();
  });
  const endDrag = (e) => {
    if (!drag || e.pointerId !== drag.id) return;
    if (drag.moved) suppressClick = true;
    drag = null;
    svg.classList.remove("dragging");
  };
  svg.addEventListener("pointerup", endDrag);
  svg.addEventListener("pointercancel", endDrag);
  // 捕获阶段拦截，先于节点上的 click 监听器执行
  svg.addEventListener("click", (e) => {
    if (suppressClick) {
      suppressClick = false;
      e.stopPropagation();
      e.preventDefault();
    }
  }, true);
}

function branchLabelHtml() {
  return `
    <text class="tbranch" x="-235" y="-320">体修 · 三头六臂</text>
    <text class="tbranch" x="235" y="-320" text-anchor="end">法修 · 万法周天</text>
    <text class="tbranch" x="-235" y="336">器道 · 万宝归宗</text>
    <text class="tbranch" x="235" y="336" text-anchor="end">御兽 · 万兽山河</text>
  `;
}

function render() {
  const svg = overlay.querySelector("#talent-svg");
  const stage = hooks.getStage();
  const alloc = allocatedIds();
  const total = talentPoints(stage);
  const left = total - spentPoints();

  const pointsEl = overlay.querySelector("#talent-points");
  pointsEl.textContent = `悟性 剩余 ${left} / 共 ${total}（每路点+1，Boss 额外+1）`;

  const nodeById = new Map(TREE_NODES.map((n) => [n.id, n]));
  const edges = TREE_EDGES.map(([a, b]) => {
    const na = nodeById.get(a);
    const nb = nodeById.get(b);
    const on = alloc.has(a) && alloc.has(b);
    const half = alloc.has(a) || alloc.has(b);
    return `<line x1="${na.x}" y1="${na.y}" x2="${nb.x}" y2="${nb.y}" class="tedge${on ? " on" : half ? " half" : ""}" />`;
  }).join("");

  const nodes = TREE_NODES.map((n) => {
    const r = nodeRadius(n.kind);
    const on = alloc.has(n.id);
    const avail = !on && canAllocate(n.id, stage);
    const color = BRANCH_COLORS[n.branch] || "#ccc";
    const cls = `tnode ${n.kind}${on ? " on" : avail ? " avail" : " locked"}`;
    const label = n.kind === "small"
      ? ""
      : `<text class="tlabel" x="${n.x}" y="${n.y + r + 13}" text-anchor="middle">${n.name}</text>`;
    return `
      <g class="${cls}" data-id="${n.id}" style="--bc:${color}">
        <circle cx="${n.x}" cy="${n.y}" r="${r}" />
        ${n.kind === "keystone" ? `<circle class="tks-ring" cx="${n.x}" cy="${n.y}" r="${r + 4.5}" />` : ""}
        ${label}
      </g>
    `;
  }).join("");

  svg.innerHTML = edges + nodes + branchLabelHtml();
  applyView(); // innerHTML 重建后恢复当前视角（模块级 view）

  for (const g of svg.querySelectorAll(".tnode")) {
    const id = g.dataset.id;
    g.addEventListener("click", () => {
      const node = getNode(id);
      if (!node || node.kind === "root") return;
      if (allocatedIds().has(id)) {
        if (!deallocate(id)) {
          setInfo(`「${node.name}」不可退点：会切断后续节点与道基的连接`, true);
          return;
        }
      } else if (!allocate(id, hooks.getStage())) {
        const reason = talentPoints(hooks.getStage()) - spentPoints() <= 0 ? "悟性不足（推关获得）" : "需与已点节点相邻";
        setInfo(`「${node.name}」无法点亮：${reason}`, true);
        return;
      }
      hooks.onChange();
      render();
    });
    g.addEventListener("pointerenter", () => {
      const node = getNode(id);
      if (node) setInfo(`【${node.name}】${node.kind === "keystone" ? "（道果）" : node.kind === "notable" ? "（大节点）" : ""} ${node.desc}`);
    });
  }
}

function setInfo(text, warn = false) {
  const el = overlay.querySelector("#talent-info");
  el.textContent = text;
  el.classList.toggle("warn", warn);
}

export function initTalentUI(options) {
  hooks = { ...hooks, ...options };
  buildOverlay();
}

export function openTalentPanel() {
  if (!overlay) return;
  overlay.hidden = false;
  render();
}

export function close() {
  if (overlay) overlay.hidden = true;
}

export function isTalentPanelOpen() {
  return !!overlay && !overlay.hidden;
}
