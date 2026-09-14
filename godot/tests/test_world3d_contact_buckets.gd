extends SceneTree
const SHAPE=preload("res://scripts/world3d/contact_geometry.gd")
func _initialize():
 var small:=Vector2(3.9,1.9);var large:=Vector2(4,2)
 assert(SHAPE.bounded_resolution(small,.87)==SHAPE.bounded_resolution(large,.87))
 var a:Array=SHAPE.bounded_contact_mesh(small,.87).surface_get_arrays(0)
 var b:Array=SHAPE.bounded_contact_mesh(large,.87).surface_get_arrays(0)
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:assert(a[channel]==b[channel],"Shared bucket must generate identical normalized geometry")
 for height in [.2,1.9,2.0,6.7,10.5,16.0]:
  for anchor in [.65,.87,.92]:
   var size:=Vector2(8,height)
   var resolution:Vector2i=SHAPE.bounded_resolution(size,anchor)
   var depth:float=(1-anchor)*height*1.6
   assert(resolution.y==32 or depth/resolution.y<=.250001,"Uncapped contact steps exceed world spacing budget")
   assert(resolution.x<=65 and resolution.y<=32)
 print("WORLD3D_CONTACT_BUCKETS_PASS identical shared geometry and bounded physical spacing")
 quit()
