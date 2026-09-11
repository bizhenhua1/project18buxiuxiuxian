extends "res://scripts/spaces/space_study.gd"
var live_template=preload("res://scripts/traditional/live_template.gd").new()
var arena: BattleArena
var model: BattleModel
var speed := 1.0

var presentation_camera=preload("res://scripts/journey/journey_camera.gd").new()
var presented_travel_distance:=0.0
var camera_trace=preload("res://scripts/journey/camera_trace.gd").new()
var accumulator := 0.0
var encounter_step := 0
const EXIT_ADVANCE := TravelPace.EXIT_DISTANCE
var travel_leg_origin:=0.0
var travel_leg_fork:=false
var opening_leg:=true
var travel_reveal := 1.0
var clearing_time := 0.0
var dialogue_speaker: Label
var dialogue_was_visible := false
var dialogue_tween: Tween
var event_box: VBoxContainer
var event_title: Label
var event_text: Label
var fight: Button
var fortune: Button
var supplies: Button
var leave_button: Button
var detail: Label
var route_complete := false
var title_label: Label
var bag_label: Label
var formation_button: Button
var camera_button: Button
var presentation_button:Button
var relic_face_button:Button
var names_button: Button
var pace_button: Button
var header_panel: AdventurePanel
var footer_panel: AdventurePanel
var event_panel: AdventurePanel
var kit_panel: PanelContainer
var kit_tab:=0
var roster_ui=preload("res://scripts/equipment/kit_roster.gd").new()
var kit_items: HBoxContainer
var kit_description: Label
var kit_mode: Button
var kit_remove: Button
var selected_unit: Dictionary = {}
var pause_before_kit := false
var pouch_icon: TextureRect
var route_zone := {}
var route_spec := {}
var prepared_step := -1
var sighting_time := 0.0
var road_actor: Control
var reward_notice: Label
var notice_left := 0.0
var final_reward := 0
var event_previews:Dictionary={}
var discovery_actor:Node
var scene_actor: Dictionary = {}
var entrance_time := 0.0
var launch_rect := Rect2()
var companions: Array[Dictionary] = []
var pack_time := 0.0
var branch_chosen_at := -INF
var fork_transit_time := 3.0
var fork_transit_from := 0.0
var fork_transit_to := 0.0
const FORK_TRANSIT_SECONDS := 3.0
const ENTRANCE_SECONDS := 1.15

func _ready() -> void:
	Journey.resume()
	if Journey.state.active_zone().is_empty():
		get_tree().change_scene_to_file("res://scenes/journey.tscn")
		return
	model = Journey.state.battle
	model.stage = Journey.state.world.map_index+int(Journey.state.active_zone().tier)
	model.reset()
	model.enemy.clear()
	encounter_step = int(Journey.state.local_steps.get(Journey.state.pending,0))
	route_zone = Journey.state.active_zone().duplicate(true)
	route_spec = LocalRouteSpec.profile(route_zone)
	super()
	labels = false
	if not route_spec.fork: phase = "travel"
	if route_spec.get("before_fork",false):phase="travel"
	var saved := int(Journey.state.route_choices.get(Journey.state.pending,0))
	if saved != 0 and route_spec.fork:
		phase="choose"
		distance=ForestRoute.PAUSE_AT
		choose(saved)
	if encounter_step > 0:
		fork_transit_time=FORK_TRANSIT_SECONDS
		distance = stops()[mini(encounter_step-1,stops().size()-1)]+1
		camera = ForestRoute.pose(distance,branch).position
		heading = ForestRoute.pose(distance,branch).heading
	# Restore the starting pose before the first frame, not as camera travel from origin.
	camera=ForestRoute.pose(distance,branch).position
	heading=ForestRoute.pose(distance,branch).heading
	if arena.scene_mode and not has_meta("traditional_editor"):live_template.advance(self,0)
	presentation_camera.reset(camera,heading,arena.battle_mix)
	presentation_camera.reference_origin=ForestRoute.pose(distance,branch).position
	presentation_camera.reference_ready=true
	presented_travel_distance=0
	RenderingServer.frame_post_draw.connect(_record_camera_snapshot)
	model.finished.connect(finish_battle)
	_ensure_event_preview()
	_update_ui()
func stops() -> Array:
	return LocalRouteSpec.entries(route_zone,branch).map(func(entry):return float(entry.distance))
func load_preset(_value: String) -> void:
	if StyleLibrary.active: ForestSettings.values=ForestSettings.read_saved()
	world = SegmentWorld.new(art,LocalRouteSpec.plan(route_zone))
	for sprite in world.sprites:
		sprite.silhouette = world.assets.silhouette(sprite.texture,sprite.region.space.atmosphere.depth_color)
	_build_ui()
	reset()
func is_social() -> bool:
	var entries := LocalRouteSpec.entries(route_zone,branch)
	return encounter_step < entries.size() and entries[encounter_step].kind == "social"
func _build_ui() -> void:
	header_panel = AdventurePanel.new()
	add_child(header_panel)
	footer_panel = AdventurePanel.new()
	add_child(footer_panel)
	title_label = StudyUI.label(str(Journey.state.active_zone().get("title","林间")),26)
	add_child(title_label)
	status = StudyUI.label("",14)
	status.add_theme_color_override("font_color",Color("b5b99a"))
	add_child(status)
	bag_label = StudyUI.label("",16)
	add_child(bag_label)
	pouch_icon = TextureRect.new()
	pouch_icon.texture = StyleLibrary.texture("watch-front") if StyleLibrary.active else AdventureSkin.part("pouch")
	pouch_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pouch_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pouch_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pouch_icon)
	leave_button = AdventureSkin.button("归途",func():
		if phase in ["battle","clearing"]: return
		Journey.fighting = false
		Journey.save()
		get_tree().change_scene_to_file("res://scenes/journey.tscn"))
	leave_button.tooltip_text = "返回冒险岛；已完成的遭遇会保留"
	add_child(leave_button)
	arena = BattleArena.new()
	add_child(arena)
	var view := SegmentView.new()
	view.setup(art,world,1,font)
	views.append(view)
	arena.setup(model,self,view)
	arena.set_process(false) # The route owns the only presentation tick.
	arena.enemies_visible = false
	road_actor = load("res://scripts/journey/road_encounter.gd").new()
	add_child(road_actor)
	reward_notice = StudyUI.label("",18)
	reward_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_notice.add_theme_color_override("font_color",Color("f4d28a"))
	reward_notice.add_theme_color_override("font_outline_color",Color("15201a"))
	reward_notice.add_theme_constant_override("outline_size",4)
	reward_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reward_notice)
	progress = ProgressBar.new()
	progress.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("263b30")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("bda166")
	progress.add_theme_stylebox_override("background",track)
	progress.add_theme_stylebox_override("fill",fill)
	add_child(progress)
	formation_button = AdventureSkin.button("随行整备",open_kit)
	add_child(formation_button)
	names_button = AdventureSkin.button("",func():
		arena.set_card_names(not arena.show_card_names)
		names_button.text = "卡名 · 显示" if arena.show_card_names else "卡名 · 隐藏")
	names_button.text = "卡名 · 显示" if arena.show_card_names else "卡名 · 隐藏"
	add_child(names_button)
	camera_button=AdventureSkin.button("镜头调校",open_camera_settings)
	camera_button.visible=StyleLibrary.active
	add_child(camera_button)
	presentation_button=AdventureSkin.button("表现 · 切换",func():arena.set_scene_mode(not arena.scene_mode))
	presentation_button.visible=StyleLibrary.active
	add_child(presentation_button)
	relic_face_button=AdventureSkin.button("道具 · 正反",func():arena.relic_reverse=not arena.relic_reverse)
	relic_face_button.visible=StyleLibrary.active
	add_child(relic_face_button)
	pause_button = AdventureSkin.button("暂歇",_toggle_pause)
	add_child(pause_button)
	pace_button = AdventureSkin.button("行速 · 一倍",func():
		speed = {0.5:1.0,1.0:2.0,2.0:4.0,4.0:0.5}.get(speed,1.0))
	add_child(pace_button)
	detail = StudyUI.label("",14)
	detail.add_theme_color_override("font_color",Color("bfb89a"))
	add_child(detail)
	event_panel = AdventurePanel.new()
	add_child(event_panel)
	event_box = VBoxContainer.new()
	event_box.add_theme_constant_override("separation",12)
	add_child(event_box)
	var kicker := StudyUI.label("路 途 手 记   /   抉 择",12)
	kicker.add_theme_color_override("font_color",Color("a89975"))
	event_box.add_child(kicker)
	var dialogue_row := HBoxContainer.new()
	dialogue_row.add_theme_constant_override("separation",36)
	event_box.add_child(dialogue_row)
	var narrative := VBoxContainer.new()
	narrative.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	narrative.add_theme_constant_override("separation",10)
	dialogue_row.add_child(narrative)
	event_title = StudyUI.label("",26)
	narrative.add_child(event_title)
	dialogue_speaker=StudyUI.label("旅途见闻",13)
	dialogue_speaker.add_theme_color_override("font_color",Color("aa9872"))
	narrative.add_child(dialogue_speaker)
	event_text = StudyUI.label("",17)
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative.add_child(event_text)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x=250
	actions.add_theme_constant_override("separation",10)
	dialogue_row.add_child(actions)
	left_button = AdventureSkin.button("循人迹",func():choose(-1))
	right_button = AdventureSkin.button("寻妖息",func():choose(1))
	fight = AdventureSkin.button("迎战",start_battle)
	fortune = AdventureSkin.button("调查旧迹",func():resolve("fortune"))
	supplies = AdventureSkin.button("取些补给",func():resolve("supplies"))
	for button in [left_button,right_button,fight,fortune,supplies]:
		button.custom_minimum_size = Vector2(250,44)
		actions.add_child(button)
	kit_panel = PanelContainer.new()
	kit_panel.add_theme_stylebox_override("panel",_kit_style())
	kit_panel.hide()
	add_child(kit_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",4)
	kit_panel.add_child(body)
	var heading_row := HBoxContainer.new()
	body.add_child(heading_row)
	var heading_label := StudyUI.label("行囊 · 点选或拖入下方阵列",17)
	heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading_label)
	var close_button := AdventureSkin.button("整备完毕",close_kit)
	close_button.custom_minimum_size = Vector2(120,40)
	heading_row.add_child(close_button)
	var tabs:=TabBar.new();tabs.add_tab("神秘道具");tabs.add_tab("角色");body.add_child(tabs)
	tabs.tab_changed.connect(func(index):kit_tab=index;_refresh_kit())
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	kit_items = HBoxContainer.new()
	kit_items.add_theme_constant_override("separation",8)
	scroll.add_child(kit_items)
	var selected_row := HBoxContainer.new()
	body.add_child(selected_row)
	kit_description = StudyUI.label("",14)
	kit_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_row.add_child(kit_description)
	kit_mode = AdventureSkin.button("手持 / 操控",func():
		if not selected_unit.is_empty(): arena.change_mode(selected_unit.index)
		_refresh_kit())
	kit_mode.custom_minimum_size.x = 150
	selected_row.add_child(kit_mode)
	kit_remove = AdventureSkin.button("收回行囊",func():
		if not selected_unit.is_empty(): arena.remove_card(selected_unit.index)
		selected_unit = {}
		_refresh_kit())
	kit_remove.custom_minimum_size.x = 130
	selected_row.add_child(kit_remove)
	_layout_ui()
func _kit_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("111820") if StyleLibrary.active else Color("101f1a")
	box.border_color = Color("655c50") if StyleLibrary.active else Color("a68a50")
	box.set_border_width_all(2)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: box.set_content_margin(side,8)
	return box
func _layout_ui() -> void:
	var ui_scale := clampf(minf(size.x/1600.0,size.y/960.0),.65,3.0)
	var canvas_size := size/ui_scale
	header_panel.position = Vector2(16,12)
	header_panel.size = Vector2(canvas_size.x-32,68)
	title_label.position = Vector2(40,18)
	status.position = Vector2(42,51)
	bag_label.position = Vector2(canvas_size.x-320,34)
	pouch_icon.position = Vector2(canvas_size.x-365,23)
	pouch_icon.size = Vector2(34,40)
	leave_button.position = Vector2(canvas_size.x-145,26)
	leave_button.size = Vector2(105,40)
	arena.position = Vector2(24,88)
	arena.size = Vector2(canvas_size.x-48,canvas_size.y-170)
	arena.equipment_open = kit_panel != null and kit_panel.visible
	arena.scenery.size=arena.size
	progress.position = Vector2(42,canvas_size.y-77)
	progress.size = Vector2(canvas_size.x-84,3)
	footer_panel.position = Vector2(16,canvas_size.y-67)
	footer_panel.size = Vector2(canvas_size.x-32,55)
	formation_button.position = Vector2(34,canvas_size.y-59)
	formation_button.size = Vector2(142,38)
	pause_button.position = Vector2(canvas_size.x-287,canvas_size.y-59)
	pause_button.size = Vector2(106,38)
	pace_button.position = Vector2(canvas_size.x-166,canvas_size.y-59)
	pace_button.size = Vector2(130,38)
	names_button.position = Vector2(188,canvas_size.y-59)
	names_button.size = Vector2(130,38)
	camera_button.position=Vector2(330,canvas_size.y-59)
	camera_button.size=Vector2(120,38)
	presentation_button.position=Vector2(462,canvas_size.y-59)
	presentation_button.size=Vector2(120,38)
	relic_face_button.position=Vector2(594,canvas_size.y-59)
	relic_face_button.size=Vector2(112,38)
	detail.position = Vector2(332,canvas_size.y-50)
	detail.size = Vector2(canvas_size.x-640,28)
	var width := minf(1100,canvas_size.x-64)
	event_panel.position = Vector2((canvas_size.x-width)/2,canvas_size.y-338)
	event_panel.size = Vector2(width,248)
	event_box.position = event_panel.position+Vector2(30,20)
	event_box.size = event_panel.size-Vector2(60,40)
	if kit_panel:
		kit_panel.position = arena.position
		kit_panel.size = Vector2(arena.size.x,arena.scenery.position.y-8)
	road_actor.position = arena.position
	road_actor.size = arena.size
	if phase == "entering":
		road_actor.start_rect = Rect2(launch_rect.position*arena.size,launch_rect.size*arena.size)
		for card in arena.cards:
			if card.side != "enemy" or card.index != 0: continue
			var box := card.portrait_rect(road_actor.art)
			box.position += card.position
			var dims: Vector2 = road_actor.art.get_size()*minf(box.size.x/road_actor.art.get_width(),box.size.y/road_actor.art.get_height())
			road_actor.end_rect = Rect2(box.get_center()-dims/2,dims)
		for entry in road_actor.companions:
			entry.start_rect = Rect2(entry.launch.position*arena.size,entry.launch.size*arena.size)
			for card in arena.cards:
				if card.side != "enemy" or card.index != entry.index: continue
				var box := card.portrait_rect(entry.art)
				box.position += card.position
				var dims: Vector2 = entry.art.get_size()*minf(box.size.x/entry.art.get_width(),box.size.y/entry.art.get_height())
				entry.end_rect = Rect2(box.get_center()-dims/2,dims)
			if not entry.actor.hidden:
				var rect: Rect2 = road_actor.sample_between(entry.start_rect,entry.end_rect,clampf((road_actor.flight_t-entry.delay)/(1-entry.delay),0,1))
				rect.position -= arena.scenery.position
				entry.actor.transition_rect = rect
		if not scene_actor.hidden:
			var actor_rect: Rect2 = road_actor.sample_rect()
			actor_rect.position -= arena.scenery.position
			scene_actor.transition_rect = actor_rect
	reward_notice.position = arena.position+arena.scenery.position+Vector2(0,18)
	reward_notice.size = Vector2(arena.size.x,32)
	for child in get_children():
		if child is Control:
			child.scale = Vector2.ONE*ui_scale
			child.position *= ui_scale
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and event_box: _layout_ui()
func open_kit() -> void:
	if kit_panel.visible:
		close_kit()
		return
	if phase in ["battle","clearing","defeat","entering","sighting"]: return
	pause_before_kit = paused
	paused = true
	kit_panel.show()
	_refresh_kit()
	_update_ui()
func close_kit() -> void:
	if not kit_panel.visible: return
	kit_panel.hide()
	paused = pause_before_kit
	Journey.save()
	_update_ui()
func _refresh_kit() -> void:
	for child in kit_items.get_children():
		kit_items.remove_child(child)
		child.queue_free()
	if not selected_unit.is_empty() and not model.player.has(selected_unit): selected_unit = {}
	kit_description.text = "选择下方卡牌，可收回或切换持用方式" if selected_unit.is_empty() else selected_unit.name+" · "+selected_unit.skillText
	kit_description.tooltip_text = kit_description.text
	kit_mode.disabled = selected_unit.is_empty() or selected_unit.get("cardType","") != "fabao"
	kit_remove.disabled = selected_unit.is_empty() or selected_unit.get("cardType","") == "char"
	if kit_tab==1:
		kit_description.text="点击角色上阵或收回 · 长按角色装配武器"
		roster_ui.populate(self)
		return
	for spec in model.rules.cards:
		if spec.pool == "enemy" or spec.cardType=="char" or spec.get("portrait_kind","")=="person": continue
		var id: String = spec.id
		var button := AdventureItem.new()
		button.text = spec.name
		button.card_id = id
		button.art = arena.art_for(spec)
		var equipped: int = model.player.filter(func(u):return u.cardId == id).size()
		button.subtitle = "随行 × %d" % equipped if equipped > 0 else "可编入阵列"
		button.pressed.connect(func():
			note(model.add_card(id))
			arena.rebuild()
			_refresh_kit())
		button.tooltip_text = spec.skillText
		kit_items.add_child(button)
func choose(direction: int) -> void:
	if not route_spec.get("fork",false): return
	if phase != "choose": return
	var saved := int(Journey.state.route_choices.get(Journey.state.pending,0))
	if saved != 0 and direction != saved: return
	super(direction)
	travel_leg_origin=distance;travel_leg_fork=true;opening_leg=false
	branch_chosen_at=distance
	moving_envelope=0.0
	fork_transit_from=distance
	fork_transit_to=float(stops()[encounter_step]) if encounter_step<stops().size() else float(route_spec.end)
	fork_transit_time=0.0
	_sync_event_previews()
	Journey.state.route_choices[Journey.state.pending] = direction
	Journey.save()
func _process(delta: float) -> void:
	if not arena: return
	playback_speed = speed
	model.paused = paused
	var dt := maxf(delta,0.0)*speed
	if not paused:
		elapsed += dt
		if phase == "entering":
			entrance_time = minf(ENTRANCE_SECONDS,entrance_time+dt)
			var t := entrance_time/ENTRANCE_SECONDS
			arena.battle_mix = maxf(arena.battle_mix,smoothstep(0,.65,t))
			arena.entrance_progress = t
			scene_actor.hidden = arena.scene_mode or t >= .18
			for actor in companions: actor.hidden = arena.scene_mode or t >= .18
			road_actor.flight_t = t
			road_actor.queue_redraw()
			if entrance_time >= ENTRANCE_SECONDS and (not arena.scene_mode or (arena.formation_ready and presentation_camera.blend>.98)):
				if model.start():
					phase = "battle"
					Journey.fighting = true
					accumulator = 0
		elif phase=="reviving":
			entrance_time+=dt
			if entrance_time>=.65 and model.start():
				phase="battle";Journey.fighting=true;accumulator=0
		elif phase in ["encounter","sighting"]:
			arena.battle_mix=move_toward(arena.battle_mix,1,dt*1.5)
		elif phase not in ["battle","clearing","defeat"]:
			arena.battle_mix = move_toward(arena.battle_mix,0,dt*1.4)
		if notice_left > 0: notice_left = maxf(0,notice_left-dt)
		if phase == "approach":
			phase_time += dt
			moving_envelope=move_toward(moving_envelope,travel_envelope(),dt*2.5)
			distance=minf(ForestRoute.PAUSE_AT,distance+route_travel_speed()*moving_envelope*dt)
			if ForestRoute.PAUSE_AT-distance<.02:distance=ForestRoute.PAUSE_AT;phase="choose"
		elif phase == "travel":
			moving_envelope = move_toward(moving_envelope,travel_envelope(),dt*2.5)
			if fork_transit_time<FORK_TRANSIT_SECONDS:
				distance=minf(fork_transit_to,distance+route_travel_speed()*moving_envelope*dt)
				if fork_transit_to-distance<.02:distance=fork_transit_to;fork_transit_time=FORK_TRANSIT_SECONDS
			else:distance = minf(distance+route_travel_speed()*moving_envelope*dt,route_spec.end)
			if route_spec.fork and branch==0 and distance>=ForestRoute.PAUSE_AT-.02:
				distance=ForestRoute.PAUSE_AT
				phase="choose"
		elif phase == "sighting":
			sighting_time += dt
			if sighting_time >= .18: start_battle()
		if phase == "battle":
			accumulator += dt
			while accumulator >= 1.0/120 and phase == "battle":
				model.advance(1.0/120)
				accumulator -= 1.0/120
		elif phase == "clearing":
			clearing_time += dt
			arena.enemy_opacity = 1-smoothstep(.3,.85,clearing_time)
			if arena.scene_mode:arena.battle_mix=1-smoothstep(.12,1.35,clearing_time)
			if clearing_time >= (1.4 if arena.scene_mode else 1.0):
				if arena.scene_mode:
					distance+=EXIT_ADVANCE
					travel_reveal=1.0
					# Hidden companions re-enter from the next travelling group, never
					# from a previous battlefield's persistent movement state.
					for unit in model.player:
						if not arena.seer or unit.uid!=arena.seer.uid:arena.formation_motion.units.erase(unit.uid)
				model.enemy.clear()
				arena.effects.clear()
				arena.particles.clear()
				arena.enemies_visible = false
				Journey.fighting = false
				travel_leg_origin=distance;travel_leg_fork=false;opening_leg=false
				phase = "travel"
				phase_time = 0
				travel_time = 0
				# Release the battle edit lock without resetting health, poses or resources.
				model.phase="prepare"
	if not paused and phase in ["travel","approach"]:travel_reveal=minf(1.0,travel_reveal+dt/.55)
	camera = ForestRoute.pose(distance,branch).position
	var target_heading: float = ForestRoute.pose(distance+75,branch).heading
	heading = target_heading if not paused else heading
	if phase not in ["travel","approach"]: moving_envelope = move_toward(moving_envelope,0,dt*5)
	_ensure_event_preview()
	if not arena.scene_mode and not paused and prepared_step == encounter_step and encounter_step < stops().size() and phase in ["travel","sighting","encounter"] and not companions.is_empty() and distance >= stops()[encounter_step]-.02-200:
		pack_time += dt
		var lead_motion := CreatureMotion.sample(model.enemy[0].cardId,clampf(pack_time/.28,0,1))
		scene_actor.altitude = lead_motion.altitude
		scene_actor.squash = lead_motion.squash
		for i in range(companions.size()):
			var actor := companions[i]
			var progress := clampf((pack_time-i*.055)/.28,0,1)
			var motion := CreatureMotion.sample(actor.card_id,progress)
			var u: float = motion.travel
			var side := -1 if i%2 == 0 else 1
			actor.position = ForestRoute.point_at(actor.route_s,branch,side*lerpf(190,48+floori(i/2.0)*40,u))
			actor.altitude = motion.altitude
			actor.squash = motion.squash
			if progress > 0 and progress < 1:
				for grass in actor.nearby_grass:
					if grass.position.distance_squared_to(actor.position) < 85*85:
						if elapsed-float(grass.get("rustle_started",-10)) > .2:
							grass.rustle_started = elapsed
							grass.rustle_strength = motion.grass_strength
	if phase == "travel" and encounter_step < stops().size() and distance >= stops()[encounter_step]-.02 and (branch==0 or distance>=route_spec.junction+route_spec.fork_clearance):
		distance = stops()[encounter_step]
		camera = ForestRoute.pose(distance,branch).position
		phase = "encounter"
		arena.world_anchor=ForestRoute.pose(distance,branch).position
		arena.world_facing=ForestRoute.pose(distance,branch).heading
		if not arena.scene_mode:moving_envelope = 0
		for view in views: view.sync(camera,heading,elapsed,0,branch,labels,bob,distance)
		if not is_social():
			if prepared_step != encounter_step: prepare_encounter()
			phase = "encounter" if LocalRouteSpec.entries(route_zone,branch)[encounter_step].choice else "sighting"
			sighting_time = 0
	if phase == "travel" and encounter_step >= stops().size() and distance >= route_spec.end-.02: phase = "arrived"
	if arena.scene_mode and phase=="travel" and encounter_step<stops().size():
		var event_distance:float=stops()[encounter_step]
		if absf(next_travel_target()-event_distance)<.1:
			var anticipation:=1-smoothstep(0,route_travel_speed()*.55,event_distance-distance)
			arena.battle_mix=maxf(arena.battle_mix,anticipation)
	if arena.scene_mode:
		arena.scenery.renderer.set_battle_camera(arena.battle_mix)
		if phase=="clearing":
			var exit_distance:=distance+EXIT_ADVANCE*smoothstep(0,1.4,clearing_time)
			camera=ForestRoute.pose(exit_distance,branch).position
			heading=ForestRoute.pose(exit_distance,branch).heading
	if arena.scene_mode and phase in ["encounter","sighting","entering","battle","defeat","reviving"]:
		# Battle camera belongs to the encounter center, never to a party member.
		camera=ForestRoute.pose(distance,branch).position
		heading=ForestRoute.pose(distance,branch).heading
	if arena.scene_mode and not has_meta("traditional_editor"):
		live_template.advance(self,delta)
	var previous_camera:Vector2=presentation_camera.position
	var was_initialized:bool=presentation_camera.initialized
	if arena.scene_mode and not live_template.data.is_empty() and not has_meta("traditional_editor"):
		var reference_distance:float=distance+EXIT_ADVANCE*smoothstep(0,1.4,clearing_time) if phase=="clearing" else distance
		presentation_camera.advance_reference(ForestRoute.pose(reference_distance,branch).position)
	presentation_camera.advance(camera,heading,arena.battle_mix,delta,paused or phase in ["defeat","reviving"])
	presentation_camera.advance_walk(moving_envelope,delta,paused or phase in ["defeat","reviving"])
	for view in views:view.renderer.presentation_bob=presentation_camera.walk_offset
	camera=presentation_camera.position;heading=presentation_camera.angle
	if was_initialized and not paused and phase in ["travel","approach"]:
		presented_travel_distance+=camera.distance_to(previous_camera)
	if arena.scenery.renderer is SegmentRenderer:
		arena.scenery.renderer.presentation_blend=presentation_camera.blend if arena.scene_mode else -1.0
		arena.scenery.renderer.set_battle_camera(arena.battle_mix,arena.scene_mode)
	# Layout first, then publish one camera state, then advance actors exactly once.
	_update_ui()
	for view in views: view.sync(camera,heading,elapsed,moving_envelope,branch,labels,bob,distance)
	if discovery_actor:
		discovery_actor.team_key.light_color=Color("bedae0")*arena.scenery.renderer.enemy_light_tint()
		discovery_actor.advance(minf(delta,.05),"travel",paused,speed,true)
	arena._process(minf(delta,.05))
	for view in views:view.sync_projection()
	if phase == "arrived" and not route_complete:
		var before := Journey.state.stones
		route_complete = Journey.state.finish_local()
		final_reward = Journey.state.stones-before
		Journey.save()
func _ensure_event_preview() -> void:
	_sync_event_previews()
	if phase not in ["travel","approach"] or encounter_step>=stops().size() or is_social() or prepared_step==encounter_step:return
	var entry:Dictionary=LocalRouteSpec.entries(route_zone,branch)[encounter_step]
	if route_spec.fork and branch==0 and entry.branch!=0:return
	prepare_encounter()
func prepare_encounter() -> void:
	for actor in companions: world.sprites.erase(actor)
	companions.clear()
	road_actor.companions.clear()
	pack_time = 0
	arena.scene_enemy_sources.clear()
	Journey.state.prepare_battle()
	prepared_step = encounter_step
	arena.enemies_visible = false
	arena.enemy_opacity = 1
	var ranked := model.enemy.duplicate()
	ranked.sort_custom(func(a,b):return a.maxHp*maxf(a.atk,1) > b.maxHp*maxf(b.atk,1))
	if not ranked.is_empty():
		# The physical lead becomes card zero; companions follow it into the row.
		model.enemy.erase(ranked[0])
		model.enemy.push_front(ranked[0])
		for i in range(model.enemy.size()): model.enemy[i].index = i
		if arena.enemy_actor and arena.scene_mode and not ranked[0].get("fairytale_enemy",false):model.enemy[0].name="失控梦游者"
		arena.rebuild()
		road_actor.art = arena.art_for(ranked[0])
		road_actor.caption = ranked[0].name+" · 拦路"
		var entry:Dictionary=LocalRouteSpec.entries(route_zone,branch)[encounter_step]
		var event_branch:int=entry.branch
		var region: RouteRegion = world.plan.at(entry.visual_distance,event_branch)
		var preview_key:String="%d:%d" % [event_branch,encounter_step]
		scene_actor=event_previews[preview_key]
		scene_actor.hidden=false

		if not LocalRouteSpec.entries(route_zone,branch)[encounter_step].choice:
			for i in range(1,model.enemy.size()):
				var texture := arena.art_for(model.enemy[i])
				var actor := scene_actor.duplicate()
				actor.erase("live_discovery")
				actor.erase("ground_anchor")
				actor.texture = texture
				actor.card_id = model.enemy[i].cardId
				actor.w = 54.0*texture.get_width()/texture.get_height()
				actor.h = 54.0
				actor.id = 100000+i
				actor.route_s += i*14
				actor.position = ForestRoute.point_at(actor.route_s,branch,(-1 if i%2 == 1 else 1)*190)
				actor.silhouette = world.assets.silhouette(texture,region.space.atmosphere.depth_color)
				var grasses: Array = world.sprites.filter(func(s):return s.kind == 1 and absf(s.route_s-actor.route_s) < 120)
				grasses.sort_custom(func(a,b):return a.position.distance_squared_to(actor.position) < b.position.distance_squared_to(actor.position))
				actor.nearby_grass = grasses.slice(0,24)
				actor.hidden=arena.scene_mode
				companions.append(actor)
				world.sprites.append(actor)
		if arena.enemy_actor and arena.scene_mode and not model.enemy[0].get("fairytale_enemy",false):arena.enemy_actor.bind_unit(model.enemy[0])

func start_battle() -> void:
	if phase not in ["sighting","encounter","defeat"] or is_social(): return
	if phase == "defeat":
		# Reset the existing units in place: no new spawn, layout, camera or entrance.
		model.reset()
		arena.effects.clear();arena.particles.clear()
		arena.enemy_opacity=1;arena.enemies_visible=true
		arena.scene_enemy_sources.clear()
		arena.battle_mix=1;arena.entrance_progress=1
		phase="reviving";entrance_time=0
		if arena.seer:arena.seer.trigger("revive")
		if arena.companion_actor:arena.companion_actor.trigger("revive")
		if arena.enemy_actor:arena.enemy_actor.trigger("revive")
		return
	if arena.scene_mode:
		arena.scene_enemy_sources.clear()
		var originals:Array=[scene_actor]+companions
		for i in range(mini(originals.size(),model.enemy.size())):
			arena.scene_enemy_sources[model.enemy[i].uid]=originals[i].duplicate()
			originals[i].hidden=true
	arena.world_anchor=ForestRoute.pose(distance,branch).position
	arena.world_facing=ForestRoute.pose(distance,branch).heading
	_capture_launch()
	for i in range(companions.size()):
		var actor := companions[i]
		road_actor.companions.append({"art":actor.texture,"actor":actor,"index":i+1,"delay":(i+1)*.025,"launch":_actor_launch(actor),"start_rect":Rect2(),"end_rect":Rect2()})
	road_actor.flight = not arena.scene_mode
	road_actor.flight_t = 0
	entrance_time = 0
	arena.entrance_progress = 0
	arena.enemies_visible = true
	phase = "entering"
	arena.effects.clear()
	_update_ui()
func _capture_launch() -> void:
	launch_rect = _actor_launch(scene_actor)
func _actor_launch(actor: Dictionary) -> Rect2:
	var renderer = arena.scenery.renderer
	var relative := ForestRoute.to_camera(actor.position,camera,heading)
	var projection: float = renderer.focal()/maxf(10,relative.y)
	var dims := Vector2(actor.w,actor.h)*projection
	var foot := Vector2(arena.scenery.size.x*.5+relative.x*projection,renderer.horizon_y()+(renderer.camera_height()-actor.altitude-(ForestEcology.height_at(actor.position)-ForestEcology.height_at(camera) if StyleLibrary.active else 0.0))*projection)+arena.scenery.position
	return Rect2((foot-Vector2(dims.x*.5,dims.y))/arena.size,dims/arena.size)
func finish_battle(result: String) -> void:
	if phase != "battle": return
	if result == "victory":
		var gain := int(LocalRouteSpec.entries(route_zone,branch)[encounter_step].get("reward",0))+int(route_zone.tier)
		Journey.state.stones += gain
		Journey.state.journal.append("战胜拦路妖物 · 灵石 +%d" % gain)
		reward_notice.text = "战斗胜利 · 灵石 +%d · 已收入行囊" % gain
		notice_left = 3.5
		encounter_step += 1
		Journey.state.local_steps[Journey.state.pending] = encounter_step
		Journey.save()
		phase = "clearing"
		clearing_time = 0
		# Finish the last lethal animation before the existing departure/cleanup clock.
		if arena.scene_mode:
			for actor in arena.equipped_actors.values():clearing_time=minf(clearing_time,-actor.death_remaining())
			if arena.enemy_actor:clearing_time=minf(clearing_time,-arena.enemy_actor.death_remaining())
		arena.restore_victorious_party()
		_sync_event_previews()
	else:
		phase = "defeat"
		Journey.fighting = false
func resolve(option: String) -> void:
	if phase != "encounter" or not is_social(): return
	var before := Journey.state.stones
	if Journey.state.resolve_event(option,false):
		reward_notice.text = "补给入囊 · 灵石 +%d" % (Journey.state.stones-before) if option == "supplies" else "获得寻宝机缘 · 后续地块收获增加"
		notice_left = 3.5
		encounter_step += 1
		Journey.state.local_steps[Journey.state.pending] = encounter_step
		Journey.save()
		phase = "clearing" if arena.scene_mode else "travel"
		clearing_time=0
		_sync_event_previews()
func show_detail(unit: Dictionary) -> void:
	selected_unit = unit
	detail.text = "%s · 攻 %.0f · 生命 %d/%d" % [unit.name,unit.atk,unit.hp,unit.maxHp]
	detail.tooltip_text = unit.skillText
	if kit_panel and kit_panel.visible: _refresh_kit.call_deferred()
func note(value: String) -> void:
	detail.text = value if not value.is_empty() else "随行阵容已更新"
	Journey.save()
	if kit_panel and kit_panel.visible: _refresh_kit.call_deferred()
func _update_ui() -> void:
	if not status or not arena: return
	arena.formation_locked = phase in ["entering","reviving"]
	_layout_ui()
	var choosing := phase == "choose"
	var encounter := phase in ["encounter","defeat"]
	left_button.disabled = not choosing
	right_button.disabled = not choosing
	left_button.visible = choosing
	right_button.visible = choosing
	pause_button.text = "启程" if paused else "暂歇"
	pace_button.text = "行速 · "+{0.5:"半速",1.0:"一倍",2.0:"二倍",4.0:"四倍"}.get(speed,"一倍")
	leave_button.disabled = phase in ["battle","clearing","entering","reviving"]
	formation_button.disabled = phase in ["battle","clearing","defeat","sighting","entering"]
	formation_button.text = "整备完毕" if kit_panel.visible else "随行整备"
	pause_button.disabled = kit_panel.visible
	leave_button.text = "返岛" if route_complete else "归途"
	bag_label.text = "行囊 · %d 灵石" % Journey.state.stones
	status.text = {"approach":"山风微起 · 前路有岔","choose":"听风辨路","travel":"沿路探幽","encounter":"前方有缘","battle":"交锋之中","clearing":"妖息渐散","defeat":"胜负乃常事 · 原地休整","arrived":"此间已探尽 · 收获入囊"}.get(phase,phase)
	progress.value = distance/route_spec.end*100
	event_box.visible = (choosing or encounter or route_complete) and not kit_panel.visible
	event_panel.visible = event_box.visible
	if event_box.visible and not dialogue_was_visible:
		if dialogue_tween:dialogue_tween.kill()
		event_box.modulate.a=0;event_panel.modulate.a=0
		dialogue_tween=create_tween().set_parallel(true)
		dialogue_tween.tween_property(event_box,"modulate:a",1.0,.18)
		dialogue_tween.tween_property(event_panel,"modulate:a",1.0,.18)
	dialogue_was_visible=event_box.visible
	var social := is_social()
	fight.visible = encounter and not social
	fight.text = "原地休整" if phase == "defeat" else "迎战"
	fortune.visible = encounter and social
	supplies.visible = encounter and social
	var kind := Journey.state.event_kind()
	dialogue_speaker.text="旅途见闻"
	if route_complete:
		event_title.text = "此地探索完成"
		event_text.text = "地块奖励 · 灵石 +%d\n战斗与事件所得已收入行囊，可从上方返岛。" % final_reward
	elif choosing:
		event_title.text = "岔路 · 听风辨路"
		event_text.text = "一侧留有人迹，另一侧隐约传来妖息。"
	elif social:
		event_title.text = {"traveler":"路遇采药人","merchant":"歇脚行商","story":"旅途旧迹"}.get(kind,"旅途机缘")
		event_text.text = {"traveler":"他收拢药篓，朝你点了点头。\n“前面不好走。带些补给，或让我告诉你一处旧迹。”","merchant":"行商将旧布铺开，露出随身带来的货物。\n“补给在这里。想找些别的？这张寻宝符或许用得上。”","story":"旧路旁留着一道模糊的刻痕。你停下脚步，辨认其中的线索。"}.get(kind,"你在路边停下脚步，查看留下的物品与线索。")
		dialogue_speaker.text={"traveler":"采药人","merchant":"行商","story":"旧迹"}.get(kind,"旅途见闻")
	else:
		event_title.text = "妖物挡路" if phase != "defeat" else "暂歇 · 重整旗鼓"
		event_text.text = "前方的身影停住了。它察觉了你的靠近，挡在去路中央。\n你收紧手中的武器，准备迎战。" if phase != "defeat" else "交锋暂歇，队伍需要重新站稳脚跟。\n休整后，将在原地再次迎战。"
	fortune.text = "寻宝符 · 4 灵石" if kind == "merchant" else "调查旧迹"
	fortune.disabled = kind == "merchant" and Journey.state.stones < 4
	if phase == "sighting": status.text = "妖物现身 · 即将交锋"
	if phase == "entering": status.text = "妖势展开 · 凝神迎敌"
	reward_notice.visible = notice_left > 0
	road_actor.visible = not arena.scene_mode and phase == "entering" and scene_actor.get("hidden",false)
	if StyleLibrary.active:
		for label in [title_label,status,bag_label,event_title,event_text,reward_notice,detail]: label.text = StyleLibrary.words(label.text);label.add_theme_color_override("font_color",Color("d2cbc0"))
func _record_camera_snapshot() -> void:
	camera_trace.sample(self)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
		var path:String=camera_trace.save(self)
		reward_notice.text="镜头记录已保存" if not path.is_empty() else "镜头记录保存失败"
		notice_left=4.0
		get_viewport().set_input_as_handled()
		return
	if kit_panel and kit_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: close_kit()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT: choose(-1)
		if event.keycode == KEY_RIGHT: choose(1)
func _unhandled_key_input(event: InputEvent) -> void:
	if kit_panel and kit_panel.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE: _toggle_pause()

func open_camera_settings() -> void:
	var dialog:=Window.new()
	dialog.title="镜头调校 · 即时预览"
	dialog.size=Vector2i(360,260)
	dialog.transient=true
	dialog.exclusive=false
	add_child(dialog)
	var panel:=VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(panel)
	var fields:Dictionary={}
	var presets:=OptionButton.new()
	presets.add_item("当前镜头 · 自定义")
	for key in ForestSettings.CAMERA_PRESETS:presets.add_item(key)
	panel.add_child(presets)
	for entry in [["camera_height","机位高度",30,80,1],["camera_horizon","地平线位置",.35,.65,.01],["camera_lens","镜头倍率",.75,1.25,.01]]:
		var row:=HBoxContainer.new()
		var label:=Label.new();label.text=entry[1];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var spin:=SpinBox.new();spin.min_value=entry[2];spin.max_value=entry[3];spin.step=entry[4]
		spin.value=ForestSettings.values.get(entry[0],ForestSettings.CAMERA_PRESETS["原版视角"][entry[0]])
		spin.value_changed.connect(func(value):
			ForestSettings.values[entry[0]]=value
			if arena.seer:arena.seer.world_scale_calibrated=false)
		fields[entry[0]]=spin;row.add_child(spin);panel.add_child(row)
	presets.item_selected.connect(func(index):
		if index==0:return
		var values:Dictionary=ForestSettings.CAMERA_PRESETS[presets.get_item_text(index)]
		for key in values:fields[key].value=values[key])
	panel.add_child(StudyUI.button("保存镜头",func():ForestSettings.save();dialog.queue_free()))
	panel.add_child(StudyUI.button("异域场景目录",func():get_tree().change_scene_to_file("res://scenes/biome_hub.tscn")))
	panel.add_child(StudyUI.button("关闭 · 保留本次预览",func():dialog.queue_free()))
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()

func route_travel_speed() -> float:
	return TravelPace.RUN if opening_leg else TravelPace.mixed_speed(maxf(0,distance-travel_leg_origin),travel_leg_fork)
func next_travel_target() -> float:
	var target:float=route_spec.end
	if encounter_step<stops().size():target=float(stops()[encounter_step])
	if route_spec.fork and branch==0:target=minf(target,ForestRoute.PAUSE_AT)
	return target
func travel_envelope() -> float:
	var remaining:=maxf(0,next_travel_target()-distance)
	# Physical braking before the event, rather than stopping and relocating the camera.
	return minf(1.0,sqrt(2.0*remaining/(route_travel_speed()*TravelPace.BRAKE_SECONDS)))

func _sync_event_previews() -> void:
	if not world or not arena:return
	if arena.scene_mode and not discovery_actor and not FairytaleCatalog.has_scene(route_zone.get("theme","")):
		discovery_actor=preload("res://scripts/battle/enemy_actor.gd").new();add_child(discovery_actor)
	# Resources may be warm, but only the next reachable event owns a world body.
	# An unchosen branch is not part of the player's linear event sequence yet.
	var entries:Array=LocalRouteSpec.entries(route_zone,branch)
	var key:=""
	if encounter_step<entries.size():
		var entry:Dictionary=entries[encounter_step]
		if entry.kind=="battle" and (entry.branch==0 or branch!=0):
			key="%d:%d" % [entry.branch,encounter_step]
			if not event_previews.has(key):
				var texture:Texture2D=load("res://"+FairytaleCatalog.lead_art(route_zone.theme)) if FairytaleCatalog.has_scene(route_zone.get("theme","")) else discovery_actor.texture() if discovery_actor else StyleLibrary.texture("hound")
				var actor:Dictionary={"actor":true,"born_at":elapsed,"edge_strength":0.0,"hidden":false,"position":ForestRoute.point_at(entry.spawn_distance,entry.branch),"texture":texture,"w":70.0*texture.get_width()/float(texture.get_height()),"h":70.0,"flip":false,"kind":0,"id":110000+event_previews.size(),"region":world.plan.at(entry.visual_distance,entry.branch),"route_s":entry.spawn_distance,"wait_s":entry.visual_distance,"spawn_s":entry.spawn_distance,"route_branch":entry.branch,"altitude":0.0,"motion":"static","event_index":encounter_step}
				actor.silhouette=world.assets.silhouette(texture,actor.region.space.atmosphere.depth_color)
				if discovery_actor:actor.live_discovery=true;actor.ground_anchor=Vector2(.5,discovery_actor.ground_uv())
				event_previews[key]=actor;world.sprites.append(actor)
	for preview_key in event_previews:
		var actor:Dictionary=event_previews[preview_key]
		var in_battle:bool=int(actor.event_index)==encounter_step and phase in ["entering","battle","defeat","reviving"]
		actor.hidden=preview_key!=key or in_battle
		actor.edge_strength=0.0
		if not actor.hidden:
			# Fixed world path, sampled from activation time; never chase the camera.
			var duration:=TravelPace.MONSTER_APPROACH_SECONDS
			var t:=clampf((elapsed-float(actor.born_at))/duration,0,1)
			var progress:=t+t*t-t*t*t
			actor.route_s=lerpf(actor.spawn_s,actor.wait_s,progress)
			actor.position=ForestRoute.point_at(actor.route_s,actor.route_branch)
			if discovery_actor:
				var next_animation:="walk" if t<1 else "idle"
				if discovery_actor.state!=next_animation:discovery_actor.play(next_animation)
