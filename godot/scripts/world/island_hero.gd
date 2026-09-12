extends "res://scripts/battle/seer_actor.gd"
# Reuse the protagonist model and calibrated walk; render directly in the island world.
const BODY_SCALE:=.324
# Keep cadence independent of the visual shrink: both travel and gait slow by 20%.
const GAIT_REFERENCE_SCALE:=.45
var retarget=preload("res://scripts/spaces/preview_retarget.gd").new()
var rig:Skeleton3D
var jump_clip:Dictionary
var was_jumping:=false
var previous_grid:=Vector2(INF,INF)
var facing:=PI
const MODELS=preload("res://scripts/spaces/character_library.gd").MODELS
var selected_model:=0
var motion_data:Dictionary
var motion_cache:Dictionary={}
var motion_time:=0.0
var water_depth:=0.0
var ripple:MeshInstance3D
var ripples:Array=[]
var ripple_distance:=0.0
var ripple_clock:=1.0
var occlusion_renderer:Node
var traversal_blending:=false
var blend_elapsed:=1.0
var blend_positions:Array[Vector3]=[]
var blend_rotations:Array[Quaternion]=[]
func _ready() -> void:
	motion_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_hero_motions.json"))
	var library=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
	assert(library.bones==motion_data.bones)
	for entry in library.clips:
		if entry.get("traversal",false):motion_data[entry.id]=entry
	jump_clip=motion_data.jump
	var config=ConfigFile.new()
	if config.load("user://world-hero.cfg")==OK:selected_model=clampi(int(config.get_value("hero","index",0)),0,MODELS.size()-1)
	select_model(selected_model)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-40,-35,0)
	key.light_color=Color("deded3");key.light_energy=.85;add_child(key)
	for i in range(12):
		var mesh=MeshInstance3D.new();mesh.mesh=PlaneMesh.new();mesh.mesh.size=Vector2(.65,.65)
		mesh.material_override=ShaderMaterial.new();mesh.material_override.shader=preload("res://shaders/world_foot_ripple.gdshader");mesh.visible=false;add_child(mesh)
		ripples.append({"mesh":mesh,"age":10.0,"grid":Vector2.ZERO,"tile":Vector2i.ZERO,"height":0.0})
	ripple=ripples[0].mesh
func select_model(index:int,save:=false):
	selected_model=index
	if is_instance_valid(occlusion_renderer):occlusion_renderer.queue_free()
	if body:body.queue_free()
	body=load("res://assets/characters3d/"+MODELS[index].file).instantiate();add_child(body)
	rig=find_rig(body)
	var head_height:float=rig.get_bone_global_rest(rig.find_bone("頭")).origin.y+.2
	body.scale=Vector3.ONE*(BODY_SCALE if index==0 else .65/head_height)
	apply_ink_material(body);disable_animation(body)
	occlusion_renderer=preload("res://scripts/world/hero_occlusion.gd").new()
	add_child(occlusion_renderer);occlusion_renderer.setup(self)
	retarget.configure(rig,motion_data.bones);clip="";motion_time=0
	blend_positions.clear();blend_rotations.clear();blend_elapsed=1
	if save:
		var config=ConfigFile.new();config.set_value("hero","index",index);config.save("user://world-hero.cfg")
func update_occlusion(view:IslandView3D,_dt:float):
	occlusion_renderer.sync(self,view)
func disable_animation(node:Node):
	if node is AnimationPlayer:node.active=false
	for child in node.get_children():disable_animation(child)
func sample_motion(name:String,time:float):
	if clip!=name:
		if traversal_blending and not clip.is_empty():
			blend_positions.clear();blend_rotations.clear()
			for i in rig.get_bone_count():
				blend_positions.append(rig.get_bone_pose_position(i));blend_rotations.append(rig.get_bone_pose_rotation(i))
			blend_elapsed=0
		clip=name
		if not motion_cache.has(name):
			retarget.load_clip(motion_data[name]);motion_cache[name]=retarget.data
		else:
			retarget.data=motion_cache[name];retarget.frames=motion_data[name].frames;retarget.fps=motion_data[name].fps
	retarget.apply(time)
func find_rig(node:Node) -> Skeleton3D:
	if node is Skeleton3D:return node
	for child in node.get_children():
		var found=find_rig(child)
		if found:return found
	return null
func update_world(view:IslandView3D,dt:float) -> void:
	var model:=view.model
	traversal_blending=traversal_blending or not model.traversal.active.is_empty()
	model.traversal.hip_grid_height=retarget.hip_height*body.scale.y/IslandView3D.HEIGHT
	var pose:=model.avatar()
	body.position=view.world_position(pose.x,pose.z,pose.y)
	var grid:=IslandModel.wxz(pose.x,pose.z)
	var traveled:=0.0 if not is_finite(previous_grid.x) else grid.distance_to(previous_grid)
	previous_grid=grid
	if not model.traversal.active.is_empty():
		var link:Dictionary=model.traversal.active
		var direction:=IslandModel.wxz(link.to.x,link.to.y)-IslandModel.wxz(link.from.x,link.from.y)
		if direction.length_squared()>.00001:
			facing=lerp_angle(facing,atan2(direction.x,direction.y)+(PI if link.get("down",false) else 0.0),1-exp(-dt*6))
	elif model.walking and not model.rebounding:
		var direction:=IslandModel.wxz(model.walk_to.x,model.walk_to.y)-IslandModel.wxz(model.walk_from.x,model.walk_from.y)
		var target:=atan2(direction.x,direction.y)
		facing=lerp_angle(facing,target,1-exp(-dt*18))
	body.rotation.y=facing-model.angles().x
	var jumping:=model.is_jumping()
	var tile_key:=Vector2i(floori(pose.x+.5),floori(pose.z+.5))
	var tile:Dictionary=model.lookup.get(tile_key,{})
	var wet:bool=not tile.is_empty() and (tile.get("layer","")=="water" or "water" in str(tile.get("base",""))) and not jumping
	water_depth=move_toward(water_depth,.07 if wet else 0.0,dt*.5)
	body.position.y-=water_depth
	ripple_distance+=traveled;ripple_clock+=dt
	if wet and ((model.walking and ripple_distance>=.14) or ripple_clock>=.9):
		var oldest:Dictionary=ripples[0]
		for pulse in ripples:
			if pulse.age>oldest.age:oldest=pulse
		oldest.age=0.0;oldest.grid=Vector2(pose.x,pose.z);oldest.tile=tile_key;oldest.height=float(tile.h)
		ripple=oldest.mesh;ripple_distance=0;ripple_clock=0
	for pulse in ripples:
		pulse.age+=dt;pulse.mesh.visible=pulse.age<1.5
		if not pulse.mesh.visible:continue
		pulse.mesh.position=view.world_position(pulse.grid.x,pulse.grid.y,pulse.height)+Vector3(0,.008,0)
		var center:=view.world_position(pulse.tile.x,pulse.tile.y,pulse.height)
		pulse.mesh.material_override.set_shader_parameter("tile_center",Vector2(center.x,center.z))
		pulse.mesh.material_override.set_shader_parameter("angle",model.angles().x)
		pulse.mesh.material_override.set_shader_parameter("age",pulse.age)
	if not model.traversal.active.is_empty():
		var motion:Dictionary=model.traversal.motion()
		var length:float=(motion_data[motion.name].frames-1)/motion_data[motion.name].fps
		var time:float=fmod(motion.get("time",0.0),length) if motion.loop else clampf(motion.get("fraction",motion.get("time",0.0)/length),0,1)*length
		if motion.name=="walk":
			if clip!="walk":motion_time=0
			motion_time+=traveled/(WALK_STRIDE_METERS*GAIT_REFERENCE_SCALE)*WALK_DURATION
			time=fmod(motion_time,length)
		sample_motion(motion.name,time)
		if motion.name in ["idle","walk"]:motion_time=time
		else:rig.set_bone_pose_position(retarget.root_bone,retarget.rests[retarget.root_bone].origin)
	elif model.rebounding and model.ambush_elapsed<2.0:
		var hit_time:=maxf(0,model.ambush_elapsed-IslandModel.AMBUSH_WINDUP)
		sample_motion("hit",minf(hit_time,(motion_data.hit.frames-1)/motion_data.hit.fps))
		rig.set_bone_pose_position(retarget.root_bone,retarget.rests[retarget.root_bone].origin)
	elif jumping:
		var progress:=model.jump_progress()
		if model.lookup[model.walk_to].h<model.lookup[model.walk_from].h:progress=lerpf(.35,1.0,progress)
		sample_motion("jump",progress*(jump_clip.frames-1)/jump_clip.fps)
		# The map trajectory owns height and translation; retain only the jump pose.
		rig.set_bone_pose_position(retarget.root_bone,retarget.rests[retarget.root_bone].origin)
	else:
		var name:="walk" if model.walking else "idle"
		if clip!=name:motion_time=0
		motion_time+=traveled/(WALK_STRIDE_METERS*GAIT_REFERENCE_SCALE)*WALK_DURATION if model.walking else dt
		sample_motion(name,fmod(motion_time,(motion_data[name].frames-1)/motion_data[name].fps))
	if blend_elapsed<.45 and blend_positions.size()==rig.get_bone_count():
		blend_elapsed+=dt
		var weight:=smoothstep(0,.45,blend_elapsed)
		for i in rig.get_bone_count():
			rig.set_bone_pose_position(i,blend_positions[i].lerp(rig.get_bone_pose_position(i),weight))
			rig.set_bone_pose_rotation(i,blend_rotations[i].slerp(rig.get_bone_pose_rotation(i),weight))
	if model.traversal.active.is_empty() and blend_elapsed>=.45:traversal_blending=false
	update_occlusion(view,dt)
	was_jumping=jumping
