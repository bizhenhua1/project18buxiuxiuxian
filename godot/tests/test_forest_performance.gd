extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	StyleLibrary.active=true
	root.size=Vector2i(2545,1301)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var session=root.get_node("Journey")
	session.SAVE="user://performance-test.json";session.state=JourneyState.new()
	session.expedition_active=true;session.state.pending=session.state.zones[0].id
	var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app)
	app.set_process(false)
	var samples:Array[float]=[];var phases:Dictionary={}
	var last:=Time.get_ticks_usec()
	for i in range(600):
		app._process(1.0/60.0)
		if app.phase=="encounter":app.start_battle()
		if "--turn" in OS.get_cmdline_user_args():
			app.heading=sin(i*.01)*.5
			for view in app.views:view.sync(app.camera,app.heading,app.elapsed,1,app.branch,false,false,app.distance)
		await process_frame
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		if i>60:
			var ms:=(now-last)/1000.0;samples.append(ms)
			if not phases.has(app.phase):phases[app.phase]=[]
			phases[app.phase].append(ms)
		last=now
	samples.sort()
	for phase in phases:
		var v:Array=phases[phase];v.sort()
		print("PERF ",phase," count=",v.size()," p50=",v[int(v.size()*.5)]," p95=",v[int(v.size()*.95)]," max=",v.back())
	print("PERF_TOTAL 2545x1301 p50=",samples[int(samples.size()*.5)]," p95=",samples[int(samples.size()*.95)]," max=",samples.back())
	quit()
