extends SceneTree
func _initialize():call_deferred("run")
func run():
 var scenery=preload("res://scripts/world3d/scenery.gd").new()
 scenery.shared_shell_heading=false
 var route=preload("res://scripts/world3d/route_segment.gd").new(1000,Vector2(230,450),.7,1700,420,3200)
 var shell={"shell":true,"route_s":2400.0,"route_branch":-1,"position":Vector2(3,4),"w":1250.0,"h":355.0}
 var explicit=shell.duplicate();explicit.plane_heading=-.2
 var grass={"shell":false,"route_s":2400.0,"route_branch":1}
 var source:Array=[shell,explicit,grass]
 scenery.fixed_shells=false
 assert(scenery.route_shells(source,route)==source)
 scenery.fixed_shells=true
 var result:Array=scenery.route_shells(source,route)
 assert(is_equal_approx(float(result[0].plane_heading),.2))
 assert(result[0].position==shell.position and result[0].w==shell.w and result[0].h==shell.h)
 assert(not shell.has("plane_heading"))
 assert(result[1].plane_heading==-.2 and not result[2].has("plane_heading"))
 ForestRoute.origin_heading=-2.0
 assert(scenery.route_shells(source,route)[0].plane_heading==result[0].plane_heading)
 assert(scenery.route_shells(result,route)==result)
 scenery.shared_shell_heading=true
 var chamber:=shell.duplicate();chamber.position=route.point(1800,-1);chamber.route_s=1800;chamber.w=720
 var distant:=chamber.duplicate();distant.route_s=5000;distant.position=route.point(5000,-1)
 var shared:Array=scenery.route_shells([chamber,distant,explicit],route)
 assert(is_equal_approx(float(shared[0].plane_heading),route.heading),"Shared chamber must keep the owning route cross-section")
 assert(is_equal_approx(float(shared[1].plane_heading),float(route.pose(5000,-1).heading)),"Separated exit must recover its own heading")
 assert(shared[2].plane_heading==explicit.plane_heading)
 assert(not chamber.has("plane_heading") and shared[0].position==chamber.position and shared[0].w==chamber.w)
 assert(scenery.route_shells(shared,route)==shared)
 var intermediate:=chamber.duplicate();intermediate.route_s=3000;intermediate.position=route.point(3000,-1)
 var two_heading:float=scenery.route_shells([intermediate],route)[0].plane_heading
 route.exits=3
 var three_heading:float=scenery.route_shells([intermediate],route)[0].plane_heading
 assert(absf(angle_difference(route.heading,three_heading))<absf(angle_difference(route.heading,two_heading)),"Middle exit requires more space before turning arches")
 scenery.free()
 if "--runtime" in OS.get_cmdline_user_args():
  assert(DisplayServer.get_name()!="headless")
  var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
  while not app.stage or not app.stage.ready_stage:await process_frame
  var stage=app.stage;stage.set_process(false)
  var checked:=0
  for chunk in stage.scenery.chunks:
   var mm:MultiMesh=chunk.multimesh
   var material:ShaderMaterial=mm.mesh.surface_get_material(0)
   if not str(material.get_meta("source_asset","")).ends_with("/palace/shell.png"):continue
   for i in mm.instance_count:
    var data:Color=mm.get_instance_custom_data(i)
    if int(absf(data.b))<16:continue
    assert(int(absf(data.b))%8==7,"Shell must use fixed adaptive-contact mode")
    checked+=1
  assert(checked>10)
  print("WORLD3D_SHELL_RUNTIME fixed shells=",checked)
 print("WORLD3D_SHELL_ORIENTATION PASS immutable owning route, source isolation, explicit art orientation preserved")
 quit()
