extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var baseline=JSON.parse_string(FileAccess.get_file_as_string("res://../tempassets/work/formal-battle-baseline.json"))
 var formal_world:bool="--formal-world" in OS.get_cmdline_user_args()
 if formal_world:
  set_meta("world3d_route_fixture",baseline.route_zone)
  ForestSettings.values=baseline.forest_settings.duplicate(true)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 for i in 4:await process_frame
 if formal_world:
  var app=shell.stage
  app.distance=baseline.distance
  app.encounter_anchor=Vector2(baseline.camera[0],baseline.camera[1])-Vector2(app.frame.lateral,app.frame.forward)
  app.camera_origin=app.encounter_anchor
  for i in app.team.size():app.team[i].position=app.slot_position(i)
  app._process(0)
  assert(app.world.sprites.size()==baseline.sprites.size(),"Formal route scatter count differs")
  for i in baseline.sprites.size():
   var source=baseline.sprites[i];var actual=app.world.sprites[i]
   assert(actual.texture.resource_path==source.texture)
   assert(actual.position.distance_to(Vector2(source.position[0],source.position[1]))<.001)
   assert(absf(actual.w-source.width)<.001 and absf(actual.h-source.height)<.001)
  print("FORMAL_SCATTER_PARITY sprites=",baseline.sprites.size()," identical textures, positions and sizes")
 var rect:Array=baseline.content_rect_pixels
 var space=shell.stage.world.camera_region.space
 assert(space.ground_texture.resource_path==baseline.space.ground_texture)
 for key in ["ground_tint","ambient","top_color"]:assert(space.get(key).to_html()==baseline.space[key],"Formal scene color mismatch: "+key)
 for key in ["depth_color","haze_color"]:assert(space.atmosphere.get(key).to_html()==baseline.space[key],"Formal atmosphere mismatch: "+key)
 assert(shell.container.global_position.distance_to(Vector2(rect[0],rect[1]))<1)
 assert((shell.container.size*shell.container.scale).distance_to(Vector2(rect[2],rect[3]))<1)
 assert(shell.stage.bridge.view_size.distance_to(Vector2(baseline.renderer_size[0],baseline.renderer_size[1]))<2)
 var slot_error:=0.0
 assert(shell.stage.units.size()==baseline.cards.size(),"Baseline lineup changed; recapture the formal entry with the same lineup")
 for index in baseline.cards.size():
  var reference:Dictionary=baseline.cards[index]
  assert(shell.stage.units[index].cardId==reference.id,"Cannot compare different lineups")
  for key in ["x","depth","height","clearance"]:
   slot_error=maxf(slot_error,absf(float(shell.stage.profiles[index][key])-float(reference.slot[key])))
 assert(slot_error<.01,"Native formation differs from independent formal runtime")
 print("FORMAL_SLOT_PARITY max route-unit error=",slot_error)
 var comparisons:Array=[]
 var matched_pose:bool="--matched-pose" in OS.get_cmdline_user_args()
 if matched_pose:shell.stage.set_process(false)
 var transform:Transform2D=shell.container.get_global_transform_with_canvas()
 for actor in shell.stage.team:
  var matches:Array=baseline.actors.filter(func(item):return item.get("model","")==actor.model_key)
  if matches.size()!=1:continue
  var reference:Dictionary=matches[0]
  var native_ground:float=actor.position.y*20-ForestEcology.height_at(shell.stage.bridge.camera_world)
  var native_depth:float=-shell.stage.camera.to_local(actor.global_position).z*20
  var ground_shift:float=(float(reference.relative_ground)-native_ground)*shell.stage.bridge.focal()/native_depth*shell.container.scale.y
  print("INDEPENDENT_GROUND ",actor.model_key," native=",native_ground," formal=",reference.relative_ground," expected pixel shift=",ground_shift," depth=",native_depth,"/",reference.depth)
  if matched_pose:
   actor.rotation.y=reference.body_yaw-shell.stage.bridge.heading
   for saved in reference.bone_pose:
    var index:int=actor.rig.find_bone(saved.name)
    assert(index>=0)
    actor.rig.set_bone_pose_position(index,Vector3(saved.p[0],saved.p[1],saved.p[2]))
    actor.rig.set_bone_pose_rotation(index,Quaternion(saved.q[0],saved.q[1],saved.q[2],saved.q[3]))
    actor.rig.set_bone_pose_scale(index,Vector3(saved.s[0],saved.s[1],saved.s[2]))
  for bone_name in reference.landmarks_pixels:
   var bone:int=actor.rig.find_bone(bone_name)
   if bone<0:continue
   var point:Vector3=actor.rig.global_transform*actor.rig.get_bone_global_pose(bone).origin
   var pixel:Vector2=transform*shell.stage.camera.unproject_position(point)
   var weak:Vector2=transform*shell.stage.camera.unproject_position(preload("res://scripts/world3d/portrait_presenter.gd").projected_attachment(point,actor.global_position,shell.stage.camera))
   var expected:=Vector2(reference.landmarks_pixels[bone_name][0],reference.landmarks_pixels[bone_name][1])
   var anchor_shift:float=(float(reference.ground_anchor[1])-0.884615421295166)*float(reference.height)*shell.stage.bridge.focal()/native_depth*shell.container.scale.y
   var explained:Vector2=weak-Vector2(0,ground_shift+anchor_shift)
   if matched_pose:assert(explained.distance_to(expected)<.02,"Unexplained composition error after independent terrain and portrait-anchor accounting")
   if matched_pose and formal_world:
    var runtime_point:Vector3=actor.portrait_presenter.projected_attachment(point,actor.global_position,shell.stage.camera,actor.portrait_presenter.vertical_offset)
    assert((transform*shell.stage.camera.unproject_position(runtime_point)).distance_to(expected)<.02,"Runtime projection differs at the same formal world location")
   comparisons.append({"model":actor.model_key,"bone":bone_name,"formal":[expected.x,expected.y],"native":[pixel.x,pixel.y],"error_pixels":pixel.distance_to(expected),"weak_error_pixels":weak.distance_to(expected),"ground_shift_pixels":ground_shift,"portrait_anchor_shift_pixels":anchor_shift,"unexplained_error_pixels":explained.distance_to(expected)})
 FileAccess.open("res://../tempassets/work/world3d-independent-landmarks"+("-matched" if matched_pose else "")+".json",FileAccess.WRITE).store_string(JSON.stringify({"matched_pose":matched_pose,"note":"Independent formal formation; matched mode copies only formal pose and yaw. World height and camera remain native. Weak errors are analytical, not GPU masks.","comparisons":comparisons},"  "))
 # This coroutine can resume inside the current frame's setup. Explicitly
 # yield a frame and request the frozen diagnostic render before readback.
 await process_frame
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-formal-content-frame"+("-matched" if matched_pose else "")+("-same-world" if formal_world else "")+".png")
 assert(shell.stage.get_meta("presentation_scene")=="res://scenes/world3d_presentation.tscn")
 shell.stage.set_process(true)
 for dimensions in [Vector2i(1920,1080),Vector2i(1280,960)]:
  root.size=dimensions
  for i in 4:await process_frame
  var factor:float=clampf(minf(float(dimensions.x)/1600,float(dimensions.y)/960),.65,3)
  assert(shell.container.position.distance_to(Vector2(24,88)*factor)<1)
  assert((shell.container.size*factor).distance_to(Vector2(dimensions)-Vector2(48,170)*factor)<2)
  assert(shell.stage.bridge.view_size.distance_to(shell.container.size)<2)
 print("WORLD3D_CONTENT_FRAME_PASS independent formal content rectangle and render dimensions")
 quit()
