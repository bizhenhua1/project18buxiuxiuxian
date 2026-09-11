extends RefCounted
static func bake(instance:MeshInstance3D,height_bottom:float,height_top:float):
 # Store an immutable rest-pose height in UV2, which is not deformed by skinning.
 # Work on an editor-owned mesh; imported assets and gameplay materials stay untouched.
 var source:Mesh=instance.mesh
 var baked:=ArrayMesh.new()
 for blend in range(source.get_blend_shape_count()):baked.add_blend_shape(source.get_blend_shape_name(blend))
 var span:=maxf(.001,height_top-height_bottom)
 for surface in range(source.get_surface_count()):
  var arrays:Array=source.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var reference:=PackedVector2Array();reference.resize(vertices.size())
  for i in range(vertices.size()):
   var point:Vector3=instance.global_transform*vertices[i]
   reference[i]=Vector2((point.y-height_bottom)/span,0.0)
  arrays[Mesh.ARRAY_TEX_UV2]=reference
  baked.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays,source.surface_get_blend_shape_arrays(surface),{},source.surface_get_format(surface))
  assert(baked.get_surface_count()==surface+1,"Reference-height mesh rebuild failed")
  baked.surface_set_material(surface,source.surface_get_material(surface))
 instance.mesh=baked
