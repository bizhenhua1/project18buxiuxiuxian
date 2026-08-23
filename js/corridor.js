/**
 * 森林走廊：单 <canvas> 画家算法伪 3D。
 * 针孔投影 sx = cx + x*f/z，远→近排序绘制；
 * 深度压暗 = 每帧按相机相对深度画"本体 + 黑剪影(连续 alpha)"两笔，
 * 完全连续无台阶；雾带只垫在所有精灵之下（纯地面/天空氛围，永不盖精灵）；
 * 静止时零重绘。
 */

export const CORRIDOR_VERSION = "canvas25";
export const CORRIDOR_BASE = "assets/corridor/forest/";
export const STAGE_STEP = 420;

/* ---- 世界参数（世界单位） ---- */
const Z_NEAR = 26;          // 初始铺设的近端
const Z_EXIT = 9;           // 比这更近才回收：确保精灵先滑出画框再消失
const Z_FAR = 2100;         // 生成远端（> CULL_Z：新精灵生成时必然在剔除区内，不可见）

/* ---- 可调场景参数（场景参数编辑器实时读写，localStorage 持久化） ---- */
export const CORRIDOR_DEFAULTS = Object.freeze({
  curveA1: 210,      // 主弯幅度（世界单位）
  curveL1: 1250,     // 主弯波长
  curveA2: 90,       // 次弯幅度
  curveL2: 470,      // 次弯波长
  curveLook: 40,     // 相机向前看的距离（入弯时视线略偏弯内）
  pathHalf: 55,      // 道路半宽
  treeDensity: 1,    // 树密度倍率（缩放各车道 z 间距）
  treeSize: 1,       // 树体型倍率
  grassCount: 95,    // 高草散铺数量
  lowCount: 70,      // 路面低草散铺数量
  flower: 1,         // 花变体权重倍率（0=纯草地）
  fogStart: 240,     // 深度压暗起点
  fogEnd: 1450,      // 完全压黑距离
  camH: 58,          // 相机离地高
  focalMult: 1.12,   // 焦距 = 画幅高 × 此倍率
  horizonFrac: 0.56, // 地平线在画幅中的高度占比
  cloudCount: 10,    // 云数量
  cloudSize: 1,      // 云尺寸倍率
  cloudParallax: 0.12, // 云视差因子（相对树/草的逼近速度）
  cloudWind: 5,      // 云的独立横向风速（世界单位/秒，正=向右；与推进无关）
  skyBright: 1,      // 天空亮度（0=纯黑夜空）
  skyType: -1,       // 天空预设下标（见 SKY_PRESETS；-1 = 随昼夜时钟自动过渡）
  ambient: 1,        // 环境光强度倍率（0=关闭全局氛围着色）
  dayStart: 9,       // 起始时刻（小时，0~24；每推一关 +2h）
  sunSize: 1,        // 日月尺寸倍率
  bob: 1,            // 行进镜头起伏幅度倍率（0=关闭）
});
const PARAM_STORE = "corridor-params-v2";
const P = { ...CORRIDOR_DEFAULTS };
try {
  const saved = JSON.parse(localStorage.getItem(PARAM_STORE) || "{}");
  for (const k in saved) {
    if (k in P && typeof saved[k] === "number" && Number.isFinite(saved[k])) P[k] = saved[k];
  }
} catch { /* 本地存档损坏则用默认值 */ }

/* 派生量：绘制热路径直接读这些变量，编辑器改动后由 applyDerived() 刷新。 */
let CAM_H = 58;
let FOG_START = 240;
let FOG_END = 1450;
let FADE_START = 1150;   // 最后一段深度做 per-sprite alpha 淡入，杜绝跳变
let CULL_Z = 1450;       // 淡到 alpha=0 处即剔除
let PATH_HALF = 55;
let CLOUD_PARALLAX = 0.12;
function applyDerived() {
  CAM_H = P.camH;
  FOG_START = P.fogStart;
  FOG_END = Math.min(Z_FAR - 100, Math.max(P.fogStart + 250, P.fogEnd));
  FADE_START = FOG_END - 300;
  CULL_Z = FOG_END;
  PATH_HALF = P.pathHalf;
  CLOUD_PARALLAX = P.cloudParallax;
}
applyDerived();

/* 路径弯曲：世界 z → 道路中心的横向偏移（双正弦叠加，连续平滑）。
 * 所有地面物件按各自世界 z 加偏移、相机跟随自己脚下的偏移，
 * 远处的路便会左右摆出弯道（伪 3D 赛车的经典手法）。 */
function pathOffset(z) {
  return P.curveA1 * Math.sin(z / Math.max(1, P.curveL1) + 0.7)
       + P.curveA2 * Math.sin(z / Math.max(1, P.curveL2) + 2.3);
}

/* 树车道：最外→内五条，最外圈用巨树专门封死超宽画幅的两侧与上角，
 * 路中央保持通透。step 收紧 + 抖动降幅，避免随机聚簇后留出可见缝隙。 */
const TREE_LANES = [
  { baseX: 560, spreadX: 120, size: 310, step: 30 },
  { baseX: 392, spreadX: 105, size: 252, step: 26 },
  { baseX: 268, spreadX: 85, size: 210, step: 34 },
  { baseX: 182, spreadX: 55, size: 178, step: 38 },
  { baseX: 122, spreadX: 32, size: 148, step: 50 },
];

/* ---- 天空层 / 云朵 / Mode-7 地面 / 密草条带参数 ---- */
/* 远山：静止背景（不随相机平移，只被雾带压暗）。 */
const SKY_LAYERS = [
  { name: "mtn-far.png", dim: 0.55 },
  { name: "mtn-near.png", dim: 0.4 },
];
/* 祥云：作为世界精灵挂在高空，随前进迎面靠近、放大、掠过头顶。
 * 云极远，视差因子（P.cloudParallax）让它相对树/草以极慢速度逼近。 */
const CLOUD_IMAGE = "cloud-strip.png";
/* 日月：沿"左起右落"圆弧运行的天体。时钟挂在 camZ 上——
 * 每前进一个 STAGE_STEP（一次推关）= +2 小时，12 关一个昼夜循环。
 * 6:00–18:00 太阳，18:00–次日 6:00 月亮。 */
const SUN_IMAGE = "sun.png";
const MOON_IMAGE = "moon.png";
/* 天空：程序驱动的垂直渐变（无素材）。每个预设 = 一组色标（0=画幅顶，1=地平线）
 * + 联动系数：
 *   haze     —— 大气雾霾色：远山/远云的距离衰减、地平线以上的雾带都往这个
 *               颜色融（晴天=亮天光青，夜空≈黑）。黑暗只属于通道内部——
 *               远树/地面仍按黑压暗，隧道尽头的黑暗恒在；
 *   cloudCap —— 云被雾霾色淡化的上限（天越亮上限越低）；
 *   mtnCap   —— 远山被雾霾色淡化的上限（同理）；
 *   fogUp    —— 雾带向上延伸的收缩系数（天越亮雾带越矮，山峰从雾里露出来）；
 *   amb      —— 环境光 [颜色, 强度]：帧末对整个画面做 multiply 着色，
 *               树/草/花/地面全局受氛围影响（夜晚变冷变暗、黄昏染暖橙、
 *               恐怖蒙病态红）。乘法混合下黑仍是黑，尽头的黑暗不受影响。 */
const SKY_PRESETS = [
  { name: "夜空", haze: "#0d1730", cloudCap: 0.6, mtnCap: 0.42, fogUp: 0.62, amb: ["#7d90c4", 0.5], stops: [[0, "#243a5f"], [0.5, "#1a2d55"], [0.85, "#142446"], [1, "#0e1a34"]] },
  { name: "晴天", haze: "#a9c4d6", cloudCap: 0.35, mtnCap: 0.45, fogUp: 0.55, amb: ["#fff3dd", 0.2], stops: [[0, "#3d6ea6"], [0.5, "#6f9cc4"], [0.85, "#a9c6d8"], [1, "#8fb2c4"]] },
  { name: "阴天", haze: "#43494c", cloudCap: 0.45, mtnCap: 0.45, fogUp: 0.6, amb: ["#a9b2b6", 0.45], stops: [[0, "#6d7478"], [0.5, "#565c5f"], [0.85, "#3b4144"], [1, "#2c3134"]] },
  { name: "黄昏", haze: "#8a5230", cloudCap: 0.4, mtnCap: 0.4, fogUp: 0.55, amb: ["#f0a468", 0.45], stops: [[0, "#2e2947"], [0.45, "#5d3a45"], [0.8, "#a05c2e"], [1, "#c9822e"]] },
  { name: "恐怖", haze: "#47110d", cloudCap: 0.5, mtnCap: 0.5, fogUp: 0.6, amb: ["#b06452", 0.5], stops: [[0, "#0d0509"], [0.5, "#2a0c14"], [0.85, "#5c1512"], [1, "#8a2a12"]] },
];
/** 当前天气预设（手选模式）。 */
function skyPreset() {
  return SKY_PRESETS[Math.round(P.skyType)] || SKY_PRESETS[0];
}

/** 线性插值两个 #rrggbb 颜色。 */
function lerpHex(a, b, t) {
  const c = [1, 3, 5].map((i) => {
    const va = parseInt(a.slice(i, i + 2), 16);
    return Math.round(va + (parseInt(b.slice(i, i + 2), 16) - va) * t);
  });
  return "#" + c.map((v) => v.toString(16).padStart(2, "0")).join("");
}

/** 混合两个天空预设：色标（位置+颜色）、雾霾、环境光、联动系数全部插值。 */
function blendSky(a, b, t) {
  if (t <= 0) return a;
  if (t >= 1) return b;
  return {
    name: a.name + "→" + b.name,
    haze: lerpHex(a.haze, b.haze, t),
    cloudCap: a.cloudCap + (b.cloudCap - a.cloudCap) * t,
    mtnCap: a.mtnCap + (b.mtnCap - a.mtnCap) * t,
    fogUp: a.fogUp + (b.fogUp - a.fogUp) * t,
    amb: [lerpHex(a.amb[0], b.amb[0], t), a.amb[1] + (b.amb[1] - a.amb[1]) * t],
    stops: a.stops.map(([p, col], i) => [
      p + (b.stops[i][0] - p) * t,
      lerpHex(col, b.stops[i][1], t),
    ]),
  };
}

/** 昼夜表：时刻→预设下标的关键帧（夜→黎明染黄昏色→晴→黄昏→夜）。 */
const DAY_SCHEDULE = [
  [0, 0], [4.5, 0], [6.5, 3], [8.5, 1], [15.5, 1], [17.5, 3], [19.5, 0], [24, 0],
];
let timeSkyCache = { h: -1, p: null };
/** 时刻驱动的天空：在昼夜表相邻关键帧间平滑过渡。
 *  时刻量化到 0.05h——过渡期换色是小步进，剪影染色缓存不会每帧重烘。 */
function timeSky(hour) {
  const h = Math.round(hour * 20) / 20;
  if (timeSkyCache.h === h) return timeSkyCache.p;
  let p = SKY_PRESETS[0];
  for (let i = 0; i < DAY_SCHEDULE.length - 1; i++) {
    const [h0, i0] = DAY_SCHEDULE[i];
    const [h1, i1] = DAY_SCHEDULE[i + 1];
    if (h >= h0 && h <= h1) {
      p = i0 === i1 ? SKY_PRESETS[i0] : blendSky(SKY_PRESETS[i0], SKY_PRESETS[i1], (h - h0) / (h1 - h0));
      break;
    }
  }
  timeSkyCache = { h, p };
  return p;
}
const GROUND_TILE = "ground-tile.png";
const GROUND_TILE_WORLD = 150;  // 一块 512px 纹理对应的世界长度
const GROUND_SLICES = 48;
/* 密草条带：加载时把草印章烘进横条，行进时按世界 z 行摆放并回收 */
const STRIP_VARIANTS = 4;
const STRIP_PX_W = 2048;
const STRIP_PX_H = 176;
const STRIP_WORLD_W = 680;      // 条带纹理对应的世界宽度
const STRIP_PPW = STRIP_PX_W / STRIP_WORLD_W;
const STRIP_WORLD_H = STRIP_PX_H / STRIP_PPW;
const ROW_SPACING = 54;
/* 低草条带（路面专用）：像素密度提高 1.5 倍（近景放大不糊），
 * 条带世界高压到 30，改为每行画两遍（错半个行距）来盖满行间。 */
const LOW_STRIP_VARIANTS = 3;
const LOW_STRIP_PX_W = 3072;
const LOW_PPW = LOW_STRIP_PX_W / STRIP_WORLD_W;
const LOW_STRIP_WORLD_H = 30;
const LOW_STRIP_PX_H = Math.round(LOW_STRIP_WORLD_H * LOW_PPW);

const TREE_IMAGES = [
  { name: "tree-side.png", cache: 768 },
  { name: "tree-b.png", cache: 768 },
  { name: "tree-c.png", cache: 768 },
];
const GRASS_IMAGES = [
  { name: "grass-1.png", cache: 256 },
  { name: "grass-2.png", cache: 256 },
  { name: "grass-3.png", cache: 256 },
  { name: "grass-4.png", cache: 256 },
  { name: "foliage.png", cache: 256 },
];
/* 路面低草不用独立素材：直接复用两侧的素草/蕨位图（下标 0、3），
 * 绘制时压矮拉宽——风格与草甸完全一致，透明通道天然干净。 */
const LOW_SOURCE_VARIANTS = [0, 3];
const LOW_SQUASH_H = 0.62;   // 低草纵向压扁比
const LOW_STRETCH_W = 1.15;  // 低草横向加宽比
/* 草变体权重：素草/蕨为主，红花粉苞只做点缀，避免草甸变花海。
 * 花类（下标 1/2/4）再乘 P.flower 倍率，动态归一化。 */
const GRASS_WEIGHTS = [0.55, 0.05, 0.04, 0.28, 0.08];
const GRASS_IS_FLOWER = [false, true, true, false, true];

function pickGrassVariant(rnd) {
  let total = 0;
  const w = [];
  for (let i = 0; i < GRASS_WEIGHTS.length; i++) {
    w[i] = GRASS_WEIGHTS[i] * (GRASS_IS_FLOWER[i] ? P.flower : 1);
    total += w[i];
  }
  if (total <= 0) return 0;
  let acc = 0;
  for (let i = 0; i < w.length; i++) {
    acc += w[i] / total;
    if (rnd < acc) return i;
  }
  return 0;
}

function fract(n) {
  return n - Math.floor(n);
}
function hash(i, salt) {
  return fract(Math.sin(i * 127.1 + salt * 311.7) * 43758.5453);
}
function asset(name) {
  return `${CORRIDOR_BASE}${name}?v=${CORRIDOR_VERSION}`;
}
function loadImage(src) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = src;
  });
}

/** 扫描不透明包围盒：各 PNG 透明边距不一（树底 5%、foliage 20%），
 *  不裁掉的话“图片底边=地面”会让每类精灵落地点不一致，看起来像层级错误。 */
function alphaBBox(img) {
  const w = img.naturalWidth || img.width;
  const h = img.naturalHeight || img.height;
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  const g = c.getContext("2d");
  g.drawImage(img, 0, 0);
  const data = g.getImageData(0, 0, w, h).data;
  let x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (data[(y * w + x) * 4 + 3] > 12) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < 0) return { x: 0, y: 0, w, h };
  return { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 };
}

/** 每张图裁到不透明内容后预烘两张离屏副本：本体 + 纯黑剪影。
 *  运行时"画本体、再以连续 alpha 叠画剪影"实现任意深度的平滑压暗，
 *  零每帧 filter、零量化台阶。wFrac/hFrac = 内容占原图比例，
 *  用于把世界尺寸换算到裁剪后的绘制尺寸，保证所有精灵内容底边=地面。 */
function buildSpriteCache(img, maxSize) {
  const box = alphaBBox(img);
  const ratio = Math.min(1, maxSize / Math.max(box.w, box.h));
  const w = Math.max(1, Math.round(box.w * ratio));
  const h = Math.max(1, Math.round(box.h * ratio));
  const base = document.createElement("canvas");
  base.width = w;
  base.height = h;
  base.getContext("2d").drawImage(img, box.x, box.y, box.w, box.h, 0, 0, w, h);
  const sil = document.createElement("canvas");
  sil.width = w;
  sil.height = h;
  const gs = sil.getContext("2d");
  gs.drawImage(base, 0, 0);
  gs.globalCompositeOperation = "source-in";
  gs.fillStyle = "#000";
  gs.fillRect(0, 0, w, h);
  return {
    img: base,
    sil,
    wFrac: box.w / (img.naturalWidth || img.width),
    hFrac: box.h / (img.naturalHeight || img.height),
  };
}

/** 云带按透明列切成独立云簇（列 alpha 全空 ≥6px 视为分隔），宽度不足的碎片丢弃。 */
function sliceCloudClusters(img) {
  const w = img.naturalWidth;
  const h = img.naturalHeight;
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  const g = c.getContext("2d");
  g.drawImage(img, 0, 0);
  const data = g.getImageData(0, 0, w, h).data;
  const occupied = new Array(w).fill(false);
  for (let x = 0; x < w; x++) {
    for (let y = 0; y < h; y++) {
      if (data[(y * w + x) * 4 + 3] > 12) { occupied[x] = true; break; }
    }
  }
  const clusters = [];
  let start = -1;
  let gap = 0;
  for (let x = 0; x <= w; x++) {
    const on = x < w && occupied[x];
    if (on) {
      if (start < 0) start = x;
      gap = 0;
    } else if (start >= 0) {
      gap++;
      if (gap >= 6 || x === w) {
        const end = x - gap + 1;
        if (end - start >= 40) clusters.push([start, end]);
        start = -1;
        gap = 0;
      }
    }
  }
  return clusters.map(([x0, x1]) => {
    const cw = x1 - x0;
    const cc = document.createElement("canvas");
    cc.width = cw;
    cc.height = h;
    cc.getContext("2d").drawImage(c, x0, 0, cw, h, 0, 0, cw, h);
    return cc;
  });
}

/** 深度压暗 0..1：相机相对深度 z 经 smoothstep，连续单调、两端斜率为 0。 */
function darknessAt(z) {
  const t = (z - FOG_START) / (FOG_END - FOG_START);
  const k = t < 0 ? 0 : t > 1 ? 1 : t;
  return k * k * (3 - 2 * k);
}

/**
 * @param {HTMLElement} host
 * @param {{
 *   keyboard?: boolean,
 *   band?: boolean,
 *   autoForward?: boolean,
 *   onStatus?: (text: string) => void,
 * }} [opts]
 */
export function createCorridor(host, opts = {}) {
  if (!host) return null;

  const keyboard = !!opts.keyboard;
  const band = !!opts.band;
  const onStatus = typeof opts.onStatus === "function" ? opts.onStatus : null;

  host.innerHTML = "";
  const viewport = document.createElement("div");
  viewport.className = `corridor-viewport${band ? " band" : ""}`;
  const canvas = document.createElement("canvas");
  canvas.className = "corridor-canvas";
  viewport.appendChild(canvas);
  host.appendChild(viewport);
  const ctx = canvas.getContext("2d");

  /* ---- 场景精灵 ---- */
  const treeCaches = [];   // [variant] -> {img, sil, wFrac, hFrac}
  const grassCaches = [];
  const lowCaches = [];    // 路面低草（= 素草/蕨缓存的引用）
  const stripCaches = [];  // [variant] -> {img, sil} 预烘密草条带
  const lowStripCaches = [];
  const skyCaches = [];    // [layer] -> 预压暗的远山条带（静止背景）
  const cloudCaches = [];  // [variant] -> 云簇精灵缓存
  let groundTile = null;   // 512x512 地面纹理
  let sunImg = null;       // 太阳（白天 6~18 点）
  let moonImg = null;      // 月亮（夜间 18~6 点）
  const sprites = [];      // {id, kind, x, z, baseW, baseH, variant, flip}
  const clouds = [];       // 云层单独绘制：永远垫在树林之后（远山之前）
  let ready = false;
  let spriteId = 0;

  function jitterTree(s, seedA, seedB) {
    const cfg = TREE_LANES[s.lane];
    s.x = s.side * (cfg.baseX + (hash(seedA, 5 + s.lane) - 0.5) * 2 * cfg.spreadX);
    s.variant = Math.floor(hash(seedA, seedB) * TREE_IMAGES.length) % TREE_IMAGES.length;
    s.flip = hash(seedA, seedB + 4) > 0.5;
    const size = cfg.size * P.treeSize * (0.84 + hash(seedA, seedB + 8) * 0.36);
    s.baseH = size;
    s.baseW = size;
  }

  function jitterGrass(s, seedA, seedB) {
    if (s.low) {
      /* 路面低草：只落在道路区域内；同款草压矮拉宽，读作贴地短草。 */
      s.x = (hash(seedA, seedB) - 0.5) * 2 * (PATH_HALF * 0.95);
      s.variant = Math.floor(hash(seedA, seedB + 2) * LOW_SOURCE_VARIANTS.length) % LOW_SOURCE_VARIANTS.length;
      const size = 20 * (0.7 + hash(seedA, seedB + 6) * 0.6);
      s.baseH = size * LOW_SQUASH_H;
      s.baseW = size * LOW_STRETCH_W;
    } else {
      /* 高草/花：让开中央道路，只长在两侧草甸。 */
      const side = hash(seedA, seedB + 1) > 0.5 ? 1 : -1;
      s.x = side * (PATH_HALF + 12 + hash(seedA, seedB) * (330 - PATH_HALF - 12));
      s.variant = pickGrassVariant(hash(seedA, seedB + 2));
      const size = 34 * (0.7 + hash(seedA, seedB + 6) * 0.6);
      s.baseH = size;
      s.baseW = size;
    }
    s.flip = hash(seedA, seedB + 3) > 0.5;
    /* 根部下沉 4%~8%：让草根穿插进地面/后方草丛，避免底边排成直线。 */
    s.sink = 0.04 + hash(seedA, seedB + 9) * 0.04;
  }

  function buildScene() {
    let seed = 1;
    /* 树：左右各三条车道（外侧大、内侧小），z 密布 + 抖动，
     * 三道错相排布让树干前后交叠成连续林墙。 */
    for (const side of [-1, 1]) {
      for (let lane = 0; lane < TREE_LANES.length; lane++) {
        const cfg = TREE_LANES[lane];
        /* 密度倍率直接缩放车道 z 间距。 */
        const step = cfg.step / Math.max(0.1, P.treeDensity);
        const offset = lane * 31 + (side < 0 ? 0 : step * 0.5);
        for (let z = Z_NEAR + offset; z < Z_FAR; z += step) {
          const s = {
            id: spriteId++,
            kind: "tree",
            side,
            lane,
            z: z + (hash(seed, 1) - 0.5) * step * 0.6,
          };
          jitterTree(s, seed, 11);
          sprites.push(s);
          seed++;
        }
      }
    }
    /* 云朵：挂在高空的世界物件，随前进迎面漂来（单独层，树永远遮住云）。 */
    for (let i = 0; i < P.cloudCount; i++) {
      const s = { id: spriteId++, z: 260 + hash(seed, 71) * (Z_FAR - 260) };
      jitterCloud(s, seed);
      clouds.push(s);
      seed++;
    }
    /* 草丛：全宽（含路中央与树下）散铺做近景细节，回收时重掷。
     * 远端铺到 FOG_END 之外：新草进入视野时 alpha=0，从黑暗中淡入。 */
    const GRASS_FAR = FOG_END + 40;
    for (let i = 0; i < P.grassCount; i++) {
      const s = { id: spriteId++, kind: "grass", low: false, z: Z_NEAR + hash(seed, 31) * (GRASS_FAR - Z_NEAR) };
      s.zSpan = GRASS_FAR - Z_EXIT;
      jitterGrass(s, seed, 17);
      sprites.push(s);
      seed++;
    }
    /* 路面低草散铺：道路区域的近景细节。 */
    for (let i = 0; i < P.lowCount; i++) {
      const s = { id: spriteId++, kind: "grass", low: true, z: Z_NEAR + hash(seed, 33) * (GRASS_FAR - Z_NEAR) };
      s.zSpan = GRASS_FAR - Z_EXIT;
      jitterGrass(s, seed, 19);
      sprites.push(s);
      seed++;
    }
    /* 密草条带行：等距世界 z 行，随精灵一起进画家排序（与树正确穿插）。 */
    const rowCount = Math.ceil((GRASS_FAR - Z_NEAR) / ROW_SPACING);
    for (let i = 0; i < rowCount; i++) {
      const s = { id: spriteId++, kind: "grassRow", z: Z_NEAR + 14 + i * ROW_SPACING };
      s.zSpan = rowCount * ROW_SPACING;
      jitterRow(s, seed);
      sprites.push(s);
      seed++;
    }
  }

  function jitterRow(s, seedA) {
    s.variant = Math.floor(hash(seedA, 51) * STRIP_VARIANTS) % STRIP_VARIANTS;
    s.lowVariant = Math.floor(hash(seedA, 55) * LOW_STRIP_VARIANTS) % LOW_STRIP_VARIANTS;
    s.uShift = hash(seedA, 53) * STRIP_WORLD_W;
    s.sink = 1.5 + hash(seedA, 57) * 3;
  }

  /* 云的横向风卷绕边界：漂出 ±CLOUD_X_WRAP 从另一侧绕回，
   * 绘制端在边界前 180 世界单位内柔和消散，杜绝跳变。 */
  const CLOUD_X_WRAP = 900;

  function jitterCloud(s, seedA) {
    s.x = (hash(seedA, 81) - 0.5) * 980;
    s.vr = hash(seedA, 83);               // 变体随机数，绘制时按实际簇数取模
    /* 不做镜像：云尾方向与横向风向保持全场一致 */
    const size = 220 + hash(seedA, 87) * 180;
    s.baseW = size;
    s.baseH = size;
    s.alt = 190 + hash(seedA, 89) * 130;  // 云底离地高度（世界单位）
  }
  buildScene();

  /** 把草印章烘进横向条带（环绕式落章，普通 repeat 平铺即无缝），
   *  同时预烘黑剪影副本，压暗与其它精灵完全一致（连续 alpha）。 */
  function buildGrassStrips() {
    const pool = grassCaches.filter(Boolean);
    if (!pool.length) return;
    for (let v = 0; v < STRIP_VARIANTS; v++) {
      const c = document.createElement("canvas");
      c.width = STRIP_PX_W;
      c.height = STRIP_PX_H;
      const g = c.getContext("2d");
      const STAMPS = 170;
      for (let i = 0; i < STAMPS; i++) {
        const idx = pickGrassVariant(hash(i, v * 7 + 61));
        const cache = pool[Math.min(idx, pool.length - 1)];
        const worldH = 18 + hash(i, v * 7 + 63) * 26;   // 18~44 世界单位
        const dh = worldH * STRIP_PPW;
        const dw = dh * (cache.img.width / cache.img.height);
        const x = hash(i, v * 7 + 67) * STRIP_PX_W;
        const y = STRIP_PX_H - dh + hash(i, v * 7 + 69) * 14 - 4;
        const flip = hash(i, v * 7 + 71) > 0.5;
        for (const bx of [x, x - STRIP_PX_W, x + STRIP_PX_W]) {
          if (bx + dw < 0 || bx > STRIP_PX_W) continue;
          if (flip) {
            g.save();
            g.translate(bx + dw / 2, 0);
            g.scale(-1, 1);
            g.drawImage(cache.img, -dw / 2, y, dw, dh);
            g.restore();
          } else {
            g.drawImage(cache.img, bx, y, dw, dh);
          }
        }
      }
      stripCaches.push({ img: c, sil: bakeSilhouette(c) });
    }
    /* 路面低草条带：更矮、无花，铺在道路区域。 */
    const lowPool = lowCaches.filter(Boolean);
    if (!lowPool.length) return;
    for (let v = 0; v < LOW_STRIP_VARIANTS; v++) {
      const c = document.createElement("canvas");
      c.width = LOW_STRIP_PX_W;
      c.height = LOW_STRIP_PX_H;
      const g = c.getContext("2d");
      const STAMPS = 260;
      for (let i = 0; i < STAMPS; i++) {
        const cache = lowPool[Math.floor(hash(i, v * 9 + 141) * lowPool.length) % lowPool.length];
        const worldH = 6 + hash(i, v * 9 + 143) * 7;    // 6~13 世界单位
        const dh = worldH * LOW_PPW;
        /* 同款草压矮：宽度按“原始比例 ÷ 压扁比 × 加宽比”放大，读作贴地短草。 */
        const dw = dh * (cache.img.width / cache.img.height) * (LOW_STRETCH_W / LOW_SQUASH_H);
        const x = hash(i, v * 9 + 147) * LOW_STRIP_PX_W;
        /* 单株矮草盖不满行距：让落点纵向铺满整条带，行与行才能咬合无缝。 */
        const y = hash(i, v * 9 + 149) * (LOW_STRIP_PX_H - dh);
        const flip = hash(i, v * 9 + 151) > 0.5;
        for (const bx of [x, x - LOW_STRIP_PX_W, x + LOW_STRIP_PX_W]) {
          if (bx + dw < 0 || bx > LOW_STRIP_PX_W) continue;
          if (flip) {
            g.save();
            g.translate(bx + dw / 2, 0);
            g.scale(-1, 1);
            g.drawImage(cache.img, -dw / 2, y, dw, dh);
            g.restore();
          } else {
            g.drawImage(cache.img, bx, y, dw, dh);
          }
        }
      }
      lowStripCaches.push({ img: c, sil: bakeSilhouette(c) });
    }
  }

  /** 当前生效的天空：skyType<0 时随昼夜时钟自动过渡，否则用手选预设。 */
  function curSky() {
    return P.skyType < 0 ? timeSky(dayHour()) : skyPreset();
  }

  /** 当前大气雾霾色（随 skyBright 变暗：天全黑时雾霾也退成黑）。 */
  function hazeRGB() {
    const hex = curSky().haze;
    const s = P.skyBright;
    return [1, 3, 5].map((i) => Math.round(parseInt(hex.slice(i, i + 2), 16) * s));
  }

  /** 剪影按雾霾色染色（懒烘焙，换天气/亮度时才重建）。 */
  function tintedSil(cache, color) {
    if (cache._tintColor !== color) {
      const c = document.createElement("canvas");
      c.width = cache.sil.width;
      c.height = cache.sil.height;
      const g = c.getContext("2d");
      g.drawImage(cache.sil, 0, 0);
      g.globalCompositeOperation = "source-in";
      g.fillStyle = color;
      g.fillRect(0, 0, c.width, c.height);
      cache._tint = c;
      cache._tintColor = color;
    }
    return cache._tint;
  }

  function bakeSilhouette(c) {
    const sil = document.createElement("canvas");
    sil.width = c.width;
    sil.height = c.height;
    const gs = sil.getContext("2d");
    gs.drawImage(c, 0, 0);
    gs.globalCompositeOperation = "source-in";
    gs.fillStyle = "#000";
    gs.fillRect(0, 0, c.width, c.height);
    return sil;
  }

  /** 天空层缓存：原图 + 黑剪影，绘制时按天气预设动态压暗
   *  （预烘死黑度会让亮天下的远山黑成一片，故改为运行时叠加）。 */
  function buildSkyCache(img) {
    const c = document.createElement("canvas");
    c.width = img.naturalWidth;
    c.height = img.naturalHeight;
    c.getContext("2d").drawImage(img, 0, 0);
    return { img: c, sil: bakeSilhouette(c) };
  }

  Promise.all([
    ...TREE_IMAGES.map((t) => loadImage(asset(t.name))),
    ...GRASS_IMAGES.map((g) => loadImage(asset(g.name))),
    ...SKY_LAYERS.map((s) => loadImage(asset(s.name))),
    loadImage(asset(CLOUD_IMAGE)),
    loadImage(asset(GROUND_TILE)),
    loadImage(asset(SUN_IMAGE)),
    loadImage(asset(MOON_IMAGE)),
  ]).then((imgs) => {
    for (let i = 0; i < TREE_IMAGES.length; i++) {
      treeCaches.push(imgs[i] ? buildSpriteCache(imgs[i], TREE_IMAGES[i].cache) : null);
    }
    for (let i = 0; i < GRASS_IMAGES.length; i++) {
      const img = imgs[TREE_IMAGES.length + i];
      grassCaches.push(img ? buildSpriteCache(img, GRASS_IMAGES[i].cache) : null);
    }
    const skyBase = TREE_IMAGES.length + GRASS_IMAGES.length;
    for (let i = 0; i < SKY_LAYERS.length; i++) {
      const img = imgs[skyBase + i];
      skyCaches.push(img ? buildSkyCache(img) : null);
    }
    const cloudImg = imgs[skyBase + SKY_LAYERS.length];
    if (cloudImg) {
      /* 按透明列自动分簇：避免固定等分把云切出直边。
       * 缓存上限 768：云在近处会放大到数百像素，精度必须留足。 */
      for (const c of sliceCloudClusters(cloudImg)) {
        cloudCaches.push(buildSpriteCache(c, 768));
      }
    }
    groundTile = imgs[skyBase + SKY_LAYERS.length + 1] || null;
    sunImg = imgs[skyBase + SKY_LAYERS.length + 2] || null;
    moonImg = imgs[skyBase + SKY_LAYERS.length + 3] || null;
    /* 个别图加载失败时用已加载变体顶替，保证任何精灵（含回收重掷）都有位图可画。 */
    const treeFallback = treeCaches.find(Boolean) || null;
    const grassFallback = grassCaches.find(Boolean) || null;
    for (let i = 0; i < treeCaches.length; i++) if (!treeCaches[i]) treeCaches[i] = treeFallback;
    for (let i = 0; i < grassCaches.length; i++) if (!grassCaches[i]) grassCaches[i] = grassFallback;
    /* 路面低草直接引用素草/蕨的缓存，绘制时再压矮拉宽。 */
    for (const vi of LOW_SOURCE_VARIANTS) lowCaches.push(grassCaches[vi] || grassFallback);
    buildGrassStrips();
    ready = true;
    requestRedraw();
  });

  /* ---- 相机 / 行进状态 ---- */
  const keys = Object.create(null);
  let autoForward = opts.autoForward !== false && keyboard;
  let traveling = false;
  let travelGoal = 0;
  let travelResolve = null;
  let camX = 0;
  let camZ = 0;
  let speed = 0;
  let bobPhase = 0;
  let bobEnv = 0;          // 镜头起伏包络（随速度渐入，到站后缓出不弹跳）
  let windAcc = 0;         // 云横向风的位移累积（静止时节流重绘）
  let raf = 0;
  let lastTs = 0;
  let alive = true;
  let dirty = true;
  let recycleSeed = 9000;

  /* ---- 画布几何 ---- */
  let W = 0;
  let H = 0;
  let dpr = 1;
  let focal = 300;
  let horizonY = 170;

  function measure() {
    const w = Math.max(1, viewport.clientWidth || host.clientWidth || 1);
    const h = Math.max(1, viewport.clientHeight || host.clientHeight || 1);
    dpr = Math.min(2, window.devicePixelRatio || 1);
    W = w;
    H = h;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    horizonY = h * P.horizonFrac;
    /* 焦距按带高定：让近树冠顶出画、地面草铺满下半。 */
    focal = h * P.focalMult;
    dirty = true;
    /* 改尺寸会把画布清成透明；立即填黑，未就绪/未重绘期间不露底。 */
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = "#000";
    ctx.fillRect(0, 0, W, H);
  }

  function finishTravel(ok) {
    traveling = false;
    const resolve = travelResolve;
    travelResolve = null;
    if (resolve) resolve(ok);
  }

  /* 诊断仪器（默认关闭）：window.__corridorDebugOn = true 时收集每帧
   * 精灵深度/压暗/alpha 与回收事件，供 scripts/diag_*.py 回归验证。 */
  function dbg() {
    if (!window.__corridorDebugOn) return null;
    if (!window.__corridorDebug) {
      window.__corridorDebug = { frames: [], recycles: [] };
    }
    return window.__corridorDebug;
  }

  function recycle() {
    const d = dbg();
    for (const s of sprites) {
      if (s.kind === "tree") {
        while (s.z - camZ < Z_EXIT) {
          s.z += Z_FAR - Z_EXIT;
          recycleSeed++;
          jitterTree(s, recycleSeed, 23);
          d?.recycles.push({ id: s.id, kind: s.kind, zRel: s.z - camZ, camZ });
        }
        while (s.z - camZ > Z_FAR) {
          s.z -= Z_FAR - Z_EXIT;
          recycleSeed++;
          jitterTree(s, recycleSeed, 29);
        }
      } else if (s.kind === "grassRow") {
        while (s.z - camZ < Z_EXIT) {
          s.z += s.zSpan;
          recycleSeed++;
          jitterRow(s, recycleSeed);
          d?.recycles.push({ id: s.id, kind: s.kind, zRel: s.z - camZ, camZ });
        }
        while (s.z - camZ > Z_EXIT + s.zSpan) {
          s.z -= s.zSpan;
          recycleSeed++;
          jitterRow(s, recycleSeed);
        }
      } else {
        while (s.z - camZ < Z_EXIT) {
          s.z += s.zSpan;
          recycleSeed++;
          jitterGrass(s, recycleSeed, 37);
          d?.recycles.push({ id: s.id, kind: s.kind, zRel: s.z - camZ, camZ });
        }
        while (s.z - camZ > Z_EXIT + s.zSpan) {
          s.z -= s.zSpan;
          recycleSeed++;
          jitterGrass(s, recycleSeed, 41);
        }
      }
    }
    const cloudCam = camZ * CLOUD_PARALLAX;
    for (const s of clouds) {
      while (s.z - cloudCam < Z_EXIT) {
        s.z += Z_FAR - Z_EXIT;
        recycleSeed++;
        jitterCloud(s, recycleSeed);
      }
      while (s.z - cloudCam > Z_FAR) {
        s.z -= Z_FAR - Z_EXIT;
        recycleSeed++;
        jitterCloud(s, recycleSeed);
      }
    }
  }

  /** 当前时刻（小时，0~24）：时钟挂在 camZ 上，一个 STAGE_STEP = 2 小时。 */
  function dayHour() {
    const h = (P.dayStart + (camZ / STAGE_STEP) * 2) % 24;
    return h < 0 ? h + 24 : h;
  }

  /** 日月：左方升起→右方降下的圆弧。画在天空渐变之上、远山之下——
   *  升落时被远山/雾带自然吞没，行进中被树冠遮挡。 */
  function drawSunMoon(hy) {
    const hour = dayHour();
    const isSun = hour >= 6 && hour < 18;
    const img = isSun ? sunImg : moonImg;
    if (!img) return;
    /* 半日 12h ÷ 每关 2h = 6 步走完一条圆弧。
     * 运动与推进对齐：v = 本次推进内的进度（每关恰好 +2h，推进
     * 边界在 dayStart + 2N）。全程缓动——步进开始即起步、缓慢
     * 移动、步进结束正好滑到下一位；战斗期间时钟不走，日月驻留。 */
    const ht = isSun ? hour - 6 : (hour + 6) % 12;  // 半日内进度 0~12h
    const v = ((((hour - P.dayStart) % 2) + 2) % 2) / 2;
    const base = ht - 2 * v;
    const eased = base + 2 * (v * v * (3 - 2 * v));
    /* f: 0=左端升起，0.5=弧顶，1=右端落下 */
    const f = Math.max(0, Math.min(1, eased / 12));
    const dw = H * 0.3 * P.sunSize;
    const dh = dw * (img.height / img.width);
    /* 圆弧路线收在中央天空楔内（画幅两角被树冠盖死）：
     * 两端在天空楔两侧半高处，中间上拱到画幅顶部。 */
    const cxs = W * (0.32 + 0.36 * f);
    const peakY = H * 0.06 + dh * 0.5;
    const endY = hy * 0.55;
    const cy = endY - (endY - peakY) * Math.sin(Math.PI * f);
    /* 6/18 点日月交接：出没各留 0.3h 淡入淡出 */
    ctx.globalAlpha = Math.max(0, Math.min(1, Math.min(ht, 12 - ht) / 0.3));
    ctx.drawImage(img, cxs - dw * 0.5, cy - dh * 0.5, dw, dh);
    ctx.globalAlpha = 1;
  }

  /** 远山：完全静止的背景（真实远山在前进中几乎不动），
   *  镜像平铺（奇数块水平翻转）保证无缝。距离衰减 = 叠雾霾色剪影
   *  （大气透视：晴天远山融进亮天光而非黑暗），量 = min(层基础值, 预设上限)。 */
  function drawSkyLayers(hy) {
    const dimCap = 1 - P.skyBright * (1 - curSky().mtnCap);
    const [hr, hg, hb] = hazeRGB();
    const hazeColor = `rgb(${hr},${hg},${hb})`;
    for (let i = 0; i < SKY_LAYERS.length; i++) {
      const cache = skyCaches[i];
      if (!cache) continue;
      const dim = Math.min(SKY_LAYERS[i].dim, dimCap);
      const drawH = i === 0 ? H * 0.24 : H * 0.34;
      const bottomY = hy + (i === 0 ? 2 : 4);
      const drawW = cache.img.width * (drawH / cache.img.height);
      const sil = tintedSil(cache, hazeColor);
      for (let k = 0; k * drawW < W; k++) {
        const x = k * drawW;
        const flip = (k & 1) === 1;
        const dx = flip ? W - x - drawW : x;
        if (flip) ctx.setTransform(-dpr, 0, 0, dpr, canvas.width, 0);
        ctx.drawImage(cache.img, dx, bottomY - drawH, drawW, drawH);
        if (dim > 0.004) {
          ctx.globalAlpha = dim;
          ctx.drawImage(sil, dx, bottomY - drawH, drawW, drawH);
          ctx.globalAlpha = 1;
        }
        if (flip) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      }
    }
  }

  /** 祥云：真实透视投影（迎面漂来、放大、掠过头顶），但永远画在
   *  树林之下——只从林隙与画幅顶部露出，不会糊在树冠上。
   *  压暗/淡入与精灵同一套连续曲线。 */
  function drawClouds(hy, cx) {
    if (!cloudCaches.length) return;
    const cloudCam = camZ * CLOUD_PARALLAX;
    const [hr, hg, hb] = hazeRGB();
    const hazeColor = `rgb(${hr},${hg},${hb})`;
    for (const s of clouds) {
      const z = s.z - cloudCam;
      if (z < Z_EXIT || z > CULL_Z) continue;
      const cache = cloudCaches[Math.floor(s.vr * cloudCaches.length) % cloudCaches.length];
      if (!cache) continue;
      const scale = focal / z;
      const sx = cx + (s.x - camX) * scale;
      /* 按云簇真实宽高比绘制（baseW 为世界宽度），避免被压扁。 */
      const w = s.baseW * P.cloudSize * scale;
      const h = w * (cache.img.height / cache.img.width);
      if (sx + w * 0.5 < 0 || sx - w * 0.5 > W) continue;
      const sy = hy + (CAM_H - s.alt) * scale;  // 云底在高空，靠近时升出画幅
      /* 云的距离衰减 = 融进雾霾色（晴天融进亮天光而非压黑），
       * 上限随预设联动；天空全黑时雾霾也是黑，恢复原始压黑。 */
      const dark = Math.min(darknessAt(z), 1 - P.skyBright * (1 - curSky().cloudCap));
      let fade = 1;
      if (z > FADE_START) {
        fade = 1 - (z - FADE_START) / (FOG_END - FADE_START);
        if (fade <= 0.01) continue;
      }
      /* 掠头前柔和消散：避免大云贴着画幅顶边蹭出深色悬挂物。 */
      if (z < 560) {
        fade *= Math.max(0, (z - 240) / 320);
        if (fade <= 0.01) continue;
      }
      /* 横向风卷绕边界前柔和消散，绕回另一侧再淡入。 */
      fade *= Math.max(0, Math.min(1, (CLOUD_X_WRAP - Math.abs(s.x)) / 180));
      if (fade <= 0.01) continue;
      const dy = Math.round(sy - h);
      const dw = Math.max(1, Math.round(w));
      const dh = Math.max(1, Math.round(h));
      const dx = Math.round(sx - w * 0.5);
      ctx.globalAlpha = fade;
      drawClipped(cache.img, dx, dy, dw, dh);
      if (dark > 0.004) {
        ctx.globalAlpha = fade * dark;
        drawClipped(tintedSil(cache, hazeColor), dx, dy, dw, dh);
      }
    }
    ctx.globalAlpha = 1;
  }

  /** Mode-7 扫描带地面：地平线以下切水平带，逐带反算深度取纹理行，
   *  v 随 camZ 滚动产生前进感；v 用 ping-pong 寻址（往返镜像）免接缝。
   *  远端（v 跨度过大 / 超出 FOG_END）退化为整块拉伸——反正会被雾带压黑。 */
  function drawGround(hy) {
    if (!groundTile) {
      const ground = ctx.createLinearGradient(0, hy, 0, H);
      ground.addColorStop(0, "#000000");
      ground.addColorStop(0.22, "#0c1607");
      ground.addColorStop(0.55, "#1a2c0f");
      ground.addColorStop(1, "#2a4418");
      ctx.fillStyle = ground;
      ctx.fillRect(0, Math.floor(hy), W, Math.ceil(H - hy));
      return;
    }
    const TEX = groundTile.naturalWidth;           // 512
    const pxPerWorld = TEX / GROUND_TILE_WORLD;
    /* FOG_END 之外纯黑打底（也垫住扫描带上沿） */
    ctx.fillStyle = "#000";
    ctx.fillRect(0, Math.floor(hy), W, Math.ceil(H - hy));
    const yFogEnd = hy + (CAM_H * focal) / FOG_END; // 比这更靠上的地面已全黑
    const yTop = Math.max(Math.ceil(yFogEnd), Math.ceil(hy + 2));
    const sliceH = (H - yTop) / GROUND_SLICES;
    if (sliceH <= 0) return;
    const zAt = (y) => (CAM_H * focal) / (y - hy);
    for (let i = 0; i < GROUND_SLICES; i++) {
      const y0 = yTop + i * sliceH;
      const y1 = y0 + sliceH;
      const zTop = zAt(y0);
      const zBot = zAt(y1);
      let v0 = (camZ + zBot) * pxPerWorld;  // 带内自下而上 v 增大
      let v1 = (camZ + zTop) * pxPerWorld;
      const span = v1 - v0;
      if (span > TEX * 0.8) {
        /* 远端一带压缩了太多世界长度：整块拉伸即可（在雾里几乎全黑） */
        ctx.drawImage(groundTile, 0, 0, TEX, TEX, 0, y0, W, sliceH + 0.5);
        continue;
      }
      /* ping-pong 寻址逐段绘制（跨折返线时最多拆 2~3 段）。
       * 约定：屏幕越靠上 v 越大；正向段纹理行随 v 增而增（需垂直翻转绘制），
       * 镜像段纹理行随 v 增而减（正向绘制），折返处行号连续 ⇒ 无缝。 */
      let v = v0;
      let yBottom = y1;
      while (v < v1 - 0.01) {
        const period = TEX * 2;
        const p = ((v % period) + period) % period;
        const mirrored = p >= TEX;
        const local = mirrored ? period - p : p;      // 当前 v 对应的纹理行
        const room = mirrored ? local : TEX - local;  // 距折返线的行数
        const segV = Math.min(v1 - v, room);
        if (segV < 0.5) { v += 0.5; continue; }
        const segH = (segV / span) * sliceH;
        const yTopSeg = yBottom - segH;
        if (mirrored) {
          ctx.drawImage(groundTile, 0, local - segV, TEX, segV, 0, yTopSeg, W, segH + 0.5);
        } else {
          ctx.save();
          ctx.translate(0, yBottom);
          ctx.scale(1, -1);
          ctx.drawImage(groundTile, 0, local, TEX, segV, 0, 0, W, segH + 0.5);
          ctx.restore();
        }
        v += segV;
        yBottom = yTopSeg;
      }
    }
  }

  function drawFogBand(hy) {
    /* 地平线氛围雾带：只垫在所有精灵之下（画完地面立即画），
     * 精灵的深度压暗全部由自身剪影叠加完成——精灵与雾带之间
     * 永远不存在绘制顺序翻转，行进时不会有整棵树跳亮。
     * 向上延伸随天气收缩（fogUp）：天越亮雾带越矮，山峰露出雾外。
     * 地平线以上是"大气雾霾"：上端为透明的亮雾霾色，越靠近地平线
     * 颜色越压向黑（暗红/暗紫/深灰随预设色相走），衔接通道内部的纯黑；
     * 地平线以下保持黑色——隧道尽头的黑暗只属于通道内部。 */
    const up = H * 0.44 * (1 - P.skyBright * (1 - curSky().fogUp));
    const down = H * 0.55;
    const total = up + down;
    const pivot = up / total;
    const ease = (k) => k * k * (3 - 2 * k);
    const [hr, hg, hb] = hazeRGB();
    const DEEP = 0.8; // 地平线处雾霾色被压暗的比例（1=纯黑）
    const grad = ctx.createLinearGradient(0, hy - up, 0, hy + down);
    const STEPS = 6;
    for (let i = 0; i <= STEPS; i++) {
      const k = i / STEPS;
      const a = ease(k);
      const m = 1 - DEEP * a; // 不透明度越高颜色越暗
      grad.addColorStop(
        pivot * k,
        `rgba(${Math.round(hr * m)},${Math.round(hg * m)},${Math.round(hb * m)},${a.toFixed(4)})`
      );
    }
    for (let i = 1; i <= STEPS; i++) {
      const k = i / STEPS;
      grad.addColorStop(pivot + (1 - pivot) * k, `rgba(0,0,0,${ease(1 - k).toFixed(4)})`);
    }
    ctx.globalAlpha = 1;
    ctx.fillStyle = grad;
    ctx.fillRect(0, Math.floor(hy - up), W, Math.ceil(total));
  }

  function draw() {
    if (!ready) return;
    const t0 = performance.now();
    /* 行走镜头起伏：垂直颠簸（每步一次）+ 半频左右摇摆（步伐交替），
     * 幅度随速度渐入渐出，起步/停步不跳变。 */
    const bobK = bobEnv * P.bob;
    const hy = horizonY + Math.sin(bobPhase) * H * 0.016 * bobK;
    const sway = Math.sin(bobPhase * 0.5) * 8 * bobK;
    const cx = W * 0.5;
    /* 相机跟随脚下道路中心（略向前看）：近处路永远在正下方，远处摆出弯。 */
    const camEff = camX + sway + pathOffset(camZ + P.curveLook);

    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "low";

    /* 1. 纯黑底（隧道尽头的黑暗）。 */
    ctx.globalAlpha = 1;
    ctx.fillStyle = "#000";
    ctx.fillRect(0, 0, W, H);

    /* 1.5 天空：程序渐变（0=画幅顶，1=地平线），按天气预设取色标。
     * skyBright 作为总亮度旋钮叠在黑底上；地平线附近由雾带压进黑暗。 */
    if (P.skyBright > 0.01) {
      const preset = curSky();
      const skyH = Math.ceil(hy) + 2;
      const grad = ctx.createLinearGradient(0, 0, 0, skyH);
      for (const [pos, color] of preset.stops) grad.addColorStop(pos, color);
      ctx.globalAlpha = P.skyBright;
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, W, skyH);
      ctx.globalAlpha = 1;
    }

    /* 1.8 日月：随推关时钟沿弧线运行（远山、云、树都会遮住它）。 */
    drawSunMoon(hy);

    /* 2. 静止远山 + 迎面漂来的祥云（云在树后，只从林隙/顶部露出）。 */
    drawSkyLayers(hy);
    drawClouds(hy, cx);

    /* 3. Mode-7 扫描带地面：纹理 v 随 camZ 滚动。 */
    drawGround(hy);

    /* 4. 氛围雾带垫底：画在全部精灵之前，只影响地面/天空/山云。 */
    drawFogBand(hy);

    /* 4. 精灵严格全局画家排序：按相机相对深度远→近，等深用 id 稳定。 */
    const visible = [];
    for (const s of sprites) {
      const z = s.z - camZ;
      if (z < Z_EXIT || z > CULL_Z) continue;
      visible.push(s);
    }
    visible.sort((a, b) => (b.z - a.z) || (a.id - b.id));

    const d = dbg();
    const frameRec = d
      ? { t: t0, camZ, speed, sprites: [], newlyDrawn: [] }
      : null;

    for (const s of visible) {
      const z = s.z - camZ;
      if (s.kind === "grassRow") {
        drawGrassRow(s, z, hy, cx, camEff, frameRec);
        continue;
      }
      const cache = s.kind === "tree" ? treeCaches[s.variant]
        : s.low ? lowCaches[s.variant]
        : grassCaches[s.variant];
      if (!cache) continue;
      const scale = focal / z;
      const sx = cx + (s.x + pathOffset(s.z) - camEff) * scale;
      /* 世界尺寸 × 内容占比 = 裁剪后内容的绘制尺寸；内容底边即落地点。 */
      const w = s.baseW * cache.wFrac * scale;
      const h = s.baseH * cache.hFrac * scale;
      if (sx + w * 0.5 < 0 || sx - w * 0.5 > W) continue;
      /* 统一地面锚点：所有精灵内容底边 = hy + CAM_H*scale；草再随机下沉。 */
      let sy = hy + CAM_H * scale;
      if (s.kind === "grass") sy += h * s.sink;
      if (sy - h > H) continue;
      /* 深度压暗：连续 smoothstep，远端到 1（纯黑，融入黑背景）。 */
      const dark = darknessAt(z);
      /* 深度末段 alpha 淡入：远处新精灵从全透明渐显，永不跳变蹦出。 */
      let fade = 1;
      if (z > FADE_START) {
        fade = 1 - (z - FADE_START) / (FOG_END - FADE_START);
        if (fade <= 0.01) continue;
      }
      const dy = Math.round(sy - h);
      const dw = Math.max(1, Math.round(w));
      const dh = Math.max(1, Math.round(h));
      const dx = s.flip ? Math.round(W - sx - w * 0.5) : Math.round(sx - w * 0.5);
      if (s.flip) ctx.setTransform(-dpr, 0, 0, dpr, canvas.width, 0);
      ctx.globalAlpha = fade;
      drawClipped(cache.img, dx, dy, dw, dh);
      if (dark > 0.004) {
        /* 第二笔黑剪影：alpha 为浮点连续值，压暗永远平滑。 */
        ctx.globalAlpha = fade * dark;
        drawClipped(cache.sil, dx, dy, dw, dh);
      }
      if (s.flip) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      if (frameRec) {
        frameRec.sprites.push({
          id: s.id, kind: s.kind, z: Math.round(z * 10) / 10,
          dark: Math.round(dark * 1000) / 1000,
          fade: Math.round(fade * 1000) / 1000,
          x: s.flip ? Math.round(W - dx - dw) : dx, y: dy,
          w: dw, h: dh,
        });
      }
    }
    ctx.globalAlpha = 1;

    /* 6. 环境光：全屏 multiply 着色，氛围对树/草/地面全局生效。
     * 乘法下黑不变黑，隧道尽头的黑暗与雾带不受影响。 */
    const [ambColor, ambBase] = curSky().amb;
    const ambA = ambBase * P.ambient;
    if (ambA > 0.01) {
      ctx.globalCompositeOperation = "multiply";
      ctx.globalAlpha = ambA;
      ctx.fillStyle = ambColor;
      ctx.fillRect(0, 0, W, H);
      ctx.globalCompositeOperation = "source-over";
      ctx.globalAlpha = 1;
    }

    if (frameRec && d) {
      const prev = d.frames[d.frames.length - 1];
      const prevIds = prev ? new Set(prev.sprites.map((r) => r.id)) : null;
      for (const r of frameRec.sprites) {
        if (!prevIds || !prevIds.has(r.id)) frameRec.newlyDrawn.push(r);
      }
      d.frames.push(frameRec);
      if (d.frames.length > 3000) d.frames.shift();
    }
    window.__corridorDrawMs = performance.now() - t0;
  }

  /** 密草条带行：一行 = 预烘条带纹理沿 x 平铺（烘焙时环绕落章，普通平铺无缝）。
   *  高草条带让开中央道路（按该行深度算出路缘），路面用低草条带铺；
   *  两者边界略微重叠，避免露出直缝。压暗/淡入与精灵同一套连续曲线。 */
  function drawGrassRow(s, z, hy, cx, camEff, frameRec) {
    const cache = stripCaches[s.variant];
    if (!cache) return;
    const scale = focal / z;
    const h = STRIP_WORLD_H * scale;
    if (h < 2) return;
    const dark = darknessAt(z);
    let fade = 1;
    if (z > FADE_START) {
      fade = 1 - (z - FADE_START) / (FOG_END - FADE_START);
      if (fade <= 0.01) return;
    }
    const bend = pathOffset(s.z);
    const sy = hy + CAM_H * scale + s.sink * scale;
    const pathCx = cx + (bend - camEff) * scale;
    const phw = PATH_HALF * scale;
    /* 高草：路缘之外（左右两段） */
    tileStrip(cache, s.uShift, scale, sy, h, fade, dark, cx, bend - camEff,
      [[0, pathCx - phw * 0.92], [pathCx + phw * 0.92, W]]);
    /* 低草：路面之内（与高草边界重叠约 13%）。
     * 条带世界高只有 30、盖不满行距 54，同一行画两遍（错半个行距），
     * 近处不再叠成高草墙，行间也不露黑地。颜色与两侧同一套压暗曲线。 */
    const lowCache = lowStripCaches[s.lowVariant];
    if (lowCache) {
      for (const [dz, du] of [[0, 0], [ROW_SPACING * 0.5, 337]]) {
        const z2 = z - dz;
        if (z2 < 0.5) continue;
        const sc2 = focal / z2;
        const lh = LOW_STRIP_WORLD_H * sc2;
        if (lh < 2) continue;
        const dark2 = darknessAt(z2);
        let fade2 = 1;
        if (z2 > FADE_START) {
          fade2 = 1 - (z2 - FADE_START) / (FOG_END - FADE_START);
          if (fade2 <= 0.01) continue;
        }
        const bend2 = pathOffset(s.z - dz);
        const sy2 = hy + CAM_H * sc2 + s.sink * sc2 * 0.6;
        const pcx2 = cx + (bend2 - camEff) * sc2;
        const phw2 = PATH_HALF * sc2;
        tileStrip(lowCache, s.uShift + du, sc2, sy2, lh, fade2, dark2, cx, bend2 - camEff,
          [[pcx2 - phw2 * 1.05, pcx2 + phw2 * 1.05]]);
      }
    }
    if (frameRec) {
      frameRec.sprites.push({
        id: s.id, kind: "grassRow", z: Math.round(z * 10) / 10,
        dark: Math.round(dark * 1000) / 1000,
        fade: Math.round(fade * 1000) / 1000,
        x: 0, y: Math.round(sy - h), w: W, h: Math.round(h),
      });
    }
  }

  /** 把一条草带纹理沿 x 平铺，只画进给定的横向区段列表。
   *  xOff = 该行道路弯曲偏移 - 相机横向位置（世界单位）。 */
  function tileStrip(cache, uShift, scale, sy, h, fade, dark, cx, xOff, spans) {
    const dy = Math.round(sy - h);
    if (dy > H) return;
    const dw = STRIP_WORLD_W * scale;
    const dh = Math.max(1, Math.round(h));
    const kMin = Math.floor(((0 - cx) / scale - xOff - uShift) / STRIP_WORLD_W);
    for (let k = kMin; ; k++) {
      const dx = cx + (k * STRIP_WORLD_W + uShift + xOff) * scale;
      if (dx > W) break;
      if (dx + dw < 0) continue;
      const rx = Math.round(dx);
      const rw = Math.max(1, Math.round(dw));
      for (const [b0, b1] of spans) {
        if (b1 <= b0) continue;
        ctx.globalAlpha = fade;
        drawClipped(cache.img, rx, dy, rw, dh, b0, b1);
        if (dark > 0.004) {
          ctx.globalAlpha = fade * dark;
          drawClipped(cache.sil, rx, dy, rw, dh, b0, b1);
        }
      }
    }
  }

  /** 只把落在视口内的部分交给栅格化（软件渲染下近树 2/3 在画外，省一大截）。
   *  可选 bx0/bx1：额外的横向裁剪边界（用于高草让路、低草限定路面）。 */
  function drawClipped(img, dx, dy, dw, dh, bx0 = 0, bx1 = Infinity) {
    const xlo = Math.max(0, bx0);
    const xhi = Math.min(W, bx1);
    let x0 = dx;
    let y0 = dy;
    let x1 = dx + dw;
    let y1 = dy + dh;
    if (x1 <= xlo || x0 >= xhi || y1 <= 0 || y0 >= H) return;
    let sx0 = 0;
    let sy0 = 0;
    if (x0 < xlo) { sx0 = (xlo - x0) * img.width / dw; x0 = xlo; }
    if (y0 < 0) { sy0 = (-y0) * img.height / dh; y0 = 0; }
    if (x1 > xhi) x1 = xhi;
    if (y1 > H) y1 = H;
    const sw = (x1 - x0) * img.width / dw;
    const sh = (y1 - y0) * img.height / dh;
    if (sw <= 0 || sh <= 0) return;
    ctx.drawImage(img, sx0, sy0, sw, sh, x0, y0, x1 - x0, y1 - y0);
  }

  /* ---- 主循环：仅在运动/脏帧时重绘，静止即停。 ---- */
  function loopNeeded() {
    if (keyboard) return true;
    return traveling || dirty || Math.abs(speed) > 0.5
      || (ready && Math.abs(P.cloudWind) > 0.01);
  }

  function tick(now) {
    if (!alive) return;
    raf = 0;
    if (!lastTs) lastTs = now;
    const dt = Math.min(0.05, (now - lastTs) / 1000);
    lastTs = now;

    /* 未就绪：冻结相机与行进，保持黑屏等待；首个可见帧必然是完整场景。 */
    if (!ready) {
      raf = requestAnimationFrame(tick);
      return;
    }

    let targetSpeed = 0;
    if (keyboard) {
      targetSpeed =
        (autoForward ? 220 : 0) +
        (keys.KeyW || keys.ArrowUp ? 260 : 0) -
        (keys.KeyS || keys.ArrowDown ? 280 : 0);
    } else if (traveling) {
      const gap = travelGoal - camZ;
      if (gap <= 1.5) {
        camZ = travelGoal;
        speed = 0;
        finishTravel(true);
      } else {
        targetSpeed = Math.min(340, Math.max(110, gap * 1.2));
      }
    }

    speed += (targetSpeed - speed) * Math.min(1, dt * 3.1);
    if (!keyboard && !traveling) speed = 0;

    const prevZ = camZ;
    const prevX = camX;
    camZ += speed * dt;

    if (keyboard) {
      const strafe = (keys.KeyD || keys.ArrowRight ? 1 : 0) - (keys.KeyA || keys.ArrowLeft ? 1 : 0);
      camX += strafe * 160 * dt;
      if (camX > 70) camX = 70;
      if (camX < -70) camX = -70;
      if (!strafe) camX += (0 - camX) * dt * 1.2;
    }

    const moved = Math.abs(camZ - prevZ) > 0.001 || Math.abs(camX - prevX) > 0.001;
    if (moved) bobPhase += dt * (3.8 + Math.abs(speed) * 0.017);
    /* 起伏包络：随速度渐入；到站 speed 归零后缓出（余摆收回），不弹跳。 */
    bobEnv += (Math.min(1, Math.abs(speed) / 200) - bobEnv) * Math.min(1, dt * 4);
    if (bobEnv < 0.004) bobEnv = 0;
    else if (!moved) dirty = true;

    /* 云的独立横向风：真实时间驱动、与推进无关，驻足时也缓缓漂。
     * 前进中每帧生效（反正要重绘）；静止画面按位移阈值节流——
     * 攒够 ~0.6 世界单位才动一帧，rAF 空转开销可忽略。 */
    if (Math.abs(P.cloudWind) > 0.01) {
      windAcc += P.cloudWind * dt;
      if (moved || Math.abs(windAcc) > 0.6) {
        for (const s of clouds) {
          s.x += windAcc;
          if (s.x > CLOUD_X_WRAP) s.x -= CLOUD_X_WRAP * 2;
          else if (s.x < -CLOUD_X_WRAP) s.x += CLOUD_X_WRAP * 2;
        }
        windAcc = 0;
        dirty = true;
      }
    }

    if (moved || dirty) {
      recycle();
      draw();
      dirty = false;
    }

    if (onStatus) {
      const mode = keyboard
        ? (autoForward ? "自动前进中" : "手动")
        : traveling
          ? "赶路中"
          : "驻足";
      onStatus(`${mode} · 深度 ${Math.abs(camZ | 0)} · canvas 画家算法`);
    }

    if (loopNeeded()) {
      raf = requestAnimationFrame(tick);
    } else {
      lastTs = 0;
    }
  }

  function requestRedraw() {
    dirty = true;
    if (!raf && alive) raf = requestAnimationFrame(tick);
  }

  /* ---- 场景参数编辑器 ---- */

  /** 结构性参数改动后重建全部精灵（不重载图片，开销可忽略）。 */
  function rebuildScene() {
    sprites.length = 0;
    clouds.length = 0;
    spriteId = 0;
    buildScene();
    if (ready) recycle();
  }

  /** 花权重改动后重烘密草条带（几十毫秒级）。 */
  function rebakeStrips() {
    if (!ready) return;
    stripCaches.length = 0;
    lowStripCaches.length = 0;
    buildGrassStrips();
  }

  const EDITOR_FIELDS = [
    ["弯道", [
      ["curveA1", "主弯幅度", 0, 400, 5],
      ["curveL1", "主弯波长", 400, 3000, 25],
      ["curveA2", "次弯幅度", 0, 200, 5],
      ["curveL2", "次弯波长", 200, 1500, 10],
      ["curveLook", "视线前探", 0, 200, 5],
    ]],
    ["道路", [
      ["pathHalf", "道路半宽", 20, 140, 1, "structural"],
    ]],
    ["森林", [
      ["treeDensity", "树密度", 0.3, 2.5, 0.05, "structural"],
      ["treeSize", "树体型", 0.6, 1.6, 0.02, "structural"],
    ]],
    ["草地", [
      ["grassCount", "高草散铺", 0, 220, 5, "structural"],
      ["lowCount", "路面低草", 0, 160, 5, "structural"],
      ["flower", "花密度", 0, 3, 0.1, "strips"],
    ]],
    ["纵深", [
      ["fogStart", "压暗起点", 80, 800, 10],
      ["fogEnd", "全黑距离", 700, 2000, 10],
    ]],
    ["相机", [
      ["camH", "相机高度", 30, 120, 1],
      ["focalMult", "焦距", 0.6, 1.8, 0.02, "measure"],
      ["horizonFrac", "地平线", 0.35, 0.75, 0.01, "measure"],
      ["bob", "镜头起伏", 0, 3, 0.1],
    ]],
    ["天空", [
      ["skyBright", "天空亮度", 0, 1, 0.05],
      ["ambient", "氛围强度", 0, 1, 0.05],
      ["dayStart", "起始时刻", 0, 24, 0.5],
      ["sunSize", "日月尺寸", 0.4, 2, 0.05],
      ["cloudWind", "云风速", -20, 20, 0.5],
      ["cloudCount", "云数量", 0, 24, 1, "structural"],
      ["cloudSize", "云尺寸", 0.4, 2.5, 0.05],
      ["cloudParallax", "云视差", 0, 0.5, 0.01],
    ]],
  ];

  function persistParams() {
    try { localStorage.setItem(PARAM_STORE, JSON.stringify(P)); } catch { /* 配额满等忽略 */ }
  }

  function applyParamChange(mode) {
    applyDerived();
    if (mode === "measure") measure();
    else if (mode === "structural") rebuildScene();
    else if (mode === "strips") { rebakeStrips(); rebuildScene(); }
    if (ready) { recycle(); draw(); }
    requestRedraw();
  }

  const fmtVal = (v) => (Math.abs(v) >= 100 ? String(Math.round(v)) : String(Math.round(v * 100) / 100));

  function buildEditor() {
    const gear = document.createElement("button");
    gear.type = "button";
    gear.className = "corridor-gear";
    gear.title = "场景参数编辑器";
    gear.textContent = "⚙";
    const panel = document.createElement("div");
    panel.className = "corridor-editor";
    panel.hidden = true;
    const inputs = {};
    for (const [group, items] of EDITOR_FIELDS) {
      const head = document.createElement("div");
      head.className = "ce-group";
      head.textContent = group;
      panel.appendChild(head);
      if (group === "天空") {
        /* 天气预设按钮行 */
        const presetRow = document.createElement("div");
        presetRow.className = "ce-presets";
        const btns = [];
        const skyOptions = [
          { name: "随时间", v: -1 },
          ...SKY_PRESETS.map((preset, i) => ({ name: preset.name, v: i })),
        ];
        skyOptions.forEach((opt) => {
          const b = document.createElement("button");
          b.type = "button";
          b.textContent = opt.name;
          if (opt.v === Math.round(P.skyType)) b.classList.add("on");
          b.addEventListener("click", () => {
            P.skyType = opt.v;
            for (const other of btns) other.classList.remove("on");
            b.classList.add("on");
            persistParams();
            applyParamChange();
          });
          btns.push(b);
          presetRow.appendChild(b);
        });
        panel.appendChild(presetRow);
      }
      for (const [key, label, min, max, step, mode] of items) {
        const row = document.createElement("label");
        row.className = "ce-row";
        const name = document.createElement("span");
        name.textContent = label;
        const input = document.createElement("input");
        input.type = "range";
        input.min = String(min);
        input.max = String(max);
        input.step = String(step);
        input.value = String(P[key]);
        const val = document.createElement("em");
        val.textContent = fmtVal(P[key]);
        input.addEventListener("input", () => {
          P[key] = Number(input.value);
          val.textContent = fmtVal(P[key]);
          persistParams();
          applyParamChange(mode);
        });
        inputs[key] = { input, val };
        row.append(name, input, val);
        panel.appendChild(row);
      }
    }
    const foot = document.createElement("div");
    foot.className = "ce-foot";
    const reset = document.createElement("button");
    reset.type = "button";
    reset.textContent = "恢复默认";
    reset.addEventListener("click", () => {
      Object.assign(P, CORRIDOR_DEFAULTS);
      persistParams();
      for (const k in inputs) {
        inputs[k].input.value = String(P[k]);
        inputs[k].val.textContent = fmtVal(P[k]);
      }
      panel.querySelectorAll(".ce-presets button").forEach((b, i) => {
        b.classList.toggle("on", i - 1 === Math.round(P.skyType));
      });
      applyDerived();
      measure();
      rebakeStrips();
      rebuildScene();
      if (ready) { recycle(); draw(); }
      requestRedraw();
    });
    foot.appendChild(reset);
    panel.appendChild(foot);
    gear.addEventListener("click", () => { panel.hidden = !panel.hidden; });
    viewport.appendChild(gear);
    viewport.appendChild(panel);
  }

  function onKeyDown(e) {
    keys[e.code] = true;
    if (e.code === "Space") {
      e.preventDefault();
      autoForward = !autoForward;
    }
    requestRedraw();
  }
  function onKeyUp(e) {
    keys[e.code] = false;
  }

  function setMoving(on) {
    if (on) {
      if (keyboard) return;
      traveling = true;
      travelGoal = camZ + STAGE_STEP;
      requestRedraw();
      return;
    }
    speed = 0;
    if (traveling) finishTravel(false);
    traveling = false;
    travelGoal = camZ;
  }

  function travelForward(distance = STAGE_STEP) {
    if (keyboard) return Promise.resolve(false);
    if (traveling) return Promise.resolve(false);
    traveling = true;
    travelGoal = camZ + Math.max(80, distance);
    requestRedraw();
    return new Promise((resolve) => {
      travelResolve = resolve;
    });
  }

  if (keyboard) {
    document.addEventListener("keydown", onKeyDown);
    document.addEventListener("keyup", onKeyUp);
  }

  const onResize = () => {
    measure();
    /* 同步重绘：不给“清空后的黑帧”留出显示窗口。 */
    if (ready) {
      recycle();
      draw();
    }
    requestRedraw();
  };
  const ro = typeof ResizeObserver === "function" ? new ResizeObserver(onResize) : null;
  ro?.observe(viewport);
  ro?.observe(host);
  window.addEventListener("resize", onResize);

  measure();
  buildEditor();
  requestRedraw();

  /* 调试钩子：截图脚本用（设置参数 / 直接指定当前时刻）。 */
  window.__corridorSet = (k, v) => { P[k] = v; applyParamChange(); };
  window.__corridorSetHour = (h) => {
    P.dayStart = h - (camZ / STAGE_STEP) * 2;
    applyParamChange();
  };

  return {
    setMoving,
    travelForward,
    syncFromState() {
      /* 位移由 travelForward / setMoving 驱动，不跟关卡号缓漂 */
    },
    destroy() {
      alive = false;
      cancelAnimationFrame(raf);
      raf = 0;
      finishTravel(false);
      ro?.disconnect();
      window.removeEventListener("resize", onResize);
      if (keyboard) {
        document.removeEventListener("keydown", onKeyDown);
        document.removeEventListener("keyup", onKeyUp);
      }
      host.innerHTML = "";
    },
  };
}
