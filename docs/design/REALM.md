# 境界系统（REALM）· dao11

主角（道童）的经典修仙境界等级线：击杀妖兽得修为 → 层内攒满自动升层 → 九层圆满点「突破」进大境界。实现于 `js/realm.js`，存档 `localStorage["dao-realm-v1"]`。

## 体系表

| 大境界 | 层数 | 状态 |
|---|---|---|
| 炼气期 | 1~9 层 | 可达（初始） |
| 筑基期 | 1~9 层 | 可达 |
| 金丹期 | 1~9 层 | 可达 |
| 元婴期 | 1~9 层 | 可达 |
| 化神期 | 1~9 层 | 可达（第一版封顶，圆满后无突破按钮） |
| 炼虚/合体/大乘/渡劫 | — | 数据结构扩展位（`REALM_STAGES` 已登记，`ACTIVE_STAGES=5` 关门） |

称号格式：`炼气三层`、`筑基圆满`（第 9 层攒满显示"圆满"）。0 基的 `stage/layer` 只在代码内部使用。

## 修为获取

- **击杀入账**：每只敌方单位 `killExp = ⌈有效血量(maxHp) ÷ 10⌉`（有效血量含关卡成长倍率，随推关水涨船高，避免后期修为断供）。
- **Boss 关**（每图第 8 路点，`isBossStage`）：整单 ×3。
- **入账时机**：胜利结算 `settleVictory`（与掉落/收服同链路），loot-log 显示 `修为 +N`；战败不入账。
- **圆满封顶**：第 9 层攒满后修为停止累积，溢出丢弃（loot-log 标注"圆满溢出"）。

## 升层需求曲线

`need(stage, layer) = round(30 × 2^stage × 1.15^(stage×9 + layer))`（`EXP_BASE=30`、`EXP_GROWTH=1.15`、突破后 base ×2 跳档）。

| 大境界 | 首层需求 | 末层需求 | 全境界合计 |
|---|---|---|---|
| 炼气 | 30 | 92 | 503 |
| 筑基 | 211 | 646 | 3,543 |
| 金丹 | 1,485 | 4,543 | 24,928 |
| 元婴 | 10,448 | 31,962 | 175,386 |
| 化神 | 73,513 | 224,878 | 1,233,978 |

前期一关约入账 10~20 修为（5 只低级怪），2~3 关升一层；关卡怪血指数成长带动修为增长，但需求增速（1.15/层 + 突破跳档）更快，后期明显放缓，符合"越修越难"。

## 收益

- **每层**：道童 atk/maxHp ×1.02（复利；`applyPlayerMods` 内按 `mods.realmLayers` 计算，只作用于 `cardType === "char"`）。
- **每次突破**：额外 atk/maxHp ×1.10（复利，`mods.realmBreaks`）+ **1 点悟性**（天赋点）。
- 化神九层满修（44 层 + 4 次突破）≈ 攻血 ×3.5。
- 第一版不做格位解锁挂钩。

### 与天赋点经济的关系

`talentPoints(unlockStage, breakthroughs = breakthroughCount())` = 路点数 + Boss 数 + **突破次数**。突破给点与推关给点共存；`canAllocate/reconcile` 走同一函数，默认参数自动带上突破数，洗髓判定不误伤。境界 mods 以 `realmLayers/realmBreaks` 两个计数字段并入 `mergeMods(talentMods(), equipMods(), realmMods())`，与天赋/装备同一条聚合管线。

## 突破

- 条件：当前大境界圆满（`isFull`）且下一大境界在 `ACTIVE_STAGES` 内。
- 入口：修行面板「突破境界」按钮（金色呼吸光，非圆满时隐藏），点击立即成功 → 下一大境界 1 层、修为清零。
- 反馈：状态栏金色文字 + `realm-box` 闪光动画；第一版无失败/天劫。

## 展示与存档

- 修行面板：境界称号 + 金色修为细条（`#realm-bar`），悬浮显示 当前/需求、总修为、下一层（或突破）收益；道童卡面 tip 也带境界行。
- 存档字段 `{stage, layer, exp, totalExp}`；加载钳制：stage∈[0,4]、layer∈[0,8]、exp∈[0,need]（非圆满层不允许 exp≥need）、NaN/负数归零。
- 调试钩子：`__dao.realm() / addExp(n) / breakthrough() / resetRealm() / expPreview()`。

## 验收

`scripts/plan_realm.json`（击杀入账/Boss 三倍/升层+2%/存档钳制）+ `scripts/probe_breakthrough.py`（真实鼠标点突破按钮，验证 +10% 与 +1 悟性）。
