extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app);current_scene=app
 while not app.ready_stage:await process_frame
 assert(app.theme_key=="swamp")
 var previous:WeakRef=weakref(app)
 app.theme_picker.item_selected.emit(app.THEMES.KEYS.find("sewer"))
 app=null
 await scene_changed
 while not current_scene.ready_stage:await process_frame
 assert(previous.get_ref()==null,"Theme reload must release old scene")
 assert(current_scene.theme_key=="sewer","Picker choice must override launch argument")
 assert(current_scene.world.plan.regions.all(func(r):return r.space.key==&"sewer"))
 print("WORLD3D_THEME_SWITCH_PASS swamp to sewer, launch override, old scene released")
 quit()
