extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	StyleLibrary.active=true
	root.size=Vector2i(1200,800)
	var art:=ForestArt.new()
	var world:=SegmentWorld.new(art,LocalRouteSpec.plan({"theme":"forest"}))
	var tree:Dictionary=world.sprites.filter(func(s):return s.kind==0)[0].duplicate()
	tree.position=Vector2(90,700)
	world.sprites=[tree]
	var view:=SegmentView.new()
	root.add_child(view);view.size=Vector2(1200,800)
	view.setup(art,world,1,ThemeDB.fallback_font)
	view.renderer.visible=false
	# Instrument the real production shader only in this isolated test material.
	var code:=FileAccess.get_file_as_string("res://shaders/space_ground.gdshader")
	code=code.replace("uniform vec4 sky_bottom;","uniform vec4 sky_bottom;\nuniform vec2 probe;")
	code=code.replace("COLOR = vec4(color,1.0);","COLOR = distance(world,probe)<12.0 ? vec4(1,0,1,1) : vec4(0,0,0,1);")
	var shader:=Shader.new();shader.code=code
	view.ground_material.shader=shader
	view.ground_material.set_shader_parameter("probe",tree.position)
	var worst:=0.0
	for preset in ForestSettings.CAMERA_PRESETS.values():
		ForestSettings.values.merge(preset,true)
		for yaw in [-.25,0.0,.25]:
			for step in [0,80,160,240]:
				view.sync(Vector2(0,step),yaw,0,0,0,false,false,step)
				for i in range(2):await process_frame
				await RenderingServer.frame_post_draw
				var projected:Array=view.renderer._project_space(600,view.renderer.horizon_y(),view.renderer.focal())
				assert(projected.size()==1)
				var rect:Rect2=projected[0].rect
				var anchor:Vector2=tree.ground_anchor
				if tree.flip:anchor.x=1-anchor.x
				var expected:=rect.position+rect.size*anchor
				var image:=root.get_texture().get_image()
				var sum:=Vector2.ZERO
				var count:=0
				for y in range(maxi(0,int(expected.y)-12),mini(800,int(expected.y)+13)):
					for x in range(maxi(0,int(expected.x)-12),mini(1200,int(expected.x)+13)):
						var c:=image.get_pixel(x,y)
						if c.r>.9 and c.b>.9 and c.g<.1:sum+=Vector2(x+.5,y+.5);count+=1
				if count==0:
					image.save_png("res://captures/ground-registration-failure.png")
					print("PROBE_FAILURE expected=",expected," resolution=",view.ground_material.get_shader_parameter("resolution")," camera=",view.ground_material.get_shader_parameter("camera_world")," ecology=",view.ground_material.get_shader_parameter("ecology")," size=",view.ground.size)
					quit(1);return
				worst=maxf(worst,(sum/count).distance_to(expected))
	assert(worst<1.0,"Ground/anchor registration exceeds one pixel")
	print("GROUND_REGISTRATION_PASS actual GPU ground vs CPU tree anchor; 36 preset/moving/yaw poses; worst pixels=",worst)
	quit()
