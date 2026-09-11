extends RefCounted
# Bake the skeleton vertices into the selected character's rest pose, then use its skin.
static func meshes(node:Node,result:Array):
 if node is MeshInstance3D:result.append(node)
 for child in node.get_children():meshes(child,result)
static func rig_of(node:Node)->Skeleton3D:
 if node is Skeleton3D:return node
 for child in node.get_children():
  var result=rig_of(child)
  if result:return result
 return null
static func head_bounds(root:Node,skeleton:Skeleton3D,head:int)->AABB:
 var objects:Array=[];meshes(root,objects)
 var low:=Vector3(INF,INF,INF);var high:=-low
 for mesh in objects:
  if not mesh.skin:continue
  for surface in range(mesh.mesh.get_surface_count()):
   var arrays:Array=mesh.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var joints=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
   if joints==null or weights==null:continue
   var stride:int=joints.size()/vertices.size()
   for v in range(vertices.size()):
    var influence:=0.0
    for k in range(stride):
     var slot:int=v*stride+k;var bind:int=joints[slot]
     var bone:int=mesh.skin.get_bind_bone(bind)
     if bone<0:bone=skeleton.find_bone(mesh.skin.get_bind_name(bind))
     while bone>=0:
      if bone==head:influence+=weights[slot];break
      bone=skeleton.get_bone_parent(bone)
    if influence>.5:low=low.min(vertices[v]);high=high.max(vertices[v])
 return AABB(low,high-low) if is_finite(low.x) else AABB()
static func build(target:Skeleton3D,head_scale:float=1.0)->Array:
 var source=load("res://assets/characters3d/transformation-skeleton.glb").instantiate()
 var source_rig=rig_of(source)
 var source_orientation:=Basis.IDENTITY
 var mapping:Array=[];var ratios:Array=[];var rotations:Array=[];var anchors:Array=[]
 var source_head:=source_rig.find_bone("頭")
 var head_bones:Array=[source_head]
 for i in range(source_rig.get_bone_count()):
  var parent:=source_rig.get_bone_parent(i)
  while parent>=0:
   if parent==source_head:head_bones.append(i);break
   parent=source_rig.get_bone_parent(parent)
 var target_head:=target.find_bone("頭")
 if target_head<0:source.free();return []
 var source_bounds:=head_bounds(source,source_rig,source_head)
 var ratio:=target.get_bone_global_rest(target_head).origin.y/source_rig.get_bone_global_rest(source_rig.find_bone("頭")).origin.y
 # Torso shares one continuous mapping instead of independently moving ribs and pelvis.
 # MMD lower-body pivots sit at different waist heights. Anchor at the actual
 # leg sockets so the pelvis cannot float above the femurs after fitting.
 var source_hip:Vector3=(source_rig.get_bone_global_rest(source_rig.find_bone("足.L")).origin+source_rig.get_bone_global_rest(source_rig.find_bone("足.R")).origin)*.5
 var target_hip:Vector3=(target.get_bone_global_rest(target.find_bone("足.L")).origin+target.get_bone_global_rest(target.find_bone("足.R")).origin)*.5
 var source_neck:=source_rig.get_bone_global_rest(source_rig.find_bone("首")).origin
 var target_neck:=target.get_bone_global_rest(target.find_bone("首")).origin
 # Use the skull/neck joint, not the skull bounding-box centre, as the scale
 # pivot. Its fitted position must use exactly the existing neck mapping.
 var head_pivot:=source_rig.get_bone_global_rest(source_head).origin
 var head_relative:=head_pivot-source_hip
 var head_along:=head_relative.y/maxf(.001,source_neck.y-source_hip.y)
 var head_joint:=target_hip.lerp(target_neck,head_along)+Vector3(head_relative.x*ratio,0,head_relative.z*ratio)
 for i in range(source_rig.get_bone_count()):
  var at:=i;var match_id:=-1;var anchor:=i
  while at>=0 and match_id<0:
   anchor=at;match_id=target.find_bone(source_rig.get_bone_name(at));at=source_rig.get_bone_parent(at)
  if i in head_bones:match_id=target_head;anchor=source_head
  anchors.append(anchor)
  mapping.append(maxi(0,match_id));ratios.append(ratio);rotations.append(source_orientation)
  var kids:=source_rig.get_bone_children(i)
  if not kids.is_empty() and source_rig.get_bone_name(i) not in ["頭","首","上半身","上半身2","下半身"]:
   var child:int=kids[0];var target_child:=target.find_bone(source_rig.get_bone_name(child))
   if target_child>=0 and match_id>=0:
    var length:=source_rig.get_bone_global_rest(child).origin.distance_to(source_rig.get_bone_global_rest(i).origin)
    if length>.01:
     var from_dir:Vector3=(source_rig.get_bone_global_rest(child).origin-source_rig.get_bone_global_rest(i).origin).normalized()
     var to_dir:Vector3=(target.get_bone_global_rest(target_child).origin-target.get_bone_global_rest(match_id).origin).normalized()
     if to_dir.length_squared()>.5:rotations[i]=Basis(Quaternion(source_orientation*from_dir,to_dir))*source_orientation
     ratios[i]=clampf(target.get_bone_global_rest(target_child).origin.distance_to(target.get_bone_global_rest(match_id).origin)/length,ratio*.45,ratio*1.8)
 var skin:=Skin.new()
 for i in range(target.get_bone_count()):skin.add_bind(i,target.get_bone_global_rest(i).affine_inverse())
 var originals:Array=[];meshes(source,originals)
 var result:Array=[]
 for original in originals:
  if not original.skin:continue
  var mesh:=ArrayMesh.new()
  for surface in range(original.mesh.get_surface_count()):
   var arrays:Array=original.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var joints:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
   var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var count:int=joints.size()/vertices.size()
   for v in range(vertices.size()):
    var position:=Vector3.ZERO;var normal:=Vector3.ZERO
    for k in range(count):
     var slot:=v*count+k;var bind:int=joints[slot]
     var source_id:int=original.skin.get_bind_bone(bind)
     if source_id<0:source_id=source_rig.find_bone(original.skin.get_bind_name(bind))
     if source_id<0:continue
     var target_id:int=mapping[source_id]
     var before:=source_rig.get_bone_global_rest(int(anchors[source_id]))
     var after:=target.get_bone_global_rest(target_id)
     if source_id in head_bones and source_bounds.size.y>.001:
      position+=(head_joint+(vertices[v]-head_pivot)*ratio*head_scale)*weights[slot]
     elif source_rig.get_bone_name(source_id) in ["下半身","上半身","上半身2","首"]:
      var relative:Vector3=vertices[v]-source_hip
      var along:float=relative.y/maxf(.001,source_neck.y-source_hip.y)
      var axis:Vector3=target_hip.lerp(target_neck,along)
      position+=(axis+Vector3(relative.x*ratio,0,relative.z*ratio))*weights[slot]
     else:
      position+=(after.origin+rotations[source_id]*(vertices[v]-before.origin)*float(ratios[source_id]))*weights[slot]
     normal+=(rotations[source_id]*normals[v])*weights[slot]
     joints[slot]=target_id
    vertices[v]=position;normals[v]=normal.normalized()
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_BONES]=joints
   arrays[Mesh.ARRAY_TANGENT]=null
   mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var instance:=MeshInstance3D.new();instance.name="FittedHologramSkeleton";instance.mesh=mesh;instance.skin=skin
  target.add_child(instance);instance.skeleton=NodePath("..");result.append(instance)
 source.free()
 return result

