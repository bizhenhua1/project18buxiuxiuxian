/**
 * 走廊渲染器：单 <canvas> 画家算法伪 3D，多主题（THEMES 注册表）。
 * 针孔投影 sx = cx + x*f/z，远→近排序绘制；
 * 深度压暗 = 每帧按相机相对深度画"本体 + 黑剪影(连续 alpha)"两笔，
 * 完全连续无台阶；雾带只垫在所有精灵之下（纯地面/天空氛围，永不盖精灵）；
 * 静止时零重绘。
 *
 * 主题体系：THEMES 登记每个主题的资产清单/图层开关/氛围参数（森林 forest、
 * 洞穴 cave、云海 cloudsea……），按推进关数分段自动轮换（P.themeSegment 关一段），
 * 段落边界处做全黑淡入淡出过渡，主题资产懒加载、在黑幕下完成替换。
 */

export const CORRIDOR_VERSION = "canvas27";
/** @deprecated 兼容保留：基线森林主题目录。运行时以 THEMES[*].base 为准。 */
export const CORRIDOR_BASE = "assets/corridor/forest/";
export const STAGE_STEP = 420;

/* ---- 世界参数（世界单位） ---- */
const Z_NEAR = 26;          // 初始铺设的近端
const Z_EXIT = 9;           // 比这更近才回收：确保精灵先滑出画框再消失
const Z_FAR = 2100;         // 生成远端（> CULL_Z：新精灵生成时必然在剔除区内，不可见）

/* ---- 可调场景参数（场景参数编辑器实时读写，localStorage 持久化） ---- */
export const CORRIDOR_DEFAULTS = Object.freeze({
  themeMode: -1,     // 主题：-1=按推进分段自动轮换，>=0 = 固定 THEME_ORDER 下标
  themeSegment: 10,  // 自动轮换的分段长度（每多少关换一个主题）
  curveA1: 210,      // 主弯幅度（世界单位）
  curveL1: 1250,     // 主弯波长
  curveA2: 90,       // 次弯幅度
  curveL2: 470,      // 次弯波长
  curveLook: 40,     // 相机向前看的距离（入弯时视线略偏弯内）
  pathHalf: 55,      // 道路半宽
  treeDensity: 1,    // 侧景大件密度倍率（缩放各车道 z 间距）
  treeSize: 1,       // 侧景大件体型倍率
  grassCount: 95,    // 地被散铺数量
  lowCount: 70,      // 路面低层散铺数量
  flower: 1,         // 点缀变体权重倍率（0=只剩素件）
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
let CURVE_MUL = 1;       // 弯道幅度主题倍率（洞穴隧道更蜿蜒），换主题时更新
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
 * 远处的路便会左右摆出弯道（伪 3D 赛车的经典手法）。
 * CURVE_MUL 为主题弯道倍率（洞穴管道更蜿蜒），主题切换在全黑幕下
 * 完成，倍率跳变不会被看见。 */
function pathOffset(z) {
  return CURVE_MUL * (
    P.curveA1 * Math.sin(z / Math.max(1, P.curveL1) + 0.7)
    + P.curveA2 * Math.sin(z / Math.max(1, P.curveL2) + 2.3)
  );
}

/* 侧景车道：最外→内数条，最外圈用巨件专门封死超宽画幅的两侧与上角，
 * 路中央保持通透。step 收紧 + 抖动降幅，避免随机聚簇后留出可见缝隙。 */
const TREE_LANES = [
  { baseX: 560, spreadX: 120, size: 310, step: 30 },
  { baseX: 392, spreadX: 105, size: 252, step: 26 },
  { baseX: 268, spreadX: 85, size: 210, step: 34 },
  { baseX: 182, spreadX: 55, size: 178, step: 38 },
  { baseX: 122, spreadX: 32, size: 148, step: 50 },
];
/* 洞穴岩壁车道：柱体贴墙更紧，填满岩环立柱之间的缝隙。 */
const CAVE_LANES = [
  { baseX: 500, spreadX: 110, size: 300, step: 30 },
  { baseX: 340, spreadX: 80, size: 240, step: 28 },
  { baseX: 228, spreadX: 48, size: 190, step: 34 },
  { baseX: 152, spreadX: 26, size: 150, step: 46 },
];
/* 云海云墙车道：隆起云墙拔高聚拢，左右围成云谷（体型比树更高大）。 */
const CLOUD_LANES = [
  { baseX: 540, spreadX: 110, size: 380, step: 30 },
  { baseX: 372, spreadX: 88, size: 308, step: 28 },
  { baseX: 248, spreadX: 58, size: 252, step: 34 },
  { baseX: 164, spreadX: 30, size: 204, step: 44 },
];

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

/* =====================================================================
 * 主题注册表：每个主题一份"资产清单 + 图层结构 + 氛围参数"。
 * 字段契约（新主题按此登记，另见 assets/corridor/SCENE-SPEC.md 登记表）：
 *   label          中文名（编辑器按钮/状态栏）
 *   base           资产目录
 *   sky            true = 程序渐变天空随昼夜演变，配日月/云/远山；
 *                  false = 封闭场景（顶部由岩拱等实体封死），无天体
 *   skyPreset      封闭场景的固定氛围预设（结构同 SKY_PRESETS 单项）：
 *                  stops 画顶部微渐变，haze 决定雾带颜色（洞穴=暗紫），
 *                  amb 环境光；sky:true 的主题不需要此字段
 *   bigs / lanes   侧景大件位图清单（树/岩柱）与车道排布
 *   deco           地被散件清单（草/花 | 石笋/蘑菇/水晶/尸骨/灯笼/碎石）
 *   decoWeights    散铺权重（主体素件合计 ≥0.8，点缀 ≤0.2）
 *   decoAccent     点缀标记（受 P.flower "点缀密度"倍率调制）
 *   lowVariants    路面低层用的"无点缀素件"下标（低草/碎石带）
 *   decoSize/lowDecoSize   散铺件世界尺寸基准
 *   stampH/lowStampH       条带烘焙印章世界高 [基准, 随机幅度]
 *   farLayers      远景剪影层（森林=远山；洞穴无——远处只有黑暗）
 *   cloud/sun/moon 高空动态件与日月素材（无则 null）
 *   ground         Mode-7 地面纹理；groundFallback 加载失败的渐变色标
 *   rings          环形切片层（洞穴岩环）：{ images, cache, spacing,
 *                  size, sizeJitter }——沿 z 每 spacing 放一圈，
 *                  顶部岩拱+左右岩壁立柱环形包围，随 pathOffset 蜿蜒
 *   curveMul       弯道幅度倍率（洞穴管道转弯更明显）
 *   dimColor       深度压暗的目标色：黑 = 传统"没入黑暗"（森林/洞穴）；
 *                  亮色（云海=雾金白）= 远方精灵/雾带压向亮雾而非黑暗，
 *                  第二笔剪影改用该色的染色变体
 *   floaters       悬浮件（云海浮空碎石）：{ images, cache, count,
 *                  alt: [基准, 随机幅度] }——不贴地，锚在悬浮高度上，
 *                  小幅正弦上下浮动
 *   seaDrift       true = 密植条带整体做极慢横向漂移（云海层叠云面），
 *                  漂速挂在云风 P.cloudWind 上
 *   fullWidthStrips true = 条带全宽铺满、不为道路让口（云海：脚下就是
 *                  层叠云海，无道路裁剪——实心云块被区段裁剪会切出直边）
 * ===================================================================== */
export const THEMES = {
  forest: {
    label: "森林",
    base: "assets/corridor/forest/",
    sky: true,
    bigs: [
      { name: "tree-side.png", cache: 768 },
      { name: "tree-b.png", cache: 768 },
      { name: "tree-c.png", cache: 768 },
    ],
    lanes: TREE_LANES,
    deco: [
      { name: "grass-1.png", cache: 256 },
      { name: "grass-2.png", cache: 256 },
      { name: "grass-3.png", cache: 256 },
      { name: "grass-4.png", cache: 256 },
      { name: "foliage.png", cache: 256 },
    ],
    /* 素草/蕨为主，红花粉苞只做点缀，避免草甸变花海。 */
    decoWeights: [0.55, 0.05, 0.04, 0.28, 0.08],
    decoAccent: [false, true, true, false, true],
    lowVariants: [0, 3],
    decoSize: 34,
    lowDecoSize: 20,
    stampH: [18, 26],
    lowStampH: [6, 7],
    farLayers: [
      { name: "mtn-far.png", dim: 0.55 },
      { name: "mtn-near.png", dim: 0.4 },
    ],
    cloud: "cloud-strip.png",
    sun: "sun.png",
    moon: "moon.png",
    ground: "ground-tile.png",
    groundFallback: [[0, "#000000"], [0.22, "#0c1607"], [0.55, "#1a2c0f"], [1, "#2a4418"]],
    rings: null,
    curveMul: 1,
    dimColor: "#000000",
  },
  cave: {
    label: "洞穴",
    base: "assets/corridor/cave/",
    sky: false,
    /* 封闭洞穴的固定氛围：顶部近黑微渐变，雾带融向暗紫，环境光冷紫。 */
    skyPreset: {
      name: "洞穴",
      haze: "#231433",
      cloudCap: 0.5,
      mtnCap: 0.5,
      fogUp: 0.5,
      amb: ["#8f7cc0", 0.42],
      stops: [[0, "#040308"], [0.55, "#0a0714"], [0.85, "#120b22"], [1, "#1a1030"]],
    },
    bigs: [
      { name: "pillar-a.png", cache: 768 },
      { name: "pillar-b.png", cache: 768 },
      { name: "pillar-c.png", cache: 768 },
    ],
    lanes: CAVE_LANES,
    deco: [
      { name: "deco-stalag-1.png", cache: 256 },
      { name: "deco-stalag-2.png", cache: 256 },
      { name: "deco-mushroom.png", cache: 256 },
      { name: "deco-crystal-a.png", cache: 256 },
      { name: "deco-crystal-b.png", cache: 256 },
      { name: "deco-bones.png", cache: 256 },
      { name: "deco-lantern.png", cache: 256 },
      { name: "deco-rubble-1.png", cache: 256 },
      { name: "deco-rubble-2.png", cache: 256 },
    ],
    /* 石笋/碎石为主体，发光蘑菇/水晶/尸骨/灯笼做点缀。 */
    decoWeights: [0.24, 0.16, 0.06, 0.04, 0.03, 0.04, 0.03, 0.22, 0.18],
    decoAccent: [false, false, true, true, true, true, true, false, false],
    lowVariants: [7, 8],
    decoSize: 30,
    lowDecoSize: 18,
    stampH: [12, 18],
    lowStampH: [5, 6],
    farLayers: [],       // 洞穴远处只有黑暗，无远景层
    cloud: null,
    sun: null,
    moon: null,
    ground: "ground-tile.png",
    groundFallback: [[0, "#000000"], [0.3, "#07080d"], [0.65, "#0e1016"], [1, "#161a22"]],
    /* 岩环：顶部岩拱+左右岩壁立柱的环形切片，沿 z 等距排布，
     * 远处逐层没入黑暗、近处从暗中浮现（复用连续压暗管线）。 */
    rings: {
      images: ["arch-a.png", "arch-b.png"],
      cache: 1024,
      spacing: 250,
      size: 724,
      sizeJitter: 0.1,
    },
    curveMul: 1.3,
    dimColor: "#000000",
  },
  cloudsea: {
    label: "云海",
    base: "assets/corridor/cloudsea/",
    sky: true,
    bigs: [
      { name: "wall-a.png", cache: 768 },
      { name: "wall-b.png", cache: 768 },
      { name: "wall-c.png", cache: 768 },
    ],
    lanes: CLOUD_LANES,
    /* 地被 = puff 云团：散铺 + 烘成层叠云海条带（行式后流视差），
     * 路面低层 = 压矮云絮，中央通道浮着薄云。 */
    deco: [
      { name: "puff-1.png", cache: 300 },
      { name: "puff-2.png", cache: 300 },
      { name: "puff-3.png", cache: 300 },
      { name: "puff-4.png", cache: 300 },
    ],
    decoWeights: [0.3, 0.3, 0.22, 0.18],
    decoAccent: [false, false, false, false],
    lowVariants: [0, 3],
    decoSize: 46,
    lowDecoSize: 26,
    stampH: [22, 30],
    lowStampH: [8, 9],
    /* 浮空仙山：单件远景，悬在云海雾带之上，吃雾霾染色随天空演变；
     * 放在中央天空楔内偏右（两侧被云墙盖死，只有楔内可见）。 */
    farLayers: [
      { name: "island-far.png", dim: 0.5, single: true, h: 0.32, lift: 0.16, x: 0.54 },
    ],
    /* 天空全套复用森林素材：祥云条带 + 日月（同 style-e 画风）。 */
    cloud: "../forest/cloud-strip.png",
    sun: "../forest/sun.png",
    moon: "../forest/moon.png",
    /* 无 Mode-7 地面：脚下就是云海，条带层层铺满；垫底用亮雾渐变。 */
    ground: null,
    groundFallback: [[0, "#e8d9b9"], [0.45, "#cdd2d6"], [1, "#a9bac9"]],
    rings: null,
    curveMul: 1.1,
    /* 关键差异：远方压向雾金亮色而非黑暗——云上世界没有黑尽头。 */
    dimColor: "#e8d9b9",
    floaters: {
      images: ["rock-1.png", "rock-2.png", "rock-3.png", "rock-4.png"],
      cache: 320,
      count: 14,
      alt: [42, 110],
    },
    seaDrift: true,
    fullWidthStrips: true,
  },
};
/** 自动轮换顺序（P.themeMode >= 0 时也用作固定主题下标表）。 */
export const THEME_ORDER = ["forest", "cave", "cloudsea"];

const GROUND_TILE_WORLD = 150;  // 一块 512px 纹理对应的世界长度
const GROUND_SLICES = 48;
/* 密植条带：加载时把地被印章烘进横条，行进时按世界 z 行摆放并回收 */
const STRIP_VARIANTS = 4;
const STRIP_PX_W = 2048;
const STRIP_PX_H = 176;
const STRIP_WORLD_W = 680;      // 条带纹理对应的世界宽度
const STRIP_PPW = STRIP_PX_W / STRIP_WORLD_W;
const STRIP_WORLD_H = STRIP_PX_H / STRIP_PPW;
const ROW_SPACING = 54;
/* 低层条带（路面专用）：像素密度提高 1.5 倍（近景放大不糊），
 * 条带世界高压到 30，改为每行画两遍（错半个行距）来盖满行间。 */
const LOW_STRIP_VARIANTS = 3;
const LOW_STRIP_PX_W = 3072;
const LOW_PPW = LOW_STRIP_PX_W / STRIP_WORLD_W;
const LOW_STRIP_WORLD_H = 30;
const LOW_STRIP_PX_H = Math.round(LOW_STRIP_WORLD_H * LOW_PPW);

/* 路面低层不用独立素材：复用地被中的无点缀素件（主题 lowVariants），
 * 绘制时压矮拉宽——风格与两侧完全一致，透明通道天然干净。 */
const LOW_SQUASH_H = 0.62;   // 低层纵向压扁比
const LOW_STRETCH_W = 1.15;  // 低层横向加宽比

/** 主题地被变体加权随机（点缀类再乘 P.flower 倍率，动态归一化）。 */
function pickDecoVariant(cfg, rnd) {
  let total = 0;
  const w = [];
  for (let i = 0; i < cfg.decoWeights.length; i++) {
    w[i] = cfg.decoWeights[i] * (cfg.decoAccent[i] ? P.flower : 1);
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
function asset(cfg, name) {
  return `${cfg.base}${name}?v=${CORRIDOR_VERSION}`;
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

  /* ---- 相机 / 行进状态（先于主题逻辑声明：主题按 camZ 分段） ---- */
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
  let seaDrift = 0;        // 云海条带横向漂移累积（云海主题，挂在云风上）
  let raf = 0;
  let lastTs = 0;
  let alive = true;
  let dirty = true;
  let recycleSeed = 9000;

  /* ---- 主题状态 ----
   * 每个主题的位图缓存打包成 bundle 懒加载（Map 缓存，只加载一次）；
   * 切换 = 全黑淡出 → 黑幕下换 bundle + 重建场景 → 淡入，绝无闪帧。 */
  const themeBundles = new Map();   // id -> bundle
  const themeLoading = new Map();   // id -> Promise<bundle>
  /** 主题过渡：null 或 { target, phase: "out"|"in", alpha } */
  let transition = null;
  const TRANS_OUT_S = 0.45;  // 淡出到全黑
  const TRANS_IN_S = 0.7;    // 从全黑淡入新主题

  /** 关卡序号 → 主题 id（固定模式恒定；自动模式按分段轮换）。 */
  function themeForStage(stage) {
    if (P.themeMode >= 0) {
      return THEME_ORDER[Math.min(THEME_ORDER.length - 1, Math.round(P.themeMode))];
    }
    const seg = Math.max(1, Math.round(P.themeSegment));
    const idx = Math.floor(stage / seg);
    return THEME_ORDER[((idx % THEME_ORDER.length) + THEME_ORDER.length) % THEME_ORDER.length];
  }
  function curStage() {
    return Math.floor(camZ / STAGE_STEP + 1e-6);
  }

  let themeId = themeForStage(curStage());
  let T = THEMES[themeId];   // 当前主题配置
  let A = null;              // 当前主题资产 bundle（loadTheme 产出）
  CURVE_MUL = T.curveMul;

  const sprites = [];      // {id, kind, x, z, baseW, baseH, variant, flip}
  const clouds = [];       // 云层单独绘制：永远垫在树林之后（远山之前）
  let ready = false;
  let spriteId = 0;

  /** 懒加载主题资产：图片 → 精灵缓存 → 密植条带，全部进 bundle。 */
  function loadTheme(id) {
    if (themeBundles.has(id)) return Promise.resolve(themeBundles.get(id));
    if (themeLoading.has(id)) return themeLoading.get(id);
    const cfg = THEMES[id];
    const job = (async () => {
      const [bigImgs, decoImgs, farImgs, ringImgs, floatImgs, cloudImg, groundImg, sunI, moonI] = await Promise.all([
        Promise.all(cfg.bigs.map((t) => loadImage(asset(cfg, t.name)))),
        Promise.all(cfg.deco.map((g) => loadImage(asset(cfg, g.name)))),
        Promise.all(cfg.farLayers.map((s) => loadImage(asset(cfg, s.name)))),
        Promise.all((cfg.rings ? cfg.rings.images : []).map((n) => loadImage(asset(cfg, n)))),
        Promise.all((cfg.floaters ? cfg.floaters.images : []).map((n) => loadImage(asset(cfg, n)))),
        cfg.cloud ? loadImage(asset(cfg, cfg.cloud)) : null,
        cfg.ground ? loadImage(asset(cfg, cfg.ground)) : null,
        cfg.sun ? loadImage(asset(cfg, cfg.sun)) : null,
        cfg.moon ? loadImage(asset(cfg, cfg.moon)) : null,
      ]);
      const bundle = {
        bigCaches: bigImgs.map((img, i) => (img ? buildSpriteCache(img, cfg.bigs[i].cache) : null)),
        decoCaches: decoImgs.map((img, i) => (img ? buildSpriteCache(img, cfg.deco[i].cache) : null)),
        farCaches: farImgs.map((img) => (img ? buildSkyCache(img) : null)),
        ringCaches: ringImgs.map((img) => (img ? buildSpriteCache(img, cfg.rings.cache) : null)),
        floatCaches: floatImgs.map((img) => (img ? buildSpriteCache(img, cfg.floaters.cache) : null)),
        cloudCaches: [],
        lowCaches: [],
        stripCaches: [],
        lowStripCaches: [],
        groundTile: groundImg || null,
        sunImg: sunI || null,
        moonImg: moonI || null,
        flowerBaked: P.flower,
      };
      if (cloudImg) {
        /* 按透明列自动分簇：避免固定等分把云切出直边。
         * 缓存上限 768：云在近处会放大到数百像素，精度必须留足。 */
        for (const c of sliceCloudClusters(cloudImg)) {
          bundle.cloudCaches.push(buildSpriteCache(c, 768));
        }
      }
      /* 个别图加载失败时用已加载变体顶替，保证任何精灵（含回收重掷）都有位图可画。 */
      const bigFallback = bundle.bigCaches.find(Boolean) || null;
      const decoFallback = bundle.decoCaches.find(Boolean) || null;
      const ringFallback = bundle.ringCaches.find(Boolean) || null;
      const floatFallback = bundle.floatCaches.find(Boolean) || null;
      for (let i = 0; i < bundle.bigCaches.length; i++) if (!bundle.bigCaches[i]) bundle.bigCaches[i] = bigFallback;
      for (let i = 0; i < bundle.decoCaches.length; i++) if (!bundle.decoCaches[i]) bundle.decoCaches[i] = decoFallback;
      for (let i = 0; i < bundle.ringCaches.length; i++) if (!bundle.ringCaches[i]) bundle.ringCaches[i] = ringFallback;
      for (let i = 0; i < bundle.floatCaches.length; i++) if (!bundle.floatCaches[i]) bundle.floatCaches[i] = floatFallback;
      /* 路面低层直接引用无点缀素件的缓存，绘制时再压矮拉宽。 */
      for (const vi of cfg.lowVariants) bundle.lowCaches.push(bundle.decoCaches[vi] || decoFallback);
      buildStrips(bundle, cfg);
      themeBundles.set(id, bundle);
      themeLoading.delete(id);
      return bundle;
    })();
    themeLoading.set(id, job);
    return job;
  }

  function jitterBig(s, seedA, seedB) {
    const cfg = T.lanes[s.lane];
    s.x = s.side * (cfg.baseX + (hash(seedA, 5 + s.lane) - 0.5) * 2 * cfg.spreadX);
    s.variant = Math.floor(hash(seedA, seedB) * T.bigs.length) % T.bigs.length;
    s.flip = hash(seedA, seedB + 4) > 0.5;
    const size = cfg.size * P.treeSize * (0.84 + hash(seedA, seedB + 8) * 0.36);
    s.baseH = size;
    s.baseW = size;
  }

  function jitterDeco(s, seedA, seedB) {
    if (s.low) {
      /* 路面低层：只落在道路区域内；同款素件压矮拉宽，读作贴地碎草/碎石。 */
      s.x = (hash(seedA, seedB) - 0.5) * 2 * (PATH_HALF * 0.95);
      s.variant = Math.floor(hash(seedA, seedB + 2) * T.lowVariants.length) % T.lowVariants.length;
      const size = T.lowDecoSize * (0.7 + hash(seedA, seedB + 6) * 0.6);
      s.baseH = size * LOW_SQUASH_H;
      s.baseW = size * LOW_STRETCH_W;
    } else {
      /* 地被散件：让开中央道路，只落在两侧与岩壁/林墙根部。 */
      const side = hash(seedA, seedB + 1) > 0.5 ? 1 : -1;
      s.x = side * (PATH_HALF + 12 + hash(seedA, seedB) * (330 - PATH_HALF - 12));
      s.variant = pickDecoVariant(T, hash(seedA, seedB + 2));
      const size = T.decoSize * (0.7 + hash(seedA, seedB + 6) * 0.6);
      s.baseH = size;
      s.baseW = size;
    }
    s.flip = hash(seedA, seedB + 3) > 0.5;
    /* 根部下沉 4%~8%：让根部穿插进地面/后方丛簇，避免底边排成直线。 */
    s.sink = 0.04 + hash(seedA, seedB + 9) * 0.04;
  }

  /** 浮空碎石（云海）：散布两侧云通道，悬浮高度锚点 + 正弦上下浮动参数。 */
  function jitterRock(s, seedA) {
    const fl = T.floaters;
    const side = hash(seedA, 61) > 0.5 ? 1 : -1;
    s.x = side * (PATH_HALF + 46 + hash(seedA, 62) * 190);
    s.variant = Math.floor(hash(seedA, 63) * fl.images.length) % fl.images.length;
    s.flip = hash(seedA, 64) > 0.5;
    const size = 40 + hash(seedA, 65) * 44;
    s.baseW = size;
    s.baseH = size;
    s.alt = fl.alt[0] + hash(seedA, 66) * fl.alt[1];   // 悬浮高度（世界单位，不贴地）
    s.bobPhase = hash(seedA, 67) * Math.PI * 2;
    s.bobAmp = 2.5 + hash(seedA, 68) * 3.5;            // 上下浮动幅度
    s.bobSpeed = 0.5 + hash(seedA, 69) * 0.5;          // 浮动角速度（rad/s）
  }

  /** 岩环切片（洞穴）：中心跟随道路，尺寸/变体/镜像随机微调。 */
  function jitterRing(s, seedA) {
    const rings = T.rings;
    s.x = (hash(seedA, 91) - 0.5) * 16;
    s.variant = Math.floor(hash(seedA, 93) * rings.images.length) % rings.images.length;
    s.flip = hash(seedA, 95) > 0.5;
    const size = rings.size * (1 + (hash(seedA, 97) - 0.5) * 2 * rings.sizeJitter);
    s.baseW = size;
    s.baseH = size;
  }

  function buildScene() {
    let seed = 1;
    /* 侧景大件：左右各数条车道（外侧大、内侧小），z 密布 + 抖动，
     * 多道错相排布让大件前后交叠成连续侧墙。 */
    for (const side of [-1, 1]) {
      for (let lane = 0; lane < T.lanes.length; lane++) {
        const cfg = T.lanes[lane];
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
          jitterBig(s, seed, 11);
          sprites.push(s);
          seed++;
        }
      }
    }
    /* 岩环切片：沿 z 等距一圈圈排布（洞穴主题），随精灵一起画家排序。 */
    if (T.rings) {
      const spacing = T.rings.spacing;
      const count = Math.ceil((Z_FAR - Z_NEAR) / spacing);
      for (let i = 0; i < count; i++) {
        const s = { id: spriteId++, kind: "ring", z: Z_NEAR + 40 + i * spacing };
        s.zSpan = count * spacing;
        jitterRing(s, seed);
        sprites.push(s);
        seed++;
      }
    }
    /* 浮空碎石：散布两侧云通道的悬浮件，随精灵一起画家排序。 */
    if (T.floaters) {
      const FLOAT_FAR = FOG_END + 40;
      for (let i = 0; i < T.floaters.count; i++) {
        const s = { id: spriteId++, kind: "rock", z: Z_NEAR + hash(seed, 77) * (FLOAT_FAR - Z_NEAR) };
        s.zSpan = FLOAT_FAR - Z_EXIT;
        jitterRock(s, seed);
        sprites.push(s);
        seed++;
      }
    }
    /* 云朵：挂在高空的世界物件，随前进迎面漂来（单独层，树永远遮住云）。 */
    if (T.cloud) {
      for (let i = 0; i < P.cloudCount; i++) {
        const s = { id: spriteId++, z: 260 + hash(seed, 71) * (Z_FAR - 260) };
        jitterCloud(s, seed);
        clouds.push(s);
        seed++;
      }
    }
    /* 地被散铺：全宽（含路中央与侧墙下）做近景细节，回收时重掷。
     * 远端铺到 FOG_END 之外：新散件进入视野时 alpha=0，从黑暗中淡入。 */
    const DECO_FAR = FOG_END + 40;
    for (let i = 0; i < P.grassCount; i++) {
      const s = { id: spriteId++, kind: "grass", low: false, z: Z_NEAR + hash(seed, 31) * (DECO_FAR - Z_NEAR) };
      s.zSpan = DECO_FAR - Z_EXIT;
      jitterDeco(s, seed, 17);
      sprites.push(s);
      seed++;
    }
    /* 路面低层散铺：道路区域的近景细节。 */
    for (let i = 0; i < P.lowCount; i++) {
      const s = { id: spriteId++, kind: "grass", low: true, z: Z_NEAR + hash(seed, 33) * (DECO_FAR - Z_NEAR) };
      s.zSpan = DECO_FAR - Z_EXIT;
      jitterDeco(s, seed, 19);
      sprites.push(s);
      seed++;
    }
    /* 密植条带行：等距世界 z 行，随精灵一起进画家排序（与大件正确穿插）。 */
    const rowCount = Math.ceil((DECO_FAR - Z_NEAR) / ROW_SPACING);
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

  /** 把地被印章烘进横向条带（环绕式落章，普通 repeat 平铺即无缝），
   *  同时预烘黑剪影副本，压暗与其它精灵完全一致（连续 alpha）。 */
  function buildStrips(bundle, cfg) {
    const pool = bundle.decoCaches.filter(Boolean);
    if (!pool.length) return;
    for (let v = 0; v < STRIP_VARIANTS; v++) {
      const c = document.createElement("canvas");
      c.width = STRIP_PX_W;
      c.height = STRIP_PX_H;
      const g = c.getContext("2d");
      const STAMPS = 170;
      for (let i = 0; i < STAMPS; i++) {
        const idx = pickDecoVariant(cfg, hash(i, v * 7 + 61));
        const cache = pool[Math.min(idx, pool.length - 1)];
        const worldH = cfg.stampH[0] + hash(i, v * 7 + 63) * cfg.stampH[1];
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
      bundle.stripCaches.push({ img: c, sil: bakeSilhouette(c) });
    }
    /* 路面低层条带：更矮、无点缀，铺在道路区域。 */
    const lowPool = bundle.lowCaches.filter(Boolean);
    if (!lowPool.length) return;
    for (let v = 0; v < LOW_STRIP_VARIANTS; v++) {
      const c = document.createElement("canvas");
      c.width = LOW_STRIP_PX_W;
      c.height = LOW_STRIP_PX_H;
      const g = c.getContext("2d");
      const STAMPS = 260;
      for (let i = 0; i < STAMPS; i++) {
        const cache = lowPool[Math.floor(hash(i, v * 9 + 141) * lowPool.length) % lowPool.length];
        const worldH = cfg.lowStampH[0] + hash(i, v * 9 + 143) * cfg.lowStampH[1];
        const dh = worldH * LOW_PPW;
        /* 同款素件压矮：宽度按“原始比例 ÷ 压扁比 × 加宽比”放大，读作贴地矮层。 */
        const dw = dh * (cache.img.width / cache.img.height) * (LOW_STRETCH_W / LOW_SQUASH_H);
        const x = hash(i, v * 9 + 147) * LOW_STRIP_PX_W;
        /* 单株矮件盖不满行距：让落点纵向铺满整条带，行与行才能咬合无缝。 */
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
      bundle.lowStripCaches.push({ img: c, sil: bakeSilhouette(c) });
    }
  }

  /** 当前生效的天空/氛围预设：封闭主题（洞穴）用主题固定预设；
   *  开放主题 skyType<0 随昼夜时钟自动过渡，否则用手选预设。 */
  function curSky() {
    if (T.skyPreset) return T.skyPreset;
    return P.skyType < 0 ? timeSky(dayHour()) : skyPreset();
  }

  /** 当前大气雾霾色（随 skyBright 变暗：天全黑时雾霾也退成黑）。 */
  function hazeRGB() {
    const hex = curSky().haze;
    const s = P.skyBright;
    return [1, 3, 5].map((i) => Math.round(parseInt(hex.slice(i, i + 2), 16) * s));
  }

  /** 剪影染色（懒烘焙）：按 (缓存, 颜色) 键控——同一位图可能同帧
   *  被雾霾色（远景/云）与主题压暗色 dimColor（云海亮雾）各染一份，
   *  单槽缓存会来回重烘，故用 Map；换天气渐变时旧色条目会缓慢累积，
   *  超过 8 份即清空重来（重烘只有几毫秒级、且极少发生）。 */
  function tintedSil(cache, color) {
    let tints = cache._tints;
    if (!tints) tints = cache._tints = new Map();
    let c = tints.get(color);
    if (!c) {
      if (tints.size > 8) tints.clear();
      c = document.createElement("canvas");
      c.width = cache.sil.width;
      c.height = cache.sil.height;
      const g = c.getContext("2d");
      g.drawImage(cache.sil, 0, 0);
      g.globalCompositeOperation = "source-in";
      g.fillStyle = color;
      g.fillRect(0, 0, c.width, c.height);
      tints.set(color, c);
    }
    return c;
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

  /** 远景层缓存：原图 + 黑剪影，绘制时按天气预设动态压暗
   *  （预烘死黑度会让亮天下的远山黑成一片，故改为运行时叠加）。 */
  function buildSkyCache(img) {
    const c = document.createElement("canvas");
    c.width = img.naturalWidth;
    c.height = img.naturalHeight;
    c.getContext("2d").drawImage(img, 0, 0);
    return { img: c, sil: bakeSilhouette(c) };
  }

  /* 初始主题加载：未就绪期间保持黑屏，首个可见帧必然是完整场景。 */
  loadTheme(themeId).then((bundle) => {
    A = bundle;
    ready = true;
    requestRedraw();
  });

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
          jitterBig(s, recycleSeed, 23);
          d?.recycles.push({ id: s.id, kind: s.kind, zRel: s.z - camZ, camZ });
        }
        while (s.z - camZ > Z_FAR) {
          s.z -= Z_FAR - Z_EXIT;
          recycleSeed++;
          jitterBig(s, recycleSeed, 29);
        }
      } else if (s.kind === "ring") {
        /* 岩环保持等距节奏：按整段跨度回收，只重掷变体/镜像/尺寸。 */
        while (s.z - camZ < Z_EXIT) {
          s.z += s.zSpan;
          recycleSeed++;
          jitterRing(s, recycleSeed);
          d?.recycles.push({ id: s.id, kind: s.kind, zRel: s.z - camZ, camZ });
        }
        while (s.z - camZ > Z_EXIT + s.zSpan) {
          s.z -= s.zSpan;
          recycleSeed++;
          jitterRing(s, recycleSeed);
        }
      } else if (s.kind === "rock") {
        while (s.z - camZ < Z_EXIT) {
          s.z += s.zSpan;
          recycleSeed++;
          jitterRock(s, recycleSeed);
          d?.recycles.push({ id: s.id, kind: s.kind, zRel: s.z - camZ, camZ });
        }
        while (s.z - camZ > Z_EXIT + s.zSpan) {
          s.z -= s.zSpan;
          recycleSeed++;
          jitterRock(s, recycleSeed);
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
          jitterDeco(s, recycleSeed, 37);
          d?.recycles.push({ id: s.id, kind: s.kind, zRel: s.z - camZ, camZ });
        }
        while (s.z - camZ > Z_EXIT + s.zSpan) {
          s.z -= s.zSpan;
          recycleSeed++;
          jitterDeco(s, recycleSeed, 41);
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

  /** 当前时刻（小时，0~24）：时钟挂在 camZ 上，一个 STAGE_STEP = 2 小时。
   *  洞穴等封闭主题里时钟照走（地下不见天日），回到地面时天色已自然推移。 */
  function dayHour() {
    const h = (P.dayStart + (camZ / STAGE_STEP) * 2) % 24;
    return h < 0 ? h + 24 : h;
  }

  /** 日月：左方升起→右方降下的圆弧。画在天空渐变之上、远山之下——
   *  升落时被远山/雾带自然吞没，行进中被树冠遮挡。 */
  function drawSunMoon(hy) {
    const hour = dayHour();
    const isSun = hour >= 6 && hour < 18;
    const img = isSun ? A.sunImg : A.moonImg;
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

  /** 远景层：完全静止的背景（真实远山在前进中几乎不动），
   *  镜像平铺（奇数块水平翻转）保证无缝。距离衰减 = 叠雾霾色剪影
   *  （大气透视：晴天远山融进亮天光而非黑暗），量 = min(层基础值, 预设上限)。 */
  function drawSkyLayers(hy) {
    if (!T.farLayers.length) return;
    const dimCap = 1 - P.skyBright * (1 - curSky().mtnCap);
    const [hr, hg, hb] = hazeRGB();
    const hazeColor = `rgb(${hr},${hg},${hb})`;
    for (let i = 0; i < T.farLayers.length; i++) {
      const layer = T.farLayers[i];
      const cache = A.farCaches[i];
      if (!cache) continue;
      const dim = Math.min(layer.dim, dimCap);
      const drawH = H * (layer.h ?? (i === 0 ? 0.24 : 0.34));
      const drawW = cache.img.width * (drawH / cache.img.height);
      const sil = tintedSil(cache, hazeColor);
      /* 单件远景（云海浮空仙山）：只画一座，悬在地平线上方 lift 处，
       * 底部被雾带亮雾自然吞没，读作"悬于云海之上"。 */
      if (layer.single) {
        const dx = W * (layer.x ?? 0.5) - drawW * 0.5;
        const by = hy - H * (layer.lift ?? 0);
        ctx.drawImage(cache.img, dx, by - drawH, drawW, drawH);
        if (dim > 0.004) {
          ctx.globalAlpha = dim;
          ctx.drawImage(sil, dx, by - drawH, drawW, drawH);
          ctx.globalAlpha = 1;
        }
        continue;
      }
      const bottomY = hy + (i === 0 ? 2 : 4);
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
    if (!A.cloudCaches.length) return;
    const cloudCam = camZ * CLOUD_PARALLAX;
    const [hr, hg, hb] = hazeRGB();
    const hazeColor = `rgb(${hr},${hg},${hb})`;
    for (const s of clouds) {
      const z = s.z - cloudCam;
      if (z < Z_EXIT || z > CULL_Z) continue;
      const cache = A.cloudCaches[Math.floor(s.vr * A.cloudCaches.length) % A.cloudCaches.length];
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
    const groundTile = A.groundTile;
    if (!groundTile) {
      const ground = ctx.createLinearGradient(0, hy, 0, H);
      for (const [pos, color] of T.groundFallback) ground.addColorStop(pos, color);
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
     * 地平线以下融向主题压暗色 dimColor：黑主题（森林/洞穴）保持
     * "尽头黑暗只属于通道内部"；亮主题（云海）整条雾带压向雾金亮色——
     * 云上世界的远方是亮雾而非黑暗。 */
    const up = H * 0.44 * (1 - P.skyBright * (1 - curSky().fogUp));
    const down = H * 0.55;
    const total = up + down;
    const pivot = up / total;
    const ease = (k) => k * k * (3 - 2 * k);
    const [hr, hg, hb] = hazeRGB();
    const dimHex = T.dimColor || "#000000";
    const [dr, dg, db] = [1, 3, 5].map((i) => parseInt(dimHex.slice(i, i + 2), 16));
    const DEEP = 0.8; // 地平线处雾霾色被压向 dimColor 的比例（1=纯 dimColor）
    const grad = ctx.createLinearGradient(0, hy - up, 0, hy + down);
    const STEPS = 6;
    for (let i = 0; i <= STEPS; i++) {
      const k = i / STEPS;
      const a = ease(k);
      const m = DEEP * a; // 不透明度越高越贴近 dimColor
      grad.addColorStop(
        pivot * k,
        `rgba(${Math.round(hr + (dr - hr) * m)},${Math.round(hg + (dg - hg) * m)},${Math.round(hb + (db - hb) * m)},${a.toFixed(4)})`
      );
    }
    for (let i = 1; i <= STEPS; i++) {
      const k = i / STEPS;
      grad.addColorStop(pivot + (1 - pivot) * k, `rgba(${dr},${dg},${db},${ease(1 - k).toFixed(4)})`);
    }
    ctx.globalAlpha = 1;
    ctx.fillStyle = grad;
    ctx.fillRect(0, Math.floor(hy - up), W, Math.ceil(total));
  }

  /** 本帧压暗剪影目标色（null = 传统黑，走 cache.sil 快路径）。 */
  let dimC = null;

  function draw() {
    if (!ready) return;
    const t0 = performance.now();
    dimC = T.dimColor && T.dimColor !== "#000000" ? T.dimColor : null;
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

    /* 1.5 天空/顶部：程序渐变（0=画幅顶，1=地平线），按预设取色标。
     * 开放主题随昼夜/天气演变；封闭主题（洞穴）为近黑微渐变，
     * 顶部实际由岩环拱层层封闭。skyBright 作为总亮度旋钮叠在黑底上。 */
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

    if (T.sky) {
      /* 1.8 日月：随推关时钟沿弧线运行（远山、云、树都会遮住它）。 */
      drawSunMoon(hy);
      /* 2. 静止远山 + 迎面漂来的祥云（云在树后，只从林隙/顶部露出）。 */
      drawSkyLayers(hy);
      drawClouds(hy, cx);
    }

    /* 3. Mode-7 扫描带地面：纹理 v 随 camZ 滚动。 */
    drawGround(hy);

    /* 4. 氛围雾带垫底：画在全部精灵之前，只影响地面/天空/远景。 */
    drawFogBand(hy);

    /* 5. 精灵严格全局画家排序：按相机相对深度远→近，等深用 id 稳定。 */
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
      const cache = s.kind === "tree" ? A.bigCaches[s.variant]
        : s.kind === "ring" ? A.ringCaches[s.variant]
        : s.kind === "rock" ? A.floatCaches[s.variant]
        : s.low ? A.lowCaches[s.variant]
        : A.decoCaches[s.variant];
      if (!cache) continue;
      const scale = focal / z;
      const sx = cx + (s.x + pathOffset(s.z) - camEff) * scale;
      /* 世界尺寸 × 内容占比 = 裁剪后内容的绘制尺寸；内容底边即落地点。 */
      const w = s.baseW * cache.wFrac * scale;
      const h = s.baseH * cache.hFrac * scale;
      if (sx + w * 0.5 < 0 || sx - w * 0.5 > W) continue;
      /* 统一地面锚点：所有精灵内容底边 = hy + CAM_H*scale；散件再随机下沉。 */
      let sy = hy + CAM_H * scale;
      if (s.kind === "grass") sy += h * s.sink;
      /* 浮空碎石：锚在悬浮高度上（不贴地），叠加小幅正弦上下浮动。 */
      else if (s.kind === "rock") {
        sy -= (s.alt + Math.sin(t0 / 1000 * s.bobSpeed + s.bobPhase) * s.bobAmp) * scale;
      }
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
        /* 第二笔剪影：alpha 为浮点连续值，压暗永远平滑。
         * 黑主题用预烘黑剪影，亮主题（云海）用 dimColor 染色变体——
         * 远方精灵融进亮雾而非黑暗。 */
        ctx.globalAlpha = fade * dark;
        drawClipped(dimC ? tintedSil(cache, dimC) : cache.sil, dx, dy, dw, dh);
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

    /* 7. 主题过渡黑幕：段落边界处淡出→黑幕下换主题→淡入。 */
    if (transition && transition.alpha > 0.001) {
      ctx.globalAlpha = Math.min(1, transition.alpha);
      ctx.fillStyle = "#000";
      ctx.fillRect(0, 0, W, H);
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

  /** 密植条带行：一行 = 预烘条带纹理沿 x 平铺（烘焙时环绕落章，普通平铺无缝）。
   *  高层条带让开中央道路（按该行深度算出路缘），路面用低层条带铺；
   *  两者边界略微重叠，避免露出直缝。压暗/淡入与精灵同一套连续曲线。 */
  function drawGrassRow(s, z, hy, cx, camEff, frameRec) {
    const cache = A.stripCaches[s.variant];
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
    /* 云海条带整体极慢横向漂移（挂在云风上），层叠云面缓缓流动。 */
    const u = s.uShift + (T.seaDrift ? seaDrift : 0);
    /* 全宽模式（云海）：层叠云海铺满整幅、不为道路让口——实心云块
     * 被路缘区段裁剪会切出笔直硬边；路面低层条带同理跳过。 */
    if (T.fullWidthStrips) {
      tileStrip(cache, u, scale, sy, h, fade, dark, cx, bend - camEff, [[0, W]]);
      if (frameRec) {
        frameRec.sprites.push({
          id: s.id, kind: "grassRow", z: Math.round(z * 10) / 10,
          dark: Math.round(dark * 1000) / 1000,
          fade: Math.round(fade * 1000) / 1000,
          x: 0, y: Math.round(sy - h), w: W, h: Math.round(h),
        });
      }
      return;
    }
    /* 高层：路缘之外（左右两段） */
    tileStrip(cache, u, scale, sy, h, fade, dark, cx, bend - camEff,
      [[0, pathCx - phw * 0.92], [pathCx + phw * 0.92, W]]);
    /* 低层：路面之内（与高层边界重叠约 13%）。
     * 条带世界高只有 30、盖不满行距 54，同一行画两遍（错半个行距），
     * 近处不再叠成高墙，行间也不露黑地。颜色与两侧同一套压暗曲线。 */
    const lowCache = A.lowStripCaches[s.lowVariant];
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
        tileStrip(lowCache, u + du, sc2, sy2, lh, fade2, dark2, cx, bend2 - camEff,
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

  /** 把一条条带纹理沿 x 平铺，只画进给定的横向区段列表。
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
          drawClipped(dimC ? tintedSil(cache, dimC) : cache.sil, rx, dy, rw, dh, b0, b1);
        }
      }
    }
  }

  /** 只把落在视口内的部分交给栅格化（软件渲染下近树 2/3 在画外，省一大截）。
   *  可选 bx0/bx1：额外的横向裁剪边界（用于高层让路、低层限定路面）。 */
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

  /* ---- 主题切换 ---- */

  /** 黑幕下换主题：换配置/资产指针 + 重建场景。调用前必须处于全黑。 */
  function swapTheme(id) {
    themeId = id;
    T = THEMES[id];
    A = themeBundles.get(id);
    CURVE_MUL = T.curveMul;
    /* 点缀密度改过而该主题条带还是旧值：黑幕下顺手重烘。 */
    if (A.flowerBaked !== P.flower) rebakeStrips();
    rebuildScene();
    dirty = true;
  }

  /** 推进/参数变化后驱动主题过渡状态机（在 tick 中每帧调用）。 */
  function stepTheme(dt) {
    if (!ready) return;
    const want = themeForStage(curStage());
    if (!transition && want !== themeId) {
      transition = { target: want, phase: "out", alpha: 0 };
      loadTheme(want);
    }
    /* 预载下一段主题：临近段落边界提前拉资产，黑幕不用等加载。 */
    if (P.themeMode < 0) {
      const next = themeForStage(curStage() + 1);
      if (next !== themeId && !themeBundles.has(next)) loadTheme(next);
    }
    if (!transition) return;
    if (transition.phase === "out") {
      transition.alpha = Math.min(1, transition.alpha + dt / TRANS_OUT_S);
      /* 到达全黑后等资产就绪再换（懒加载慢时黑幕多停一会，不闪帧）。 */
      if (transition.alpha >= 1 && themeBundles.has(transition.target)) {
        if (transition.target !== themeId) swapTheme(transition.target);
        transition.phase = "in";
      }
    } else {
      transition.alpha = Math.max(0, transition.alpha - dt / TRANS_IN_S);
      if (transition.alpha <= 0) transition = null;
    }
    dirty = true;
  }

  /* ---- 主循环：仅在运动/脏帧/过渡时重绘，静止即停。 ---- */
  function loopNeeded() {
    if (keyboard) return true;
    return traveling || dirty || !!transition || Math.abs(speed) > 0.5
      || (ready && !!T.cloud && Math.abs(P.cloudWind) > 0.01);
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

    /* 主题状态机：跨段落边界（或编辑器改主题）→ 黑幕过渡换主题。 */
    stepTheme(dt);

    /* 云的独立横向风：真实时间驱动、与推进无关，驻足时也缓缓漂。
     * 前进中每帧生效（反正要重绘）；静止画面按位移阈值节流——
     * 攒够 ~0.6 世界单位才动一帧，rAF 空转开销可忽略。 */
    if (T.cloud && Math.abs(P.cloudWind) > 0.01) {
      windAcc += P.cloudWind * dt;
      if (moved || Math.abs(windAcc) > 0.6) {
        for (const s of clouds) {
          s.x += windAcc;
          if (s.x > CLOUD_X_WRAP) s.x -= CLOUD_X_WRAP * 2;
          else if (s.x < -CLOUD_X_WRAP) s.x += CLOUD_X_WRAP * 2;
        }
        /* 云海条带漂移：比高空云慢得多（层叠云面只微微流动），
         * 条带平铺按周期卷绕，不会跳变。 */
        if (T.seaDrift) {
          seaDrift = (seaDrift + windAcc * 0.35) % STRIP_WORLD_W;
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
      onStatus(`${mode} · ${T.label} · 深度 ${Math.abs(camZ | 0)} · canvas 画家算法`);
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

  /** 点缀权重改动后重烘当前主题的密植条带（几十毫秒级）。 */
  function rebakeStrips() {
    if (!A) return;
    A.stripCaches.length = 0;
    A.lowStripCaches.length = 0;
    buildStrips(A, T);
    A.flowerBaked = P.flower;
  }

  const EDITOR_FIELDS = [
    ["主题", [
      ["themeSegment", "分段关数", 2, 24, 1],
    ]],
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
    ["侧景", [
      ["treeDensity", "大件密度", 0.3, 2.5, 0.05, "structural"],
      ["treeSize", "大件体型", 0.6, 1.6, 0.02, "structural"],
    ]],
    ["地被", [
      ["grassCount", "地被散铺", 0, 220, 5, "structural"],
      ["lowCount", "路面低层", 0, 160, 5, "structural"],
      ["flower", "点缀密度", 0, 3, 0.1, "strips"],
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

  /** 预设按钮行（主题选择 / 天气预设共用）：点击写入 P[param]=v。 */
  function buildPresetRow(panel, param, options) {
    const presetRow = document.createElement("div");
    presetRow.className = "ce-presets";
    const btns = [];
    options.forEach((opt) => {
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = opt.name;
      b.dataset.param = param;
      b.dataset.v = String(opt.v);
      if (opt.v === Math.round(P[param])) b.classList.add("on");
      b.addEventListener("click", () => {
        P[param] = opt.v;
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
      if (group === "主题") {
        buildPresetRow(panel, "themeMode", [
          { name: "自动轮换", v: -1 },
          ...THEME_ORDER.map((id, i) => ({ name: THEMES[id].label, v: i })),
        ]);
      } else if (group === "天空") {
        buildPresetRow(panel, "skyType", [
          { name: "随时间", v: -1 },
          ...SKY_PRESETS.map((preset, i) => ({ name: preset.name, v: i })),
        ]);
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
      panel.querySelectorAll(".ce-presets button").forEach((b) => {
        b.classList.toggle("on", Number(b.dataset.v) === Math.round(P[b.dataset.param]));
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

  /* 调试钩子：截图脚本用（设置参数 / 直接指定当前时刻 / 立即切主题）。 */
  window.__corridorSet = (k, v) => { P[k] = v; applyParamChange(); };
  window.__corridorSetHour = (h) => {
    P.dayStart = h - (camZ / STAGE_STEP) * 2;
    applyParamChange();
  };
  /** 立即切主题（无黑幕过渡，等资产就绪后返回）——自动化验收专用。 */
  window.__corridorSetTheme = async (id) => {
    if (!THEMES[id]) return false;
    P.themeMode = THEME_ORDER.indexOf(id);
    await loadTheme(id);
    transition = null;
    swapTheme(id);
    if (ready) { recycle(); draw(); }
    requestRedraw();
    return true;
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
