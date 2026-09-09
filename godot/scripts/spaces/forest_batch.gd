class_name ForestBatch
extends Node2D
var white_edge_pass:MultiMeshInstance2D
var edge_pass:MultiMeshInstance2D
var batch:MultiMesh
var atlas:ImageTexture
var entries:Array[Dictionary]=[]
var regions:=PackedVector4Array()
var textures:Dictionary={}
var image_keys:Dictionary={}
var source:Array[Dictionary]=[]
var last_heading:=INF
var last_camera:=Vector2(INF,INF)
var last_lens:=Vector2.ZERO
var groups:Array[Dictionary]=[]
var ordering:Thread
var worker_signal:=Semaphore.new()
var worker_lock:=Mutex.new()
var worker_request:Array=[]
var worker_result:Dictionary={}
var worker_busy:=false
var stopping:=false
var initialized:=false
var order_angle:=0.0
var sprite_slots:Dictionary={}
var dynamic_slots:Array[int]=[]
const MAX_DYNAMIC_POSITIONS=256
var dynamic_positions:=PackedVector2Array()
var dynamic_indices:Dictionary={}
var ordered_static:=PackedFloat32Array()
var insertion_points:Array[int]=[]
func setup(sprites:Array[Dictionary]) -> void:
	source=sprites.filter(func(s):return not s.get("actor",false))
	var images:Array[Image]=[]
	for key in ["hound","bell","moth","agent-rear","medium-rear","warden","book","watch-front","watch-reverse","mask","lantern"]:
		var tex:=StyleLibrary.texture(key)
		var raw:=tex.get_image();raw.clear_mipmaps()
		textures[tex.get_instance_id()]=images.size();image_keys[hash(raw.get_data())]=images.size();images.append(raw)
		var trimmed:=raw.get_region(raw.get_used_rect())
		var key_hash:=hash(trimmed.get_data())
		if not image_keys.has(key_hash):image_keys[key_hash]=images.size();images.append(trimmed)
	for sprite in source:
		for texture in [sprite.texture]+sprite.get("root_cover",[]).map(func(c):return c.texture):
			var key:int=texture.get_instance_id()
			if textures.has(key):continue
			textures[key]=images.size()
			images.append(texture.get_image())
	var sheet:=Image.create(4096,8192,false,Image.FORMAT_RGBA8)
	var x:=16;var y:=16;var row_h:=0
	for im in images:
		if x+im.get_width()+16>4096:x=16;y+=row_h+32;row_h=0
		assert(y+im.get_height()<8192)
		sheet.blit_rect(im,Rect2i(0,0,im.get_width(),im.get_height()),Vector2i(x,y))
		regions.append(Vector4(x/4096.0,y/8192.0,im.get_width()/4096.0,im.get_height()/8192.0))
		x+=im.get_width()+32;row_h=maxi(row_h,im.get_height())
	sheet.generate_mipmaps()
	atlas=ImageTexture.create_from_image(sheet)
	var shader:=ShaderMaterial.new();shader.shader=load("res://shaders/forest_batch.gdshader")
	regions.resize(64);shader.set_shader_parameter("atlas_regions",regions);material=shader
	var arches:=source.filter(func(s):return s.get("shell",false) and s.has("plane_heading"))
	if not arches.is_empty():shader.set_shader_parameter("rock_contact",contact_profile(arches[0].texture.get_image()))
	batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_2D
	batch.use_colors=true;batch.use_custom_data=true
	var quad:Mesh
	if source.any(func(s):return s.has("plane_heading")):quad=surface_mesh()
	else:
		quad=QuadMesh.new();quad.size=Vector2.ONE
	batch.mesh=quad
	# A second, outline-only pass shares projection and atlas, above scenery bodies.
	edge_pass=MultiMeshInstance2D.new()
	edge_pass.multimesh=MultiMesh.new()
	edge_pass.multimesh.transform_format=MultiMesh.TRANSFORM_2D
	edge_pass.multimesh.use_colors=true;edge_pass.multimesh.use_custom_data=true
	edge_pass.multimesh.mesh=quad;edge_pass.multimesh.instance_count=32
	edge_pass.texture=atlas;edge_pass.material=shader.duplicate()
	edge_pass.material.set_shader_parameter("edge_only",true)
	edge_pass.z_index=1;add_child(edge_pass)
	white_edge_pass=edge_pass.duplicate()
	white_edge_pass.multimesh=edge_pass.multimesh.duplicate()
	white_edge_pass.material=edge_pass.material.duplicate()
	white_edge_pass.material.set_shader_parameter("edge_color",Vector3(.20,.62,1.0))
	white_edge_pass.material.set_shader_parameter("discovery_edge",true)
	add_child(white_edge_pass)
var retired_geometry:Array=[]
func sync(renderer:SegmentRenderer) -> void:
	if not retired_geometry.is_empty():
		var retired:Dictionary=retired_geometry[0]
		for key in retired:
			for i in range(mini(64,retired[key].size())):retired[key].pop_back()
		if retired.groups.is_empty() and retired.entries.is_empty():retired_geometry.pop_front()
	var actors:Array[Dictionary]=[]
	var rustles:Array[Dictionary]=[]
	for sprite in renderer.world.sprites:
		if sprite.get("actor",false):actors.append(sprite)
		if sprite.has("rustle_started") and renderer.elapsed-float(sprite.rustle_started)<.42:rustles.append(sprite)
	actors.append_array(renderer.battle_actors)
	for actor in actors:
		for field in ["live_character","live_enemy","live_companion","live_discovery"]:
			if actor.get(field,false):
				material.set_shader_parameter(field,actor.texture)
				edge_pass.material.set_shader_parameter(field,actor.texture)
				white_edge_pass.material.set_shader_parameter(field,actor.texture)
	if renderer.lantern_enabled:actors.append_array(world_mist(renderer))
	if groups.is_empty():
		for sprite in source:
			var members:Array[Dictionary]=[{"sprite":sprite}]
			for cover in sprite.get("root_cover",[]):members.append({"sprite":sprite,"cover":cover})
			groups.append({"members":members,"position":sprite.position,"width":sprite.w,"start":entries.size()})
			entries.append_array(members)
		batch.instance_count=entries.size()
		for i in range(entries.size()):write_instance(i,renderer,entries[i])
		var buffer:=batch.buffer
		for group in groups:
			group.buffer=PackedFloat32Array()
			for j in range(group.members.size()):group.buffer.append_array(buffer.slice((group.start+j)*16,(group.start+j+1)*16))
	worker_lock.lock()
	var ready_result:=worker_result
	worker_result={}
	worker_lock.unlock()
	if not ready_result.is_empty():
		# A sort for an older camera angle must not replace the current turning order.
		if absf(angle_difference(float(ready_result.angle),renderer.heading))<.0001:apply_order(ready_result)
		worker_busy=false
	var turning:=initialized and absf(angle_difference(last_heading,renderer.heading))>.0001
	if turning:
		last_heading=renderer.heading;last_camera=renderer.camera_world;last_lens=Vector2(renderer.view_size.x,renderer.focal())
		apply_order(build_order(last_camera,last_heading,renderer.view_size.x,renderer.focal()))
	elif not worker_busy and (not initialized or last_camera.distance_squared_to(renderer.camera_world)>16384 or last_lens!=Vector2(renderer.view_size.x,renderer.focal())):
		last_heading=renderer.heading;last_camera=renderer.camera_world;last_lens=Vector2(renderer.view_size.x,renderer.focal())
		if not initialized:
			apply_order(build_order(last_camera,last_heading,renderer.view_size.x,renderer.focal()));initialized=true
		else:
			if ordering==null:
				ordering=Thread.new();ordering.start(order_worker)
			worker_request=[last_camera,last_heading,renderer.view_size.x,renderer.focal()]
			worker_busy=true;worker_signal.post()
	dynamic_slots.clear()
	dynamic_indices.clear()
	dynamic_positions=PackedVector2Array();dynamic_positions.resize(MAX_DYNAMIC_POSITIONS)
	insertion_points.clear()
	var frame_buffer:=PackedFloat32Array()
	var blank:=PackedFloat32Array();blank.resize(16)
	var copied:=0
	var axis:=Vector2(sin(order_angle),cos(order_angle))
	actors.sort_custom(func(a,b):return a.position.dot(axis)>b.position.dot(axis))
	for actor in actors:
		var depth:float=actor.position.dot(axis)
		var lo:=0;var hi:=entries.size()
		while lo<hi:
			var mid:=(lo+hi)/2
			if entries[mid].sprite.position.dot(axis)>depth:lo=mid+1
			else:hi=mid
		frame_buffer.append_array(ordered_static.slice(copied*16,lo*16))
		copied=lo
		dynamic_slots.append(frame_buffer.size()/16)
		insertion_points.append(lo)
		frame_buffer.append_array(blank)
	frame_buffer.append_array(ordered_static.slice(copied*16))
	var count:=entries.size()+actors.size()
	var capacity:=int(ceil(count/512.0))*512
	if batch.instance_count!=capacity:batch.instance_count=capacity
	frame_buffer.resize(capacity*16)
	batch.buffer=frame_buffer
	batch.visible_instance_count=count
	for i in range(actors.size()):write_instance(dynamic_slots[i],renderer,{"sprite":actors[i]})
	for sprite in rustles:
		if not sprite_slots.has(sprite.id):continue
		var slot:int=sprite_slots[sprite.id]
		var shifted:=slot
		for at in insertion_points:
			if at<=slot:shifted+=1
		write_instance(shifted,renderer,entries[slot])
	var params:Dictionary={"dynamic_positions":dynamic_positions,"lantern_forward":Vector2(sin(renderer.heading),cos(renderer.heading)),"lantern_enabled":renderer.lantern_enabled,"lantern_position":renderer.lantern_position(),"enemy_light_position":renderer.enemy_light_position(),"enemy_light_strength":renderer.enemy_light_strength(),"atmosphere_time":renderer.elapsed,"canvas_origin":global_position,"canvas_scale":global_transform.get_scale(),"camera_world":renderer.camera_world,"viewport_size":renderer.view_size,"heading":renderer.heading,"focal":renderer.focal(),"horizon":renderer.horizon_y(),"eye":renderer.camera_height(),"terrain_amplitude":ForestSettings.values.height,"fog_color":renderer.environment.b.atmosphere.depth_color,"fog_range":Vector2(renderer.environment.b.depth_start,renderer.environment.b.depth_end)}
	for key in params:
		material.set_shader_parameter(key,params[key])
		edge_pass.material.set_shader_parameter(key,params[key])
		white_edge_pass.material.set_shader_parameter(key,params[key])
	renderer.bind_combat_lights(material)
	renderer.bind_biome(material)
	renderer.bind_biome(edge_pass.material)
	for pass_node in [edge_pass,white_edge_pass]:
		var white:bool=pass_node==white_edge_pass
		var highlighted:Array=actors.filter(func(a):return a.get("edge_strength",0.0)>0 and not a.get("hidden",false) and bool(a.get("discovery_edge",false))==white)
		if highlighted.size()>pass_node.multimesh.instance_count:pass_node.multimesh.instance_count=highlighted.size()
		pass_node.multimesh.visible_instance_count=highlighted.size()
		for i in range(highlighted.size()):
			var outline:Dictionary=highlighted[i].duplicate()
			var outline_tint:Color=outline.get("ecology_tint",Color.WHITE)
			outline_tint.a*=float(outline.edge_strength)
			outline.ecology_tint=outline_tint
			write_instance(i,renderer,{"sprite":outline},pass_node.multimesh)
	queue_redraw()
func _draw() -> void:
	if batch:draw_multimesh(batch,atlas)

func write_instance(i:int,renderer:SegmentRenderer,entry:Dictionary,target:MultiMesh=null) -> void:
	if target==null:target=batch
	var sprite:Dictionary=entry.sprite
	var squash:Vector2=sprite.get("squash",Vector2.ONE)
	var w:float=sprite.w*squash.x;var h:float=sprite.h*squash.y
	var anchor:Vector2=sprite.get("ground_anchor",Vector2(.5,1))
	var offset:=Vector2((.5-anchor.x)*w,(.5-anchor.y)*h)
	var tex:Texture2D=sprite.texture
	if entry.has("cover"):
		var cover:Dictionary=entry.cover
		tex=cover.texture;h=sprite.h*cover.height;w=h*tex.get_width()/float(tex.get_height())
		offset=Vector2((cover.x-anchor.x)*sprite.w,(cover.foot_y-anchor.y)*sprite.h-h*.5)
	if sprite.flip:offset.x=-offset.x
	var transform:=Transform2D(Vector2(-w if sprite.flip else w,0),Vector2(0,h),offset)
	if sprite.has("rustle_started"):
		var age:=renderer.elapsed-float(sprite.rustle_started)
		if age>=0 and age<.42:transform=Transform2D(sin(age*32)*.10*pow(1-age/.42,2)*float(sprite.rustle_strength),Vector2.ZERO)*transform
	target.set_instance_transform_2d(i,transform)
	var tint:Color=sprite.region.space.ambient*sprite.get("ecology_tint",Color.WHITE)
	if sprite.get("actor",false):tint.a*=smoothstep(0,.35,renderer.elapsed-float(sprite.get("born_at",-1)))
	if sprite.get("hidden",false):tint.a=0
	target.set_instance_color(i,tint)
	var packed_position:Vector2=sprite.position
	if sprite.get("actor",false):
		# Compatibility packs INSTANCE_CUSTOM into half floats. Only an exact small
		# index belongs there; moving world coordinates use full-precision uniforms.
		if not dynamic_indices.has(sprite.id):
			assert(dynamic_indices.size()<MAX_DYNAMIC_POSITIONS)
			var index:int=dynamic_indices.size()
			dynamic_indices[sprite.id]=index
			dynamic_positions[index]=sprite.position-renderer.camera_world
		packed_position=Vector2(dynamic_indices[sprite.id],0)
	if sprite.get("live_discovery",false):
		target.set_instance_custom_data(i,Color(packed_position.x,packed_position.y,sprite.altitude,64*15));return
	if sprite.get("live_character",false) or sprite.get("live_enemy",false) or sprite.get("live_companion",false):
		target.set_instance_custom_data(i,Color(packed_position.x,packed_position.y,sprite.altitude,64*(14 if sprite.get("live_companion",false) else 13 if sprite.get("live_enemy",false) else 12)))
		return
	if not textures.has(tex.get_instance_id()):
		var im:=tex.get_image();im.clear_mipmaps()
		textures[tex.get_instance_id()]=image_keys[hash(im.get_data())]
	var category:=8 if sprite.get("shell",false) else 7 if sprite.get("outflow",false) else 4 if sprite.get("drip",false) else 2 if sprite.get("firefly",false) else 1 if sprite.get("mist",false) else 3 if sprite.get("emissive",false) else 5 if sprite.get("actor",false) else 6 if sprite.get("biome_prop",false) else 0
	var altitude:float=sprite.altitude
	if sprite.has("plane_heading"):
		category=9 if sprite.get("shell",false) else 11 if sprite.get("emissive",false) else 10
		altitude=float(sprite.plane_heading)
	target.set_instance_custom_data(i,Color(packed_position.x,packed_position.y,altitude,textures[tex.get_instance_id()]+64*category))

func contact_profile(im:Image) -> PackedFloat32Array:
	# Sample only the foot band, never mistake the canopy over the empty opening for a foot.
	var result:=PackedFloat32Array();result.resize(9);result.fill(-1.0)
	for column in range(9):
		var x:=clampi(roundi(column/8.0*(im.get_width()-1)),0,im.get_width()-1)
		for y in range(im.get_height()-1,int(im.get_height()*.78),-1):
			if im.get_pixel(x,y).a>.5:
				result[column]=y/float(im.get_height())-.025
				break
	var sampled:=result.duplicate()
	for column in range(9):
		if result[column]>=0:continue
		var nearest:=-1
		for candidate in range(9):
			if sampled[candidate]>=0 and (nearest<0 or abs(candidate-column)<abs(nearest-column)):nearest=candidate
		result[column]=sampled[nearest] if nearest>=0 else .92
	return result

func surface_mesh() -> ArrayMesh:
	# Ground skirts and fixed world planes need interior vertices for projection.
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	var rows:=[0.0,.25,.5,.65,.75,.84,.86,.87,.88,.9,.92,1.0]
	for v in rows:
		for x in range(9):
			var u:=x/8.0
			vertices.append(Vector3(u-.5,v-.5,0));uv.append(Vector2(u,1-v))
	for y in range(rows.size()-1):
		for x in range(8):
			var a:=y*9+x
			indices.append_array(PackedInt32Array([a,a+1,a+9,a+1,a+10,a+9]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func build_order(camera:Vector2,angle:float,viewport_width:float,lens:float) -> Dictionary:
	var order:Array[Vector2]=[]
	var axis:=Vector2(sin(angle),cos(angle))
	for i in range(groups.size()):
		var delta:Vector2=groups[i].position-camera
		var z:=delta.dot(axis)
		if z < -256 or z > 1956:continue
		var x:=delta.dot(Vector2(axis.y,-axis.x))
		if absf(x)>maxf(z,10)*viewport_width*.5/lens+float(groups[i].width)+256:continue
		order.append(Vector2(-groups[i].position.dot(axis),i))
	order.sort();var ordered_entries:Array[Dictionary]=[]
	var buffer:=PackedFloat32Array()
	for item in order:
		var group:Dictionary=groups[int(item.y)]
		ordered_entries.append_array(group.members)
		buffer.append_array(group.buffer)
	return {"entries":ordered_entries,"buffer":buffer,"angle":angle}

func apply_order(result:Dictionary) -> void:
	entries=result.entries
	order_angle=result.angle
	sprite_slots.clear()
	for i in range(entries.size()):sprite_slots[entries[i].sprite.id]=i
	ordered_static=result.buffer
	dynamic_slots.clear()

func order_worker() -> void:
	while true:
		worker_signal.wait()
		if stopping:return
		var result:=build_order(worker_request[0],worker_request[1],worker_request[2],worker_request[3])
		worker_lock.lock();worker_result=result;worker_lock.unlock()

func _exit_tree() -> void:
	if ordering!=null:
		stopping=true;worker_signal.post();ordering.wait_to_finish()

func world_mist(renderer:SegmentRenderer) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var branches:Array[int]=[0]
	if not renderer.world.plan.straight:
		branches.append_array([-1,1])
		if renderer.world.plan.exits==3:branches.append(2)
	for path in branches:result.append_array(mist_for_branch(renderer,path))
	return result

func mist_for_branch(renderer:SegmentRenderer,path:int) -> Array[Dictionary]:
	var patches:Array[Dictionary]=[]
	var first:=maxi(0,floori((renderer.world.camera_s-90)/80))
	for cell in range(first,first+10):
		var seed_value:=sin(cell*127.1+43.7)
		var route_s:=cell*80.0+seed_value*19.0
		if not renderer.world.plan.straight and ((path==0) != (route_s<ForestRoute.JUNCTION)):continue
		var branch:int=path
		for layer in range(4):
			var lateral:float=seed_value*17+sin(renderer.elapsed*.13+cell)*3 if layer<2 else (-1.0 if layer==2 else 1.0)*(48+seed_value*14)
			var anchor:=ForestRoute.point_at(route_s+layer*13,branch,lateral)
			if renderer.world.plan.straight:anchor=Vector2(lateral,route_s+layer*13)
			var z:=ForestRoute.to_camera(anchor,renderer.camera_world,renderer.heading).y
			if z<12 or z>650:continue
			var side_fade:=1.0 if layer<2 else .85*(1-smoothstep(180,350,z))
			patches.append({"mist":true,"actor":true,"born_at":-100.0,"position":anchor,"texture":source[0].texture,"w":70.0+seed_value*15,"h":18.0+(layer%2)*7,"altitude":2.0+(layer%2)*5,"ground_anchor":Vector2(.5,1),"flip":false,"id":300000+cell*4+layer,"region":renderer.world.camera_region,"ecology_tint":Color(1,1,1,side_fade*smoothstep(12,45,z)*(1-smoothstep(450,650,z)))})
	if str(renderer.world.camera_region.space.key)=="swamp":
		for cell in range(int(floor(renderer.world.camera_s/40))-1,int(floor(renderer.world.camera_s/40))+12):
			if not renderer.world.plan.straight and ((path==0) != (cell*40.0<ForestRoute.JUNCTION)):continue
			for j in range(3):
				var phase:=float(cell*11+j*7)
				var anchor:=ForestRoute.point_at(cell*40.0+j*9,path,sin(phase)*110+sin(renderer.elapsed*.7+phase)*7)
				patches.append({"firefly":true,"actor":true,"position":anchor,"texture":source[0].texture,"w":2.5,"h":2.5,"altitude":10+sin(phase)*6+sin(renderer.elapsed+phase)*3,"ground_anchor":Vector2(.5,.5),"flip":false,"id":400000+cell*3+j,"region":renderer.world.camera_region,"ecology_tint":Color(1,1,1,.6+.4*sin(renderer.elapsed*1.3+phase))})
	if str(renderer.world.camera_region.space.key) in ["crystal","sewer","whale"]:
		for cell in range(int(floor(renderer.world.camera_s/65)),int(floor(renderer.world.camera_s/65))+8):
			if not renderer.world.plan.straight and ((path==0) != (cell*65.0<ForestRoute.JUNCTION)):continue
			var anchor:=ForestRoute.point_at(cell*65.0,path,sin(cell*8.1)*100)
			patches.append({"drip":true,"actor":true,"position":anchor,"texture":source[0].texture,"w":.5,"h":4.0,"altitude":90-fposmod(renderer.elapsed*47+cell*31,88),"ground_anchor":Vector2(.5,.5),"flip":false,"id":500000+cell,"region":renderer.world.camera_region,"ecology_tint":Color(1,1,1,.42)})
	for patch in patches:patch.id+=(path+1)*1000000
	return patches

func replace_scenery(sprites:Array[Dictionary]) -> void:
	# Keep the loaded atlas and render nodes; invalidate only geometry ordering.
	if ordering!=null:
		stopping=true;worker_signal.post();ordering.wait_to_finish();ordering=null
	stopping=false;worker_busy=false;worker_result={};worker_request=[]
	worker_signal=Semaphore.new()
	source=sprites.filter(func(s):return not s.get("actor",false))
	retired_geometry.append({"groups":groups,"entries":entries})
	groups=[];entries=[];sprite_slots.clear();initialized=false

func quiesce_ordering() -> void:
	if ordering!=null and not stopping:
		stopping=true;worker_signal.post()
