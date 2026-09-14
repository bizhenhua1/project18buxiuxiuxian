extends SceneTree
const P=preload("res://scripts/world3d/projection.gd")
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
 while not app.stage or not app.stage.ready_stage:await process_frame
 var stage=app.stage;stage.set_process(false)
 # The stage now starts with its own theme; do not mask a loading-color regression.
 assert(stage.environment_3d.background_color.is_equal_approx(stage.world.camera_region.space.top_color))
 var vault:bool="--vault-connector" in OS.get_cmdline_user_args()
 var tag:=""
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--tag="):tag=argument.get_slice("=",1)+"-"
 if vault:stage.add_child(preload("res://tests/world3d_vault_fixture.gd").build(stage.route_segment))
 assert(stage.scenery.fixed_shells)
 var entries:Array=[]
 for chunk in stage.scenery.chunks:
  var mm:MultiMesh=chunk.multimesh
  if not str(mm.mesh.surface_get_material(0).get_meta("source_asset","")).ends_with("/palace/shell.png"):continue
  for i in mm.instance_count:
   var data:Color=mm.get_instance_custom_data(i)
   if int(absf(data.b))>=16:entries.append([mm,i,data])
 assert(entries.size()>10)
 # Scenery-only diagnostic at saved travel framing, not a gameplay traversal.
 for actor in stage.team:actor.hide()
 for item in stage.props:item.node.hide()
 var frame:Dictionary=stage.composition.frames.travel
 for index in 3:
  var s:float=stage.route_segment.junction_s+float(index)*210
  var pose:Dictionary=stage.route_segment.pose(s,1)
  stage.bridge.camera_world=P.frame_origin(pose.position,pose.heading,frame)
  stage.bridge.heading=P.frame_heading(pose.heading,frame)
  P.configure(stage.camera,Vector2(1440,900),stage.bridge.camera_world,stage.bridge.heading,frame.height,frame.lens,frame.horizon)
  stage.scenery.update_view(stage.bridge)
  for fixed in [false,true]:
   for entry in entries:
    var data:Color=entry[2]
    if not fixed:data.b-=signf(data.b)
    entry[0].set_instance_custom_data(entry[1],data)
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../tempassets/work/"+tag+("vault-" if vault else "")+"shell-compare-%d-%s.png"%[index,"fixed" if fixed else "billboard"])
 print("SHELL_COMPARISON snapshots=6 shells=",entries.size())
 quit()
