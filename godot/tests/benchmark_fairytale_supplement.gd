extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1440,900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var report:Array=[]
	for key in ["alice_tea","snow_mirror"]:
		set_meta("tour_biome",key);set_meta("tour_event_placement","after");set_meta("tour_exits",3)
		var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
		app.set_process(false);app.arena.set_process(false)
		for i in 90:app._process(1.0/60);await process_frame
		var samples:Array=[];var draws:Array=[];var last:=Time.get_ticks_usec()
		for i in 180:
			app._process(1.0/60);await process_frame
			var now:=Time.get_ticks_usec();samples.append((now-last)/1000.0);last=now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.sort();draws.sort()
		report.append({"scene":key,"frames":samples.size(),"p50_ms":samples[90],"p95_ms":samples[171],"draws_p50":draws[90],"sprites":app.world.sprites.size(),"scope":"traditional travel, 1440x900, frame wall time, not skill stress"})
		root.remove_child(app);app.queue_free();await process_frame
	var file:=FileAccess.open("res://../art/fairytales/corridor/review-20260916/runtime-budget.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("SUPPLEMENT_BUDGET ",JSON.stringify(report));quit()
