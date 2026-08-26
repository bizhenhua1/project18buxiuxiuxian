/**
 * 法宝飞行道具：按类型用正式立绘，不再共用一颗 CSS 光点。
 * 成品在 assets/style-e/style-e-proj-*.png（品红底抠透明）。
 */

import { assetUrl } from "./assets.js?v=dao13";

const VER = "proj1";

function projArt(id) {
  return assetUrl(`assets/style-e/style-e-proj-${id}.png`, VER);
}

/** 类型规格：size 为弹道像素边长；rotate 跟飞行角；spin 自转。 */
export const PROJ_TYPES = {
  sword: { id: "sword", art: projArt("sword"), size: 40, rotate: true },
  heavysword: { id: "heavysword", art: projArt("heavysword"), size: 46, rotate: true },
  axe: { id: "axe", art: projArt("axe"), size: 44, rotate: true },
  seal: { id: "seal", art: projArt("seal"), size: 34, rotate: false, spin: true },
  rope: { id: "rope", art: projArt("rope"), size: 36, rotate: true },
  mirror: { id: "mirror", art: projArt("mirror"), size: 30, rotate: false, spin: true },
  gourd: { id: "gourd", art: projArt("gourd"), size: 32, rotate: false },
  fan: { id: "fan", art: projArt("fan"), size: 40, rotate: true },
};

/** 卡牌 id → 飞行道具类型。未登记的仍走 CSS 占位弹。 */
export const CARD_PROJ = {
  "taomu-jian": "sword",
  "qingfeng-jian": "sword",
  "xuantie-jian": "heavysword",
  "kaishan-fu": "axe",
  "waci-yin": "seal",
  "masuo": "rope",
  "tongjing": "mirror",
  "xiaohulu": "gourd",
  "juhun-fan": "fan",
};

export function projForCard(cardId) {
  const type = CARD_PROJ[cardId];
  return type ? PROJ_TYPES[type] : null;
}
