extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage._process(0)
 assert(not stage.props.is_empty())
 var initial:Array=stage.props.map(func(item):return item.node.position)
 var moved:=false
 for tick in 20:
  stage._process(.05)
  for i in stage.props.size():
   var item:Dictionary=stage.props[i]
   var delta:Vector3=item.node.position-initial[i]
   assert(absf(delta.x)<.00001 and absf(delta.z)<.00001,"Floating props must retain their ground anchor")
   assert(absf(delta.y)<=2*item.bob/20+.00001,"Reuse formal amplitude, never scale bob with camera")
   if item.bob==0:assert(delta.length()<.00001,"Grounded lantern must not float")
   moved=moved or absf(delta.y)>.0001
 assert(moved,"Floating prop fixture should visibly animate")
 var positions:Array=stage.props.map(func(item):return item.node.position)
 for item in stage.props:item.node.modulate.a=1
 stage.start_travel()
 # Accelerated transition fixture: a changed route and encounter anchor must
 # not influence the outgoing props, even when the fade has not finished yet.
 stage.encounter_anchor+=Vector2(80,120)
 stage.distance=ForestRoute.JUNCTION+20;stage.branch=-1
 stage.next_event=stage.distance+200
 for tick in 8:
  var opacity:float=stage.props[0].node.modulate.a
  stage._process(.05)
  for i in stage.props.size():
   assert(stage.props[i].node.position==positions[i],"Outgoing card was moved by route/encounter coordinates")
   assert(stage.props[i].node.modulate.a<=opacity)
 assert(stage.props[0].node.modulate.a==0)
 stage.phase="prepare";stage._process(.05)
 assert(stage.props[0].node.position!=positions[0],"Next formation must still receive its new position")
 assert(stage.props[0].node.modulate.a>0)
 print("WORLD3D_PROP_DEPARTURE_PASS fixed world position through fade, next formation placed")
 quit()
