extends SceneTree
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":
  push_error("MultiMesh custom-data readback requires a graphics backend")
  quit(1);return
 var scenery=load("res://scripts/world3d/scenery.gd").new();root.add_child(scenery)
 var image:=Image.create(8,8,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(image)
 var forest:=SpaceType.new();forest.key=&"forest"
 var crystal:=SpaceType.new();crystal.key=&"crystal"
 var a:=RouteRegion.new();a.space=forest
 var b:=RouteRegion.new();b.space=crystal
 var common:Dictionary={"texture":texture,"position":Vector2(20,20),"w":30.0,"h":50.0,"flip":false,"altitude":0.0,"region":a,"biome_prop":true}
 var grounded:Dictionary=common.duplicate();grounded.region=b
 var shell:Dictionary=grounded.duplicate();shell.shell=true;shell.plane_heading=.3
 var groups:Dictionary={}
 # Ordinary crystal comes first, so a later shell must still install its profile.
 for sprite in [common,grounded,shell]:scenery.add_sprite_to_groups(sprite,groups)
 assert(groups.size()==2,"Reused texture across themes must split incompatible geometry")
 for group in groups.values():scenery.build_group(group)
 assert(scenery.imported_count==3 and scenery.chunks.size()==2)
 var counts:Dictionary={}
 for chunk in scenery.chunks:
  var mm:MultiMesh=chunk.multimesh
  for i in mm.instance_count:
   var mode:int=int(absf(mm.get_instance_custom_data(i).b))
   counts[mode]=int(counts.get(mode,0))+1
 assert(counts.get(1,0)==1 and counts.get(3,0)==1 and counts.get(21,0)==1)
 assert(scenery.contact_cache.has(texture),"Later shell must configure the shared contact profile")
 print("WORLD3D_MIXED_GEOMETRY_BATCH_PASS shared texture, distinct modes, late shell contact")
 quit()
