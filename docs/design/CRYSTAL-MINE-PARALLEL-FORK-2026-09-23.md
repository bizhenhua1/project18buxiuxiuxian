# 水晶矿洞：平行双岔编排（2026-09-23）

本方案只针对无门的水晶矿洞。它不是从交点永久斜向发散的 Y 形地图。主通道到达选择点后，两条路径在有限的过渡距离内横移，之后均恢复原始前进轴向；镜头前方的主拱形仍按同一世界轴横向排列。无门矿洞只开放两条路。三条路需要先有明确的关门洞口、开门切换和遮挡资产，此版本不生成。

## 几何与资产所有权

- `junction_s` 是选择与横移起点。横移长度为 `turn_length`，两条终点中心线各离原轴 265 世界单位。曲线为 `x = side * 265 * (3t²-2t³)`，`y=s`，`t=clamp((s-junction_s)/turn_length,0,1)`。端点横向导数为零，所以后续路线与原始方向平行。相邻完整主拱宽 420，稳定段两路中心距 530，保留 110 单位净距。
- 主通道始终使用原始 `shell.png`；入口左、右分别使用 `opening-left-v1.png` 和 `opening-right-v1.png`。左、右洞口的主要岩足共用一个地面基准。过渡段还有两级较窄的原始拱形，宽高等比缩放；稳定段恢复原始全拱。左右序列沿前进方向错开 34 单位，避免同一深度的拱顶排成机械的 M。
- 每个连续 `RouteRegion` 只生成落在自己区间内的拱形。尤其不能让后续区域重新生成同一洞口；这会在路中叠出岩柱。保留主路结构延续到选择点之后的一个共同拱形，双洞口在其后。拱形世界姿态始终是原轴的横断面；路线中心线、地面着色和角色移动都读取同一条横移曲线。
- 选择后仍能看到两条入口；未选道路在主角进入稳定平行段之后才渐退。这个退场不得在选择瞬间发生。镜头在横移期间限制转角，并让角色行进构图偏移使用同一镜头角，避免角色被带出画面。

## 环境底色

`BiomeCatalog.CONFIG` 的 `backdrop` 单独定义没有资产覆盖的环境底色。水晶矿洞为 `#000000`；巨鲸体内的示例为 `#15080d`。正式 3D 视图与路线预览均读取 `SpaceType.top_color`。这只决定资产之间露出的底色，不把黑色误当成已完成的实体顶部。

## 洞口资产来源与检查

两张洞口均以原始 `shell.png` 作风格参考，通过内置 imagegen 生成，保留透明背景与可通行中空。左洞口要求外侧左岩足较厚、内侧右岩足较薄；右洞口反向，且岩板形状独立。提示词核心为：`front-facing independent compact cave mouth, dark blue-gray angular slate matching shell.png, transparent exterior and central passage, feet sharing a ground baseline, asymmetrical outer/inner legs, no M-shaped double peak, no floor, no gate, no text, sparse subdued cyan mineral flecks`。这两张是独立资产，不是将一张图镜像成两侧。源图本身包含透明边距，底部支持点按 alpha 范围分别设在图高的 `.876` 与 `.959`，不能统一使用画布底边。

## 验证入口与当前界限

- 几何与生成数量：`godot --headless --path godot --script res://tests/test_crystal_parallel_fork.gd`，检查开放三岔被限定为双岔、横移结束后恢复平行、左右洞口各只有一个。
- 真实 3D 关键帧：`godot --path godot --script res://tests/capture_world3d_cave_fork.gd -- --output=<绝对目录> --theme=crystal --exits=2`；加 `--left` 检查左路。截取选择前、选后过渡与恢复平行的镜头。
- 当前实现解决路线持续发散、重复洞口叠放和灰蓝漏空底色。它仍使用原始单张主拱重复排布；洞口在正式光照下的辨识度、长期重复感尚不能仅由几何测试证明合格。每次修改资产宽高、透明基准或镜头约束，都要重新看双路选择和两条过渡的实际渲染帧。
