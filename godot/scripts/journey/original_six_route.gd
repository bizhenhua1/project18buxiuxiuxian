extends "res://scripts/journey/endless_forest.gd"
## Menu/save isolation only: inherit the recovered route in both rendering modes.
func _ready() -> void:
	super()
	Journey.SAVE = "user://original-six-preview.json"
	for link in leave_button.pressed.get_connections():
		leave_button.pressed.disconnect(link.callable)
	leave_button.pressed.connect(func():get_tree().change_scene_to_file("res://scenes/original_six_hub.tscn"))
	leave_button.text = "原始六套目录"
