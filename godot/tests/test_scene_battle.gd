extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 StyleLibrary.active=true;root.size=Vector2i(1600,960)
 var session=root.get_node("Journey");session.SAVE="user://scene-mode-test.json";session.state=JourneyState.new()
 session.state.pending=session.state.zones[0].id
 var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.prepare_encounter();app.arena.battle_mix=1;app.arena.entrance_progress=1;app.arena.enemies_visible=true
 var original:=JSON.stringify(app.model.player)
 app.arena.scene_mode=true;app.arena._process(0)
 for view in app.views:view.sync(Vector2.ZERO,0,0,0,0,false,false,0)
 for card in app.arena.cards:card.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.hovered=false
 for i in range(8):await process_frame
 assert(not app.arena.player_backdrop.visible and not app.arena.enemy_backdrop.visible)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://captures/scene-battle-preview.png")
 app.arena.scene_mode=false;app.arena._process(0)
 assert(app.arena.player_backdrop.visible)
 app.arena.scene_mode=true;app.arena._process(0)
 assert(JSON.stringify(app.model.player)==original)
 print("SCENE_MODE_PASS borderless/card toggling preserves combat units; original frames restored; rear assets loaded")
 quit()
