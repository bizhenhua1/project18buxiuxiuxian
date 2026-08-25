/**
 * 主角境界等级系统（经典修仙体系）。
 *
 * - 大境界 × 9 层：炼气 → 筑基 → 金丹 → 元婴 → 化神（STAGES 预留炼虚/合体/大乘/渡劫扩展位）
 * - 修为来源：击杀敌方单位（killExp = ⌈有效血量/10⌉，Boss 关整单 ×3），胜利结算时入账
 * - 层内攒满自动升层；9 层圆满后修为停止累积，需点「突破」进入下一大境界第 1 层
 * - 收益（只作用于道童，走 mods 聚合管线）：每层攻/血 ×1.02 复利；每次突破额外 ×1.10 且 +1 悟性点
 * - 存档 localStorage `dao-realm-v1`，加载时钳制污染值（负数/超界/NaN）
 */

const STORE_KEY = "dao-realm-v1";

/** 大境界表：前 ACTIVE_STAGES 个可达，其余为数据结构扩展位（第一版化神圆满即封顶）。 */
export const REALM_STAGES = ["炼气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"];
export const ACTIVE_STAGES = 5;
export const LAYERS_PER_STAGE = 9;

/** 升层需求曲线：need = BASE × BREAK_MULT^大境界 × GROWTH^全局层序（前期几关一层，后期明显放缓）。 */
export const EXP_BASE = 30;
export const EXP_GROWTH = 1.15;
export const BREAK_BASE_MULT = 2;

/** 收益：每层攻/血 +2%（复利），突破大境界额外 +10%（复利）+1 悟性点。 */
export const LAYER_GAIN_PCT = 2;
export const BREAK_GAIN_PCT = 10;

const CN_NUM = ["一", "二", "三", "四", "五", "六", "七", "八", "九"];

/** 某大境界第 layer 层（0 基）升下一层所需修为。 */
export function needFor(stage, layer) {
  const globalLayer = stage * LAYERS_PER_STAGE + layer;
  return Math.round(EXP_BASE * BREAK_BASE_MULT ** stage * EXP_GROWTH ** globalLayer);
}

// stage/layer 0 基（显示 +1）；exp 为当前层内修为；totalExp 为累计入账修为（圆满溢出的不计）
let realm = { stage: 0, layer: 0, exp: 0, totalExp: 0 };

function clampInt(v, lo, hi, dflt = lo) {
  const n = Math.floor(Number(v));
  if (!Number.isFinite(n)) return dflt;
  return Math.max(lo, Math.min(hi, n));
}

/** 加载钳制：大境界/层/修为全部收回合法区间，层内修为不越过当前层需求。 */
function load() {
  try {
    const raw = JSON.parse(localStorage.getItem(STORE_KEY) || "null");
    if (raw) {
      const stage = clampInt(raw.stage, 0, ACTIVE_STAGES - 1, 0);
      const layer = clampInt(raw.layer, 0, LAYERS_PER_STAGE - 1, 0);
      const exp = clampInt(raw.exp, 0, needFor(stage, layer), 0);
      const totalExp = clampInt(raw.totalExp, 0, Number.MAX_SAFE_INTEGER, 0);
      realm = { stage, layer, exp, totalExp };
      // 非圆满层不允许 exp 恰好等于需求（应已升层）：多出的钳掉
      if (!isFull() && realm.exp >= needFor(stage, layer)) realm.exp = needFor(stage, layer) - 1;
    }
  } catch { /* 损坏则从炼气一层开始 */ }
}

function save() {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(realm));
  } catch { /* 静默 */ }
}

load();

/** 圆满：大境界第 9 层且修为攒满（停止累积，待突破）。 */
export function isFull() {
  return realm.layer === LAYERS_PER_STAGE - 1 && realm.exp >= needFor(realm.stage, realm.layer);
}

/** 击杀单个敌方单位的修为：有效血量 ÷10 向上取整（Boss 关整单 ×3 由结算方乘）。 */
export function killExp(maxHp) {
  return Math.max(1, Math.ceil((maxHp || 0) / 10));
}

/**
 * 修为入账：层内攒满自动升层（可连升），圆满后封顶不再累积。
 * 返回 { gained, levels, full }。
 */
export function addExp(amount) {
  const n = Math.max(0, Math.floor(Number(amount) || 0));
  if (n <= 0 || isFull()) return { gained: 0, levels: 0, full: isFull() };
  let left = n;
  let absorbed = 0;
  let levels = 0;
  while (left > 0) {
    const need = needFor(realm.stage, realm.layer);
    const room = need - realm.exp;
    if (realm.layer === LAYERS_PER_STAGE - 1) {
      // 第 9 层：只灌到圆满封顶，溢出丢弃
      const take = Math.min(left, room);
      realm.exp += take;
      absorbed += take;
      left = 0;
      break;
    }
    if (left < room) {
      realm.exp += left;
      absorbed += left;
      left = 0;
    } else {
      absorbed += room;
      left -= room;
      realm.exp = 0;
      realm.layer += 1;
      levels += 1;
    }
  }
  realm.totalExp += absorbed;
  save();
  return { gained: absorbed, levels, full: isFull() };
}

/** 是否可突破：圆满且下一大境界在可达范围内（第一版化神封顶）。 */
export function canBreakthrough() {
  return isFull() && realm.stage + 1 < ACTIVE_STAGES;
}

/** 突破：立即成功进入下一大境界第 1 层（第一版无失败/天劫）。 */
export function breakthrough() {
  if (!canBreakthrough()) return false;
  realm.stage += 1;
  realm.layer = 0;
  realm.exp = 0;
  save();
  return true;
}

/** 突破次数 = 当前大境界序号（talentPoints 的悟性加点来源）。 */
export function breakthroughCount() {
  return realm.stage;
}

/** 境界称号：如「炼气三层」「筑基圆满」。 */
export function realmTitle() {
  return `${REALM_STAGES[realm.stage]}${isFull() ? "圆满" : `${CN_NUM[realm.layer]}层`}`;
}

/** mods 来源（与天赋/装备合并）：层数与突破数计数，applyPlayerMods 对道童做复利乘算。 */
export function realmMods() {
  return {
    realmLayers: realm.stage * LAYERS_PER_STAGE + realm.layer,
    realmBreaks: realm.stage,
  };
}

/** UI/调试快照。 */
export function realmState() {
  return {
    stage: realm.stage,
    layer: realm.layer,
    exp: realm.exp,
    need: needFor(realm.stage, realm.layer),
    totalExp: realm.totalExp,
    full: isFull(),
    canBreak: canBreakthrough(),
    title: realmTitle(),
  };
}

/** 调试/验收用：清回炼气一层。 */
export function resetRealm() {
  realm = { stage: 0, layer: 0, exp: 0, totalExp: 0 };
  save();
}
