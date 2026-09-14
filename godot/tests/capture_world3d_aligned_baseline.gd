extends SceneTree
# Independent runtime formation/pose. Route specification, settings and sample
# distance match the formal capture; no rig, actor transforms or scale copied.
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../tempassets/work/formal-battle-baseline.json"))
 set_meta("world3d_route_fixture",reference.route_zone)
 ForestSettings.values=reference.forest_settings.duplicate(true)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 stage.set_inspection_expanded(false)
 assert(stage.world.sprites.size()==reference.sprites.size())
 for i in reference.sprites.size():
  var a:Dictionary=stage.world.sprites[i];var b:Dictionary=reference.sprites[i]
  assert(a.texture.resource_path==b.texture)
  assert(a.position.distance_to(Vector2(b.position[0],b.position[1]))<.001)
  assert(absf(a.w-b.width)<.001 and absf(a.h-b.height)<.001)
 stage.distance=float(reference.distance)
 stage.encounter_anchor=stage.route_segment.point(stage.distance,stage.branch)
 stage.camera_origin=stage.encounter_anchor
 stage.camera_heading=stage.route_segment.pose(stage.distance,stage.branch).heading
 for i in stage.team.size():stage.team[i].position=stage.slot_position(i)
 for i in 30:stage._process(1.0/60)
 # Synchronize only animation time/identity, not positions, sizes or shader output.
 # Formal cards use unit uid as their deterministic bob phase.
 assert(reference.has("prop_visual_time"),"Refresh formal baseline with prop timing")
 var prop_time:float=reference.prop_visual_time
 stage.clock=float(str_to_var(reference.lighting_inputs.atmosphere_time))
 for item in stage.props:item.bob_phase=float(reference.cards[item.slot].uid)+2*(prop_time-stage.clock)
 stage._process(0)
 var report:Dictionary={"distance":stage.distance,"camera":[stage.bridge.camera_world.x,stage.bridge.camera_world.y],"frame":stage.frame.duplicate(true),"actors":[],"verified_source_sprites":reference.sprites.size(),"scope":"Same route specification/settings/distance, independently generated scatter and computed formation/pose; bones are not mesh silhouette"}
 var screen:Transform2D=shell.container.get_global_transform_with_canvas()
 report.content_rect_pixels=[screen.origin.x,screen.origin.y,(screen.x*shell.container.size.x).length(),(screen.y*shell.container.size.y).length()]
 report.props=[]
 report.transparency_candidates=[]
 for item in stage.props:
  var anchor:Vector3=item.node.position
  var near_chunks:=0;var crossing:=0;var instances:=0
  for chunk in stage.scenery.chunks:
   if not chunk.visible:continue
   var box:AABB=chunk.multimesh.custom_aabb
   var half_width:float=item.node.texture.get_width()*item.node.pixel_size*.5
   if box.end.x<anchor.x-half_width or box.position.x>anchor.x+half_width:continue
   if box.end.z<anchor.z or box.position.z>anchor.z:continue
   near_chunks+=1
   var low:=INF;var high:=-INF
   for index in chunk.multimesh.instance_count:
    var z:float=chunk.multimesh.get_instance_transform(index).origin.z
    low=minf(low,z);high=maxf(high,z)
   if low<anchor.z and high>anchor.z:
    crossing+=1;instances+=chunk.multimesh.instance_count
  report.transparency_candidates.append({"slot":item.slot,"bounds_crossing":near_chunks,"anchor_depth_crossing":crossing,"instances_in_crossing_batches":instances})
 print("ALIGNED_TRANSPARENCY_CANDIDATES ",JSON.stringify(report.transparency_candidates))
 report.lighting_differences={}
 var lighting:Dictionary=stage.bridge.combat_light_parameters();lighting.merge(stage.bridge.biome_parameters())
 lighting.merge({"lantern_position":stage.bridge.lantern_position(),"lantern_enabled":stage.bridge.lantern_enabled,"atmosphere_time":stage.bridge.elapsed,"region_tint":stage.world.camera_region.space.ambient})
 for key in reference.get("lighting_inputs",{}):
  var native_value:String=var_to_str(lighting.get(key))
  if native_value!=reference.lighting_inputs[key]:report.lighting_differences[key]={"formal":reference.lighting_inputs[key],"native":native_value}
 print("ALIGNED_LIGHTING_DIFF ",JSON.stringify(report.lighting_differences))
 assert(report.lighting_differences.is_empty(),"Same-frame comparison requires matching lighting inputs")
 for item in stage.props:
  var node:Sprite3D=item.node
  var height:float=node.texture.get_height()*node.pixel_size
  var width:float=node.texture.get_width()*node.pixel_size
  var right:=Vector3(stage.camera.global_basis.x.x,0,stage.camera.global_basis.x.z).normalized()
  var top_left:Vector2=screen*stage.camera.unproject_position(node.position-right*width*.5+Vector3.UP*height)
  var bottom_right:Vector2=screen*stage.camera.unproject_position(node.position+right*width*.5)
  var formal:Array=reference.cards[item.slot].rect
  var origin:Array=reference.content_rect_pixels
  var ratio:=Vector2(float(origin[2])/reference.arena_size[0],float(origin[3])/reference.arena_size[1])
  var expected:=Vector2(origin[0],origin[1])+Vector2(formal[0],formal[1])*ratio
  # SceneFormation adds 38 logical pixels for the card HUD beneath its art.
  var expected_end:=expected+Vector2(formal[2],formal[3]-38.0)*ratio
  var error:float=maxf(top_left.distance_to(expected),bottom_right.distance_to(expected_end))
  report.props.append({"slot":item.slot,"texture":stage.prop_atmosphere.entries[stage.props.find(item)].source.resource_path,"corner_error_pixels":error})
  assert(error<.05,"Prop art corners differ after removing HUD padding and synchronizing bob phase")
  print("ALIGNED_PROP slot=",item.slot," corner_error_px=",error)
 for actor in stage.team:
  var landmarks:Dictionary={}
  var pixels:Dictionary={};var errors:Dictionary={}
  var matches:Array=reference.actors.filter(func(entry):return entry.get("model","")==actor.model_key)
  for name in ["頭","首","手首.L","手首.R","足首.L","足首.R"]:
   var bone:int=actor.rig.find_bone(name)
   if bone<0:continue
   var world:Vector3=actor.rig.global_transform*actor.rig.get_bone_global_pose(bone).origin
   var pixel:Vector2=stage.camera.unproject_position(actor.portrait_presenter.presented_attachment(world,stage.camera))
   landmarks[name]=[pixel.x,pixel.y]
   var window_pixel:Vector2=screen*pixel
   pixels[name]=[window_pixel.x,window_pixel.y]
   if matches.size()==1 and matches[0].landmarks_pixels.has(name):
    var other:Array=matches[0].landmarks_pixels[name]
    errors[name]=window_pixel.distance_to(Vector2(other[0],other[1]))
  report.actors.append({"model":actor.model_key,"scale":actor.scale.x,"position":[actor.position.x,actor.position.y,actor.position.z],"landmarks_content_pixels":landmarks,"landmarks_window_pixels":pixels,"formal_distance_pixels":errors})
  print("ALIGNED_LANDMARKS ",actor.model_key," ",JSON.stringify(errors))
 for i in 4:await process_frame
 if "--foreground-depth-bands" in OS.get_cmdline_user_args():
  report.depth_bands=load("res://tests/fixtures/foreground_depth_bands.gd").apply(stage)
  print("FOREGROUND_DEPTH_BANDS ",JSON.stringify(report.depth_bands))
  for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 var suffix:="-depth-bands" if "--foreground-depth-bands" in OS.get_cmdline_user_args() else ""
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-aligned-baseline"+suffix+".png")
 FileAccess.open("res://../tempassets/work/world3d-aligned-baseline"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("WORLD3D_ALIGNED_BASELINE_CAPTURE distance=",stage.distance," camera=",stage.bridge.camera_world)
 quit()
