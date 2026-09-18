# 全面 3D 迁移：实施账本

## 前置阶段

美术补充已交付，见 `ART-SUPPLEMENT-DELIVERY-2026-09-16.md`。当前长期目标仍然进行中，不能把补图完成等同于全面迁移完成。

## 当前收尾状态（优先于下方逐批记录）

- 原远征/无限探索：原 BattleModel、事件/岔路、收益/存档、模型与图片敌人、原生弹道接入；已验证森林和童话代表类型、自然短路线通关、社交选择、失败原地重开。直接无限启动默认原生；目录传统对照仍保留。
- 连续防守：原 defense_sim 只读表现适配，启动入口、设置、整备与跨场景保存应用已接通；自然失败、50 压测、模型身份与五秒尸体烟雾通过。自然完整胜利与末尾全部出生仍需验证。
- 复用性能：旧肖像骨骼增加 native_pose_external，只保留原流程时钟和构图元数据，跳过重复 retarget.apply，且保持旧离屏渲染关闭。切回传统对照会恢复。原森林集成验证旧姿态采样数不增长并检查恢复标记，原事件/相机/死亡流程仍通过。尚未宣称消除全部旧场景 CPU 开销或给出新的 FPS 增幅。
- 原生 gentleman 复活补齐 rise 动画，不再直接跳 idle；起身期间不被攻击动画立即打断，森林用例已增加断言。
- 待收尾：启动/导航矩阵（含其余旧入口的范围判断）、连续防守尾波/胜利、现有战术模式回归、代表画面最终对照、最终技术标准与例外清单。不再重复生成已交付美术或逐地图研发。

### 尾波和保留模式补验

`test_world3d_defense_tail.gd` 让原普通波次完整出生 90 名，逐帧检查激活敌人有模型，最后首领 89 号确实活着显示过，全部死亡/漏过总和为 90，胜利后八秒全部隐藏、烟雾结束、重开清空。为观察完整尾波，该测试提高防线生命和我方数值，是受控生命周期测试，不是默认队伍自然胜利或平衡结论。测试暴露胜利后原 sim.shots 遗留引用；defense_stage 仅在 battle 转结算状态时清掉 shots/effects，不改交战规则。最终日志 `world3d-defense-tail.log` 通过。

保留战术模式：`test_tactical_roster_skills.gd` 八职业主动技能、反伤、第四击、治疗、回能、弹道落点、区域、推移免疫及死亡中断通过；GPU `test_tactical_presentation.gd` 共享场景/机位、真实视口点击角色、技能预览、菜单减速和恢复通过。证据 `migration-tactical-skills.log`、`migration-tactical-presentation.log`。不代表重做或改变战术规则。

正式默认启动：`test_mistwood_start.gd` 从 project.godot 的实际 main_scene 进入，确认 native_route_view 可见，镜头调校入口及原场景物件存在；截图 `migration-default-start.png` 已检查，无预热时原点穿镜头画面。测试使用临时状态并备份恢复 mistwood-game 原始字节，最终日志无错误。此前清理测试状态过早导致的一次退出错误已修正，不以该次结果为通过证据。

剩余集中在导航矩阵/入口归类、代表画面对照和交付说明；不要再把上述已通过的尾波、整备、战术检查列为未实施功能。

## 已实施的第一批

- 3D 主题目录由原六主题扩展到六主题加十八童话场景，另保留混合路线。
- 十八场景沿用原撒布种子、图片尺寸、透明锚点和路线数据，进入现有公共 3D 场景构建器；没有为每张地图重新设计镜头。
- 童话拱廊复用已有底部贴地适配，路线固定平面朝向保留。
- 童话目录增加「3D 场景 · 行进与岔路」入口，保留传统版与世界格子入口；3D 中可返回目录。
- 二十四主题的旋转后续路段检查已通过；魔镜真实 3D 战斗构图截图位于 `tempassets/work/world3d-theme-snow_mirror.png`。
- 茶会真实 3D 连续流程通过 16 个事件、1 次岔路、2 个路段；最长普通路段用时约 5.95 秒。镜头缓停峰值速度比 1.00012、反向步骤 0。证据：`tempassets/work/world3d-tale-flow.log`。此测试显式结束战斗，只验证路线/事件状态衔接，不验证战斗平衡或原模式收益。

## 不能混淆的迁移边界

原规则适配进展：`world3d/model_bridge.gd` 已实现原 BattleModel 到世界坐标表现的只读适配，以 UID 维持身份，输出真实血量、护盾、攻击、死亡和复活状态，不推进模拟时钟。近战表现位移上限 1.2 米，死亡锁定实际位置。`world3d/model_cutouts.gd` 将原怪物图片放入深度测试的 3D 空间，首次测量透明底部并缓存，复用气氛材质和烟雾网格。

验证：`test_world3d_model_bridge.gd` 对同一种子战斗逐 tick 对照，所有原始玩家/敌人字典、血量、护盾、弹道和胜负一致；`test_world3d_original_enemy_art.gd` 验证魔镜三张原怪物图、位置、缓存锚点、五秒尸体停留、烟雾和复活保留。截图在 `tempassets/work/world3d-original-tale-enemies.png`。

ModelBridge 已由内部原远征的 route_models 消费；正式模式默认入口、全部敌方模型和原规则特效消费者仍未迁完。

### 原远征流程接线（已有独立体验入口，尚未替换所有正式入口）

新增 `world3d/route_view.gd`，由 `expedition_route.gd` 在原来镜头、阵形完成更新后调用。通过 SceneTree 元数据 `native_route_view=true` 启用，传统编辑器除外。它使用真实 SegmentWorld 和 SceneFormation 世界坐标，复用公共 Scenery、雾、接地和投影，UI/整备/选择/胜负/收益仍属于原控制器；呈现自身不推进 BattleModel。旧版目录入口显式关闭该内部开关。

六主题与十八童话目录已增加「3D 探索与战斗 · 体验版」，进入原 endless_forest 规则的 3D 呈现。它与先前「3D 场景 · 行进与岔路」诊断入口不同，实际使用原怪物卡组与收益流程。传统入口保留。旧 defense_route 明确排除此开关，等待该模式专用适配，避免从体验版返回后污染另一模式。

`route_projectiles.gd` 已实现只读弹道适配：原 BattleModel 的 shot 字典 age/duration/resolved 是唯一时间与命中依据，3D 适配没有伤害或碰撞回调。普通远程使用现有 Epic StormMissile 粒子池与角色颜色变种，光束使用世界坐标带状几何，保留原模型决定的直达命中时机。原浮字/辅助反馈仍可作为 UI 绘制，旧飞行轨迹在 native view 可见时停画。32 飞行 / 24 命中 / 8 出手实例，32 光束、256 跟踪请求上限；复用 ordinary 粒子预算与四组虚拟飞行光源，超限只降级表现，不丢伤害。材质在当帧虚拟光源发布后统一更新，避免 arena 清理造成灯光不生效。

集成测试增加原 model.shoot 发射、VFX sync 前后原模型 JSON 完全相同、原 resolved 后实际请求命中特效、原 beam 对应 3D 网格。GPU 用例现在逐渲染帧推进，纯逻辑逐 tick 对照仍由 test_world3d_model_bridge 独立覆盖。尚需专门验收自然战斗全过程和多目标技能、失败/重开/返回世界及收益存档。新的入口不是全目标完成的证据。

### 正式远征闭环（已通过第一条自然流程）

`test_world3d_expedition_save.gd` 使用独立 `user://native-route-integration-test.json`，从实际 Journey.enter_battle 进入正式 expedition_route，不用强制胜利、不提高攻击力。默认队伍自然赢下第一条短路线的两次遭遇。首次胜利后重复通知不会重发奖励，保存并销毁场景/重新读取存档后恢复 local_steps=1 与已获 2 秘银，继续通关获得合计 16 秘银；重复 finish_local 不再增收。实际归途按钮回到 journey.tscn，地块解除锁定，存档收益一致。测试结束删除隔离存档，不使用正式 journey-v1.json。日志：`tempassets/work/world3d-expedition-save.log`，最终无错误。

世界遭遇面板的「进入局内冒险」现统一调用 Journey.enter_battle，并启用 native_route_view。传统目录/编辑器对照保留。此验证覆盖正式短战斗路线的自然战斗、部分进度重载和世界返回；不宣称已经覆盖社交分支、失败重开及连续防线模式。

接下来优先处理旧连续防线：`defense/defense_route.gd` 使用原 `defense/defense_sim.gd`，而现有 world3d stage 的 `combat_sim.gd` 是其物理弹道扩展，不能只替换入口就声称规则一致。应保留原防线规则的适配器或明确验证必要差异，复用现有 native 模型池与场景，保留舞台灯、角色独立补光、StormMissile 开关和迟滞结界。避免再新建一套场景渲染或重做地图。

### 连续防守适配（核心规则及实机已接通）

新增 `world3d/defense_adapter.gd` 直接继承原 defense_sim，仅把原 effects 转换为现有 projectile_view 可消费的世界轨迹，禁止调用 swept projectile.step 结算伤害。`test_world3d_defense_adapter.gd` 在相同初始条件下逐 tick 比较普通/50 压测、迟滞、敌人和队员字典、原 shots、生命与结局全部一致。此为模拟规则一致，不代表两种入口默认队伍初始化完全相同：新入口使用当前 3D 公共保存队伍，而旧入口重建 Journey 默认样例。

`defense_stage.gd` 继承现有 world3d stage，`defense_shell.gd` 复用原画幅壳；没有新增一套撒布和镜头实现。原规则默认整场 90 个敌人，按 spawn_cycle 分类型预热 90 槽以避免最后敌人不可见，仍仅对活跃模型更新；这不是已优化到最小的池预算。50 压测与普通持续刷怪入口、迟滞、20 防线生命、舞台补光、独立角色补光、Storm 开关和原色小弹道保留。设置复用 defense-presentation.cfg。五秒尸体后烟雾已接，倒地时保持当前位置；旧场景保留。`启动防线战斗预览.cmd` 已指向 `res://scenes/defense_3d.tscn`。

GPU `test_world3d_defense_mode.gd` 检查 50 敌全部分配模型、迟滞生效、舞台灯关闭不取消独立补光、Storm 与基础弹道切换、重开摄像机不动，最终无脚本错误。证据 `tempassets/work/world3d-defense-mode.log`、`world3d-defense-mode.png`。模型池能覆盖全部 90 的数量由分类型容量计算保证；仍需自然完整波次/失败清场及交互回归，不能把七秒的压测片段当成整场验收。原整备入口和完整正式导航也需要继续收尾，现阶段仍不能结束总目标。

补充回归：同一 GPU 用例现运行普通波次至自然失败，模拟时间 47.2 秒、累计出生 80 名，逐帧确认所有激活存活敌人有模型；失败后继续呈现四秒，再重开回到准备状态。五秒前无尸体烟雾、5.6 秒出现烟雾、重开清空尸体烟雾均通过。修复岔路测试元数据进入防守后的串扰，以及重开遗留烟雾的问题。此结果覆盖自然失败，尚不覆盖自然胜利及最后十名出生；不可将出生 80 写成完整 90 波次通过。整备交互、正式导航、其他模式失败/社交分支仍待完成。

连续防守现有「随行整备」入口，仅准备阶段开放。新增公共 party_editor，角色模型肖像与神秘道具分栏，可添加/收回、上下调位、切换道具持用，角色长按或列表装配按钮复用 kit_roster 六槽装备界面及原武器限制。阵容先在副本中编辑，保存时仅替换 Journey.state.battle.player 并调用原原子存档流程；保存成功重新载入防守场景以更新全部模型/站位，失败保留旧阵容。装备界面仍按原行为即时保存，关闭阵容面板不撤销装备修改。没有复制或改写世界进度/收益规则。

`test_world3d_party_editor.gd` 使用独立临时存档，验证编辑隔离、顺序保存/还原、137 秘银保留、最后角色不能移除、角色加入及六槽界面。GPU 已通过，截图 `tempassets/work/world3d-party-editor.png`。防守实机用例也实际点击整备按钮并确认阵容与模型数据相符，然后继续普通波次自然失败与重开验证。尚未用自动化点击“保存并应用”跨场景后逐模型核对；需要在入口整合回归中补足。

入口补充：adventure_preview、mistwood_start 明确启用 native_route_view；endless_forest 直接启动缺省启用，目录传统对照按钮显式 false 仍尊重。传统镜头/Shader 编辑器不修改。入口更改待对应启动回归。

整备跨场景回归已补足：`test_world3d_party_apply.gd` 在隔离存档中进入实际 defense_3d 场景，调整阵容后点击实际保存按钮，等待 reload_current_scene，逐一核对阵列顺序、team_slots 对应模型文件及原 173 秘银未变，GPU 通过。此用例发现 party.read_units 固定读取 journey-v1 而编辑器按 Journey.SAVE 保存的问题；已统一从当前 Journey.SAVE 读取（无会话时保留默认路径）。不修改已有正式文件。证据 `tempassets/work/world3d-party-apply.log`。

直接无限入口回归：原森林集成用例移除预设 native 标志，从 endless_forest 实际缺省路径进入，已通过两场事件、岔路、第二路段及死亡消散检查，见更新后的 `world3d-original-forest.log`。

社交与失败分支：新增 `test_world3d_route_choices.gd`，独立临时存档 short_social 路线，实际点击补给选项，验证只能领取一次、推进到下一个战斗事件；通过修改测试单位血量制造失败（不是自然难度验证），实际点击原地休整并等待重新开战，检查步数/收益未变、角色生命恢复、机位位置误差小于 0.01。GPU 通过，`tempassets/work/world3d-route-choices.log`。本次没有改动事件和重开规则；这些流程在原生呈现中仍可工作。重生动画逐角色观感仍应纳入最终代表场景观察。

`test_world3d_original_route.gd` 已在 GPU 通过：投影误差 <0.05 像素、连续调用表现不改变模型时间、原魔镜怪物卡组、两场事件战斗、一次岔路以及第二路段接续。地形仅随世界身份更换重建，共两次。测试显式结束战斗，只验证流程接线，不代表自然战斗平衡/技能验收。测试恢复原无限测试存档文件。证据：`tempassets/work/world3d-original-route.log`。

`route_models.gd` 现已接入我方原生骨骼：按原单位 UID / 装配选择模型，复用 allied_actor、character_framing、portrait_presenter、party_lighting、actor_atmosphere 与 health_view。使用实际位移驱动步频，ModelBridge 提供攻击、死亡和复活状态；倒地锁定位置、复活播放 rise。图片单位采用公共气氛材质。GPU 用例补充验证每名角色存在正确模型的 Skeleton3D、没有重复贴图、死亡原地保留和复活起身。

被替代的我方旧 SubViewport 已停止渲染，切回传统时恢复。但 SceneFormation 仍读取旧角色尺寸/状态，旧动画计算尚未彻底移除。原规则弹道、完整死亡/复活时序、正式入口与存档回流仍需继续整合。

`route_enemy.gd` 已接入原非童话模式的 gentleman 敌人：发现与战斗共用一个 native 骨骼实例，沿原事件世界坐标行动，使用实际位移步频、原攻击事件、血量转化与独立补光。入场位置由原控制器提供；不重新编排敌人规则。旧发现/战斗预览不再重复渲染。非复活敌人倒地完成且至少五秒后使用公共烟雾移除，复活倒计时保留尸体。童话及其他原图片敌人也接入同样的五秒烟雾流程，出生渐现复用 born_at。

新增 `test_world3d_original_forest.gd`，复用原远征集成用例：确认发现与战斗为同一个实例，位置与原 SceneFormation 一致，没有贴图副本；测试两场原战斗、岔路和下一路段，保留原卡组。魔镜与森林两类用例均验证五秒前无烟雾、5.6 秒出现烟雾、存在复活倒计时时撤销烟雾。森林日志 `tempassets/work/world3d-original-forest.log` 最终无脚本错误和资源泄漏；截图 `world3d-original-route-forest-battle.png`。早期测试暴露隐藏事件的空贴图错误，已在创建呈现节点前过滤；不得将早期错误日志当成通过证据。原图片敌人是正确资产；不统一换成防线五模型。

**更正前次构图诊断：**小角色不是旧入口默认机位造成，而是 CorridorView.sync 因隐藏状态提前返回，摄像机一直停在 (0,8)，事件和角色已走到 y≈169。已将坐标发布与显示状态解耦，新增持续同步与战斗原点距离检查，未改保存的镜头或模型尺寸。最新 `world3d-original-route-battle.png` 已恢复近景角色占比。另 texture_sampling 对 ViewportTexture 直接保持活引用，禁止将动态模型画面读回并冻结为静态 mip 图片。回归日志通过且没有引擎错误；需继续以认可的 3D 构图为验收标准。

目前 `world3d/stage.gd` 使用防线模拟器及测试事件控制器。把一个主题接入该场景，**不意味着它已继承原远征模式的怪物卡组、奖励与存档**。目录按钮明确标为场景行进测试。旧远征、无限探索与新战术防守的规则不应被统一替换为防线规则。

下一批需要：

1. 拆分公共 3D 表现与模式控制器，给旧 `BattleModel`、连续防守、新战术防守分别设置表现适配器。
2. 从 `journey/expedition_route.gd` 保留真实事件序列、岔路选择、整备、收益、进度与世界返回；通过模式入口选用 3D 表现。
3. 无限探索保留 `journey/endless_forest.gd` 的持续路线与从头开始语义；不得读取后自动抹掉既有存档。
4. 童话原有 54 个怪物图片应成为真实世界坐标下的平面单位，并继续使用对应血量/技能数据；不能永久显示防线默认五模型冒充主题怪物。
5. 原防线入口迁到公共 3D 表现，继续保持其补光、StormMissile 开关、爬行/落地/侧入场规则。
6. 大世界已经使用 `IslandView3D`，重点是出入单局、主题参数与存档衔接；家园/UI 不强行改成 3D。

## 固定技术标准

- 复用用户认可的 `traditional_camera_active.json`、角色构图投影、路线弧长和固定步速；不得为了事件时间加速滑动或另改画幅比例。
- 美术仍主要是 2D 透明图片置于 3D 空间，角色按现有模型管线；接地依据实际透明边界，不依据整张图中心。
- 相邻路段流式加载、按材质与空间分块批次复用、模型池、技能查询/特效预算保持现有实现。
- 几何与规则批量检查，视觉检查按构图/资产类别选代表用例。只在出现新的实际问题时扩展检查，避免循环重测所有地图。
- 原网页 demo 保留；传统入口保留到迁移流程验证完成，不因新增入口就宣称全部模式完成。
