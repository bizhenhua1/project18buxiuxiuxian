# 正式 3D 迁移目标与验收计划

日期：2026-09-13。状态：**进行中，工程基础验证阶段，未完成迁移**。

最近进展（2026-09-14）：接地与穿插工作详见 WORLD3D-GROUND-CONTACT-PLAN.md。原生clover锚点已修正；乔治死亡改用Death2，isabella替代动作已撤回；尸体末帧停止重复骨骼更新。树干共享占地重排仅--resolve-trunk-contacts试验启用，支持不可变路线描述、整批预登记、可续算候选、过期/未来分块回收。64事件/5岔路/5路线森林逻辑回归通过，但树干保守占地仍有未解冲突、尸体/衣摆视觉未通过、高压技能帧率仍未达标，整个迁移远未完成。不可把局部测试结果当全面验收，也不可忽略默认关闭的实验状态。
目标已由用户明确授权，并在目标工具登记为 active。旧的 18 景资产目标已另存 HANDOFF-18-FAIRYTALE-SCENES-2026-09-13.md，不与本目标混淆。

## 产品目标
2026-09-14 独立正式版构图复核：重新capture_formal_battle_baseline（defense_route真实入口）后运行content_frame --formal-world --matched-pose，3483源资产贴图/位置/尺寸一致，站位参数最大误差1.74e-9旧单位，当前两角色相对地形和深度误差近零；同世界同姿态运行投影关键点<.02px断言及1920×1080/1280×960内容区检查通过。首次测试写完landmarks后停在frame_post_draw等待，已终止该测试并改先yield process_frame再force_draw请求冻结诊断渲染，重跑退出0并有CONTENT_FRAME_PASS。仅测试截图触发改动，未改生产镜头。匹配姿态是诊断，非独立动画时间线/全部动态遮挡及风格一致性完成。日志latest-formal-baseline.log、latest-content-parity.log。
2026-09-14 最新完整导航回归：真实GPU test_world3d_continuous_travel --long-stream --straight-first通过64事件/5岔路/5route，实际按钮含1次三岔直行，maxleg5.45s、maxworldstep.15357m、69刹停样本峰速比1.000720/无倒退。采样chunks1799起、各次回收926/658/696/655、末1227（含下一段），各采样pending0，说明此次可回收/无累积上传积压，不是全程显存或帧率证明。战斗明确注入胜利，不能声称64真实战斗通过；这次使用world3d_stage原生入口，不是presentation完整画面对照。日志latest-continuous-flow.log、world3d-long-stream-connected-baseline.json。
2026-09-14 贯穿区域高度修复：原corridor将(from+to)/2统一作为高度基准，对斜线漏命中路径目标并误中同XZ但偏离局部路径高度者；测试先复现失败。apply_ids可选path_end，仅对扫掠候选按XZ最近参数插值高度，纯竖直线按端点高度区间、退化点按原高度，圆形区域路径不变；不全场额外扫描。斜线、反向、竖直新增用例及原旋转/空中拒绝/1000目标空间剪枝通过，实际GPU持续区域伤害/显示/重开清理回归通过。属于带垂直半高的走廊体积，非声称实现任意定向球胶囊；未新加技能美术或帧率收益。日志area-slope.log、area-slope-integration.log。
2026-09-14 同步齐射死目标消耗修复：新增两发同一步穿过近/远目标用例，旧projectiles共享broad/lookup后不重新检查HP，第二发仍在已死近目标消耗，测试先失败并终止。候选求交和最终伤害提交前均重新检查hp/resolved（后者也覆盖伤害回调改变其他命中候选），跳过尸体不消耗remaining，不改稳定命中排序或空间索引。新用例及最近命中/贯穿去重/移动扫掠/空中拒绝通过，实际GPU24.8s失败/原位重开/辅助真实伤害胜利离场回归通过。此为有意修正齐射伤害逻辑，不保证所有低血量压力场景指纹不变；没有新帧率声明。日志projectile-dead-target.log、projectile-liveness-battle.log。
2026-09-14 粒子纹理分格参数层级读取：epic181_effect把sheet cycles/row_mode/columns/row/tile_count从两个逐粒子分支移到层级，仅sheet_enabled时查表；每帧重新读取所以不冻结编辑参数，不改粒子顺序/数量、frame/start曲线或随机数。实际GPU原StormMissile三效果5383样本transform最大差0、color/custom相同；新增--sheet-fixture注入4×4/3.5循环/固定行2/随机起始帧，5378样本相同。测试参考包含多项历史优化差异，日志计时不能归因此次修改；尚无整场新增收益声明。未采用生成序列帧，仍使用资产原有粒子贴图。日志particle-sheet-cache.log、particle-sheet-fixture.log。
2026-09-14 按需索引整场高压复核：首次benchmark直接读areas.index而未主动sync，导致额外弹道372/area10857/指纹696585，不能比较性能；保留query-cadence-stress-stale-index.log。补齐benchmark apply_skill_load与real_battle_result辅助burst入口显式sync（stage主动技能原已有），全项目搜索其他调用均有初始化/sync。重跑384额外弹道/10885area/408ccb原指纹、39模型、32zones、零漏播，mean38.0971ms/p9551.558、particles17.3117、simulation.6198ms、1444draw。单次无同步旧代码对照，不宣称稳定提速；仍不达60FPS。真实战斗24.8s失败/重开/辅助真实伤害胜利离场回归通过。日志query-cadence-stress.log、query-cadence-real-result.log。后续技能入口必须在瞬时查询前sync，不依赖周期区域隐式刷新。
2026-09-14 技能空间索引按需刷新：projectiles在无active弹道时清空旧events/已有broad并早退，clear也释放broad数据；areas新增needs_targets，combat_sim仅在当前步会触发区域tick时sync，advance的计时/多tick/过期逻辑保持。stage主动burst/corridor仍显式sync因此不读取旧索引。独立差分100步（移动目标、双区域不同interval、.8大步跨多tick、到期）每步比较伤害序列与zones，完全一致，候选sync9次/参考100次；这不是整场FPS收益。真实GPU区域伤害/标记/重开清理，以及弹道最近命中、贯穿去重、移动目标相对扫掠/高度拒绝全部通过。尚未重跑整场高压帧时，不宣称达到60FPS。日志query-cadence.log、query-area-integration.log、query-projectiles.log。
2026-09-14 倒地武器深度量化：actual GPU runtime逐顶点读取装备surface，经mesh.global_transform与camera变换，确认isabella当前左手sword_A（右手空）距离1.8678–2.1877m，近裁面.05m，无顶点跨近裁面；原生投影包围矩形宽.193/高.149视口。此前“拉伸”仅是视觉描述，现证据不足以判定武器缩放或蒙皮异常，不能因此缩小武器。此bounds是全部几何而非可见像素，未做stand/death物理尺寸全对照。维持默认投影不变；尸体多数出画仍受低于画幅的战位锚点和弱透视影响。日志corpse-projection-comparison.log CORPSE_WEAPON_DIAGNOSTIC。装备profile已确认会在右手为空时选择左手武器，不是武器类别丢失。
2026-09-14 尸体异常对象隔离：完整材质链真实透视测试追加actor.hide以及仅attachments.hide两张同帧截图，之后恢复全部可见状态及材质权重。查看revive-corpse-hidden：异常随演员消失；revive-corpse-native-no-weapons：身体保留，宽大浅色形状消失。因此该形状来自武器而非身体蒙皮，下一步应检查近裁面/武器真实深度和投影，而不能以此修改人物骨骼。残余身体在底边之外仍未解决。纯测试隔离，未让游戏死亡武器自动隐藏。日志corpse-projection-comparison.log，回归起身/归位仍通过。
2026-09-14 尸体投影对照补齐next_pass：先前仅修改基础surfaces/weapons遗漏后续actor atmosphere，因此测试新增遍历完整材质next_pass链，按Material去重，保存/还原实际权重值；仅冻结诊断使用，不进逐帧生产。真实GPU重测并查看，浅色局部形状仍存在（色调变化但轮廓未消失），因此不能归因于只漏同步光照层，也不能声称附件同步就修复了形变。需要进一步检查该倒地姿态蒙皮/表面/遮挡，维持真实透视未启用。日志corpse-projection-comparison.log和revive-corpse-native.png覆盖为这次完整材质链结果。
2026-09-14 尸体真实透视GPU对照：test_world3d_revive_runtime增加--compare-corpse-projection，在冻结尸体时暂存/置零surface与weapon portrait_weight后截图再还原，未改生产逻辑、机位、骨骼与锚点。查看revive-corpse-native：比弱透视露出更多头身部分，但多数仍在底边外，手部附近出现明显浅色拉伸/重叠形状待查，不能默认启用或宣称修复。actor atmosphere材质此时仍沿用已有其他灯光参数，测试不是完整权重统一的实现，只用于投影形状初筛。恢复后原地起身/归位回归通过。日志corpse-projection-comparison.log。真实地面锚点低于画幅的约束仍在，不能靠切换投影保证整具尸体可见。
2026-09-14 尸体出画投影归因：实际runtime倒地后新增头/盆骨/踝原生投影与presented_attachment对照。非主角vertical_offset=0，排除主角腰部偏移沿用；地面anchor UV y=1.091本来就在视口下。头原生y=.915而传统弱透视后1.021，盆骨1.010/1.015，说明弱透视进一步压平倒地深度导致头出画；脚原生y1.62/1.40、弱透视1.02/1.10，不是所有骨骼都被同向推低。下一步可试死亡渐变回真实透视，须同时统一材质/轮廓/武器/灯光/附件投影权重，不能只改画面而使命中位置漂移。当前仅记录证据，未抬高尸体/移动相机/修改站位。日志revive-runtime.log的CORPSE_PROJECTION_DIAGNOSTIC，仍只有当前第二队员的受控离位案例。
2026-09-14 中途复活实际画面采集：runtime测试在致死前将离位坐标提交到演员，再断言死亡期间位置不变；1440×900采集revive-corpse、rise-4、rise-12、home并查看。起身/回原位确实执行，复活后站立显示正常；corpse图里尸体大部分落在画幅下沿之外，故此前节点/状态测试不能算尸体可读性通过。起身首段也有同队模型遮挡，仍需改进原地姿态的画幅表现而不能改全场机位。该用例允许其他战斗模拟继续，截图FPS由批量无渲染步进导致，不能用于性能判断；仅一个现有队员模型和受控治疗注入，不是全模型/技能验收。未因截图通过而标完成。
2026-09-14 起身/归位朝向与首帧：stage战斗自动朝敌仅在非rising/returning时执行；否则此前每帧会覆盖native advance按行走速度设置的归位方向。battle_revive复用已有.16s骨骼混合，从实际尸体姿态开始，再进入rise，避免直接换首帧；只有复活发生时记录evaluation_bones，不加常态模型缓存。真实GPU复活测试新增人为非战斗朝向.73rad，在整个原地起身期间不变；归位/idle通过，并验证零时间恢复首帧所有评估骨骼Transform近似不变。该零时连续性不代表完整起身姿态/衣摆接地已达标，仍需多模型录像/截图验证。日志revive-runtime.log。
2026-09-14 中途复活原地起身阶段：allied_actor新增仅用于战斗恢复的battle_revive，播放现有rise(7_Getup_Seq)，与整备/胜利trigger revive分离。configure_allies把实际起身动作时长传给模拟；死亡HP恢复后先rising原地、禁止攻击，到时才returning固定速度归位。实际GPU stage测试第二个队员在模拟离位后伤害致死、等待倒地、恢复HP，断言rise播放、rising期间原地、归位后idle；独立再次死亡归位测试回归通过。该用例是受控注入攻击位置和治疗HP，非已加入可操作复活技能；没有截图/逐帧骨骼连续性验收，死亡末帧与起身首帧吻合程度仍待检查。日志revive-runtime.log、revive-return.log。修改默认仅作用未来/测试中的中途恢复，不改变普通胜利和重开恢复。
2026-09-14 复活归位接入：补验证world3d actor.animate_unit的dead同步，尸体最终姿态缓存、显式revive以及仅HP恢复均清除dead；第二次死亡重新播放通过。combat_sim对HP>0且state=death的我方单位取消旧attack字段/待出手windup，保留attack_origin为return_target，以固定3模拟单位/s（1.2m/s）回位，期间推迟next不出手；中途再次死亡保留原回位目标，死亡不位移。stage看见存活HP/dead演员触发revive并清attack_stamp，回位时把实际速度传入动画。独立simulation测试验证位移上限、恢复/二次死亡/归位，真实GPU战斗24.8s失败、原位重开、真实伤害辅助胜利与离场回归通过。未新增主动复活技能或UI，尚需实际中途复活完整动画画面测试，不能宣称已解决全部复活观感/敌人复活规则。日志death-state-sync.log、revive-return.log、revive-return-battle.log。
2026-09-14 非森林主题初始化背景修复：stage环境创建时直接采用首个实际主题space.top_color，森林继续101923；后续跨主题lerp保持不变。避免宫殿/其他封闭主题起步先出现蓝灰背景，再慢慢变暗。shell_comparison移除强制改背景，改为断言真实初始颜色；真实GPU宫殿94shell六图通过。现有contact_toggle实际覆盖水晶（命令行palace被测试内部meta覆盖），三次场景创建/两次reload通过，明确不当宫殿reload证据。未改镜头、模型大小、灯光亮度、物件数量或更新频率；此项是默认运行行为修复，不代表顶部几何或全场穿插完成。

2026-09-14 对话事件重开漏洞修复：can_reset不再允许social事件切到prepare（此前会允许start_battle，却因current.kind非battle无法win解决事件，导致depart受阻）。事件阶段仅未解决battle可整备；prepare/battle/victory/defeat重开保持。test_world3d_social_controls用真实商人按钮验证无货币购买禁用、未解决不能重开/开战/离开、补给只领取一次、完成后继续到下一事件。实际战斗回归自然失败24.8秒/6击杀/20漏怪/6队友死亡，原地重置通过；随后通过真实伤害API辅助清场的胜利恢复/事件解决/继续行进通过，不是完整平衡验收或尸体视觉全部通过。

2026-09-14 动态岔路UI修复：开局始终创建左/直/右三个按钮，显示与可用性依据当前route_segment.exits和fork状态更新；仅在真实岔路显示，非法方向由choose_branch拒绝，初始route_segment.exits与plan同步。避免初始两岔路线导致后继三岔路没有直路按钮。状态缓存避免每帧重复设置控件。独立2→3→2→3与六阶段测试通过；continuous_travel改走真实按钮pressed信号，--long-stream --straight-first通过64事件/5岔路/5路线、1次直路，最长5.45秒、刹停峰值比1.000720、无倒退。战斗结果仍由测试注入，不代表64次真实战斗清场或全套视觉验收。

2026-09-14 后续落地更新：无树干重排时默认按原240单位空间块流式上传（--whole-route-upload可对照），实际森林37361实例/1187批次首批CPU约390→28–31ms；这是加载指标，非战斗FPS。路线环境边界延续已修复，普通3D武器渐隐不再依赖投影开关。重新整备/开战前比较已应用装备与保存配置，只在变化时重建武器和动作；战斗近远程行为读取实际actor.profile，避免新数值配旧武器。实际装备同步测试不写存档，通过位置/机位不变、重复整备资源复用和原生战斗投影回归。曲线共享采样区间数值精确一致，局部12万次约95.6→77.6ms；高压仍约37ms，未到60FPS。整缓冲粒子上传更慢已撤回。部分树干避让、精细贴地、远景接地LOD、近景准备即交接仍为实验，不是默认效果；远景LOD虽降三角约18%，高压仅37.24→37.04ms，不能宣称明确提速。森林退出10贴图引用告警已消除，静态脚本告警仍在。更多证据记录在WORLD3D-GROUND-CONTACT-PLAN.md，全文目标和未完成项不变。

2026-09-14 活跃粒子分层复测（开启计时有自身开销）：高压spawn4.999ms/update11.521ms，粒子整体18.677ms；最高update为missile5 hybrid1.988ms、impact2 hybrid1.939ms、missile4 analytic1.796ms、impact4 hybrid1.692ms、missile1 analytic1.229ms。missile4 Dust与missile1 DustTrail都是普通透明混合，不能以无序槽或跨特效合批改变其叠加顺序；missile0/2/3才是additive。当前analytic粒子虽由shader运动，但CPU保持紧凑顺序，前部粒子死亡会令后续motion_slot改变并重新上传其出生矩阵。下一步应量化这些重传，再针对可交换的加法层试验稳定槽位或评估本地批量更新；普通透明层继续保序。此前bulk/cohort/batch失败试验不能忽略，也不能将本次带计时39.595ms与不带计时直接比较为退化。

2026-09-14 发射形状固定变换：Epic181为每层预计算ShapeFrame（旋转basis、非均匀scale、offset），spawn只应用缓存；半径/形状随机采样及顺序保持原逻辑，禁用缓存时保留原计算路径。20形状分支×开关×128采样共5120变换与RNG状态精确对照原实现，实际GPU实例5383样本max_error=0。高压相同39模型/1449draw/408ccb指纹/零漏播，mean37.891/p9552.527、粒子CPU17.564ms；此前空层优化后38.075/52.131/17.756ms，本次均值小降但p95未改善，差异不足以宣称稳定帧率收益。新增--uncached-particle-shapes诊断对照，默认缓存，约每层一个小型不可变对象；仍需更大幅度优化活跃粒子路径，未达到高压目标。

2026-09-14 空粒子层更新：Epic181默认在发射判断后跳过已空层的材质/物理更新，保留显示数归零；休眠期间置motion_needs_sync，恢复时强制同步发射器/逆矩阵/朝向，避免可选uniform缓存留下旧值。原包浏览器也只跳过不可见空层，粒子数量/发射顺序不改；--update-empty-particle-layers可对照。空层恢复788uniform/403空样本、休眠时移动缩放相机及重置通过，原uniform缓存2160项通过，复杂GPU18帧仍6/1179648像素变化（max23/255）无新增差异。同负载39模型/32区/384额外弹道/10885区域命中、同408ccb指纹、1449draw与零漏播，修改前mean38.812/p9555.239、粒子CPU18.125ms；修改后mean38.075/p9552.131、粒子17.756ms。仅小幅单轮改善，未达高压60FPS，不宣称稳定提升；还需处理活跃粒子执行/提交成本。

将基础行进、提前部署事件、真实岔路转向、空间感、战斗、撒布和镜头过渡统一到 3D 空间。大量使用现有 2D 图像作为场景面片、地面、物件和风格化表现，减少资产生成成本与包体。怪物和角色使用实际骨骼模型，避免每个角色先渲染成图再贴回场景。针对未来 PVZ/明日方舟式持续来敌、索敌、多弹道、爆炸/区域/贯穿 AOE 预留预算。

## 不可丢失的构图与流程要求

### 当前最高优先级：正式版战斗整幅构图
运动uniform缓存试验（2026-09-14）：每effect快照global_transform一次，比较emitter/billboard矩阵，静止时跳过相同参数上传；setup使缓存失效，age仍每帧。2160uniform比较覆盖静止、移动、旋转、非均匀缩放、相机平移/旋转、reset通过；复杂GPU对照误差保持6/118万max23/255。首轮cached mean41.1779/p9562.210、particles19.2026，对照38.9775/p9554.394、particles18.6763；cached复核38.3094/p9551.660、particles17.9457，结果存在波动，未证实稳定收益。检查无其他Godot进程存活。缓存改--cache-motion-uniforms显式试验默认false，保留单次读取变换快照，benchmark按实际缓存标志命名。下一步不应继续把小型GDScript缓存当作足以解决整体高压预算的路径；仍需针对混合粒子CPU更新与GPU提交架构。

默认特效容量补齐（2026-09-14）：原默认24/24/24未覆盖既定压力峰值；原生projectile_view改默认missile128/impact96/muzzle24，full-vfx-capacity仍160/128/24供更大诊断。GPU motion/current只使用transform编码与shader颜色/图集，MultiMesh移除unused colors/custom两份vec4，实例布局20→12 floats，针对该缓冲理论减40%（非总显存；相较旧小池默认预留内存仍增加）。复杂GPU18帧差异保持6/1179648 max23/255，CPU不可变参考5383max0。不带full容量或GPU实验参数默认满高压：39模型/同408ccb指纹、请求impact637/missile407/muzzle54、峰值85/120/7、零漏播，mean40.8963/p9555.428ms。默认完整flow通过。此轮使普通启动真正覆盖这组已测并发，不保证任意未来技能无限容量，且高压60FPS仍未达成。

GPU运动默认落地到原生3D（2026-09-14）：同轮水晶满容量高压CPU motion mean47.2486/p9562.340、particles26.6149ms；GPU motion mean39.0352/p9553.007、particles18.5385ms。脚本核对同模拟指纹、39模型、384额外射弹/10885命中/32区域、相同三类特效请求与零漏播。world3d/projectile_view现仅在gl_compatibility且GPU曲线有效、无跨效果batch时默认开启，--cpu-particle-motion可回退；通用FX默认与旧版浏览器不变，共享cohort仍默认false。benchmark命名/字段改读取实际启用状态。默认完整六状态flow通过；不带实验参数正常固定负载确认gpu_particle_motion=true，mean16.409/p9526.653、零漏播，仍非稳定60FPS。此前“GPU motion默认关闭”的历史条目已由本次决定替代。高压性能、完整画面验收及其他迁移要求仍未完成。

出生帧共享年龄试验（2026-09-14，默认关闭）：MotionCohort复用同帧年龄累加/最近到期寿命，无新增/到期时跳过analytic层粒子遍历；到期仍稳定紧凑，cohort对象回收并CAP有界。6303粒子身份/数量/年龄精确比较、3次reset、变化dt含0通过；复杂GPU18帧误差保持6像素/118万max23/255，默认不可变参考5383max0。高压同408ccb指纹零漏播，cohorts mean41.9936/p9560.167、particles21.1909/update13.5091；不分组mean39.3920/p9554.440、particles18.6668/update11.4881，明显退化，已改--particle-cohorts显式实验，默认false。持续发射几乎每次都dirty，分组维护叠加稳定整理，不能用正确性通过声称优化；仅可能进一步研究burst-only层，不再全局默认应用。

世界空间噪声拖尾GPU求值（2026-09-14）：gpu_motion适用条件移除local/zero-noise限制，仍要求零重力、无velocity曲线、有效阻尼0、恒定旋转、无sheet、mode0/4。噪声两端曲线按独立长度缓存1行RGBAF纹理，vertex手动插值；world-space中心=出生世界位置+速度*elapsed，噪声仍按原emitter基转换，零noise不执行三角函数。StormMissile1由hybrid转analytic，分层CPU更新2.87→1.18ms；同水晶满高压39模型、同408ccb指纹/零漏播，mean41.3901/p9552.671ms，相比上一轮40.7626/55.885不能宣称整帧收益。基础移动相机/变步长/随机色18帧118万像素1超差像素max4/255；增加世界偏移(128,7,-256)后3像素max6/255；再增加两端不同长度随机noise曲线6像素max23/255，均符合现有像素比例门槛但非逐像素相等。默认不可变参考5383变换max0、颜色custom一致。GPU motion依旧实验默认关闭；接下来最贵剩余为missile5/impact2的旋转曲线和图集层，以及活粒子生命周期/紧凑提交开销。

粒子分层成本定位（2026-09-14）：仅profile_particles时统计每层spawn/update usec与particle_steps，benchmark按effect kind/index汇总，默认不做计时。水晶满容量高压同内容零漏播mean40.7626/p9555.885ms；主要更新：missile1 2.87ms/399481步，missile5 1.97ms/165683，impact2 1.89ms/184631，impact4 1.71ms/396499；analytic missile4仍1.70ms/662156。测量含统计开销，不是优化收益。最贵missile1是world-space、无重力/阻尼/velocity-over-life、startSpeed[0,1]、rotation常量[6.628415,12.56637]、noise33点[0,1.5]。下一步优先把这个世界空间噪声拖尾按出生位置/速度+GPU噪声曲线直接求值，注意当前CPU nonlocal噪声通过emitter基变换，与简单world噪声不同，保留移动发射器/变步长对照。默认CPU参考5383样本max0再通过。

静止粒子无效阻尼消除（2026-09-14）：epic181_effect 对 startSpeed 与 gravityModifier 两侧均恒零的层缓存 effective_dampen=0，原数据与随机序列不变，CPU跳过无效限制；GPU motion开启时Storm impact analytic2→3、missile3→4，muzzle不变。移动相机+变步长+随机颜色18帧1179648像素对照仅1像素超过2/255、最大4/255，符合现有测试门槛但非逐像素相同；默认CPU不可变参考5383变换样本max0、颜色custom一致。水晶满容量高压同408ccb指纹、39模型、384额外射弹/10885区域命中、零漏播，mean42.931/p9561.729ms、particles20.622（spawn5.126/update13.396）。没有同轮去优化基线，不宣称整帧收益；GPU motion仍默认关闭，整体高压60FPS未达成。

粒子bulk上传与GPU拉伸扩展：新增epic181_instance_buffer/--bulk-particle-upload，仅CPU普通层按20 floats/instance批量上传；5383真实MultiMesh变换max0/颜色custom一致、18帧GPU对照通过，但满高压mean43.6932ms/particles23.3178比此前42.7654/22.3366更慢，保持关闭。随后GPU current-state覆盖render_mode1，启用等上下曲线的GPU大小/颜色，传speed、保留CPU速度投影朝向；shader按Basis.scaled的全局行缩放语义对offset.y拉伸，再加noise。基础及moving-camera+varied-step+random-color各18帧1179648像素，超2/255差异0、max1/255。全Storm覆盖impact2analytic+3hybrid、missile3+3、muzzle1+3；满高压同指纹/同命中/零漏播mean43.5670/p9561.72，particles21.2175/update14.1850，其他CPU项也升高，不能宣称整帧收益；仍随--gpu-particle-motion实验默认关闭。默认CPU参考5383max0再通过。下一步更大规模物理采样/状态提交开销优化，目标未完成。
合并后的满容量技能压力与缓存成本：新增audit_surface_merge_memory，六模型原始raw buffers4999044bytes，转换6843696bytes、5缓存项（另一模型无需合并），同源重复请求同一mesh；只计raw buffers非driver/总内存。默认surface合并+full-vfx-capacity+gpu-particle-motion+breakdown固定高压实测：39模型、32zones、384额外射弹、10885area hits、相同408ccb…指纹，峰值missile120/impact85，全需求零漏播；mean42.76540/p9557.981ms，draw1443，particles22.33659（spawn4.77759/update15.60584），CPU stage28.18581。虽然较此前未合并满高压52.6ms低，仍远未达60FPS，不能用正常负载14ms替代满技能验收。下一步针对粒子逐个变换/颜色/custom上传和更新计算做批处理或更完整GPU执行，保持全部命中/弹道可见。
角色surface合并取得实际收益并默认落地：审计6常见模型blendshape均0、几乎所有面带LOD。新增surface_merge，按完整StandardMaterial存储属性（忽略资源命名）+格式分组，串接顶点/骨骼权重/索引，LOD合并所有源阈值并为各源保留对应索引；同源mesh缓存共享。native prepare_body默认空，仅world3d override默认启用，可--no-merge-character-surfaces关闭；blendshape/独立shadow_mesh/custom通道/实例surface override保留原网格。6模型×walk/attack/death×3.5/12m共36实际GPU对照通过max1/255；初始两层比较差异来自camera隐藏了layer1灯，改灯layers与cull_mask同时3后通过，未放宽阈值。固定39模型同指纹同技能需求零漏播：draw1395->689，mean21.91436->14.15265ms，p9527.753->18.928，仍非稳定60FPS。启用状态atmosphere隐藏/flash/换装回归通过，完整flow通过并查看battle；默认启用后36GPU对照再通过。下一步合并缓存内存与LOD阈值边界/完整镜头、全技能高压性能，目标仍未完成。
绘制开销实测与下一优化方向：新增audit_world3d_draw_cost，固定战斗帧40可见actor，完整1282draw/1144764primitives；相机layer排除actor后398draw，关scenery969，关actor atmosphere1159。最初hide/show actor使primitive从1144764变1157382、draw相同，故恢复断言失败，未放宽；改诊断专用layer隔离后每阶段恢复两计数完全相同。材质census：composer每人10surface但texture+base_color仅2组；george7面4组、isabella身体13面2组、joseph13面3组。此签名仅提示机会，不能直接认定全部shader/骨骼/blendshape兼容。下一步调查兼容surface合并及真实GPU外形/动作对照，目标减少角色重复绘制，保持相同模型/场景，不用删除可见内容作优化。没有本轮帧率提升声明，目标仍未完成。
角色共享光照时钟试验（默认关闭）：--shared-atmosphere-clock将全角色相同elapsed用一个RGBAF像素更新，material只绑定一次，原制服值路径保留。共享include使用WORLD3D_SHARED_CLOCK宏限定native actor shader，其他场景shader无额外采样分支。新增同视口6时间点含12h GPU对照1536000像素完全一致；默认atmosphere hidden-return/flash-clear/equipment/比较缓存回归通过。相邻固定基准同39模型/1395draw/同指纹零漏播：clock CPU光照1.65825ms vs原1.72581，仅省.06756；整帧22.1742/p9528.52 vs原22.0359/p9527.899，没有整帧收益。保留试验关闭，不宣称性能改善，不默认推广。下一步应针对更大规模材质提交、绘制和粒子位置执行开销；稳定60FPS和全目标仍未达成。
大型晶体实际尺寸补测：从biome_layout得到shell高205-220/20米、侧壁185-210/20米。GPU接地测试加--height，shell用真实mode5+rock_contact而非道具mode4；原ForestBatch contact_profile等价复制为native contact_geometry静态函数，scenery/test共享，旧版不动，移除scenery未使用的sampler Node。11m shell六组合最大地面遮挡0.160767%，10.5m prop2最大0.164474%，均过原门槛，shell图已查看。新增按height命名结果避免覆盖小尺寸记录（命名调整前两次实际结果记录于progress）。资源retirement通过。晶体右岔路连续16事件2路段，maxleg5.45s，17次刹停peakratio1.000159，无倒退；属于状态/空间检查，不是动态逐像素遮挡验收。接下来动态镜头画面对照与整体性能继续推进，目标未完成。
晶体碎石共面遮挡实际修复：contact_mesh提取到contact_geometry共享，测试新增--ground-skirt，用生产mode4、spatial-marks真实anchor和俯角-.08。prop0初始实际地面遮掉2.5945%绿色像素失败，确认高度函数与三角地面共面误差。mode3-5加.001+.0025*abs(amplitude)米支撑间距（默认3.5mm），不增加顶点/绘制；prop0最大遮挡降.262258%。九种prop各3角度2坡幅共54组合全过原1%门槛，最差prop6 .767065%；折地裙摆不能用直立底边全列贴地误差验收，JSON明确ground_skirt与contact_line_test_applicable=false。晶体36模型实战图已查看。测试只用2m道具，实际大型尺寸、shell专用rock_contact与动态视角仍未覆盖，下一步补全，整体目标未完成。
鲸鱼骨拱与六主题覆盖审计：查看whale/shell原图，6组合48底边采样max0.619080px，生产ground遮挡0.343869%，无退出警告；启用whale shell profile并查看36模型实战图。审计输出增加theme与excluded_deformed_instances，每主题独立JSON，避免复用变形网格后零样本被误报通过。六主题固定开场解析检查：forest8052、swamp866、sewer488、palace367、whale603直立候选均无>2cm埋地；crystal0候选，明确不适用，仍需实际GPU验证其不同contact模式。另六主题旋转后继路段物件/光源位置不变量测试通过。这不是动态相机和全部种子视觉验收；下一步晶体实际地形与移动过程遮挡、性能，目标未完成。
宫殿/下水道拱门接地与测试依赖清理：verbose确认退出遗留为ForestEcology/ForestWorld/IslandModel等脚本引用，不是本次新建场景节点。将base_contact_mesh原实现提取contact_geometry.gd静态共享，scenery代理同一函数；隔离GPU测试直接用它、原生资产load和anchors JSON，去掉全场景/StyleLibrary依赖。沼泽结果与之前精确一致且退出无资源警告。查看宫殿/下水道原图，实际接地6组合分别48/42采样，max0.609314/1.374969px，ground loss0.599249%/0.192563%，均保持原门槛通过。默认将palace/sewer shell加入适配；两主题36模型实战图已查看，材质顺序回归通过。鲸鱼和其他道具、全主题动态遮挡及性能仍未完成，不能将这两个静态主题验收外推整体完成。
沼泽拱顶接地默认落地：已查看swamp/shell原图，左右菌根与开放通道明确，复用共享85顶点底部profile，不改变上部拱形；仅swamp shell启用，其他主题未泛化。测试支持原生biome路径，最初宽图出画导致断言，改按完整宽高构图并先检查采样边界后，6组合42真实底边采样max0.563873px，生产地面遮挡0.625723%，通过并查看mask。完整flow通过，沼泽主题实战36模型画面已查看；没有据HUD瞬时54FPS宣称性能达标。修复profile只在首次材质创建时生成的顺序隐患，改按需初始化且继续同贴图共享材质；新增ordinary-then-adaptive材质测试通过，实际资源retirement测试亦通过。接地GPU脚手架原有退出资源警告仍待解决。下一步其他主题宽底座/原图语义与动态镜头穿插检查，继续整体性能优化，目标未完成。
落叶堆原图与接地修复：已查看style2/litter，属于三分之四视角叶片枝条堆，保留直立完整剪影，不压成俯视地贴。旧屏幕锚点.82在真实深度中埋入下部；scenery仅本3D入口将ForestEcology litter纹理的body anchor设为(.5,1)，不修改源sprite/旧版、不加顶点或批次。GPU测试增加--rigid-anchor：真实alpha、生产ground网格、3角度2坡幅，最大遮掉绿色像素0.20688%，1%门槛通过；刚性枝叶各列不是接地线，因此报告明确该线误差不适用，不能用其58px外叶高度声称失败或伪造精确贴地。解析候选8000剩2个swamp/shell埋地，litter124候选全部消除，变形树不在审计范围。完整flow通过并查看battle。GPU测试退出13ObjectDB/9resources等已有警告仍待清理；全主题和其他坡面、空间视觉验收仍未完成。下一步宽底座shell及接地验证范围补全。
偏心树根遮盖接地已默认落地：custom mode增加32标记，解码后按镜像和面片方向计算自己的中心，使用该点与父树地面高度差整体调整，保持叶片形状；全contact试验模式避免重复修正，AABB按地形幅度扩展。不新增实例/网格或逐帧CPU循环。独立GPU对照20组合（5朝向、2翻转、2坡幅）与直接放置在真实support的普通面片逐像素一致；初始0.6角差异来自custom半精度，参考明确模拟上传精度后通过，未放宽像素门槛。更新解析审计：8000非变形候选剩126，其中litter124、swamp shell2，short-grass/clover此前37埋地候选已消除；树变形不在此审计范围。完整flow通过并查看battle；固定普通负载39模型mean24.63565/p9535.649ms、1395draw、scenery CPU .69175ms，指纹不变零漏播，仍未稳定60FPS。下一步litter真实艺术接地和其他大型底座/坡面、全主题视觉验证；整体目标未完成。
森林真实穿地来源与树修复默认落地：查看fern原图确认中央根和下垂外叶不是同一条foot线。新增source_asset材质元数据，ForestEcology动态纹理映射回StyleLibrary路径；逐实例保留body/root_cover角色而不为诊断拆批，初始化计算无逐帧开销。审计旧直立候选9201：tree-b625/629埋地、tree-a333/572，litter124/124，short-grass32与clover5主要来自偏心cover；fern2194候选0解析埋地，此前强制所有foot贴地测试是泛化算法失败，不能说实际fern必定严重埋地。两树真实GPU测试已通过，现默认对带trunk_radius的body启用profile网格，root_cover及其他植物保留原路径；--contact-bases仍为全部资产试验。材质/网格批次key区分adaptive_contact；完整GPUflow通过并查看battle，终态构图未改。整个穿插问题仍未完成，接下来优先litter与偏心cover、植物接触语义，以及选择性默认的性能复测；不能以两树落地代替全范围修复。
真实资产GPU接地测试：test_world3d_contact_raster支持--asset，读取StyleLibrary真实alpha（只诊断改绿），树用12m高和正式anchor(.52/.5,.995)，植物默认anchor1，litter才.82，保留原尺寸纵横比。tree-a12采样max.5213px/地面遮挡.0683%，tree-b18采样max.603px/遮挡.0953%，通过。fern初始误用合成.82锚点失败后，已按实际1.0重新测，72采样max10.0775px、地面遮挡.9259%，仍失败，未放宽阈值或默认启用。外侧叶片最低alpha并非真实根部，17列稀疏轮廓亦会跨越叶间空隙，不能对全部植物强制压平底边。下一步分型support/root像素与悬垂叶片、root_cover偏心锚点；保持完整问题而不是只验收两棵树。测试增加按资产输出图片及JSON供失败定位；还有退出资源警告待清理。
真实地面网格接触验证：test_world3d_contact_raster新增--ground-mesh，使用生产ground.gdshader原vertex部分和同尺寸/分段PlaneMesh，fragment仅中和颜色以识别遮挡；分别无地面/有地面实际GPU图像比较。不规则底边12组合156采样max1.103px，地面遮掉的绿色像素最大0.7425%（门槛1%，约底边采样带），通过并查看world3d-contact-on-ground.png。仍是合成轮廓，不是所有真实资产的视觉验收。实际森林源图来自StyleLibrary(ROOT assets/style2)，树名tree-a/tree-b、ground_anchor .995，ForestEcology动态ImageTexture使resource_path为空；可用静态textures映射回key，下一步用真实alpha轮廓/实际尺寸与根部cover验证，再考虑默认启用。
不规则底边接地验证与修正：GPU接地测试增加--curved-foot（余弦不规则底边），旧固定网格/9列轮廓在3角度2坡幅下max5.245px失败。改17列profile与每列沿实际alpha foot安排网格行，85顶点/贴图共享，保持原图UV及实例数；--contact-bases仍默认关闭。相同156列不规则底边max1.10303px，平底156列max1.07166px，阈值1.5px未放宽均通过。最终版实际GPUflow采集通过并查看战斗图。测试末资源引用警告仍在（deferred quit未消除），后续需清理测试脚手架但不改变已读回结果。新网格比45顶点多，性能需重测；测试仍未覆盖真实地面三角形、所有复杂alpha资产/浮空分型、根部cover和全主题，所以不能默认推广或宣称穿插完成。
实际GPU接地测试定位默认采样缺陷：新增test_world3d_contact_raster，用程序生成绿色不透明底边，两底边UV/.82锚点、3角度×2地形幅度、156列，独立相机投影解析地形。初测max21.103px，中心多正常但零散列下方出现绿色细线；确认cutout art sampler重复采样将顶部不透明像素卷到底边。加入repeat_disable后同测试max1.07166px，收紧阈值到1.5px通过；默认cutout路径已应用此零新增网格/绘制修复，贴地变形仍--contact-bases诊断。测试末有8 ObjectDB/5资源退出引用警告待清理，不影响已读回像素，但不可忽略遗留。默认完整flow重新采集，模型机位检查通过。该GPU测试针对合成直底边和解析地形，不含实际地面三角插值、复杂alpha轮廓/根部cover分型和全主题验收；下一步继续这些验证及实际资产采样来源。不能据此称全部穿插已解决。
接地试验第二轮：移除统一折地apron，改每张贴图首次建材质时缓存9列不透明底边（底部30%搜索），shader仅在底边附近按实际foot高度适配地形，上部保持原位；保持共享45顶点mesh/MultiMesh，--contact-bases仍默认关闭。实际GPU battle已查看，第一轮左树明显横缝消退，截图world3d-contact-profile-experiment.png（此图在最终band防翻折修正前）。新增band=max(.08m,.08h,2abs(displacement))，保证大幅抬底时smoothstep位移导数不导致纵向翻折；最终版GPUflow重新运行。审计新增拒绝对变形模式套用原直立底边采样，防止误报“零穿插”。第一版profile性能mean22.809/p9529.981ms、draw1397，相邻默认mean24.949/p9533.609、draw1394，CPU多项亦波动，不可宣称性能提升；两者相同指纹39模型零漏播。最终band版未做性能复测。下一步必须GPU实际底边/主体轮廓和坡面/角度验证、浮空物件与cover分型、查找图片来源，之后再决定默认启用；当前没有完成地面穿插修复。
用户新增最高关注：大量物件与地面穿插。已检查scenery/cutout/ground，普通物件只根部采样地形，晶体才有contact mesh。新增audit_world3d_ground_contact：当前机位粗筛9201直立候选、12纹理，1121候选不透明底边有>2cm解析埋地，最大8.097cm；不是实际可见像素穿插数量，包含被遮挡实例，不代表全部严重穿插原因。动态生成纹理resource_path为空，审计改按纹理ID分组，后续需持久资产来源标识。新增--contact-bases试验：共享45顶点底部网格，mode6/7仅底部带地形适配并折叠下摆、扩大cull bounds，无新增实例或逐帧CPU逐物件采样；默认关闭。实际GPU流程通过但已查看战斗图，近景左树底部出现横向接缝，视觉失败，不能默认启用；截图world3d-contact-bases-experiment.png。下一步按真实alpha接触轮廓和主图/根部cover身份分开处理，不能用统一折叠或整体抬高来掩盖；必须同时验证地面三角插值、透明排序和斜坡/转向近景，性能尚未测。
接近事件缓停速度衔接：stage记录进入stopping前实际camera_origin速度，0.8秒Hermite保留起始速度并终端归零；直线且D/(vT)在[.5,.98)时按v(t)=v0(1-t^n)积分，n=D/(vT-D)，满足固定距离/时长并单调减速，避免Hermite中段额外加速。实际GPUflow加入缓停入口速度、连续直线不加速、事件终点精确断言，通过；incoming/first均61.3571路程单位每秒，81个stopping样本peak61.3571，终点准确。首事件3.17秒、16事件1岔路2路线、max_leg5.4秒均保持；实际弯道仍Hermite方向连续路径，其速度单调性及原版连续画面未验收。当前hero全流程骨骼高度峰值0.014177UV，锚点峰值0.018353UV出现在开场；这些测量不能替代独立轮廓/完整战斗/性能验收。下一步应检查曲线路径机位运动、开场角色入位与默认镜头的速度衔接，保持正式构图优先。
我方行进姿势衔接：allied_actor仅在站立/行走/跑步切换时缓存当前骨骼姿势，用0.16秒混合到按原时钟采样的新动作；只处理已有evaluation_bones，切换时缓存，无持续对全部敌人增加该开销。攻击路径维持原调用，死亡立即取消混合，换装清除旧混合。新增test_world3d_locomotion_blend四组过渡，新动作首帧角度变化小于直接切换20%，结束后姿势及clock与原路径一致，world anchor不变，死亡打断保持原始姿势；通过。实际GPU连续flow采集通过，主角全流程骨骼高度峰值0.044973→0.022303UV，边界中心峰值0.018310→0.014228UV；锚点峰值仍0.020799UV（接近事件段），不能宣称所有跳变已消失。portrait_runtime实际GPU通过模型/武器锚点、换装、机位终态、真实战斗检查；已查看入场截图。下一步仍需接近事件镜头速度接续、独立正式连续轮廓对照及完整实战，不以骨骼局部数据替代验收。
离场镜头起步修正：start_travel保存出发模板，以0.9秒smoothstep一次性消解初始camera offset并混合六个模板字段；替代首帧速度最大的指数衰减，不持续低通追赶移动目标，0.9秒后精确回到默认机位。角色尺寸/站位/移动预算不变。capture流程新增首段与再次行进六参数精确到位断言，通过。独立前后骨骼连续采样（0.01s、离场t>4.27）主角锚点峰值0.024446→0.018336UV（约下降25%），骨骼高度变化0.056819→0.044972UV；仍不是足够平滑的充分证据。16事件/1岔路/2路线连续测试通过，max_leg5.4s、max_world_step0.15355，战斗胜利仍由测试注入。查看离场截图，未改变保存终态构图；接下来需要检查实际前进开始时路线跟随速度的衔接、角色动画切换及正式版连续轮廓对照，不能称完整镜头验收。
连续构图采样发现与修复：capture_world3d_presentation_flow新增每0.01秒全部可见队员骨骼边界、脚踝/头/腰、锚点、透明度记录至world3d-flow-motion.json，隐藏后出现不跨间断误算速度，主角独立统计。发现start_battle对非主角隐藏队员直接安置战位后把安置距离/dt送给动画，造成首帧错误run；已改非重开安置使用零速度，重开真实复位仍用实际速度。新增入场第一帧idle断言通过。主角离场仍有高变化：t4.33锚点相邻0.01秒变化0.024446UV、骨骼高度0.056819UV，t4.34边界中心0.021706UV；这是待解决证据，不是验收通过。下一步聚焦start_travel镜头偏移exp(-age*7)及模板指数混合的初始速度衔接，保存原稳态机位/3秒首事件/正常角色速度约束。骨骼包围仅动态诊断，尚不能代替真实mesh轮廓、独立正式版连续帧或完整战斗验收。
粒子复用与过程画面复采：每个 Epic 层回收死亡 Particle，按历史峰值复用，活跃+回收数量不超过256；reset_particles回收仍活着的粒子并立即清空GPU可见数量，3D特效重新播放/全清采用此入口，避免旧实例残留。新增实际图形后端 test_epic_particle_reuse，Storm飞行/出手/爆炸×CPU/GPU曲线/GPU混合运动×3次循环，30015状态与MultiMesh采样一致，重复负载新增分配0；旧实现5383几何样本仍零误差。完整压力本次mean52.613/p9569.331ms，spawn4.851/update15.871/particles22.732ms，39模型、120飞行/85命中峰值、0漏特效、同指纹；单次测量，未声称稳定性能提升。重新capture_world3d_presentation_flow取得6检查点，已查看battle/travel/departing；截图HUD的FPS来自同步快进采集，不是实时性能值。当前断言只验证头部在画幅范围内，不足以证明角色占比、轮廓和过程自然；胜利为注入，非完整实战。下一步应扩展逐帧轮廓/脚底/头顶相对正式版基线的测量，继续优先验收整体构图，不以本项通过完成目标。
粒子状态类型化与混合运动进展：非局部 CloudTrail/DustTrail 和阻尼 CloudBurst 保留原 CPU 物理积分，将朝向、尺寸、噪声偏移等展示计算送到 GPU；仍只在 --gpu-particle-motion 下启用，模式 1 拉伸层继续 CPU。新增 --particle-breakdown 区分生成与更新，完整容量原字典状态单次 spawn5.412/update21.314ms。当前将粒子 Dictionary 替换为带类型 RefCounted 字段，保留随机调用顺序、年龄精度和原数学，不修改镜头/尺寸/站位。5383 原实现几何样本 max_error0，CPU 同实现 18 帧画面完全一致；混合 GPU + 变步长/移动镜头/随机配色 18 帧对照最大1/255、超差0。相同完整容量/固定步长/技能压力/分项计时：39 模型、120 飞行/85 命中峰值、0 漏特效、指纹408ccb8c…a72一致；spawn5.243/update16.617/particles23.880ms，mean53.890/p9571.900ms。以上为前后单次运行，未完成交替复测，不能宣称稳定收益或60FPS达标。默认 GPU 运动仍关闭，默认特效容量的压力漏播问题仍未解决。后续优先减少反复分配/曲线解释成本，并回到动态整幅构图与完整流程验收；不能将特效局部通过替代迁移验收。

独立效果GPU局部运动原型：新增epic181_local_motion shader，使用全精度instance transform载入不变出生位置/速度/出生时刻/寿命/尺寸/旋转/随机/图集帧，每帧仅更新发射器与相机参数、CPU回收/压缩，槽位变化时才重传。仅local=true、无重力/额外速度/阻尼/噪声、恒定旋转曲线、无sheet动画的适用层，其他仍原路径，--gpu-particle-motion诊断且与batch互斥，不默认启用。最初GPU自行判断elapsed>=life导致0.1秒光核提前一帧消失，已移除冗余判定，死亡由CPU可见数量唯一控制；18帧GPU画面对照最大1/255、超差0。完整容量120飞行/85命中峰值、0池失败/相同指纹，particles27.670ms（此前28.381）、mean57.020ms/p9575.572，收益很小，不能算并发优化达标。下一步重点是非局部CloudTrail/DustTrail（无阻尼但有旋转/噪声曲线），以及阻尼CloudBurst；局部光核支持只是基础，不应继续只优化容易通过的小层。原透明顺序保留，未开启失败的合批方案。

深度分片批量特效试验（未启用）：新增epic181_render_batch，启动时按kind/层/4m深度片预建MultiMesh，单片1024粒子、范围-8..72m，范围外保留原渲染；每个发射器粒子继续独立模拟，写入共享批次前真实world变换换算，不删粒子，容量溢出有独立计数。--batch-particles仅诊断，默认关闭；clear清空批次。单个Storm飞行/出手/爆炸18帧GPU对照通过（最大1/255、超差0）。新增test_epic_batch_overlap，4个不同深度相互重叠爆炸、4帧：丢粒子0，但2796/307200像素差>2/255、max.227，未过；两图已查看。原因方向是跨发射器按“层”合批改变透明叠加先后，不能凭单实例通过开启此方案；下一步应保留透明排序关系或采用适合的独立执行方案，不能继续无条件合并同种层。默认CPU实现5383样本读回再次max_error0，默认路径未切换。批次性能尚未测，因为视觉门槛未通过；完整特效覆盖/60FPS仍未实现。

完整容量与场景隔离实测：新增仅诊断--profile-no-scenery和--full-vfx-capacity（missile160/impact128/muzzle24），benchmark记录实际容量/scenery_drawn，默认容量未改变。隐藏scenery但保留其CPU更新，39模型/同压力指纹，draw1550→1238、mean31.317→30.754ms，特效仍8.710ms；这组负载不支持把森林撒布当主要瓶颈。完整容量实际GPU：峰值missile120/impact85/muzzle7、粒子3727/2210/222，所有407飞行/637独立命中/54出手请求均分配成功；相同384额外弹道/10885区域命中/408ccb…指纹，draw2146、particles28.381ms、mean57.164ms/p9574.233。该模式证明容量需求，绝非性能达标，不默认开启。下一步建议同种效果同层共享MultiMesh/材质、保留每个发射器粒子状态及真实位置（而不是再合并独立命中），用GPU帧对照验证世界变换与透明排序，再测同完整容量；CPU粒子运动仍需继续缩减或迁移。full_vfx字段仍false是因为这不代表未来所有技能特效已实现；本测试已知三种Storm效果的分配覆盖为100%。

粒子层级配置提取与零模块跳过：epic181_effect每层每次advance读取local/render_mode/mesh_basis/velocity/sheet/dampen等公共配置，重力/旋转/噪声仅严格[[0],[0]]常量时跳过逐粒子采样，仍每次读取配置避免固定缓存掩盖运行时修改。不减少粒子、不改变RNG/时间/非零曲线。原CPU冻结实现5383样本GPU readback max_error0通过；默认GPU大小/颜色18帧1179648像素对照超2/255像素0、最大1/255再通过。固定技能压力39模型/1550draw/同408ccb…指纹/同384弹道和10885区域命中，particles8.585ms（此前11.270）、stage16.401ms、mean31.317ms/p9539.718；仍720分配失败（missile315/impact405）。单对测量显著减少当前CPU特效开销，但高并发完整显示、稳定60FPS未达到；下一步并发池执行方式与场景/模型渲染提交均需继续优化。

GPU颜色曲线接入并默认用于已验证后端：粒子生成时把颜色随机因子编码为两字节缓存（不额外调用RNG），经实例COLOR通道传递并在vertex重建，初始min/max颜色用普通uniform，渐变从已有RGBAF曲线纹理计算；生命周期继续高位+放大残差，size保留高精度基变换。原Storm18帧和--random-color双端异色/不等长渐变18帧，同视口逐帧GPU图像比较均超2/255像素0、最大1/255。压力同指纹/同需求/命中下particles11.270ms、mean34.479ms/p9544.658，仍720次池失败。world3d projectile_view现仅gl_compatibility默认启用适用层，其他后端及--cpu-particle-curves保留CPU；共享Epic FX本身gpu_curves默认false，旧预览不自动改。普通固定战斗默认路径复测39模型/1394draw，同原64c8…指纹，mean22.259ms/p9527.885、particles1.642ms、分配失败0，仍未稳定60FPS。默认CPU引擎样本对照5383 max_error0再通过。该进展没有解决高并发全部弹道与命中可见，下一步继续处理池容量与粒子位置/姿态执行开销，不可把普通负载零失败外推到压力负载。

GPU曲线测试基线纠正与首轮通过：新增--cpu-control，两份原实现的独立视口竟产生同样1538差异，证明此前剩余差异不能归因GPU。改同视口同相机冻结时刻轮流显示并等待提交；逐层原实现完全一致，全层爆炸仍不同，粒子Dictionary/transform/color/custom逐项断言相同。根因是重叠透明层排序依赖实例创建的内部次序。epic181_effect为各层加sorting_offset=-层序*.001，小深度偏移打破同位置平局，保留不同世界位置深度关系，不用全局material priority。修复后CPU-control18帧1179648像素完全一致；GPU大小曲线对照同样18帧，最大通道差1/255，超2/255像素0，通过。爆炸GPU截图已查看。实际同负载GPU mean35.545ms/p9545.650、particles12.445ms；随后默认CPU mean36.340ms/p9544.904、particles13.133ms，fingerprint/请求与命中一致，池失败均720。仅均值小幅收益，p95未改善，仍保留诊断开关不默认启用；当前只迁移适用大小曲线，颜色等仍CPU，更完整并发架构/可见覆盖与60FPS均未达成。此前“爆炸层GPU未通过”的定位已被这一对照证据更新，不应继续沿错误基线排查。

GPU实例参数精度隔离：test_epic_gpu_curve_values新增--uniform-input与--residual-input；相同纹理与4组t/random/start_size，普通uniform输入全过而原INSTANCE_CUSTOM失败，确认偏差在实例输入链。生命周期用half高位+残差，未放大残差时.1/.49仍失败；残差×2048传递、shader除回后四组均通过（差值×10000后的8bit读回0，不代表无限精度严格零）。实验路径初始尺寸改留在transform，只有两端相同的size曲线且非stretch才走GPU；不适用层/微小初始尺寸保留CPU。完整18帧仍1538/1179648像素超差，主要爆炸1493，未达门槛，GPU默认仍关闭；因此下一步检查爆炸层实际几何/纹理采样，不重复把已通过输入测试当完整渲染通过。默认路径GPU 5383样本对照仍需保持一致，本轮已安排复核。高并发完整可见/60FPS仍未实现。

GPU曲线排障进展：epic181_particle图集tile_index改为flat varying，离散帧号不再插值后floor误入上一格；实际对照差异5439→1667像素，仍未通过，不能把此修复等同曲线完成。新增test_epic_discrete_frame以生产vertex路径、旋转缩放12帧检查93648有效像素，错误帧0，通过。新增test_epic_gpu_curve_values以4组t/random/start_size、非相同min/max曲线，将GPU尺寸与CPU期望差值放大10000输出：.588、1、.286、1（后两组1表示饱和，不等于精确误差），验证尺寸数值链本身仍有偏差。highp sampler限定未改变18帧结果；不是根因已解决。下一步检查Compatibility实例custom传递精度/曲线数据，勿再次猜测颜色量化已证实。GPU曲线仍仅诊断开关、默认关闭；帧号flat修复应用于现有默认特效材质。

GPU粒子曲线实验（未通过，默认关闭）：新增epic181_gpu_curves RGBAF采样纹理、shader可选大小曲线计算、--gpu-particle-curves诊断开关，stretch模式仍走CPU。最初同时迁移大小/颜色，双独立SubViewport、相同种子/相机/姿态/非均匀缩放，Storm飞行/出手/爆炸18帧GPU截图对照5446/1179648像素误差>2/255，未过0.05%门槛。逐层0/1各仅25/22像素，层2合计4656，重点在爆炸烟雾层；移除GPU颜色计算后仍5439像素、max0.561，因此颜色不是充分解释。尝试颜色量化未改善已移除，禁止把该假设记为事实。当前shader只实验大小、颜色保留CPU；纹理仍留完整曲线便于排查，未用于默认战斗。test_epic_gpu_curves支持--layer=N并保存实际CPU/GPU截图；失败现在明确quit(1)，避免断言悬挂。最后旧默认路径5383样本GPU对照max_error0通过。仍需验证GPU实例数据/曲线采样/大小变换，未跑性能、未声称等价或优化完成。本轮是新执行路径试验和定位证据，整个高并发问题仍未解决。

特效分配按种类拆账与重叠命中合并：projectile_view新增requested/dropped/active_peak/particles_peak统计，粒子数量遍历仅profiling时执行。原压力请求missile407/impact974/muzzle54，失败315/735/0，峰值24/24/7，说明不能仅优化出手或笼统称池已解决。group_impacts仅在同一advance、相同target、三维距离≤.625模拟单位（.25m）时共用一次命中反馈与闪光，保留首个真实接触点，不改变/合并伤害；不同target/较远接触/高度/后续帧独立。纯逻辑测试通过。实际GPU同压力合并337重叠命中，impact请求637、失败405，missile仍失败315；总失败720，比1050减少，但仍明显不足。相同fingerprint/384额外弹道/10885区域命中，mean36.285ms/p9546.101、particles13.062ms，无可信帧率改善，主要提升有限池对不同接触的覆盖。下一步需改变高并发粒子执行/表示方式而非继续压缩独立命中；全部弹道可见与完整高负载特效仍未完成。

齐射出手特效共享：projectile_view原先同帧同源同绑点每条弹道都创建muzzle，12发齐射叠12份。现按[source_id,enemy,真实发射位置+构图offset]在当前advance内合并出手闪光，其他位置/施法者及不同帧仍独立；missile/impact/伤害不合并。相同技能压力负载384额外弹道/95峰值/10885区域命中/相同408ccb…fingerprint，合并353次muzzle，particles13.089ms、mean36.305ms/p9546.402、1551draw，分配失败仍1050次，完整显示未解决。此前尝试MM整层buffer提交，5383样本几何颜色相同但实测particles17.973ms、mean41.196ms，较原逐粒子提交16.829/40.542更慢；已移除该试验运行代码和开关，保留测量结果文件，勿重新默认启用。移除后原对照GPU再测5383样本max_error0通过。该轮进展是减少同一次齐射重复出手层，不代表所有技能高并发达标；仍需解决弹道/命中池容量及更高效的粒子执行。

技能并发压力证据与无损特效优化：benchmark新增--skill-stress，32持续区域/.2秒tick、每15固定帧最近12目标多弹道（穿透3目标）加爆炸/走廊，单次伤害.01保留负载；8秒384额外弹道、峰值95活动弹道、10885区域命中。实际GPU原样mean44.583ms/p9556.782，simulation.676ms、particles20.294ms，39模型/1592draw；特效池分配失败1193次，不能声称所有弹道都有完整原包表现。优化epic181_effect常量标量/颜色采样快速分支，禁用阻尼跳过采样，零噪声跳过三角计算，未改粒子数量/随机序列/播放节奏。冻结原实现对照5383样本GPU max_error0且颜色图集一致，通过。相同压力复测mean40.542ms/p9550.996、particles16.829ms、simulation.684ms；同fingerprint408ccb8c329edb01679d89e1c795dbc3a93f36a819ee49cbc1f24fb2c0538a72及相同数量/命中/失败统计。单对测量粒子下降约17%，不是60FPS达标。下一优先级为特效并发架构和池容量/表现分配；不得通过忽略分配失败宣称多弹道完整接入。原包可视质量未降低，但高并发完整显示仍未完成。

贴图预算与退场资源清理：benchmark新增计时结束后的cutout_texture_storage统计（避免读回污染帧计时），scenery记录texture_prepare_usec。实际GPU固定480帧复测39模型/1394draw/相同final fingerprint，mean22.929ms、p9529.553ms、stage9.944ms；30源图共32971796字节，20张生成采样副本共17538668字节（约16.73MiB），准备累计60.162ms。这些是图像数据量，不等于驱动实测显存，稳定60FPS仍未达成。发现retire_before仅释放chunk，by_texture/materials/mesh_cache/contact_cache继续持有全部经过的美术资源；现退场和上传作业结束时剔除无活动chunk且无待上传引用的缓存，保留共享/即将使用资源。新GPU test_world3d_art_retirement验证存活共享、等待上传保留、所有缓存解除后WeakRef实际失效、未来重新使用可重建，通过；连续行进16事件/1岔路/2段路线复测通过，最长5.4秒、最大单步0.15355，战斗结果仍为测试注入，不代表完整战斗平衡或长时显存上界已验收。源world/全局资产库持有的原图不在本次清理范围。

物件细碎斑点根因与修复：旧ForestBatch给合并atlas执行generate_mipmaps；原生cutout虽声明filter_linear_mipmap，却直接绑定没有mip的源图。宫殿诊断10/10纹理缺失mip；--ensure-mips实际GPU对照后碎斑明显消退，保持原尺寸/机位/灯光。新增texture_sampling.gd，在每个场景材质首次建立时为缺失mip的静态贴图创建采样副本，已有mip直接复用，原资源不改动。GPU test_world3d_texture_sampling验证原图无变化、base像素逐字节相同、已有mip复用、棋盘远层采样灰值0.502，通过；初次64像素窗口测试采到背景，已改320x240及相机投影定位采样，未降低断言。正式content_frame同world/pose复查3483物件与7槽通过，森林截图已查看，宫殿正常路径采集通过。新增mip约占副本base的1/3，且无mip源仍由world持有，额外副本内存与首次生成耗时尚未量化；不能宣称性能改善或整个场景验收。下一步继续实际动态流程/整体画面与负载预算，勿把本项局部修复当作完整3D迁移完成。

本轮画面排障：宫殿同世界1659物件的实际GPU对照，新增capture_world3d_comparison诊断参数--no-cutout-prepass与--hide-ground，输出独立后缀避免覆盖正常图。分别运行并查看：去掉预深度并未消除物件细碎斑点，反而改变墙体遮挡；隐藏地面后斑点仍在，因此两者都不是充分修复，不改生产渲染开关。后续需隔离贴图采样/透明边缘与旧canvas渲染差异。雾排序测试实际GPU再次通过；verbose退出残留定位为style_library、route、forest_world、forest_settings、forest_ecology五个GDScript及三个NativeClass，并非已证明的场景节点泄漏，仍未解决。两个画面测试新增headless拒绝，防止dummy后端被当成GPU验证。此前状态答复仅确认保存，属无实现进展；本轮已恢复具体GPU排障及可复用诊断代码，目标仍未完成。

雾片叠加顺序修复：旧ForestBatch对动态雾/光点按相机轴far→near排序，原生mist_batch此前直接使用world_mist生成顺序（通常near→far，且岔路分支相互穿插），透明叠加错误。现每帧按view_heading轴排序后上传，未增删雾片；mist光照点也改为altitude+有符号局部高度（此前max(0,p.y)遗漏高度）。宫殿同world双渲染采集成功，原生图已查看；新增GPU`test_world3d_mist_order.gd`三种朝向下验证远蓝/近红半透明叠加，通过。测试退出有8 ObjectDB/5 resource残留警告，未把清理状态记为通过，仍需定位。该验证不含所有雾片与静态透明物件交错排序，整场雾视觉复原仍未验收；enemy_light_strength源函数固定0，未重新引入用户此前要求去掉的敌方额外泛光。

主题远景诊断更正：运行正式`test_biomes.gd`实际GPU全部23项（5基础非森林+18扩展主题）行进/战斗采集与基础断言通过；已查看crystal/whale/palace正式战斗图，旧版原有部分高大竖直边界。再运行`capture_world3d_comparison.gd -- --theme=palace`，用同一个原生world、同机位分别调用3D和旧SegmentView渲染器，查看两图确认远处黑色拱形/裂口轮廓在两边均存在。因此不能将其判定为迁移新引入的墙体布局错误；共享world对照仅用于渲染诊断，不能替代独立正式版全流程验收。更明显的剩余差异是雾覆盖/透明物件清晰度，下一步聚焦雾着色与排序，不擅改墙体撒布。正式theme采集在旧实际行进160位置，原生主题巡检从0准备态开始，非相同路线位置，不能直接逐像素比较这两套主题图。

六主题实际GPU画面巡检完成：新增`capture_world3d_theme.gd`使用正式展示外壳、当前战斗机位、120固定步长并逐帧渲染，独立进程顺序采集forest/crystal/swamp/sewer/whale/palace六张`world3d-theme-{key}.png`，均phase=battle、36模型，全部图片已查看。主题纹理/雾色正常分化，但多个非森林主题远处有明显竖直轮廓边界/黑色空隙，palace与sewer视觉相近；尚未有这些主题对应正式版相同机位图，不能把源资产特征误判为迁移bug，也不能视为美术验收。下一步应独立采集正式主题对照，分离原图轮廓/路线剪裁/近远排序。截图HUD短时FPS不作为性能指标。

主题混合批次修复：scenery此前texture+cell分组、由第一个物件决定grounded，复用纹理跨主题时可能整组套错接地几何。现group key加入实际grounded，build读取组属性；同组后出现shell也会安装contact_profile，避免仅首项非shell就漏装。新增`test_world3d_mixed_geometry_batches.gd`用同一纹理、同cell、forest普通/crystal贴地/后置shell，在实际OpenGL后端验证2组、3实例、模式1/3/21和接地profile，通过；同世界3483撒布与站位对照仍通过。

测试证据校正：该测试在headless模式首次读回MultiMesh模式失败，改用实际GPU后通过，确认dummy后端不适合这类渲染数据断言。此前粒子测试的headless几何/颜色读回证据不足，已在实际OpenGL重跑，5383样本max_error0及color/custom相同通过，reference68018us/current61888us。两项测试现明确拒绝headless，避免以后产生虚假渲染证据。全项目其他依赖dummy渲染读回的旧测试尚未整体审计，不能把headless绿灯当GPU验收。

物件光场高度复原：cutout原先point.y一律max(0,p.y)，遗漏自身altitude并截掉锚点以下的美术高度；正式shader只有grounded的地面足迹clamp，普通面片保留带符号高度，固定plane_heading的base_altitude为0。现按对应模式修正light_altitude及point.y，不改变world坐标。新增GPU `test_world3d_cutout_light_height.gd`保留生产vertex路径、直接显示光场高度，验证上下两点×0/.4m高度共4例，通过；同世界正式内容/站位对照仍通过。尚未证明整图视觉一致，此项是具体光场输入偏差修正。

植物柔边裁切修复：源forest_batch不裁掉低alpha像素，迁移cutout此前仍有tex.a<.12硬裁切，造成素材柔边丢失。现只跳过完全透明像素，保留全部非零alpha与原淡出乘积；`test_world3d_cutout_fade.gd`新增8%透明度背景贡献检查通过（同时原普通/岩石/斜放/雾遮挡检查通过）。读取root_cover两边实现后，尺寸、锚点和镜像换算未发现明确差异，未擅自调小树根层；前景密度问题仍需进一步区分透明批次排序与地形/光照。保留柔边可能增加低alpha片元开销，尚未单独性能测量，不能声称本轮优化了帧率或完整森林复原。

物件近景淡出复原：正式forest_batch用center_depth整体淡出，普通类别16–70、shell类别18–95；迁移cutout此前用每顶点depth且全部16–70。现以锚点深度计算near_fade，新增instance mode的16位标记shell，与既有8位发光/朝向/接地模式独立；远景淡出继续使用顶点深度，与原规则相同。GPU `test_world3d_cutout_fade.gd` 扩展验证岩石较长淡出、斜放平面两侧同alpha、前景雾仍覆盖，通过。独立正式同世界/同姿态内容对照再次通过，3483项撒布与7槽未改变；本轮截图已查看。此修正针对已有规则偏差，不能解释或解决所有前景密度、雾分布和地形贴合差异，完整美术验收保持未通过。

粒子更新减少分配与重复采样：`epic181_effect.gd`在生成粒子时缓存固定start color、存活粒子原数组稳定压缩、速度Vector3直接构造并复用一次逆朝向，保留发射次数、顺序、随机数调用及粒子几何。冻结本轮修改前完整实现为`tests/fixtures/epic181_effect_reference.gd`；`test_epic_transform_cache.gd`对Storm飞行/出手/爆炸在旋转、非均匀缩放、移动相机下逐帧比较5383个粒子，几何误差0、颜色/图集帧相同，通过。交替顺序微测reference65447us/current58519us（约10.6%下降，单轮）。固定战斗复测仍39模型/1394draw/相同最终状态校验值，mean22.670ms/p9530.067ms，粒子2.319ms、stage9.826ms、池miss0；比此前整帧26.631ms更低，但所有分项都下降，不能把整帧差额全归因于本次优化。仍未达到稳定60FPS，未来完整技能负载未覆盖。

固定战斗进度性能工具已接入`benchmark_world3d.gd -- --presentation --fixed-step`：120帧预热+480帧采样，每帧模拟1/60秒，测试内固定随机种子，独立于机器帧率推进；记录最终敌人id/type/位置/hp/state的SHA256。首次基准与`--compact-skins`对照均39模型中位数、1394draw calls、sim.clock9.95、最终状态校验值64c8aeff82f4e5cf10375d771767312104514827cef9d745f19619acec8114e2完全一致。基准mean26.631ms/p9534.116ms；压缩mean25.639ms/p9535.157ms，均值约降3.7%但P95变差，单对测量不证明稳定收益，压缩继续非默认。这个固定步长模式用于一致负载性能诊断，不能代替正常实时流的体验或完整技能负载验收；原实时模式保留。

角色环境参数比较去重：actor_atmosphere把灯光/雾等共享参数每帧比较一次，用shared_revision让连续可见组接收差量、跨多版本隐藏/新装备组补齐全量。角色锚点、近景矩阵、透明度仍逐角色同步。扩展`test_world3d_atmosphere_updates.gd`验证隐藏期间跨3次同步再显示、装备刷新/闪光清除/开关和52组可见情况；参数比较次数1196→431（减少约64%），不变状态写入0，全部通过。这是可直接计数的冗余减少，非FPS提升证明。真实展示复测mean24.651ms/p9531.701ms，38模型中位数，stage11.054ms/环境1.881ms，池miss0；整帧均值反而高于前次，存在其他负载/机器时序差，不能宣称性能提高。稳定60FPS未达到，需继续固定负载分项测量。

近景模型轮廓GPU验证通过：新增 `test_world3d_enemy_silhouette.gd`，同一实际模型/冻结姿态分别用独立透视Camera3D与单世界近景shader渲染，再按正式画像矩形采样比较轮廓。5种敌人×walk/attack/death，15组，轮廓交并比最低.98503（阈值.96），其余约.985–.993；所有图像有>100有效轮廓像素，排除空白假通过。保留纹理alpha镂空，去掉描边/照明，只验证几何及头发/服装的轮廓投影；采样为同一近景位置与统一scale.73，不能代表所有距离、巨型比例、场景遮挡、雾/补光、连续切换或完整正式版图像通过。参数层144组覆盖另有记录。

跳过远景矩阵后的展示性能复测：mean23.449ms/p9532.941ms、40模型中位数、1402draw calls、stage10.634ms、环境更新1.908ms、视觉池miss0。与此前23.965ms测试的模型数不同（38），不能作为严格性能增益证明；仍未达到稳定60FPS，后续需要固定模拟序列/冻结负载对照与进一步减少每材质参数写入。

上一轮长时间runtime验证已结束：session74151返回exit0和`WORLD3D_PORTRAIT_RUNTIME_PASS`，对应process152188已不存在。检查覆盖装备刷新/切换、移动锚点、事件与战斗关键帧、近景敌人uniform同步、附件真实深度、出手点及轨迹回归、死亡与恢复的锚点/透明度。`world3d-portrait-runtime.png`已查看；这是原始工程入口且测试中关闭了环境着色，不能把该图作为正式展示外壳的美术/亮度验收。此前待运行记录现已标记通过，不再等待或重启该句柄。

近景投影扩大参数验证：`test_world3d_enemy_projection.gd` 使用独立Camera3D.unproject_position对照3体型×3横向位置×4距离×4姿态点，共144组，最大模型空间误差5.11e-7，通过；125–160像素混合区间的逐像素权重连续单调检查通过，远处参数归零。出手更新顺序已读代码确认：stage先配置camera与敌人near参数，再执行projectile_view.advance，未发现上一帧矩阵被用于该路径的问题。完整 `test_world3d_portrait_runtime.gd` 仍未返回检查结果，session74151/process152188最后检查仍存活且CPU累计继续增加，不能记为通过或仅因观察超时重复启动；未能确定其停留位置，后续应保留该运行句柄并补足测试进度观测。

敌人近景投影已接入共享3D渲染：`enemy_portrait_projection.gd` 解析构造正式近景相机的eye/朝向/fov及脚点投影，shader保持实际clip.z/w，仅校正屏幕xy。所有敌人继续实际骨骼、同一世界；未增加画像视口。125–160逻辑像素画像高度之间平滑混合，避免复刻旧的硬切换；这段混合是有意改进而非逐像素一致。身体、描边、武器与环境后处理共享参数，飞行道具出手点同步且保持真实深度。独立正式采集11组已进入完整近景区间的6骨骼点比较通过，最大约.000122px；GPU `test_world3d_portrait_depth.gd -- --near --atmosphere` 验证两处位置的前/后实体及透明前景遮挡通过。这些不等同于完整动态角色GPU轮廓验收。首次展示压力测量38模型中位数mean23.965ms/p9533.136ms，stage10.884ms/环境2.103ms，较此前有额外开销；随后已跳过远景无效矩阵计算及未启用构图时的更新，尚需复测。稳定60FPS仍未达标。

敌人独立距离采集已完成：新增 `tests/capture_formal_enemy_framing.gd`，实际正式 `defense_route` 运行五种模型，固定远/中/近三个距离、同一朝向和路面站立姿态，输出 `formal-enemy-framing.json` 与三张 `formal-enemies-{far,middle,near}.png`。这是受控构图采样，不是连续移动验收。正式远处四种普通敌人使用正交画像，1.8倍巨型敌人已经进入近景独立透视；中/近五种均为透视，镜头位置和fov按每人相对位置重算。因此不能将我方弱投影规则全套敌人。用同一实际骨骼点对比平铺投影的解析误差：远处四种普通敌人约0px，巨型1.90px；中景7.82–9.89px；近景35.36–52.83px。近景截图已查看，巨型占幅显著高于普通角色，不能随意统一缩小。后续需要单场景shader内复原原近景投影的方向/fov和ground_uv锚点，并保留真实深度、物理位置与出手点；不重建每个敌人的独立渲染视口。当前该修正尚未实施，敌人动态构图仍未验收。

最新复核：重新运行 `test_world3d_content_frame.gd -- --matched-pose --formal-world` 通过，3483项撒布纹理/位置/尺寸一致，7槽最大差异6.6e-10路程单位，运行时同姿态骨骼投影误差<.02px。两张GPU截图已再次查看：总体角色占幅与落点接近，但头部/服装轮廓、前景植物密度与雾仍有差异；骨骼对齐不能代表轮廓、材质或动态镜头完全复原。当前正式参考仍为防线准备态，未覆盖持续来敌的远中近占幅。用户要求的完整战斗画面验收保持未通过。

蒙皮实验补充：实际GPU五模型×walk/attack/death×两个距离共30组原始/压缩对照，RGBA最大字节差0；正权重79764项和全部原始LOD数据保持一致。实验仅 `--compact-skins` 启用，默认关闭；有blend shape、独立shadow_mesh或非16字节蒙皮布局直接跳过。当前五模型独立shadow_mesh数量为0。连续两次展示外壳测量：压缩mean21.379ms/p9528.671ms，对照mean21.552ms/p9530.462ms，均38模型中位数；平均差异约0.8%，且draw calls不同（1361/1340），不足以证明稳定性能提升。保留实验开关，不默认开启；仍未达到稳定60FPS，也不包含未来完整技能负载。

蒙皮绑定压缩实验已实现（尚未接入默认运行）：`skin_palette.gd` 直接重排原始16字节顶点蒙皮索引，保留全部Skeleton骨骼、绑定名/逆绑定变换、权重、压缩顶点/索引/UV数据及LOD字节。源资源只读，按mesh+skin缓存，5种来敌绑定数量由261/355/258/517/404变181/200/88/315/242。`test_world3d_skin_palette.gd` 核对79764个正权重的绑定目标/变换等价，并逐surface验证原始几何与全部LOD未变，通过。ArrayMesh原始surface回填在当前Godot4.7.1实际验证。含blend shape或非16字节skin stride模型跳过；尚需GPU多姿态/多距离画面对照、遮挡边界/影子网格确认及开关性能测量，**不能宣称已提升FPS或默认启用**。

连续实际行进验证：新增 `test_world3d_continuous_travel.gd`，不跳传距离/角色位置，逐帧经过16个事件、1个岔路与1次后继场景接续（route2），每个战斗先实际进入战位，再测试代码主动结算胜利以继续验证离场。最长路段5.4s，最大本帧世界位移.15355m，所有travel/stopping帧都不超过正常奔跑预算，未出现路线进度停滞。headless检查耗时约6.5s。这是连续行进/选择/进场/离场/接续的逻辑证据，不是16场战斗平衡、GPU性能或连续动态美术验收。

角色移动目标持续滞后修复：此前路线每帧全速推进，而角色从战位斜向归位也消耗同一速度预算，造成无法追上移动目标。新增travel_progress，以角色本帧可走世界距离寻找可达路线进度；未归位时允许斜向向前接近，但不让抽象路线继续逃离角色，禁止额外提速。曲线路径/微起伏、两种起始偏移的单元检查证明速度不超预算、route单调、最终追上目标。真实展示流程首事件3.168s，重开和转弯通过；修正了旧测试只跳route距离到岔口却把角色留在上一战场的不真实fixture。六时刻GPU截图重新采集并检查。需继续验证长途及流式接续、不同行阵的离场时间，不代表完整流程验收。

正式跑图独立基准与持续镜头滞后修复：新增 `capture_formal_travel_baseline.gd`，隔离会话加载实际expedition_route，模拟真实移动1.4s（非编辑器）。正式主角相机相对depth约24路程单位，头部归一化x约.264；原生镜头low-pass追逐移动目标造成持续约7–8单位落后，头部x约.323。现仅衰减启程瞬间的镜头位置误差，同时随路线移动，不再每帧追赶移动目标而积累稳定滞后。实际截图已查看，主角回到更靠左、更近的跑图构图，x约.256；depth仍约22.42，涉及角色从战位追赶移动目标的初始移动差，尚非完全复原。当前展示入口流程复测首事件3.102s，无镜头越过主角，重开与岔路通过；继续独立验证角色起步与停靠过程，不能用截图相似替代完整过渡验收。

过程图复查与武器渐隐修复：新增 `capture_world3d_presentation_flow.gd`，采集跑图1.4s、事件、进入战斗、战斗、离场.3s及再次跑图六个时刻（胜利为主动设置的流程隔离条件，不是实战通关）。检查图像发现非主角队员消失时武器基础材质残留亮影；现allied_actor将opacity同步到附件，弱投影武器按身体同一dither丢弃，普通材质使用alpha hash，完全透明时隐藏附件，恢复时恢复原透明模式。重新查看离场/再次行进GPU截图，亮武器残影消除。runtime检查追加.25/0/1透明度和附件恢复并通过。当前跑图截图仍是较完整角色可见，不能据此宣称已复原用户要求的腰部构图；需要独立正式跑图基准进一步验证。截图HUD因手动步进不反映性能。

动态材质回归：`test_world3d_prop_projection.gd` 使用实际GPU渲染，三种相机角度(0/±.65rad)同一道具宽度均52px，透明度.25像素混合通过，前/后不透明几何遮挡通过。`test_world3d_flow.gd -- --presentation` 已测试当前用户入口（含传统构图、角色/道具环境着色及新的植物透明混合），首事件3.102s、最大单帧世界步长.05183m，镜头始终在主角之后；原位重开、胜利弹道清理和爆炸尾光、岔路真实转弯通过。这不是完整冒险或全部过程镜头的美术验收，仍需继续正式动态画面对照、跨批次透明排序、技能和性能工作。

道具环境着色已接入：此前原生道具Sprite3D走普通受光材质，缺少正式category5的环境色/深度雾/提灯映射。新增prop_atmosphere shader/service，按相机朝向的真实世界面片绘制，复用正式lantern_atmosphere（不额外叠environment_surface），同步场景色、雾、虚拟弹道光、原地渐隐；和现有环境着色开关联动，关闭恢复原材质。每个道具缓存参数，相同状态0次写入。`test_world3d_prop_atmosphere.gd` 通过原位透明度、闪光清除、开关恢复与无冗余写入检查；同世界GPU截图已查看，书/面具明暗改善。未据此宣称全主题/动态遮挡已通过，道具shader在不同相机方向与深度交叠仍需后续图像验证。

前景淡出修复：cutout材质同时使用ALPHA_SCISSOR导致近景渐隐残留片元变实心；移除scissor、保留低alpha纹理discard与depth_prepass_alpha，让正式smoothstep淡出保留连续透明度。实际GPU双色背景测试测得背景贡献.58431，理论.58299，通过。透明植物批次设priority=-90，位于角色环境后处理(-100)后、雾前，修复改用透明混合后雾被整批植物覆盖的问题；新增前景雾可见性GPU断言。已查看同场景截图，前景植物恢复半透明、雾恢复显示。尚需检查跨批次透明排序、其他主题及移动过程遮挡。移除scissor后、设置priority之前的展示入口性能为mean20.213ms/p9526.149ms，38模型、1358draws；这不是最终priority版本的性能证据，也不表明达成60FPS。

独立同世界对照完成：正式采集现包含route_zone、实际distance、ForestSettings和3483项撒布纹理路径/位置/尺寸。`test_world3d_content_frame.gd -- --matched-pose --formal-world` 用明确的临时路线fixture生成同一世界，再使用正式战场位置与骨骼姿态，逐项验证3483项完全一致；运行时（含主角锚点）骨骼投影到正式屏幕位置误差<.02px测试通过。截图 `world3d-formal-content-frame-matched-same-world.png` 已查看：前景植物遮挡、雾分布以及道具明暗仍有明显差异。匹配对象表不代表GPU图像相同，也不表示完整战斗/行进过程镜头完成。此fixture不读取/写入玩家存档，只用于定位独立正式参考的差异，默认冒险仍使用原生connected/主题路线。

森林资源遗漏已修复：正式 LocalRouteSpec 使用 StyleLibrary.space 对森林替换当前style2地面、地面 tint、顶部色、环境色及雾色；原生 THEMES 此前直接读取旧 forest.tres。现森林及connected里的森林区段均经同一StyleLibrary转换（复制资源，不覆盖旧文件），其他五主题继续用BiomeCatalog。独立正式采集新增space参数，内容对照测试逐项验证实际地面texture路径和ground_tint/ambient/top_color/depth_color/haze_color一致，测试通过；本轮GPU图已检查，原先异常偏绿/黄的地面已改变。正式测试为短直线3483撒布，原生为connected6797撒布，路线跨度不同；这两个总数不能用来判断资产不足，后续需在同一空间范围比较对象与尺寸。

展示入口环境着色已默认启用，并把主角画像竖直偏移同步到环境光高度采样。已检查同姿态GPU图：原先显著偏亮的角色得到压暗，但不同世界位置的光场/地形仍不可直接作为最终逐像素对照。环境材质更新测试通过（初始525次写入、相同状态0次，死亡/复活偏移、装备刷新均同步），实际GPU前后/透明遮挡测试通过。新增 benchmark 的 `--presentation` 路径测量当前真实展示外壳：385帧、38模型中位数、1355 draw calls、mean20.803ms、p9527.943ms、stage脚本8.999ms、环境着色1.507ms、视觉池miss0。**仍未达到稳定60FPS**；测试含Storm颗粒，非未来完整技能负载。记录 `world3d-benchmark-profile-presentation.json`，不要引用截图HUD的短时FPS代替这个结果。

主角画像锚点已接入实机：弱投影共享include新增竖直偏移，按原画像2.6m、角色scale与(.93-.8846154213)换算，身体/描边/武器/角色环境后处理同步；飞行道具出手偏移使用同一参数，物理轨迹与世界站位不变。死亡以原速率2.5/s退出锚点偏移，复活反向恢复。实际 `test_world3d_portrait_runtime.gd` 已验证身体和武器uniform同步、半程/死亡/恢复、出手位置、轨迹回归与不改世界位置。注意这里只移植锚点偏移，旧版死亡画像摄像机的俯视/放大变化尚未整体移植；完整死亡视觉及不同动画的GPU遮挡仍需验收。已检查本轮同姿态GPU截图，主角整体位置上移符合规则，地形采样差仍保留。

剩余位移已完成解析归因（未冒充实机修复）：正式防线相机位于route y≈169.396，原生准备态从0附近开始，ForestEcology的世界高度采样不同，分别造成主角-12.214px、队员-11.742px位移。正式主角 `SceneFormation` 用 ground_anchor.y=lerp(.93,ground_uv,corpse_frame)，站立为.93；队员为真实画像 ground_uv≈.884615。主角额外画像锚点差约31.78px，与地形差合成此前19.57px。独立正式姿态测试把这两个可计算项分离后，12个骨骼点均通过剩余误差<.02px断言。不是任意校正值。下一步实机需保留主角画像锚点规则，连同武器、补光后处理、出手位置和死亡过渡一并处理，不能仅平移身体导致附件错位；对照地形必须位于同一世界坐标，不能改变真实地形来追截图。

同姿态分离结果：正式基准现保存全部骨骼姿态和身体朝向，`test_world3d_content_frame.gd -- --matched-pose` 只复制这些姿态，保留原生站位、地形和镜头。普通透视的骨骼屏幕误差最高约101px；传统角色投影下，同一角色所有六点误差变为相同整体位移（主角19.57px、队员11.74px）。这支持角色内部比例差异来自普通透视，尚有整体落点/地形差异需要定位。弱投影数字仍是解析坐标证据，不能声称完整GPU轮廓逐像素通过。展示外壳现默认启用已存在的传统角色构图，底层工程场景仍默认普通透视，可用开关对照。`world3d-formal-content-frame-matched.png` 已实机渲染并检查，亮度和场景差异仍明显，未通过最终视觉验收。

独立站位复核更正：正式基准的7张卡牌与原生队伍逐项比较，x/depth/height/clearance最大误差小于4e-9路程单位。之前“实际站位不同”的目测判断不成立，不能据此调整布阵。`capture_formal_battle_baseline.gd` 已额外采集主角及队员的实际画像矩形与六个骨骼屏幕位置；`test_world3d_content_frame.gd` 输出 `world3d-independent-landmarks.json`。该误差包含两套实际运行姿态、地形和投影差异，尚不能单独归因于摄像机；下一步需要分离这些因素，而不是再次修改已一致的站位。

用户再次明确指出 3D 复刻角色占画幅过大。暂停继续蒙皮绑定表压缩，先解决独立正式版画面基准与构图验收。不能用基于 3D 站位反建的旧渲染画面代替正式版实机证据。

`capture_world3d_party_comparison.gd` 目前共享原生版站位、姿态和镜头，仅能用于投影诊断；骨骼投影误差接近零不能证明正式版战斗复原。当前传统角色构图开关仍默认关闭，实验截图也不能代表默认入口效果。

下一步须独立采集正式版战斗的实际内容视口、队伍、有效镜头与站位数据；保持同画幅、同队伍、同动画采样点。分别比较模型可见轮廓高度占比、头脚位置、队伍左右极值、道具占比、地面可见范围及敌人远中近缩放。之后才能决定修正单位尺度、镜头距离/投影或局部角色投影，禁止靠任意整体缩小掩盖镜头问题。进入战斗、稳定战斗和离场均须检查，最终仍需用户确认视觉效果。

已新增并运行 `tests/capture_formal_battle_baseline.gd`，独立加载正式 `defense_route.tscn`，不导入 world3d 站位。输出 `tempassets/work/formal-battle-baseline.png/json`。当前采集为正式防线准备状态，7 张实际卡牌，尚不包含战斗动态敌人。实际 arena 逻辑尺寸 1552×830，窗口截图 1440×900；上下操作栏占用画面，与 world3d 全窗口渲染不同。实机角色槽：silent-medium x=-21.0518/depth=34.5093/height=38；investigator x=-9.20733/depth=31.8706/height=38。必须用该独立数据和真实内容视口继续验证，不能沿用原生站位生成参考图。图片已人工检查，当前尚未据此修改镜头，仍未通过构图验收。

1. 现有传统版、已保存镜头和站位模板作为对照保留；不覆盖网页 demo。
2. 原森林及其他主题的撒布坐标、资产比例、锚点、地被、树根遮盖和通道层次优先导入，不重新随机一遍充当复刻。
3. 镜头默认移动机位与角色解耦，主角最终回到画幅左侧腰部构图。战斗镜头由战场中心与站位提前规划，缓停期间主角继续向有纵深的战位移动。
4. 交谈期间镜头已到预定事件机位，最终选择战斗才进入战位。重开/复活不重播镜头进场；单位原地恢复，需要时再复位。
5. 胜利离场主角向前并回到移动默认位，其他队员和道具原地渐隐；不能全队朝镜头飘。
6. 移动模式决定事件距离，禁止为了赶时间加速滑步；首个事件约 3 秒，其后通常 3–5 秒，特殊布局约 6–7 秒。事件预部署，选择岔路后在分支远端准备事件，不在每个岔口突然刷一排怪。
7. 真实世界坐标、镜头投影与屏幕 UI 分层。容许经过验证的偏轴投影和局部美术修正，不为追求标准透视破坏用户已认可画面。
8. 不把工程压力样本、图片存在、几何正确或某一帧 60 FPS 当作产品验收完成。

## 架构与当前实现

构图校准更新：`启动3D迁移验证.cmd` 现进入 `world3d_presentation.tscn`，按正式版 `_layout_ui` 相同规则显示独立 3D 战场：UI 比例 clamp(min(w/1600,h/960),.65,3)，逻辑边距左/右24、上88、下82。底层 `world3d_stage.tscn` 保留供投影与性能诊断。换主题保持展示外壳。`test_world3d_content_frame.gd` 已验证 1440×900 的内容矩形与独立正式版采集误差小于1像素，并检查1920×1080、1280×960窗口调整后的尺寸与渲染同步。实机截图 `world3d-formal-content-frame.png` 已检查。此修改只消除了整窗与内容区域不一致造成的放大，姿态、局部投影、亮度、撒布和动态敌人尚未通过独立构图验收。

独立入口：`启动3D迁移验证.cmd` / `godot/scenes/world3d_stage.tscn`。此入口是工程验证，不替换原主页与正式旅途入口。

- `godot/scripts/world3d/projection.gd`：20 原布局单位 = 1 米；Godot Camera3D 偏轴视锥。原 horizon 对应 lens shift，而非机械地俯仰摄像机。
- `scenery.gd`：读取 SegmentWorld 原撒布，按纹理与空间块组装 MultiMeshInstance3D，使用实际世界深度；复用原地面着色逻辑和原地形高度，消除每像素反求地面交点的旧路径。
- `cutout.gdshader`：竖直相机朝向面片，真实顶点投影与深度；`ground.gdshader`：原地面材质公式的 3D 网格版本；`mist.gdshader`：移植原世界锚定雾块。仍需实机视觉精修，不能宣称完全相同。
- `actor.gd`：单 World3D 中的独立骨骼模型，复用已验证的快速重定向与步幅估计，包含已有爬行动作替代、坠落/落地/起身动作映射。
- `spatial_index.gd`：空间格宽阶段查询，支持圆形、最近若干目标、线段扫掠/胶囊形区域；当前以 XZ 为作用平面，技能高度过滤待设计。
- `stage.gd`：3 模型 + 5 道具占位，50 敌人预热池、基础行进/事件/岔路/进入战斗验证，复用 DefenseSim；有圆形与贯穿伤害测试按钮。正式队伍存档、装备和完整事件对话尚未迁移。

当前入口大量复用了原世界数据，但场景范围仍为有限的 connected 测试地图；长期 PCG 流式拼接并未完成。

## 已运行的检查

- `test_world3d_foundation.gd`：三个画幅 × 三类镜头 × 三个朝向 × 多深度/高度；Camera3D 与原投影锚点最大误差约 0.00041 像素。
- 同测试：500 个单位、100 组圆形/扫掠形状，与暴力扫描命中列表一致。测试包含单位半径和空间格跨边界。
- `test_world3d_flow.gd`：首个事件约 3.25 秒、无大单帧位置跳变、重开镜头原位、左岔路发生真实世界转向。仍不是所有过程镜头的审美验收。
- `capture_world3d_stage.gd`：原 7105 条撒布（含根部遮盖共 14775 面片）、50 预热敌人，约 40 已激活时采样 57–59 FPS。没有完整 Epic 技能特效，也没有未来技能数量的压力负载，不能用于承诺正式版性能。
- 截图/日志：`tempassets/work/world3d-prepare.png`、`world3d-battle.png`、`world3d-foundation.log`、`world3d-flow.log`、`world3d-stage.log`。临时目录不代表已提交 Git。

## 必须继续完成的阶段

| 阶段 | 状态 | 必须交付的结果 |
|---|---|---|
| 原投影与单位空间基础 | 基础测试通过 | 继续覆盖完整模板 forward/lateral/yaw、镜头动画、角色轮廓与 8 个占位 |
| 原撒布的 3D 导入 | 森林初版 | 修正透视下的贴地/树根/透明边缘，恢复完整雾和灯光；其余 6 基准及 18 子景按真实平面方向导入 |
| 正式角色与队伍 | 未完成 | 读取原阵容/主角选择/装备，武器驱动动作、连招、手持绑点、血量转化、尸体与复活 |
| 正式旅途与事件 | 验证流程已通 | 接回原事件内容、对话/选择、预部署/怪物接近，按移动速度规划距离 |
| 岔路与 PCG/流式场景 | 单岔路验证 | 反复岔路、主题接缝、持续推进、种子复现、在预算内加载/回收区块 |
| 关键及过程镜头 | 静态投影已验证 | 原移动、事件、战斗同机位截图；全进出/复活过程轨迹及速度连续性 |
| 战斗与空间技能 | 查询和样本已通 | 正式索敌、射程、命中时序、分裂/多弹道、爆炸、持续区域、贯穿、单目标去重 |
| 原 VFX 与场景灯光 | 未完成 | Epic 实际资产接回单世界，虚拟/真实灯光预算、爆炸灯消散与编辑器保存数据 |
| 性能与 LOD | 初步分块/池化 | 50 常态/100 压力、技能密集时 p50/p95 CPU/GPU；动画 LOD、资源共享、空间索引增量维护 |
| 全流程发布验收 | 未开始 | 用户认可的几乎同构图画面与流畅流程；旧版可回退，才能切换正式入口 |

## 性能规则

- 为 60 FPS 以 16.67 ms/帧为总预算，使用同硬件/同分辨率/相同种子/相同已激活数量对照。分别报告 CPU/GPU 与高分位，不能用 FPS 瞬时值掩盖卡顿。
- 环境物件按纹理与空间块批处理，摄像机远处块裁剪；避免每帧对全部撒布排序和搬运实例。
- 不给每棵树/每枚子弹建碰撞刚体，不给每个角色建独立视口。动作、材质、模型尽量共享，近远差异由动画更新频率与几何 LOD 决定。
- 敌人行为与表现分频；索敌低频缓存，技能命中与弹道扫掠按必要精度执行；AOE 先筛空间格，再做窄阶段与去重。
- 出生、子弹、区域效果和伤害显示使用容量有上限的池；过载时有可说明的表现降级，不能静默漏掉伤害逻辑。

## 当前最优先续做

1. 雾块竖条问题已在新截图中确认修正。补齐角色环境色和原照明，不以强白灯掩盖问题。
2. 使用原版固定种子、相同起点与画幅导出对照，记录树干/地被/脚点/角色头顶锚点，区分数学投影一致与完整视觉一致。
3. 接回原队伍与事件会话模型，替换 stage 中的演示队伍和演示状态，保持独立入口。
4. 接入真正的原特效与空间技能压力回放，然后以分项测量决定 LOD/池容量和下一轮优化。

目标保持 active，以上未完成事项不应因交付一个可运行入口就被标记完成。

### 同世界场景对照（本轮末尾）

`capture_world3d_comparison.gd` 使用同一个 SegmentWorld 实例、相同机位参数、画幅和冻结时间，隐藏角色后分别导出 `world3d-scenery-native.png` 与 `world3d-scenery-reference.png`。参考使用原 ForestBatch 与地面着色器，不重新生成撒布。已观察到树干轮廓、地被群落位置和道路走势保持对应；透明边缘、草叶亮度及近景渐隐仍存在差异，未宣称像素级相同。最初一次比较在 3D 相机首帧设置之前冻结，且触发旧通用渲染器缺少 silhouette 的错误，该无效结果已由修正后的无报错截图覆盖。

恢复雾和盟友动作后的最新 40 怪采样为约 48 FPS（单次瞬时值）；早期 57–59 FPS 数据不是同样的完整表现负载。下一轮必须做时长足够的分项测量，再优化透明层和分块可见性，不能引用早期数字承诺性能。


### 镜头参数与分块检查更新

- 已接入原编辑器定义的 forward / lateral / yaw；横向、前向偏移使用路线方向，yaw 单独改变镜头朝向。相机、撒布、雾和灯光桥接使用同一有效机位。三种过程镜头均插值全部参数，旋转跨 ±180° 走短弧。
- 三画幅、已有三模板及含非零偏移/旋转的额外模板，对原投影公式最大误差 0.000737 像素。流程回归首事件 3.042 秒，单帧最大位移 0.0512 米，重开镜头不动、岔路实际转向通过。
- 修正面片包围盒：按宽度的旋转半径与实际上下锚点包围，包含翻转和超出图片范围的根部遮盖锚点；增加保守水平视锥与远近距离裁剪。独立角点采样检查未发现误裁剪。
- RTX 3060，1440×900，关闭垂直同步，预热后 8 秒：之前平均 19.209 ms / p95 24.449 ms / 绘制调用中位 1255；之后平均 19.206 ms / p95 24.071 ms / 绘制调用中位 1229。活动分块 396 → 345。没有明显平均帧耗时改善；且此次同时修正镜头偏移，活动模型中位数 38 / 39，不能把小差异归因于单一优化。
- 重新生成并检查同世界对照：森林构图对应，未看到明显裁剪缺块；草叶亮度、透明边缘与近景渐隐差异仍在。正式队伍、事件、VFX、持续主题地图仍未完成。
- 下一步应做透明绘制/动画分项测量及正式阵容接入；禁止将本轮结果报告成已达到 60 FPS 或完成整体迁移。


### 正式阵容读取与武器接入

- 新增 world3d/party.gd，只读 journey-v1.json 中的 formation，用原 BattleModel 重建卡牌与数值；不初始化 Journey.state，不修改主存档。主角沿用 world-hero.cfg，装备沿用 character-loadouts.cfg。缺少存档时采用 BattleModel 默认队伍。
- 角色使用实际卡牌 model_file；道具使用原卡面。主角在表现数组中优先，不改变阵容原槽位。8 卡精确使用原八槽，其他数量按槽位曲线插值，左右极值保留。模型大小现在以槽位 height 的世界高度匹配，替代固定 38/52 缩放。
- allied_actor.gd 在同一个 World3D 内使用原 palm_mount、斧盾旋转修正、双手占用规则、武器职业动作与连招列表；没有重新引入每角色独立视口。
- test_world3d_party.gd 通过：两种角色身份不同、角色/道具分类、2/8/10 卡站位极值、武器连招循环、死亡后仍显示与复活重置。流程回归首事件 2.97 秒，原位重开与岔路转向通过。实机整备/战斗截图已生成并检查，角色与道具显示符合当前存档；角色材质边缘及整体画面复刻仍需继续。
- 尚未完成：新入口中的整备编辑 UI / 跨进程重新读取装备，近战前进攻击退回，攻击命中时刻与动画时长绑定，正式原卡牌技能/ held 道具完整规则，血量转化、复活位置完整状态机。已读取数值不等于正式战斗规则已全部迁移。
- 最新截图约 40 敌人瞬时 52 FPS，仅供功能截图，不与之前性能基准比较（阵容、角色体积与装备负载已变）。


### 近战位移与出手时序

- 独立 world3d/combat_sim.gd 继承防线逻辑，仅新入口使用；原防线不受影响。我方近战前进/退回写入模拟位置，最大前进 1.2 米且在目标前停留；进出速度使用平滑曲线，动画周期随攻击周期匹配。远程不附加前进。
- 我方伤害增加可取消的出手等待，当前统一在周期 42% 时判定近战射程并结算一次；远程在此时发射，仍沿用简化飞行时间队列。死亡取消未出手攻击，冻结当前位置。每次开始战斗清理表现攻击时间戳，避免重开的第一击被旧时间戳吞掉。
- test_world3d_melee.gd 通过：出手前无伤害、单次命中、距离上限、回位、死亡停止位移、死亡取消攻击。完整入口运行无报错并导出战斗截图；旅途流程回归通过，首事件 2.975 秒。
- 仍需完成每条原动作的真实命中标记（统一 42% 只是过渡规则），近战原特效、远程空间弹道碰撞、复活后复位、技能区域判定与完整正式战斗效果。此次不是全部战斗系统已完成。


### 空间弹道与原 StormMissile

- 新增 projectiles.gd：固定步长更新位置，空间格筛选后执行三维相对运动扫掠球求交，按最早接触排序；支持贯穿次数、跨帧目标去重与飞行寿命。双方远程接入此路径，取代锁定目标的定时扣血；近战保留上轮的独立出手规则。当前沿初始方向直飞，不自动追踪。
- test_world3d_projectiles.gd 通过：200 单位/秒高速扫掠，目标 ID 与距离反序，贯穿跨帧去重，怪物横穿弹道，以及高度错开的目标拒绝命中。近战回归继续通过。
- projectile_view.gd 将原 Epic181 StormMissile 和对应 impact 粒子直接放入同一 World3D/Camera3D。各24个表现实例预热复用；表现池满时计入 dropped_visuals，伤害模拟不受表现容量影响。暂未加入原 muzzle、灯光配置、发射握点、朝向完整匹配和其他原特效。模拟弹道目前仍用动态数组，尚未完成容量预算与高负载优化。
- 实机截图已检查，约40模型时瞬时42 FPS；这是含粒子后的功能截图，不是正式性能对照。需要继续做粒子更新与透明绘制分项测量。原特效大小和照明仍需对照修正。


### 原子弹灯光参数与战后清理

- 新增 projectile_lights.gd，读取 user://projectile-light-profiles.json 对应 StormMissile 文件键的设置，与原预览器默认参数一致。飞行、爆炸开关分别生效；爆炸点保留世界坐标，在子弹结束后继续达峰与消散。场景着色器使用四个槽，优先爆炸，总能量不超过配置的单灯最大强度，避免同时发射导致无限增亮。
- 已加入原 muzzle 资产。此轮灯光作用于地面/撒布着色器，角色材质仍未接入对应点光；尚不能称为完整场景照明迁移。原子弹开关、舞台灯和角色补光设置 UI 仍需补齐。
- 胜利/失败时清理正在飞行的模拟弹道和等待出手，已触发的爆炸光与粒子独立衰减；重开立即清理旧特效。流程回归新增了胜利后弹道清空、爆炸尾光保留的断言。
- test_world3d_lights.gd 验证坐标映射、达峰与衰减、结束清理、四槽/总能量预算和两个禁用开关。实机运行日志无报错，约40模型的功能截图瞬时43 FPS，不属于性能验收。下一步仍应进行粒子/角色/场景分项剖析，再扩展正式流程和主题地图。


### 分项 CPU 计时与固定镜头裁剪缓存

- stage 增加按需开启的 simulation / crowd / particles / scenery 计时；benchmark_world3d 现在明确标注 storm_particles=true，记录表现实例池耗尽次数。旧 baseline 文件保留，新测量输出 profile / profile-optimized。
- 固定机位时缓存分块可见性；相机位置、朝向、镜头焦距、画幅或重新 populate 时失效，不改变实际剪裁条件。test_world3d_flow 新增固定镜头不重算、移动镜头立即重算检查，完整流程通过。
- 同 RTX3060 1440×900 无垂直同步、8秒采样：before 平均22.063ms/p95 28.401ms；after平均24.105ms/p95 34.144ms。场景CPU 4.245→2.325ms，但 crowd 2.988→3.548、particles 2.412→2.880、simulation .570→.746ms。两个样本中位38模型、约1190绘制调用、0特效池丢失。局部重复工作已减少，总帧时间没有改善，且其他分项同时变慢；不可据此宣称整体加速。
- 后续要稳定回放状态并重复对照，再分析动画与粒子开销；此轮仅确定场景重复裁剪确实占CPU，不是完整性能验收。


### 粒子坐标变换缓存

- Epic181 原粒子更新每个粒子重复求发射器逆矩阵、相机朝向和水平面朝向，改为每次 advance 预先计算。粒子模拟、随机数、生成数与材质保持原样；此为共享原特效执行器的等价优化。
- tests/fixtures/epic_advance_reference.gd 固定保留改前更新方法作对照。test_epic_transform_cache.gd 对 StormMissile / muzzle / impact，变化发射器位置、旋转、非均匀缩放与镜头方向，120帧，合计5383个样本逐项比较数量、实例变换、颜色与纹理帧。
- 实际 OpenGL 后端运行通过，最大几何差异0；交替更新顺序的隔离 CPU 用时 reference 74964μs / cached 71789μs，约4.2%减少。headless也通过，但以实际渲染后端数值检查作为变换证据。没有宣称整场提速4.2%，没有达到完整性能验收。
- 需避免只做局部微优化而耽误目标主体：下一轮优先接正式事件状态与持续路线，随后继续完整回放负载测量、LOD及技能预算。原有全部验收门槛仍有效。


### 原事件目录与对话链路

- encounters.gd 使用 local_encounters 原目录：线性战斗序列、左路档案员/战斗、右路战斗；行商选择沿用4秘银费用与原线索奖励规则。抵达才允许互动，未解决事件不能直接继续，胜利或社交选择只能结算一次。当前是独立测试会话行囊，不写正式 Journey 存档；地图区域 tier/reward 尚用默认测试参数，不能称为全部长线接通。
- encounter_panel.gd 在事件、岔路、胜利、失败显示对应原中文对话及选项，深色底和金色边框。准备/行进/战斗时隐藏，分支需要手动选择。未加入此前被用户否定的感悟类事件。
- test_world3d_encounters 检查抵达门槛、不可跳过、奖励去重、分支内容和商人费用；test_world3d_flow 回归通过，首事件2.972秒。world3d-event-panel.png 已检查，按钮和文本完整可见。截图同时反映移动/事件角色占比仍需进一步复刻，不代表镜头已验收。
- 未完成：社交NPC可视形象、事件预览与真正战斗队伍身份统一、所有场景主题/区域上下文、正式存档结算、重复岔路和无限分块流式地图。当前目录序列循环仅为独立流程，不等于已实现无尽地图；下一轮应优先解决连续路线空间和场景回收。


### 现有支路尾部扩展与地形回收

- 查明 connected.tres 仅有左右支路，UI此前始终展示直路会进入无区域覆盖的位置。新入口与对话现在按 plan.exits 显示，choose_branch 拒绝不存在的直路。
- 新增 extend_route_if_needed：距离支路尾端1600路线单位时，调用该主题原布局策略生成后续1800单位物件，使用确定的区块键和原 seed；扩展既有主题区间，避免着色器区域数组无限增长。
- scenery 分离 append_sprites 与地面初始化，复用纹理材质；退掉当前距离后500单位之外的旧面片组并过滤 world.sprites。地面网格随镜头保持覆盖，但颜色/高度继续以世界坐标计算。
- test_world3d_stream 在左右支路各扩8次，检查新逻辑覆盖与后续真实物件，累计16次，峰值1096块、着色器仍5区域，通过。headless 单次同步生成9.5–19.5ms，仍有潜在卡顿，尚未做帧预算队列或工作线程；不能宣称已实现无卡顿流式地图。
- 当前仅扩展末端 cave/cloud 原策略；重复岔路、森林/其他主题分块生成、主题组合、跨块接缝画面与玩家长期行进实机验证仍待完成。不是完整 PCG 迁移。下一轮优先拆分上传预算与重复岔路拓扑。


### 分帧物件分组与实例上传

- scenery 新增 queue_sprites/process_uploads，按默认1500μs软预算逐个处理物件分组与渲染组创建；初次载入仍用同步 append_sprites。预算允许单个组完成后小幅超时，不是硬实时保证。stage 每帧推进队列，新增几何时失效裁剪缓存。
- 排队期间已落后于回收线的组直接丢弃，避免旧地形延迟上传后重新出现；测试比较同步与排队输出的1500实例，包围盒、变换、颜色、自定义锚点完全一致。实际OpenGL运行通过，100μs测试预算下约119批，单批峰值386μs。
- 连续16次支路扩展继续通过；同步阶段从此前约10–20ms降为约4–8ms，布局策略本身与回收过滤仍同步，未消除全部潜在卡顿。实际运行中的GPU上传尖峰、长期资源占用仍需继续测量。
- 最初快速退出测试出现纹理资源退出警告；显式释放测试节点并等待帧后，verbose复跑无ERROR/WARNING。仍应在持续运行测试中核对资源趋势，不能仅凭退出日志称内存验收完成。
- 路线流程回归通过，约2.971秒首事件。重复岔路与其他主题完整接入仍未完成。


### 独立路段坐标与下一岔路规划

- 新增 route_segment.gd，按每段保存起始距离、世界原点、朝向、岔路位置、转弯长度、出口数、种子与主题。姿态计算复原原 ForestRoute 的圆弧/切线，但不修改全局状态，使前后段能共存。stage 的角色、战斗锚点和镜头路线采样已改用此段实例；当前首段画面与路线行为保持同构。
- 选定真实出口时规划 planned_successor，连接在上一段末端的实际世界位置与切线，种子决定后续2/3岔路和间距；不会重置角色或摄像机。此轮仅规划，未激活 successor，也未上传其地形，因此不能称为重复岔路已实现。
- test_world3d_route_segments：原路线多深度对照，100次左右/直行接续，位置/切线连续、同种子复现、历史段不受后续规划影响。长距离三维换算后跨边界微步误差最大0.0009375米；最初过严路线单位阈值触发了浮点误差，现以3毫米世界精度上限检查，实际低于1毫米。旅途流程回归通过，首事件2.969秒。
- 下一步必须将 successor 的布局预热、保留旧段可见几何、地面路网多段采样和真实状态交接接通，不能只保留计划变量或数学测试就认定目标完成。


### 多路段地面道路计算准备

- ground.gdshader 新增最多3个独立段的原点/朝向/起止/圆弧/出口数据，按有限长直线与圆弧计算最近道路距离；不把旧支路视为向无穷远延伸。scenery.bind_route_segments 提供上传入口。默认 segment_count=0，继续原单段画面，尚未在正式行进中启用多段，以免与未预加载的物件错位。
- route_segment.lane_distance 提供同一几何定义的CPU查询。对转向/偏移后的三岔路，40个散点与各支路每单位一步、共2500步的密集路径折线对照，误差<0.01路线单位；100次连接测试仍通过。实际OpenGL运行编译更新后的地面shader无报错。
- 此轮是前后段地面并存的依赖，不能说重复岔路已可玩。仍须接入 successor 地形预加载、真实handoff、区域颜色采样和对照截图；不能继续仅增加未启用的数学组件来替代这一主流程。


### 下一段预加载与真实交接接通

- successor_world.gd 按当前出口末端主题与下一段独立坐标生成原布局；生成期间临时设置旧适配器依赖的 ForestRoute 参数后立即恢复。新物件进入分帧上传队列，旧段连接点之后的实例按 route_s 精确裁去，保留同组近景实例。此阶段布局生成仍同步，尚有输入时尖峰风险。
- stage 在实际行进跨越连接点且上传完成时使用新路段/区域，保留累计距离、角色位置、镜头位置与运动状态，branch重置为新段未选择主干。前后两段地面同时启用，随后可遇到新2/3岔路。修正到达岔路端点时主干区域排他边界导致的空region错误。
- 修正更新区域时纹理槽索引应沿用既有floor_types，不能因为下一段仅有cave就把它错误指向forest贴图槽。当前后续延续选中支路主题，不是完整主题PCG组合。
- test_world3d_handoffs 实际建立并上传六个successor，进入第七路段，检查物件非空、交接不改角色/相机、区域覆盖、左右出口和有限区域数量；峰值2666块。OpenGL复跑和新岔路截图完成，无脚本错误。测试快速定位连接点，不等于完整漫长手动游玩或所有过程镜头已验收。
- world3d-repeated-fork.png 暴露洞穴视觉不合格：部分物件竖卡阻路/尺度或平面方向不当、紫色边缘残留。必须修复资产表达和通道观感，不得以流程测试通过替代视觉验收。下一轮优先处理这一实机缺陷，并继续降低同步布局预生成成本。


### 移除旧测试洞穴/云海，恢复当前场景与平面朝向

- 查明入口使用旧 connected.tres 的 cave/cloudsea，并非用户当前六套森林/水晶矿洞/菌菇沼泽/下水道/巨鲸/宫殿。入口仅在内存复制计划后将旧洞穴替换为现有crystal、旧cloudsea替换为swamp，原资源文件未修改。最新初始6797条撒布、含根部14467面片。
- cutout 使用原 sprite.plane_heading 决定固定空间朝向，普通植物仍朝向镜头；恢复squash参数，所有平面锚点继续参与包围盒。原先紫边来自旧洞穴资产，当前矿洞截图不再使用这些图，未对源图做不可追溯修改。
- successor_world 改为先在局部北向坐标调用旧布局策略，再统一变换物件/灯光/plane_heading到新路段。避免原岩壁分组代码用全局x排序导致转弯后的构图错误。
- 六次交接OpenGL复跑通过，矿洞新截图已检查：旧挡路碎石卡片/紫边消失，通道可见；洞顶和远景仍有露天/重复拱门感，尚不符合完整原版封闭场景。角色占比、材质边缘也未验收。右路swamp最终键名修正后流程回归通过，首事件2.985秒；右路视觉尚需单独检查。
- 此轮顺带接入按当前环境平滑调整背景色，但静态快速截图dt=0不体现渐变完成，不应根据该截图声称背景问题已解决。下一步需要同一机位对照封闭环境与实际照明。


### 矿洞同机位对照与原接地处理

- capture_world3d_comparison 新增 --crystal，将同一个世界定位到左路3000，冻结同机位/时间。当前计划全部属于原ForestBatch支持的主题，因此参考直接启用原SegmentRenderer，而非隐藏renderer再手工补batch；恢复真正的原远景/背景参考。
- 对照发现主要硬切来源是缺失原 rock_contact 与grounded footprint：原版将锚点以下图像铺向地面，并按横向采样的接地线改变岩壁底边。cutout着色器与细分网格恢复这一处理，同时按实际地面高度抬升各横向点，扩大相应包围盒防误裁剪。
- 修改后 world3d-scenery-native.png 与 reference 对照已检查：原右侧水平截断消失，左右岩壁脚部与地面贴合，封闭通道布局接近原参考。仍有亮度、雾层/透明边缘与远景差异，不能称像素一致或全部机位验收。
- 细分面片只用于需接地变形的矿洞资产；普通森林仍为四边形。同纹理/网格种类共享mesh、接地采样按纹理缓存，避免每块重复读取图像和新建细分资源。流程回归通过，首事件2.973秒。
- 下一步继续其余主题同机位对照、环境层与角色机位比例；矿洞本轮单帧截图中的FPS来自短暂初始化，不能作为新性能基准。

## Six-theme entry and environment parity follow-up

The independent 3D entry now offers forest, crystal, swamp, sewer, whale and palace, plus the connected forest route. Selection restarts only the prototype scene. The picker overrides launch arguments and a weak-reference test confirms the previous scene is released.

Successor generation now builds the original forest source instead of creating an empty forest. Local biome lights rotate their X/Z coordinates, preserving height and radius. `test_world3d_themes.gd` passes all six themes including transformed scenery, light placement and restored global route context. `test_world3d_theme_switch.gd -- --theme=swamp` passes. First-event flow regression remains 2.974 seconds.

Actual OpenGL swamp and sewer same-camera comparisons revealed missing original emissive highlights, fireflies and drips. These are now restored in world-space batches, using original formulas and source placements. Captures: `tempassets/work/world3d-{swamp,sewer}-{native,reference}.png`. Visible transparency-edge, brightness and floor differences remain. This does not establish full visual parity or sustained 60 FPS.

GPU queued-upload regression matched all 1500 instances, but exit again reported texture/resource leaks despite explicit cleanup. Treat memory lifetime as unresolved; the assertion pass is not a clean shutdown pass. Keep the long-term goal active.

## Lighting update cost and resource-lifetime audit

Shared renderer lighting bind APIs now delegate to parameter snapshots. The independent 3D scenery computes one snapshot per frame and updates only currently visible cutout materials plus ground/fog. Visibility changes and streaming invalidate the material set. The traditional bind entry points remain compatible. Frozen pre-change reference comparison passed 264 parameter values across seven theme configurations; GPU visibility/re-entry test passed 560 values, skipping up to 18 irrelevant materials. First-event flow regression passed at 2.973 seconds.

Current OpenGL 1440x900 battle sample: mean 19.223 ms, p95 27.73 ms, scenery CPU 0.593 ms, crowd 3.237 ms, particles 2.649 ms, simulation 0.542 ms; median 38 model bindings, 1159 draws. Storm particles enabled, full VFX not enabled. Asset/chunk counts differ from older reports, so this is not a controlled whole-frame A/B result. Stable 60 FPS remains unmet. Source: `tempassets/work/world3d-benchmark-lighting-snapshot.json`.

The upload fixture's optional `--release-shared-cache` removes GL texture leak warnings, isolating those retained textures to shared caches; script-resource shutdown warnings remain. A separate 21-world/three-cycle headless audit confirms every world weak reference expires and cache counts plateau at [10,0,3,13]. This does not prove full actor/GPU lifetime correctness. No production cache eviction was added merely to suppress shutdown diagnostics.

## Bone evaluation pruning without animation decimation

The shared defense retargeter now evaluates only mapped bones plus their ancestor closure. All rig bones remain present; unmapped accessory chains still inherit parent motion. No animation frames, death/getup states, or close-up updates were skipped. Example evaluated/total bones: Isabella 71/517, composer 83/261, Joseph 103/355, geisha 93/258, George 103/404.

`test_world3d_bone_pruning.gd` compares a frozen original retargeter against the optimization across all five actual enemy models and original motions plus fall/landing/getup/crawl. 256685 global-pose checks passed, including fractional sample times and endpoints. Isolated apply timing was 470133 vs 288835 microseconds. Party/equipment/corpse/revive regression passed.

Sequential same-configuration OpenGL battle runs, 1440x900, 8-second sampling, median 38 active model bindings: all-bones mean 16.545 ms / p95 23.214 ms / crowd CPU 2.927 ms; pruned mean 15.699 ms / p95 21.610 ms / crowd CPU 2.278 ms. Current benchmarks support a useful reduction but do not establish stable 60 FPS. Frame pacing, full VFX, heavier skills, 100-unit stress and visual/migration requirements remain unfinished. Evidence: `tempassets/work/world3d-benchmark-{all-bones,bone-pruning}.json`.

## Fixed-step spatial area skills

Explosion and forward-area buttons now dispatch damage directly to IDs returned by the spatial query, eliminating the subsequent full-enemy scan. A world-metre area system rebuilds one enemy index per fixed battle step, excludes inactive/dead/resolved units, checks vertical reach, and supports periodic circular zones. The new test button creates a 4-second radius-2.8-metre zone, ticking every 0.5 seconds. Up to 64 concurrent zones share the index. Restart and terminal states clear zones. Range markers use one MultiMesh and conform to ground height.

Tests pass for airborne exclusion, delayed activation, moving into/out of a zone, exact final tick, rotated/translated battlefield, local queries against 1000 logical units, and real-stage fixed-step damage plus GPU marker/restart cleanup. Flow and projectile regressions pass. Capture: `tempassets/work/world3d-area-test.png`. Query tests do not establish 1000-model performance. Current capsule is a horizontal area with a fixed vertical band; arbitrary sloped beams, full card/skill rules and finished effect art remain outstanding.

## User priority: formal battle occupancy and angle

The user explicitly rejected the oversized native party composition and reiterated that formal battle occupancy/angle is a strict acceptance criterion. Investigation found a concrete conversion error: native party scale was slot.height/36 while formal SceneFormation displays the entire 2.6-metre portrait viewport, so the equivalent native scale is slot.height/(20*2.6). Previous linear scale was 44.44% too large. This has been corrected without changing camera or foot positions. `test_world3d_character_frame.gd` uses the actual original enemy_actor Camera3D to verify the conversion for three heights; measured normalized projection is 0.3846154213 per metre.

This fixes a scale conversion, not full composition parity. Next priority is identical-party formal/native image overlay, measured head/foot/width occupancy, facing angle and perspective residuals, followed by movement/event/battle transition verification. Do not substitute numeric camera parity for visual acceptance.

Material comparison also isolated severe dark folds to missing actor lighting rather than broken geometry; disabling outline did not remove them, original materials were intact. Original saved team key/rim/ambient values are now applied with actor-only light masks in native stage. No model edits; experimental backface shader was removed. Actual captures were inspected, but dedicated lighting and performance tests remain. `tempassets/work/world3d-material-before.png` preserves the old image; current/no-outline/original diagnostic images are available.

## Same-lineup original-renderer composition fixture

`capture_world3d_party_comparison.gd` now produces native, original-renderer and landmark-overlay images using the same lineup, saved slot parameters and camera frame. It instantiates real original portrait actors, copies rig poses, and uses the production ForestBatch renderer. This is a component-level reference, not yet a full formal expedition replay. Overlay yellow points represent original projection, cyan native.

Restored missing stationary inward facing (0.22 rad) and fixed one-unit slot interpolation to use the formal central slot. Also corrected native watch art to formal watch-front, discovered when the renderer's existing atlas rejected watch.png. Party regression passes.

Current comparison does NOT pass visual parity. Head/neck positions are within roughly 1-12 pixels, but hands/ankles still differ roughly 53-103 pixels in the 1440x900 frame. Closest limbs show substantial perspective differences; further audit of reference pose rendering and model-local camera projection is required before concluding all residuals are perspective. Do not hide the remaining mismatch by reporting the earlier scale fix as completion. Next goal turn must continue composition/projection work as user priority.

## Projection cause verified; weak-perspective diagnostic

Full original/native rig pose equality is now asserted in the comparison fixture, including pose scale. The remaining large limb offsets are perspective: actor anchors are only ~1.57/1.70 m from camera, with limb depth offsets ~0.14-0.24 m. Independent weak-perspective math on the native world bones matches the real original orthographic portrait-camera projection to <0.001 px. This is mathematical landmark evidence, not GPU raster-mask parity.

Added diagnostic character surface/outline and weapon shaders sharing `portrait_projection.gdshaderinc`. They blend clip XY toward actor-centred weak perspective while preserving real clip Z/W; scene, rig and simulation remain 3D. `capture_world3d_party_comparison.gd -- --weak-projection` renders this experiment. Body and weapon use the same anchor. Actual OpenGL compilation/captures inspected. The normal game entry is unchanged: experiment NOT enabled by default.

Files: `tempassets/work/world3d-party-weak-projection.png`, `world3d-party-weak-overlay.png`, `world3d-party-weak-landmarks.json`. Standard captures are stored separately. Remaining gates: occlusion correctness, moving anchor/weapon/projectile origin consistency, shader/lighting parity, performance and full phase flow. The weapon diagnostic preserves base color/texture, roughness and metallic only; full material semantics remain to be audited before adoption.

## Runtime composition trial and validation

Added an optional, default-off “传统角色构图（试验）” toggle to the migration stage. A per-actor presenter shares the moving world anchor across body, outline and weapon shaders, restores original shaders/materials when disabled, and rebuilds bindings after equipment refresh. It does not mutate world transforms. Conservative extra culling margins are restored when disabled; these still require wider-pose validation.

Actual OpenGL depth tests pass for front/back blockers at two anchor positions. Runtime tests pass for movement, weapon anchors, equipment refresh, toggle restoration and actual event arrival followed by battle. Fixed incomplete ally entry opacity: battle now finishes the remaining fade-in instead of leaving allies permanently partly transparent. Inspected `tempassets/work/world3d-portrait-runtime.png` after the fix. Its FPS text comes from a manually stepped capture and is not a performance measurement.

An 8-second 1440x900 benchmark with the projection option measured 18.553 ms mean, 25.318 ms p95, median 38 model bindings and 1167 draw calls. This does not establish stable 60 FPS or isolate projection cost against older builds. Weapon shader semantics remain limited to base color/texture, roughness and metallic; projectile hand origins, complex intersections, full formal replay and lighting parity remain unfinished. A reset invoked mid-travel can retain the previous encounter anchor; this separate debug-flow issue remains to be addressed. Goal remains active and visual parity is not accepted yet.

## Physical hand emission and projected effect alignment

Ranged simulation now supports a stage emission callback. Model sources use the right wrist pose translated to the current fixed-step source position, with terrain-aware inverse world conversion; nonmodel sources retain their previous fallback. Direction is recomputed from this origin to the target. Projectile records retain source ID and original position.

The presentation layer maps the physical origin through the same actor-centred projection as the surface shader while preserving camera depth. Muzzle and initial missile share that position; a smooth offset converges to the physical path over 0.8 m. Simulation positions, swept collision and impacts are unaffected by the projection option. Effect placement runs after camera configuration, removing a one-frame camera mismatch.

Actual OpenGL runtime assertions pass for hand/world roundtrip, off-axis projection equivalence, unchanged depth, pooled effect placement, convergence and unchanged simulation data. Projectile and melee regressions also pass. This is not full attack visual parity: staff-tip/left-hand sockets, exact fixed-step animation release, close immediate impacts and full formal replay remain outstanding. No claim of goal completion or improved frame rate.

## Restart and repeated-input transition corrections

The stale mid-travel reset issue is now guarded in both callable logic and the visible button. Reset is supported only at prepare/event/battle/victory/defeat. Repeated travel requests during travel/stopping/entering/fork no longer redeploy or move the next event target. Battle/terminal restart preserves camera heading and lens/frame; repeated preparation does not teleport units back. Revived model allies return from their current positions to formation at bounded run speed, and entry completes only after all arrive.

Actual OpenGL `test_world3d_restart_flow.gd` passes repeated-input invariants, in-place revival, exact camera transform/projection preservation and all-ally movement bounds. Existing flow regression passes: first event 2.985 seconds, maximum movement step 0.052625 m. This does not establish full phase image parity. Revival currently resets the pose; a dedicated stand-up animation is still absent. Goal remains active.

## Camera interpolation completion independent of actor arrival

Found another saved-frame mismatch: entering used exponential camera blending only until hero arrival, so short entry paths froze height/lens/horizon/offsets at intermediate values. Event stopping had the same residual-value problem. Event frames now interpolate from a captured source over the existing stopping transition. Battle frames interpolate independently for 0.6 seconds, continuing after actor entry completes; restart camera hold remains authoritative.

Actual OpenGL regression deliberately starts the hero already at its combat slot: phase immediately becomes battle while camera continues smoothly, reaches every saved field exactly, stays within bounded intermediate values, and remains unchanged on restart. Runtime test also asserts exact event/battle saved fields. Flow passes at 2.986 seconds to first event. Updated runtime image inspected; frame text is manually stepped capture data, not a performance measure. This is parameter/transition validation, not formal full-frame visual acceptance. Goal remains active.

## Formal travel destination correction

Native travel used depth 18 and lateral -10, whereas formal SceneFormation uses depth 32 and a reference-focal/aspect-derived lateral offset. Shared `traditional/travel_rig.gd` now preserves the formal expression and native uses the same tangent-space destination. Saved camera edits do not redefine the actor destination. First-leg planned distance compensates for the depth change without increasing speed.

Actual OpenGL travel-rig test passes three aspect ratios and curved routes against the frozen original formula. Flow passes at 2.968 seconds to first event. Formal editor regression is NOT clean: despite printing PASS, camera_editor.gd:166 reports index 7 out of range twice because preview player count is below eight. Next work should repair/reference-check this before treating formal replay as validated. Full visual composition parity remains incomplete.

## Reference editor eight-slot repair

Resolved the prior reference regression: its isolated expedition creates seven units while the calibration UI requires eight. Missing preview entries are now populated before scene snapshots and the arena rebuilt. Existing preview units are retained; player save is not involved. `test_traditional_camera_parity.gd` now passes without script errors. `test_slot_profiles_editor.gd` also passes all eight character/prop previews, independent edits, temporary save/load and runtime sampling for 1/3/8/10 units. This restores a usable reference gate; it does not prove native visual parity. Goal remains active.

## Travel capture exposes camera overtaking

Added --travel same-pose comparison. Initial 1.4-second capture showed invisible hero: camera depth 0.0668 m, head x about -5075 px. start_travel advanced route 31 units without physical hero movement. Removed that discontinuity; first leg now RUN*3 distance, unchanged speed. Actual capture now shows left-foreground hero. Flow passes 3.102 seconds and an every-frame camera-depth >0.5 m regression. This corrects visibility, not full formal visual parity; lighting/ground/fog and full replay remain open.

## Remove duplicated party scene lighting

Stage sun previously affected dedicated party layers on top of saved portrait key/rim lights. Its mask is now layer 1, preserving scenery/enemies and excluding party actors. Runtime mask assertions pass. Actual travel reference/native captures inspected: native remains brighter, so lighting parity is not accepted. Original forest_batch additionally applies region ambient, environment_surface, fog and lantern_atmosphere to the portrait; this transfer remains to be reproduced or calibrated. No arbitrary darkening factor was introduced.

## GPU atmosphere isolation

Added --reference-no-atmosphere diagnostic to the same-pose capture. Actual original rendering without lantern_atmosphere approaches native brightness; fixed hair/dress/sleeve ROI measurements are in tempassets/work/world3d-atmosphere-isolation.json. Hair RGB native 97.56/85.39/79.69 vs no-atmosphere reference 87.75/77.67/74.89 vs normal reference 37.43/33.78/32.02. This narrows the next implementation to combined-light atmosphere response rather than saved key/rim changes. The shared formula has nonlinear highlight compression, additive scatter and fog; multiplying albedo alone would not faithfully reproduce it. One pose/theme and three ROIs do not establish general parity. Runtime rendering unchanged this turn; diagnostic evidence advances the migration work.

## Actual post-light actor atmosphere trial

Implemented a default-off party-only atmosphere toggle. A transparent screen-reading next pass shades the already-lit opaque character with original lantern_atmosphere plus region/depth tint, preserving native projection/opacity. Saved key/rim values are unchanged. This is a shared scene screen copy, not per-character render textures. GPU opaque front/back tests pass at two anchors; runtime toggles restore material chains. Actual travel capture is substantially closer but too dark: dress RGB 48.87/30.42/43.94 vs formal 60.61/42.25/49.68 (previous native about 160/103/126).

8-second 38-model samples: enabled mean 22.321 ms, p95 32.271, draws 1193; disabled mean 22.954 ms, p95 31.920, draws 1170. Timing noise prevents reliable cost attribution; neither proves stable 60 FPS. Remaining: transparent fog/vegetation ordering, complex overlap, weapons/outlines/enemies, flat portrait vs true surface/color-space differences, biome surface treatment, uniform-update overhead and longer profiling. Trial remains off by default and goal remains active.

## Transparent foreground ordering regression

Actual GPU test reproduced post-light priority 100 erasing a half-transparent blue foreground: RGB 0/.149/0. Priority -100 now applies actor atmosphere before normal transparent passes. Foreground result is 0/.0745/.498, matching half-alpha compositing; transparent background does not bleed through opaque actor. Both moving anchors and existing opaque depth tests pass. Travel capture rerun. Special-priority effects, complex overlapping actors and full visual/performance acceptance remain pending.

## Atmosphere uniform change tracking

Added per-material value caches and a dedicated CPU profile scope. Actual runtime test passes: 456 initial writes, zero unchanged writes, 96 writes when time changes and a flash clears. Hidden/moved actors refresh on reentry; expired lights and toggle transitions leave no stale uniforms. Current 38-model benchmark mean19.616 ms/p95 29.006, atmosphere CPU .4213 ms,1193 draws. This is not controlled causal FPS evidence or stable60; geometry/pass cost and visual parity remain unfinished.

## Atmosphere sampling aligned to traditional portrait

Traditional projection now samples environment on the camera-facing anchor plane; normal perspective keeps surface XZ. Added terrain-relative clearance and signed height. Actual shader-bound lamp/fog/tint values match original in diagnostic. Dress ROI improved from48.87/30.42/43.94 to65.06/43.57/52.49 against original60.61/42.25/49.68. Opaque/transparent depth and parameter-cache/reentry tests pass. This is one pose/theme, not whole-game parity. Weapons/enemies and wider comparisons remain open; default remains off.

## Six-theme travel atmosphere review

Captured forest/whale/swamp/crystal/sewer/palace with theme-specific output names. Fixed reference fixture to apply actual formal ally scene_light_tint before rendering. Native captures inspected; dress ROIs differ about1-8 channel units from reference across themes, retaining clothing identity. Evidence in world3d-theme-atmosphere-rois.json. This is one pose per theme, not whole-game parity; scenery/ground/fog differences remain visible, and weapon/enemy/other-pose integration is unfinished.

## Weapon atmosphere lifecycle

Registered weapon atmosphere on both actor-owned normal and projected material chains. Original asset materials are duplicated before modification. Equipment refresh detaches old chains and registers replacement attachments; three refreshes across projection modes keep entry counts stable, anchors correct and toggles reversible. Actual runtime tests pass. Removed diagnostic weapon overriding from comparison fixture in favor of runtime presenter. Full weapon material semantics and visual reference including attachments remain outstanding; enemy integration/performance/overall parity remain open.

## Pooled enemy atmosphere and grouped updates

Trial includes preview and enemy pool. Naive per-material updates measured6.316 ms CPU and26.041 ms mean frame at38 model bindings. Grouped actor-level comparisons/clearance calculation reduced atmosphere CPU to1.640 ms; latest mean23.232/p95 32.254 ms,1556 draws. Frozen ungrouped benchmark saved separately. Runtime validates hidden pooled activation, stale flash clearing and equipment regrouping. Added passes remain expensive; stable60 and full enemy visual fidelity are not achieved. Default stays off.

## Subpixel outline LOD

Added projected-width outline reduction0.65->0.25px, then bypass invisible outline while retaining atmosphere. Near/far whole-group state cached after initial implementation. Runtime tests pass restoration, opacity-chain preservation, pooled reentry and disable. Draws1430 vs1557 full at38 models. Timing samples do NOT prove faster frames: initial LOD22.697ms vs later full21.267ms; cached-band version added afterward needs profiling. Visual distant-contour audit remains; stable60/whole-game parity not achieved.

## Frozen outline AB and whole-stage timing

Added frozen identical-scene full/LOD/LOD/full120-frame blocks. Draws1535->1310,225 passes removed. Times5.757/5.004/4.515/4.220ms show drift, so no isolated FPS win claim. Pixel comparison finds1378 pixels>8 difference(0.1063%),mean RGB difference<.037; LOD image inspected. New whole-stage scope in live battle measures8.971ms script vs21.211ms mean wall-frame,p95 27.829. Remainder can include engine, render, driver and scheduling; do not assert all is bone cost without isolation. Next performance priority is dynamic engine-side update isolation. Goal remains active.

## Pose submission isolation

Added submit_pose=true diagnostic gate; only --no-pose-upload benchmark disables enemy rig submission after warmup, retaining retarget math/movement/combat/VFX. Normal mean20.485/p95 26.521/stage8.789ms vs no-submit16.237/22.277/8.358ms, draws1424/1423. Downstream skeleton/skin handling is now a concrete target; cannot attribute all4.25ms precisely because shape/visibility and timing also vary. No production animation reduction. Next audit actual skin/joint palette and skeleton work with deformation parity proof. Goal remains active.

## Actual weighted-skin usage audit

Audited all positive-weight vertex influences in five actual enemy assets. Total Skin bindings/weighted bones: composer261/181, Joseph355/200, geisha258/88, Isabella517/315, George404/242. Ancestor closures195/228/102/410/273 show why weighted-only skeleton deletion would be wrong. Each model currently has one mesh/one full-size Skin. Evidence world3d-skin-usage.json. Next implement shared palette compaction with index remapping and deformation proof, retaining full skeleton hierarchy. Audit alone makes no FPS claim and does not change runtime.
































