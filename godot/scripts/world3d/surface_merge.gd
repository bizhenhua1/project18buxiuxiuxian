extends RefCounted
# Each compatible source mesh is converted once and shared by native 3D actors.
static var cache:Dictionary={}
static func material_key(material:Material)->String:
 if not material is StandardMaterial3D:return str(material.get_instance_id()) if material else "none"
 var values:Array=[]
 for property in material.get_property_list():
  if not int(property.usage)&PROPERTY_USAGE_STORAGE:continue
  if property.name in ["resource_name","resource_local_to_scene","resource_path"]:continue
  var value=material.get(property.name)
  values.append([property.name,value.get_instance_id() if value is Resource else value])
 return var_to_bytes(values).hex_encode()
static func decode_indices(bytes:PackedByteArray,count:int,offset:int)->PackedInt32Array:
 var stride:int=2 if count<=65536 else 4
 var result:=PackedInt32Array();result.resize(bytes.size()/stride)
 for i in result.size():result[i]=(bytes.decode_u16(i*2) if stride==2 else bytes.decode_u32(i*4))+offset
 return result
static func merge(source:ArrayMesh)->ArrayMesh:
 if cache.has(source):return cache[source]
 if source.get_blend_shape_count()>0 or source.shadow_mesh!=null:return source
 var groups:Dictionary={}
 for i in source.get_surface_count():
  if source.surface_get_primitive_type(i)!=Mesh.PRIMITIVE_TRIANGLES:return source
  if source.surface_get_format(i)&(Mesh.ARRAY_FORMAT_CUSTOM0|Mesh.ARRAY_FORMAT_CUSTOM1|Mesh.ARRAY_FORMAT_CUSTOM2|Mesh.ARRAY_FORMAT_CUSTOM3):return source
  var key:=str(source.surface_get_format(i))+":"+material_key(source.surface_get_material(i))
  if not groups.has(key):groups[key]=[]
  groups[key].append(i)
 if groups.size()==source.get_surface_count():return source
 var output:=ArrayMesh.new()
 for group in groups.values():
  var combined:Array=[];combined.resize(Mesh.ARRAY_MAX)
  var members:Array=[];var thresholds:Dictionary={};var offset:=0
  for index in group:
   var arrays:Array=source.surface_get_arrays(index)
   var count:int=arrays[Mesh.ARRAY_VERTEX].size()
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(count))
   indices=indices.duplicate()
   for j in indices.size():indices[j]+=offset
   arrays[Mesh.ARRAY_INDEX]=indices
   for channel in Mesh.ARRAY_MAX:
    if arrays[channel]==null:continue
    if combined[channel]==null:combined[channel]=arrays[channel].duplicate()
    else:combined[channel].append_array(arrays[channel])
   var lods:Array=[]
   for lod in RenderingServer.mesh_get_surface(source.get_rid(),index).get("lods",[]):
    var edge:float=lod.edge_length;thresholds[edge]=true
    lods.append({"edge":edge,"indices":decode_indices(lod.index_data,count,offset)})
   lods.sort_custom(func(a,b):return a.edge<b.edge)
   members.append({"indices":indices,"lods":lods});offset+=count
  # Preserve every source transition, retaining full-detail indices for members
  # which have not reached their own threshold at this combined level.
  var merged_lods:Dictionary={};var edges:Array=thresholds.keys();edges.sort()
  for edge in edges:
   var indices:=PackedInt32Array()
   for member in members:
    var chosen:PackedInt32Array=member.indices
    for lod in member.lods:
     if lod.edge>edge:break
     chosen=lod.indices
    indices.append_array(chosen)
   merged_lods[edge]=indices
  var flags:int=source.surface_get_format(group[0])&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
  output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,combined,[],merged_lods,flags)
  output.surface_set_material(output.get_surface_count()-1,source.surface_get_material(group[0]))
 output.custom_aabb=source.custom_aabb
 cache[source]=output
 return output
static func apply(node:Node):
 if node is MeshInstance3D and node.mesh is ArrayMesh and node.material_override==null:
  var overridden:=false
  for i in node.mesh.get_surface_count():overridden=overridden or node.get_surface_override_material(i)!=null
  if not overridden:node.mesh=merge(node.mesh)
 for child in node.get_children():apply(child)
