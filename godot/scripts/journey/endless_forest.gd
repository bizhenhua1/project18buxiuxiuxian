extends "res://scripts/journey/expedition_route.gd"
var lap:=1
var test_zone:=""
var between:=0.0
var veil:ColorRect
func _ready() -> void:
	StyleLibrary.active=true
	Journey.SAVE="user://endless-forest-test.json"
	Journey.state=JourneyState.new();Journey.expedition_active=true;Journey.fighting=false
	for zone in Journey.state.zones:zone.theme="forest"
	test_zone=Journey.state.zones[0].id
	Journey.state.pending=test_zone
	super()
	arena.scene_mode=true
	DisplayServer.window_set_title("雾林 · 无限跑图战斗测试")
	veil=ColorRect.new();veil.color=Color(0,0,0,0);veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.z_index=1000;add_child(veil)
func _process(delta:float) -> void:
	super(delta)
	if not arena or paused:return
	if phase=="choose":choose(-1 if lap%2 else 1)
	if phase=="encounter":
		if is_social():resolve("supplies")
		else:start_battle()
	if phase=="defeat" or route_complete:
		between+=delta
		veil.color.a=smoothstep(.30,.48,between)
		if between>=.5:restart_lap()
	else:veil.color.a=move_toward(veil.color.a,0,delta*6)
	title_label.text="无限林径 · 第 %d 轮"%lap
func restart_lap() -> void:
	lap+=1;between=0
	Journey.state.pending=test_zone
	Journey.state.world.input_locked=true
	Journey.state.local_steps.erase(Journey.state.pending)
	Journey.state.cleared.erase(Journey.state.pending)
	Journey.state.route_choices.erase(Journey.state.pending)
	Journey.fighting=false
	for actor in companions:world.sprites.erase(actor)
	if not scene_actor.is_empty():world.sprites.erase(scene_actor)
	companions.clear();scene_actor={};road_actor.companions.clear();road_actor.flight=false
	model.reset();model.enemy.clear();arena.effects.clear();arena.particles.clear();arena.enemies_visible=false
	arena.battle_mix=0;arena.entrance_progress=0;arena.rebuild()
	route_complete=false;encounter_step=0;prepared_step=-1;distance=0;heading=0;camera=Vector2.ZERO
	phase="travel";phase_time=0;moving_envelope=0;notice_left=0
