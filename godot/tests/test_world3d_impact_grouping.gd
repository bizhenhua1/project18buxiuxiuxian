extends SceneTree
func _initialize():
 var first:Dictionary={"target":2,"position":Vector3.ZERO,"shot":1}
 var same:Dictionary={"target":2,"position":Vector3(.2,0,0),"shot":2}
 var distinct:Dictionary={"target":2,"position":Vector3(.7,0,0),"shot":3}
 var other:Dictionary={"target":4,"position":Vector3.ZERO,"shot":4}
 var airborne:Dictionary={"target":2,"position":Vector3(0,1,0),"shot":5}
 var events:Array=[first,same,distinct,other,airborne]
 var groups:Array=preload("res://scripts/world3d/projectile_view.gd").group_impacts(events)
 assert(groups==[first,distinct,other,airborne])
 assert(events.size()==5 and same.position==Vector3(.2,0,0),"Simulation contacts stay intact")
 assert(preload("res://scripts/world3d/projectile_view.gd").group_impacts([same])==[same],"A new frame gets its own feedback")
 print("WORLD3D_IMPACT_GROUPING_PASS same target/proximity only, exact contact, separate frame")
 quit()
