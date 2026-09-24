# SCENE3D v3.2 执行问题登记

本文件只登记执行过程中遇到的问题，不修改生产规范，也不把临时补丁写成规范。

执行边界：

- 按 `SCENE3D-START-HERE.md`、`SCENE3D-PRODUCTION-STANDARD-2026-09-21.md` 和各景 recipe 执行。
- 现有六套基准镜头、战斗玩法和已接受的 3D 路径保持不变。
- 未列入当前景 recipe 的资产类型不得因为截图漏空而临时增加。
- 问题必须有文件、运行日志或固定机位图作为证据；没有证据的内容保持待核，不猜测关闭。
- `candidate`、`verified` 只表示结构或运行验证，不表示用户视觉验收通过。

## 当前执行批次

| 场景 | 当前状态 | 已执行 | 未完成 |
|---|---|---|---|
| `red_cottage` | candidate_reviewed | 闭合低顶、框架尺度、共享段/分支顶面、固定机位 beauty/diagnostic | 用户视觉验收、完整战斗与三岔复核 |
| `snow_mirror` | candidate_reviewed | 运行时高拱 profile、固定机位 beauty/diagnostic | 资产物理标注、用户视觉验收 |
| `piper_mountain` | candidate_reviewed | 运行时洞壳 profile、固定机位 beauty/diagnostic | 连续洞壳资产物理标注、入口过渡、用户视觉验收 |

## 问题清单

### EXEC-BRANCH-001 · 未选分支的顶面提前进入画面

- **场景**：`red_cottage` 两岔/三岔。
- **证据**：`tmp/rep-visible-check-3/diagnostic.png`、`godot/scripts/world3d/scenery.gd`。
- **现象**：初始化时同时生成左右分支顶面，远处产生交叉轮廓。
- **处理**：仅保留公共段顶面，分支顶面按 `world.camera_region.branch` 加载；未选分支不生成，因此也减少绘制开销。
- **状态**：`runtime_fixed_candidate`。
- **仍需验证**：真实两岔/三岔选择后的镜头、分支接续和战斗入口。

### EXEC-ASSET-001 · 三个代表场景尚无完整物理资产合同

- **场景**：`snow_mirror`、`piper_mountain`；`red_cottage` 已有候选合同。
- **证据**：`docs/design/SCENE3D-ASSET-MIGRATION.json`、`docs/design/SCENE3D-ASSET-GAP-REPORT-2026-09-21.json`。
- **现象**：尺寸、脚印、接触面和 socket 仍不能全部从旧 PNG 元数据推导。
- **处理**：保持缺口登记，不把零面积或像素比例伪装成 runtime_ready；若后续标注证明旧资产不适配，按资产手册直接替换或从运行时目录删除，不为保留旧图改变场景族规则。
- **状态**：`open_annotation_gap`。
- **需要外部处理**：按拱门/岩环、入口结构、地面功能物件分别填写 AssetSpec。

### EXEC-VIS-001 · 三个代表场景完成固定机位候选复核，但均未视觉验收

- **证据**：`tmp/rep-envelope-red-2/manifest.json`、`tmp/rep-envelope-snow-2/manifest.json`、`tmp/rep-envelope-piper-2/manifest.json`，三份来源校验均通过。
- **状态**：`candidate_reviewed_pending_user`。
- **处理要求**：三景已经分别完成 beauty/diagnostic；顶面包络规则已写入 `SCENE3D-COMPUTED-PLACEMENT-V3.2.md`，不再以临时墙体或雾效修正。

## 后续执行顺序

1. 对 `red_cottage` 做有限两岔/三岔与战斗入口复核，确认公共段/活动分支顶面只生成一次。
2. 保留 `snow_mirror`、`piper_mountain` 的资产物理标注缺口，交给 Luna 按合同字段补齐。
3. 每景只做一次固定机位 beauty/diagnostic 和有限移动/岔路复核。
4. 新问题追加到本文件；规范无法覆盖的情况停在问题状态，不用临时资产或未批准结构绕过。
