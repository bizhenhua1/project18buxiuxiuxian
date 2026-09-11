extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1600,1000)
 var browser=load("res://scenes/shader_browser.tscn").instantiate();root.add_child(browser)
 await process_frame
 var journey=root.get_node("Journey");journey.resume();var original=journey.state;var save_path=journey.SAVE
 browser.team_state.item_selected.emit(1)
 assert(not browser.solo_host.visible and browser.game_preview.visible)
 browser.game_preview.hide();browser.solo_host.show()
 browser.team_state.item_selected.emit(1)
 assert(not browser.solo_host.visible and browser.game_preview.visible)
 assert(journey.state==original and journey.SAVE==save_path)
 assert(browser.game_preview.ready_preview)
 browser.team_inputs.x.value=-2.4;browser.team_inputs.energy.value=3.2;browser.team_inputs.road_x.value=28
 var actor=browser.game_preview.app.arena.seer
 var slot=browser.game_preview.app.arena.world_slots[actor.uid]
 assert(absf(angle_difference(actor.body.rotation.y,PI+(.22 if slot.right_facing else -.22)))<.001)
 assert(is_equal_approx(actor.team_key.position.x,-2.4))
 assert(is_equal_approx(actor.team_key.light_energy,3.2))
 assert(is_equal_approx(browser.game_preview.app.arena.scenery.renderer.team_light().road_x,28))
 browser.team_state.item_selected.emit(0);browser.team_inputs.energy.value=.8
 assert(browser.game_preview.app.phase=="travel")
 assert(is_equal_approx(actor.team_key.light_energy,.8))
 browser.team_state.item_selected.emit(1);assert(is_equal_approx(actor.team_key.light_energy,3.2))
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/team-light-battle.png")
 print("TEAM_LIGHT_PASS dropdown opens/reopens real scene, isolated session, battle/travel lights independent, actor and environment controls")
 quit()
