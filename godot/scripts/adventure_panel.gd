class_name AdventurePanel
extends Control
var fill := Color(.045,.085,.073,.96)
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void: AdventureSkin.frame(self,Rect2(Vector2.ZERO,size),fill)
