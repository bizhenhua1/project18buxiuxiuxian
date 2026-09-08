class_name ForestBatch
extends Node2D
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
var rustle_slots:Array[int]=[]
var dynamic_slots:Array[int]=[]
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
	batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_2D
	batch.use_colors=true;batch.use_custom_data=true
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;batch.mesh=quad
	# A second, outline-only pass shares projection and atlas, above scenery bodies.
	edge_pass=MultiMeshInstance2D.new()
	edge_pass.multimesh=MultiMesh.new()
	edge_pass.multimesh.transform_format=MultiMesh.TRANSFORM_2D
	edge_pass.multimesh.use_colors=true;edge_pass.multimesh.use_custom_data=true
	edge_pass.multimesh.mesh=quad;edge_pass.multimesh.instance_count=32
	edge_pass.texture=atlas;edge_pass.material=shader.duplicate()
	edge_pass.material.set_shader_parameter("edge_only",true)
	edge_pass.z_index=1;add_child(edge_pass)
func sync(renderer:SegmentRenderer) -> void:
	var actors:Array[Dictionary]=[]
	var rustles:Array[Dictionary]=[]
	for sprite in renderer.world.sprites:
		if sprite.get("actor",false):actors.append(sprite)
		if sprite.has("rustle_started") and renderer.elapsed-float(sprite.rustle_started)<.42:rustles.append(sprite)
	actors.append_array(renderer.battle_actors)
	if renderer.lantern_enabled:actors.append_array(world_mist(renderer))
	if groups.is_empty():
		for sprite in source:
			var members:Array[Dictionary]=[{"sprite":sprite}]
			for cover in sprite.get("root_cover",[]):members.append({"sprite":sprite,"cover":cover})
			groups.append({"members":members,"position":sprite.position,"width":sprite.w,"start":entries.size()})
			entries.append_array(members)
		batch.instance_count=entries.size()*2
		for i in range(entries.size()):write_instance(i*2,renderer,entries[i])
		var buffer:=batch.buffer
		for group in groups:
			group.buffer=buffer.slice(group.start*32,(group.start+group.members.size())*32)
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
	for slot in dynamic_slots:batch.set_instance_custom_data(slot,Color(renderer.camera_world.x,renderer.camera_world.y,0,0))
	dynamic_slots.clear()
	var axis:=Vector2(sin(order_angle),cos(order_angle))
	actors.sort_custom(func(a,b):return a.position.dot(axis)>b.position.dot(axis))
	for actor in actors:
		var depth:float=actor.position.dot(axis)
		var lo:=0;var hi:=entries.size()
		while lo<hi:
			var mid:=(lo+hi)/2
			if entries[mid].sprite.position.dot(axis)>depth:lo=mid+1
			else:hi=mid
		var slot:=maxi(0,lo-1)*2+1
		while slot in dynamic_slots:slot+=2
		slot=mini(slot,batch.visible_instance_count-1)
		write_instance(slot,renderer,{"sprite":actor})
		dynamic_slots.append(slot)
	for slot in rustle_slots:
		if slot<entries.size():write_instance(slot*2,renderer,entries[slot])
	rustle_slots.clear()
	for sprite in rustles:
		if not sprite_slots.has(sprite.id):continue
		var slot:int=sprite_slots[sprite.id]
		write_instance(slot*2,renderer,entries[slot])
		rustle_slots.append(slot)
	var params:Dictionary={"lantern_enabled":renderer.lantern_enabled,"lantern_position":renderer.lantern_position(),"enemy_light_position":renderer.enemy_light_position(),"enemy_light_strength":renderer.enemy_light_strength(),"atmosphere_time":renderer.elapsed,"canvas_origin":global_position,"canvas_scale":global_transform.get_scale(),"camera_world":renderer.camera_world,"viewport_size":renderer.view_size,"heading":renderer.heading,"focal":renderer.focal(),"horizon":renderer.horizon_y(),"eye":renderer.camera_height(),"terrain_amplitude":ForestSettings.values.height,"fog_color":renderer.environment.b.atmosphere.depth_color,"fog_range":Vector2(renderer.environment.b.depth_start,renderer.environment.b.depth_end)}
	for key in params:
		material.set_shader_parameter(key,params[key])
		edge_pass.material.set_shader_parameter(key,params[key])
	renderer.bind_biome(material)
	renderer.bind_biome(edge_pass.material)
	var highlighted:Array=actors.filter(func(a):return a.get("edge_strength",0.0)>0 and not a.get("hidden",false))
	if highlighted.size()>edge_pass.multimesh.instance_count:edge_pass.multimesh.instance_count=highlighted.size()
	edge_pass.multimesh.visible_instance_count=highlighted.size()
	for i in range(highlighted.size()):
		var outline:Dictionary=highlighted[i].duplicate()
		var outline_tint:Color=outline.get("ecology_tint",Color.WHITE)
		outline_tint.a*=float(outline.edge_strength)
		outline.ecology_tint=outline_tint
		write_instance(i,renderer,{"sprite":outline},edge_pass.multimesh)
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
	if not textures.has(tex.get_instance_id()):
		var im:=tex.get_image();im.clear_mipmaps()
		textures[tex.get_instance_id()]=image_keys[hash(im.get_data())]
	var category:=8 if sprite.get("shell",false) else 7 if sprite.get("outflow",false) else 4 if sprite.get("drip",false) else 2 if sprite.get("firefly",false) else 1 if sprite.get("mist",false) else 3 if sprite.get("emissive",false) else 5 if sprite.get("actor",false) else 6 if sprite.get("biome_prop",false) else 0
	target.set_instance_custom_data(i,Color(sprite.position.x,sprite.position.y,sprite.altitude,textures[tex.get_instance_id()]+64*category))

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
	sprite_slots.clear();rustle_slots.clear()
	for i in range(entries.size()):sprite_slots[entries[i].sprite.id]=i
	var buffer:PackedFloat32Array=result.buffer
	var count:=entries.size()*2
	var capacity:=int(ceil(count/512.0))*512
	if batch.instance_count!=capacity:batch.instance_count=capacity
	buffer.resize(capacity*16)
	batch.buffer=buffer
	batch.visible_instance_count=count
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
