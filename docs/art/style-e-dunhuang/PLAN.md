# style-e 出图规划

选定风格：**风格五 · 敦煌矿物平涂（分体图鉴）**（`style-e`）。不改战斗 demo 规则；卡面方案 2 只换立绘皮。

## 资产分类

| type | 用途 | 进入卡面方案 2 的方式 |
| --- | --- | --- |
| `char` | 角色全身/3/4 身立绘 | `.s2-art` 背景图（竖构图，主体居中偏上） |
| `monster` | 怪物、精怪、坐骑（当敌或召唤物） | 同上，或池里的单位卡 |
| `artifact` | 法宝物件 | 技能图标 / 附加物；一般不当整张单位卡主图 |
| `sheet` | 多主体图鉴拼贴 | **不**进卡框；只作审核与提示词回归 |

卡面方案 2 结构（已实现，勿改逻辑）：上 2/3 立绘、名称、下圆血槽 + CD 环。立绘区很窄，需要**单主体、竖向剪影、平底或可抠底**。图鉴横图 `style-e-adapt-*.png` 不能直接贴进去。

建议数据侧（以后再接线，本次不改 js）：

```text
card.art = "assets/style-e-char-yangjian.png"
```

emoji 占位保留到真图齐套。

## 出图流程

### A. 图鉴拼贴（审核用）

- 比例 16:9。
- 模块：`base` + `palette` + `layout-sheet` + 多个 subject + `negative`。
- 文件名：`style-e-sheet-{theme}.png`（已有 adapt 可视为 sheet）。
- 过关：一眼数清主体、中间是空石青、没有地面。

### B. 单主体（生产用）

- 比例优先 3:4 或 9:16，贴近方案 2 立绘窗。
- 模块：`base` + `palette` + `layout-single` + 一个 subject + `negative`。
- **一次只画一个主体。** 法宝不要握在手里除非该卡就是「持器角色」；物件卡单独出 `artifact`。

### 文件命名

```text
style-e-{type}-{id}.png
```

- `type`：`char` | `monster` | `artifact` | `sheet`
- `id`：小写英文或拼音，无空格。例：`style-e-char-nezha.png`、`style-e-artifact-jinjiao-jian.png`、`style-e-monster-xiaotian.png`
- 审核图沿用已有：`style-e-dunhuang-v2.png`、`style-e-adapt-{slug}.png`（历史文件不改名）
- 迭代加后缀 `-r2`，不要覆盖通过 QC 的文件。

落盘目录：生产图仍放 `assets/`，或以后 `assets/style-e/`。

## 品质门槛（不过关就重出）

1. **剪影可读：** 缩小到卡面宽度仍能区分人/兽/器。  
2. **无环境：** 没有地平线、建筑、云海、洞窟墙。允许纯石青或浅壁画平涂。  
3. **主体分离：** sheet 上任何两件不相交、飘带不相连。  
4. **平涂：** 没有厚涂高光球体、没有照片级皮肤。  
5. **封神线不佛：** 无莲台、袈裟、手印、梵文；金圆若出现须小于头宽且无放射线。  
6. **哪吒绫 / 鞭：** 绫是独立物件；鞭不是锡杖。

## 已知风险

| 风险 | 表现 | 对策（写进 prompt） |
| --- | --- | --- |
| 金圆佛味 | 脑后大实心金盘 | 量产关闭；或改为小云纹/无背光 |
| 飘带飞天 | 长带绕身、人悬空 | 带画成独立法宝；人站实、短衣 |
| 哪吒绫 | 混天绫缠腰缠臂 | `Huntian silk as SEPARATE icon, not worn` |
| 鞭变锡杖 | 姜子牙长杖带穗环 | `whip or short rod, NOT khakkhara / monk staff` |
| 取经猿 | 白猿金箍棒 | 禁止紧箍与袈裟；用石绿腰带 |
| 横图进竖卡 | adapt 整图塞进 `.s2-art` | 只引用单主体 `char`/`monster` |

## 下一步（可执行）

1. **先出 4 张单主体竖图**（3:4）：`style-e-char-yangjian`、`style-e-char-daji`、`style-e-char-nezha`（绫不绕身）、`style-e-char-jiangshang`（鞭非杖）。用 `layout-single` + 关金圆，对照本目录 QC。  
2. **先出 6 张物件/兽图标**（1:1 或 3:4 平底）：刀、剪、印、旗、琵琶、四不像或哮天犬。确认缩小后仍可读。  
3. **做一张「关金圆」对照 sheet**：同一批封神五人，prompt 写明 no gold disc，对比 `style-e-adapt-*.png`，把更道的那版定为人物默认。  
4. **卡面方案 2 接线清单**（只列、先不改代码）：每个 `CARD_LIBRARY.id` 对应一个 `style-e-char-*` 或先共用一张占位；立绘 CSS 用 `background-image`，emoji 作 fallback。  
5. **冻结负面词：** 新图必须带 `negative.en.txt`；哪吒/姜子牙额外各贴一行绫/鞭约束。连续 3 张 QC 失败则改 subject 模块，不改 base。
