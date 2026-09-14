extends RefCounted
static func bake(instance:MeshInstance3D,height_bottom:float,height_top:float,reference_transform:Variant=null):
 # Store an immutable rest-pose height in UV2, which is not deformed by skinning.
 # Work on an editor-owned mesh; imported assets and gameplay materials stay untouched.
 var source:Mesh=instance.mesh
 var baked:=ArrayMesh.new()
 baked.blend_shape_mode=source.blend_shape_mode
 baked.custom_aabb=source.custom_aabb
 for blend in range(source.get_blend_shape_count()):baked.add_blend_shape(source.get_blend_shape_name(blend))
 var span:=maxf(.001,height_top-height_bottom)
 var reference_space:Transform3D=instance.global_transform if reference_transform==null else reference_transform
 for surface in range(source.get_surface_count()):
  var arrays:Array=source.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var reference:=PackedVector2Array();reference.resize(vertices.size())
  for i in range(vertices.size()):
   var point:Vector3=reference_space*vertices[i]
   reference[i]=Vector2((point.y-height_bottom)/span,0.0)
  arrays[Mesh.ARRAY_TEX_UV2]=reference
  # Rest-height metadata must not discard the imported lower-detail meshes.
  var lods:Dictionary={}
  for lod in RenderingServer.mesh_get_surface(source.get_rid(),surface).get("lods",[]):
   var bytes:PackedByteArray=lod.index_data
   var stride:int=2 if vertices.size()<=65536 else 4
   var indices:=PackedInt32Array();indices.resize(bytes.size()/stride)
   for index in indices.size():indices[index]=bytes.decode_u16(index*2) if stride==2 else bytes.decode_u32(index*4)
   lods[float(lod.edge_length)]=indices
  baked.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays,source.surface_get_blend_shape_arrays(surface),lods,source.surface_get_format(surface))
  assert(baked.get_surface_count()==surface+1,"Reference-height mesh rebuild failed")
  baked.surface_set_material(surface,source.surface_get_material(surface))
 instance.mesh=baked
