extends SceneTree
## Real travel to a fork and along its left exit, with normal camera updates.
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../tempassets/work/fairytale-forks"))
	for key in ["alice_tea","snow_mirror","piper_bridge"]:
		set_meta("tour_biome",key);set_meta("tour_event_placement","after");set_meta("tour_exits",3)
		var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
		app.set_process(false);app.arena.set_process(false)
		var reached:=false
		for i in 1800:
			app._process(1.0/60)
			if app.phase=="choose":reached=true;break
		assert(reached,"Fork not reached: "+key)
		await capture(key+"-junction")
		app.choose(-1)
		for i in 120:app._process(1.0/60)
		await capture(key+"-left-two-seconds")
		print("FORK_CAPTURE ",key," phase=",app.phase)
		root.remove_child(app);app.queue_free();await process_frame
	quit()
func capture(label:String)->void:
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tempassets/work/fairytale-forks/"+label+".png")
