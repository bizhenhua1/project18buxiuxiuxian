# 矿洞：独立生产工单说明

运行配方：`scene-production/recipes/crystal.json`。撒布实现：`godot/scripts/spaces/layouts/biome_layout.gd`。
正式光照策略初始为 **atmospheric**，最终按实际光照审查，不由类型名强制封顶。

## 逐槽制作与检查

| 槽位 | 具体内容 | 新包变体起始数量 | 表达方式 |
|---|---|---|---|
| 岩环 | narrow rock ring, asymmetric ring, broken decorative ring | 3 | structural_cutout |
| 独立大岩壁 | left rock buttress, right buttress, freestanding rock | 3 | rigid_cutout |
| 岩根碎石 | rubble, chips, grit, low stone shelf | 4 | rigid_cutout |
| 晶簇 | small shard group, angled cluster, large vein | 3 | rigid_cutout |
| 洞顶收口 | tileable rock ceiling skin and curved transition patch | 2 | surface_texture |

以上是新包起始配额；旧参考图可直接复用，不为补数量重制。完整提示词位于对应 `jobs/workflow_crystal/`；需要生成前填写参考、尺寸、视角。

## 根点、拼组和空间特例

Mark both ring supports and lower opening; rock overhang is not a support footprint. Crystal tips must not be used as floor anchors.

Ring spacing 4.25m is the old visual cadence, not roof closure. Continuous rock ceiling behind rings owns inter-ring gaps. Separate roots/rubble fill only ground contact seams.

Group corridor cross-sections by overlap; one common chamber while overlapping, split rings only after both supports clear all exits. Never stretch a complete ring across the junction.

## 光影及物效

Cool reference tint and limited crystal emissive accents. Ceiling drips originate on verified rock surface and terminate at ground; one pooled emitter group.

必须对照正式/诊断图；实际光照自然时允许深色背景、天空盒和雾衔接。新增实时灯预算为0，优先共享现有环境光及发光材质。

## 执行顺序

1. 看 `review/crystal/index.html` 的完整源图和尺寸；复用原图则保留原adapter支点，换图则标注支点、占地/挂点并运行inspect。
2. 先计算尺寸和所有分支净空；不兼容的整框拆件或重制。
3. 主结构→功能组合→低装饰→光效，固定随机种子，不逐帧重撒布。
4. `python scripts/scene_production.py compile scene-production/recipes/crystal.json`。
5. 用 `capture --family crystal --recipe godot/data/scene_production/reference_crystal.json` 加上Godot路径与新输出目录，运行八镜头。
6. 检查正式效果优先、诊断问题按实际可见程度处理，再看源hash和原图分辨率。
7. 特例失败按OPEN-ISSUES登记；允许的暗部衔接记录为接受，不制造无限补顶工作。
8. 按WORKFLOW-RUNBOOK进行负载与最终审查，使用freeze检查后冻结包。

## 提交物

源图与提示词、参考hash、资产元数据、编译配方、八镜头正式/诊断图、源文件检查、明确问题及审查结果。工程流程跑通与用户视觉通过分别记账。
