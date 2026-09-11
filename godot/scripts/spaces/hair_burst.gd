extends RefCounted
var rig:Skeleton3D
var bones:Array=[]
var materials:Array=[]
var flames:CPUParticles3D
var head:=-1
var strength:=0.0
var remaining:=0.0
var clock:=0.0
var fire:=true
func hair_name(value:String)->bool:
 var n:=value.to_lower()
 return "hair" in n or "头发" in n or "前发" in n or "后发" in n or "侧发" in n or "刘海" in n or n=="发"
func setup(root:Node3D,skeleton:Skeleton3D):
 rig=skeleton
 for i in range(rig.get_bone_count()):
  if hair_name(rig.get_bone_name(i)):bones.append(i)
 head=rig.find_bone("頭")
 if head<0:head=rig.find_bone("頭調整")
 collect(root)
 flames=CPUParticles3D.new();root.get_parent().add_child(flames)
 flames.amount=60;flames.lifetime=.65;flames.emitting=false;flames.local_coords=false
 flames.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;flames.emission_sphere_radius=.12
 flames.direction=Vector3.UP;flames.spread=18;flames.gravity=Vector3(0,.25,0)
 flames.initial_velocity_min=.3;flames.initial_velocity_max=.65
 flames.scale_amount_min=.055;flames.scale_amount_max=.12
 var gradient:=Gradient.new();gradient.set_color(0,Color(1,.85,.2,0));gradient.add_point(.15,Color(1,.7,.08,.8));gradient.add_point(.55,Color(1,.22,.015,.55));gradient.set_color(1,Color(.6,.04,0,0));flames.color_ramp=gradient
 var mesh:=QuadMesh.new();mesh.size=Vector2(1,2.2)
 var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/hair_flame.gdshader");mesh.material=mat;flames.mesh=mesh
func collect(node:Node):
 if node is MeshInstance3D:
  for i in range(node.mesh.get_surface_count()):
   var original=node.get_active_material(i)
   if not original is StandardMaterial3D:continue
   var is_hair:=hair_name(original.resource_name)
   # Unnamed material slots can be identified by actual hair-bone skin weights.
   if not is_hair and not bones.is_empty() and node.skin:
    var arrays=node.mesh.surface_get_arrays(i)
    var weights=arrays[Mesh.ARRAY_WEIGHTS];var indices=arrays[Mesh.ARRAY_BONES]
    var total:=0.0;var weighted:=0.0
    if weights!=null and indices!=null:
     for k in range(weights.size()):
      total+=weights[k]
      var bind:int=indices[k]
      if bind<node.skin.get_bind_count():
       var bone:int=node.skin.get_bind_bone(bind)
       if bone<0:bone=rig.find_bone(node.skin.get_bind_name(bind))
       if bone in bones:weighted+=weights[k]
     is_hair=total>0 and weighted/total>.7
   if is_hair:
    var mat=original.duplicate();node.set_surface_override_material(i,mat)
    materials.append({"mat":mat,"color":mat.albedo_color,"emission":mat.emission,"enabled":mat.emission_enabled,"energy":mat.emission_energy_multiplier})
 for child in node.get_children():collect(child)
func trigger():remaining=5.0
func advance(dt:float):
 clock+=dt;remaining=maxf(0,remaining-dt)
 strength=move_toward(strength,1.0 if remaining>0 else 0.0,dt*(2.5 if remaining>0 else 1.5))
 for i in bones:
  var rest:Basis=rig.get_bone_rest(i).basis
  var direction:=rig.get_bone_global_rest(i).basis.y.normalized()
  var axis:=direction.cross(Vector3.UP)
  var angle:=minf(direction.angle_to(Vector3.UP),1.1)*.32*strength
  if axis.length_squared()>.001:
   var local_axis:=rig.get_bone_global_rest(i).basis.inverse()*axis.normalized()
   rig.set_bone_pose_rotation(i,(rest.get_rotation_quaternion()*Quaternion(local_axis.normalized(),angle+sin(clock*2.8+i*.7)*.035*strength)).normalized())
  elif strength==0:rig.set_bone_pose_rotation(i,rest.get_rotation_quaternion())
 for entry in materials:
  var mat:StandardMaterial3D=entry.mat
  mat.albedo_color=entry.color.lerp(Color(1,.64,.12,entry.color.a),strength*.75)
  mat.emission_enabled=entry.enabled or strength>.001
  mat.emission=entry.emission.lerp(Color(1,.3,.025),strength)
  mat.emission_energy_multiplier=lerpf(entry.energy,2.2,strength)
 if head>=0:flames.global_position=rig.global_transform*rig.get_bone_global_pose(head).origin+Vector3(0,.13,0)
 flames.emitting=fire and strength>.1 and not materials.is_empty() and head>=0
func dispose():
 if is_instance_valid(flames):flames.queue_free()
