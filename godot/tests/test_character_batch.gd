extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/character_library.tscn").instantiate();root.add_child(app)
 for index in app.MODELS.size():
  app.select_model(index)
  if app.rig==null:push_error("Missing skeleton");quit(1);return
  for hand in range(2):
   app.weapon_panel.hand=hand;app.weapon_panel.weapon=1;app.weapon_panel.bind_model()
   if not is_instance_valid(app.weapon_panel.attachment):push_error("Missing hand "+str(index));quit(1);return
  var mapped=0
  for bone in app.retarget.mapping:
   if bone>=0:mapped+=1
  if mapped<15:push_error("Insufficient mapping "+str(index));quit(1);return
  for time in [0.0,.3,.8]:app.retarget.apply(time)
  print("CHARACTER_PASS ",index," ",app.MODELS[index].name," mapped=",mapped)
  await process_frame
 print("CHARACTER_BATCH_PASS ",app.MODELS.size());quit()
