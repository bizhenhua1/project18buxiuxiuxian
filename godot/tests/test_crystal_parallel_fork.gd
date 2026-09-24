extends SceneTree

const Route=preload("res://scripts/world3d/route_segment.gd")
const Cave=preload("res://scripts/world3d/cave_fork.gd")
const Themes=preload("res://scripts/world3d/themes.gd")

func _initialize()->void:call_deferred("run")

func run()->void:
 ForestRoute.reset_frame()
 var plan:RoutePlan=Themes.plan("crystal",3,1842)
 assert(plan.exits==2,"An open mine cannot expose a third exit")
 assert(ForestRoute.cave_fork)
 var segment=Route.new(0.0,Vector2.ZERO,0.0,700.0,420.0,2200.0,2,1842,"crystal")
 for branch in [-1,1]:
  var start:Dictionary=segment.pose(700.0,branch)
  var finish:Dictionary=segment.pose(1120.0,branch)
  var later:Dictionary=segment.pose(1420.0,branch)
  assert(start.position.is_equal_approx(Vector2(0,700)))
  assert(is_zero_approx(float(start.heading)))
  assert(is_equal_approx(finish.position.x,branch*Cave.HALF_SEPARATION))
  assert(is_equal_approx(finish.position.y,1120.0))
  assert(is_zero_approx(float(finish.heading)))
  assert(is_equal_approx(later.position.x,finish.position.x),"Branch must recover the original forward axis")
  assert(is_equal_approx(later.position.y,1420.0))
 var world:=SegmentWorld.new(ForestArt.new(),plan)
 var mouths:Array=world.sprites.filter(func(sprite):return sprite.get("cave_mouth",false))
 assert(mouths.size()==2,"The two visible entrances need independent assets")
 assert(mouths[0].texture!=mouths[1].texture)
 for mouth in mouths:
  assert(mouth.get("shell",false) and mouth.get("cross_section",false))
  assert(mouth.position.distance_to(ForestRoute.point_at(float(mouth.route_s),int(mouth.route_branch)))<.001)
 var tail:Dictionary=segment.pose(1800.0,1)
 var successor=segment.successor(1,1842,1)
 assert(successor.origin.is_equal_approx(segment.pose(segment.end_s,1).position))
 assert(is_zero_approx(float(tail.heading)) and is_zero_approx(float(successor.heading)))
 print("CRYSTAL_PARALLEL_FORK_PASS mouths=",mouths.size()," sprites=",world.sprites.size())
 quit()
