extends SceneTree
var app
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":
  push_error("Scenery comparison requires an actual GPU renderer");quit(1);return
 root.size=Vector2i(1440,900)
 app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 await create_timer(.3).timeout
 if "--crystal" in OS.get_cmdline_user_args():
  app.distance=3000;app.branch=-1;app.camera_origin=app.route_segment.point(app.distance,-1);app.camera_heading=app.route_segment.pose(app.distance,-1).heading
  app.frame=app.composition.frames.event.duplicate();app._process(0)
  app.environment_3d.background_color=app.world.camera_region.space.top_color
 app.set_process(false)
 var suffix:=""
 if "--ensure-mips" in OS.get_cmdline_user_args():
  var missing:=0
  for texture in app.scenery.by_texture:
   var pixels:Image=texture.get_image()
   if not pixels.has_mipmaps():
    missing+=1;pixels.generate_mipmaps()
    app.scenery.by_texture[texture].set_shader_parameter("art",ImageTexture.create_from_image(pixels))
  print("SCENERY_MISSING_MIPMAPS ",missing," / ",app.scenery.by_texture.size())
  suffix+="-mips"
 if "--hide-ground" in OS.get_cmdline_user_args():
  app.scenery.floor_node.hide();suffix+="-no-ground"
 if "--no-cutout-prepass" in OS.get_cmdline_user_args():
  # Diagnostic only: isolates coplanar depth contention without changing production.
  var diagnostic:=Shader.new()
  diagnostic.code=FileAccess.get_file_as_string("res://scripts/world3d/cutout.gdshader").replace("depth_prepass_alpha","depth_draw_never")
  for material in app.scenery.by_texture.values():material.shader=diagnostic
  suffix+="-no-prepass"
 for actor in app.team:actor.hide()
 for item in app.props:item.node.hide()
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-scenery-native"+suffix+".png")
 var old:=SegmentView.new();old.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(old);old.setup(ForestArt.new(),app.world,1,ThemeDB.fallback_font)
 old.renderer.runtime_camera=app.frame.duplicate();old.renderer.lantern_enabled=true;old.renderer.battle_frame_shift=.19
 old.renderer.show()
 old.sync(app.bridge.camera_world,app.bridge.heading,app.clock,0,app.branch,false,false,app.distance)
 old.renderer.environment=app.world.environment()
 old.renderer.queue_redraw()
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-scenery-reference"+suffix+".png")
 print("WORLD3D_COMPARISON_READY identical world instance, camera parameters, viewport and time")
 quit()
