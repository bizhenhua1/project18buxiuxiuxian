/** 关卡/大区进度。中段场景是纸片走廊，不再把路点画进地图。 */

import { fmtMult, monsterMult } from "./balance.js?v=dao7";

export const NODES_PER_REGION = 8;

export const REGIONS = [
  {
    id: "qingjin",
    name: "青金仙途",
    nodes: [
      { x: 7.2, y: 54 },
      { x: 18.5, y: 63 },
      { x: 30.5, y: 49 },
      { x: 42.5, y: 41 },
      { x: 54.5, y: 48 },
      { x: 67, y: 37 },
      { x: 80, y: 53 },
      { x: 92.5, y: 43 },
    ],
  },
  {
    id: "dansha",
    name: "丹砂夜岭",
    nodes: [
      { x: 9.5, y: 49 },
      { x: 21.5, y: 41 },
      { x: 33.5, y: 52 },
      { x: 45.5, y: 44 },
      { x: 57.5, y: 54 },
      { x: 70, y: 39 },
      { x: 82.5, y: 47 },
      { x: 93.5, y: 37 },
    ],
  },
];

export function regionIndexOf(stage) {
  return Math.floor(Math.max(0, stage) / NODES_PER_REGION) % REGIONS.length;
}

export function nodeIndexOf(stage) {
  return Math.max(0, stage) % NODES_PER_REGION;
}

export function regionOf(stage) {
  return REGIONS[regionIndexOf(stage)];
}

export function regionStartOf(stage) {
  return Math.floor(Math.max(0, stage) / NODES_PER_REGION) * NODES_PER_REGION;
}

export function stageAtNode(stage, nodeIndex) {
  return regionStartOf(stage) + nodeIndex;
}

export function setMapNodesPickable() {
  /* 走廊场景不再放置可点路点 */
}

export function renderMap(state, corridor) {
  const title = document.getElementById("map-region-label");
  const region = regionOf(state.unlockStage);
  const frontier = nodeIndexOf(state.unlockStage);
  const focusStage = Number.isFinite(state.focusStage) ? state.focusStage : state.unlockStage;
  const sameRegion = regionIndexOf(focusStage) === regionIndexOf(state.unlockStage);
  const focusNode = sameRegion ? nodeIndexOf(focusStage) : frontier;
  const loop = Math.floor(Math.max(0, state.unlockStage) / NODES_PER_REGION);
  const loopTag = loop >= REGIONS.length ? ` · 循环 ${Math.floor(loop / REGIONS.length) + 1}` : "";
  const mm = monsterMult(focusStage);
  const boss = mm.boss ? " · Boss" : "";

  if (title) {
    title.textContent = `${region.name} · 路点 ${focusNode + 1}/${NODES_PER_REGION}${boss}${loopTag}`;
  }

  corridor?.syncFromState?.(state);
}
