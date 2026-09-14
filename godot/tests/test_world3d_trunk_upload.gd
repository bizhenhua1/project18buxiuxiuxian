extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scenery=preload("res://scripts/world3d/scenery.gd").new();root.add_child(scenery)
 scenery.trunk_placement=preload("res://scripts/world3d/trunk_placement.gd").new()
 var pixels:=Image.create(8,8,false,Image.FORMAT_RGBA8);pixels.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(pixels)
 var space:=SpaceType.new();space.key=&"forest"
 var region:=RouteRegion.new();region.space=space
 var source:Dictionary={"texture":texture,"position":Vector2(200,20),"route_s":20.0,"route_branch":0,"trunk_radius":8.0,"w":30.0,"h":50.0,"flip":false,"region":region}
 var second:=source.duplicate();second.position=Vector2(200,500);second.route_s=500.0
 var batch:Array=[source,second]
 scenery.queue_sprites(batch)
 scenery.process_uploads(1)
 assert(scenery.upload_jobs[0].reserve_cursor==1 and scenery.upload_jobs[0].cursor==0)
 assert(not source.has("native_trunk_id"),"Queue reservation changed input array or dictionary")
 scenery.retire_before(100)
 var frames:=0
 while not scenery.upload_jobs.is_empty() and frames<100:
  scenery.process_uploads(1);frames+=1
 assert(scenery.upload_jobs.is_empty())
 assert(scenery.chunks.size()==1,"Expired reserved trunk must not reappear")
 assert(scenery.trunk_placement.entries.size()==1)
 scenery.retire_before(800)
 assert(scenery.trunk_placement.entries.is_empty() and scenery.trunk_placement.buckets.is_empty())
 var pause_a:=source.duplicate();pause_a.position=Vector2(220,2000);pause_a.route_s=2000;pause_a.route_branch=-1
 var pause_b:=pause_a.duplicate();pause_b.position+=Vector2(1,1);pause_b.route_branch=1
 var reserved:Array=scenery.trunk_placement.prepare([pause_a,pause_b])
 var pending:Dictionary=scenery.trunk_placement.begin_place(reserved[0])
 assert(not pending.done,"Fixture must pause inside a conflicting placement")
 scenery.trunk_placement.step_place(pending)
 assert(not pending.done and pending.attempt==1,"One step must try only one candidate")
 scenery.retire_before(3000)
 scenery.trunk_placement.step_place(pending)
 assert(pending.done and scenery.trunk_placement.entries.is_empty() and scenery.trunk_placement.buckets.is_empty(),"Resuming cancelled search resurrected retired occupancy")
 assert(scenery.trunk_placement.begin_place(reserved[1]).done,"Retired reservation must be ignored before search begins")
 assert(scenery.trunk_placement.begin_place(pause_a).done,"Expired unreserved source must not be registered")
 var future:=source.duplicate();future.route_s=4000
 var cancelled:Dictionary=scenery.trunk_placement.reserve(future)
 scenery.trunk_placement.trim_after(3500)
 assert(scenery.trunk_placement.begin_place(cancelled).done,"Cancelled future reservation must not be recreated")
 assert(scenery.trunk_placement.entries.is_empty() and scenery.trunk_placement.buckets.is_empty())
 print("WORLD3D_TRUNK_UPLOAD_PASS staged reservation, immutable input, retirement during upload, full cleanup")
 quit()
