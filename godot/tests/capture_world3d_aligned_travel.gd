extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../tempassets/work/formal-travel-baseline.json"))
 set_meta("world3d_route_fixture",reference.route_zone)
 ForestSettings.values=reference.forest_settings.duplicate(true)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage.set_inspection_expanded(false)
 stage.start_travel()
 for i in 140:stage._process(.01)
 # Compare the same route station, using the native travel destination and
 # saved native composition. Never copy the formal actor or camera transforms.
 stage.distance=float(reference.distance)
 stage.camera_origin=stage.route_segment.point(stage.distance,stage.branch)
 stage.team[0].position=stage.travel_destination(stage.distance)
 stage._process(0)
 var actor=stage.team[0]
 var animation:Dictionary=reference.animation
 assert(float(animation.blend_time)>.12,"Reference must be outside its animation blend")
 actor.play(animation.state)
 assert(actor.library.clips[actor.clip].id==animation.clip_id,"Both renders must sample the same source animation")
 var duration:float=float(actor.library.clips[actor.clip].frames-1)/actor.library.clips[actor.clip].fps
 actor.retarget.apply(fmod(float(animation.elapsed),duration))
 var actual_position:=Vector2(actor.position.x,-actor.position.z)*20
 var actual_camera:Vector2=stage.bridge.camera_world
 var expected_position:=Vector2(reference.actor_position[0],reference.actor_position[1])
 var expected_camera:=Vector2(reference.camera[0],reference.camera[1])
 var report:Dictionary={"model":actor.model_key,"camera_error_units":actual_camera.distance_to(expected_camera),"actor_anchor_error_units":actual_position.distance_to(expected_position),"native_frame":stage.frame.duplicate(true),"formal_frame":reference.frame,"animation":animation,"scope":"Same station, saved frame, source clip and animation time; independent rigs. Landmark residuals are measured, not asserted as exact silhouette or full image parity."}
 assert(actor.model_key==reference.model)
 report.landmark_errors_uv={}
 report.facing={"formal":animation.get("body_yaw",0),"native_relative_camera":actor.rotation.y+actor.body.rotation.y+stage.camera_heading}
 for name in reference.landmarks_uv:
  var bone:int=actor.rig.find_bone(name)
  var world:Vector3=(actor.rig.global_transform*actor.rig.get_bone_global_pose(bone)).origin
  var point:Vector2=stage.camera.unproject_position(actor.portrait_presenter.presented_attachment(world,stage.camera))/stage.bridge.view_size
  var expected:=Vector2(reference.landmarks_uv[name][0],reference.landmarks_uv[name][1])
  report.landmark_errors_uv[name]=point.distance_to(expected)
  assert(report.landmark_errors_uv[name]<.0001,"Matched travel pose must retain the formal body-facing offset: "+name)
 assert(report.camera_error_units<.001)
 assert(report.actor_anchor_error_units<.001)
 for key in ["height","lens","horizon","forward","lateral","yaw"]:assert(is_equal_approx(float(stage.frame[key]),float(reference.frame[key])))
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-aligned-travel.png")
 var frozen_clock:float=stage.clock
 var frozen_camera:Transform3D=stage.camera.transform
 var frozen_actor:Vector3=actor.position
 stage.playback_button.button_pressed=true
 stage._process(.05)
 assert(stage.clock==frozen_clock and stage.camera.transform==frozen_camera and actor.position==frozen_actor)
 stage.playback_button.button_pressed=false
 if "--isolate" in OS.get_cmdline_user_args():
  stage.preview.hide();RenderingServer.force_draw()
  root.get_texture().get_image().save_png("res://../tempassets/work/travel-without-preview.png")
  stage.preview.show();stage.scenery.hide();RenderingServer.force_draw()
  root.get_texture().get_image().save_png("res://../tempassets/work/travel-without-scenery.png")
  stage.scenery.show();stage.scenery.mist_batch.visible_instance_count=0;RenderingServer.force_draw()
  root.get_texture().get_image().save_png("res://../tempassets/work/travel-without-mist.png")
  var no_depth:=Shader.new()
  no_depth.code=load("res://scripts/world3d/cutout.gdshader").code.replace(", depth_prepass_alpha",", depth_draw_never")
  for material in stage.scenery.by_texture.values():material.shader=no_depth
  RenderingServer.force_draw()
  root.get_texture().get_image().save_png("res://../tempassets/work/travel-without-cutout-depth.png")
 FileAccess.open("res://../tempassets/work/world3d-aligned-travel.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("WORLD3D_ALIGNED_TRAVEL ",JSON.stringify(report));quit()
