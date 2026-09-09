# 提灯调查员 · 三维角色原型

保留现有主角的黑发、墨绿长外套、短披肩、黄铜配件和提灯，制作成 5.5 头身的原创低模角色。重点验证大轮廓、骨骼动作和游戏导入；当前采用简化色块材质，面部、发型和衣料属于原型表现，并非最终手绘贴图成品。

## 直接查看

在项目根目录双击 **启动3D主角预览.cmd**。拖动鼠标旋转，滚轮缩放，下方按钮选择动作，也能暂停、自动转台。独立预览已接入 Godot；当前没有替换正式战斗中的二维角色。

双击 **打开主角Blender.cmd** 可编辑源模型。Blender 中模型和骨架均已保存，动作在 Action Editor 中按名称选择。

## 文件与规格

- `lantern-investigator.blend`：可编辑网格、骨骼、六段动作及渲染灯光。
- `../../../godot/assets/characters3d/lantern-investigator.glb`：游戏使用的带骨骼与动画模型，不包含展示台、相机及摄影棚灯光。
- `front.png`、`rear.png`、`face.png`：实际模型渲染。
- `game-*.png`：Godot 中的动作截图。
- 模型高度 3.30，头高约 0.60，5.5 头身；3665 个顶点、6601 个三角面、20 根骨骼。
- 待机 Idle、行走 Walk、奔跑 Run、攻击 Attack、受击 Hit、倒下 Defeat。动作以 24 fps 制作，播放时由引擎插值；行走和奔跑为原地循环，由游戏控制位移。
- 衣摆和灯笼有独立骨骼动画。当前不包含面部表情骨骼或布料物理。

## Blender 与 MCP

已安装官方 Blender 4.5.9 LTS 便携版：`C:/Users/admin/.local/share/blender-tools/blender-4.5.9-windows-x64/blender.exe`，并对下载包进行官方 SHA256 校验。

已安装社区 blender-mcp 1.9.1 和 Blender 插件，使用本机 9876 端口，关闭遥测。Codex 的 `blender` MCP 配置已注册，本次建模通过真实 MCP 调用完成。新任务或重启 Codex 后可加载已注册工具；需要 Blender 保持打开、插件服务器启动。若打开多个 Blender，MCP 会连接占用该端口的实例。

官方来源：[Blender 下载目录](https://download.blender.org/release/Blender4.5/)、[Blender MCP 源码](https://github.com/ahujasid/blender-mcp)、[Codex MCP 文档](https://developers.openai.com/codex/mcp)。模型由本项目直接构建，没有使用第三方付费模型生成服务。

## 验证

已验证 GLB 在 Godot 中导入、20 根骨骼完整、六段动画均有实际骨骼运动，并分别渲染检查。此次未执行帧率压力测试。
