# 场景美术复核：以画面而非通过数量验收

> 2026-09-21 校正：后续工作以 [3D生产规范与Luna交接](SCENE3D-PRODUCTION-STANDARD-2026-09-21.md) 为准。本文下方“18景3D撒布审查汇总”使用的最初三张联系表源于9月16日存量截图，撤回其证明最新native 3D效果的表述。七类scatter profile仅为未验收试配，没有解决顶部及岔路共用厅。当前不再调参；资产清单、结构测试与视觉验收分别记录。

用户指出工作偏离资产补充/场景检查后，暂停新增战斗迁移工作。此前生成数量、透明锚点和路线检查通过，不能代替场景质量验收。原美术交付记录只证明那批文件和检查结果，不再作为全部美术质量已经完成的判断。

## 本次实际观察

重新查看 review-20260916 的三张行进联系表：十八场景主体具有主题区分，但多张图仍主要由完整大框景、裸地板和雾组成，中型生活/生产物件不足。问题在长屋、矮人居所、木偶工坊、剧场尤其明显。仅增加小碎屑数量不会解决。

优先补充方向：

- 矮人居所：床铺、储物柜、矿具整备台等中型生活侧景。
- 长屋/工坊/厨房：沿墙工作台、壁炉旁家具、货架等，不以重复完整房间代替道具。
- 集市/游乐场：独立摊架、破车、围栏及入口侧景，降低宽阔地面与稀疏单件的反差。
- 果园/玫瑰园/南瓜庭院：中层灌木、篱边和低矮群落，保留道路可读性。
- 魔镜/钟楼/山口/桥：复核中景围合及岔路侧面，不无条件增加大拱框。

这是一份待解决清单，不是十八场景新一轮验收通过。

## 已落地的第一项

生成 snow_house-bed-alcove-v2：一件透明背景、完整脚点的矮人双层床组合。原图及手写提示词位于 art/fairytales/corridor/raw；运行时图 750×768，位于 godot/assets/fairytales/snow_house/furnishings。furnishings.json 保存显示高度、接地锚点、来源及提示词。

共享布置器新增可选中型家具层，仅存在 furnishings.json 的场景启用。独立随机种子不扰动原装饰布置，左右交替、220–310 世界单位间隔，所有道路至少保留 76 单位加半图宽的净空。只在生成路段时布置，无每帧撒布。

`capture_snow_house_furnishing.gd` 已实机输出 snow-house-furnishing-v2.png 并检查21个家具实例的道路净空。画面中床铺在左右中景可见，没有把新增资产藏在外墙之后；左侧近景截出画框属于自然裁景。整体中景比联系表丰富，但墙体大框重复及岔路建筑拼接仍需继续观察，不以这一个镜头宣布居所精修完成。

## 第二项：储物与矿具整备侧景

新增 snow_house-work-cabinet-v2，为储物柜、矮工作台、矿灯、绳索、煤篮构成的一件中型组合，避免把数件小物件分别撒成杂乱颗粒。生成原图及提示词留在同一 raw 目录，透明运行时图片为 768×657。高度 82，低于床架 105；两种图片共用原中型家具实例预算，不增加布置频率。

实机复核了行进 1.25 秒和 2.25 秒两个位置，截图 snow-house-furnishing-v2.png / snow-house-furnishing-v2-forward.png。右侧柜架与左侧床铺可辨认，远近尺寸随场景投影变化，通路未被家具堵住；21 个家具实例包含两种资产，道路净空检查通过。家具底部部分被现有雾和墙边物件遮挡，不能将此检查扩大宣称为所有角度都无穿插。

当前仍明显可见：岔路远处的完整屋架组合像两排重复大拱框，低层过渡偏少。下一项应处理侧墙/独立支柱与中层物件的关系，保持现有镜头，不靠继续堆同一套完整屋架解决。

## 第三项：岔路木柱与矮墙

新增独立木柱、斜撑、石砌矮墙组合 branch-side.png，656×1016。首两次生成残留棕色背景雾边，已留档并弃用；最终使用纯品红背景版本机械去色，保留物件与内部镂空，原图和各步提示词均在 raw 目录。安装脚本 install_snow_house_branch.py。

仅 snow_house 开启 junction_side_radius=700；岔路附近使用独立侧模块代替跨路完整屋架，沿用全道路净空检查，其他主题参数不变。实机从起步走到两岔选择再左转两秒，完成 capture_snow_house_furnishing 用例，截图 snow-house-branch-junction.png / snow-house-branch-left.png。左转后独立柱墙形成清晰侧边，柜架在柱墙前可见，镂空没有棕色背景矩形。远处仍保留完整屋架形成终端围合；选路前远处双拱轮廓仍存在，不能声称所有建筑组合问题均解决。

## 第四项：外婆长屋的石砌壁炉侧景

生成 red_cottage-hearth-v2，组合石砌炉体、陶罐架、暗红布料与柴薪，主题和矮人矿具家具区分。原图/提示词留档；运行时 768×755，显示高度 115，300–410 单位稀疏间隔，独立 furniture 清单接入。不加火焰/光源，不改当前环境灯光和镜头。

通用安装工具 install_medium_furnishing.py 仅更新指定场景指定资产的条目，测量透明边界并保留8像素空边。capture_snow_house_furnishing.gd 现支持场景参数；red_cottage 实机生成15个实例，通过全道路净空检查，输出进入、前进、岔路、左转四张截图。已查看前进和左转，炉体在两侧可辨认、保持道路通畅，近处有自然画框裁切；雾覆盖部分底脚，接地仍需结合无遮挡位置而非单一远景判断。只有一件中型组合，不能把重复同一壁炉计为侧景多样性完成；后续应补软性家具/储物组合并轮换。

## 第五项：长屋针线与休息侧景

新增 red_cottage-sewing-corner-v2（衣柜、旧摇椅、针线篮与小边桌），原图和提示词留档，运行时727×768，高度108。与壁炉共用15个既有中型摆放位置，未提高密度。显著高低错落的木质轮廓替代部分石砌壁炉，保持暗红布料线索。

重新捕获该场景四个行进/岔路视角，清单中的两种家具都实际出现，道路净空检查通过；左转图右侧可见衣柜与摇椅，背后仍为原长屋墙板。家具靠墙且未横挡通路。原主框架仍有重复、画面顶部空缺问题，本项仅完成中型家具变体补充，不宣称长屋总体已验收。下一批转向木偶工坊/剧场的制作与存放类中型物件，避免继续只磨同一个房间。

## 第六项：剧场布景运输车（生成与实机检查）

使用内置图像生成新增 puppet_theatre-scenery-cart-v2：旧月亮/小屋木质布景板、轮车、服装箱和幕布组成单件中型侧景。原图和完整提示词保存在 art/fairytales/corridor/raw 同名 png / prompt.txt；运行时 godot/assets/fairytales/puppet_theatre/furnishings/scenery-cart-v2.png，737×768，高度120，透明脚点，沿用300–410间隔，无新光源或每帧布置开销。

Godot导入完成；capture_snow_house_furnishing.gd -- puppet_theatre 实机生成15处，全部通过全道路净空检查。四张截图位于 tempassets/work/puppet_theatre-{furnishing-v2,furnishing-v2-forward,branch-junction,branch-left}.png；已实际查看forward和left。新增月亮布景车在两侧可辨，底轮有自然接地轮廓，未横堵道路。中远景部分被原雾与舞台柱遮挡。

视觉结论仍为未验收：重复完整舞台框是主要围合，岔路连成两个舞台口，顶部仍有空背景；只增加一件道具车没有解决这些问题。下一步需要独立幕柱/侧翼布景，以及较低的座椅或道具收纳侧景，而非堆更多同一种整幅舞台框。

同轮工坊雕刻台生成被服务端输出审核拦截（request ID 320c8144-9fb4-4cf9-a46a-6f7782e22344），没有输出文件、没有接入、没有计入完成；原提示词保留，后续工坊仍待补充。不影响剧场独立资产工作。

## 第七项：剧场岔路独立幕柱

新增 curtain-pier-v3-key，内置图像生成，原图/提示词在 raw 同名文件。前两次输出有棕红背景晕边，均留档且未接入；最终纯品红版经机械去色导出 branch-side.png（388×1016），脚点完整，高度220，junction_side_radius=700。install_puppet_theatre_branch.py 可重现导出。复用既有侧模块布置，不修改摄像机或战斗代码。

重新运行剧场行进/两岔/左转捕获，进程正常结束，15件家具道路净空检查通过；实际查看新的 puppet_theatre-branch-left.png，近中景已从连续完整舞台框变为独立幕柱两侧通道，底部布帘有落地轮廓，无背景晕边矩形。远端仍保留完整舞台作终端围合。

仍未通过整体视觉验收：移除横跨路口的大框后，顶部及左侧空背景更明显；需要连续侧翼/后台墙面填补，而不是降低相机或把空处涂黑掩盖。当前单幅截图也不足证明所有接地角度无误。新增幕柱替换导致本捕获sprite数529→544，后续侧翼应替换既有实例或控制间隔，避免仅叠加增加层数。

## 当前无生图条件下的运行审计

图像生成额度暂时不可用，本轮跳过新图片生成，先完成代码和运行审计。新增 `godot/tests/audit_fairytale_travel_visual.gd`，逐一实例化18个主题场景并执行一次真实 route tick，停止在战斗前，检查实际走廊生成、装饰资源接入、家具道路净空、世界格子主题/资源引用，并断言 native 3D route view 节点真实创建。2026-09-20 运行通过：`TRAVEL_ART_AUDIT_PASS count=18`，日志为 `tempassets/work/fairytale-travel-audit-20260920-native.log`，机器报告为 `tempassets/work/fairytale-travel-audit/report.json`。18景均有 corridor 资产和9种 dressing 变体；目前家具变体实际启用为 red_cottage 2、snow_house 2、puppet_theatre 1，其余场景为0，不能把“9种 dressing”误报成中型侧景已齐全。

该审计还在每个实例化前清除 `native_route_view`，随后断言 `endless_forest.gd` 重新启用它。因此后续其他主体场景的接入必须继续经过 `scripts/journey/expedition_route.gd` 的最新 `world3d/route_view.gd`、统一投影、接地和镜头路径；不得新增旧版独立摄像机或传统坐标换算。该断言只证明路由选择正确，不替代截图级的构图、遮挡和材质验收。

当前仍未验收的美术项：除已有三套中型家具场景外，剩余主题需要独立中景/岔路侧景；完整大框在多个主题的岔路仍可能重复，地面接缝数值报告需要结合同机位画面判断，不能只按 `analyze_fairytale_scene_standard.py` 的原始边缘差异直接判定。

## 批处理渲染修复与复测

18 景审计首次运行暴露 `ForestBatch` 的白色描边通道直接复制运行中 `MultiMesh`，Godot 在首个主题绘制时报 `Cannot set a buffer on a Multimesh that is a different size from the Multimesh's existing buffer`。已改为创建同拓扑但全新缓冲的 `MultiMeshInstance2D`，不改变材质、投影或实例预算。修复后重新运行 `audit_fairytale_travel_visual.gd`，18 景均通过，且不再出现该缓冲错误；`test_fairytale_corridor_frames.gd` 也通过 `CORRIDOR_FRAME_PASS layouts=144`。

这项修复属于所有主体场景共用的批处理基础，不是单独给某个主题打补丁。后续主体场景接入仍须使用最新 native 3D route view 的投影、接地和镜头路径，并经过同一套审计。

`build_fairytale_dressing_metadata.py` 也已重新运行，确认18景共162个已提取装饰资源的运行元数据完整。当前无需新图即可完成的代码、元数据、路线净空和 native 3D 路径审计已收口；剩余工作是新中型/岔路图像资产以及依赖这些图片的截图级视觉验收。

## 连续主题路段审计（2026-09-20）

为避免只验证第一段场景，新增 `godot/tests/audit_world3d_fairytale_streaming.gd`。它对18个童话主题分别构造当前路段和一次实际 successor：检查岔路选择后 successor 从上一段 `end_s` 无缝接续、2/3岔出口仍有效、旋转后的装饰坐标和生物群系灯光保持一致、所有纹理与位置数值有效，并确认 `ForestRoute` 的临时兼容上下文在每段生成后恢复。测试不创建渲染节点或等待帧，只验证运行时使用的 `world3d/successor_world.gd` 结构，因此不会把旧版 2D 坐标换算误当成通过。

运行结果：`WORLD3D_FAIRYTALE_STREAM_PASS count=18`；明细在 `tempassets/work/world3d-fairytale-stream-audit.json`，日志在 `tempassets/work/world3d-fairytale-stream-audit-20260920.log`。这项结果证明18个主题已经可以沿最新 native 3D 路由继续生成，并不替代缺失图片资产的截图级美术验收，也不等于长时间 GPU 生命周期/性能已经完成。

本轮还通过了 `forest_batch.gd` 与 `fairytale_corridor.gd` 的 Godot `--check-only` 解析检查，以及 `git diff --check`。未引入战斗逻辑或旧版网页 demo 的改动。

## 18 景 3D 撒布审查汇总（2026-09-20）

已将现有 18 景 native 3D 跑图、战斗和世界截图按同一缩略图尺寸汇总，供逐景审查：

- `tempassets/work/fairytales/fairytale-3d-travel-contact-sheet.png`
- `tempassets/work/fairytales/fairytale-3d-battle-contact-sheet.png`
- `tempassets/work/fairytales/fairytale-3d-world-contact-sheet.png`

每景原图仍保留在同一目录下的 `<scene>-travel.png`、`<scene>-battle.png`、`<scene>-world.png`。联系表反映当前已接入的 3D 路由和撒布结果，不代表缺失中型资产的视觉验收已经完成。

## 撒布校准改为按空间类型分层（2026-09-20）

此前尝试把室外森林的密度节奏统一套到18景，已立即回滚；这种做法会破坏室内、矿洞、桥、舞台和钟楼的顶部围合与地面留白。现在改为读取 `godot/data/fairytale_scatter_profiles.json`，按照场景数据中的 `space` 分成 `street / interior / garden / bridge / cave / stage / clock` 七类。每类独立控制中低层簇的间隔、成员数量、侧向范围、家具节奏、碎片横向范围和大型物件保留概率；通道主体仍使用每个场景自己的 `corridor.json`，没有改成一套全局重复距离。

结构审计已经通过，18景仍全部生成成功。新的计数用于发现类别差异，而不是直接以数量判定美术通过：室外/花园类会有更多侧边地面层，室内/舞台类保留更大的顶部和墙边留白，矿洞/桥/钟楼使用各自的节奏。下一步必须逐类在同机位截图中复核顶部覆盖、左右中景占比、地面填充和道路净空，再决定是否调整具体 profile；不会再用统一倍率继续加密。
