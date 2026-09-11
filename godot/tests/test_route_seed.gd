extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/endless_forest.tscn").instantiate();app.set_process(false);root.add_child(app)
 var sequences:Array=[]
 for seed_value in [1842,9317,1842]:
  app.run_seed=seed_value
  var sequence:Array=[]
  for i in range(1,12):
   var zone={"route_kind":"fork","combat_only":true,"theme":"forest","endless_leg":i}
   app.configure_leg(zone,i)
   var plan=LocalRouteSpec.plan(zone)
   assert(plan.layout_seed==zone.layout_seed)
   sequence.append([zone.exits,zone.event_placement,plan.layout_seed])
  sequences.append(sequence)
 assert(sequences[0]==sequences[2]);assert(sequences[0]!=sequences[1])
 set_meta("tour_exits",3);set_meta("tour_event_placement","after")
 var fixed={};app.configure_leg(fixed,4);assert(fixed.exits==3 and fixed.event_placement=="after")
 var signatures:Array=[]
 for seed_value in [1842,9317,1842]:
  var zone=app.route_zone.duplicate(true);zone.layout_seed=seed_value
  ForestRoute.reset_frame()
  var world=SegmentWorld.new(app.art,LocalRouteSpec.plan(zone))
  assert(world.seed_value==seed_value)
  var signature:Array=[]
  for i in range(mini(80,world.sprites.size())):signature.append([world.sprites[i].position,world.sprites[i].w])
  signatures.append(signature)
 assert(signatures[0]==signatures[2]);assert(signatures[0]!=signatures[1])
 app.free()
 print("SEED_PASS reproducible topology, event placement, layout seeds and fixed overrides")
 quit()
