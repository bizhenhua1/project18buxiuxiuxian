extends SceneTree
func _initialize():call_deferred("run")
func snapshot()->Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 root.size=Vector2i(1440,900)
 var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../tempassets/work/formal-battle-baseline.json"))
 set_meta("world3d_route_fixture",baseline.route_zone);ForestSettings.values=baseline.forest_settings.duplicate(true)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 stage.distance=baseline.distance;stage.camera_origin=stage.route_segment.point(stage.distance,0);stage.encounter_anchor=stage.camera_origin
 stage._process(0)
 for child in stage.get_children():
  if child is CanvasLayer:child.hide()
 for actor in stage.team:actor.hide()
 for item in stage.props:item.node.hide()
 for chunk in stage.scenery.chunks:chunk.hide()
 # Hide the fog MultiMesh instance, retaining only the real ground mesh.
 for child in stage.scenery.get_children():
  if child is GeometryInstance3D and child!=stage.scenery.floor_node:child.hide()
 var native:Image=await snapshot()
 native.save_png("res://../tempassets/work/forest-ground-native.png")
 var old:=SegmentView.new();root.add_child(old)
 old.position=shell.container.position;old.scale=shell.container.scale;old.size=shell.container.size
 old.setup(ForestArt.new(),stage.world,1,ThemeDB.fallback_font)
 old.renderer.runtime_camera=stage.frame.duplicate();old.renderer.battle_frame_shift=.19
 old.sync(stage.bridge.camera_world,stage.bridge.heading,stage.clock,0,0,false,false,stage.distance)
 old.renderer.hide()
 var formal:Image=await snapshot()
 formal.save_png("res://../tempassets/work/forest-ground-reference.png")
 var error:=Vector3.ZERO;var count:=0;var peak:=0.0
 # Lower content region excludes sky and UI. Units are 8-bit RGB differences.
 for y in range(500,800,4):
  for x in range(40,1400,4):
   var a:Color=native.get_pixel(x,y);var b:Color=formal.get_pixel(x,y)
   var delta:=Vector3(absf(a.r-b.r),absf(a.g-b.g),absf(a.b-b.b))*255
   error+=delta;peak=maxf(peak,maxf(delta.x,maxf(delta.y,delta.z)));count+=1
 print("GROUND_RENDER_PARITY samples=",count," mean_rgb_error=",error/count," peak=",peak," same world/camera/time, actual 2D and 3D ground shaders")
 var sky_peak:=0.0
 for y in range(90,230,4):
  for x in range(40,1400,16):
   var a:Color=native.get_pixel(x,y);var b:Color=formal.get_pixel(x,y)
   sky_peak=maxf(sky_peak,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))*255)
 print("SKY_DIAGNOSTIC peak=",sky_peak," visible=",stage.forest_background.visible," values=",stage.forest_background.cached)
 assert(native.get_pixel(700,100).b<native.get_pixel(700,220).b,"Background must show the vertical gradient")
 assert(error.x/count<6 and error.y/count<6 and error.z/count<6,"Background must not cover ground")
 print("FOREST_BACKGROUND_RENDER_PASS gradient present and ground retained; measured sky peak error=",sky_peak," /255, pixel parity not asserted")
 quit()
