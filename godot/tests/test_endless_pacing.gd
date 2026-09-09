extends SceneTree
func _initialize():call_deferred("run")
func run():
 for biome in ["forest","crystal"]:
  set_meta("tour_biome",biome);set_meta("tour_event_placement","after")
  var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
  await process_frame;app.set_process(false)
  var time:=0.0
  while app.phase!="choose" and time<6:
   app._process(.05);time+=.05
  assert(app.phase=="choose" and time>=2.8 and time<=5,"Initial leg cadence")
  print(biome," initial seconds=",time)
  app.choose(1);time=0
  while app.phase not in ["sighting","encounter","entering","battle"] and time<6:
   app._process(.05);time+=.05
  assert(time>=2.8 and time<=5,"Post-junction cadence")
  assert(app.distance>=app.route_spec.junction+app.route_spec.fork_clearance,"Event must clear the junction")
  print(biome," post-junction seconds=",time)
  var scaled=[]
  for unit in app.model.player+app.model.enemy:scaled.append(unit.maxHp)
  app.model.health_multiplier=1;app.model.reset()
  var units=app.model.player+app.model.enemy
  for i in range(units.size()):assert(is_equal_approx(float(scaled[i]),float(units[i].maxHp)*5))
  app.model.health_multiplier=5;app.model.start()
  for i in range(units.size()):assert(units[i].maxHp==scaled[i] and units[i].hp==scaled[i])
  app.model.reset()
  for i in range(units.size()):assert(units[i].maxHp==scaled[i],"Health multiplier compounded")
  app.queue_free();await process_frame
 print("ENDLESS_PACING_PASS");quit()

