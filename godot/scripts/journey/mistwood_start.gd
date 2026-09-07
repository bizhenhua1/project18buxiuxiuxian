extends Node
## Default playable entry for the current art direction; isolated from style 1 saves.
func _ready() -> void:
	StyleLibrary.active=true
	DisplayServer.window_set_title("雾林调查局 · 幽暗森林")
	Journey.SAVE="user://mistwood-game.json"
	Journey.resume()
	Journey.expedition_active=true
	Journey.fighting=false
	for zone in Journey.state.zones:
		zone.theme="forest"
		zone.title=["旧林巡查道","失联驿站","钟楼岔路"][int(zone.tier)]
	if Journey.state.pending.is_empty():
		for zone in Journey.state.zones:
			if not Journey.state.cleared.has(zone.id):
				Journey.state.pending=zone.id
				break
	Journey.state.world.input_locked=not Journey.state.pending.is_empty()
	var target:="res://scenes/expedition_route.tscn" if not Journey.state.pending.is_empty() else "res://scenes/journey.tscn"
	get_tree().call_deferred("change_scene_to_file",target)
