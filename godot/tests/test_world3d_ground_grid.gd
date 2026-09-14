extends SceneTree
const GRID=preload("res://scripts/world3d/ground_grid.gd")
func _initialize():
 var arrays:=GRID.mesh().get_mesh_arrays()
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 assert(vertices.size()==161*261)
 for vertex in vertices:
  assert(absf(vertex.x-roundf(vertex.x))<.00002 and absf(vertex.z-roundf(vertex.z))<.00002,"Terrain vertices must lie on the world metre lattice")
 var offsets:Array[Vector2]=[Vector2.ZERO,Vector2(.1,.1),Vector2(-.1,-.1),Vector2(19.99,20.01),Vector2(-20.01,137.5),Vector2(5373.5,-6251.2)]
 for camera in offsets:
  var origin:=GRID.patch_origin(camera)
  var desired:=Vector3(camera.x/20,0,-camera.y/20-65)
  assert(origin.distance_to(desired)<1.415)
  assert(origin.x==floor(origin.x) and origin.z==floor(origin.z))
  # The same triangle offsets recur at every cell, independent of patch movement.
  for i in range(0,indices.size(),6):
   var a:=vertices[indices[i]];var b:=vertices[indices[i+1]];var c:=vertices[indices[i+2]]
   assert((b-a).is_equal_approx(vertices[indices[1]]-vertices[indices[0]]))
   assert((c-a).is_equal_approx(vertices[indices[2]]-vertices[indices[0]]))
 print("WORLD3D_GROUND_GRID_PASS vertices=",vertices.size()," triangles=",indices.size()/3," camera_offsets=",offsets.size())
 print("GRID_FIRST_TRIANGLE ",vertices[indices[0]]," ",vertices[indices[1]]," ",vertices[indices[2]])
 # Sample barycentric points from the mesh's own index buffer, independently
 # of the query's cell/diagonal choice. Cover both triangles and negative cells.
 var saved_height=ForestSettings.values.height
 var checked:=0
 for amplitude in [1.0,5.0]:
  ForestSettings.values.height=amplitude
  for triangle in range(0,indices.size(),297):
   var a:=vertices[indices[triangle]];var b:=vertices[indices[triangle+1]];var c:=vertices[indices[triangle+2]]
   for weights in [Vector3(.1,.2,.7),Vector3(.6,.3,.1),Vector3(.5,.5,0)]:
    var p:Vector3=a*weights.x+b*weights.y+c*weights.z
    var expected:float=(ForestEcology.height_at(Vector2(a.x,-a.z)*20)*weights.x+ForestEcology.height_at(Vector2(b.x,-b.z)*20)*weights.y+ForestEcology.height_at(Vector2(c.x,-c.z)*20)*weights.z)/20.0
    assert(absf(GRID.support_height(Vector2(p.x,p.z))-expected)<.00002,"Support query differs from indexed terrain triangle")
    checked+=1
 ForestSettings.values.height=saved_height
 print("WORLD3D_TRIANGLE_SUPPORT_PASS samples=",checked)
 quit()
