class_name IslandView3D
extends SubViewportContainer
const HEIGHT := 22.0/(112.0*0.8660254038)
const BASE_DEPTH := 1.15
const CLEAR_SECONDS := 0.85
var bedrock_y := 0.0
var model: IslandModel
var assets: IslandAssets
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var tiles := {}
var hero: Node
var outline: MeshInstance3D
var ghost_body: MeshInstance3D
var ghost_prop: MeshInstance3D
var selection_union: ColorRect
var passage_markers:Array[Dictionary]=[]
func setup(state: IslandModel, library: IslandAssets) -> void:
	model = state
	assets = library
	stretch = true
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2a241c")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("99adbb")
	env.environment.ambient_light_energy=.45
	world.add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 100.0
	camera.position = Vector3(0,10,17.320508)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	model.map_changed.connect(rebuild)
	rebuild()
	selection_union = ColorRect.new()
	selection_union.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_union.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_union.material = ShaderMaterial.new()
	selection_union.material.shader = preload("res://shaders/island_selection_union.gdshader")
	add_child(selection_union)
	selection_union.visible = false
	var selector:=OptionButton.new();selector.position=Vector2(12,12);selector.custom_minimum_size=Vector2(230,36)
	for entry in preload("res://scripts/spaces/character_library.gd").MODELS:selector.add_item("主角 · "+entry.name)
	selector.select(hero.selected_model);selector.item_selected.connect(func(index):hero.select_model(index,not model.get_meta("traversal_demo",false)))
	add_child(selector)
	if not model.get_meta("traversal_demo",false):
		var test:=Button.new();test.text="海浪 / 高台 / 洞口测试";test.position=Vector2(255,12);add_child(test)
		test.pressed.connect(func():
			var demo=preload("res://scripts/world/island_traversal_demo.gd").new();get_tree().root.add_child(demo))
	mouse_exited.connect(func():model.hover = Vector2i(-999,-999))
func surface(path: String, color := Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/island_surface.gdshader")
	mat.set_shader_parameter("textured",not path.is_empty())
	mat.set_shader_parameter("tint",color)
	if not path.is_empty(): mat.set_shader_parameter("art",assets.texture(path))
	return mat
func billboard(path: String, width: float, foot: float) -> MeshInstance3D:
	var tex := assets.texture(path)
	var height := width*tex.get_height()/tex.get_width()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width,height)
	mesh.center_offset = Vector3(0,height/2-foot,0)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = surface(path)
	instance.material_override.shader = preload("res://shaders/island_billboard.gdshader")
	instance.material_override.set_shader_parameter("art",tex)
	instance.basis = camera.basis
	world.add_child(instance)
	return instance
func top_mesh(path: String) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3(.5,.002,0),Vector3(0,.002,.5),Vector3(-.5,.002,0),Vector3(0,.002,-.5)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = assets.diamond_uv(path)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1,0,3,2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
func rebuild() -> void:
	for marker in passage_markers:
		marker.node.queue_free();marker.button.queue_free()
	passage_markers.clear()
	for tile in tiles.values():
		tile.root.queue_free()
		if tile.prop: tile.prop.queue_free()
		if tile.get("event_actor") != null: tile.event_actor.queue_free()
	tiles.clear()
	if is_instance_valid(hero) and not model.get_meta("traversal_demo",false):
		hero.queue_free();hero=null
	if is_instance_valid(outline): outline.queue_free()
	if is_instance_valid(ghost_body): ghost_body.queue_free()
	if is_instance_valid(ghost_prop): ghost_prop.queue_free()
	bedrock_y = INF
	for cell in model.cells: bedrock_y = minf(bedrock_y,float(cell.h)*HEIGHT-BASE_DEPTH)
	for cell in model.cells:
		var root := Node3D.new()
		world.add_child(root)
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		var depth := float(cell.h)*HEIGHT-bedrock_y
		box.size = Vector3(sqrt(.5),depth,sqrt(.5))
		body.mesh = box
		if model.get_meta("traversal_demo",false) and cell.layer!="water":body.mesh=exterior_box(box,cell)
		body.position.y = -depth/2
		body.rotation.y = PI/4
		body.material_override = surface("",IslandAssets.side_colors(cell.base)[0])
		body.material_override.shader = preload("res://shaders/island_cliff.gdshader")
		body.material_override.set_shader_parameter("themed_art",cell.has("cliff"))
		body.material_override.set_shader_parameter("art",assets.texture(cell.get("cliff","assets/cave/ground-tile.png")))
		body.material_override.set_shader_parameter("depth",depth)
		body.material_override.set_shader_parameter("top_height",float(cell.h)*HEIGHT)
		body.material_override.set_shader_parameter("upper_fade_height",float(cell.get("upper_fade",0.0)))
		body.material_override.set_shader_parameter("hole_radius",.24 if cell.get("hole",false) else 0.0)
		body.material_override.set_shader_parameter("water_body",cell.get("layer","")=="water")
		body.material_override.set_shader_parameter("solid_fade",model.get_meta("traversal_demo",false) and cell.layer!="water")
		body.material_override.set_shader_parameter("silhouette_background",Color("2a241c"))
		body.material_override.set_shader_parameter("grid_origin",Vector2(-float(cell.r),float(cell.c))*sqrt(.5))
		body.material_override.set_shader_parameter("fog_origin",IslandModel.wxz(cell.c,cell.r))
		root.add_child(body)
		var top := MeshInstance3D.new()
		top.mesh = top_mesh(cell.base)
		top.material_override = surface(cell.base)
		top.material_override.set_shader_parameter("hole_radius",.24 if cell.get("hole",false) else 0.0)
		root.add_child(top)
		if cell.get("hole",false):
			var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.23;torus.outer_radius=.30;ring.mesh=torus
			var stone:=StandardMaterial3D.new();stone.albedo_color=Color("444641");ring.material_override=stone;ring.position.y=.025;root.add_child(ring)
			var dark:=MeshInstance3D.new();var disc:=CylinderMesh.new();disc.top_radius=.235;disc.bottom_radius=.235;disc.height=.015;dark.mesh=disc
			var black:=StandardMaterial3D.new();black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;black.albedo_color=Color("050709");dark.material_override=black;dark.position.y=-.07;root.add_child(dark)
		var waterfall: MeshInstance3D = null
		if not cell.get("waterfall_edges",[]).is_empty():
			waterfall=make_waterfall(cell.waterfall_edges,depth)
			waterfall.material_override.set_shader_parameter("origin",IslandModel.wxz(cell.c,cell.r))
			waterfall.material_override.set_shader_parameter("surface_height",float(cell.h)*HEIGHT)
			root.add_child(waterfall)
		var prop: MeshInstance3D = null
		if cell.feat != null: prop = billboard(cell.feat.src,cell.feat.w,0)
		var fog := MeshInstance3D.new()
		fog.mesh = QuadMesh.new()
		fog.position.y = 0.006
		fog.material_override = ShaderMaterial.new()
		fog.material_override.shader = preload("res://shaders/island_fog_union.gdshader")
		fog.material_override.set_shader_parameter("origin",IslandModel.wxz(cell.c,cell.r))
		root.add_child(fog)
		var wisp := MeshInstance3D.new()
		var wisp_mesh := QuadMesh.new()
		wisp_mesh.size = Vector2(1.12,0.56)
		wisp.mesh = wisp_mesh
		wisp.material_override = fog.material_override.duplicate()
		wisp.material_override.shader = preload("res://shaders/island_fog.gdshader")
		wisp.material_override.set_shader_parameter("wisp",true)
		root.add_child(wisp)
		var known: bool = model.style(IslandModel.key(cell)).known
		tiles[IslandModel.key(cell)] = {"root":root,"body":body,"top":top,"prop":prop,"path":cell.base,"cell":cell,"fog":fog,"wisp":wisp,"was_known":known,"clear_t":CLEAR_SECONDS if known else 0.0,"waterfall":waterfall}
	if not is_instance_valid(hero):
		hero=preload("res://scripts/world/island_hero.gd").new()
		world.add_child(hero)
	for link in model.traversal.links:
		var marker:=Node3D.new();world.add_child(marker)
		var button:=Button.new();button.text=link.label;button.modulate=Color("b8eddf");add_child(button)
		button.pressed.connect(func():model.traversal.request(model,link.id))
		passage_markers.append({"node":marker,"link":link,"button":button})
	outline = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 127
	mat.albedo_color = Color(Color("c5e9a5"),.98)
	outline.material_override = mat
	world.add_child(outline)
	ghost_body = MeshInstance3D.new()
	ghost_prop = MeshInstance3D.new()
	for ghost in [ghost_body,ghost_prop]:
		var ghost_material := ShaderMaterial.new()
		ghost_material.shader = preload("res://shaders/island_xray_3d.gdshader")
		ghost_material.render_priority = 126
		ghost.material_override = ghost_material
		world.add_child(ghost)
	ghost_body.material_override.shader = preload("res://shaders/island_selection_head.gdshader")
func world_position(c: float,r: float,h: float) -> Vector3:
	var p := (IslandModel.wxz(c,r)-model.pivot).rotated(model.angles().x)
	return Vector3(p.x,(h+model.wave_height(c,r))*HEIGHT,p.y)
func exterior_box(box:BoxMesh,cell:Dictionary)->ArrayMesh:
	var arrays:=box.get_mesh_arrays()
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var source:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var indices:=PackedInt32Array()
	for i in range(0,source.size(),3):
		var n:Vector3=normals[source[i]]
		# The cube rotates 45 degrees: local +X is grid -R; local +Z is grid +C.
		var offset:=Vector2i(0,-int(sign(n.x))) if absf(n.x)>.5 else Vector2i(int(sign(n.z)),0)
		var neighbor:Dictionary=model.lookup.get(IslandModel.key(cell)+offset,{})
		if absf(n.y)<.5 and not neighbor.is_empty() and neighbor.layer!="water" and float(neighbor.h)>=float(cell.h):continue
		indices.append_array(source.slice(i,i+3))
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func make_waterfall(edges: Array, depth: float) -> MeshInstance3D:
	var corners:=[Vector3(.5,.008,0),Vector3(0,.008,.5),Vector3(-.5,.008,0),Vector3(0,.008,-.5)]
	var pairs:=[[0,1],[2,3],[1,2],[3,0]]
	var vertices:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for edge in edges:
		# Full-width faces share corner positions; no uncovered strip at the turn.
		var a: Vector3=corners[pairs[edge][0]]*1.006
		var b: Vector3=corners[pairs[edge][1]]*1.006
		var offset:=vertices.size()
		vertices.append_array(PackedVector3Array([a,b,b+Vector3.DOWN*depth,a+Vector3.DOWN*depth]))
		uvs.append_array(PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]))
		for index in [0,1,2,0,2,3]: indices.append(offset+index)
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	instance.material_override=ShaderMaterial.new()
	instance.material_override.shader=preload("res://shaders/island_waterfall.gdshader")
	return instance
func fog_burst(parent: Node3D, event_tile:=false) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 48 if event_tile else 28
	particles.lifetime = 1.35 if event_tile else .9
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.35
	particles.direction = Vector3.UP
	particles.spread = 85.0
	particles.gravity = Vector3(0,0.3,0)
	particles.initial_velocity_min = 0.45
	particles.initial_velocity_max = 1.0 if event_tile else .75
	particles.scale_amount_min = 0.25
	particles.scale_amount_max = .55 if event_tile else .4
	var gradient := Gradient.new()
	gradient.set_color(0,Color.WHITE)
	gradient.set_color(1,Color(1,1,1,0))
	particles.color_ramp = gradient
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = ShaderMaterial.new()
	quad.material.shader = preload("res://shaders/island_fog_particle.gdshader")
	particles.mesh = quad
	particles.position = Vector3(0,0.1,0)
	parent.add_child(particles)
	particles.basis = parent.basis.inverse()*camera.basis
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
func _process(_dt: float) -> void:
	if not model or size.y < 1: return
	camera.size = size.y/(112*model.zoom)
	camera.v_offset = ((size.y*.36+22*model.zoom)-size.y*.5)/(112*model.zoom)
	for marker in passage_markers:
		var link:Dictionary=marker.link
		var a:=world_position(link.from.x,link.from.y,model.lookup[link.from].h)
		var b:=world_position(link.to.x,link.to.y,link.get("exit_height",model.lookup.get(link.to,{}).get("h",model.lookup[link.from].h)))
		marker.node.position=a.lerp(b,.30)+Vector3(0,.22,0)
		marker.node.visible=model.explored.has(link.from) or model.preview_all
		marker.button.visible=marker.node.visible and not model.input_locked
		marker.button.position=camera.unproject_position(marker.node.position)-marker.button.size*.5
	for position_value in tiles:
		var tile: Dictionary = tiles[position_value]
		var cell: Dictionary = tile.cell
		var style := model.style(position_value)
		var event_visible: bool = model.blocked.has(position_value) and model.explored.has(position_value)
		if event_visible and tile.get("event_actor") == null:
			var event_texture := assets.texture(model.blocked[position_value].art)
			var event_width := minf(.72,1.0*event_texture.get_width()/event_texture.get_height()) if StyleLibrary.active else .72
			tile.event_actor = billboard(model.blocked[position_value].art,event_width,0)
		if tile.get("event_actor") != null:
			tile.event_actor.visible=event_visible
			tile.event_actor.position=world_position(cell.c,cell.r,cell.h)+camera.basis.z*.015
			if model.ambush_position==position_value and model.ambush_elapsed<1.1:
				var target:=world_position(model.player.x,model.player.y,model.lookup[model.player].h)
				var direction:Vector3=(target-tile.event_actor.position).normalized()
				var pulse:=sin(clampf(model.ambush_elapsed/(IslandModel.AMBUSH_WINDUP*2.0),0,1)*PI)
				tile.event_actor.position+=direction*.22*pulse
		if style.known and not tile.was_known and not model.preview_all:
			tile.clear_t = 0.0
			fog_burst(tile.root,model.blocked.has(position_value))
		var clear_duration:float=IslandModel.AMBUSH_WINDUP if model.ambush_position==position_value else 1.15 if model.blocked.has(position_value) else CLEAR_SECONDS
		if style.known: tile.clear_t = minf(clear_duration,tile.clear_t+_dt)
		else: tile.clear_t = 0.0
		if model.preview_all: tile.clear_t = clear_duration
		tile.was_known = style.known
		var clearing: float = tile.clear_t/clear_duration
		if tile.get("event_actor") != null: tile.event_actor.material_override.set_shader_parameter("reveal",smoothstep(0.0,0.75,clearing))
		tile.fog.visible = clearing < 1.0
		tile.wisp.visible = clearing < 1.0
		tile.wisp.position = Vector3(0,0.13+clearing*0.12,0)
		for mist in [tile.fog,tile.wisp]:
			mist.material_override.set_shader_parameter("clearing",clearing)
			mist.material_override.set_shader_parameter("brightness",style.bright)
		tile.top.visible = style.known and not cell.get("concealed_peak",false)
		tile.root.position = world_position(cell.c,cell.r,cell.h)
		tile.root.rotation.y = -model.angles().x
		tile.wisp.basis = tile.root.basis.inverse()*camera.basis.scaled(Vector3.ONE*(1.0+clearing*0.3))
		var path: String = cell.base if style.known else IslandAssets.SHROUD
		if path != tile.path:
			tile.path = path
			tile.top.mesh = top_mesh(path)
			tile.top.material_override.set_shader_parameter("art",assets.texture(path))
			tile.body.material_override.set_shader_parameter("tint",IslandAssets.side_colors(path)[0])
		tile.body.material_override.set_shader_parameter("textured",style.known)
		if cell.has("water_level") and style.known:
			tile.top.material_override.shader=preload("res://shaders/island_water.gdshader")
			var banks: Array=cell.water_banks
			tile.top.material_override.set_shader_parameter("banks",Vector4(banks[0],banks[1],banks[2],banks[3]))
			tile.top.material_override.set_shader_parameter("flow",Vector2(cell.water_flow[0],cell.water_flow[1]))
			tile.top.material_override.set_shader_parameter("origin",IslandModel.wxz(cell.c,cell.r))
		if tile.waterfall != null:
			tile.waterfall.visible=style.known
			tile.waterfall.material_override.set_shader_parameter("reveal",clearing)
			tile.waterfall.material_override.set_shader_parameter("brightness",style.bright)
			tile.waterfall.material_override.set_shader_parameter("saturation",style.sat)
		tile.body.material_override.set_shader_parameter("fog_reveal",clearing)
		tile.body.material_override.set_shader_parameter("tint",IslandAssets.side_colors(IslandAssets.SHROUD)[0].lerp(IslandAssets.side_colors(cell.base)[0],smoothstep(0.0,1.0,clearing)))
		if cell.has("water_level"):
			tile.body.material_override.set_shader_parameter("tint",IslandAssets.side_colors(IslandAssets.SHROUD)[0].lerp(Color("35453e"),smoothstep(0.0,1.0,clearing)))
		for mesh in [tile.top,tile.body,tile.prop]:
			if mesh:
				mesh.material_override.set_shader_parameter("brightness",style.bright)
				mesh.material_override.set_shader_parameter("saturation",style.sat)
		if tile.prop:
			tile.prop.visible = style.known
			tile.prop.material_override.set_shader_parameter("fog_cover",0.0)
			tile.prop.material_override.set_shader_parameter("fog_origin",IslandModel.wxz(cell.c,cell.r))
			tile.prop.material_override.set_shader_parameter("reveal",smoothstep(0.0,0.75,clearing))
			# Center the sprite foot on the tile; a tiny depth bias avoids z fighting.
			tile.prop.position = tile.root.position+camera.basis.z*.015
		tile.body.visible = style.known
		tile.body.material_override.set_shader_parameter("fog_reveal",1.0)
		if tile.fog.visible: update_fog_union(tile)
	hero.update_world(self,_dt)
	outline.visible = tiles.has(model.hover)
	ghost_body.visible = outline.visible
	ghost_prop.visible = false
	selection_union.visible = false
	if outline.visible:
		var tile: Dictionary = tiles[model.hover]
		ghost_body.mesh = tile.body.mesh
		ghost_body.transform = tile.root.transform*tile.body.transform
		ghost_body.material_override.set_shader_parameter("body_depth",tile.body.mesh.get_aabb().size.y)
		var color := Color("c5e9a5") if model.can_visit(model.hover) else Color("d59075")
		ghost_body.material_override.set_shader_parameter("tint",color)
		ghost_body.material_override.set_shader_parameter("unified",false)
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var corners := [Vector3(.5,.006,0),Vector3(0,.006,.5),Vector3(-.5,.006,0),Vector3(0,.006,-.5)]
		for i in range(4):
			mesh.surface_add_vertex(tile.root.transform*corners[i])
			mesh.surface_add_vertex(tile.root.transform*corners[(i+1)%4])
		mesh.surface_end()
		outline.mesh = mesh
		outline.material_override.albedo_color = Color("c5e9a5") if model.can_visit(model.hover) else Color("d59075")
		# Unknown props already contribute their silhouette to the fog union.
		# Selection follows that same silhouette, including during reveal.
		if tile.prop:
			var quad: QuadMesh = tile.prop.mesh
			var tl := camera.unproject_position(tile.prop.transform*(quad.center_offset+Vector3(-quad.size.x/2,quad.size.y/2,0)))
			var br := camera.unproject_position(tile.prop.transform*(quad.center_offset+Vector3(quad.size.x/2,-quad.size.y/2,0)))
			var origin := camera.unproject_position(tile.root.transform*corners[0])
			var sm: ShaderMaterial = selection_union.material
			var head: ShaderMaterial = ghost_body.material_override
			head.set_shader_parameter("unified",true)
			head.set_shader_parameter("prop_art",assets.texture(tile.cell.feat.src))
			head.set_shader_parameter("prop_rect",Vector4(tl.x,tl.y,br.x-tl.x,br.y-tl.y))
			head.set_shader_parameter("view_size",size)
			sm.set_shader_parameter("prop_art",assets.texture(tile.cell.feat.src))
			sm.set_shader_parameter("prop_rect",Vector4(tl.x,tl.y,br.x-tl.x,br.y-tl.y))
			sm.set_shader_parameter("top_origin",origin)
			sm.set_shader_parameter("top_u",camera.unproject_position(tile.root.transform*corners[1])-origin)
			sm.set_shader_parameter("top_v",camera.unproject_position(tile.root.transform*corners[3])-origin)
			sm.set_shader_parameter("view_size",size)
			sm.set_shader_parameter("tint",color)
			selection_union.visible = true
			outline.visible = false
func update_fog_union(tile: Dictionary) -> void:
	var corners := [Vector3(.5,0,0),Vector3(0,0,.5),Vector3(-.5,0,0),Vector3(0,0,-.5)]
	var tops := PackedVector2Array()
	var bottoms := PackedVector2Array()
	var top_depths := PackedFloat32Array()
	var bottom_depths := PackedFloat32Array()
	var bounds := Rect2(camera.unproject_position(tile.root.position),Vector2.ZERO)
	for corner in corners:
		var top := camera.unproject_position(tile.root.transform*corner)
		var bottom := camera.unproject_position(tile.root.transform*(corner+Vector3(0,-0.85,0)))
		tops.append(top)
		bottoms.append(bottom)
		top_depths.append(-camera.to_local(tile.root.transform*corner).z)
		bottom_depths.append(-camera.to_local(tile.root.transform*(corner+Vector3(0,-0.85,0))).z)
		bounds=bounds.expand(top).expand(bottom)
	var prop_bounds := Rect2()
	if tile.prop:
		var mesh: QuadMesh=tile.prop.mesh
		var tl:=camera.unproject_position(tile.prop.transform*(mesh.center_offset+Vector3(-mesh.size.x/2,mesh.size.y/2,0)))
		var br:=camera.unproject_position(tile.prop.transform*(mesh.center_offset+Vector3(mesh.size.x/2,-mesh.size.y/2,0)))
		prop_bounds=Rect2(tl,br-tl)
		bounds=bounds.merge(prop_bounds)
	var scale_value:=112.0*model.zoom
	tile.fog.mesh.size=bounds.size/scale_value
	var anchor: Vector3=tile.root.position+camera.basis.z*(23.52/112*sqrt(3.0)+.02)
	var ray:=camera.project_ray_origin(bounds.get_center())
	var direction:=camera.project_ray_normal(bounds.get_center())
	tile.fog.global_position=ray+direction*((anchor-ray).dot(camera.basis.z)/direction.dot(camera.basis.z))
	tile.fog.global_basis=camera.basis
	for i in range(4):
		tops[i]=(tops[i]-bounds.position)/bounds.size
		bottoms[i]=(bottoms[i]-bounds.position)/bounds.size
	var mat: ShaderMaterial=tile.fog.material_override
	mat.set_shader_parameter("top_points",tops)
	mat.set_shader_parameter("bottom_points",bottoms)
	mat.set_shader_parameter("top_depths",top_depths)
	mat.set_shader_parameter("bottom_depths",bottom_depths)
	mat.set_shader_parameter("field_size",bounds.size/scale_value)
	mat.set_shader_parameter("has_prop",tile.prop != null)
	if tile.prop:
		mat.set_shader_parameter("prop_art",assets.texture(tile.cell.feat.src))
		mat.set_shader_parameter("prop_depth",-camera.to_local(tile.prop.position).z)
		var start: Vector2=(prop_bounds.position-bounds.position)/bounds.size
		var extent: Vector2=prop_bounds.size/bounds.size
		mat.set_shader_parameter("prop_rect",Vector4(start.x,start.y,extent.x,extent.y))
	var center:=camera.unproject_position(tile.root.position)
	mat.set_shader_parameter("fade_start",(center.y+scale_value*0.16-bounds.position.y)/bounds.size.y)
	mat.set_shader_parameter("fade_end",(center.y+scale_value*0.72-bounds.position.y)/bounds.size.y)
func pick(point: Vector2, visit_only := false) -> Vector2i:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var nearest := INF
	var result := Vector2i(-999,-999)
	for k in tiles:
		if visit_only and not model.can_visit(k): continue
		var tile: Dictionary = tiles[k]
		if tile.cell.get("concealed_peak",false):continue
		var t: float = (tile.root.position.y-origin.y)/direction.y
		if t < 0 or t >= nearest: continue
		var local: Vector3 = tile.root.transform.affine_inverse()*(origin+direction*t)
		# Diamond footprint of the actual rotated cube top.
		if absf(local.x)+absf(local.z) <= .5:
			nearest = t
			result = k
	return result
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for marker in passage_markers:
			if marker.node.visible and camera.unproject_position(marker.node.position).distance_to(event.position)<45:
				model.traversal.request(model,marker.link.id);accept_event();return
	if event is InputEventMouseMotion: model.hover = pick(event.position)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: model.go_to(pick(event.position))
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: model.zoom_goal = minf(2.4,model.zoom_goal*1.12)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: model.zoom_goal = maxf(.42,model.zoom_goal/1.12)
