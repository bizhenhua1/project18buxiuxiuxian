extends Control
var state:IslandModel
var view:IslandView3D
var caption:Label
var veil:ColorRect
var map_id:=0
var transition:Dictionary={}
var transition_time:=0.0
var swapped:=false
const TRANSITION_SECONDS:=2.2
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	state=IslandModel.new();state.set_meta("traversal_demo",true);state.wave_strength=.42
	state.passage_requested.connect(begin_transition)
	build_map(0)
	view=IslandView3D.new();add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.setup(state,IslandAssets.new())
	veil=ColorRect.new();veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.color=Color("191c1c",0);veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(veil)
	var panel:=VBoxContainer.new();panel.position=Vector2(12,65);add_child(panel)
	caption=Label.new();caption.text="海岸 · 点击渐隐立面或缺格洞口，前往另一张地图";panel.add_child(caption)
	var wave:=CheckButton.new();wave.text="海浪起伏";wave.button_pressed=true;panel.add_child(wave);wave.toggled.connect(func(v):state.waves_enabled=v)
	var strength:=HSlider.new();strength.min_value=0;strength.max_value=1.0;strength.step=.02;strength.value=state.wave_strength;strength.custom_minimum_size.x=280;panel.add_child(strength);strength.value_changed.connect(func(v):state.wave_strength=v)
	var note:=Label.new();note.text="波浪幅度 · 已增强，可向右继续调大";panel.add_child(note)
	var row:=HBoxContainer.new();panel.add_child(row)
	for dir in [-1,1]:
		var rotate:=Button.new();rotate.text="↶ 左转 Q" if dir<0 else "右转 E ↷";row.add_child(rotate);rotate.pressed.connect(func():state.rotate_view(dir))
	var reset:=Button.new();reset.text="回到海岸重新测试";panel.add_child(reset);reset.pressed.connect(func():
		if not transition.is_empty() or state.input_locked:return
		build_map(0);caption.text="海岸 · 点击渐隐立面或缺格洞口")
	var close:=Button.new();close.text="退出测试";panel.add_child(close);close.pressed.connect(func():queue_free())
func build_map(next:int):
	map_id=next
	var angle:=state.heading
	var strength:=state.wave_strength
	state.set_block_signals(true);state.load_map(next);state.set_block_signals(false)
	state.heading=angle;state.wave_strength=strength
	var land:Dictionary=state.cells.filter(func(c):return c.layer=="land")[0].duplicate(true)
	var water:Dictionary=state.cells.filter(func(c):return c.layer=="water")[0].duplicate(true)
	state.cells.clear();state.lookup.clear();state.blocked.clear();state.explored.clear();state.traversal.reset()
	for r in range(-3,3):
		for c in range(-3,2):
			if next!=2 and Vector2i(c,r)==Vector2i(0,1):continue
			if next==2 and Vector2i(c,r)==Vector2i(0,0):continue
			if next==1 and c< -1 and r>0:continue
			if next==2 and c< -1 and r< -1:continue
			var wet:=next==0 and (c< -1 or r< -1)
			var cell:Dictionary=(water if wet else land).duplicate(true)
			cell.c=c;cell.r=r;cell.h=-.25 if wet else 0.0;cell.feat=null;cell.waterfall_edges=[]
			if wet:cell.source_h=-.25
			add_cell(cell)
	if next==0:
		add_land(land,Vector2i(2,-1))
		for p in [Vector2i(2,-2),Vector2i(3,-2)]:add_land(land,p,true)
		add_link("up","崖壁 · 攀向上层崖口 ↑",Vector2i(2,-1),Vector2i(2,-2),false,1,Vector2i(2,-1),Vector2i(2,-2))
		add_link("hole","洞口 · 跳向下层空地 ↓",Vector2i(0,0),Vector2i(0,1),true,2,Vector2i(0,1),Vector2i(0,1))
	elif next==1:
		for p in [Vector2i(2,-2),Vector2i(3,-2)]:add_land(land,p)
		add_link("hole","崖口 · 跳回海岸崖脚 ↓",Vector2i(2,-2),Vector2i(2,-1),true,0,Vector2i(2,-1),Vector2i(2,-1))
	else:
		add_land(land,Vector2i(0,0),true)
		add_link("up","洞壁 · 爬回海岸洞口 ↑",Vector2i(0,1),Vector2i(0,0),false,0,Vector2i(0,1),Vector2i(0,0))
	state.player=Vector2i(-1,0);state.pivot=Vector2.ZERO;state.preview_all=true;state.zoom=1.25;state.zoom_goal=1.25;state.input_locked=not transition.is_empty()
	IslandWater.solve(state.cells)
	for cell in state.cells:state.remember(IslandModel.key(cell))
	state.update_sight();state.map_changed.emit()
func add_land(template:Dictionary,p:Vector2i,concealed:=false):
	var cell:=template.duplicate(true);cell.c=p.x;cell.r=p.y;cell.h=9.0 if concealed else 0.0;cell.feat=null
	if concealed:cell.upper_fade=1.35;cell.concealed_peak=true;cell.requires_traversal=true
	add_cell(cell)
func add_link(id:String,label:String,from:Vector2i,to:Vector2i,down:bool,destination:int,arrival_from:Vector2i,arrival_to:Vector2i):
	# Identical grid coordinates preserve the shaft/cliff correspondence across layers.
	state.traversal.links.append({"id":id,"label":label,"from":from,"to":to,"kind":"hole" if down else "climb","down":down,"duration":5.0,"transition_height":float(state.lookup.get(to,{}).get("h",9.0))-1.35/IslandView3D.HEIGHT+.5,"exit_height":-6.0 if down else 7.5,"destination_map":destination,"arrival_pose":{"from":arrival_from,"to":arrival_to,"kind":"fall" if down else "climb"}})
func add_cell(cell:Dictionary):
	state.cells.append(cell);state.lookup[IslandModel.key(cell)]=cell
func begin_transition(link:Dictionary):
	if not transition.is_empty():return
	transition=link;transition_time=0;swapped=false
	veil.mouse_filter=Control.MOUSE_FILTER_STOP
	caption.text="正在离开这片区域……"
func _process(dt:float):
	if not state:return
	dt=minf(dt,.05)
	if transition.is_empty():state.advance(dt);return
	if not swapped:state.traversal.advance_departure_fade(dt,transition_time/.55)
	transition_time+=dt
	var t:=clampf(transition_time/TRANSITION_SECONDS,0,1)
	var direction:float=-1.0 if transition.get("down",false) else 1.0
	veil.color=Color("191c1c",smoothstep(0,.25,t)*(1-smoothstep(.75,1,t)))
	if t>=.5 and not swapped:
		build_map(transition.destination_map);swapped=true
		state.player=transition.arrival_pose.to
		state.traversal.start_arrival(state,transition.arrival_pose)
	if swapped and t>=.75:state.advance(dt)
	view.world.position.y=direction*(1-smoothstep(.5,.75,t))*.65 if swapped else -direction*smoothstep(.25,.5,t)*.65
	if t>=1:
		view.world.position=Vector3.ZERO;transition={};veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
		caption.text=["海岸 · 新的一组地块","高处区域 · 已切换地图","地下区域 · 已切换地图"][map_id]
func _unhandled_key_input(event:InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_Q,KEY_LEFT]:state.rotate_view(-1);get_viewport().set_input_as_handled()
		if event.keycode in [KEY_E,KEY_RIGHT]:state.rotate_view(1);get_viewport().set_input_as_handled()
