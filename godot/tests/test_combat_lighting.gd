extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame;app.set_process(false);app.choose(-1)
 while app.is_social():app.encounter_step+=1
 app.distance=app.stops()[app.encounter_step];app.fork_transit_time=app.FORK_TRANSIT_SECONDS
 app.prepare_encounter();app.phase="encounter";app.start_battle()
 for i in range(25):app._process(.05);await process_frame
 assert(app.phase=="battle")
 app.model.paused=true;app.paused=true
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/3d/seer/lighting-rest.png")
 var hero:Dictionary=app.model.player.filter(func(u):return u.cardId=="daotong")[0]
 var enemy:Dictionary=app.model.enemy[0]
 app.arena.on_event({"type":"cast","from":hero,"to":enemy})
 app.arena.on_event({"type":"damage","unit":enemy,"source":hero,"amount":12,"crit":true})
 for light in app.arena.light_flashes:light.age=.065
 app.arena._process(0);app.arena.scenery.sync_projection()
 assert(app.arena.light_flashes.is_empty())
 assert(app.arena.scenery.renderer.combat_lights.is_empty())
 var colors=app.arena.scenery.ground_material.get_shader_parameter("combat_light_colors")
 var lit:=false
 for color in colors:
  if color.a>0:lit=true
 assert(not lit)
 for i in range(4):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/3d/seer/lighting-flash.png")
 app.model.paused=false
 app.arena._process(.5)
 assert(app.arena.scenery.renderer.combat_lights.is_empty())
 print("COMBAT_LIGHTING_PASS");quit()
