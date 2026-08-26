/**
 * 时间挂机：页签打开时按分钟滴漏保底收益；关闭/后台节流后，
 * 下次恢复按离开时所在区域换算补领。不推进任务、不模拟战斗。
 * 存档 localStorage `dao-idle-v1`。
 */

import { BALANCE } from "./balance.js?v=dao13";

const STORE_KEY = "dao-idle-v1";

export const IDLE = {
  /** 离线补领封顶：8 小时 */
  maxOfflineMs: 8 * 3600 * 1000,
  /** 在线滴漏最短间隔，避免每帧入账 */
  minClaimMs: 15 * 1000,
  expPerMin: 10,
  coinsPerMin: 6,
  /** 大约每 N 分钟掷一次保底掉落 */
  lootEveryMin: 4,
  maxLootRolls: 6,
};

let accruedAt = 0;

function load() {
  try {
    const raw = JSON.parse(localStorage.getItem(STORE_KEY) || "null");
    const ts = Math.floor(Number(raw?.accruedAt));
    accruedAt = Number.isFinite(ts) && ts > 0 ? ts : Date.now();
  } catch {
    accruedAt = Date.now();
  }
}

function save() {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify({ accruedAt }));
  } catch { /* 静默 */ }
}

load();

export function idleRates(areaIndex) {
  const g = BALANCE.regionGrowth ** Math.max(0, areaIndex | 0);
  return {
    expPerMin: Math.max(1, Math.round(IDLE.expPerMin * g)),
    coinsPerMin: Math.max(1, Math.round(IDLE.coinsPerMin * g)),
    lootEveryMin: IDLE.lootEveryMin,
  };
}

export function previewIdle(ms, areaIndex) {
  const capped = Math.max(0, Math.min(IDLE.maxOfflineMs, Math.floor(Number(ms) || 0)));
  const minutes = capped / 60000;
  const rates = idleRates(areaIndex);
  const lootRolls = Math.min(IDLE.maxLootRolls, Math.floor(minutes / rates.lootEveryMin));
  return {
    ms: capped,
    minutes,
    exp: Math.floor(rates.expPerMin * minutes),
    coins: Math.floor(rates.coinsPerMin * minutes),
    lootRolls,
    rates,
    capped: Math.floor(Number(ms) || 0) > IDLE.maxOfflineMs,
  };
}

export function idleAccruedAt() {
  return accruedAt;
}

export function touchIdle(now = Date.now()) {
  accruedAt = Math.max(accruedAt, Math.floor(now));
  save();
}

/**
 * 领取 [accruedAt, now] 区间的挂机收益，并把水位推到 now。
 * 不足 minClaimMs 时不领（首屏离线补领可传 force=true）。
 */
export function claimIdle(now = Date.now(), areaIndex = 0, force = false) {
  const ts = Math.floor(now);
  if (!accruedAt) {
    accruedAt = ts;
    save();
    return null;
  }
  const elapsed = ts - accruedAt;
  if (elapsed < (force ? 1000 : IDLE.minClaimMs)) return null;
  const preview = previewIdle(elapsed, areaIndex);
  accruedAt = ts;
  save();
  if (preview.exp <= 0 && preview.coins <= 0 && preview.lootRolls <= 0) return null;
  return preview;
}
