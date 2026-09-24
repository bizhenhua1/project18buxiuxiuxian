# Luna执行与验收手册 v3

执行入口：[SCENE3D-START-HERE.md](SCENE3D-START-HERE.md)。本文件给出可依次执行的步骤，不要求Luna自行重新设计七个家族。当前只交付规范，下面任务全部在后续实现轮执行。

**v3.1执行修订**：先读[空间组合补充](SCENE3D-SPATIAL-PRESETS-V3.1.md)第6–7节。R01的6–10米可见候选先交付；下表T06的30米/战场/岔路是完整代表景要求，不是第一份成果门槛。T01满足可靠固定取景或已记录的替代出口即可解锁可见结构工作；T02仍为后置专项。不得先花数小时建设采集平台。

**v3.2优先修订**：先读[资产驱动计算](SCENE3D-COMPUTED-PLACEMENT-V3.2.md)。当前资产一次标注→尺度/开口/接触/顶面计算→明确补件决策→实施→取景核对。T01工具修复不再是几何工作和首景布局的依赖；只影响能否声称截图精确可比。下表的历史依赖字段按此解释，机器任务已同步移除不必要的采集前置。不要先建设全资产自动分析平台。

## A. 一次工作的边界

先做一个代表景，交出具体画面；不要先标注329项、重拍24景或完成全部报表才进入布局。首景 `red_cottage`，其次 `piper_mountain`；开放家族可以独立推进，不依赖洞穴美术批准。顺序推荐：小屋 → 山洞 → 苹果园 → 市场 → 桥 → 剧院 → 钟楼，再扩同家族其余11景。

状态用：`todo / implementing / candidate_ready / awaiting_visual_review / blocked_specific / accepted`。用户审查前允许准备同家族其他景，但不全量套用尚未接受的模板。代码/合同测试通过与美术接受是两个状态。

## B. 任务分解与预期产物

| ID | 依赖 | 具体动作 | 必交付 | 停止/完成条件 |
|---|---|---|---|---|
| T01 | 无 | 修同入口CaptureContext与诊断冻结；只测试red_cottage及一个参考 | 采集代码修复、同帧beauty/neutral、状态哨兵 | 禁雾参数持续有效、姿态完全相同；失败两轮报具体覆写链 |
| T02 | T01 | 修role/depth量纲和有效像素；已知深度微场景验证 | 测试2/10/35 m、独立validity、role映射 | 若工具暂不可得，标measurements_unavailable，可继续结构试配，不生成假数值 |
| T03 | 无 | 为red_cottage实际使用的图建v2记录、源图核查 | 资产清单、支撑/占地/尺寸、缺口分类 | 可先完成最小包；未知asset不发布；不等待329项 |
| T04 | T03 | 修CeilingBand、墙顶收口、连续面与材质复用 | 直/弯UV测试，单景无雾顶壁图 | 先几何闭合后美术材质；缺材质只阻塞正式美术 |
| T05 | T04 | 实现公共岔路owner、可通行并集与屋顶连接 | 两/三岔结构图，全部出口可走 | 无重叠顶面、墙不封出口、支柱不压路 |
| T06 | T03,T04,T05 | 接入red_cottage完整profile与分层layout | 30 m路段+战场+岔路；正式/中性图及录像 | 满足硬门槛即可提交审查；两次定向修改上限 |
| T07 | T03的标注方法 | 按山洞配方实现连续洞壳与岩腔 | piper_mountain对应资产与场景证据 | 可独立于小屋视觉批准，不复制低顶方案 |
| T08 | 无全局采集前置 | 苹果园/市场/桥/剧院/钟楼分别实例化模板 | 每景一份profile和对应结构/主题证据 | 按景提交，不先批量“完成” |
| T09 | 对应代表candidate_ready | 按18景配方扩展其余11景 | 每景自己的主体、禁用项、缺口与证据 | 代表未accepted时仅candidate，不冒充已批准 |
| T10 | 单景candidate_ready | 有界性能对比与局部回归 | 该景回放3次数据、最多2次优化 | 不因碎物测试重开战斗或所有场景压测 |
| T11 | 所有景已有实际状态 | 汇总审查页和未解决清单 | 18景状态、有效证据、剩余具体问题 | 部分blocked就如实交付，不补空PASS |

这些依赖是实施优先级，不是美术批准的全局锁。T03资产处理方法可复用，T07不应要求red_cottage整包图才能标注洞穴。禁止因一个场景缺图把其他17景都标blocked。

## C. 代码落点和最小改造接口

以下为设计接口，不宣称仓库已经实现。优先复用实际类，不按名字强制新建平行系统。

| 当前位置 | 改动意图 | 禁止事项 |
|---|---|---|
| `godot/scripts/spaces/layouts/fairytale_layout.gd` | 保留有corridor时的委托入口，明确配置走哪条路径 | 在委托后不会执行的旧分支调参数然后说生效 |
| `godot/scripts/spaces/layouts/fairytale_corridor.gd` | 读取发布profile；拆结构/家具/覆盖/地表生成；稳定ID；按真实footprint拒绝 | 增加无条件structure fallback、每帧重抽 |
| `godot/scripts/spaces/segment_world.gd` | 注册profile、route patch、owners和预读边界 | 以新数组索引作为永久实例ID |
| `godot/scripts/world3d/ceiling_band.gd` | 修弧长UV、单位、地形高度与端面；低顶实现 | uv_repeat参数存在却不用；多个顶带盖住同一厅 |
| `godot/scripts/world3d/junction_geometry.gd` | J并集、出口开口、共用floor/roof ownership | 只针对选中路线清障 |
| `godot/scripts/world3d/scenery.gd`及cutout/floor/mist shader | role分批，contact分派，可靠diagnostic override | 通用mask丢失原vertex逻辑、用首实例role代替整批 |
| `godot/scripts/world3d/route_view.gd` | 提供冻结/诊断状态，控制下一次sync不覆写 | 在相机不同阶段采集后拿来比较 |
| `godot/data/scene3d/`（待建） | 运行时catalog与profile、版本迁移适配 | 运行时读取docs或tempassets |
| `godot/tests/capture_*`及`scripts/aggregate_scene3d_baselines.py` | 单入口回放、same-frame各pass、可靠深度和ROI统计 | PASS字符串覆盖错误日志 |

建议最小数据接口：

```text
resolve_scene_profile(scene_id) -> validated runtime profile
build_route_patch(route, span_m, all_branches) -> floor + clearance + junction owners
build_enclosure(patch, roof_mode, materials, cross_section) -> static meshes + sockets
place_structures(patch, profile, rng_structure) -> stable instances
place_assemblies_and_dressing(patch, catalog, rng_by_layer) -> stable instances + rejection stats
publish_chunk(instances, geometry, resource_keys) -> existing batched renderer
capture_frozen_context(context, passes) -> manifest + images + validity
```

Profile最少字段：schema_version、scene_id、family、roof_mode、meter_units、reference_context_id、asset_catalog_revision、structure_spacing_m、cross_section、assemblies、layer_rules、junction_rules、contact_policy、lod_budget、random_namespace、review_status。未知值不填0；fallback必须显式记录。

连续面cross_section至少包括地面/墙/顶材料ID、走廊净空与镜头净空包络、支撑高度来源、纵横UV周期、采样容差。灯光/雾引用现有已接受配置，本次不用它们作密度旋钮。

## D. 可信的中性诊断

### D1. 同机位与同帧

从一个统一3D运行入口创建reference和candidate，或注入完全相同的CaptureContext。Context至少含：run_seed、scene_id、route seed、branch choices、phase、route_s_m、camera transform/projection/FOV/near/far、viewport有效矩形、actor model/pose/time/transform、light profile、时间戳和有效依赖hash。

先加载到稳定、执行所有route/scenery同步，冻结模拟/动画/流式与shader时间，再截图。beauty和neutral之间只换材质诊断开关，不调用额外app._process，不让角色和风摆多走一帧；需要渲染提交时只触发绘制。若无法冻结GPU TIME，debug分支显式使用保存的时间uniform。记录各pass相机/姿态hash一致。

关雾顺序：禁mist批次与背景雾 → 材质自定义fog参数 → 环境雾/volumetric可用项 → 主/补/点光及局部光参数 → 发光、后处理与曝光 → 隐藏HUD/选中描边/技能特效。neutral用统一中性照明或原albedo无光输出，不能保留整片死黑。

draw前检查参数哨兵和mist可见实例数；把一个本应明亮可见的灰色校准面纳入测试。设置后被sync覆盖或仍有浓雾即 `invalid_diagnostic`，不继续采全图。

如果原图本身烘焙得很暗，albedo pass也不够判断结构：追加**平灰几何pass**（统一中灰实体、明亮且明显不同色的背景、固定曝光，保留alpha开口）和法线pass。屋顶没有面时会直接露背景；有面但纹理太暗则灰色面仍连续。原图单独在白/灰底检查，不把调亮后的诊断图当正式美术。判断“缺资产/缺面”必须区分这两种情况。

### D2. 保留原几何

原cutout shader含skip_vertex_transform、贴地/壳体/角色皮肤等路径，通用override不等价。在同shader加入debug输出分支，保留vertex、alpha discard与受支持的骨骼/实例变换，只把fragment输出改albedo/role/depth；透明mist在结构pass中隐藏。这样ID/深度与可见几何一致。

若renderer限制无法做精确ID，先做CPU投影抽样/逐role开关对照，输出“不具备像素精确ID”，不能把后处理色差当分类误差硬凑百分比。

### D3. 深度与role正确性

深度定义选正的view轴距离或相机欧氏距离之一并固定，建议正view深度米数。首选R32F/EXR线性输出和独立validity；若当前后端无法可靠读浮点，可离线24位打包，关闭色调映射、gamma污染、抗锯齿混色并验证往返精度。不能用8位灰度随意反推20米后报30米档。

固定测试：前景2 m、中景10 m、远景35 m三个平面+透明开口+背景；误差≤0.02 m工程门槛，背景validity=0。深度分段按实际镜头可见范围冻结，例如0–10/10–30/30–far；far≤30时第三段明示不适用。

Role从资产语义或每实例字段取得，不从材质名字/第一实例推断；树木结构、植被、地表、屋顶、墙、家具、角色、背景至少可分。ID pass禁止混合，alpha边界混色像素单列unknown，不硬按最近RGB塞给某类。

### D4. 统计用途与局限

有效viewport去掉UI和黑边；上部30%、下部25%、左右各25%、中部50%为首轮固定ROI，重叠ROI只分别报率、不能相加成100%。角色像素从场景占用分母剔除并单独报告。

占用率不能证明屋顶连续（可能只是横梁挡住）；对所有应闭合区域还要网格拓扑/射线覆盖检查。建议沿路每0.5 m从内侧向顶/侧采样，排除显式门洞及开放区；不能只对屏幕顶部做一张mask。多方向检验用调试相机，正式构图比较仍用冻结镜头。

密度指标先作诊断，不设置“全景80%覆盖”之类统一门槛。每家族从有效参考测得区间，再结合主题配方判断；当前无有效数据时以结构、主体、比例和手工对照为主，不能编造baseline数值。

## E. 一个场景的验收包

最低包只包含有意义的材料：

1. 同机位正式图：行进、事件停机、战斗各1张；旁边放主参考相同阶段图（不同主题只比较空间语言）。
2. 中性图：能看清屋顶/墙根/家具支撑；闭合场景补一张调试剖面或向上结构图。
3. 15–25秒录像或等价确定性帧序列：直行、两岔左右各一次、三岔最侧分支、选择后结构恢复；不要只有选择前静态图。
4. 一页变更单：改了哪层、复用了哪些asset_id、新增/缺哪些、拒绝放置原因、依赖版本。
5. 硬门槛结果、待用户审查项、最多3个主要残留问题。

不要求同一阶段生成五份互相重复的报告。截图必须写实际入口/phase/seed；manifest里的seed来自运行中world，而非只写UI输入值。

### E1. 硬门槛

- 闭合区域无未声明天空/背景漏出，连续面无共面闪烁，出口无堵墙。
- 主体角色画幅和镜头不因资产修复改变；支撑点硬物误差≤0.02 m初值。
- 树根/桌腿/门柱/吊点不明显断裂；无物体穿地、漂浮、随镜头翻转。
- 相同seed同patch重复生成transform一致；新增litter不改变structure。
- 岔路共享owner唯一；三条路都可通行；未选路不当场重撒/消失。
- 没有SCRIPT ERROR/SHADER ERROR/非预期资源缺失；测试不可只匹配PASS。
- Runtime发布资源全部位于Godot导出路径内，未知资产未发布。

### E2. 美术审查四问

1. 不看名称，能辨认这是室内/岩窟/桥/茶庭/市场吗？
2. 至少有一类主题主体明确承担中景，还是全是零碎草和箱子？
3. 层次、屏幕占用和结构节奏接近该家族标杆，而非尺寸膨胀填满？
4. 正式光雾让氛围更好，同时中性图证明实体结构确实成立？

任何一问否定，写具体物件/位置/缺层，下一轮只改该问题。用户未审查时标awaiting_visual_review，不无限自判。

## F. 回归范围与证据失效

| 修改 | 需要重验 | 不需要 |
|---|---|---|
| 文档/提示词/未发布profile | 文档链接、JSON结构 | 所有截图 |
| 单资产脚点/尺寸 | 用到它的一个近景+岔路侧向 | 未引用该资产的17景 |
| 单景布局/配方 | 该景行进/战斗/岔路 | 六基准全拍 |
| 共用顶带/公共厅算法 | 一个低顶、一个洞穴/高拱、两/三岔单测 | 开放场景全量回放 |
| shader根变形/alpha路径 | 一个硬物、一个软草、一个壳体的近远移动 | 每个相同材质对象 |
| 共用镜头/单位转换（本任务通常禁改） | 原六参考代表机位与各家族代表、人工说明授权范围 | 不得仅以一景通过替代 |

源码hash变化是线索，不是让所有历史图作废的命令。manifest列出有效依赖；旧基准图仍可作为历史目标，注明旧实现，不能声称它是新实现截图。禁止篡改旧hash来让验证器通过。

## G. 防止再次无效循环

一轮定义：明确假设 → 单一类别变更 → 同一测试用例 → 前后结论。观察“仍暗”后只重复截图不算一轮；改草数同时改FOV、光照、家具尺度则无法归因，应拆开。

同一问题最多2轮。首次发现缺顶就直接定位连续面和材质，不先做全18景性能；两轮仍无改善，立即提交：问题位置、当前图、两次改法及结果、代码原因、最小缺口、推荐方案和代价。用户需要回答时用一个明确取舍问题，其余独立任务继续。

可用时间提醒：连续30分钟还没有一个可审查的场景变化，应停止当前路径，写出具体卡点；不是要求30分钟内完整完成一景，而是不允许数小时只生成证明工作量的报告。

每个任务收尾只报：本次实际改变、可见改善/失败、验证、下一步或阻塞。不得把测试文件数量、截了多少图当成果。

## H. 可以直接交给Luna的执行指令

> 阅读 `docs/design/SCENE3D-START-HERE.md` 及所链接的v3手册。此次只做最新Godot 3D场景生产，不改网页demo、原六基准、镜头和战斗玩法。先按T01修可靠中性诊断，并按T03标注red_cottage实际使用的资产；采用closed_low_ceiling完成连续顶壁，修顶带UV和公共岔路owner，按该景配方归位家具及地表层，交付一个可审查场景。当前沿用不生图范围时只复用、裁材质和登记精确缺图；不要因缺图停止其他工程工作。设计初值可以在手册区间内试配，未知值不得冒充实测。每个问题最多两轮；无法解决时提供证据、推荐方案和代价，停止重复试配。首景candidate_ready即提交用户审查，不等18景全做完，也不擅自宣布视觉accepted。之后再按独立家族任务推进。

> v3.1补充：先完成R01的6–10米domestic_low候选，再做R03完整行进/战场/岔路；不等待完整素材配额、329项标注或T02深度工具。取景工具两轮失败就使用规定替代出口。每张工单最多三项必要检查，采用既定默认值，只有出现具体失败证据才重新设计。

> v3.2覆盖上述“先修T01”的顺序：从当前一张拱架/一间房的资产内容开始，计算可用尺度、节距、顶高和实体覆盖；按结果直接实施，只在之后用截图核对。源图标注或明确公式能回答的问题，不再靠反复截图试错。雾和杂草只允许做合法结构与接触之后的语义收口。

本指令不自动启动新长期目标；目标的恢复/替换仍以用户操作和当前任务范围为准。
