# 资产存放与 Git 提交

- `godot/assets/`：游戏运行所需模型、贴图、动作和已准备的场景资源，提交到 Git。
- `tools/blender/`：转换脚本和来源清单，提交到 Git。
- `tempassets/`：下载源包、重复包、UE 导出工程、转换临时文件，本地保留，Git 忽略。
- `art/**/*.blend`、Blender 备份、制作日志：本地保留，Git 忽略。需要在另一台机器继续制作时，请另外备份这些源文件。
- `godot/.godot/`：Godot 自动生成的缓存，不提交。

2026-09-09 检查：约 120 MB 的 `art/3d/seer/seer-animated.blend` 未进入提交历史，已排除；当前运行资产不需要为解决此问题引入 Git LFS。未执行提交或推送，未删除源文件。GitHub Desktop 刷新后即可重新选择需要提交的内容。

## 本批角色

角色列表由 `godot/scripts/spaces/character_library.gd` 统一提供，动作浏览器、Shader 浏览器与大世界选择器共用。新增 17 个角色/形态，共 24 项。来源和输出名记录在 `tools/blender/new_character_batch.json`。保留原有列表顺序，避免存档角色编号发生变化。

“盛夏光影 (1)”是重复下载，不重复入库。“Mechanic Collection Part.1”的 Blender 文件仅有分件网格，没有骨架，暂不作为可播放动作的角色加入。古董商目录中的“萧”是附件，不作为角色加入；同一园丁包只采用命名明确的主体版本。

验证：24 个模型均可加载；每个模型映射 57–73 个动作骨骼；左右手挂点可创建，动作采样通过。这不是所有动作下衣摆、头发和武器接触效果的逐帧验收。
