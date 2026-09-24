# 上轮问题逐项裁决与修复设计 v3

核查日期：2026-09-21。依据：仓库中的问题台账、实际layout/renderer/shader/采集代码和3张关键源资产（小屋壳、茶桌、山洞岩门）。本轮没有重新运行场景，没有把所有旧截图视作中性诊断。本表的“方案已定”只表示可执行，不表示缺陷已修复。

## 1. 必须先撤回的证据结论

1. `capture_fairytale_3d_representative.gd` 在设置诊断参数之后又调用app更新；`route_view → scenery` 会重写fog/lighting。仅更改WorldEnvironment并不能禁用自定义shader的雾和局部光，独立mist批次也要处理。故历史diagnostic不能自动称为“无雾中性”。
2. 六基准由独立stage采集，18景由endless入口采集；tick、相机、route状态并不相同。不能把不同入口画面的差异直接算成密度差。
3. `capture_world3d_role_depth_masks.gd` 把线性深度限制到20 m，聚合器却有30 m以上统计档；深度图的白色背景还可能被当作20 m。该深度表不能支持层次结论。
4. 通用material_override的mask会失去原cutout shader的vertex变换与接地逻辑；按MultiMesh首实例分类也不能代表全部实例。需在原几何路径输出诊断，或严格复制其变换。
5. `ceiling_band.gd` 是原型：步长单位为U；`uv_repeat_m`没有参与UV；前两截面累计UV时机错误；独立分支顶带没有处理公共厅。不能因一次测试标志就声称生产可用。
6. `fairytale_corridor.gd` 已调用 `structure.png`；茶会重复加主体实验的“原来没加载”解释错误，应回到真实放置/遮挡/尺寸调查。
7. `test_fairytale_corridor_frames.gd` 的假world缺`scene_profiles`；日志出现脚本错误后仍可能打印PASS。测试必须同时看退出码、错误日志和目标断言。

这些均为仓库静态核查发现；影响程度须修复后用一景验证，不据此宣称全部场景实际发生了同一种故障。

## 2. 21项问题的明确处理

| 旧ID | 本版裁决与默认方案 | 实现位置/工件 | 完成证据 | 当前状态 |
|---|---|---|---|---|
| ROOF-001 | 小屋shell是装饰框；采用连续低顶、侧墙、墙顶收口，优先本主题材质裁片 | ceiling_band、场景profile、red_cottage资产标注 | 同机位无雾顶面、梁端、墙顶、分岔全连通 | design_decided / implementation_pending |
| ROOF-002 | palace为只读参考，不能用piper_mountain图证明palace缺顶；将基准疑点与新景闭合分开 | 修台账证据归属；新景按各自roof_mode | 基准疑点如需验证只采其自身；新景有独立顶壁证据 | evidence_correction_pending |
| ROOF-003 | 顶带原型先修步长、UV、地形高度、公共厅连接，再接runtime profile；不等用户提供全部尺寸 | ceiling_band与单元测试 | 直线/弯道/三岔UV、相邻边、法线、净空断言及无雾图 | implementation_pending |
| ASSET-001 | 按一个场景用到的图优先标注；允许有来源的设计试配；悬挂/顶面不强填地面脚印 | 新v2契约、迁移适配器 | 一景完整runtime_ready记录、角色尺规、语义校验 | implementation_pending |
| CAP-001 | role mask保留原vertex/alpha，按asset role分类；深度用线性浮点和独立validity | capture mask shader、聚合器 | 已知深度测试点2/10/35 m正确，背景不计入、role覆盖校验 | invalid_metrics_quarantined |
| CAP-002 | 在最终渲染态冻结后覆写诊断；停掉后续同步，禁全部雾及补光；记录实际draw前状态 | representative capture、scenery debug开关 | 参数哨兵未被覆盖、mist实例数0、beauty/diagnostic同姿态 | diagnostic_untrusted |
| JUNCTION-001 | J为所有路线并集，公共地顶唯一owner，分支出J才恢复；开口不建墙 | junction_geometry、fairytale_corridor | 两/三岔各方向连通、无重叠面、owner唯一、移动不跳 | implementation_pending |
| PROFILE-001 | 现有七组随机参数降级legacy；本版给家族节奏范围和主题组模板 | v3主规范、runtime adapter | 一个代表景结构/主体/覆盖分别有效且可回放 | design_decided / implementation_pending |
| PERF-001 | 场景固定回放同机对照；两轮上限；不扩大到技能重做 | bounded benchmark | 3次30秒分布、相对基准、纹理和draw call；有瓶颈即报告 | bounded_validation_pending |
| CAP-003 | 18景历史图用于问题导航；先只复核当前代表景；不要求全量新截图解锁工作 | evidence manifests | 每景变更时只更新相关阶段的证据 | historical_navigation_only |
| CAP-004 | 按语义依赖判stale，文档/未引用代码不作废图片；禁止改旧hash | manifest依赖清单 | 捕获入口、相机、profile、所用资产、有效shader变更可追溯 | implementation_pending |
| SCATTER-002 | 七物理家族分模板，住宅与大厅各有参数；18景用不同语义主体 | 18景配方及profile | 室内/洞穴/花园等在同机位可辨，不能全像森林 | design_decided / implementation_pending |
| ASSET-002 | canvas/visible分开、支撑点与占地分开，硬物禁用草根变形 | asset adapter、接地shader分派 | 桌四脚、门两端、吊灯挂点、斜坡和转角接触图 | implementation_pending |
| MOTION-001 | 静态seed与transform冻结、加载卸载滞回，过渡按同帧回放检查 | streaming、route frames | 直行/左转/右转/三岔录像，实例稳定ID前后对照 | targeted_validation_pending |
| PROFILE-002 | 不等待用户逐字段批准；Luna用设计初值实例化candidate，发布到godot/data | runtime profiles与export检查 | 不读docs路径、完整字段、候选与批准状态区分 | implementation_pending |
| VIS-001 | 已接受镜头作为锁定输入，按同类参考拆指标；缺有效度量时先做结构/语义审查，不全停 | CaptureContext、代表景审查 | 同入口同viewport对照，角色画幅冻结，参考语义明确 | engineering_actionable |
| VIS-002 | 尺寸与role标注属于执行工作；视觉难题才升级用户 | 资产手册D与单景清单 | 每项来源/值/可信度、未知不进入runtime | engineering_actionable |
| VIS-003 | 屋顶方案本版已定：住宅低顶、大厅拱顶、岩窟连续洞壳、开放场景局部棚 | 各配方roof_mode | 闭合/开放区域显式可验，没有暗部伪装 | design_decided |
| VIS-004 | 主题组合不是随机加密；茶席、摊架、机器必须有主物和配物关系 | assembly模板+独立随机流 | 一景前后能指出具体新增/归位的主体 | design_decided |
| VIS-005 | beauty看氛围，neutral看结构，role/depth看分层；无法禁雾则诊断为失败 | debug pipeline | 无雾、无舞台灯、无HUD且原几何不变 | implementation_pending |
| VIS-006 | 撤销泛增密与重复主体的成功叙述；对已回退实验只保留失败教训 | alice_tea记录、piper_market任务 | 下一次实验明确只改一个原因，有完整对照 | rejected_experiment_retained |

## 3. 不能再伪装成用户决策的事项

以下已经有明确默认方案，Luna应实现/试配，不应问用户“怎么办”：读取现有图、定义脚点、求画布尺寸、生成简单连续面、修UV、保存profile、修诊断覆写、对齐采集入口、确定性随机、岔路公共owner、同景材质裁片与拼接检查。

以下才需要带具体证据升级：

| 触发 | 必须提交 | 默认推荐 |
|---|---|---|
| 固定镜头净空与住宅低顶观感确实矛盾 | 同镜头两种剖面和正式截图；分别牺牲什么 | 保镜头，高侧墙+画幅内低梁+镜头外高顶 |
| 两次复用/生成仍无合格屋顶材料 | 候选图与具体失败位置、最小补图请求 | 补1张材质，不重画全景 |
| 原画透视无法适配岔路侧向视角 | 正面/侧向截图与支持角度 | 增加侧片或低面厚度，不绕转billboard |
| 某代表景两轮后仍明显不像家族 | 前后图、层级分解、缺失主体、两种构图草案 | 优先补主题主体，停止加碎物 |
| 性能两轮后超预算 | 分项帧时/批次/资源，成本最大的1–3项 | 减透明覆盖与碎物，保结构/镜头 |

升级报告不应只有“请给方向”。写明推荐方案、代价和最小需要用户回答的取舍；同一问题不重复询问。该问题阻塞时转做独立工作，不继续在它上面无差别试配。

## 4. 旧文件的解释边界

旧台账 `findings/status` 和delivery中的PASS均是当时记录。每个相关入口已加v3审查说明，旧数据未删除、未伪造重测。历史mask/diagnostic不再作为数值门槛来源。未来解决问题时同时更新v3索引中的实现状态和证据路径，旧记录保持可追溯。

这次文档交付关闭的是“没有明确设计和执行规则”的缺口；运行时问题仍待对应任务实施和复核，不能把这21行标成代码已完成。
