extends "res://scripts/adventure_item.gd"
signal held
var held_time:=0.0
var did_hold:=false
func _ready():
 super()
 button_down.connect(func():held_time=0;did_hold=false)
func _process(dt):
 if button_pressed and not did_hold:
  held_time+=dt
  if held_time>=.55:did_hold=true;held.emit()
func _get_drag_data(_position:Vector2) -> Variant:return null
