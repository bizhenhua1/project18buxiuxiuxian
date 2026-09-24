> **2026-09-21 v3 修订：本文件保留为历史依据，不再是执行入口。** 请从 [3D场景生产规范·唯一入口](SCENE3D-START-HERE.md) 开始。旧文中“已验证中性诊断/深度指标”“顶带生产可用”“必须等用户逐项标注”“源码变化后全量重拍”等结论已被复核或取代；具体见 [逐项裁决](SCENE3D-ISSUE-DECISIONS-V3.md)。本次只完成规范设计，未宣称运行时已修复。

# 3D 场景问题集中交接（Astra）

这份文件是当前 3D 场景生产阶段的集中问题入口。机器台账见
`SCENE3D-ASTRA-ISSUE-LEDGER-2026-09-21.json`；本文件只说明处理顺序、证据边界和验收要求。台账结构和证据路径可先运行
`scripts/validate_scene3d_astra_issue_ledger.py` 校验，报告见
`SCENE3D-ASTRA-ISSUE-LEDGER-VALIDATION-2026-09-21.json`。

## 处理顺序

1. **先补闭合空间结构**：`ROOF-001`（red_cottage）、`ROOF-002`（palace / piper_mountain 入口证据）和 `ROOF-003`（无高拱梁时的 `closed_low_ceiling`）。诊断图里仍能看到顶部背景时，不能通过加雾、调暗或压低镜头视为修复。
   仓库中已有 palace/sewer/crystal shell 与 cave arch 候选，见 `SCENE3D-ROOF-REUSE-AUDIT-2026-09-21.json`；它们只是候选，未完成 AssetSpec 和闭合证据前不能直接接入。
2. **再补资产物理语义**：处理 `ASSET-001`。329 个迁移资产的 `size_px` 和 `alpha_bounds_px` 已由旧 metadata 或 PNG 文件读取，但 `size_m`、`footprints_m`、`contact`、`sockets_m` 仍为空，不能可靠推算接地、穿插、顶面连接或战场净空。分场景、分角色的处理顺序见 `SCENE3D-ASSET-GAP-REPORT-2026-09-21.json`。
   现有 18 景引用路径审计为 0 个缺失；这只证明文件存在，不代表视觉或物理语义合格。
3. **按物理家族校准撒布**：处理 `SCATTER-002`/`PROFILE-001`。森林、室内、洞穴、花园、桥、舞台、钟楼不能共用森林密度或同一顶部规则；必须使用 `SCENE3D-SCENE-PROFILES-2026-09-21.json` 的场景级配置，缺字段保持 pending。
   当前 profile 已额外固定每个家族的 topology、required roles 和 scatter namespace；这只是结构契约，数值与资产 ID 仍需回填。
4. **审查岔路保护**：处理 `JUNCTION-001`。`junction_geometry` 已有测试和显式开关审计，默认开关仍关闭；Astra 需要审查壳体例外、公共厅唯一 owner 和非壳体装饰拒绝结果后，才能决定正式启用。
5. **最后做视觉和性能验收**：处理 `CAP-001`、`CAP-002`、`CAP-003`、`CAP-004`、`PERF-001`。正式 beauty 图用于风格与构图，diagnostic 图用于几何与资产完整性；18 景入口截图和多种子截图只证明可构造与可复现，不代表视觉完成。`CAP-002` 明确要求关闭正式雾、舞台光和补光后再判断几何，不能把暗部当作漏空，也不能把漏空藏进暗部。`CAP-004` 还要求先完成当前源码 provenance 重采集，再使用截图做当前版本结论。

## 必须保留的边界

- 不覆盖现有六套基准，也不把机器 provenance 通过当作美术批准。
- 未有用户视觉审查的代表场景，不得标记为“完成”。
- P01 与 P02 都已有源码冻结后的 Windows/OpenGL 当前有效重采集；P02 的旧批次与18景旧截图批次仍标记为 provenance recheck required。不得修改旧 manifest 的 hash 来“修复”证据，必须在源码冻结后重新采集并重新校验。
- 未标注物理语义的资产不得填零脚印或猜测尺寸；应保留缺口并回到资产请求。
- P10 当前只测旅行/流式路径，不包含技能、AOE、多弹道、远程特效或高密度战斗压力；最新 Windows/OpenGL 报告已有真实 draw-call，但仍不能据此承诺最终战斗稳定 60 FPS。
- 台账中没有任何问题可仅凭“文件存在”或“机器 provenance 通过”关闭；必须回填修改前后截图、资产 ID、SceneProfile 版本和验证结果。

## 证据入口

- 18 景统一入口截图：`tempassets/work/scene3d-18-captures-20260921/contact-sheet.png`
- P01 当前源码重采集：`tempassets/work/p01-recheck-20260921-181000/manifest.json`
- P02 六主题当前源码重采集：`docs/design/SCENE3D-BASELINE-MEASUREMENTS-RECHECK-2026-09-21.json`、`tempassets/work/p02-recheck-20260921-181000/`、`tempassets/work/p02-mask-recheck-20260921-181000/`
- 18 景批次摘要：`tempassets/work/scene3d-18-captures-20260921/batch-summary.json`
- 现有阶段覆盖审计：`docs/design/SCENE3D-EVIDENCE-COVERAGE-2026-09-21.json`
- red_cottage / piper_mountain 多种子：`tempassets/work/representative-multiseed-20260921/contact-sheet.png`
- 代表场景 beauty/diagnostic：`tempassets/work/representative-diagnostic/`
- P10 有边界性能报告：`tempassets/work/scene3d-performance-20260921/p10-report.json`

## 交付给 Astra 的最小输出

对每个问题回填：`issue_id`、修改前后截图、使用的资产 ID、SceneProfile 版本、是否影响默认六基准、以及验证命令/结果。只有拥有这些证据的问题才能从 `open` 或 `*_visual_review_pending` 转为 `resolved`。
