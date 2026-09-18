extends Node
var SAVE := "user://journey-v1.json"
var state: JourneyState
var fighting := false
var home := HomeState.new()
var expedition_active := false
var autosave_elapsed := 0.0
func _enter_tree():
	preload("res://scripts/journey/native_save_upgrade.gd").import_settings()
func _process(dt: float) -> void:
	home.advance(dt)
	autosave_elapsed += dt
	if state and autosave_elapsed >= 10:
		autosave_elapsed = 0
		save()
func resume() -> void:
	if state: return
	state = JourneyState.new()
	if FileAccess.file_exists(SAVE):
		var value = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if value is Dictionary and state.restore(value):
			if not value.has("home") and not FileAccess.file_exists(SAVE+".before-home.json"):
				DirAccess.copy_absolute(SAVE,SAVE+".before-home.json")
			if value.get("home") is Dictionary: home.restore(value.home)
			expedition_active = bool(value.get("expedition_active",false))
func save() -> bool:
	if not state: return false
	var file := FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if not file: return false
	var data := state.to_save()
	data.home = home.to_save()
	data.expedition_active = expedition_active
	file.store_string(JSON.stringify(data))
	file.close()
	return DirAccess.rename_absolute(SAVE+".tmp",SAVE) == OK
func enter_battle() -> bool:
	if not state or state.active_zone().is_empty(): return false
	fighting = false
	save()
	get_tree().set_meta("native_route_view",true)
	get_tree().change_scene_to_file("res://scenes/expedition_route.tscn")
	return true
func return_to_world() -> void:
	fighting = false
	save()
	get_tree().change_scene_to_file("res://scenes/journey.tscn")
func depart(destination: int) -> void:
	if expedition_active: return
	state = JourneyState.new()
	state.world.load_map(posmod(home.returns*3+destination,32))
	state.setup_zones()
	expedition_active = true
	fighting = false
	save()
func return_home() -> bool:
	if fighting or not expedition_active or state.world.walking: return false
	home.bank += state.stones
	home.returns += 1
	home.message = "平安归来 · 行囊中的 %d 秘银已入库。" % state.stones
	state.stones = 0
	expedition_active = false
	save()
	get_tree().change_scene_to_file("res://scenes/home.tscn")
	return true
