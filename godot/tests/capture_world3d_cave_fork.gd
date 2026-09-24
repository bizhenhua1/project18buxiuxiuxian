extends SceneTree
## Real native-stage frames around a cave choice, with stable seed and direction.
var app
var output := ""
var theme := "crystal"
var direction := 1

func _initialize() -> void:call_deferred("run")

func capture(label:String) -> void:
 for frame in 4:await process_frame
 var path:=output+"/"+label+".png"
 assert(root.get_texture().get_image().save_png(path)==OK)
 print("CAVE_FORK_FRAME ",label," distance=",app.distance," branch=",app.branch," hidden=",app.scenery.hidden_branch_fraction," heading=",rad_to_deg(app.camera_heading))

func run() -> void:
 var seed_value:=1842
 var exits:=2
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
  if arg.begins_with("--theme="):theme=arg.trim_prefix("--theme=")
  if arg.begins_with("--layout-seed="):seed_value=int(arg.trim_prefix("--layout-seed="))
  if arg.begins_with("--exits="):exits=int(arg.trim_prefix("--exits="))
  if arg=="--left":direction=-1
  if arg=="--center":direction=2
 assert(not output.is_empty())
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1280,800)
 set_meta("world3d_theme",theme)
 assert(exits in [2,3])
 set_meta("world3d_fork_test",exits)
 app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 app.set_inspection_expanded(false)
 var ticks:=0
 while app.phase!="fork" and ticks<140:
  app._process(.05);ticks+=1
  if ticks%12==0:await process_frame
 assert(app.phase=="fork")
 await capture("00-choice")
 app.choose_branch(direction)
 assert(app.phase=="travel")
 for tick in 96:
  app._process(.05)
  if tick in [0,4,8,12,18,25,34,46,62,80,95]:await capture("%02d-after"%tick)
  if app.phase!="travel":break
 if theme=="crystal":
  for target in [app.route_segment.junction_s+app.route_segment.turn_length+120.0,app.route_segment.junction_s+app.route_segment.turn_length+400.0]:
   app.distance=target
   app.camera_origin=app.route_segment.point(target,direction)
   app.camera_heading=app.route_segment.pose(target,direction).heading
   app.phase="travel"
   app._process(0.0)
   await capture("parallel-%d"%int(target))
 print("CAVE_FORK_CAPTURE_DONE seed=",seed_value," theme=",theme," direction=",direction)
 quit()
