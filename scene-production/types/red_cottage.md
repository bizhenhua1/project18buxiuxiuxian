# 低顶室内：独立生产工单说明

运行配方：`scene-production/recipes/red_cottage.json`。撒布实现：`godot/scripts/spaces/layouts/fairytale_corridor.gd`。
正式光照策略初始为 **hybrid**，最终按实际光照审查，不由类型名强制封顶。

## 逐槽制作与检查

| 槽位 | 具体内容 | 新包变体起始数量 | 表达方式 |
|---|---|---|---|
| 梁架 | plain beam frame, repaired frame, asymmetric beam frame | 3 | structural_cutout |
| 连续天花材质 | seamless ceiling underside oak planks | 1 | surface_texture |
| 地板材质 | seamless worn floorboards | 1 | surface_texture |
| 生活功能组合 | hearth+firewood; sewing desk+cloth basket; chest+stool | 3 | rigid_cutout |
| 小物与碎屑 | pottery, rags, wood shavings, shoes | 4 | rigid_cutout |
| 吊挂装饰 | lantern+chain; dried herbs+cord; draped cloth+paired hooks | 3 | suspended_cutout |

以上是新包起始配额；旧参考图可直接复用，不为补数量重制。完整提示词位于对应 `jobs/workflow_red_cottage/`；需要生成前填写参考、尺寸、视角。

## 根点、拼组和空间特例

Furniture needs authored support points. Hanging fixtures use top sockets and lowest points, never bottom-center roots. A figure hanging by a rope is an explicit optional narrative asset, not randomly selected room dressing.

One continuous ceiling mesh across all exits. Beam supports must clear every path after scale. Hanging chain+body use one pivot; doorway frame is decoration, never proof of closure.

Single roof polygon union with continuous UV. Do not add left/right walls. Before a fork, preserve all exits; do not remove unselected roof while still visible.

## 光影及物效

Default hanging sway zero, optional <=2 degrees, <=8 moving fixtures. No physics chain, no per-fixture real light. Static soft ceiling material; no floor dirt texture reused as final ceiling.

必须对照正式/诊断图；实际光照自然时允许深色背景、天空盒和雾衔接。新增实时灯预算为0，优先共享现有环境光及发光材质。

## 执行顺序

1. 看 `review/red_cottage/index.html` 的完整源图和尺寸；复用原图则保留原adapter支点，换图则标注支点、占地/挂点并运行inspect。
2. 先计算尺寸和所有分支净空；不兼容的整框拆件或重制。
3. 主结构→功能组合→低装饰→光效，固定随机种子，不逐帧重撒布。
4. `python scripts/scene_production.py compile scene-production/recipes/red_cottage.json`。
5. 用 `capture --family red_cottage --recipe godot/data/scene_production/reference_red_cottage.json` 加上Godot路径与新输出目录，运行八镜头。
6. 检查正式效果优先、诊断问题按实际可见程度处理，再看源hash和原图分辨率。
7. 特例失败按OPEN-ISSUES登记；允许的暗部衔接记录为接受，不制造无限补顶工作。
8. 按WORKFLOW-RUNBOOK进行负载与最终审查，使用freeze检查后冻结包。

## 提交物

源图与提示词、参考hash、资产元数据、编译配方、八镜头正式/诊断图、源文件检查、明确问题及审查结果。工程流程跑通与用户视觉通过分别记账。
