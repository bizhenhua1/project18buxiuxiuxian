extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scenery=preload("res://scripts/world3d/scenery.gd").new();root.add_child(scenery)
 scenery.stream_spatial_blocks=false
 var pixels:=Image.create(8,8,false,Image.FORMAT_RGBA8);pixels.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(pixels)
 var space:=SpaceType.new();space.key=&"forest"
 var region:=RouteRegion.new();region.space=space
 var sprites:Array=[]
 for distance in [3000.0,3020.0,100.0,120.0,1500.0]:
  sprites.append({"texture":texture,"position":Vector2(200,distance),"route_s":distance,"route_branch":0,"w":30.0,"h":50.0,"flip":false,"region":region})
 scenery.queue_sprites(sprites)
 var steps:=0
 while not scenery.upload_jobs[0].grouped and steps<100:
  scenery.process_uploads(1);steps+=1
 assert(steps<100 and scenery.chunks.is_empty())
 assert(not scenery.route_nearby_ready(null,Vector2.ZERO,1000))
 scenery.process_uploads(1)
 assert(scenery.chunks.size()==1)
 assert(scenery.chunks[0].get_meta("route_samples")==[100.0,120.0],"Near batch must upload first without reordering its instances")
 assert(scenery.route_nearby_ready(null,Vector2.ZERO,1000),"Far pending batches should not block local coverage")
 assert(not scenery.route_nearby_ready(null,Vector2(200,1500),100),"Moving toward a pending batch must remain blocked")
 var saved:AABB=scenery.upload_jobs[0].ready[1].bounds
 scenery.upload_jobs[0].ready[1].bounds=AABB(Vector3(-5,0,-80),Vector3(10,5,60))
 assert(not scenery.route_nearby_ready(null,Vector2.ZERO,1000),"Large art extending into view must block even when its origin is far away")
 scenery.upload_jobs[0].ready[1].bounds=saved
 while not scenery.upload_jobs.is_empty() and steps<200:
  scenery.process_uploads(1);steps+=1
 assert(scenery.upload_jobs.is_empty() and scenery.chunks.size()==3)
 assert(scenery.chunks[1].get_meta("route_samples")==[1500.0])
 assert(scenery.chunks[2].get_meta("route_samples")==[3000.0,3020.0])
 assert(sprites[0].route_s==3000 and sprites[4].route_s==1500,"Source art order must remain unchanged")
 assert(scenery.imported_count==5)
 print("WORLD3D_UPLOAD_PRIORITY_PASS near first; original batches, instances and source order preserved")
 quit()
