> **2026-09-21 v3 修订：本文件保留为历史依据，不再是执行入口。** 请从 [3D场景生产规范·唯一入口](SCENE3D-START-HERE.md) 开始。旧文中“已验证中性诊断/深度指标”“顶带生产可用”“必须等用户逐项标注”“源码变化后全量重拍”等结论已被复核或取代；具体见 [逐项裁决](SCENE3D-ISSUE-DECISIONS-V3.md)。本次只完成规范设计，未宣称运行时已修复。

# Astra 交接问题台账

完整机器台账见 `SCENE3D-ASTRA-ISSUE-LEDGER-2026-09-21.json`。处理顺序固定为：先解决室内/洞穴的连续顶面，再补齐资产物理标注和深度诊断，之后才做岔路撒布与18景推广。台账完整性与证据路径由 `scripts/validate_scene3d_astra_issue_ledger.py` 校验，当前报告为 `SCENE3D-ASTRA-ISSUE-LEDGER-VALIDATION-2026-09-21.json`。

目前最明确的两个视觉问题是：`red_cottage` 的壳体中心开口没有连续顶棚；`palace` 的拱门上方在诊断光照下直接看到灰色背景。正式暗光截图不作为几何证据。

代表场景的同机位 beauty/diagnostic 证据也已补齐：`red_cottage` 见 `tempassets/work/representative-diagnostic/red_cottage-20260921051448/`，`piper_mountain` 见 `tempassets/work/representative-diagnostic/piper_mountain-20260921051509/`。两套 manifest 均通过 `scripts/validate_scene3d_capture.py` 的 provenance 检查；诊断图仍能看到顶部背景漏空，因此 ROOF-001/002 已升级为确认的缺失资产问题，仍待用户视觉验收。

如果没有高拱梁，执行 `closed_low_ceiling`：使用连续顶面带网格、累计弧长UV、独立 ceiling 材质、ceiling sockets 和吊挂装饰。没有可用顶面材质时登记 `blocked_missing_asset`，不通过调暗、雾、镜头或家具拉伸解决。

连续顶面带生成器已经落地并通过几何测试，但还没有绑定任何正式场景的材质、净空和 socket；因此不能把它当作已封顶的视觉结果。

现有仓库的 roof/shell/arch 资产已做只读盘点，见 `docs/design/SCENE3D-ROOF-REUSE-AUDIT-2026-09-21.json`。其中 palace、sewer、crystal shell 和 cave arch 被列为“候选”，但没有任何一个因为文件名或外观就自动获准复用；仍需补 AssetSpec、socket/脚印和原机位闭合证据。

六套基准现在已有当前源码下重新采集的正式图、诊断图、同相机 role-ID 遮罩和线性视空间深度遮罩；聚合报告见 `docs/design/SCENE3D-BASELINE-MEASUREMENTS-RECHECK-2026-09-21.json`，机器 ROI/距离段统计已通过，但仍需要视觉审查，不能把机器统计当作美术批准。P02 已完成“可追溯测量”，没有完成“美术验收”。原六套基准目录未被覆盖。

岔路保护的几何基础已完成并通过无头测试：路径走廊采样、SAT 脚印相交、空间桶候选、2/3 岔边界接续和 `segment_id + junction_id` 共用厅 owner 均有证据。现在也已在显式 `--junction-geometry-layout` 开关下完成 18 景运行时审计，结果见 `tempassets/work/fairytale-travel-audit-junction-geometry/report.json`。开关模式会拒绝部分非壳体装饰，sprite 数量相对默认模式下降；默认仍保持关闭，等待 Astra 审查结构例外。壳体使用专用开口/支撑检查，SAT 只约束非壳体装饰。

交给 Astra 时请保留三个边界：

1. 没有用户审查通过的代表场景，不得标记为“视觉完成”；当前 P05/P06/P07/P08/P09/P10 仍未完成。
2. 已通过的 18 景旅行审计和流式构造审计只证明数据、引用和有限值有效，不证明密度、比例、顶面、接缝或构图已经对齐六套基准。
3. 当前两个场景的性能数据只是短时旅行样本，不包含技能、AOE、多弹道、远程特效或长期流式上传压力；不能据此宣称最终 60 FPS。

18 个童话场景的统一 `approach` 机位截图目录仍保留在 `tempassets/work/scene3d-18-captures-20260921/`，快速总览见 `contact-sheet.png`。但源码 provenance 复核发现这批旧证据不能代表当前源码：目前审计到 98 个 manifest，其中 62 个 v2、36 个 legacy/malformed；v2 中 8 个是当前源码有效的新采集，54 个仍无效，其中 46 个仍引用旧的 `fairytale_corridor.gd` hash，另有 1 个缺少核心源码 hash，其他无效项来自源码更新前的旧批次。截图与旧 manifest 只保留为历史视觉参考，不得改写旧 hash 来“修复”证据；P01/P02 已另存当前源码重采集，18景旧批次仍需在源码冻结后重采集。旧批次不能作为当前版本的物理家族、顶部、密度、接地、接缝、通道或战场避让验收。

现有截图 manifest 的阶段覆盖已由 `scripts/audit_scene3d_evidence_coverage.py` 扫描，结果见 `docs/design/SCENE3D-EVIDENCE-COVERAGE-2026-09-21.json`：共 31 个 manifest，绝大多数场景只有 `approach`，因此移动、事件、战斗、2/3 岔和 successor 仍是明确缺口。源码一致性复核见 `scripts/audit_scene3d_manifest_provenance.py` 与 `docs/design/SCENE3D-MANIFEST-PROVENANCE-AUDIT-2026-09-21.json`；P01/P02 已用当前源码完成 Windows/OpenGL 重采集，P02 旧批次及18景旧批次仍维持 recheck_required。

`red_cottage` 与 `piper_mountain` 已另外用 1842、2718、4096 三个种子各捕获一次入口机位，6/6 provenance 通过，见 `tempassets/work/representative-multiseed-20260921/`。多种子只证明当前生成是可复现且能构造，不代表资产密度和屋顶几何已经合格。

P10 的有边界测量已在 Windows/OpenGL 桌面渲染环境补齐：固定 1440×900、60Hz、120 帧预热、每次 1800 帧（30 秒），参考森林与 `alice_tea`、`snow_mirror` 交替三轮。draw-call 监控真实可用：三轮各场景 draw p95 最大值为 631（`alice_tea` 单轮最低 459，`snow_mirror` 单轮最低 382）；森林 9885 个精灵，`alice_tea` 1372 个精灵，`snow_mirror` 632 个精灵。候选样本 frame-time P95 最高 12.726ms，参考森林最高 16.881ms，上传峰值最高 0.052ms；按参考中位 P95 加 `max(10%,2ms)` 的规则，旅行范围门通过。当前报告只证明旅行和流式路径的这一档压力，技能和战斗压力仍需另测。

已生成 18 景的 `SceneProfile` 草案：`docs/design/SCENE3D-SCENE-PROFILES-2026-09-21.json`，并通过 `scripts/validate_scene3d_scene_profiles.py`。这只是可执行的字段契约，不是已批准的美术参数；结构、顶部、功能组、地被、战场净空、资产 ID 和 limits 均明确保留 pending。

329 个迁移资产的字段缺口已按场景、物理家族和角色拆分到 `docs/design/SCENE3D-ASSET-GAP-REPORT-2026-09-21.json`；独立迁移校验报告 `docs/design/SCENE3D-ASSET-MIGRATION-VALIDATION-2026-09-21.json` 已确认18景、329个资产全部拥有合法 `size_px`、`alpha_bounds_px` 和 `anchor_uv`，且没有 Alpha 贴边。当前没有资产触及透明画布边缘，但 `size_m`、`footprints_m`、`contact`、`sockets_m` 四类物理字段仍为 329/329 缺失，报告不会推断或填充这些值。

新增集中登记的问题为：`SCATTER-002`（物理家族仍未独立校准）、`ASSET-002`（root/接地/脚印/穿插闭环缺失）、`MOTION-001`（真实移动和镜头过渡尚未覆盖）、`PROFILE-002`（18 景 profile 等待 Astra 回填）。这些问题与原有屋顶、资产标注、诊断图、岔路保护和性能边界一起，统一以 JSON 台账的 `handoff_order` 为处理顺序。
