extends SceneTree
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":push_error("GPU buffer comparison requires graphics backend");quit(1);return
 var classic=preload("res://scripts/world3d/scenery.gd").new();root.add_child(classic);classic.stream_spatial_blocks=false
 var streamed=preload("res://scripts/world3d/scenery.gd").new();root.add_child(streamed);streamed.stream_spatial_blocks=true
 var pixels:=Image.create(8,8,false,Image.FORMAT_RGBA8);pixels.fill(Color.WHITE)
 var texture:=ImageTexture.create_from_image(pixels)
 var space:=SpaceType.new();space.key=&"forest"
 var region:=RouteRegion.new();region.space=space
 var sprites:Array=[]
 # Input deliberately interleaves cells, as ecology layers do in real maps.
 for layer in 5:
  for cell in range(39,-1,-1):
   sprites.append({"texture":texture,"position":Vector2(200,cell*240+10+layer*4),"route_s":float(cell*240+layer*4),"route_branch":0,"w":30.0+layer,"h":50.0,"flip":layer%2==0,"region":region,"ground_anchor":Vector2(.3,1),"root_cover":[{"texture":texture,"height":.2,"x":.2,"foot_y":.95}]})
 classic.queue_sprites(sprites);streamed.queue_sprites(sprites)
 var steps:=0
 while streamed.chunks.is_empty() and steps<1000:streamed.process_uploads(1);steps+=1
 assert(not streamed.chunks.is_empty() and not streamed.upload_jobs.is_empty())
 assert(streamed.upload_jobs[0].cell_cursor==0,"First cell must upload before grouping remote cells")
 assert(streamed.chunks[0].get_meta("end_s")<240)
 if streamed.track_pending_bounds:
  assert(streamed.route_nearby_ready(null,Vector2(200,50),100),"Remote ungrouped cells must not block the loaded near cell")
  assert(not streamed.route_nearby_ready(null,Vector2(200,500),100),"Ungrouped near cells must still block")
 while not streamed.upload_jobs.is_empty() and steps<10000:streamed.process_uploads(1);steps+=1
 while not classic.upload_jobs.is_empty() and steps<20000:classic.process_uploads(1);steps+=1
 assert(classic.upload_jobs.is_empty() and streamed.upload_jobs.is_empty())
 assert(classic.chunks.size()==40 and streamed.chunks.size()==40)
 var reference:Dictionary={}
 for chunk in classic.chunks:reference[chunk.get_meta("end_s")]=chunk
 await process_frame
 for chunk in streamed.chunks:
  var old=reference[chunk.get_meta("end_s")]
  assert(chunk.multimesh.buffer==old.multimesh.buffer,"Streaming changed instance transforms/colors/anchors/order")
  assert(chunk.multimesh.custom_aabb==old.multimesh.custom_aabb,"Streaming changed culling bounds")
  assert(chunk.get_meta("contact_roles")==old.get_meta("contact_roles"))
 assert(streamed.imported_count==400 and classic.imported_count==400)
 # Cancellation/retirement must release the source partitions as well as nodes.
 streamed.queue_sprites(sprites)
 streamed.process_uploads(1)
 streamed.upload_jobs.clear();streamed.retire_before(INF)
 assert(streamed.chunks.is_empty() and streamed.by_texture.is_empty())
 print("WORLD3D_SPATIAL_UPLOAD_PASS 40 original batches / 400 exact GPU instances; early near upload; retirement")
 quit()
