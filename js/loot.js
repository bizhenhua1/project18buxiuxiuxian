/**
 * 掉落与收服：胜利结算时调用。
 * - 普通路点：60% 掉 1 件装备（气运提升概率与品质）
 * - Boss 路点：保底 1 件 ≥灵品，并额外 35% 再掉 1 件
 * - 收服：本场每击杀 1 只敌方妖兽，独立掷收服（基础 10% + 天赋/词条）
 */

import { makeItem } from "./equipment.js?v=dao11";

const BEAST_KEY = "dao-beasts-v1";

export function rollLoot(stage, boss, luckPct = 0) {
  const items = [];
  if (boss) {
    items.push(makeItem({ stage, luckPct, minTier: 1 }));
    if (Math.random() < 0.35 + luckPct / 200) items.push(makeItem({ stage, luckPct }));
  } else if (Math.random() < 0.6 + luckPct / 250) {
    items.push(makeItem({ stage, luckPct }));
  }
  return items;
}

/** 每只被击杀妖兽独立掷收服，返回收服成功的 cardId 列表。 */
export function rollCaptures(killedIds, capturePct = 0) {
  const caught = [];
  const chance = Math.min(0.75, 0.10 + capturePct / 100);
  for (const id of killedIds || []) {
    if (Math.random() < chance) caught.push(id);
  }
  return caught;
}

// ---------------------------------------------------------------------------
// 御兽收藏（localStorage）
// ---------------------------------------------------------------------------

let beasts = {};

function loadBeasts() {
  try {
    const raw = JSON.parse(localStorage.getItem(BEAST_KEY) || "null");
    if (raw && typeof raw === "object") beasts = raw;
  } catch { /* 损坏则重置 */ }
}
loadBeasts();

function saveBeasts() {
  try {
    localStorage.setItem(BEAST_KEY, JSON.stringify(beasts));
  } catch { /* 静默 */ }
}

export function ownedBeasts() {
  return { ...beasts };
}

export function beastCount(cardId) {
  return beasts[cardId] || 0;
}

export function addBeast(cardId) {
  beasts[cardId] = (beasts[cardId] || 0) + 1;
  saveBeasts();
}
