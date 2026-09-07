class_name ForestSettings
extends RefCounted
const SAVE := "user://forest-style2-settings.json"
const PRESETS := {
	"幽暗密林":{"density":2.0,"size":1.0,"cover":1.6,"width":26.0,"variation":8.0,"bend":12.0,"height":1.0},
	"古木夹道":{"density":1.15,"size":1.25,"cover":1.0,"width":45.0,"variation":9.0,"bend":12.0,"height":.7},
	"荒弃林径":{"density":1.35,"size":.85,"cover":1.8,"width":32.0,"variation":14.0,"bend":24.0,"height":1.2}}
const CAMERA_PRESETS := {
	"原版视角":{"camera_height":58.0,"camera_horizon":.48,"camera_lens":1.0},
	"低机位平视":{"camera_height":42.0,"camera_horizon":.50,"camera_lens":1.0},
	"低机位广视野":{"camera_height":42.0,"camera_horizon":.50,"camera_lens":.85}}
static var values: Dictionary = read_saved()
static func read_saved() -> Dictionary:
	var result: Dictionary=PRESETS["幽暗密林"].duplicate()
	result.merge(CAMERA_PRESETS["原版视角"])
	if FileAccess.file_exists(SAVE):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if saved is Dictionary:
			for key in result:
				if saved.get(key) is float or saved.get(key) is int: result[key]=saved[key]
	return sanitized(result)
static func sanitized(source: Dictionary) -> Dictionary:
	var result:=source.duplicate()
	for key in CAMERA_PRESETS["原版视角"]:
		if not result.has(key): result[key]=CAMERA_PRESETS["原版视角"][key]
	var ranges: Dictionary={"camera_height":Vector2(30,80),"camera_horizon":Vector2(.35,.65),"camera_lens":Vector2(.75,1.25),"density":Vector2(.5,2.5),"size":Vector2(.65,1.4),"cover":Vector2(.3,2),"width":Vector2(26,65),"variation":Vector2(0,18),"bend":Vector2(0,30),"height":Vector2(0,2)}
	for key in ranges: result[key]=clampf(float(result[key]),ranges[key].x,ranges[key].y)
	return result
static func save() -> void:
	values=sanitized(values)
	var file:=FileAccess.open(SAVE,FileAccess.WRITE)
	file.store_string(JSON.stringify(values,"\t"))
