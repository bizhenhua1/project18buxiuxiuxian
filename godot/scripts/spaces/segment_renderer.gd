class_name SegmentRenderer
extends CorridorRenderer
## Empty during gameplay; the standalone traditional editor supplies effective projection values.
var editor_camera:Dictionary={}
var runtime_camera:Dictionary={}
var environment: Dictionary
var projection_ms:=0.0
var forest_batch:ForestBatch
var combat_lens:=1.0
var presentation_blend:float=-1.0
var team_light_override:Dictionary={}
var lantern_enabled:=false
var travel_eye_offset:=15.0
var travel_lateral:=0.0
var shoulder_lift:=0.0
var battle_frame_shift:=0.0

func set_battle_camera(mix:float,enabled:bool=true) -> void:
	if presentation_blend>=0 and enabled:mix=presentation_blend
	combat_lens=lerpf(1.0,.92,mix) if enabled else 1.0
	shoulder_lift=lerpf(travel_eye_offset,10.0,mix) if enabled else 0.0
	battle_frame_shift=.19*mix if enabled else 0.0
var battle_actors:Array[Dictionary]=[]
var combat_lights:Array[Dictionary]=[]
func bind_combat_lights(shader:ShaderMaterial) -> void:
	var team=team_light()
	shader.set_shader_parameter("team_light_energy",team.road_energy)
	shader.set_shader_parameter("team_light_radius",team.road_radius)
	shader.set_shader_parameter("team_light_color",team.road_color*environment_light_tint())
	var positions:=PackedVector4Array();positions.resize(4)
	var colors:=PackedColorArray();colors.resize(4);colors.fill(Color(0,0,0,0))
	for i in range(mini(4,combat_lights.size())):
		var light:Dictionary=combat_lights[i]
		positions[i]=Vector4(light.position.x,light.position.y,light.position.z,light.radius)
		colors[i]=Color(light.color,light.energy)
	shader.set_shader_parameter("combat_light_positions",positions)
	shader.set_shader_parameter("combat_light_colors",colors)
var biome_light_cache:=PackedVector4Array()
var biome_light_clock:=-1.0
func bind_biome(material:ShaderMaterial) -> void:
	var scene:=world as SegmentWorld
	var key:=str(scene.camera_region.space.key)
	var catalog=preload("res://scripts/spaces/biome_catalog.gd")
	var active:bool=key in catalog.CONFIG
	material.set_shader_parameter("enemy_scene_tint",enemy_light_tint())
	material.set_shader_parameter("environment_light_tint",environment_light_tint())
	material.set_shader_parameter("biome_kind",catalog.TITLES.keys().find(key)+1 if active else 0)
	if not active:return
	if FairytaleCatalog.has_scene(key):material.set_shader_parameter("fairytale_mist_color",Color(FairytaleCatalog.entry(key).fog))
	if absf(elapsed-biome_light_clock)>.2 or biome_light_cache.is_empty():
		biome_light_clock=elapsed
		var nearby:Array=scene.biome_lights.filter(func(p):return Vector2(p.x,p.z).distance_squared_to(camera_world)<360000)
		nearby.sort_custom(func(a,b):return Vector2(a.x,a.z).distance_squared_to(camera_world)<Vector2(b.x,b.z).distance_squared_to(camera_world))
		biome_light_cache=PackedVector4Array(nearby.slice(0,4));biome_light_cache.resize(4)
	material.set_shader_parameter("biome_lights",biome_light_cache)
	material.set_shader_parameter("biome_glow_color",catalog.CONFIG[key].color)

func team_light() -> Dictionary:
	return preload("res://scripts/battle/team_lighting.gd").sample(clampf(battle_frame_shift/.19,0,1),team_light_override)
func lantern_position() -> Vector3:
	var light=team_light()
	var anchor:=camera_world+Vector2(sin(heading),cos(heading))*float(light.road_z)+Vector2(cos(heading),-sin(heading))*float(light.road_x)
	return Vector3(anchor.x,float(light.road_y)+sin(elapsed*6.4)*.6,anchor.y)

func enemy_light_position() -> Vector3:
	var progress:=clampf(battle_frame_shift/.19,0,1)
	var anchor:=camera_world+Vector2(sin(heading),cos(heading))*(210+16*progress)
	return Vector3(anchor.x,30,anchor.y)

func enemy_light_strength() -> float:
	# Keep discovery illumination through combat; do not add a second colored floodlight.
	return 0.0

func camera_height() -> float:
	if not editor_camera.is_empty():return float(editor_camera.height)
	if not runtime_camera.is_empty():return float(runtime_camera.height)
	return float(ForestSettings.values.get("camera_height",58.0))+shoulder_lift if StyleLibrary.active else 58.0

func focal() -> float:
	if not editor_camera.is_empty():return super()*float(editor_camera.lens)
	if not runtime_camera.is_empty():return super()*float(runtime_camera.lens)
	return super()*combat_lens*float(ForestSettings.values.get("camera_lens",1.0)) if StyleLibrary.active else super()

func horizon_y() -> float:
	if not editor_camera.is_empty():return view_size.y*float(editor_camera.horizon)
	if not runtime_camera.is_empty():return view_size.y*float(runtime_camera.horizon)
	# Lens shift preserves upright cutout sprites; this is not a pitched 3D camera.
	return super()+view_size.y*(float(ForestSettings.values.get("camera_horizon",.48))-.48-battle_frame_shift) if StyleLibrary.active else super()


func _draw_ridge(cx: float, hy: float, f: float) -> void:
	if (environment.a.far_ridge_enabled and environment.weight < 1) or (environment.b.far_ridge_enabled and environment.weight > 0):
		super(cx, hy, f)

func _draw() -> void:
	if not world: return
	var t0 := Time.get_ticks_usec()
	var scene := world as SegmentWorld
	environment = scene.environment()
	var closed := 0.0 if scene.camera_region.space.sky_enabled else 1.0
	# Visibility is physical. Lighting may blend, but a closed interior cannot reveal the outdoor landmark.
	var f := focal()
	var hy := horizon_y()
	var cx := view_size.x * 0.5
	landmark_markers.clear()
	world.atmosphere = scene.fields[environment.b.get_instance_id()]
	if closed < 1:
		super._draw_distance(cx, hy, f)
	if closed > 0 and scene.camera_region.space.key!=&"crystal":
		var color: Color = environment.b.top_color if not environment.b.sky_enabled else environment.a.top_color
		draw_rect(Rect2(0, 0, view_size.x, hy + 1), Color(color, closed))
	for pair in [[environment.a, 1.0 - environment.weight], [environment.b, environment.weight]]:
		var field: SkyField = scene.fields[pair[0].get_instance_id()]
		var profile := field.profile
		draw_texture_rect(field.horizon_texture, Rect2(0, hy - view_size.y * profile.horizon_up, view_size.x, view_size.y * (profile.horizon_up + profile.horizon_down)), false, Color(1,1,1,pair[1]))
	# Physical entrance silhouette is behind interior geometry, but before outside trees.
	for region in scene.plan.regions:
		if not region.space.ceiling_enabled or region.start < 1000: continue
		var p := ForestRoute.to_camera(ForestRoute.point_at(region.start, region.branch), camera_world, heading)
		if p.y <= 20: continue
		var scale := f / p.y
		var foot := Vector2(cx + p.x * scale, hy + minf(camera_height() * scale, 8.0))
		var w := region.space.shell_width * scale * 0.43
		var h := region.space.ceiling_height * scale * 0.90
		var points := PackedVector2Array([foot + Vector2(-w, 0)])
		for i in range(33):
			var angle := PI - i * PI / 32.0
			points.append(foot + Vector2(cos(angle) * w, -sin(angle) * h))
		points.append(foot + Vector2(w, 0))
		draw_colored_polygon(points, region.space.atmosphere.depth_color)
	if StyleLibrary.active and scene.plan.regions.all(func(region):return region.space.key in [&"forest",&"crystal",&"swamp",&"sewer",&"whale",&"palace"] or FairytaleCatalog.has_scene(str(region.space.key))):
		if forest_batch==null:
			forest_batch=ForestBatch.new();add_child(forest_batch)
			forest_batch.setup(world.sprites)
		forest_batch.sync(self)
		last_draw_ms=(Time.get_ticks_usec()-t0)/1000.0
		return
	var projection_start:=Time.get_ticks_usec()
	var items := _project_space(cx, hy, f)
	projection_ms=(Time.get_ticks_usec()-projection_start)/1000.0
	visible_count = items.size()
	for item in items:
		var s: Dictionary = item.sprite
		var rect: Rect2 = item.rect
		if s.has("rustle_started"):
			var age := elapsed-float(s.rustle_started)
			if age >= 0 and age < .42:
				var angle := sin(age*32)*.10*pow(1-age/.42,2)*float(s.rustle_strength)
				var foot := Vector2(rect.get_center().x,rect.end.y)
				draw_set_transform(foot,angle,Vector2(-1 if s.flip else 1,1))
				_draw_fogged(s.texture,Rect2(-rect.size.x/2,-rect.size.y,rect.size.x,rect.size.y),item)
				draw_set_transform(Vector2.ZERO)
				continue
		if s.get("actor",false) and not s.has("transition_rect"):
			var foot := Vector2(rect.get_center().x,rect.end.y)
			draw_set_transform(foot,0,Vector2(1,.22))
			draw_circle(Vector2.ZERO,rect.size.x*.4,Color(0,0,0,.22*item.tint.a))
			draw_set_transform(Vector2.ZERO)
		if s.flip:
			draw_set_transform(Vector2(rect.position.x + rect.size.x, rect.position.y), 0, Vector2(-1,1))
			_draw_fogged(s.texture, Rect2(Vector2.ZERO, rect.size), item)
			draw_set_transform(Vector2.ZERO)
		else: _draw_fogged(s.texture, rect, item)
	last_draw_ms = (Time.get_ticks_usec() - t0) / 1000.0

func _project_space(cx: float, hy: float, f: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var depth_order:Array[Vector2]=[]
	var scene := world as SegmentWorld
	var co:=cos(heading)
	var si:=sin(heading)
	var eye:=camera_height()
	var terrain_camera:=ForestEcology.height_at(camera_world) if StyleLibrary.active else 0.0
	for sprite in world.sprites:
		if sprite.get("hidden",false): continue
		var position: Vector2 = sprite.position
		var delta:Vector2=position-camera_world
		var z:=delta.x*si+delta.y*co
		if z <= 10 or z >= 1700:continue
		var rx:=delta.x*co-delta.y*si
		var scale:=f/z
		# Reject horizontally before any height, color or attachment work.
		if absf(rx*scale)>view_size.x*.5+float(sprite.w)*scale:continue
		var altitude: float = sprite.altitude
		if StyleLibrary.active:
			if not sprite.has("terrain_unit"):sprite.terrain_unit=2.2*sin(position.y*.009)+1.3*sin(position.x*.017+position.y*.004)
			altitude += float(sprite.terrain_unit)*float(ForestSettings.values.height)-terrain_camera
		if sprite.motion == "sea": position.x += sin(elapsed * 0.055 + sprite.route_s * 0.001) * 5.0
		if sprite.motion == "floater": altitude += sin(elapsed * 0.65 + sprite.id) * 5.0
		if sprite.motion == "sea":
			delta=position-camera_world
			rx=delta.x*co-delta.y*si
			z=delta.x*si+delta.y*co
			scale=f/z
		var squash: Vector2 = sprite.get("squash",Vector2.ONE)
		var w: float = sprite.w * scale*squash.x
		var h: float = sprite.h * scale*squash.y
		var sx := cx + rx * scale
		var sy := hy + (eye - altitude) * scale
		var anchor:Vector2=sprite.get("ground_anchor",Vector2(.5,1))
		if sprite.flip:anchor.x=1-anchor.x
		var projected:=Rect2(sx-w*anchor.x,sy-h*anchor.y,w,h)
		if projected.end.x < -20 or projected.position.x > view_size.x + 20 or projected.position.y > view_size.y or projected.end.y < 0: continue
		var style: SpaceType = sprite.region.space
		var dark := smoothstep(style.depth_start, style.depth_end, z) * 0.94
		var alpha := 1.0 - smoothstep(1400, 1700, z)
		if sprite.get("actor",false): alpha *= smoothstep(0,.35,elapsed-float(sprite.get("born_at",-1)))
		var tint := style.ambient
		tint *= sprite.get("ecology_tint",Color.WHITE)
		# Target-color compositing uses an alpha-preserving silhouette pass.
		depth_order.append(Vector2(-z,result.size()))
		result.append({"sprite": sprite, "depth": z, "rect": sprite.get("transition_rect",projected), "tint": Color(tint, alpha), "fog": dark, "target": style.atmosphere.depth_color})
	depth_order.sort()
	var sorted:Array[Dictionary]=[]
	sorted.resize(result.size())
	for i in range(depth_order.size()):sorted[i]=result[int(depth_order[i].y)]
	return sorted

func _draw_fogged(texture: Texture2D, rect: Rect2, item: Dictionary) -> void:
	# Opaque-color silhouette preserves alpha edges and blends continuously by depth.
	draw_texture_rect(texture, rect, false, item.tint)
	var silhouette: Texture2D = item.sprite.silhouette
	if item.fog>.001:draw_texture_rect(silhouette, rect, false, Color(1,1,1,item.fog * item.tint.a))
	# Root attachments share the tree transform, but can be offscreen independently.
	var world_rect:Rect2=item.rect
	if world_rect.position.y+world_rect.size.y*.92>view_size.y+world_rect.size.y*.06:return
	for cover in item.sprite.get("root_cover",[]):
		var tex:Texture2D=cover.texture
		var h:float=rect.size.y*cover.height
		if h<3:continue
		var w:float=h*tex.get_width()/float(tex.get_height())
		var box:=Rect2(rect.position.x+rect.size.x*cover.x-w*.5,rect.position.y+rect.size.y*cover.foot_y-h,w,h)
		draw_texture_rect(tex,box,false,item.tint)
		if item.fog>.001:draw_texture_rect(cover.silhouette,box,false,Color(1,1,1,item.fog*item.tint.a))



func enemy_light_tint() -> Color:
	return preload("res://scripts/spaces/biome_catalog.gd").enemy_light_tint(str(world.camera_region.space.key))

func environment_light_tint() -> Color:
	return preload("res://scripts/spaces/biome_catalog.gd").environment_light_tint(str(world.camera_region.space.key),.10)
