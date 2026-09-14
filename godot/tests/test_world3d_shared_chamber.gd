extends SceneTree
func _initialize():call_deferred("run")
func run():
 var route=preload("res://scripts/world3d/route_segment.gd").new(1000,Vector2(230,450),.7,1700,420,3200,3)
 var region:=RouteRegion.new();region.space=preload("res://scripts/spaces/biome_catalog.gd").make_space("whale")
 var source:Array=[]
 for branch in [-1,1,2]:source.append({"id":source.size(),"region":region,"shell":true,"route_branch":branch,"route_s":2080.0,"position":route.point(2080,branch),"w":114.0,"h":250.0})
 var shape=preload("res://scripts/world3d/shared_chamber.gd")
 var snapshot:Array=source.duplicate(true)
 var merged:Array=shape.apply(source,route)
 assert(merged.size()==1 and merged[0].position==route.point(2080,2))
 assert(merged[0].w==760 and merged[0].h==370)
 assert(is_equal_approx(float(merged[0].plane_heading),.7))
 assert(source==snapshot,"Source edits would alter the legacy comparison")
 assert(shape.apply(merged,route)==merged)
 assert(shape.apply(source.slice(0,2),route)==source.slice(0,2),"Incomplete groups must not remove a branch")
 var explicit:Array=source.duplicate(true);explicit[0].plane_heading=.3
 assert(shape.apply(explicit,route)==explicit,"Explicit art orientation must be preserved")
 route.exits=2
 assert(shape.apply(source,route)==source)
 print("WORLD3D_SHARED_CHAMBER_PASS intact portal, transformed route, source isolation, incomplete group and explicit heading preserved")
 quit()
