extends "res://scripts/journey/expedition_route.gd"
var lap:=1
var test_zone:=""
var between:=0.0
var veil:ColorRect
var biome_key:="forest"
var junction_wait:=0.0
var center_exit:Button
func _ready() -> void:
	StyleLibrary.active=true
	lap=int(get_tree().get_meta("tour_lap",1))
	biome_key=str(get_tree().get_meta("tour_biome","forest"))
	Journey.SAVE="user://endless-forest-test.json"
	Journey.state=JourneyState.new();Journey.expedition_active=true;Journey.fighting=false
	for zone in Journey.state.zones:
		zone.theme=biome_key
		zone.route_kind="fork"
		zone.exits=int(get_tree().get_meta("tour_exits",2 if lap%2 else 3))
	test_zone=Journey.state.zones[0].id
	Journey.state.pending=test_zone
	super()
	center_exit=AdventureSkin.button("直行 ↑",func():choose(2))
	left_button.get_parent().add_child(center_exit)
	left_button.get_parent().move_child(center_exit,right_button.get_index())
	arena.scene_mode=true
	DisplayServer.window_set_title("雾林 · 无限跑图战斗测试")
	veil=ColorRect.new();veil.color=Color(0,0,0,0);veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.z_index=1000;add_child(veil)
	if biome_key!="forest":
		for link in leave_button.pressed.get_connections():leave_button.pressed.disconnect(link.callable)
		leave_button.text="场景目录"
		leave_button.pressed.connect(func():get_tree().change_scene_to_file("res://scenes/biome_hub.tscn"))
func _process(delta:float) -> void:
	super(delta)
	if not arena or paused:return
	center_exit.visible=phase=="choose" and world.plan.exits==3
	if phase=="choose":
		left_button.text="← 左路";right_button.text="右路 →"
		event_panel.position.y=size.y-235
		event_box.position=event_panel.position+Vector2(24,12)
		junction_wait+=delta
		event_title.text="%s岔路口"%("三" if world.plan.exits==3 else "两")
		event_text.text="可点击或用方向键选路，即将自动继续。"
		if junction_wait>=1.2:choose(([ -1,2,1 ][floori(lap/2.0)%3]) if world.plan.exits==3 else (-1 if lap%4==1 else 1))
	if phase=="encounter":
		if is_social():resolve("supplies")
		else:start_battle()
	if phase=="defeat" or route_complete:
		between+=delta
		veil.color.a=smoothstep(.30,.48,between)
		if between>=.5:restart_lap()
	else:veil.color.a=move_toward(veil.color.a,0,delta*6)
	var title:String=preload("res://scripts/spaces/biome_catalog.gd").TITLES.get(biome_key,"无限林径")
	title_label.text="%s · 第 %d 轮"%[title,lap]
	if biome_key!="forest":leave_button.text="场景目录"
func restart_lap() -> void:
	get_tree().set_meta("tour_lap",lap+1)
	get_tree().call_deferred("change_scene_to_file","res://scenes/endless_forest.tscn")
	set_process(false)

func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_UP and phase=="choose" and world.plan.exits==3:
		choose(2)
		get_viewport().set_input_as_handled()
	else:super(event)
