extends SceneTree
func _initialize():
 var plan:=RoutePlan.new()
 for data in [[0,100,200],[-1,200,400],[-1,400,600],[1,200,600]]:
  var region:=RouteRegion.new();region.branch=data[0];region.start=data[1];region.end=data[2];plan.regions.append(region)
 assert(plan.environment_at(700,-1)==plan.regions[2])
 assert(plan.environment_at(50,0)==plan.regions[0])
 assert(plan.environment_at(400,-1)==plan.regions[2])
 assert(plan.at(700,-1)==null,"Environment clamping must not extend geometry ownership")
 assert(plan.environment_at(300,2)==null)
 plan.regions[2].start=450
 assert(plan.environment_at(425,-1)==null,"Do not silently conceal interior route gaps")
 print("ROUTE_ENVIRONMENT_BOUNDARY_PASS")
 quit()
