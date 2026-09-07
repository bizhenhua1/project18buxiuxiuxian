# 仙途 · 原生制作样本

设计决策与多主题验收范围见[知识库设计案](../docs/design/ADVENTURE-PRESENTATION.md)。

原生 Godot 项目，测试版本 **4.7.1.stable.official.a13da4feb**，Compatibility / OpenGL。当前包含森林基线、洞穴/云海连续区域、可操作战斗，以及共用探索状态的浮岛 2D / 3D 对照。完整成长系统与关卡循环尚未移植。正式版目标平台仍待讨论，本轮先供本机 Windows 鼠标键盘体验。

## 新样本入口

**当前默认入口是「归云居 · 我的主岛」**：点击地块种植、搬迁、解锁，收获后安排出征；冒险岛入口进入森林/洞穴/云海局内路线，再处理怪物或旅人事件，携行囊返航。此前三战换岛是历史联调方案。当前结构和限制见[主岛与出征设计](../docs/design/HOME-AND-EXPEDITIONS.md)。通过主岛右上「表现样本」仍可进入原对照目录。

默认运行打开主岛。`./godot/run.ps1 -Battle` 直接进入独立战斗样本；`-World` 进入两种浮岛；`-Spaces` 进入连续空间；`-Forest` 进入原森林 A/B。森林场景可用 Esc 返回目录。

`./godot/run.ps1 -Adventure` 打开本轮连续战斗验收入口（也可运行 `scenes/adventure_preview.tscn`）。它使用独立存档：选右路连续两战，选左路先遇旅人类事件再连续两战；己方卡牌与景观常驻，胜利清场后继续前行，到路段终点才结算。正式主岛出征进入局内时使用相同实现。算法、存档检查点与表现边界见[本轮整改](../docs/design/BATTLE-CONTINUITY-AUDIT.md)。

战斗中点击左侧卡牌加入，右键移除，拖动己方卡牌换位，双击法宝切换手持/操控。可先看“默认阵容”，再试“护阵示例”。支持暂停、0.5/1/2/4 倍速、换敌与第 1–32 关参数。试验库直接提供 24 张原卡牌，不代表已接入捕获、装备或天赋成长。

浮岛默认并排，支持单看 2D / 3D；Q/E、A/D、左右键旋转，滚轮或按钮缩放。点击已探索格寻路，点击相邻未知格探索；全貌预览不解锁地块。换岛循环原生成器导出的 32 座样本，保存/读取使用本机 Godot 用户目录。

详见[战斗与浮岛双方案设计案](../docs/design/BATTLE-AND-WORLD-SAMPLES.md)。统一检查：`python scripts/check_godot_samples.py --render`；日志和报告写入 `godot/captures/validation/`。本机 PATH 如无法定位引擎，可传 `--engine <Godot 控制台 exe 绝对路径>`。`--render` 会打开短时 GPU 回放窗口并生成截图。

## 启动

- 用 Godot 导入本目录 `project.godot`，按 F6 运行主场景或 F5 运行项目。
- PowerShell：`./godot/run.ps1`；打开编辑器：`./godot/run.ps1 -Editor`。
- 直接调用引擎：`godot.exe --path <本目录绝对路径>`。本机另有旧版 `godot.cmd`，启动脚本明确查找 `godot.exe`。

## 比较方式

以下是 **森林基线** 的比较说明；进入 `scenes/main.tscn` 或使用 `-Forest`。默认单看 B（作者选择），仍可并排比较。两边共享同一相机、道路、随机种子和植被。A 使用固定世界方位的参照山，B 将远山放置在对应分支的实际延伸线上；远景位置是两组的实验变量，未通过屏幕吸附伪造朝向。

1. 首段接近在 1.8 秒内停步，过程中即可选择。
2. 点左/右路，两边同步进入相同路线。转入后还有持续前进阶段，观察是否感到回到了原路。
3. 用“单看 A / 单看 B”切到较大画幅；“并排对照”恢复。切换不重置行进状态。
4. 用“重新比较”回到相同起点和场景。可以关掉地标提示、关闭起伏或慢放。

快捷键：←/→ 选路；空格暂停/继续；R 重来；1/2 单看 A/B；3 并排；F3 绘制计时和航向诊断。

## 已改变的算法

- 道路使用 XZ 平面上的沿程位置与航向。岔路后通过连续转弯段接向 ±0.5 弧度方向的后续路段，不再并回旧 X=0 主轴。
- 远景、日轮和云使用相对航向计算画面位置。B 的目标处于分支延长线上，随着相机转入自然位于前方；A 的参照峰保持独立世界位置。
- 全部近景采用原有最终 PNG；运行时按 alpha 内容裁切、生成 mipmap、将草烘焙为若干高/低条带。原图字节不变。
- 岔口植被按所有道路的净空生成，不靠临时移动整面树墙展示出口。
- 两个等尺寸视图共享当帧投影/排序结果，避免重复计算近景。可见绘制仍各自提交，性能记录是整个小样而非正式版预算。

## 文件职责

| 文件 | 职责 |
| --- | --- |
| scripts/route.gd | 连续路径、航向、相机坐标及净空查询 |
| scripts/forest_world.gd | 固定种子生成近景布局 |
| scripts/art_library.gd | 原始素材加载、内容锚点、运行时条带与 mipmap |
| scripts/corridor_renderer.gd | 投影、排序、雾化、远景与纸片绘制 |
| shaders/ground.gdshader | 地面反投影与天空渐变 |
| scripts/corridor_view.gd | 裁切视图、shader 参数与渲染器连接 |
| scripts/app.gd | A/B 同步控制、UI、回放与诊断截图 |

## 检查

```text
godot.exe --headless --path <项目目录> --script res://tests/test_routes.gd
godot.exe --headless --path <项目目录> --script res://tests/test_interaction.gd
godot.exe --path <项目目录> res://scenes/main.tscn --resolution 1600x960 -- --capture=<截图目录绝对路径>
godot.exe --path <项目目录> res://scenes/main.tscn -- --capture=<另一目录> --capture-left --focus=2
```

截图回放使用真实渲染后端，请勿添加 `--headless`。输出四张关键帧和 `report.json`，完成后自动退出。统计包含截图造成的停顿，属于本机回放观察，不能直接当独立性能基准。画面不是旧 Demo 的像素等价复刻，不能据此宣称两层迁移已经完成或作者已认可。

资源清单：`assets/manifest.json`。刷新资源：`python scripts/sync_godot_assets.py`。`.godot/` 导入缓存和 `captures/` 截图不进版本控制；`.import` 配置与 `.gd.uid` 保留。

## 当前局内界面与粒子特效（2026-09-06）

最新正式入口从地块读取环境主题，普通地块为短直线，仅明确配置的深林入口有岔路。行进时敌阵收起，怪物在路上现身后自动交锋；战后显示战利品，走完地块显示探索奖励。局内界面随窗口统一缩放。设计与验证边界见[地块、局内路线与遭遇的归属](../docs/design/TILE-LOCAL-ROUTES.md)。

通过 `./godot/run.ps1 -Adventure` 进入隔离试玩。顶部显示旅途信息，中央保留景观与交锋，底部“随行整备”在上方敌阵区域展开带原画的横向行囊；它是场景内区域，下方阵容始终可见、可点选与拖放。支持收回、重新编入和手持切换，点击“整备完毕”恢复旅途。岔路与遭遇操作按阶段出现，战后清除敌方并继续前进，我方卡牌始终保留。

新界面使用六个透明小部件拼接，字体与面板尺寸由引擎管理。命中、暴击、治疗、增益与倒下使用有上限的原生 GPU 粒子池及单张静态笔触，不使用序列帧。完整参数、资产来源与验证边界见[局内界面、卡牌与粒子特效](../docs/design/ADVENTURE-UI-AND-PARTICLES.md)。

## 森林首轮边界（历史记录）

- 只做森林双岔及两种地标关系；没有搬写旧玩法、数值，也没有实现完整昼夜、主题切换或浮空岛。
- 小样道路是有限长度的固定实验布局；正式版仍需把持续道路生成、地图事件和世界目的地接入。
- 转角、时长、镜头远近与近景密度仍待作者游玩反馈，不作为最终设计。
- 本机 Windows 截图控制工具报 `SetIsBorderRequired ... 0x80004002`，未完成实体鼠标回归；已通过 Godot 输入传播/按钮信号测试，并检查引擎自身输出的真实渲染截图。

## 天空、云场与路径尽头（2026-09-06）

当前以 B 为主，保留 A 对照。参数集中在 `scripts/atmosphere_profile.gd`，森林实例为 `profiles/forest.tres`。创建地图/关卡配置时可覆写资源，不需要修改渲染算法；由 `ForestArt.new(profile)` 传入，世界与两个视图共享同一配置。

- **地平线幽深**：单独的渐变雾带，位于远景之后、林木草地之前；路径尽头最暗，向上过渡回大气雾，近景不被整体蒙黑。`depth_color`、`horizon_strength`、`horizon_up/down` 控制主题色、强度和范围。洞穴出口等特殊关卡可以改为暖亮色；这只是可配置能力，尚未确定关卡美术规则，也未迁移洞穴。
- **统一投影**：太阳是无限远方向，不受平移影响；山体是世界平面，分 96 段透视投影。山的雾感只混合 RGB，保留轮廓遮挡。
- **三层云**：近 / 中 / 远分别有距离带、网格间距、高度、尺寸、横向风速与透明度。近云较大较清晰，远云更小更淡。静止时只有横向风及小幅阵风；前进带来的上移和变大完全来自相机与云的相对位置，没有独立的径向滚动动画。同一仰角下，距离越近，前进视差越大。
- **持续编排**：`SkyField` 按固定种子生成世界网格；相机只查询附近网格，不拖动云。云穿过距离带边界时渐隐/渐显，跨网格、转向与左右分支保持世界位置。A/B 共用同一时刻的云场结果。暂停冻结时间，重来复位。
- **遮挡**：所有云与目的地统一按相机深度排序，允许近云在目的地前、远云在其后，随后绘制地平线雾带和森林。地标文字仍属于可关闭的提示层。

`tests/test_sky.gd` 验证太阳平移不变、各层横向风、静止不径向漂移、距离视差、移动相机时云世界位置稳定及主题配置隔离。`tests/test_interaction.gd` 验证选择、暂停、重来、视图切换。原生回放截图位于本地 `captures/atmosphere-final/`；这些截图与导入缓存不纳入版本管理。

## 多类型连续路线小样

启动 `./godot/run.ps1 -Spaces`，或运行 `scenes/space_study.tscn`。左路森林进入洞穴，右路森林进入云海；顶部可直接切到洞穴或云海。按键沿用 ←/→、空格、R。

结构与限制见[空间类型与连续过渡设计案](../docs/design/SPACE-TYPES-AND-TRANSITIONS.md)。类型资源在 `spaces/types/`，路段配置在 `spaces/routes/`，布局策略在 `scripts/spaces/layouts/`。本轮最多 12 路段和 3 种材质类型，当前路径仍是固定双岔；不代表任意路网或双向门户系统已经完成。

```text
godot.exe --headless --path <项目目录> --script res://tests/test_spaces.gd
godot.exe --path <项目目录> --script res://tests/capture_spaces.gd
godot.exe --path <项目目录> res://scenes/space_study.tscn -- --space=cave
godot.exe --path <项目目录> res://scenes/space_study.tscn -- --space=cloudsea
```

`capture_spaces.gd` 使用真实 GPU，输出到 `captures/spaces-review/`。运行完自动退出。新类型尚待作者验收，原森林基线继续保留。
