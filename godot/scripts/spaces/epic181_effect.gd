extends Node3D
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
func scalar_line(values:Array,t:float)->float:
 var index:=clampf(t,0,1)*maxi(0,values.size()-1);var lo:=int(index);var hi:=mini(values.size()-1,lo+1)
 return lerpf(values[lo],values[hi],index-lo)
func sample(values:Array,t:float,random:float=.5)->float:
 return lerpf(scalar_line(values[0],t),scalar_line(values[1],t),random)
func color_line(values:Array,t:float)->Color:
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
  var sheet:Dictionary=data.get("sheet",{})
  var tile_count:int=data.material.get("tiles",[]).size()
  if sheet.get("enabled",false):mat.set_shader_parameter("tiles",Vector2(sheet.x,sheet.y));tile_count=int(sheet.x)*int(sheet.y)
  elif tile_count==4:mat.set_shader_parameter("tiles",Vector2(2,2))
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=mesh
  mm.custom_aabb=AABB(Vector3(-100,-100,-100),Vector3(200,200,200));mm.instance_count=CAP;mm.visible_instance_count=0
  var visual:=MultiMeshInstance3D.new();visual.multimesh=mm;visual.material_override=mat;add_child(visual)
  var transform:=Transform3D.IDENTITY
  for tr in data.transforms:
   var q:Array=tr.rotation;var sc:Array=tr.scale
   transform=transform*Transform3D(Basis(Quaternion(-q[0],-q[1],q[2],q[3])).scaled(Vector3(sc[0],sc[1],sc[2])),v(tr.position))
  var anchor:=Vector3.ZERO
  if int(data.render_mode)==4:anchor=texture_anchor(mesh,asset_root+data.material.texture)
  layers.append({"anchor":anchor,"data":data,"mm":mm,"transform":transform,"particles":[],"carry":0.0,"burst":0,"cycle":-1,"tiles":tile_count})
func unit_sphere()->Vector3:
 var z:=rng.randf_range(-1,1);var angle:=rng.randf()*TAU;var r:=sqrt(1-z*z)
 return Vector3(r*cos(angle),r*sin(angle),z)
func emit_pose(shape:Dictionary)->Transform3D:
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
  var rot:Dictionary=shape.get("m_Rotation",{});var sb:=Basis.from_euler(Vector3(-rot.get("x",0),-rot.get("y",0),rot.get("z",0))*PI/180)
  var sc:Dictionary=shape.get("m_Scale",{});var off:Dictionary=shape.get("m_Position",{})
  position=sb*(position*Vector3(sc.get("x",1),sc.get("y",1),sc.get("z",1)))+Vector3(off.get("x",0),off.get("y",0),-off.get("z",0))
  direction=sb*direction
 var forward:=direction.normalized() if direction.length_squared()>.001 else Vector3.FORWARD
 var up:=Vector3.RIGHT if absf(forward.dot(Vector3.UP))>.98 else Vector3.UP
 return Transform3D(Basis.looking_at(forward,up),position)
func spawn(layer:Dictionary,emission_origin:Vector3):
 if layer.particles.size()>=CAP:return
 var d:Dictionary=layer.data;var r:=rng.randf();var t:=fmod(age,maxf(.01,d.duration))/maxf(.01,d.duration)
 var life:=maxf(.01,sample(d.start.startLifetime,t,r));var tr:Transform3D=layer.transform;var pose:=emit_pose(d.shape)
 var pos:Vector3=tr*pose.origin;var velocity:Vector3=tr.basis*(-pose.basis.z)*sample(d.start.startSpeed,t,r)
 var local:bool=d.get("local",false)
 layer.particles.append({"age":0.0,"life":life,"random":r,"position":pos if local else global_basis*pos+emission_origin,"velocity":velocity if local else global_basis*velocity,"rotation":sample(d.start.startRotation,t,r),"size":sample(d.start.startSize,t,r),"tile":rng.randi_range(0,maxi(0,int(layer.tiles)-1))})
func advance(dt:float):
 age+=dt;var previous_position:=last_position;var travel:=global_position.distance_to(last_position);last_position=global_position
 for layer in layers:
  var d:Dictionary=layer.data;var time:float=age-sample(d.delay,0)
  if not stopped and time>=0 and (d.loop or time<d.duration):
   var cycle:=int(time/maxf(.01,d.duration));var local_time:=fmod(time,maxf(.01,d.duration))
   if cycle!=layer.cycle:layer.cycle=cycle;layer.burst=0
   var t:=local_time/maxf(.01,d.duration)
   layer.carry+=maxf(0,sample(d.rate,t))*dt+maxf(0,sample(d.distance_rate,t))*travel
   var count:=mini(CAP,int(layer.carry));layer.carry-=count
   for i in count:spawn(layer,previous_position.lerp(global_position,float(i+1)/maxi(1,count)))
   while layer.burst<d.bursts.size() and local_time>=d.bursts[layer.burst].time:
    if rng.randf()<=d.bursts[layer.burst].get("probability",1):
     for i in mini(CAP,int(sample(d.bursts[layer.burst].count,t))):spawn(layer,global_position)
    layer.burst+=1
  var alive:Array=[]
  for p in layer.particles:
   p.age+=dt
   if p.age>=p.life:continue
   var t:float=p.age/p.life;var random:float=p.random;var local:bool=d.get("local",false)
   var gravity:=Vector3.DOWN*9.81*sample(d.start.gravityModifier,t,random)*dt
   p.velocity+=global_basis.inverse()*gravity if local else gravity
   if not d.velocity.is_empty():
    var vel:=v([sample(d.velocity.x,t,random),sample(d.velocity.y,t,random),sample(d.velocity.z,t,random)])
    if local and d.get("velocity_world",false):vel=global_basis.inverse()*vel
    elif not local and not d.get("velocity_world",false):vel=global_basis*vel
    p.position+=vel*dt
   var limit:=sample(d.damping,t,random)
   if float(d.dampen)>0 and limit>0 and p.velocity.length()>limit:p.velocity=p.velocity.lerp(p.velocity.normalized()*limit,clampf(float(d.dampen)*dt*30,0,1))
   p.position+=p.velocity*dt;p.rotation+=sample(d.rotation,t,random)*dt
   var noise:=sample(d.noise,t,random)*.025
   var pos:Vector3=(p.position if local else to_local(p.position))+Vector3(sin(p.age*13+random*12),cos(p.age*17+random*6),sin(p.age*11))*noise
   var basis:Basis=layer.transform.basis
   if int(d.render_mode)!=4:
    basis=global_basis.orthonormalized().inverse()*camera.global_basis
    if int(d.render_mode)==1:
     var vel:Vector3=global_basis*p.velocity if local else p.velocity
     var projected:=Vector2(vel.dot(camera.global_basis.x),vel.dot(camera.global_basis.y))
     if projected.length()>.01:p.rotation=atan2(-projected.x,projected.y)
    if int(d.render_mode)==2:basis=global_basis.orthonormalized().inverse()*Basis(Vector3.RIGHT,PI*.5)
    basis=basis*Basis(Vector3.BACK,p.rotation)
   else:basis=Basis(Vector3.BACK,p.rotation)*basis
   var sz:float=maxf(.001,p.size*sample(d.size,t,random));var stretch:=Vector3.ONE
   if int(d.render_mode)==1:stretch.y=maxf(1,float(d.length_scale)+float(d.get("velocity_scale",0))*p.velocity.length()/sz)
   var index:=alive.size();layer.mm.set_instance_transform(index,Transform3D(basis.scaled(Vector3.ONE*sz*stretch),pos))
   var tile:float=p.tile;var sheet:Dictionary=d.get("sheet",{})
   if sheet.get("enabled",false):
    var frame:float=sample(sheet.frame,fmod(t*float(sheet.get("cycles",1)),1),random)+sample(sheet.start,0,random)
    tile=floor(fposmod(frame,.99999)*maxi(1,layer.tiles))
    if int(sheet.get("row_mode",0))==1:tile=int(sheet.get("row",0))*int(sheet.x)+fmod(tile,int(sheet.x))
   var color:=color_sample(d.color,0,random)*color_sample(d.gradient,t,random);layer.mm.set_instance_color(index,color);layer.mm.set_instance_custom_data(index,Color(tile,0,0,0));alive.append(p)
  layer.particles=alive;layer.mm.visible_instance_count=alive.size()
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
