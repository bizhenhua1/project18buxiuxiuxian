extends SceneTree
const SHAPE=preload("res://scripts/world3d/contact_geometry.gd")
const LOD=preload("res://scripts/world3d/contact_mesh_lod.gd")
func _initialize():
 var cases:=0
 for size in [Vector2(2,2),Vector2(10.5,10.5),Vector2(11,14)]:
  for anchor in [.82,.92,.999]:
   var fine:=SHAPE.bounded_contact_mesh(size,anchor)
   var coarse:=LOD.coarse(fine,SHAPE.bounded_resolution(size,anchor).x)
   var a:=fine.surface_get_arrays(0);var b:=coarse.surface_get_arrays(0)
   assert(a[Mesh.ARRAY_VERTEX]==b[Mesh.ARRAY_VERTEX] and a[Mesh.ARRAY_TEX_UV]==b[Mesh.ARRAY_TEX_UV])
   assert(b[Mesh.ARRAY_INDEX].size()<a[Mesh.ARRAY_INDEX].size())
   var area:=0.0;var uv:PackedVector2Array=b[Mesh.ARRAY_TEX_UV];var indices:PackedInt32Array=b[Mesh.ARRAY_INDEX]
   for i in range(0,indices.size(),3):
    for j in 3:assert(indices[i+j]>=0 and indices[i+j]<uv.size())
    var signed:float=(uv[indices[i+1]]-uv[indices[i]]).cross(uv[indices[i+2]]-uv[indices[i]])*.5
    assert(signed>0);area+=signed
   assert(absf(area-1)<.00001,"LOD lost coverage or introduced overlapping strips")
   cases+=1
 var box:=AABB(Vector3(-1,0,-70),Vector3(2,2,2))
 assert(LOD.distant(box,Vector2.ZERO,0,false))
 assert(not LOD.distant(box,Vector2(0,400),0,true))
 assert(not LOD.distant(box,Vector2(0,260),0,false))
 assert(LOD.distant(box,Vector2(0,260),0,true),"Hysteresis must retain the previous state")
 print("CONTACT_LOD_TOPOLOGY_PASS cases=",cases," full UV coverage, winding, preserved vertices, hysteresis")
 quit()
