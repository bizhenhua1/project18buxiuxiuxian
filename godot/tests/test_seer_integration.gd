extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame
 app.set_process(false);app.arena.set_process(false)
 app.choose(-1);app.phase="travel";app.moving_envelope=1.0
 app.event_panel.hide();app.event_box.hide()
 for i in range(20):
  app._process(.016);await process_frame
 assert(app.arena.seer.clip=="EM_Walk")
 assert(app.arena.scenery.renderer.battle_actors.any(func(a):return a.get("live_character",false)))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/3d/seer/in-game-walk.png")
 app.phase="battle";app.arena.battle_mix=1;app.arena.entrance_progress=1
 for i in range(20):
  app._process(.016);await process_frame
 assert(app.arena.seer.clip=="EM_Idle")
 app.arena.seer.texture().get_image().save_png("res://../art/3d/seer/live-texture.png")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/3d/seer/in-game-battle.png")
 var hero:Dictionary=app.model.player.filter(func(u):return u.cardId=="investigator")[0]
 app.arena.on_event({"type":"shot","from":hero,"to":hero})
 assert(app.arena.seer.clip=="EM_RangeAttack")
 app.model.paused=true;app.arena._process(.05);assert(not app.arena.seer.player.active)
 print("SEER_INTEGRATION_PASS");quit()
