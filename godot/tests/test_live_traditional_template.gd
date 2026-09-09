extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var session=root.get_node("Journey");session.SAVE="user://live-template-isolated.json";session.state=JourneyState.new();session.expedition_active=true;session.set_process(false)
 StyleLibrary.active=true
 var zone=session.state.zones[0];zone.route_kind="straight";zone.route_profile="short_battle";zone.theme="forest";zone.battle_choice=true;session.state.pending=zone.id
 var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app)
 await process_frame
 app.set_process(false);app.arena.scene_mode=true
 var controller=app.live_template
 controller.active_path="user://live-template-test.json"
 var value=JSON.parse_string(FileAccess.get_file_as_string(controller.ACTIVE))
 var f=FileAccess.open(controller.active_path,FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
 app.phase="travel";app.paused=false
 for i in range(20):app._process(.025)
 assert(not controller.data.is_empty())
 app.phase="battle";app.arena.battle_mix=1
 for i in range(150):
  controller.advance(app,.025)
 assert(is_equal_approx(controller.current.height,value.frames.battle.height))
 controller.prepare_slots(app.model.player)
 assert(controller.slot_targets.size()==app.model.player.size())
 var changed=value.duplicate(true);changed.frames.battle.height=46
 f=FileAccess.open(controller.active_path,FileAccess.WRITE);f.store_string(JSON.stringify(changed));f.close()
 for i in range(200):controller.advance(app,.025)
 assert(absf(controller.current.height-46)<.01,"Running controller did not reload saved template")
 f=FileAccess.open(controller.active_path,FileAccess.WRITE);f.store_string("{invalid");f.close();controller.poll(1)
 assert(controller.data.frames.battle.height==46,"Invalid save replaced active configuration")
 var extra=app.model.player.duplicate(true)
 var unit=extra[0].duplicate(true);unit.uid=999999;extra.append(unit)
 controller.prepare_slots(extra);assert(controller.slot_targets.size()==extra.size())
 DirAccess.remove_absolute(controller.active_path)
 print("LIVE_TRADITIONAL_PASS runtime load, hot reload, invalid-file fallback, variable party size")
 quit()
