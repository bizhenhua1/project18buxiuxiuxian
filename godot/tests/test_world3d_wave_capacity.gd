extends SceneTree
const CHECK=preload("res://scripts/world3d/wave_capacity.gd")
func _initialize():
 var base:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json"))
 var pool:Array=[]
 for kind in 5:
  for index in [13,12,10,3,12][kind]:pool.append({"kind":kind})
 assert(CHECK.validate(base,pool,true).is_empty())
 var normal:Dictionary=base.duplicate(true);normal.total=24;normal.cap=14
 assert(CHECK.validate(normal,pool,false).is_empty())
 for change in [{"total":51},{"total":0},{"total":1.5},{"cap":0},{"interval":0},{"interval":{}},{"spawn_cycle":[]},{"spawn_cycle":[8]},{"spawn_cycle":[1.5]},{"spawn_cycle":[0],"cap":1}]:
  var candidate:Dictionary=normal.duplicate(true);candidate.merge(change,true)
  var before:=JSON.stringify(candidate)
  assert(not CHECK.validate(candidate,pool,false).is_empty(),"Invalid wave must be rejected: "+str(change))
  assert(JSON.stringify(candidate)==before,"Validation must not rewrite the user's wave")
 print("WORLD3D_WAVE_CAPACITY_PASS normal/stress, per-kind corpse capacity, invalid input, nonmutating validation")
 quit()
