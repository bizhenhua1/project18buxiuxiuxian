extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scenery=load("res://scripts/world3d/scenery.gd").new();root.add_child(scenery)
 scenery.bounded_ground=true
 var pixels:=Image.create(32,32,false,Image.FORMAT_RGBA8);pixels.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(pixels)
 var space:=SpaceType.new();space.key=&"crystal"
 var region:=RouteRegion.new();region.space=space
 var base:Dictionary={"texture":texture,"position":Vector2(20,20),"route_s":20.0,"w":80.0,"h":120.0,"flip":false,"region":region,"biome_prop":true,"ground_contact":true,"ground_anchor":Vector2(.5,.65)}
 var other:=base.duplicate();other.ground_anchor=Vector2(.5,.92)
 var shell:=base.duplicate();shell.shell=true
 var groups:Dictionary={}
 for sprite in [base,other,shell,base.duplicate()]:scenery.add_sprite_to_groups(sprite,groups)
 if groups.size()!=3:
  push_error("Different contact anchors and shell profiles must not share geometry; got %d groups"%groups.size());scenery.free();quit(1);return
 for group in groups.values():
  scenery.build_group(group)
  var item:Dictionary=group.items[0]
  var profile:PackedFloat32Array=scenery.contact_cache[texture]
  var expected:Mesh=preload("res://scripts/world3d/contact_geometry.gd").bounded_contact_mesh(Vector2(item.member.w,item.member.h)/20,item.member.anchor.y,profile)
  var actual:Array=scenery.chunks.back().multimesh.mesh.surface_get_arrays(0)
  var wanted:Array=expected.surface_get_arrays(0)
  for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:assert(actual[channel]==wanted[channel],"Batch must use its own contact geometry")
 var meshes:Array=[]
 for chunk in scenery.chunks:
  var mesh:Mesh=chunk.multimesh.mesh
  if meshes.has(mesh):push_error("Different contact shapes reused one cached mesh");scenery.free();quit(1);return
  meshes.append(mesh)
 assert(scenery.by_texture.size()==1,"Contact variants should still share material")
 assert(scenery.imported_count==4)
 var ordinary:Dictionary={};scenery.bounded_ground=false
 for sprite in [base,other,shell]:scenery.add_sprite_to_groups(sprite,ordinary)
 assert(ordinary.size()==1,"Unbounded geometry must retain existing batching")
 scenery.free()
 print("WORLD3D_CONTACT_BATCH_IDENTITY_PASS anchors and shell topology isolated; identical instances batched; shared material retained")
 quit()
