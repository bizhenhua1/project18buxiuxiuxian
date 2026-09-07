extends Node
func _ready() -> void:
	DisplayServer.window_set_title("云岫 · 连续冒险与战斗验收")
	Journey.SAVE = "user://adventure-preview.json"
	Journey.state = JourneyState.new()
	Journey.expedition_active = true
	Journey.fighting = false
	Journey.state.pending = Journey.state.zones[0].id
	Journey.state.world.input_locked = true
	get_tree().call_deferred("change_scene_to_file","res://scenes/expedition_route.tscn")
