extends Node
func _ready() -> void:
	StyleLibrary.active = true
	DisplayServer.window_set_title("雾林调查局 · 风格 2 · 森林群落版")
	Journey.SAVE = "user://style2-preview.json"
	Journey.state = JourneyState.new()
	Journey.expedition_active = true
	Journey.fighting = false
	for zone in Journey.state.zones:
		zone.theme = "forest"
		zone.title = ["旧林巡查道","失联驿站","钟楼岔路"][int(zone.tier)]
	Journey.state.world.set_reveal_range(2)
	get_tree().call_deferred("change_scene_to_file","res://scenes/journey.tscn")
