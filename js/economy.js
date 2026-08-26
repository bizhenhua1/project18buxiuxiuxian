/**
 * 灵石货币：任务完成、区域刷取与挂机补领的通用代币。
 * 存档 localStorage `dao-coins-v1`。本期只发放、不消耗。
 */

const STORE_KEY = "dao-coins-v1";

let coins = 0;

function load() {
  try {
    const raw = JSON.parse(localStorage.getItem(STORE_KEY) || "null");
    const n = Math.floor(Number(raw?.coins));
    coins = Number.isFinite(n) && n > 0 ? n : 0;
  } catch { /* 损坏则从 0 开始 */ }
}

function save() {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify({ coins }));
  } catch { /* 静默 */ }
}

load();

export function coinBalance() {
  return coins;
}

export function addCoins(amount) {
  const n = Math.floor(Number(amount) || 0);
  if (n <= 0) return 0;
  coins += n;
  save();
  return n;
}

export function renderCoins() {
  const el = document.getElementById("coin-num");
  if (el) el.textContent = String(coins);
}
