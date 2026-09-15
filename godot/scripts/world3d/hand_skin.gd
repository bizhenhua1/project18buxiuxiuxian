extends RefCounted
# Correct finger influence extending behind its joint into the palm.
static var cache:Dictionary={}
static func apply(node:Node,rig:Skeleton3D)->void:
 if node is MeshInstance3D and node.skin and node.mesh is ArrayMesh:
  var source:ArrayMesh=node.mesh
  if cache.has(source):node.mesh=cache[source]
  else:
   var binds:Dictionary={};var targets:Dictionary={}
   for b in node.skin.get_bind_count():
    var bone:int=rig.find_bone(node.skin.get_bind_name(b))
    if bone<0:bone=node.skin.get_bind_bone(b)
    binds[bone]=b
   for bone in binds:
    var name:String=rig.get_bone_name(bone)
    if not ("指" in name and (name.ends_with(".L") or name.ends_with(".R"))):continue
    var parent:int=rig.get_bone_parent(bone)
    if not binds.has(parent):continue
    var origin:Vector3=rig.get_bone_global_rest(bone).origin
    var children:=rig.get_bone_children(bone)
    var along:Vector3=origin-rig.get_bone_global_rest(parent).origin
    if not children.is_empty():along=rig.get_bone_global_rest(children[0]).origin-origin
    targets[binds[bone]]=[binds[parent],origin,along.normalized()]
   var output:=ArrayMesh.new()
   for s in source.get_surface_count():
    var arrays:Array=source.surface_get_arrays(s);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
    if bones!=null:
     var count:int=bones.size()/vertices.size()
     for v in vertices.size():
      var combined:Dictionary={}
      for j in count:
       var b:int=bones[v*count+j];var weight:float=weights[v*count+j]
       # Each finger chain is short; move anatomically proximal vertices toward the wrist.
       for step in 4:
        if not targets.has(b):break
        var target:Array=targets[b]
        if (vertices[v]-target[1]).dot(target[2])>=-.004:break
        b=target[0]
       combined[b]=float(combined.get(b,0.0))+weight
      var keys:Array=combined.keys()
      for j in count:
       bones[v*count+j]=keys[j] if j<keys.size() else 0
       weights[v*count+j]=combined[keys[j]] if j<keys.size() else 0.0
     arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
    var lods:Dictionary={}
    for lod in RenderingServer.mesh_get_surface(source.get_rid(),s).get("lods",[]):
     lods[lod.edge_length]=preload("res://scripts/world3d/surface_merge.gd").decode_indices(lod.index_data,vertices.size(),0)
    output.add_surface_from_arrays(source.surface_get_primitive_type(s),arrays,[],lods,source.surface_get_format(s)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
    output.surface_set_material(s,source.surface_get_material(s))
   output.custom_aabb=source.custom_aabb;cache[source]=output;node.mesh=output
 for child in node.get_children():apply(child,rig)
