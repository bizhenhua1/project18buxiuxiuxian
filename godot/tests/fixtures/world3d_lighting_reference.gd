extends SegmentRenderer
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
