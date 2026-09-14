extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scenery=load("res://scripts/world3d/scenery.gd").new();root.add_child(scenery)
 var pixels:=Image.create(8,8,false,Image.FORMAT_RGBA8);pixels.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(pixels)
 var space:=SpaceType.new();space.key=&"forest"
 var region:=RouteRegion.new();region.space=space
 var a:Dictionary={"texture":texture,"position":Vector2(20,20),"route_s":20.0,"w":30.0,"h":50.0,"flip":false,"region":region}
 var b:=a.duplicate();b.position=Vector2(20,500);b.route_s=500.0
 if scenery.bounded_ground:
  space.key=&"crystal"
  a.biome_prop=true;a.ground_anchor=Vector2(.5,.87);a.w=210;a.h=210
  b.biome_prop=true;b.ground_anchor=Vector2(.5,.87);b.w=330;b.h=330
 scenery.append_sprites([a,b])
 assert(scenery.chunks.size()==2 and scenery.by_texture.size()==1)
 if scenery.bounded_ground:
  assert(scenery.mesh_cache.size()==2,"Different contact size buckets must have separate geometry")
  assert(scenery.by_texture[texture].get_shader_parameter("precise_ground_contact"))
 var sampled:Texture2D=scenery.by_texture[texture].get_shader_parameter("art")
 var weak_sample:WeakRef=weakref(sampled);sampled=null
 scenery.retire_before(100)
 assert(scenery.chunks.size()==1 and scenery.by_texture.size()==1,"Shared live art must survive retirement")
 scenery.queue_sprites([b])
 scenery.retire_before(600)
 assert(scenery.by_texture.size()==1,"Pending uploads retain their art")
 scenery.upload_jobs.clear();scenery.release_unused_art()
 assert(scenery.by_texture.is_empty() and scenery.mesh_cache.is_empty() and scenery.materials.is_empty() and scenery.visible_materials.is_empty() and scenery.contact_offsets.is_empty())
 await process_frame;await process_frame
 assert(weak_sample.get_ref()==null,"Retired mip texture must actually be released")
 # A later route may reuse the same source; rebuilding must remain valid.
 b.route_s=900;scenery.append_sprites([b])
 assert(scenery.by_texture.size()==1 and scenery.chunks.size()==1)
 scenery.queue_free();await process_frame
 print("WORLD3D_ART_RETIREMENT_PASS shared live/pending preservation, actual release, reload")
 quit()
