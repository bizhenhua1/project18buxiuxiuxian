extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session = root.get_node("Journey")
	session.SAVE = "user://entry-benchmark.json"
	var samples := []
	for i in range(6):
		session.state = JourneyState.new()
		session.state.pending = session.state.zones[0 if i < 3 else 2].id
		var start := Time.get_ticks_usec()
		var scene = load("res://scenes/expedition_route.tscn").instantiate()
		var loaded := Time.get_ticks_usec()
		root.add_child(scene)
		var ready_at := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		var sample := {"run":i,"route":"short" if i < 3 else "fork","scene_load_ms":(loaded-start)/1000.0,"ready_ms":(ready_at-loaded)/1000.0,"first_frame_ms":(Time.get_ticks_usec()-start)/1000.0}
		samples.append(sample)
		print(JSON.stringify(sample))
		scene.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://captures/entry-benchmark")
	var file := FileAccess.open("res://captures/entry-benchmark/latest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t"))
	DirAccess.remove_absolute(session.SAVE)
	print("ENTRY_BENCHMARK_PASS")
	quit()
