extends "res://scripts/world3d/presentation_shell.gd"
var kit:Button
func _init():stage_scene="res://scenes/defense_3d_stage.tscn"
func _ready():
 await super()
 title.text="林间防线 · 持续来敌"
 stage.set_meta("presentation_scene","res://scenes/defense_3d.tscn")
 kit=Button.new();kit.text="随行整备";add_child(kit)
 kit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);kit.position=Vector2(24,size.y-55)
 resized.connect(func():kit.position=Vector2(24,size.y-55))
 kit.pressed.connect(func():
  if stage.phase!="prepare":return
  if get_node_or_null("PartyEditor"):return
  var editor=preload("res://scripts/world3d/party_editor.gd").new();editor.name="PartyEditor";add_child(editor)
  editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);editor.offset_left=35;editor.offset_top=90;editor.offset_right=-35;editor.offset_bottom=-75
  editor.setup(stage.units)
  editor.applied.connect(func():get_tree().reload_current_scene()))
func _process(_dt:float):
 if kit and stage:kit.disabled=stage.phase!="prepare"
