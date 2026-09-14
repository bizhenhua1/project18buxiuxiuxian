extends Node3D
class MotionCohort extends RefCounted:
 var age:=0.0
 var next_life:=INF
class ShapeFrame extends RefCounted:
 var basis:Basis
 var scale:Vector3
 var offset:Vector3
 func _init(shape:Dictionary):
  var rot:Dictionary=shape.get("m_Rotation",{})
  basis=Basis.from_euler(Vector3(-rot.get("x",0),-rot.get("y",0),rot.get("z",0))*PI/180)
  var sc:Dictionary=shape.get("m_Scale",{});var off:Dictionary=shape.get("m_Position",{})
  scale=Vector3(sc.get("x",1),sc.get("y",1),sc.get("z",1))
  offset=Vector3(off.get("x",0),off.get("y",0),-off.get("z",0))
class Particle extends RefCounted:
 var age:float=0.0
 var life:float
 var random:float
 var position:Vector3
 var velocity:Vector3
 var rotation:float
 var size:float
 var tile:int
 var base_color:Color
 var gpu_color:Color
 var motion_data:Transform3D
 var motion_slot:int=-1
 var cohort:MotionCohort
const ROOT="res://assets/fx/epic181/"
const CAP=256
var asset_root:=ROOT
static var mesh_cache:Dictionary={}
static var material_cache:Dictionary={}
static var anchor_cache:Dictionary={}
var layers:Array=[]
var age:=0.0
var stopped:=false
var camera:Camera3D
var last_position:=Vector3.ZERO
var rng:=RandomNumberGenerator.new()
var gpu_curves:=false
var gpu_motion:=false
var skip_empty_layers:bool=not "--update-empty-particle-layers" in OS.get_cmdline_user_args()
var cache_shape_frames:bool=not "--uncached-particle-shapes" in OS.get_cmdline_user_args()
var particle_cohorts:bool="--particle-cohorts" in OS.get_cmdline_user_args()
var bulk_upload:bool="--bulk-particle-upload" in OS.get_cmdline_user_args()
var motion_step:=0.0
var motion_uniforms_ready:=false
var last_motion_transform:=Transform3D.IDENTITY
var last_motion_billboard:=Basis.IDENTITY
var cache_motion_uniforms:bool="--cache-motion-uniforms" in OS.get_cmdline_user_args()
var profile_particles:=false
var spawn_usec:=0
var update_usec:=0
var particle_allocations:=0
var budget_skipped_spawns:=0
static var motion_shaders:Dictionary={}
var render_batch:Node3D
var render_kind:=""
var half_scratch:=PackedByteArray([0,0])
func scalar_line(values:Array,t:float)->float:
 if values.size()==1:return values[0]
 var index:=clampf(t,0,1)*maxi(0,values.size()-1);var lo:=int(index);var hi:=mini(values.size()-1,lo+1)
 return lerpf(values[lo],values[hi],index-lo)
func sample(values:Array,t:float,random:float=.5)->float:
 if values[0].size()==1 and values[1].size()==1:return lerpf(values[0][0],values[1][0],random)
 # Exported min/max curves usually share the same sample grid. Compute its
 # interval once, keeping the original interpolation order and float precision.
 if values[0].size()==values[1].size():
  var lower:Array=values[0];var upper:Array=values[1]
  var index:=clampf(t,0,1)*maxi(0,lower.size()-1);var lo:=int(index);var hi:=mini(lower.size()-1,lo+1)
  return lerpf(lerpf(lower[lo],lower[hi],index-lo),lerpf(upper[lo],upper[hi],index-lo),random)
 return lerpf(scalar_line(values[0],t),scalar_line(values[1],t),random)
static func zero_constant(values:Array)->bool:
 return values[0].size()==1 and values[1].size()==1 and values[0][0]==0 and values[1][0]==0
func color_line(values:Array,t:float)->Color:
 if values.size()==1:
  var value:Array=values[0];return Color(value[0],value[1],value[2],value[3])
 var index:=clampf(t,0,1)*maxi(0,values.size()-1);var lo:=int(index);var hi:=mini(values.size()-1,lo+1)
 var a:Array=values[lo];var b:Array=values[hi]
 return Color(a[0],a[1],a[2],a[3]).lerp(Color(b[0],b[1],b[2],b[3]),index-lo)
func color_sample(values:Array,t:float,random:float)->Color:
 return color_line(values[0],t).lerp(color_line(values[1],t),random)
func v(a:Array)->Vector3:return Vector3(a[0],a[1],-a[2])
func find_mesh(n:Node,parent_transform:Transform3D=Transform3D.IDENTITY)->Mesh:
 var transform:Transform3D=parent_transform*n.transform if n is Node3D else parent_transform
 if n is MeshInstance3D:
  var baked:=ArrayMesh.new()
  for surface in n.mesh.get_surface_count():
   var arrays:Array=n.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   for i in vertices.size():vertices[i]=transform*vertices[i]
   for i in normals.size():normals[i]=(transform.basis.inverse().transposed()*normals[i]).normalized()
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
   baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  return baked
 for c in n.get_children():
  var found=find_mesh(c,transform)
  if found:return found
 return null
func setup(spec:Dictionary,cam:Camera3D,root:String=ROOT):
 motion_uniforms_ready=false
 asset_root=root;camera=cam;rng.seed=1391;last_position=global_position
 for data in spec.layers:
  var mesh:Mesh
  if int(data.render_mode)==4:
   var path:String=asset_root+data.get("mesh","circle.glb")
   if not data.get("mesh","circle.glb").is_empty() and ResourceLoader.exists(path):
    if not mesh_cache.has(path):
     var scene=load(path).instantiate();mesh_cache[path]=find_mesh(scene);scene.free()
    mesh=mesh_cache[path]
   else:mesh=SphereMesh.new()
  else:mesh=QuadMesh.new()
  var key:String=asset_root+str(data.material)
  var mat:ShaderMaterial
  if material_cache.has(key):mat=material_cache[key]
  else:
   mat=ShaderMaterial.new();var shader:=Shader.new();var code=FileAccess.get_file_as_string("res://shaders/epic181_particle.gdshader")
   if data.material.additive:code=code.replace("depth_draw_never;","depth_draw_never,blend_add;")
   shader.code=code;mat.shader=shader
   if not data.material.texture.is_empty():mat.set_shader_parameter("art",load(asset_root+data.material.texture))
   var c:Array=data.material.tint;mat.set_shader_parameter("tint",Color(c[0],c[1],c[2],c[3]));mat.set_shader_parameter("gain",float(data.material.get("gain",2.0)))
   var sc:Array=data.material.get("uv_scale",[1,1]);var off:Array=data.material.get("uv_offset",[0,0])
   mat.set_shader_parameter("uv_scale",Vector2(sc[0],sc[1]));mat.set_shader_parameter("uv_offset",Vector2(off[0],off[1]))
   material_cache[key]=mat
  # Sheet dimensions are per emitter, so keep material instances separate from cached source materials.
  mat=mat.duplicate()
  var use_gpu_curves:bool=gpu_curves and (int(data.render_mode)!=1 or gpu_motion) and data.size[0]==data.size[1]
  if use_gpu_curves:
   var curves:Dictionary=preload("res://scripts/spaces/epic181_gpu_curves.gd").prepare(data.size,data.gradient)
   mat.set_shader_parameter("gpu_curves_enabled",true)
   mat.set_shader_parameter("particle_curves",curves.texture);mat.set_shader_parameter("curve_counts",curves.counts)
   for side in 2:
    var initial:Array=data.color[side][0]
    mat.set_shader_parameter("particle_start_min" if side==0 else "particle_start_max",Vector4(initial[0],initial[1],initial[2],initial[3]))
  var sheet:Dictionary=data.get("sheet",{})
  # Damping only changes stored velocity. With zero initial speed and no gravity,
  # that velocity stays zero; velocity-over-life separately offsets position.
  var effective_dampen:float=0.0 if zero_constant(data.start.startSpeed) and zero_constant(data.start.gravityModifier) else float(data.dampen)
  var use_gpu_motion:bool=gpu_motion and use_gpu_curves and int(data.render_mode) in [0,4] and zero_constant(data.start.gravityModifier) and data.velocity.is_empty() and effective_dampen==0 and data.rotation[0].size()==1 and data.rotation[1].size()==1 and not sheet.get("enabled",false)
  var use_gpu_current:bool=gpu_motion and use_gpu_curves and not use_gpu_motion and int(data.render_mode) in [0,1,4]
  if use_gpu_motion or use_gpu_current:
   var original:Shader=mat.shader
   if not motion_shaders.has(original):
    var motion_shader:=Shader.new();var code:String=original.code
    motion_shader.code=code.get_slice("void vertex()",0).replace("depth_draw_never","depth_draw_never,skip_vertex_transform")+"\n#include \"res://shaders/epic181_local_motion.gdshaderinc\"\nvoid fragment()"+code.get_slice("void fragment()",1)
    motion_shaders[original]=motion_shader
   mat.shader=motion_shaders[original]
   mat.set_shader_parameter("motion_mesh_mode",int(data.render_mode)==4)
   mat.set_shader_parameter("motion_rotation",Vector2(data.rotation[0][0],data.rotation[1][0]))
   mat.set_shader_parameter("motion_current_state",use_gpu_current)
   mat.set_shader_parameter("motion_local",data.get("local",false))
   mat.set_shader_parameter("motion_stretch",int(data.render_mode)==1)
   mat.set_shader_parameter("motion_stretch_parameters",Vector2(data.length_scale,data.get("velocity_scale",0)))
   if use_gpu_motion and not zero_constant(data.noise):
    var noise_data:=preload("res://scripts/spaces/epic181_gpu_curves.gd").prepare_noise(data.noise)
    mat.set_shader_parameter("motion_noise_enabled",true)
    mat.set_shader_parameter("motion_noise_curve",noise_data.texture);mat.set_shader_parameter("motion_noise_counts",noise_data.counts)
  var tile_count:int=data.material.get("tiles",[]).size()
  if sheet.get("enabled",false):mat.set_shader_parameter("tiles",Vector2(sheet.x,sheet.y));tile_count=int(sheet.x)*int(sheet.y)
  elif tile_count==4:mat.set_shader_parameter("tiles",Vector2(2,2))
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
  # GPU motion encodes spawn/current data entirely in the transform; its vertex
  # shader calculates COLOR and tile, so two instance vec4 buffers are unused.
  mm.use_colors=not (use_gpu_motion or use_gpu_current);mm.use_custom_data=mm.use_colors;mm.mesh=mesh
  mm.custom_aabb=AABB(Vector3(-100,-100,-100),Vector3(200,200,200));mm.instance_count=CAP;mm.visible_instance_count=0
  var visual:=MultiMeshInstance3D.new();visual.multimesh=mm;visual.material_override=mat;add_child(visual)
  # Resolve coincident transparent layers consistently across pooled instances.
  # Tiny depth bias retains world depth ordering instead of global priorities.
  visual.sorting_offset=-float(layers.size())*.001
  var transform:=Transform3D.IDENTITY
  for tr in data.transforms:
   var q:Array=tr.rotation;var sc:Array=tr.scale
   transform=transform*Transform3D(Basis(Quaternion(-q[0],-q[1],q[2],q[3])).scaled(Vector3(sc[0],sc[1],sc[2])),v(tr.position))
  var anchor:=Vector3.ZERO
  if int(data.render_mode)==4:anchor=texture_anchor(mesh,asset_root+data.material.texture)
  if use_gpu_motion or use_gpu_current:mat.set_shader_parameter("motion_mesh",transform.basis)
  layers.append({"index":layers.size(),"anchor":anchor,"data":data,"mm":mm,"material":mat,"transform":transform,"particles":[],"recycled":[],"carry":0.0,"burst":0,"cycle":-1,"tiles":tile_count,"gpu_curves":use_gpu_curves,"gpu_motion":use_gpu_motion,"gpu_current":use_gpu_current})
  layers.back().shape_frame=ShapeFrame.new(data.shape) if cache_shape_frames else null
  layers.back()["effective_dampen"]=effective_dampen
  layers.back()["profile_spawn_usec"]=0;layers.back()["profile_update_usec"]=0;layers.back()["profile_particle_steps"]=0
  layers.back().profile_initial_uploads=0;layers.back().profile_reorder_uploads=0
  layers.back()["cohorts"]=[];layers.back()["free_cohorts"]=[];layers.back()["spawn_cohort"]=null;layers.back()["motion_dirty"]=false
  if bulk_upload and not use_gpu_motion and not use_gpu_current:layers.back()["buffer"]=preload("res://scripts/spaces/epic181_instance_buffer.gd").new(CAP)
func unit_sphere()->Vector3:
 var z:=rng.randf_range(-1,1);var angle:=rng.randf()*TAU;var r:=sqrt(1-z*z)
 return Vector3(r*cos(angle),r*sin(angle),z)
func emit_pose(shape:Dictionary,frame:ShapeFrame=null)->Transform3D:
 var position:=Vector3.ZERO;var direction:=Vector3.FORWARD
 if bool(shape.get("enabled",false)):
  var raw=shape.get("radius",1.0);var radius:=sample(raw,0,rng.randf()) if raw is Array else float(raw) if raw is float or raw is int else 1.0
  var kind:=int(shape.get("type",0));var angle:=rng.randf()*TAU
  var thickness:=float(shape.get("radiusThickness",1));var r:=radius*sqrt(lerpf(pow(1-thickness,2),1,rng.randf()))
  match kind:
   0,1,2,3:
    direction=unit_sphere()
    if kind in [2,3]:direction.z=-absf(direction.z)
    position=direction*radius*(1.0 if kind in [1,3] else pow(rng.randf(),1.0/3))
   4,7,8,9:
    position=Vector3(cos(angle)*r,sin(angle)*r,0)
    var spread:=deg_to_rad(float(shape.get("angle",25)))*r/maxf(radius,.001)
    direction=Vector3(cos(angle)*sin(spread),sin(angle)*sin(spread),-cos(spread))
    if kind in [8,9]:position+=direction*rng.randf()*float(shape.get("length",1))
   5,15,16,18:
    position=Vector3(rng.randf()-.5,rng.randf()-.5,0 if kind==18 else rng.randf()-.5)
   10,11:
    position=Vector3(cos(angle),sin(angle),0)*(radius if kind==11 else r);direction=position.normalized()
   12:position.x=rng.randf_range(-radius,radius)
   17:
    direction=unit_sphere();position=Vector3(cos(angle),sin(angle),0)*radius+direction*float(shape.get("donutRadius",.2))
   _:direction=unit_sphere();position=direction*r
  if frame==null:
   var rot:Dictionary=shape.get("m_Rotation",{});var sb:=Basis.from_euler(Vector3(-rot.get("x",0),-rot.get("y",0),rot.get("z",0))*PI/180)
   var sc:Dictionary=shape.get("m_Scale",{});var off:Dictionary=shape.get("m_Position",{})
   position=sb*(position*Vector3(sc.get("x",1),sc.get("y",1),sc.get("z",1)))+Vector3(off.get("x",0),off.get("y",0),-off.get("z",0))
   direction=sb*direction
  else:
   position=frame.basis*(position*frame.scale)+frame.offset
   direction=frame.basis*direction
 var forward:=direction.normalized() if direction.length_squared()>.001 else Vector3.FORWARD
 var up:=Vector3.RIGHT if absf(forward.dot(Vector3.UP))>.98 else Vector3.UP
 return Transform3D(Basis.looking_at(forward,up),position)
func spawn(layer:Dictionary,emission_origin:Vector3,emission_basis:Variant=null,emission_phase:float=-1.0):
 var limit:int=int(layer.get("instance_particle_limit",layer.data.get("runtime_particle_limit",CAP)))
 if layer.particles.size()>=limit:
  if limit<CAP:budget_skipped_spawns+=1
  return
 var d:Dictionary=layer.data;var r:=rng.randf();var t:float=emission_phase if emission_phase>=0 else fmod(age,maxf(.01,d.duration))/maxf(.01,d.duration)
 var world_basis:Basis=global_basis if emission_basis==null else emission_basis
 var life:=maxf(.01,sample(d.start.startLifetime,t,r));var tr:Transform3D=layer.transform;var pose:=emit_pose(d.shape,layer.shape_frame)
 var pos:Vector3=tr*pose.origin;var velocity:Vector3=tr.basis*(-pose.basis.z)*sample(d.start.startSpeed,t,r)
 var local:bool=d.get("local",false)
 var p:Particle
 if layer.recycled.is_empty():
  p=Particle.new();particle_allocations+=1
 else:p=layer.recycled.pop_back()
 p.age=0.0;p.gpu_color=Color();p.motion_data=Transform3D.IDENTITY;p.motion_slot=-1
 p.life=life;p.random=r;p.position=pos if local else world_basis*pos+emission_origin
 p.velocity=velocity if local else world_basis*velocity
 p.rotation=sample(d.start.startRotation,t,r);p.size=sample(d.start.startSize,t,r)
 p.tile=rng.randi_range(0,maxi(0,int(layer.tiles)-1));p.base_color=color_sample(d.color,0,r)
 layer.particles.append(p)
 if layer.gpu_curves:
  var encoded:=int(round(r*65535.0))
  p.gpu_color=Color(minf(1.0,((encoded>>8)+.5)/255.0),minf(1.0,((encoded&255)+.5)/255.0),0,1)
 if layer.gpu_motion:
  if particle_cohorts:
   if layer.spawn_cohort==null:
    var cohort:MotionCohort=MotionCohort.new() if layer.free_cohorts.is_empty() else layer.free_cohorts.pop_back()
    cohort.age=0;cohort.next_life=INF;layer.cohorts.append(cohort);layer.spawn_cohort=cohort
   p.cohort=layer.spawn_cohort;p.cohort.next_life=minf(p.cohort.next_life,p.life);layer.motion_dirty=true
  p.motion_data=Transform3D(Basis(p.velocity,Vector3(age-motion_step,p.life,p.size),Vector3(p.rotation,p.random,p.tile)),p.position)
  p.motion_slot=-1
func advance(dt:float):
 motion_step=dt
 # Emitter and camera transforms are constant while this update runs.
 var emitter_transform:=global_transform
 var emitter_basis:=emitter_transform.basis
 var inverse_basis:=emitter_basis.inverse()
 var inverse_transform:=emitter_transform.affine_inverse()
 var camera_basis:=camera.global_basis
 var inverse_orientation:=emitter_basis.orthonormalized().inverse()
 var billboard_basis:=inverse_orientation*camera_basis
 var transform_changed:bool=not cache_motion_uniforms or not motion_uniforms_ready or emitter_transform!=last_motion_transform
 var billboard_changed:bool=not cache_motion_uniforms or not motion_uniforms_ready or billboard_basis!=last_motion_billboard
 last_motion_transform=emitter_transform;last_motion_billboard=billboard_basis;motion_uniforms_ready=true
 var horizontal_basis:=inverse_orientation*Basis(Vector3.RIGHT,PI*.5)
 var emission_position:Vector3=emitter_transform.origin
 age+=dt;var previous_position:=last_position;var travel:=emission_position.distance_to(last_position);last_position=emission_position
 for layer in layers:
  var phase_started:int=Time.get_ticks_usec() if profile_particles else 0
  layer.spawn_cohort=null
  var d:Dictionary=layer.data;var time:float=age-sample(d.delay,0)
  if not stopped and time>=0 and (d.loop or time<d.duration):
   var cycle:=int(time/maxf(.01,d.duration));var local_time:=fmod(time,maxf(.01,d.duration))
   if cycle!=layer.cycle:layer.cycle=cycle;layer.burst=0
   var t:=local_time/maxf(.01,d.duration)
   layer.carry+=maxf(0,sample(d.rate,t))*dt+maxf(0,sample(d.distance_rate,t))*travel
   var count:=mini(CAP,int(layer.carry));layer.carry-=count
   var spawn_phase:float=fmod(age,maxf(.01,d.duration))/maxf(.01,d.duration)
   for i in count:spawn(layer,previous_position.lerp(emission_position,float(i+1)/maxi(1,count)),emitter_basis,spawn_phase)
   while layer.burst<d.bursts.size() and local_time>=d.bursts[layer.burst].time:
    if rng.randf()<=d.bursts[layer.burst].get("probability",1):
     for i in mini(CAP,int(sample(d.bursts[layer.burst].count,t))):spawn(layer,emission_position,emitter_basis,spawn_phase)
    layer.burst+=1
  if profile_particles:
   var now:=Time.get_ticks_usec();var cost:int=now-phase_started
   spawn_usec+=cost;layer.profile_spawn_usec+=cost;phase_started=now
   layer.profile_particle_steps+=layer.particles.size()
  if skip_empty_layers and layer.particles.is_empty():
   layer.mm.visible_instance_count=0
   # Emitter-level cached transforms may change while this layer sleeps.
   layer.motion_needs_sync=true
   if profile_particles:
    var empty_cost:int=Time.get_ticks_usec()-phase_started
    update_usec+=empty_cost;layer.profile_update_usec+=empty_cost
   continue
  if layer.gpu_motion or layer.gpu_current:
   layer.material.set_shader_parameter("motion_age",age)
   if transform_changed or layer.get("motion_needs_sync",false):
    layer.material.set_shader_parameter("motion_emitter",emitter_transform)
    layer.material.set_shader_parameter("motion_inverse",inverse_transform)
   if billboard_changed or layer.get("motion_needs_sync",false):layer.material.set_shader_parameter("motion_billboard",billboard_basis)
   layer.motion_needs_sync=false
  if layer.gpu_motion:
   if particle_cohorts:
    for cohort:MotionCohort in layer.cohorts:
     cohort.age+=dt
     if cohort.age>=cohort.next_life:layer.motion_dirty=true
    if not layer.motion_dirty:
     if profile_particles:
      var cost:int=Time.get_ticks_usec()-phase_started
      update_usec+=cost;layer.profile_update_usec+=cost
     continue
    for cohort:MotionCohort in layer.cohorts:cohort.next_life=INF
   var count:=0
   for p:Particle in layer.particles:
    p.age=p.cohort.age if particle_cohorts else p.age+dt
    if p.age>=p.life:
     layer.recycled.append(p);continue
    if p.motion_slot!=count:
     if profile_particles:
      if p.motion_slot<0:layer.profile_initial_uploads+=1
      else:layer.profile_reorder_uploads+=1
     layer.mm.set_instance_transform(count,p.motion_data);p.motion_slot=count
    layer.particles[count]=p;count+=1
    if particle_cohorts:p.cohort.next_life=minf(p.cohort.next_life,p.life)
   layer.particles.resize(count);layer.mm.visible_instance_count=count
   if particle_cohorts:
    var active_cohorts:=0
    for cohort:MotionCohort in layer.cohorts:
     if cohort.next_life==INF:layer.free_cohorts.append(cohort)
     else:layer.cohorts[active_cohorts]=cohort;active_cohorts+=1
    layer.cohorts.resize(active_cohorts);layer.motion_dirty=false
   if profile_particles:
    var cost:int=Time.get_ticks_usec()-phase_started
    update_usec+=cost;layer.profile_update_usec+=cost
   continue
  var alive_count:=0
  var local:bool=d.get("local",false)
  var render_mode:int=d.render_mode
  var mesh_basis:Basis=layer.transform.basis
  var gravity_curve:Array=d.start.gravityModifier;var has_gravity:=not zero_constant(gravity_curve)
  var rotation_curve:Array=d.rotation;var has_rotation:=not zero_constant(rotation_curve)
  var noise_curve:Array=d.noise;var has_noise:=not zero_constant(noise_curve)
  var velocity:Dictionary=d.velocity;var velocity_world:bool=d.get("velocity_world",false)
  var dampen:float=layer.effective_dampen
  var sheet:Dictionary=d.get("sheet",{});var sheet_enabled:bool=sheet.get("enabled",false)
  var sheet_cycles:=1.0;var sheet_fixed_row:=false;var sheet_columns:=1;var sheet_row:=0;var tile_count:=1
  if sheet_enabled:
   sheet_cycles=float(sheet.get("cycles",1));sheet_fixed_row=int(sheet.get("row_mode",0))==1
   sheet_columns=maxi(1,int(sheet.x));sheet_row=int(sheet.get("row",0))*sheet_columns;tile_count=maxi(1,layer.tiles)
  var length_scale:float=d.length_scale;var velocity_scale:float=d.get("velocity_scale",0)
  var mm:MultiMesh=layer.mm;var layer_gpu:bool=layer.gpu_curves
  var batch_target=render_batch.target(render_kind,layer.index,global_position) if render_batch!=null else null
  var batch_transform:=Transform3D.IDENTITY
  var batch_offset:=0
  var bulk:bool=bulk_upload and batch_target==null and not layer.gpu_current
  if batch_target!=null:
   mm=batch_target.mm;batch_offset=batch_target.cursor
   batch_transform=batch_target.node.global_transform.affine_inverse()*global_transform
  for p:Particle in layer.particles:
   p.age+=dt
   if p.age>=p.life:
    layer.recycled.append(p);continue
   var t:float=p.age/p.life;var random:float=p.random
   if has_gravity:
    var gravity:=Vector3.DOWN*9.81*sample(gravity_curve,t,random)*dt
    p.velocity+=inverse_basis*gravity if local else gravity
   if not velocity.is_empty():
    var vel:=Vector3(sample(velocity.x,t,random),sample(velocity.y,t,random),-sample(velocity.z,t,random))
    if local and velocity_world:vel=inverse_basis*vel
    elif not local and not velocity_world:vel=emitter_basis*vel
    p.position+=vel*dt
   if dampen>0:
    var limit:=sample(d.damping,t,random)
    if limit>0 and p.velocity.length()>limit:p.velocity=p.velocity.lerp(p.velocity.normalized()*limit,clampf(dampen*dt*30,0,1))
   p.position+=p.velocity*dt
   if has_rotation:p.rotation+=sample(rotation_curve,t,random)*dt
   var noise:float=sample(noise_curve,t,random)*.025 if has_noise else 0.0
   if layer.gpu_current:
    var stretch_speed:=0.0
    if render_mode==1:
     var vel:Vector3=emitter_basis*p.velocity if local else p.velocity
     var projected:=Vector2(vel.dot(camera_basis.x),vel.dot(camera_basis.y))
     if projected.length()>.01:p.rotation=atan2(-projected.x,projected.y)
     stretch_speed=p.velocity.length()
    var tile:float=p.tile
    if sheet_enabled:
     var frame:float=sample(sheet.frame,fmod(t*sheet_cycles,1),random)+sample(sheet.start,0,random)
     tile=floor(fposmod(frame,.99999)*tile_count)
     if sheet_fixed_row:tile=sheet_row+fmod(tile,sheet_columns)
    mm.set_instance_transform(alive_count,Transform3D(Basis(Vector3(noise,stretch_speed,0),Vector3(p.age,p.life,p.size),Vector3(p.rotation,p.random,tile)),p.position))
    layer.particles[alive_count]=p;alive_count+=1
    continue
   var pos:Vector3=p.position if local else inverse_transform*p.position
   if noise!=0:pos+=Vector3(sin(p.age*13+random*12),cos(p.age*17+random*6),sin(p.age*11))*noise
   var basis:Basis=mesh_basis
   if render_mode!=4:
    basis=billboard_basis
    if render_mode==1:
     var vel:Vector3=emitter_basis*p.velocity if local else p.velocity
     var projected:=Vector2(vel.dot(camera_basis.x),vel.dot(camera_basis.y))
     if projected.length()>.01:p.rotation=atan2(-projected.x,projected.y)
    if render_mode==2:basis=horizontal_basis
    basis=basis*Basis(Vector3.BACK,p.rotation)
   else:basis=Basis(Vector3.BACK,p.rotation)*basis
   var gpu_size:bool=layer_gpu and float(p.size)>.001
   var sz:float=p.size if gpu_size else maxf(.001,p.size*sample(d.size,t,random));var stretch:=Vector3.ONE
   if render_mode==1:stretch.y=maxf(1,length_scale+velocity_scale*p.velocity.length()/sz)
   var index:=alive_count+batch_offset
   var particle_transform:=Transform3D(basis.scaled(Vector3.ONE*sz*stretch),pos)
   var upload:bool=index<mm.instance_count
   if upload and not bulk:mm.set_instance_transform(index,batch_transform*particle_transform if batch_target!=null else particle_transform)
   elif not upload and render_batch!=null:render_batch.dropped+=1
   var tile:float=p.tile
   if sheet_enabled:
    var frame:float=sample(sheet.frame,fmod(t*sheet_cycles,1),random)+sample(sheet.start,0,random)
    tile=floor(fposmod(frame,.99999)*tile_count)
    if sheet_fixed_row:tile=sheet_row+fmod(tile,sheet_columns)
   var color:Color=p.gpu_color if gpu_size else p.base_color*color_sample(d.gradient,t,random)
   if upload and not bulk:mm.set_instance_color(index,color)
   var custom:=Color(tile,0,0,-1 if layer_gpu else 0)
   if gpu_size:
    half_scratch.encode_half(0,t)
    var t_half:float=half_scratch.decode_half(0)
    custom=Color(tile,t_half,(t-t_half)*2048.0,.001/p.size)
   if upload:
    if bulk:layer.buffer.write(index,particle_transform,color,custom)
    else:mm.set_instance_custom_data(index,custom)
   layer.particles[alive_count]=p;alive_count+=1
  layer.particles.resize(alive_count)
  if bulk and alive_count>0:mm.buffer=layer.buffer.values
  layer.mm.visible_instance_count=alive_count if batch_target==null else 0
  if batch_target!=null:batch_target.cursor=mini(mm.instance_count,batch_offset+alive_count)
  if profile_particles:
   var cost:int=Time.get_ticks_usec()-phase_started
   update_usec+=cost;layer.profile_update_usec+=cost
func reset_particles():
 # Preserve the high-water allocation across effect restarts, with no old uploads visible.
 for layer in layers:
  layer.recycled.append_array(layer.particles);layer.particles.clear()
  layer.free_cohorts.append_array(layer.cohorts);layer.cohorts.clear();layer.spawn_cohort=null;layer.motion_dirty=false
  layer.mm.visible_instance_count=0
  layer.carry=0.0;layer.burst=0;layer.cycle=-1
func finished()->bool:
 if age<.1:return false
 for layer in layers:
  if not layer.particles.is_empty():return false
  if not stopped and (layer.data.loop or age<float(layer.data.duration)):return false
 return true
func stop_emitting():stopped=true

func texture_anchor(mesh:Mesh,texture_path:String)->Vector3:
 var key:=str(mesh.get_instance_id())+texture_path
 if anchor_cache.has(key):return anchor_cache[key]
 if not ResourceLoader.exists(texture_path):return Vector3.ZERO
 var texture:Texture2D=load(texture_path);var img:=texture.get_image()
 if img.is_compressed():img.decompress()
 var center:=Vector3.ZERO;var total:=0.0
 for surface in mesh.get_surface_count():
  var arrays:=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  if uv.is_empty():continue
  for i in range(0,ids.size()-2,3):
   var a:int=ids[i];var b:int=ids[i+1];var c:int=ids[i+2]
   var mid:Vector2=(uv[a]+uv[b]+uv[c])/3
   var weight:float=img.get_pixel(clampi(int(mid.x*img.get_width()),0,img.get_width()-1),clampi(int(mid.y*img.get_height()),0,img.get_height()-1)).a
   weight*= (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length()
   center+=(vertices[a]+vertices[b]+vertices[c])/3*weight;total+=weight
 center=center/maxf(.00001,total);anchor_cache[key]=center;return center
func align_mesh_highlight(point:Vector3):
 for layer in layers:
  if int(layer.data.render_mode)==4 and layer.mm.visible_instance_count>0:
   var center:Vector3=layer.mm.get_instance_transform(0)*layer.anchor
   global_position+=point-to_global(center);return
