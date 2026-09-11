extends "res://scripts/journey/journey_view.gd"
func _ready()->void:
 StyleLibrary.active=true
 var key:=str(get_tree().get_meta("fairytale_world","red_village"))
 FairytaleCatalog.world_override=key
 Journey.SAVE="user://fairytale-world-preview.json"
 Journey.state=JourneyState.new();Journey.expedition_active=true;Journey.fighting=false
 FairytaleCatalog.world_override=""
 super()
 var back:=AdventureSkin.button("返回童话目录",func():get_tree().change_scene_to_file("res://scenes/fairytale_hub.tscn"))
 add_child(back);back.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT);back.position=Vector2(24,size.y-52)
 DisplayServer.window_set_title(FairytaleCatalog.entry(key).get("name",key)+" · 世界地块")
