extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 for exits in [2,3,2,3]:
  app.route_segment.exits=exits
  for phase in ["prepare","travel","stopping","fork","event","battle"]:
   app.phase=phase;app.sync_fork_buttons()
   assert(app.fork_controls.visible==(phase=="fork"))
   for direction in [-1,2,1]:
    var available:bool=direction!=2 or exits==3
    assert(app.fork_buttons[direction].visible==available)
    assert(app.fork_buttons[direction].disabled==(phase!="fork" or not available))
   var before:int=app.branch
   app.choose_branch(0);assert(app.branch==before,"Reject invalid direction")
   if phase!="fork":app.choose_branch(-1);assert(app.branch==before,"Reject premature branch input")
 print("WORLD3D_FORK_CONTROLS_PASS two/three-way transitions, phase gating, invalid directions")
 quit()
