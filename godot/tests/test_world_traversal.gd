extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1400,950)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../tempassets/work/world-traversal"))
	var app=load("res://scenes/island_traversal_demo.tscn").instantiate();root.add_child(app);app.set_process(false)
	var m:IslandModel=app.state
	assert(not m.lookup.has(Vector2i(0,1)))
	var banks:=0
	var waterfalls:=0
	for cell in m.cells:
		if cell.layer=="water":
			for bank in cell.water_banks:banks+=int(bank)
			waterfalls+=cell.waterfall_edges.size()
	assert(banks>0,"Shoreline missing")
	assert(waterfalls>0,"Waterfall exits missing")
	var a:=m.wave_height(-2,-2);m.elapsed+=1;assert(absf(a-m.wave_height(-2,-2))>.02)
	for i in 4:await process_frame
	assert(not app.view.tiles[Vector2i(2,-2)].top.visible)
	await capture("overview")
	var screen:=MeshInstance3D.new();screen.mesh=BoxMesh.new();screen.mesh.size=Vector3(1,1,.08)
	app.view.world.add_child(screen)
	screen.global_transform=Transform3D(app.view.camera.global_basis,app.view.hero.body.global_position+Vector3.UP*.34+app.view.camera.global_basis.z*.9)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("302821");screen.material_override=mat
	app.view.tiles[Vector2i(99,99)]={"body":screen,"cell":{"layer":"land"}}
	for frame in 15:app.view.hero.update_occlusion(app.view,1.0/60)
	app.view.set_process(false)
	await capture("occlusion-outline")
	screen.global_position+=app.view.camera.global_basis.x*.5
	await capture("occlusion-partial")
	app.view.set_process(true)
	app.view.tiles.erase(Vector2i(99,99));screen.queue_free()
	for frame in 15:app.view.hero.update_occlusion(app.view,1.0/60)
	for i in 8:
		m.rotate_view(1)
		for step in 20:app._process(1.0/60)
		assert(m.heading==(i+1)%8)
		await capture("rotation-"+str(i))
	for route in [["up",1],["hole",0],["hole",2],["up",0]]:
		var old_map:int=app.map_id
		var marker=app.view.passage_markers.filter(func(item):return item.link.id==route[0])[0]
		var expected:Vector2i=marker.link.arrival_pose.to
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=app.view.camera.unproject_position(marker.node.position)
		app.view._gui_input(click)
		assert(not m.traversal.pending.is_empty(),"Click did not request passage")
		var saw_transition:=false
		var saw_arrival:=false
		var saw_step:=false
		var retained_hero=app.view.hero
		var previous_world:Vector3=app.view.world.position
		var previous_pose:=m.avatar()
		var previous_map:int=app.map_id
		var arrival_before:=false
		var settling_before:=false
		var previous_rotations:Array[Quaternion]=[]
		for i in 1000:
			app._process(1.0/60);app.view._process(1.0/60)
			assert(app.view.hero==retained_hero,"Map rebuild replaced the actor")
			if app.veil.color.a<.999:
				assert(app.view.world.position.distance_to(previous_world)<.001,"Visible camera offset jump")
			if arrival_before and previous_map==app.map_id:
				var delta:=m.avatar()-previous_pose
				var step:=Vector3((delta.x-delta.z)*.5,delta.y*IslandView3D.HEIGHT,(delta.x+delta.z)*.5).length()
				assert(step<=1.7/60+.0001,"Arrival position jumped")
			if settling_before:
				for bone in previous_rotations.size():
					assert(previous_rotations[bone].angle_to(retained_hero.rig.get_bone_pose_rotation(bone))<.35,"Idle pose snapped")
			previous_rotations.clear()
			for bone in retained_hero.rig.get_bone_count():previous_rotations.append(retained_hero.rig.get_bone_pose_rotation(bone))
			previous_world=app.view.world.position;previous_pose=m.avatar();previous_map=app.map_id
			arrival_before=m.traversal.active.get("arrival",false)
			if arrival_before and m.traversal.motion().name=="walk":saw_step=true
			settling_before=arrival_before and m.traversal.clock>=m.traversal.action_duration
			if not app.transition.is_empty():
				assert(m.input_locked)
				if not saw_transition:
					assert(app.map_id==old_map)
					if route[0]=="up":
						assert(m.traversal.clock>.75)
						assert(absf(m.traversal.pose(m).y-float(marker.link.transition_height))<.15,"Climb transition must track height")
					await capture("depart-"+str(old_map)+"-"+route[0]);saw_transition=true
			if not saw_arrival and m.traversal.active.get("arrival",false) and app.transition.is_empty():
				assert(m.input_locked)
				assert(m.traversal.pose(m).y!=float(m.lookup[expected].h))
				await capture("arrival-"+str(old_map)+"-"+route[0]);saw_arrival=true
			if saw_transition and app.transition.is_empty() and m.traversal.active.is_empty():break
		assert(saw_arrival)
		if route[0]=="up":assert(saw_step,"Mantle must lead into walking")
		assert(saw_transition and app.map_id==route[1] and not m.input_locked)
		assert(m.player==expected and m.lookup.has(m.player))
		assert(app.view.tiles.size()==m.cells.size(),"Previous map tiles retained")
		for idle_frame in 35:
			app._process(1.0/60);app.view._process(1.0/60)
		assert(app.view.hero.clip=="idle")
		await capture("map-"+str(app.map_id))
	print("WORLD_TRAVERSAL_PASS missing-cell hidden-cap rotation directional-transition map-replacement return")
	quit()
func capture(label:String):
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tempassets/work/world-traversal/"+label+".png")

