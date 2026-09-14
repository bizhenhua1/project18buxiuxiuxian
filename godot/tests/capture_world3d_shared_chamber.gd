extends SceneTree
const P=preload("res://scripts/world3d/projection.gd")
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
 while not app.stage or not app.stage.ready_stage:await process_frame
 var stage=app.stage;stage.set_process(false)
 var plan:RoutePlan=preload("res://scripts/world3d/themes.gd").plan(stage.theme_key)
 plan.exits=3;plan.layout_seed=9321
 for original in plan.regions.duplicate():
  if original.branch==-1:
   var middle:RouteRegion=original.duplicate();middle.branch=2;middle.key=StringName(str(original.key)+"_middle");plan.regions.append(middle)
 var world:=SegmentWorld.new(ForestArt.new(),plan)
 var route=preload("res://scripts/world3d/route_segment.gd").new(0,Vector2.ZERO,0,700,420,2200,3,9321,stage.theme_key)
 for actor in stage.team:actor.hide()
 for prop in stage.props:prop.node.hide()
 var frame:Dictionary=stage.composition.frames.travel
 var pose:Dictionary=route.pose(900,2)
 stage.bridge.camera_world=P.frame_origin(pose.position,pose.heading,frame)
 stage.bridge.heading=P.frame_heading(pose.heading,frame)
 P.configure(stage.camera,Vector2(1440,900),stage.bridge.camera_world,stage.bridge.heading,frame.height,frame.lens,frame.horizon)
 for merged in [false,true]:
  stage.scenery.free()
  stage.scenery=load("res://scripts/world3d/scenery.gd").new();stage.add_child(stage.scenery)
  stage.scenery.fixed_shells=true;stage.scenery.shared_shell_heading=true;stage.scenery.shared_shell_chambers=merged
  stage.scenery.populate(world,route);stage.scenery.update_view(stage.bridge)
  for i in 3:await process_frame
  RenderingServer.force_draw()
  root.get_texture().get_image().save_png("res://../tempassets/work/shared-chamber-"+stage.theme_key+("-merged" if merged else "-original")+".png")
 print("SHARED_CHAMBER_CAPTURE source seed9321 three-way, same saved camera, scenery only")
 quit()
