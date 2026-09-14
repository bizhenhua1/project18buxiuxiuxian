extends SceneTree
func _initialize():
 var route=preload("res://scripts/world3d/route_segment.gd").new(1000,Vector2(400,1500),.8,1700,420,3000,3)
 var a:Dictionary={"position":route.point(1100,-1,200),"route_s":1100.0,"route_branch":-1,"trunk_radius":8.0}
 var b:=a.duplicate();b.route_branch=1;b.position+=Vector2(1,1)
 var first=preload("res://scripts/world3d/trunk_placement.gd").new()
 var second=preload("res://scripts/world3d/trunk_placement.gd").new()
 var x:Array=first.prepare([a,b],route);var y:Array=second.prepare([a,b],route)
 var expected:Array=[]
 for sprite in x:expected.append(first.place(sprite).position)
 ForestRoute.origin=Vector2(-9000,8000);ForestRoute.origin_heading=-2.0;ForestRoute.origin_s=90000;ForestRoute.JUNCTION=90100
 for i in y.size():
  var result:Dictionary=second.place(y[i])
  assert(result.position==expected[i],"Pending segment placement reads another route's global state")
  if result.position!=y[i].position:assert(route.lane_distance(result.position)>=maxf(26,ForestEcology.half_width(result.route_s-route.start_s))+result.trunk_radius+8)
 assert(first.moved>0)
 var future:=a.duplicate();future.route_s=2200;future.position=route.point(2200,1,200)
 first.reserve(future,route);first.trim_after(2000)
 assert(first.entries.size()==2)
 for cell in first.buckets:
  for entry in first.buckets[cell]:assert(entry.route_s<2000,"Cancelled future keeps ghost occupancy")
 # Equal branch numbers in distinct segment descriptions are not one habitat.
 var seam=preload("res://scripts/world3d/trunk_placement.gd").new()
 var next_route=preload("res://scripts/world3d/route_segment.gd").new(1000,Vector2(400,1500),.8,1700,420,3000,3)
 var same_branch:=a.duplicate();same_branch.position+=Vector2(1,1)
 var old:Array=seam.prepare([a],route);seam.place(old[0])
 var new_batch:Array=seam.prepare([same_branch],next_route);seam.place(new_batch[0])
 assert(seam.moved==1,"Same branch id across segment boundaries bypassed conflict detection")
 print("WORLD3D_TRUNK_ROUTE_CONTEXT_PASS rotated successor independent of current globals, cancellation clears future occupancy")
 quit()
