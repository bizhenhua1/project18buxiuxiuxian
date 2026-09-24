# 森林：独立生产工单说明

运行配方：`scene-production/recipes/forest.json`。撒布实现：`godot/scripts/spaces/layouts/forest_layout.gd`。
正式光照策略初始为 **open**，最终按实际光照审查，不由类型名强制封顶。

## 逐槽制作与检查

| 槽位 | 具体内容 | 新包变体起始数量 | 表达方式 |
|---|---|---|---|
| 主树干与根部 | old oak, split trunk, narrow trunk; root foot separate from canopy reach | 3 | rooted_cutout |
| 左右冠层 | left canopy, right canopy, overhead broken canopy | 3 | suspended_canopy |
| 中层灌木 | fern, broad shrub, bramble, sapling | 4 | rooted_cutout |
| 低草与落叶 | short grass, clover, leaf litter, fallen twigs | 4 | rooted_cutout |
| 远处林隙 | distant trunk mass and distant canopy mass | 2 | distant_cutout |

以上是新包起始配额；旧参考图可直接复用，不为补数量重制。完整提示词位于对应 `jobs/workflow_forest/`；需要生成前填写参考、尺寸、视角。

## 根点、拼组和空间特例

Tree trunk footprint only; canopy overhang may cross road. Grass roots follow terrain; rigid stumps use rigid support. Distant silhouettes never receive near-camera placement.

Tree+root grass: one owner and seed. Root cover 1-3 clumps around trunk footprint, never pasted over entire trunk; inherit terrain, not canopy wind.

All exits share a clearing. Exclude trunk footprints from union of routes; overhead canopy may span exits without creating a closed ceiling.

## 光影及物效

Preserve forest environment. Shared world-anchored curved mist, root-pinned foliage wind; no lamp per tree.

必须对照正式/诊断图；实际光照自然时允许深色背景、天空盒和雾衔接。新增实时灯预算为0，优先共享现有环境光及发光材质。

## 执行顺序

1. 看 `review/forest/index.html` 的完整源图和尺寸；复用原图则保留原adapter支点，换图则标注支点、占地/挂点并运行inspect。
2. 先计算尺寸和所有分支净空；不兼容的整框拆件或重制。
3. 主结构→功能组合→低装饰→光效，固定随机种子，不逐帧重撒布。
4. `python scripts/scene_production.py compile scene-production/recipes/forest.json`。
5. 用 `capture --family forest --recipe godot/data/scene_production/reference_forest.json` 加上Godot路径与新输出目录，运行八镜头。
6. 检查正式效果优先、诊断问题按实际可见程度处理，再看源hash和原图分辨率。
7. 特例失败按OPEN-ISSUES登记；允许的暗部衔接记录为接受，不制造无限补顶工作。
8. 按WORKFLOW-RUNBOOK进行负载与最终审查，使用freeze检查后冻结包。

## 提交物

源图与提示词、参考hash、资产元数据、编译配方、八镜头正式/诊断图、源文件检查、明确问题及审查结果。工程流程跑通与用户视觉通过分别记账。
