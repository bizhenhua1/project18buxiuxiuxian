# 下水道：独立生产工单说明

运行配方：`scene-production/recipes/sewer.json`。撒布实现：`godot/scripts/spaces/layouts/biome_layout.gd`。
正式光照策略初始为 **atmospheric**，最终按实际光照审查，不由类型名强制封顶。

## 逐槽制作与检查

| 槽位 | 具体内容 | 新包变体起始数量 | 表达方式 |
|---|---|---|---|
| 砌石拱架 | plain brick arch, repaired arch, pipe-bearing arch | 3 | structural_cutout |
| 沟渠地面 | channel bed and paving tile | 2 | surface_texture |
| 边台 | straight curb, inner turn, outer turn | 3 | rigid_cutout |
| 出水口 | round outlet and grated outlet | 2 | attached_cutout |
| 污迹与碎屑 | damp stain, mineral crust, scrap, rubble | 4 | surface_decal |

以上是新包起始配额；旧参考图可直接复用，不为补数量重制。完整提示词位于对应 `jobs/workflow_sewer/`；需要生成前填写参考、尺寸、视角。

## 根点、拼组和空间特例

Channel water and walking ledge have different elevations. Arch supports land on ledge, outlets attach to a structural owner. No freestanding flat stain cards.

Brick vault skin + decorative arches every 4.15-5.9m + connected ledges. Curved junction curb has explicit inside/outside pieces. Pipe outlet owns water emitter origin.

One junction well owns roof, channel and ledges. Interior boundaries omitted; all outgoing channels connect before decoration. No extra left/right walls as a closure workaround.

## 光影及物效

Keep green-gray reference and sparse amber accents. Outflow terminates on channel water; no drips emitted from empty ceiling pixels.

必须对照正式/诊断图；实际光照自然时允许深色背景、天空盒和雾衔接。新增实时灯预算为0，优先共享现有环境光及发光材质。

## 执行顺序

1. 看 `review/sewer/index.html` 的完整源图和尺寸；复用原图则保留原adapter支点，换图则标注支点、占地/挂点并运行inspect。
2. 先计算尺寸和所有分支净空；不兼容的整框拆件或重制。
3. 主结构→功能组合→低装饰→光效，固定随机种子，不逐帧重撒布。
4. `python scripts/scene_production.py compile scene-production/recipes/sewer.json`。
5. 用 `capture --family sewer --recipe godot/data/scene_production/reference_sewer.json` 加上Godot路径与新输出目录，运行八镜头。
6. 检查正式效果优先、诊断问题按实际可见程度处理，再看源hash和原图分辨率。
7. 特例失败按OPEN-ISSUES登记；允许的暗部衔接记录为接受，不制造无限补顶工作。
8. 按WORKFLOW-RUNBOOK进行负载与最终审查，使用freeze检查后冻结包。

## 提交物

源图与提示词、参考hash、资产元数据、编译配方、八镜头正式/诊断图、源文件检查、明确问题及审查结果。工程流程跑通与用户视觉通过分别记账。
