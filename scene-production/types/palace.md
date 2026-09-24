# 宫殿：独立生产工单说明

运行配方：`scene-production/recipes/palace.json`。撒布实现：`godot/scripts/spaces/layouts/biome_layout.gd`。
正式光照策略初始为 **atmospheric**，最终按实际光照审查，不由类型名强制封顶。

## 逐槽制作与检查

| 槽位 | 具体内容 | 新包变体起始数量 | 表达方式 |
|---|---|---|---|
| 柱拱 | plain column arch, carved column arch, damaged column arch | 3 | structural_cutout |
| 石地面 | stone floor and vault surface | 2 | surface_texture |
| 柱脚装饰 | base plinth, rubble, small urn, fallen carving | 4 | rigid_cutout |
| 壁龛与灯具 | unlit fixture, sparse lamp, empty niche | 3 | attached_cutout |
| 地标 | statue group and ritual dais | 2 | rigid_cutout |

以上是新包起始配额；旧参考图可直接复用，不为补数量重制。完整提示词位于对应 `jobs/workflow_palace/`；需要生成前填写参考、尺寸、视角。

## 根点、拼组和空间特例

Two columns share module scale and support plane. Sculpture base defines grounding; niche is attached, never a floor prop.

Vault surface behind decorative column bays at 5.81-8.26m. The continuous roof closes shoulders and bay gaps. Sparse chandeliers occupy verified roof sockets.

Single crossing hall with pillars only between protected routes. Do not tile three complete facades across it.

## 光影及物效

Reference gray-green ambient and warm accents. Lamp emissive surface plus shared accent budget; no extra real light for each chandelier.

必须对照正式/诊断图；实际光照自然时允许深色背景、天空盒和雾衔接。新增实时灯预算为0，优先共享现有环境光及发光材质。

## 执行顺序

1. 看 `review/palace/index.html` 的完整源图和尺寸；复用原图则保留原adapter支点，换图则标注支点、占地/挂点并运行inspect。
2. 先计算尺寸和所有分支净空；不兼容的整框拆件或重制。
3. 主结构→功能组合→低装饰→光效，固定随机种子，不逐帧重撒布。
4. `python scripts/scene_production.py compile scene-production/recipes/palace.json`。
5. 用 `capture --family palace --recipe godot/data/scene_production/reference_palace.json` 加上Godot路径与新输出目录，运行八镜头。
6. 检查正式效果优先、诊断问题按实际可见程度处理，再看源hash和原图分辨率。
7. 特例失败按OPEN-ISSUES登记；允许的暗部衔接记录为接受，不制造无限补顶工作。
8. 按WORKFLOW-RUNBOOK进行负载与最终审查，使用freeze检查后冻结包。

## 提交物

源图与提示词、参考hash、资产元数据、编译配方、八镜头正式/诊断图、源文件检查、明确问题及审查结果。工程流程跑通与用户视觉通过分别记账。
