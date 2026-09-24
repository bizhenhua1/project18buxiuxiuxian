# 2D 洞穴资产库与挂接试验

2026-09-23。**已有真实接入与检查，仍未美术验收，不是 Luna 批量生产许可。** 路线接入证据见 [2D 岔路可见性](2D-FORK-VISIBILITY.md)。本轮不改正式场景，不增加洞体模型。

后续事件空间实测、遮挡反例与二维布局修正见 [2D-EVENT-SPACE-TRIAL.md](2D-EVENT-SPACE-TRIAL.md)。

## 源图交付

五张新增图均由内置 image_gen 生成，已复制到 `godot/assets/biomes/crystal/cards-study/`，保留原始 alpha 和像素，每张同目录有 `.prompt.txt`。原始输出路径、文件 hash、尺寸和体积见 `generation-records-20260923.json`，轮廓检查见 `assets.json`。

| 源图 | 用途 | 单图检查与限制 |
|---|---|---|
| `shoulder-left-b.png` | 左肩第二种裂纹/轮廓 | 无画布截断，独立生成，不拿镜像冒充新造型 |
| `shoulder-right-b.png` | 右肩第二种造型 | 同上，地脚按实际下部有效像素计算 |
| `backing-b.png` | 大面积侧向填充变化 | 无画布截断，不能独自承担主拱轮廓 |
| `crown-c.png` | 连续凹弧顶部变化 | 中央下缘高于两侧，不透明核心厚度进入间距预算 |
| `stalactite-a.png` | 稀疏顶面附属物 | 有完整承接帽，不能作为高密度补顶图 |

主要结构角色从单图增加为两图。组合共用 11 个活跃源图（含原有地脚、门口窄岩），不是 11 个已经验收的美术类别。五张新增 PNG 合计约 9.38 MB；按 RGBA8 和完整 mip 链估算约 41.94 MB。这是未压缩纹理的理论增量，不是实测显存或包体承诺。

原有 `crystal/prop-0/2/3` 已单独查看：低分辨率且少量画布边缘接触，本轮没有直接放大作近景填充。矿车和矿箱也没有因为同属一个目录就塞进天然洞穴。

## 变体分配：先看同屏关系

实现：`tools/cave_card_variants.py`，由编译器的 `--source-variants` 调用。

1. 在固定线路与镜头集合中，用原结构的 alpha 射线第一命中计算各实例真正露出的面积。
2. 同属一个素材组且同屏可见的实例两两建立关系，以较小可见面积累计权重。0.3% 是研究观察线，不是美术合格线。
3. 优先给强冲突实例分配不同源图，再做至多四轮局部调整；结果不如固定随机基线时保留基线，禁止无限重掷。
4. 将结果写入世界数据。运行时不随相机换图、不改源图比例、不逐帧寻优。
5. 新轮廓可能改变遮挡，因此分配后必须重查实际 alpha 组合和角色轨迹。

`cards-fork-3way-covisible-01`：69 个观察机位、940 个可分配实例、2927 条关系。加权冲突从固定随机的约 0.4921 降至 0.3896（约 20.8%）。仍有 1364 条同源关系，不能称为重复已消失。

权重来自替换前轮廓，**不能宣称最终画面的可感重复降低了 20.8%**。算法不理解安静材质与高辨识造型的艺术区别。诊断图里的长直通道仍有明显连续层叠节奏；下一步要结合视线遮挡、局部宽窄/边界凹凸和事件区域处理，不能继续只靠增图、加密或压暗。

## 悬挂组和根节点

实现：`tools/cave_card_dressing.py`，开启 `--hanging`。

- 选择已有主冠为父件，用父图指定横向列的实际 alpha 下缘定位，不猜统一天花板高度。
- 子图挂接点必须处于不透明承接帽，透明则拒绝。画布上缘不能当吊点。
- 沿承接帽取九个横向样本，查询父图下缘，计算最小整体上移量使帽沿进入父面；不弯折图片。当前十件装饰最大额外上移约 2.6cm。
- 运行时继承父件的地形支撑位置，不再次采子件脚下地面。`support_kind=ceiling_attachment` 与落地物明确分开。
- 12m 组距是本轮稀疏节奏试验值，不是全类型通用标准；每组只找一件可承接的主冠，缺父件则空缺，不放悬空物。当前共十件，不改紧凑岔口区。
- 尖端最低 2.10m 是此队长尺度下的试验约束，仍需实际身体包络复核；高角色、武器扫掠和战斗区域须重算。
- 没有增加动态点光源。发光点缀仍须是独立稀疏资产，不得重新画进高频岩片。

## 证据与复现

输出根目录：`scene-production/jobs/cave-c1-benchmark/algorithm-lab/`。

| 数据 / 实际游戏捕获 | 实际范围 |
|---|---|
| `cards-fork-3way-variants-01` / `game-card-fork-left-variants-01` | 初始固定随机两图库；左路通过，保留作分配对照 |
| `cards-fork-3way-covisible-01` / `game-card-fork-left-covisible-01` | 同屏关系分配，离线全机位与实际左路检查通过 |
| `cards-fork-3way-dressing-seated-01` / `game-card-fork-left-dressing-01` | 挂接组合；1479 个平面实例、11 源图；离线检查与实际左路 15 机位、149 根轨迹样本通过 |

```text
F:/python/python.exe tools/inspect_cave_card_sources.py
F:/python/python.exe tools/cave_card_junction.py --exits 3 --portal-preview --source-variants --hanging --out <新编译目录>
F:/python/python.exe tools/run_cave_cards_study.py --godot <Godot console> --spec <新目录/fork.json> --branch=-1 --out <新捕获目录>
```

新增组合尚未重跑实际中路、右路与两岔，不得挪用上一轮基础素材五路通过结果。自然门口分隔、远端内容、地面点缀、事件战斗、重复岔路/存档、导出和完整帧时间仍未完成。洞穴完整通过后再处理室内标杆。
