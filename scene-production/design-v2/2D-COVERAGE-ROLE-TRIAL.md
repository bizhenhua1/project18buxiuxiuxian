# 二维覆盖资产与轮廓资产：已执行的局部对照

2026-09-23。接续 [局部顶岩拼组](2D-FORMATION-GROUP-TRIAL.md)。**洞穴整体未验收，室内未开始；本文件只冻结本轮实验事实和拒绝条件。** 正式森林、正式场景及战斗逻辑未改。

## 为什么改变下一步

`tools/measure_cave_layers.py` 用真实贴地后的图片位置和记录镜头，对可见景物作射线归属统计。对 `game-card-bridge-local-01` 的 3、4、5、8 号镜头，左右和顶部填充占景物采样面积约 91.5%、92.6%、96.5%、98.4%。这不是全画幅比例，分母不含地面、天空和角色；也不计雾和纹理对比。它说明填充图实际上主导了画面，不能继续把它当作不重要的背景素材。

## 两项分开的对照

### 侧面材质对照：不能解决层片排队

内置 image_gen 生成 `godot/assets/biomes/crystal/cards-study/backing-geology-e.png`。保持原尺寸 1024×1536，以混合尺度岩纹替换大块平板图案。完整提示词和输入/原输出/hash 在同目录 `.prompt.txt` 和 `generation-records-geology-fill-20260923.json`。没有后期代码修改像素。

`cards-geology-fill-01` 只替换左路 51 米之后 111 张侧填充，数量、尺寸及排布不变。查看实际 4 号诊断和 5 号正式图后，内部岩纹丰富了，但重复板层仍明显。源轮廓也变了：相对旧图新增 16,910 个不透明像素、丢失 37,529 个。实机最多新增 39 个背景像素，局部桥接 3 个端部采样暴露。因此 **不接受为可以直接换图的生产版本**；保持同分辨率和相近外形不代表可以继承原拼接检查。

### 顶部覆盖对照：局部有改善，不等于整洞成立

原 `outer-crown` 每层约 0.65 米，使用的是四周透明的完整拱石。它既要表达岩石轮廓又要封闭视野，导致密集横纹。`cards-roof-stride2-01` 只删去一半这类层，保持所有原画及其余位置：13 个实际镜头中最多新增 913 个背景像素，并有 3 个边界连通分量，拒绝。没有继续盲目减到三分之一。

随后生成独立用途的 `roof-coverage-a.png`：上面及两侧是延续到画布边缘的实心岩面，仅下缘为天然的内凹轮廓。第一次输出中央实心带只有约四成高度，不符覆盖用途；只针对这一点重做，当前候选为 1774×887，比例 2:1。原始两次输出、提示词、hash 见同目录 `generation-records-roof-coverage-20260923.json` 和 `.prompt.txt`。

**这类资产不是独立完整石块。** 允许画面内容延伸到上/左/右图边，但这三条裁切边必须在镜头外或被其他岩体遮住；只查漏空不足以证明不会硬切。下缘则是需要在场景中自然显露的轮廓。`inspect_cave_card_sources.py` 已将它登记为 `overhead_coverage`，与 `concave_crown` 区分，仍标记 `candidate_not_approved`。

## 编译与拒绝工具

`tools/compile_cave_roof_cadence.py` 是有边界的研究对照，当前只作用左路 51 米之后，保留局部桥接组。固定路线和镜头，不改变角色构图、不引入结构模型。它不是已经批准的通用撒布器。

1. 保留每隔一层的顶部填充，删除 51 张，场景图片实例从 2184 降为 2133。
2. 根据新 PNG 的真实宽高比同时调整宽高，禁止横向拉伸。
3. 从 alpha 读取新旧图中央下缘比例 `v`，固定 `clearance = y + (1-v)*height`，用 `new_y = clearance-(1-new_v)*new_height` 保持中央净高。地形仍由原生放置器处理。这里保留净高是控制变量，不是认可旧洞高。
4. 用实机记录的位置、镜头检查裁切边，选择限定范围内的等比覆盖尺寸，不改相机来遮错。

`tools/audit_cave_continuation_edges.py` 对上、左、右每条图边采样，读取 alpha，投到实际机位，并在整个选中分支的二维图片里检查最近遮挡者。若裁切边自己的图片仍为最前方，就登记为暴露。它独立于背景缺口检查，可以拦住“没有漏天空，但是出现矩形硬切”的候选。

可追加镜头之间的插值和横向/高度各 5 厘米的压力采样。**这些是合成验证位置，不是实机捕获、不更改正式镜头权限，也不是连续数学证明。** 图边的可见几何检查不等于纹理接缝的审美判断。

## 对照结果

输出根目录：`scene-production/jobs/cave-c1-benchmark/algorithm-lab/`。

| 配置 / 实机目录后缀 | 结果与判断 |
|---|---|
| `roof-stride2-01` | 原图直接减半，漏空增多，拒绝 |
| `roof-coverage-01` | 新顶部填充、原宽度；重复横纹减弱，但新增 102 个背景像素，691 个裁切边采样可见，拒绝 |
| `roof-coverage-02` | 等比 1.25 倍，中央净高不变；13 个实机镜头无新增背景，记录机位裁切边为零；135 个中间/压力位置出现 35 个暴露采样，拒绝作为稳定结果 |
| `roof-coverage-03` | 等比 1.30 倍，中央净高不变；上述反例纳入拟合域后再实机捕获。13 个实机镜头无新增背景，裁切边采样为零。另用不同插值比例 0.17/0.41/0.73/0.94 的 180 个位置检查，裁切边采样为零。局部覆盖条件有进展，整体美术仍未接受 |

最后两项不是在原图上扩大 X：PNG 原比例完整保留。1.30 是本次图片与镜头域算出的研究值，不是所有场景或图片的默认缩放。额外顶部 PNG 约 2.42 MB；图层减少不能直接推出 FPS 更高，本轮没有完成全帧性能比较。

实机 `game-card-roof-coverage-03` 的行进角色包络：378 个样本、零相交；构图相对已记录基准最大偏差约 3.53% 画宽，与这轮改动前相同。整体仍有最多 1559 个已存在背景像素，主要涉及尚未接续的远端，未逐个批准。**零新增背景不是整个洞穴已经不漏空。**

## 复现

```powershell
F:/python/python.exe tools/compile_cave_roof_cadence.py --spec scene-production/jobs/cave-c1-benchmark/algorithm-lab/cards-bridge-local-01/fork.json --out <新的配置目录> --stride 2 --coverage-asset godot/assets/biomes/crystal/cards-study/roof-coverage-a.png --coverage-scale 1.3
F:/python/python.exe tools/run_cave_cards_study.py --godot <Godot console 路径> --spec <新的配置目录/fork.json> --branch=-1 --visual-sweep --background-reference scene-production/jobs/cave-c1-benchmark/algorithm-lab/game-card-bridge-local-01 --out <新的实机输出目录>
F:/python/python.exe tools/audit_cave_continuation_edges.py --run <新的实机输出目录>
F:/python/python.exe tools/audit_cave_continuation_edges.py --run <新的实机输出目录> --camera-holdout --holdout-phases 0.17 0.41 0.73 0.94
```

## 下一步及交付边界

正式光照下顶上横向套圈有所减弱，已经查看 03 的 5 号正式图及 02 的 8 号诊断图。但两侧仍是重复板层，洞腔形状仍过于依赖填充矩形，主岩肩没有稳定塑造圆形趋势；不能把本次覆盖解当成最终美术解。

下一步应利用可见面积归属，约束主岩肩在镜头中的实际表现及其与填充的承接。不能再次只按世界距离安排主件、让它们被填充淹没，也不能把全部填充随意换成新图。先完成这一条洞穴的主轮廓，再验证整个行进/岔路/事件/后继循环。

洞穴整体、其他分支与门、连续后继、完整性能与导出、室内标杆、最终可交 Luna 的工作流仍未完成。


后续实际装配对照与剩余问题见 [2D 联合包围试验](2D-JOINT-ENCLOSURE-TRIAL.md)。原记录为阶段证据，不据此覆盖最新状态。
