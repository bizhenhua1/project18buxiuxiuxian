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
} from "./talents.js?v=dao1";

const BRANCH_COLORS = {
  root: "#e6c46a",
  体修: "#d98a6a",
  法修: "#7ab7d9",
  器道: "#c9a54f",
  御兽: "#8fce8a",
};

let overlay = null;
let hooks = { getStage: () => 0, onChange: () => {} };

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
        <button type="button" class="btn dao-close" id="talent-close">✕</button>
      </header>
      <div class="dao-body talent-body">
        <svg id="talent-svg" viewBox="-360 -352 720 704" preserveAspectRatio="xMidYMid meet"></svg>
      </div>
      <footer class="dao-foot" id="talent-info">悬停节点查看说明；点击加点，再点已点的末梢节点可退点。</footer>
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
