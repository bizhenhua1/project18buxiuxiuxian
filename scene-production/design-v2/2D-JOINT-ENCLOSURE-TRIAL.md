# C1：2D 洞肩、顶层、外侧补片的联合装配

2026-09-23。接续 [顶部覆盖试验](2D-COVERAGE-ROLE-TRIAL.md)。**仍是研究记录，不是完成验收的洞穴标杆，也不能交 Luna 批量生产。** 全部新外观由真实 PNG 固定平面组成，没有新增洞穴结构模型，正式森林和正式场景未启用本试验。

## 已证实的问题与改动

旧方案的主洞肩被更靠近镜头的填充图遮掉了。`side-profile-04` 的实际图 5 中，左右洞肩只占所采样场景像素约 6.2%，旧左右填充占约 69.3%。这里的分母不含天空、地面、角色；不是整张画面的占比。给洞肩增加细节或增加数量，不能直接解决这个遮挡关系。

还存在两种不同连接：洞肩的裁切上端应藏在顶部后面；顶部两侧的裁切边应藏在外侧岩体后面。分别调高某一个部件并不保证两种连接同时成立。例如 `side-profile-04` 左右上端压力采样都通过，但顶图仍有 5479 个边缘样本露出。该版本没有通过联合连接条件。

这次将独立的纵深序列改成装配组。图像尺寸、人物路线和相机保持固定规则；利用各图片的真实透明轮廓决定横向位置，外侧补片必须和自己负责的洞肩/顶部保持固定前后关系。未采用摄像机跟随遮罩，也没有新增连续几何侧墙。

## 候选资产与准入

- `shoulder-left-covered-c.png`、`shoulder-right-covered-c.png`：分别绘制的洞肩，1024×1536。底部有可测落地轮廓，顶部画面延续到图边，向洞内一侧为连续内凹曲线。右侧不是左侧镜像。
- `roof-coverage-a.png`：1774×887，顶部和两侧延续到图边，下缘为洞腔轮廓。继承上一轮候选，不把它当独立完整岩块。
- `backing-quiet-c.png` 与 `backing-geology-e.png`：对照用外侧补片。前者纹理太像大块平板；后者内部岩纹更接近洞肩，仍不足以证明整个资产库丰富。
- `scree-a.png`：既有碎石脚边。跟随父资产的实体脚部范围生成，实际刚性贴地，不能独立随摄像机移动。

新洞肩原始输出、完整提示词、输入图、文件哈希均记录于 `godot/assets/biomes/crystal/cards-study/generation-records-covered-shoulder-20260923.json`。内置 image_gen 生成，没有代码像素加工。`assets.json` 仍将它们标为候选；测量通过不等于审美批准。

编译器现在拒绝：左右角色接反、资产没有测量记录、测量后图片文件发生变化、缺少地面承重点。新增图必须先检查图片本体，再运行 `inspect_cave_card_sources.py` 更新登记，不能只用相同文件尺寸冒充可替换件。

## 联合装配算法（本次局部试验）

代码：`tools/compile_cave_side_profile.py`。只替换左分支中父结构深度 ≥51 米的组及其附属装饰；装饰在父结构前 12 厘米，因此区域边界按父组归属计算，而非按装饰像素/原点机械截断。其他分支、早期父组、路线数据保持原样。

1. 删除该区域旧的主洞肩、旧独立拱顶、局部桥接组，以及不再使用的独立左右填充；子件随父件删除。
2. 从上一轮顶部覆盖序列中保留每隔一组的顶层，保留其源比例、中央净高和世界坐标。这轮保留 26 个顶层，间距由原序列决定，不是把 `3.1 米` 同时误作组距。
3. 左右洞肩置于对应顶层之后 0.08 米。按源比例设置图片高度（本轮基值 5.2 米，加既有地质缓变），**这是延伸到遮挡后方的图片高度，并不代表洞顶净高**。
4. 在源 alpha 中量出距地面 -0.05～2 米高度带内向通道伸得最远的实体像素，让它处于路径半宽之外 0.15 米。不能用透明画布边或图片中心来代表通道边界。实际地形放置仍由原生地面三角面求支撑。
5. 外侧补片除覆盖洞肩外缘外，还负责遮住顶图的纵向裁切边：深度置于顶层前 0.04 米；内缘在顶图外缘内留 0.35 米覆盖余量，且不抢占主洞腔；图片高度至少覆盖顶图上缘并留 0.4 米研究余量。使用完整源宽高比，不能只拉宽。
6. 为每个落地成员重新生成脚边碎石。成员按所属分支显示，保留原先的选路遮挡/退休机制。
7. 原生放置后，同时检查三种裁切边、漏空、角色占位、角色构图；然后看正式灯雾与明亮诊断图。**0.08/0.04/0.35/0.4 等仅是这一组图片的试验参数，未批准为所有场景的常量。**

实际岩体脚部原生查询工具：`godot/tests/measure_cave_ground_placements.gd`。`fit_cave_shoulder_connection.py` 的旧左肩单项拟合只可用于查因，不能作为当前联合装配通过的证明。它曾在记录机位高度 4.8 米通过，但独立中间机位仍失败；不得重新退回单项通过的判据。

## 留存的对照结果

目录统一位于 `scene-production/jobs/cave-c1-benchmark/algorithm-lab/`，配置前缀 `cards-`，原生证据前缀 `game-card-`。所有渲染均为相同 13 个原生机位，未改相机迁就资产。

| 后缀 | 改动 / 结论 |
|---|---|
| `side-profile-01` | 旧肩、填充外移；肩部更可见，但原资产呈横向石臂，且新增漏空，拒绝 |
| `side-profile-02` | 新左肩 4.4 米；顶部硬切，拒绝 |
| `side-profile-03` | 左肩 4.8 米且和顶层配深度；左肩记录机位通过、压力位置失败，顶图也失败 |
| `side-profile-04` | 左右新肩 5.2 米；左右上端检查通过、顶边压力检查失败；填充仍淹没洞肩 |
| `side-coverage-01` | 洞肩直接承担侧面覆盖，移除原独立填充；洞腔曲线更明确，外缘却出现大缝，拒绝 |
| `side-coverage-02` | 洞肩外缘增加成组补片；画面边界漏空消失，顶图裁边仍可见；实例 2277 |
| `side-coverage-03` | 结构组减半；实例降至 2052，顶部角落出现缺口，拒绝 |
| `side-coverage-04` | 相同数量，补片同时承担顶图外缘遮挡；13 机位和 180 个中间压力机位中，左右肩与顶图裁边均零暴露。仍有已存在的远端背景，未整体验收 |
| `side-coverage-05` | 同一组装规则替换已检查的 `backing-geology-e.png`；相对 04 无新增背景，13 机位三种裁边均零暴露，180 个中间压力机位也零暴露。正式图侧面大石板感减弱，但仍有重复与缺少局部特色的问题 |

最新 `05` 是当前继续研究的候选，**不是用户测试交付版**。实际已查看 5 号正式图；04 的 5 号正式图、8 号诊断图也已逐图查看。新增 `joint-independent-holdout.json` 记录另一组插值比例 0.11/0.37/0.69/0.91 的联合检查：顶图、左肩、右肩均零暴露。该结果来自另外一次计算，不由此前通过推定。

`05` 行进 378 个角色圆柱包络样本零相交，角色构图最大偏差约 3.53% 画宽，和之前固定路线相同。背景最多 3585 像素，无画框边界连通；背景分量目前集中在远端开口附近，但后继未接续，不能标记“整个洞已经不漏空”。

2052 是整套三分支试验图片实例数，不能当成当前屏幕可见数。原生记录绘制调用范围 160～351（包含原游戏内容）；这不证明 FPS 改善。本轮只证明结构组能在图片数减少的情况下满足局部连接约束。仍需完整帧和代表性战斗负载性能验收。

## 复现入口

从仓库根运行；输出目录必须是新目录，工具拒绝覆盖证据。

```powershell
F:/python/python.exe tools/compile_cave_side_profile.py --spec scene-production/jobs/cave-c1-benchmark/algorithm-lab/cards-roof-coverage-03/fork.json --out <新配置目录> --left-asset godot/assets/biomes/crystal/cards-study/shoulder-left-covered-c.png --right-asset godot/assets/biomes/crystal/cards-study/shoulder-right-covered-c.png --covered-height 5.2 --align-covered-roof --coverage-shoulders --paired-backfill --coverage-stride 2 --cover-roof-edges --backfill-asset godot/assets/biomes/crystal/cards-study/backing-geology-e.png
F:/python/python.exe tools/run_cave_cards_study.py --godot <Godot控制台程序路径> --spec <新配置目录/fork.json> --branch=-1 --visual-sweep --background-reference scene-production/jobs/cave-c1-benchmark/algorithm-lab/game-card-side-coverage-04 --out <新原生输出目录>
F:/python/python.exe tools/audit_cave_continuation_edges.py --run <新原生输出目录>
F:/python/python.exe tools/audit_cave_continuation_edges.py --run <新原生输出目录> --source-suffix /shoulder-left-covered-c.png
F:/python/python.exe tools/audit_cave_continuation_edges.py --run <新原生输出目录> --source-suffix /shoulder-right-covered-c.png
F:/python/python.exe tools/test_cave_side_profile.py
```

三种边缘检查还要分别追加 `--camera-holdout`。不能只执行顶图的默认检查，就声称整组通过。该采样是合成插值/5厘米压力位置，不是连续运动证明。5 项合同测试涵盖组外保护、左右/补片完整性、原图比例/方向、错误资产角色拒绝、不完整组拒绝。

历史配置有旧元数据字段 `new_shoulders_and_foot_dressing`，其中也包括补片；新编译器已更名为 `new_members_and_foot_dressing`，并分列肩/补片数量。历史实机证据未重写。成组模式不使用独立侧面节拍/外移参数，新元数据将这些标为 null 并记录实际深度间距。

## 尚未解决 / 下一步必须继承

1. **当前外侧补片占所采样场景像素仍约 43%～51%，它不能被当作低质量、不会被看到的后台图。** 资产风格/岩块尺度必须按近景主资产对待。05 洞肩占约 17%～21%，比先前稳定，但这只是可见性证据，不是审美配额。
2. 源轮廓仍很少，顶层和岩脚可辨认重复。后续变体必须按实际视野中重复身份和物理岩纹尺度制定，不能为了达到数量随便生成，也不能仅镜像旧图。
3. 只改了左路后半段，不能据此宣布初始通道、岔口选择、右路、中路、双岔以及事件战场也已改善。推广时必须与入口净空/战斗区准备一起编译。
4. 远端开口尚未接后继通道，完整连续循环未完成；不能用永久封口或浓雾冒充完成。
5. 全路连续运动、完整性能、完整导出、室内样例尚未完成。正式场景仍保持原状。
6. **本轮阶段是取得可重复的局部 2D 连接解。整体艺术效果仍未接受，不能让用户负责排查这些已知缺陷。**
