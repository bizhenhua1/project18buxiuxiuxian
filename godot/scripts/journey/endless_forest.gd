extends "res://scripts/journey/expedition_route.gd"
var lap:=1
var test_zone:=""
var biome_key:="forest"
var center_exit:Button
var restart_button:Button
var changing_leg:=false
var route_cache:Dictionary={}
var pending_world:SegmentWorld
var pending_index:=0
var pending_source:SegmentWorld
var pending_connection:Dictionary={}
var pending_distance:=0.0
func _ready() -> void:
	StyleLibrary.active=true
	lap=1
	biome_key=str(get_tree().get_meta("tour_biome","forest"))
	Journey.SAVE="user://endless-forest-test.json"
	Journey.state=JourneyState.new();Journey.expedition_active=true;Journey.fighting=false
	for zone in Journey.state.zones:
		zone.combat_only=true
		zone.battle_choice=true
		zone.battle_hp_multiplier=5.0
		zone.theme=biome_key
		zone.route_kind="fork"
		zone.event_placement="after"
		zone.exits=int(get_tree().get_meta("tour_exits",2 if lap%2 else 3))
	test_zone=Journey.state.zones[0].id
	Journey.state.pending=test_zone
	super()
	_warm_route_cache()
	restart_button=AdventureSkin.button("从头开始",restart_from_beginning)
	restart_button.z_index=100;add_child(restart_button)
	center_exit=AdventureSkin.button("直行 ↑",func():choose(2))
	left_button.get_parent().add_child(center_exit)
	left_button.get_parent().move_child(center_exit,right_button.get_index())
	arena.scene_mode=true
	DisplayServer.window_set_title("雾林 · 无限跑图战斗测试")
	if biome_key!="forest":
		for link in leave_button.pressed.get_connections():leave_button.pressed.disconnect(link.callable)
		leave_button.text="场景目录"
		leave_button.pressed.connect(func():get_tree().change_scene_to_file("res://scenes/biome_hub.tscn"))
func _process(delta:float) -> void:
	super(delta)
	if not arena:return
	restart_button.position=Vector2(size.x-245,20);restart_button.size=Vector2(105,40)
	if changing_leg:return
	_prepare_extension_slice()
	if phase=="clearing" and encounter_step>=stops().size():
		for view in views:
			if view.renderer.forest_batch:view.renderer.forest_batch.quiesce_ordering()
	center_exit.visible=phase=="choose" and world.plan.exits==3
	if phase=="choose":
		left_button.text="← 左路";right_button.text="右路 →"
		event_panel.position.y=size.y-235
		event_box.position=event_panel.position+Vector2(24,12)
		event_title.text="%s岔路口"%("三" if world.plan.exits==3 else "两")
		event_text.text="请选择前进方向；这里会一直等待你的选择。"
	if phase=="travel" and encounter_step>=stops().size():append_leg()
	var title:String=preload("res://scripts/spaces/biome_catalog.gd").TITLES.get(biome_key,"无限林径")
	title_label.text="%s · 第 %d 路段"%[title,lap]
	if biome_key!="forest":leave_button.text="场景目录"
func append_leg() -> void:
	# Extend the same world at the current physical pose; never reset the camera,
	# animations, elapsed time, distance, player state or scene tree.
	var connection:Dictionary=ForestRoute.pose(distance,branch)
	var retained:Array[Dictionary]=[]
	for sprite in world.sprites:
		if sprite.get("actor",false):continue
		var local:Vector2=ForestRoute.to_camera(sprite.position,connection.position,connection.heading)
		if local.y>=-200 and local.y<120:retained.append(sprite)
	lap+=1
	var zone:Dictionary=Journey.state.active_zone()
	zone.endless_leg=lap;zone.endless_offset=distance
	zone.event_placement="after"
	zone.exits=3 if lap%2==0 else 2
	route_zone=zone.duplicate(true);route_spec=LocalRouteSpec.profile(route_zone)
	ForestRoute.origin=connection.position;ForestRoute.origin_s=distance;ForestRoute.origin_heading=connection.heading
	var next_plan:=LocalRouteSpec.plan(route_zone)
	var next_world:SegmentWorld
	if pending_world and pending_index>=pending_source.sprites.size():
		next_world=pending_world
		next_plan=next_world.plan
	else:
		# Manual fast-forward may bypass every preparation frame.
		while not pending_world or pending_index<pending_source.sprites.size():_prepare_extension_slice(true)
		next_world=pending_world;next_plan=next_world.plan
	pending_world=null;pending_source=null;pending_index=0
	for sprite in retained:sprite.region=next_plan.regions[0]
	next_world.sprites.append_array(retained)
	world=next_world
	for view in views:
		view.renderer.world=world
		if view.renderer.forest_batch:view.renderer.forest_batch.replace_scenery(world.sprites)
		var shader:ShaderMaterial=view.ground_material
		shader.set_shader_parameter("junction",ForestRoute.JUNCTION)
		shader.set_shader_parameter("turn_length",ForestRoute.TURN_LENGTH)
		shader.set_shader_parameter("three_way",next_plan.exits==3)
		var regions:=PackedVector4Array()
		for region in next_plan.regions:regions.append(Vector4(region.start,region.end,region.branch,0))
		shader.set_shader_parameter("region_count",regions.size());regions.resize(12);shader.set_shader_parameter("regions",regions)
	travel_leg_origin=distance;travel_leg_fork=false;opening_leg=false
	branch=0;encounter_step=0;prepared_step=-1
	Journey.state.local_steps[Journey.state.pending]=0
	Journey.state.route_choices.erase(Journey.state.pending)
	scene_actor={};event_previews.clear();companions.clear();arena.scene_enemy_sources.clear()
	phase="travel";route_complete=false;fork_transit_time=FORK_TRANSIT_SECONDS
	world.update_camera(distance,0)
	_ensure_event_preview()
	for view in views:view.sync(camera,heading,elapsed,moving_envelope,branch,labels,bob,distance)


func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_UP and phase=="choose" and world.plan.exits==3:
		choose(2)
		get_viewport().set_input_as_handled()
	else:super(event)


func restart_from_beginning() -> void:
	if changing_leg:return
	_prepare_extension_slice()
	changing_leg=true
	for key in ["tour_party","tour_stones"]:
		if get_tree().has_meta(key):get_tree().remove_meta(key)
	get_tree().set_meta("tour_lap",1)
	get_tree().call_deferred("change_scene_to_file","res://scenes/endless_forest.tscn")
	set_process(false)

func _warm_route_cache() -> void:
	# Generate static layouts and their texture variants during initial loading only.
	var saved_origin:Vector2=ForestRoute.origin
	var saved_s:float=ForestRoute.origin_s
	var saved_heading:float=ForestRoute.origin_heading
	for placement in ["before","after"]:
		for exits in [2,3]:
			var zone:Dictionary=route_zone.duplicate(true)
			zone.endless_leg=2;zone.endless_offset=0;zone.event_placement=placement;zone.exits=exits
			ForestRoute.reset_frame()
			var cached:=SegmentWorld.new(art,LocalRouteSpec.plan(zone))
			for sprite in cached.sprites:
				sprite.silhouette=cached.assets.silhouette(sprite.texture,sprite.region.space.atmosphere.depth_color)
			route_cache["%s:%d" % [placement,exits]]=cached
	ForestRoute.origin=saved_origin;ForestRoute.origin_s=saved_s;ForestRoute.origin_heading=saved_heading
	LocalRouteSpec.plan(route_zone)

func _prepare_extension_slice(force:=false) -> void:
	if branch==0 and not force:return
	if not pending_world:
		pending_distance=float(stops()[-1])+EXIT_ADVANCE
		pending_connection=ForestRoute.pose(pending_distance,branch)
		var zone:Dictionary=route_zone.duplicate(true)
		zone.endless_leg=lap+1;zone.endless_offset=pending_distance
		zone.event_placement="after";zone.exits=3 if (lap+1)%2==0 else 2
		var old_junction:float=ForestRoute.JUNCTION;var old_pause:float=ForestRoute.PAUSE_AT;var old_turn:float=ForestRoute.TURN_LENGTH
		var plan:=LocalRouteSpec.plan(zone)
		ForestRoute.JUNCTION=old_junction;ForestRoute.PAUSE_AT=old_pause;ForestRoute.TURN_LENGTH=old_turn
		pending_world=SegmentWorld.new(art,plan,true)
		pending_source=route_cache["%s:%d" % [zone.event_placement,zone.exits]]
		pending_world.assets=pending_source.assets
		for light in pending_source.biome_lights:
			var point:Vector2=pending_connection.position+Vector2(light.x,light.y).rotated(-pending_connection.heading)
			pending_world.biome_lights.append(Vector4(point.x,point.y,light.z,light.w))
	var limit:=mini(pending_index+96,pending_source.sprites.size())
	while pending_index<limit:
		var source:Dictionary=pending_source.sprites[pending_index]
		pending_index+=1
		if source.position.y<120:continue
		var sprite:Dictionary=source.duplicate()
		sprite.id=1000000+lap*20000+pending_index
		sprite.position=pending_connection.position+source.position.rotated(-pending_connection.heading)
		sprite.route_s=float(source.route_s)+pending_distance
		sprite.region=pending_world.plan.regions.filter(func(region):return region.branch==source.region.branch)[0]
		if sprite.has("plane_heading"):sprite.plane_heading+=pending_connection.heading
		pending_world.sprites.append(sprite)
