# Epic Toon FX 1.81 资产梳理

2026-09-11，依据本地原包、预制体序列化数据、随包 v1.8 文档与脚本整理。当前完成盘点和拆解，尚未把这些预制体转换成 Godot 动态效果。

## 结论

建议本作下一轮直接改造本包的完整粒子组合。第一组选择 SwordSlashThinWhite + SwordHitYellow；第二组选择 FireballSoft 的发射、飞行、爆裂三个预制体。两组均可保留原设计而避免生成序列帧。

之前项目 godot/assets/fx/epic-toon/source.json 记录的是 **1.4 版的10张基础贴图**，不是完整预制体迁移。仅引用这些图片不能代表 Epic Toon FX 的原始效果。

## 清点结果

| 类型 | 数量 | 说明 |
|---|---:|---|
| 预制体 | 1447 | 包含配色变体、演示用弹道包装、旧版效果，不等于1447种独立设计 |
| PNG | 369 | 包含基础图形、云烟、火焰、图集及演示素材 |
| 材质 | 358 | 包括不同混合模式和预配色 |
| FBX | 21 | 网格粒子、环面、弹体等模型 |
| WAV | 79 | 可作为同步音效候选，尚未逐一听审 |
| 演示场景 | 39 | 原包动态验收入口 |
| C# | 17 | 弹道碰撞、灯光衰减、旋转、音调随机及演示控制 |
| 独立 shader 文件 | 2 | 不代表只依赖两种 shader；还引用 Unity 内置材质 shader |

另有2个动画、2个控制器、说明文件及一个 URP 升级子包。本次统计针对主包，未将升级子包重复计入。

内嵌粒子层共4394层；1325个预制体包含直接序列化的粒子系统。其余可能是引用其他预制体的包装或非粒子对象。

## 分类与本作适用性

| 分类 | 数量 | 本作建议 |
|---|---:|---|
| Combat | 679 | 主力：剑击、物理受击、弹道、法术、护盾、死亡 |
| Environment | 233 | 火焰、烟雾、闪电、水花、天气；按六场景分色 |
| Interactive | 378 | 优先治疗、拾取、传送、区域提示；水果、表情、金币类暂不使用 |
| Prefabs 2D | 23 | 主要针对侧视碰撞/呈现，不因本作使用2D场景就优先选用 |
| Misc | 12 | 按具体用途筛选 |
| Demo 包装 | 122 | 其中115个弹道包装、7个演示对象；不是额外122套独立效果 |

Combat 重点子类：Explosions 163、Missiles 132、Muzzleflash 93、Sword 52、Blood 51、Magic 38、Brawling 28、Death 20、Shield 4。另有爆炸文字/其他、喷火、Nova等。

## 序列帧与随机切片的区别

625个预制体启用了至少一层 Texture Sheet Animation 模块，但这不等于625个都在播放序列动画。检查 frameOverTime 后，274个包含按曲线/时间驱动的切片层；另一些仅在粒子出生时随机选取固定图片。

目录区分“切片层”和“动画切片层”。统计仅针对内嵌组件；演示包装的0层不意味着它引用的子效果没有粒子或切片。

| 候选 | 粒子层 | 切片 / 动画层 | 结构与用途 |
|---|---:|---:|---|
| SwordSlashThinWhite | 3 | 0 / 0 | 两层 Mesh 粒子 + 一层 Billboard，网格 ETFX_CirclePlane2.FBX，贴图 slash01、magic_orb2 |
| SwordSlashThickWhite | 3 | 0 / 0 | 与细剑光同类结构，可用于重劈；先改尺寸与寿命 |
| SwordHitYellow | 5 | 0 / 0 | 拉伸粒子与 Billboard 组合，独立放在目标受击处 |
| MuzzleFireballSoftFire | 2 | 0 / 0 | 施法手部的释放反馈 |
| FireballSoftMissileFire | 4 | 1 / 0 | 静态 fireball2、光晕和粒子运动；云烟2×2随机选图，不逐帧播放 |
| ExplosionFireballSoftFire | 4 | 1 / 0 | 独立爆裂，云烟随机切片；命中后播放 |
| FireballMissileFire | 4 | 2 / 1 | 含动画切片，保留为比较候选 |
| FireballSharpMissileFire | 4 | 2 / 1 | 主火焰含动画切片，暂不作为首选 |

推荐火球完整包装是 Demo/Missile Prefabs/FireballSoft/FireBallSoftFireOBJ.prefab。它通过 ETFXProjectileScript 引用上述三段效果。脚本在弹道命中时生成爆裂，分离名称带 Trail 的粒子，让残留自然消失。这段生命周期应完整保留到 Godot，而不能只搬一张火球图片。

## 改造到本作的顺序

1. 在 Unity 原包 Demo 中确认目标效果的真实动态表现；包内 prefab preview 实际只是蓝色 Unity 图标，不能当成效果截图。
2. 提取候选依赖：原纹理、网格、材质参数、颜色/尺寸/速度曲线、发射时序、层级变换、坐标空间。完整原文件和 meta 已保留。
3. 在 Godot 重建等价的粒子层和控制器。PNG/WAV可复用；FBX转换导出；Unity prefab、C#、Unity shader不能原样运行。URP升级包解决的是 Unity 渲染管线，不解决 Godot 转换。
4. 先匹配原版，再做本作的低饱和配色、收窄尺寸、缩短尾部、减少灯光。不要在尚未还原原版时同时重新设计效果。
5. 剑光绑定角色挥击空间；受击放目标端；火球尾烟在世界空间保留。位移、动作、命中与声音沿同一时间线调度。
6. 统一整体缩放时，额外核对点光源范围、尾迹宽度和音效。随包文档明确指出这些参数不会全部随 Transform 自动缩放。

原包自带多种云烟风格，包括轮廓、软阴影、硬阴影，优先使用这些已有变化来匹配本作。美术上建议选择暗描边/硬阴影，压低外层加色发光，仅保留小面积亮核心。

## 本地交付

- 解包目录：tempassets/vfx/epic-toon-1.81/source/Assets/Epic Toon FX/
- 可搜索目录：tempassets/vfx/epic-toon-1.81/index.html（展示依赖贴图，不伪装成动态预览）
- 完整机器清单：tempassets/vfx/epic-toon-1.81/catalog.json
- 表格：tempassets/vfx/epic-toon-1.81/prefabs.csv
- 可复现工具：tools/audit_epic_toon.py

原 unitypackage 未修改；解包与浏览资料留在已忽略的 tempassets 下，不批量塞入正式运行资源。
