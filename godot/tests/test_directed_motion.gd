extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 StyleLibrary.active=true
 var session=root.get_node("Journey");session.SAVE="user://directed-motion-test.json";session.state=JourneyState.new()
 session.state.pending=session.state.zones[0].id
 var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.arena.set_process(false);app.prepare_encounter()
 var arena=app.arena;arena.scene_mode=true;arena.battle_mix=1;arena.enemies_visible=true;arena._process(0)
 var player=arena.cards.filter(func(c):return c.side=="player" and c.unit.get("cardType","")=="char")[0]
 var foe=arena.cards.filter(func(c):return c.side=="enemy")[0]
 var line:Vector2=foe.scene_rest_position-player.scene_rest_position
 arena.on_event({"type":"shot","from":player.unit,"to":foe.unit})
 assert(player.motion_world_direction.dot(line.normalized())>.999)
 player.motion_age=.14;arena._process(0)
 assert(player.scene_motion_offset.dot(line)>0,"Attack did not advance")
 var current:Vector2=player.scene_motion_offset
 arena.on_event({"type":"damage","unit":player.unit,"source":foe.unit,"amount":1})
 arena._process(0)
 assert(player.scene_motion_offset.distance_to(current)<.001,"Interrupted motion snapped")
 assert(player.motion_world_direction.dot(line.normalized())<-.999)
 player.motion_age=.15;arena._process(0)
 assert(player.scene_motion_offset.dot(line)<0,"Hit did not recoil")
 player.motion_age=1;arena._process(0)
 assert(player.scene_motion_offset.length()<.001,"Motion did not return to rest")
 arena.on_event({"type":"shot","from":foe.unit,"to":player.unit})
 assert(foe.motion_world_direction.dot(line.normalized())<-.999,"Enemy advances backwards")
 print("DIRECTED_MOTION_PASS attack, recoil, enemy direction, continuous interruption and return")
 quit()
