extends SceneTree
const SCENERY=preload("res://scripts/world3d/scenery.gd")
func _initialize():call_deferred("run")
func run():
 ForestRoute.reset_frame();ForestRoute.configure(false)
 var world:=SegmentWorld.new(ForestArt.new(),load("res://spaces/routes/connected.tres"))
 var sprites:Array=world.sprites.slice(0,250)
 var immediate=SCENERY.new();var queued=SCENERY.new();root.add_child(immediate);root.add_child(queued)
 immediate.append_sprites(sprites);queued.queue_sprites(sprites)
 var ticks:=0
 while not queued.upload_jobs.is_empty():queued.process_uploads(100);ticks+=1
 assert(ticks>1 and immediate.imported_count==queued.imported_count)
 assert(immediate.chunks.size()==queued.chunks.size(),"Queued upload lost or duplicated groups")
 for index in immediate.chunks.size():
  var a:MultiMesh=immediate.chunks[index].multimesh;var b:MultiMesh=queued.chunks[index].multimesh
  assert(a.instance_count==b.instance_count and a.custom_aabb==b.custom_aabb)
  for i in a.instance_count:
   assert(a.get_instance_transform(i)==b.get_instance_transform(i))
   assert(a.get_instance_color(i)==b.get_instance_color(i))
   assert(a.get_instance_custom_data(i)==b.get_instance_custom_data(i))
 var cancelled=SCENERY.new();root.add_child(cancelled);cancelled.queue_sprites(sprites);cancelled.retire_before(INF)
 while not cancelled.upload_jobs.is_empty():cancelled.process_uploads(100)
 assert(cancelled.chunks.is_empty(),"Retired queued work must not resurrect old scenery")
 print("WORLD3D_UPLOADS_PASS ticks=",ticks," instances=",queued.imported_count," peak_usec=",queued.upload_peak_usec,"; sync parity and retired jobs")
 immediate.free();queued.free();cancelled.free();sprites.clear();world=null
 if "--release-shared-cache" in OS.get_cmdline_user_args():
  ForestEcology.textures.clear()
  SpaceAssets.textures.clear();SpaceAssets.shared_silhouettes.clear()
  StyleLibrary.cache.clear();ForestArt.prepared=null
 for i in 3:await process_frame
 quit()
