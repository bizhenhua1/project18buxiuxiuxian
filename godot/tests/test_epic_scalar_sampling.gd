extends SceneTree
func _initialize():
 var old=preload("res://tests/fixtures/epic181_effect_reference.gd").new()
 var current=preload("res://scripts/spaces/epic181_effect.gd").new()
 var random:=RandomNumberGenerator.new();random.seed=88372
 var samples:=0
 for sizes in [[1,1],[2,2],[16,16],[33,33],[2,16],[16,1]]:
  var values:Array=[[],[]]
  for side in 2:
   for i in sizes[side]:values[side].append(random.randf_range(-20,20))
  for frame in range(-20,221):
   for factor in [0.0,.123456789,.5,1.0]:
    var t:=frame/200.0
    assert(current.sample(values,t,factor)==old.sample(values,t,factor),"Curve interpolation changed numerical results")
    samples+=1
 if "--timing" in OS.get_cmdline_user_args():
  var values:Array=[[],[]]
  for i in 33:values[0].append(sin(i));values[1].append(cos(i))
  var elapsed:=[0,0];var sums:=[0.0,0.0];var actors:=[old,current]
  for round in 4:
   for side in [round%2,1-round%2]:
    var began:=Time.get_ticks_usec()
    for i in 30000:sums[side]+=actors[side].sample(values,(i%999)/999.0,.37)
    elapsed[side]+=Time.get_ticks_usec()-began
  assert(sums[0]==sums[1])
  print("SCALAR_SAMPLING_TIMING 120000 calls each reference_ms=",elapsed[0]/1000.0," shared_ms=",elapsed[1]/1000.0)
 old.free();current.free()
 print("EPIC_SCALAR_SAMPLING_PASS exact samples=",samples," equal/unequal grids, endpoints, out-of-range times")
 quit()
