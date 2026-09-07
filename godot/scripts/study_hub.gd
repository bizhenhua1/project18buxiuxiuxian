extends Control
func _ready() -> void:
	theme = StudyUI.theme()
	var column := StudyUI.column(self)
	column.add_spacer(false)
	column.add_child(StudyUI.label("仙途 · 原生制作样本",38))
	column.add_child(StudyUI.label("从山林中的前行，到列阵交战，再到浮岛探索。",20))
	column.add_child(StudyUI.label("沿用原 Demo 最终素材与战斗基础数值；新表现仍待你试玩确认。",16))
	var journey := StudyUI.button("归云居 · 返回我的主岛",func():
		Journey.resume()
		get_tree().change_scene_to_file("res://scenes/home.tscn"))
	journey.custom_minimum_size.y = 64
	journey.add_theme_font_size_override("font_size",24)
	column.add_child(journey)
	column.add_child(StudyUI.label("经营主岛，出征云外，带回战利品继续养成。",16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	column.add_child(row)
	var entries := [
		["列阵试锋","布阵、手持与操控、识海法术、御兽\n原有技能、弹道、尸体重聚与战斗结算","battle_study"],
		["浮岛 · 两种空间","A：原投影与双阶段旋转\nB：实体地块与 2D 装饰；共用探索进度","world_study"],
		["山林之间","森林、洞穴与云海\n沿路径连续进入不同空间区域","space_study"]]
	for entry in entries:
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var target: String = entry[2]
		var button := StudyUI.button(entry[0],func():get_tree().change_scene_to_file("res://scenes/%s.tscn" % target))
		button.custom_minimum_size.y = 80
		button.add_theme_font_size_override("font_size",24)
		panel.add_child(button)
		var description := StudyUI.label(entry[1],16)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(description)
	column.add_child(StudyUI.button("打开已认可的森林 A / B 基线",func():get_tree().change_scene_to_file("res://scenes/main.tscn")))
	column.add_child(StudyUI.button("崖沿 A / B / C · 近景与整岛对照",func():get_tree().change_scene_to_file("res://scenes/rim_study.tscn")))
	column.add_child(StudyUI.button("A 岛体 · 三套地表与立面贴图",func():get_tree().change_scene_to_file("res://scenes/material_study.tscn")))
	column.add_spacer(false)
	column.add_child(StudyUI.label("建议先试护阵示例，再去浮岛按 Q / E 旋转；两种世界可并排或放大查看。",16))
