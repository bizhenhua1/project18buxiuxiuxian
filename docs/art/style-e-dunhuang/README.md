# 风格五 · 敦煌矿物平涂（分体图鉴）

- **正式名：** 风格五 · 敦煌矿物平涂（分体图鉴）
- **短 ID：** `style-e`
- **状态：** 已选定。v2 定画法；封神向 5 张 adapt 已验证可铺开（非佛门题材）。
- **参考图：** `assets/style-e-dunhuang-v2.png`（画法锚点）+ `assets/style-e-adapt-*.png`（题材适配）
- **规划：** 见同目录 [`PLAN.md`](./PLAN.md)

本风格吃的是**矿物平涂 + 平底 + 分体**，不是「整窟壁画叙事插画」。v1 `style-e-dunhuang.png` 有飞天群与环境，**不要当生产锚点**。

## 适用

| 用途 | 怎么用 | 备注 |
| --- | --- | --- |
| 主角 / 单位立绘 | 全身或 3/4 身剪影，平底 | 给卡面方案 2 的 `.s2-art` 用 |
| 怪物 | 独立兽形 / 面具 / 精怪，不当环境生物 | 图鉴或卡面均可 |
| 法宝 / 物件 | 单独成件，不绕身 | 最贴这套语言 |
| 卡面方案 2 | 只取**单个主体**抠进竖卡上部约 2/3 | 不要把整张图鉴拼贴塞进卡框 |
| 图鉴 / 选角屏 | 一张图多个主体，横排留白 | 仅用于审核画风与题材，不直接当卡图 |

不适合：场景插画、过场 CG、需要体积光与厚涂的传奇卡面（那是方案 A）。

## 视觉规则

1. **平涂矿物色：** 石青、石绿、朱砂、土黄、哑光矿物金。干净深色线，大色块，剪纸式剪影。
2. **无体积光：** 禁止写实光影、厚涂、3D 体积、粒子风暴。
3. **纯色平底：** 石青（首选）或浅壁画色。无地面透视、无云海、无宫殿、无洞窟墙当场景。
4. **分体：** 每个角色 / 法宝 / 怪物是独立 cutout，互不重叠、不缠绕、不前后景融合。
5. **金圆克制：** 主角脑后最多一块**小实心金圆当图形装饰**，不要万道光、莲台、佛光。封神量产时优先缩小或去掉（见适配结论）。
6. **可读性优先：** 10 米外仍能认出「人 / 兽 / 器」。少纹饰、少铭文、少飞天群。

出图时把 [`prompts/`](./prompts/) 模块拼进英文 description，不要只写 “Dunhuang style”。

## 禁止项

- 环境场景、整图叙事插画、云海战场、祭坛全景、瑶池、寺庙洞窟。
- 佛教符号当默认语言：袈裟、紫金钵、金刚杵、莲台、手印、梵文、木鱼、剃度头、金翅大鹏、夜叉护法（v2 探索图除外，量产封神线不要）。
- 缠绕飞天、绕身长绫把人画成供养人/飞天。
- 二次元萌（大眼、Q 版头身）、现代枪械、科幻装甲、可读文字墙。
- 万智牌厚涂、昆特泥地写实、工笔绢本细皴、青铜血光祭仪（那是 A–D）。

完整英文否定词见 [`prompts/negative.en.txt`](./prompts/negative.en.txt)。

## 与方案 A–D 的差异

| ID | 文件 | 气质 | 为何不选作主轴 |
| --- | --- | --- | --- |
| A | `style-a-mtg-oil(-v2).png` | 万智牌厚涂、轮廓光 | 细节与光影重，分体图鉴弱 |
| B | `style-b-gwent-grim(-v2).png` | 昆特北境暗调、泥地 | 写实脏旧，和矿物平涂相反 |
| C | `style-c-gongbi(-v2).png` | 绢本工笔、细线淡彩 | 线密、留白雅，剪影块面不够「牌面图标」 |
| D | `style-d-bronze-dark(-v2).png` | 殷商青铜、铜绿血光 | 适合截教暗线，不宜做全库主风格 |
| **E** | **`style-e-*`** | **敦煌矿物平涂、分体、无环境** | **已选定** |

A–D 的 v2 同样是平底分体，但色温与笔法不同；**生产只锁 E**，不要在同一套卡里混 A–D 笔触。

## 封神适配结论（2026-08-22）

五张 adapt 证明：画法可以离开佛门符号，铺到封神/道教向。

**顺（优先做）：**

- 兽形：哮天犬、九尾狐、蛟、白猿、龙须虎、四不像、双头蛇、饕餮头。
- 器：三尖刀、金蛟剪、翻天印、琵琶、杏黄旗、风火轮、乾坤圈（单独成件）。

**易佛（量产要改）：**

- 脑后**实心金圆** + 静立供养人站姿 → 壁画圣像。
- **绕身飘带 / 混天绫绕身** → 飞天。哪吒的绫必须单独成件。
- 打神鞭画成带穗长杖 → 锡杖。应画成鞭/短策，不是僧杖。
- 白猿 + 金箍长棍 → 取经猴。梅山猿用石绿腰带，不要袈裟和紧箍。

**人物：** 道髻、猎装/银甲、狐耳宫廷红、截教道袍都可以；少静立、少长飘带、少金圆，才更「封神」而不是「供养人」。

## 提示词怎么拼

顺序（全部英文）：

1. [`prompts/base.en.txt`](./prompts/base.en.txt) — 画风底座  
2. [`prompts/palette.txt`](./prompts/palette.txt) — 可整段贴，或只抽色名  
3. 构图：图鉴用 [`layout-sheet.en.txt`](./prompts/layout-sheet.en.txt)；卡面用 [`layout-single.en.txt`](./prompts/layout-single.en.txt)  
4. 主体：[`subject-character.en.txt`](./prompts/subject-character.en.txt) / [`subject-artifact.en.txt`](./prompts/subject-artifact.en.txt) / [`subject-monster.en.txt`](./prompts/subject-monster.en.txt)（把 `{…}` 换成具体名）  
5. [`prompts/negative.en.txt`](./prompts/negative.en.txt) — 每张都带  

历史实打实的 GenerateImage description（**原样，非重建**）在 [`prompts/history/`](./prompts/history/)。

## 历史出图索引

| 文件 | 角色 | 来源 |
| --- | --- | --- |
| [`history/style-e-dunhuang-v2.en.txt`](./prompts/history/style-e-dunhuang-v2.en.txt) | 行者、钵、圈、大鹏、夜叉 | 2026-08-22 GenerateImage，原样 |
| [`history/style-e-adapt-yangjian.en.txt`](./prompts/history/style-e-adapt-yangjian.en.txt) | 杨戬、犬、狐、蛟 | 同上 |
| [`history/style-e-adapt-nezha.en.txt`](./prompts/history/style-e-adapt-nezha.en.txt) | 哪吒、轮、石矶、龙太子 | 同上 |
| [`history/style-e-adapt-daji.en.txt`](./prompts/history/style-e-adapt-daji.en.txt) | 妲己、白狐、琵琶、猿、龙须虎 | 同上 |
| [`history/style-e-adapt-jiejiao.en.txt`](./prompts/history/style-e-adapt-jiejiao.en.txt) | 截教、金蛟剪、翻天印、双头蛇、饕餮 | 同上 |
| [`history/style-e-adapt-jiangshang.en.txt`](./prompts/history/style-e-adapt-jiangshang.en.txt) | 姜子牙、旗、四不像、申公豹 | 同上 |

说明：v2 仍含佛门行者，只作**画法**锚点。封神量产以 adapt 五张 + 模块提示词为准。v1 场景版未入库为生产 prompt。

## 后续如何扩展

1. 先做**单主体**角色立绘与法宝图标（命名见 PLAN），再考虑拼贴审核图。  
2. 金圆改为可选：道教线默认关，佛门线才开。  
3. 同一 ID 保持剪影稳定， variate 只换色块，不换结构。  
4. 卡面方案 2 只引用 `style-e-char-{id}.png` / `style-e-monster-{id}.png`，不要引用 `style-e-adapt-*.png` 整图。  
5. 新题材先出一张 16:9 分体审核图，过「无环境 / 主体分离 / 不佛」再拆单图。
