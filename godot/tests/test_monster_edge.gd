extends SceneTree
func _initialize():call_deferred("run")
func run():
 var state:=JourneyState.new()
 for zone in state.zones:
  var position:=Vector2i(zone.cell[0],zone.cell[1])
  assert(state.world.blocked[position].battle,"Every monster marker must use edge ambush, including short_social routes")
 var model:=IslandModel.new()
 var start:=model.player
 var target:=start
 for offset in IslandModel.NBS:
  if model.lookup.has(start+offset):target=start+offset;break
 model.blocked[target]={"battle":true}
 model.explored.erase(target)
 var requests:Array=[];model.event_requested.connect(func(p):requests.append(p))
 assert(model.go_to(target))
 assert(model.explored.has(target) and model.probing_monster)
 assert(model.ambush_elapsed==0 and model.player==start)
 model.advance(IslandModel.AMBUSH_WINDUP)
 var pose:=model.avatar()
 assert(model.rebounding and is_equal_approx(Vector2(pose.x,pose.z).distance_to(Vector2(start)),IslandModel.AMBUSH_EDGE))
 for i in range(65):
  model.advance(.01);pose=model.avatar()
  assert(model.player==start and Vector2(pose.x,pose.z).distance_to(Vector2(start))<=IslandModel.AMBUSH_EDGE+.001)
 assert(not model.walking and requests.is_empty())
 assert(model.go_to(target) and requests==[target] and not model.walking)
 print("MONSTER_EDGE_PASS immediate reveal, edge-only contact, stays on original tile, second click opens event")
 quit()
