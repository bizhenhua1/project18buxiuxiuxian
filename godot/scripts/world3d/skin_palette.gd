extends RefCounted
# Experimental exact palette remap. Skeleton hierarchy/rests/animation stay intact.
# Raw surface roundtrip preserves compressed vertices, material slots and LODs.
static var cache:Dictionary={}
static func apply(node:Node):
 if node is MeshInstance3D and node.mesh is ArrayMesh and node.skin!=null:
  var result:Dictionary=compact(node.mesh,node.skin)
  node.mesh=result.mesh;node.skin=result.skin
 for child in node.get_children():apply(child)
static func compact(mesh:ArrayMesh,skin:Skin)->Dictionary:
 var key:=str(mesh.get_instance_id())+":"+str(skin.get_instance_id())
 if cache.has(key):return cache[key]
 if mesh.get_blend_shape_count()>0:return {"mesh":mesh,"skin":skin,"skipped":"blend shapes"}
 if mesh.shadow_mesh!=null:return {"mesh":mesh,"skin":skin,"skipped":"separate shadow mesh"}
 var surfaces:Array=mesh.get("_surfaces").duplicate(true)
 var used:Dictionary={}
 for surface in surfaces:
  var bytes:PackedByteArray=surface.get("skin_data",PackedByteArray())
  var count:int=surface.vertex_count
  if count==0 or bytes.size()!=count*16:return {"mesh":mesh,"skin":skin,"skipped":"unsupported skin stride"}
  for vertex in count:
   for influence in 4:
    if bytes.decode_u16(vertex*16+8+influence*2)>0:
     var index:int=bytes.decode_u16(vertex*16+influence*2)
     assert(index<skin.get_bind_count())
     used[index]=true
 var indices:Array=used.keys();indices.sort()
 if indices.is_empty():return {"mesh":mesh,"skin":skin,"skipped":"no positive weights"}
 var remap:Dictionary={};var compact_skin:=Skin.new()
 for old_index in indices:
  remap[old_index]=compact_skin.get_bind_count()
  var name:StringName=skin.get_bind_name(old_index)
  if name.is_empty():compact_skin.add_bind(skin.get_bind_bone(old_index),skin.get_bind_pose(old_index))
  else:compact_skin.add_named_bind(name,skin.get_bind_pose(old_index))
 for surface in surfaces:
  var bytes:PackedByteArray=surface.skin_data
  for vertex in int(surface.vertex_count):
   for influence in 4:
    var offset:int=vertex*16+influence*2
    bytes.encode_u16(offset,int(remap.get(bytes.decode_u16(offset),0)))
  surface.skin_data=bytes
  var old_bounds:Array=surface.get("bone_aabbs",[]);var bounds:Array=[]
  for index in indices:bounds.append(old_bounds[index] if index<old_bounds.size() else AABB(Vector3.ZERO,-Vector3.ONE))
  surface.bone_aabbs=bounds
 var compact_mesh:=ArrayMesh.new();compact_mesh.set("_surfaces",surfaces)
 compact_mesh.custom_aabb=mesh.custom_aabb
 var result:Dictionary={"mesh":compact_mesh,"skin":compact_skin,"indices":indices,"source_mesh":mesh,"source_skin":skin}
 cache[key]=result
 return result
