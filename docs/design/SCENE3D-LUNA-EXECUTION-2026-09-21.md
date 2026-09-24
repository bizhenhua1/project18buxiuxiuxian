> **2026-09-21 v3 修订：本文件保留为历史依据，不再是执行入口。** 请从 [3D场景生产规范·唯一入口](SCENE3D-START-HERE.md) 开始。旧文中“已验证中性诊断/深度指标”“顶带生产可用”“必须等用户逐项标注”“源码变化后全量重拍”等结论已被复核或取代；具体见 [逐项裁决](SCENE3D-ISSUE-DECISIONS-V3.md)。本次只完成规范设计，未宣称运行时已修复。

# Luna 执行协议 v2：3D场景生产

这是 `SCENE3D-PRODUCTION-STANDARD-2026-09-21.md` 的执行补充。v1给出事实与方向，本文件固定接口、算法决策、交付顺序、失败处理。仍不把未经截图验证的配置称为标准。任务仅限3D场景；保持现有镜头、战斗、存档和网页demo。禁止开始后一次改18景。

## A. 固定工作方式

一次执行一个工作包。完成后输出：改动文件、输入hash、测试日志、新截图manifest、未解决项。通过依赖门槛才启动下一包。遇到某景缺图时登记缺口，继续其他不依赖该图的工作；不得复制别景图片冒充新资产、放大碎片当家具、通过改相机填空。

P00/P01阶段不生成新图，先锁定基准和证据来源；P01之后如果出现真实资产缺口，允许进入条件式资产生产。可盘点、标注、接入已存在且用途匹配的资产。机器证据和用户审美确认分别记录。视觉有明显缺陷即修复，不必把每次试错都交给用户；只有代表空间达到机器门槛且完成自查后才提交一次审查。

## B. 已作出的实现决策（不留给执行者临时选架构）

1. 3D渲染仍走 `world3d/scenery.gd`。新增布局模块只产出统一世界空间放置数据；不得创建第二套相机/角色投影。
2. 顶部连续面和装饰横截面分开。室内/洞穴的承重拱、梁是装饰层，连续顶壁用低面数连接面；若现有完整壳经整个镜头路径验证已经闭合，可不加冗余面。
3. 顶壁连接面必须使用明确标注可用的顶壁纹理，不从截图、家具或地面随意拉伸取纹理。缺少可用纹理/连接点时输出资产缺口；不可将背景色涂黑视为闭合。
4. 岔路共用厅使用所有路线保护区的并集，一个segment拥有一个厅，分支仅拥有完全分离后的独立结构。空间分离用几何检测，不能固定“走300U后恢复”。
5. 摆放硬实体用脚印；透明开口、冠层悬挑、地面装饰不用整图宽度做相同避让。每个role必须显式声明。
6. 现有七类试配只保留作对照，不继续增改其数字来代替新结构。新增profile置于新namespace并由测试参数显式启用；代表景通过后再切默认。原六基准不改。
7. 新系统数据使用米；适配旧sprite输出时唯一一次乘20。材质与雾仍消费原系统约定单位，不在shader偷偷混用。

## B8. 资产生产门槛（P01之后按需启用）

生图不是用来填满截图的快捷按钮。只有 `asset_request.status=awaiting_asset` 且已证明现有资产在角色、结构、接地或开口语义上无法复用时，才允许创建生成任务。生成任务必须带 `source_prompt_path`、palette_reference、目标场景族、视角和用途；原始生成图不得直接进入运行时，必须经过裁剪、透明边缘清理、尺寸记录和AssetSpec校验。

每个物理场景族的初始生产目标如下，数量是覆盖不同语义和视距的起点，不是把同一张图复制多份：

|层|最低变体数|源图长边|必须覆盖|
|---|---:|---:|---|
|承重结构/墙/拱/顶连接|3套（左、右、转角/端部）|2048px|左右脚印、roof_left/right或wall_top socket、开口比例|
|中型家具/功能组|6种|1024–1536px|墙段、桌柜/桶/工具组、不同朝向，不能占用通道|
|地被/大植被/覆盖物|8种|768–1024px|近中远三档、不同高度和接地点|
|碎屑/小道具|12种|256–512px|至少3个簇组合，避免重复哈希造成棋盘感|
|地标/首景物件|2种以上|2048px|可辨识轮廓、独立材质语义和稳定脚点|

室内/洞穴额外需要一套连续顶壁或洞顶连接资产；只有横截面装饰而没有连续面时，该景保持 `blocked_missing_asset`，不能靠雾、黑色背景或拉伸家具伪装成封顶。数量不足但已覆盖语义时可以先接入，必须在manifest中记录 `coverage_exception`，不得把最低数量写成已满足。

每张生成资产在接入前必须通过：

1. RGBA透明边缘检查；边缘白/黑色晕边占有效轮廓不得超过1%，禁止把原背景当透明边界。
2. 可见主体在1440×900近景至少保留180px高度时，缩放后有效纹理采样宽高各不低于可见像素的2倍；达不到则只能分配到远景层。
3. `anchor_uv`、`footprints_m`、`opening_uv`、`contact`、`sockets_m`全部有值或明确列入缺口；不能用整张图片矩形代替脚印。
4. 方向性纹样、文字和单向灯具不允许镜像；左右结构必须分别核对开口宽高比，不能用均匀缩放改变建筑比例。
5. 颜色和阴影不烘焙成会抵消场景雾光的强方向光；保留环境可控的明暗层次，避免新资产单独发亮。
6. 同一层至少三种来源形态的轮廓差异；通过SHA256和轮廓面积/长宽比检查拒绝仅改色的伪变体。
7. 运行时只复用已有材质/批组；不为每个实例创建独立shader或点光源。近景唯一材质组的数量和纹理内存必须进入P10性能报告。

生成工作包的交付物固定为：生成提示与参考文件、原始图、处理后图、裁剪矩形、AssetSpec、透明/分辨率/轮廓检查日志、接入前后的单景manifest。任何一项缺失，状态保持 `awaiting_asset_review`。

## B9. 没有高拱梁时的顶面决策

“有横截面拱梁”与“空间已经封顶”是两件事。任何室内或洞穴只提供横截面装饰、中心仍能看到背景的情况，都不能被判定为闭合。

按以下顺序选择顶面方案，选择结果写入 `SceneProfile.roof_mode` 和 `roof_source`：

|条件|方案|允许的资产|验收|
|---|---|---|---|
|有左右支撑、顶壁连接点和连续顶壁纹理|`closed_arch`|拱梁装饰 + 低面数连续顶壁|无雾顶视无连续漏空；拱梁只负责边界节奏|
|没有高拱梁，但有墙/地面同源材质且空间需要封闭|`closed_low_ceiling`|沿路径铺设的连续低顶面；顶面使用独立 ceiling 材质或明确批准的地面同源材质；可附吊灯/链条|顶面几何覆盖完整，角色/相机净空大于设计值；不能把地面贴图直接拉成垂直墙面|
|具有不规则岩壁、洞口和环形截面|`cave_shell`|洞穴环形截面、岩壁连接段和洞口过渡资产|沿入口到洞内的截面连续，轮廓不自交，顶视不漏空|
|现有资产只有横截面且没有可用顶面材质|`blocked_missing_asset`|不接入运行时；生成明确的顶面资产请求|只允许展示缺口诊断图，不得靠黑背景、雾或调暗环境通过|

`closed_low_ceiling` 的连续顶面算法与地面同源但不共享实例：沿 route 的中心线自适应采样，按左右保护边界生成四边形带，顶面高度取 `ceiling_height_m`，每段共用边顶点，UV按累计弧长展开。每个主题最多一个顶面材质批组；吊灯和链条标记为 `suspended`，只挂在 ceiling socket，不参与地面脚印避让。低顶面不能通过压低相机或提高雾来隐藏净空错误。

初始净空门槛为：最高角色包围盒顶部到顶面的距离至少 `0.35m`，相机射线到顶面的最近距离至少 `0.20m`；这两个值必须在代表景截图和碰撞诊断中记录，之后才能用基准测量替换。若无法满足，场景保持 `blocked_missing_asset`，不要改角色比例或镜头来迁就。

下水道和洞穴不是因为“有一串环形图片”就天然合格：下水道可以采用规则环形截面，洞穴采用不规则截面，但二者都必须输出连续顶面/侧壁几何、开口 polygon、连接 sockets 和无雾顶视证据。环形资产只能作为截面装饰或壳体输入，不能替代连接面本身。

## C. 接口与数据合同

以下接口是待实施要求，当前代码不存在时不得报告已支持。建议放在 `godot/scripts/world3d/production/`。

### C1. AssetSpec

|字段|类型/约束|来源|
|---|---|---|
|id / texture / sha256|string，id唯一，res路径必须存在|文件清单|
|role|structure / wall / roof / canopy / furnishing / prop / cover / litter / landmark|逐图语义审核，不能只按文件名猜|
|size_m|Vector2，有限正数，宽高比与有效图像一致|基准尺寸或已接受家具尺寸；记录来源|
|anchor_uv|Vector2，裁剪后UV，0–1|标注真实脚点或吊点|
|footprints_m|Array[凸多边形]，局部XZ米，允许多脚|实际实体支持区；壳左右脚分开|
|opening_uv|Array[多边形]|门洞/岩洞透明可通行区域|
|contact|rigid_feet / conform_base / ground_surface / suspended|按用途指定|
|sockets_m|具名Vector3数组|roof_left/right、wall_top等连接位置|
|variant_family / mirror_allowed|string / bool|图案对称性，文字或单向灯具禁止镜像|
|height_band_m|Vector2|悬挑/吊挂最低高度与最高高度|
|status|unannotated / annotated / reviewed / rejected|缺字段不得自动升为reviewed|

禁止为缺少脚印的主结构填“零面积”绕开验证。已有metadata能确认的字段自动迁移，其余留null并列入缺口。原图与裁剪图坐标换算：`u'=(u*W-crop_x)/crop_w`，v同理；保留原尺寸/crop_rect。

### C2. SceneProfile

字段固定：scene_id、physical_family、baseline_id、baseline_revision、roof_mode(open/closed/local/entrance_to_closed)、layer_rules、battle_clearance_source、asset_ids、junction_rules、seed_version、limits、status。

每条layer_rule包含候选步长、簇成员范围、权重、放置带、最小间隔、允许role、避让类别、预算。任何数值必须带 `source`（基准测量文件+字段，或已批准设计值）。禁止无来源“提高到1.7”。

parent故事字段不参与选择布局。每景只有一个主空间基准；如有辅助基准，必须明确仅借用哪一层，禁止平均两个基准的密度。

### C3. PlacementRecord

字段：stable_id、segment_id、scene_id、layer、asset_id、route_s_m、branch、position_m、yaw_rad、scale、contact、footprints_world、owner_region、generation_reason。标识由seed/segment/layer/cluster/member组合产生，不使用当前数组下标作为持久ID。

输出旧sprite适配：`position=(x,-z)*20`、`w/h=size_m*20`、`altitude=height_above_ground_m*20`、`ground_anchor=anchor_uv`、`plane_heading=route_heading`；`shell`仅结构横截面用，不能给普通家具设置。region必须非空且归属连续。屋顶连接mesh作为独立批组输出，不能伪装成贴地sprite。

## D. 几何算法逐步定义

### D1. 路径保护区

使用已有route.pose/point读取中心线。弧段采用自适应采样：最大弦偏差0.025m，直段最大采样间隔0.5m（拟定工程精度，不是美术密度）。由左右法线偏移形成走廊polygon，圆弯用采样弧连接。半宽来自该镜头下参考可走区域和现有战斗站位范围，不沿用未知含义的76U。

对每个分支构造保护polygon；场景布局使用其并集，查询硬实体是否与任一保护polygon相交。段边界额外读取相邻段的可见连接部分。首版可保留多个polygon做局部相交，避免强求单一复杂多边形；顶面三角化前再求并集与检查孔洞。

脚印相交用2D凸多边形SAT；非凸脚印离线拆成凸块。空间桶建议以最大常见脚印直径向上取整为cell边长，记录检查次数；避免所有实例两两比较。净空按footprint而不是图片矩形判定。

### D2. 拱与共用厅

候选拱沿主中心线取样，步长从已接受同类基准取得。均匀缩放不能改变开口宽高比；开口不够就换更宽开口资产或登记缺口，不强行拉宽。

每个候选先把两侧支持footprint转到世界坐标，与所有路线保护polygon做相交。任一脚冲突则不放完整拱，改为共用厅边界的独立侧结构。不可只删除冲突拱后留洞顶。

出口恢复条件：两个相邻出口各自的走廊+结构footprint均不相交，且此状态持续至少一个主结构步长。用该位置作出口喉部起点，避免在阈值附近交替开关。此计算只在生成期进行。

共用厅owner固定为segment_id + junction；不可绑定左右其中一支，选路不重生成大厅。选路只决定未来可达段及退场范围。

### D3. 顶壁连接

每对相邻结构使用roof_left/right与wall_top sockets生成带状连接面；局部法线与UV沿路径累计弧长，不能每段重置纹理相位。转弯方向用现有切线，路径变化只影响几何，不改变贴图比例。

室内顶/壁接缝几何共用边顶点；视觉装饰片可以轻微重叠，但不得放共面大透明片。共用厅顶部覆盖所有室内保护polygon上方，出口保留通道，结构只放边界。使用简单多边形三角化，不把多个重叠顶片叠成半透明黑块。若socket形成自交，输出 `invalid_roof_polygon`，不静默生成。

洞穴连接面为分段不规则截面，轮廓变化应确定性且幅度来自岩洞参考；不能拿木屋平顶替代。山口profile必须明确从开放入口转为闭合洞内的s区间。

若没有满足 sockets 与顶壁纹理条件的高拱梁，按 B9 选择 `closed_low_ceiling` 或 `blocked_missing_asset`；不得自动退回 `open`。桥/庭院roof_mode=open，不执行封闭顶验收；摊棚roof_mode=local，只验证标记为covered的棚下区域。室内意外的背景孔洞不归为“设计留白”。

### D4. 按层撒布

先结构，再功能组，再地被/碎屑。中型家具围绕墙段或结构socket放置，桌柜/桶/工具构成一组，不能全部独立随机散在通道。

各层独立RandomNumberGenerator，seed由固定UTF-8字节哈希生成并存seed_version。首次实现明确采用SHA256输入串前8字节的小端正63位值，不依赖Godot String.hash跨版本稳定性。输入串是 `run|segment|scene|layer|cluster`，逐字段转十进制/原始id，用ASCII竖线连接。

每候选最多8次修正：沿允许侧带向外最多4次、沿路径前后最多4次，步长取该资产脚印直径的1/4。仍冲突则记录reject，不能改变资产大小或侵入保护区。结构缺失算失败；碎屑少量被拒绝可接受，但应统计可见覆盖。

地面layer使用ground_surface或现有正确接地的三分之四视角片；不把所有litter强制水平化。吊灯/链条只用suspended，不执行地形脚部折叠。大型家具接地用多个支持点，不能把整个柜子像草一样弯曲。

### D5. 战场与流式

战场预留由当前布阵/敌人接近区/前移上限导出，不硬编码为18景相同宽度。静态环境只能在生成时避让，进战斗不能清空或瞬移环境。相机、事件、角色轨迹固定，布局服从它们。

复用successor_world的局部生成→一次世界变换；验证位置/朝向/灯XZ都变换一次。已选择路径附近旧装饰保留到视锥后退场，不在选择瞬间替换所有图。屋顶、侧壁和实体分组共同按segment生命周期回收。

`scenery.process_uploads(1500)` 的1500是微秒预算，**不是1500个实例**；仍需测量不可打断的build_group尖峰。现有RoutePlan限制12 region/3 space，新增共用厅不要为每个asset创建region导致超限。

## E. 测量与通过规则

数值分成“工程门槛”和“审美基准”；下面门槛是本协议设定的初始验收门槛，不冒充已测得六基准数据。

### E1. 基准测量方法

固定1440×900，以实际3Dviewport为ROI，去掉HUD；种子1842/713/9981，锁定导出的镜头和ForestSettings。同样s、phase、branch与视口截图；参考片和候选片不能一张是战斗另一张是移动。

额外输出role-ID遮罩及ground/depth/actor/structure遮罩，采样采用同Camera3D、同深度与相同alpha阈值；不能根据RGB亮暗猜场景覆盖。美术图保留原光照。

ROI划分：横向左右各30%、中间40%；纵向上35%为顶部、中间35%为中景、下30%为近地。分别统计各role遮罩面积/对应ROI面积。实例必须至少贡献16个可见像素才计一个可见种类/层。统计按距离分0–10m、10–30m、30m以上，不以全路段总sprite数代替。

对每个基准计算三seed×同机位统计，记录min/median/max。新主题只有借用该层时才比较：同类结构中景占比/地面覆盖初始允许范围为参考[min−0.05,max+0.05]，截到0–1。偏离只能通过明确设计例外解释并提交审查，不能偷偷扩大阈值。园林不拿室内地面占比作目标。

封闭区域顶部漏空通过双证据检查：几何覆顶完整性+无雾debug中向上视线穿透检查；正常镜头顶部ROI里的背景也记录。几何连接边容差1mm，未标为开口的连通漏空大于4px即失败（2x MSAA下允许孤立边缘像素，必须查看连续帧）。开放区域不使用此门槛。

### E2. 必须自动失败的情况

- native节点不存在；phase/seed/branch/入口与manifest不符；输出夹混有上次文件。
- 结构位置出现NaN/INF、脚印侵入走道/战场、屋顶polygon自交、缺主要连接件。
- 同seed生成不一致；只增碎屑导致结构/事件位置hash变化；旋转后位置误差>0.001m或yaw误差>0.0001rad。
- 硬物支持点离地/入地>0.02m，或标记应保留的主体像素被地面切除；不把透明脚部空白算主体。
- 相机静止且无资产动画时结构顶点改变；进出战斗重新撒布环境。
- 脚本日志有SCRIPT ERROR/ERROR，哪怕进程返回0也失败。

### E3. 性能门槛

单次预热后测30秒固定轨迹，参考/候选交替各3轮，报告中位p50/p95和最大上传尖峰。同设置候选p95比参考增加超过10%或2ms（取较宽限值）列为回归，先查透明叠层与批组，不直接删美术层。目标60FPS单独记录；参考自身达不到时不能把相对通过写成稳定60FPS。最多两轮针对明确瓶颈修正，仍超预算提交诊断，不无限压测。

## F. 工作包及文件边界

|ID|依赖|输入/操作|输出与结束条件|
|---|---|---|---|
|P00|无|读取本协议、v1、inventory，记录git状态和五个核心源码hash|baseline_context.json；标明旧试配未验收；不改游戏|
|P01|P00|修capture工具：强制主题参数、唯一run目录、超时、native断言、保存完整manifest；一个进程一个场景|单场景真的只截1景；错误参数退出非0；旧PNG不进入新报告|
|P02|P01|给六基准加离线role映射和分层debug捕获；执行E1|六个baseline.json与原图/遮罩；无渲染路径一致证据则未通过|
|P03|P00|实现AssetSpec/Profile校验、旧metadata无损迁移和资产缺口台账|schema、validator、asset_request；未知字段保持缺口，不填假尺寸|
|P03A|P03|只处理已批准的asset_request；按B8生成/处理/验收资产，若无缺口则输出no-op|原始图、处理图、AssetSpec、透明/分辨率/轮廓日志和hash；任何一项缺失保持awaiting_asset_review|
|P04|P03|实现路径polygon、SAT/空间桶、共用厅owner|直线、左/右旋转、2/3岔、边界接续几何测试通过|
|P05|P02/P03A/P04|仅red_cottage，接顶壁/侧面/已有家具，按规范输出数据|完整移动+2/3岔+战斗截图；缺顶纹理则生成asset_request，保持未通过|
|P06|P02/P03A/P04|仅piper_mountain，实现入口→洞内与岩壁共用厅|同P05，另验证岩体接地能力字段|
|P07|P05/P06|代表空间技术/视觉自查后提交用户一次确认|decision文件记录用户原话；不得自填approved|
|P08|P07|依次扩展garden、street、bridge、stage、clock代表，复用模块|每类独立比较；不把室内顶套室外；无新算法的类不重做框架|
|P09|同类代表通过|按场景包推广剩余主题，每景只改manifest/profile|每景证据和例外；不能修改renderer隐藏某景缺陷|
|P10|P09|同设置性能/流式退场检查、聚合审查页面|18景状态分开；缺图/审美待审不计完成|

生产场景不要修改原六基准代码；共享renderer只允许能力扩展且必须先做基准等价截图。任何需要改投影、镜头模板、战斗动作的发现登记到旁支，不在此任务修。

## G. 固定命令与失败处理

在仓库根目录执行，用powershell。先 `Get-Command godot` 检查路径和版本；本项目已有wrapper不代表自定义参数已正确转发。

```powershell
python scripts/audit_scene_production_contract.py --output docs/design/SCENE3D-ASSET-INVENTORY.json
godot --headless --path godot --check-only --script res://scripts/spaces/layouts/fairytale_corridor.gd
godot --headless --path godot --script res://tests/test_fairytale_corridor_frames.gd
godot --headless --path godot --script res://tests/audit_fairytale_travel_visual.gd
# 现有捕获器仅用于P01整改验证，不是最终验收工具：
godot --path godot --script res://tests/capture_fairytale_3d_scatter_contact_sheet.gd -- red_cottage
```

capturer不能用headless等待frame_post_draw。每子进程120秒超时，仅终止自己启动的PID；禁止Stop-Process所有Godot。test运行前复制受影响user配置到独立测试环境，结束恢复；优先独立user-data-dir/测试项目配置，确认实际Godot版本支持后使用。单景manifest必须显示requested=actual且count=1，否则先修参数转发。当前工具固定输出目录、保存隔离不完整，须P01完成后使用。

缺资产request固定字段：scene_id、role、why_existing_assets_fail、required_sockets、size_source、alpha/opening要求、footprint、view_angles、palette_reference、source_prompt_path、blocking_tasks、status=awaiting_asset。没有图片时，不得把该项改成done。

布局失败分流：顶漏空→顶连接/结构；中景空→功能组/墙段；地面空→同类ground层；拥堵→footprint/保护区；岔路突变→owner与切线；马赛克→有效分辨率/采样；帧时高→透明叠层/分组/上传。每轮最多只改一个相应层，记录前后差异，禁止一次改镜头、密度、尺寸、雾四项。

## H. 交给 Luna 的首条任务

工作依赖及18景映射另存 `SCENE3D-LUNA-TASKS.json`。可运行的证据检查器已提供：`python scripts/validate_scene3d_capture.py <run_dir>/manifest.json`，核对核心源码/资产/设置hash、实际主题、native声明、机位数据、PNG尺寸/hash和运行日志。它不证明图像美观，也不能替代捕获器对native节点的真实断言。已通过1个合成合法样本与9个反例检查；尚无P01生产截图通过该检查，不能标为P01完成。

manifest顶层字段：schema_version=2、run_id、created_utc、engine_version、command、entry、requested_scene、source_sha256、asset_sha256、settings_sha256、captures、log、completion_marker、visual_status。源码与资产路径相对仓库，设置/图片/日志相对run_dir。captures每项包含scene、native_node_confirmed、phase、expected_phase、seed、branch、route_s_m、viewport=[w,h]、camera_transform=12个有限数、projection_matrix=16个有限数、image、sha256。遮罩为独立捕获项；相机矩阵按Godot列顺序序列化并在工具中记录格式，禁止全零占位。user_approved还需user_decision_reference。

“读取 SCENE3D-PRODUCTION-STANDARD-2026-09-21.md 和 SCENE3D-LUNA-EXECUTION-2026-09-21.md。本次先完成 P00、P01：整理可追溯基准上下文，使用单场景3D截图证据工具验证 red_cottage 参数只捕获该景、native节点真实存在、输出目录不复用。不要调整场景密度、镜头和美术；P00/P01不生成新图。交付工具、命令、实际截图manifest和日志。完成后按依赖推进P02/P03；如果P03登记了真实asset_request，再按B8执行P03A，交付原始图、处理图、AssetSpec和质量日志；代表景未批准前不要批量迁移18景。”

这份协议把实现选择、处理顺序和失败路径固定下来。尚未运行的基准测量、未制作资产和用户视觉批准仍是显式任务，不能用写完规范代替它们。
