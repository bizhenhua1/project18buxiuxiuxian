extends Control
var model := BattleModel.new()
var arena: BattleArena
var status: Label
var detail: Label
var message: Label
var log_text: RichTextLabel
var start_button: Button
var pause_button: Button
var speed := 1.0
var selected: Dictionary = {}
var accumulator := 0.0
var detail_panel: VBoxContainer
var journey_battle := false
var return_button: Button
var formation_controls: Array[Control] = []
func _ready() -> void:
	journey_battle = Journey.fighting and Journey.state != null
	if journey_battle: model = Journey.state.battle
	theme = StudyUI.theme()
	var column := StudyUI.column(self)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := StudyUI.label("仙途 · 列阵试锋",28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if journey_battle:
		title.text = "云岫 · "+str(Journey.state.active_zone().get("title","妖息遭遇"))
		return_button = StudyUI.button("返回浮岛",func():Journey.return_to_world())
		top.add_child(return_button)
	else:
		top.add_child(StudyUI.button("浮岛 2D / 3D",func():get_tree().change_scene_to_file("res://scenes/world_study.tscn")))
		top.add_child(StudyUI.button("局内冒险",func():get_tree().change_scene_to_file("res://scenes/space_study.tscn")))
		top.add_child(StudyUI.button("目录",func():get_tree().change_scene_to_file("res://scenes/study_hub.tscn")))
	status = StudyUI.label("",18)
	column.add_child(status)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",16)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 190
	body.add_child(left)
	left.add_child(StudyUI.label("可用卡牌",20))
	left.add_child(StudyUI.label("点击加入 · 全卡试验库",13))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var pool := VBoxContainer.new()
	pool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pool)
	for spec in model.rules.cards:
		var id: String = spec.id
		var prefix := "御兽 · " if spec.pool == "enemy" else ""
		var button := StudyUI.button(prefix+spec.name,func():
			note(model.add_card(id))
			arena.rebuild())
		button.tooltip_text = spec.skillText
		pool.add_child(button)
	arena = BattleArena.new()
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.custom_minimum_size = Vector2(560,360)
	body.add_child(arena)
	arena.setup(model,self)
	var right := VBoxContainer.new()
	detail_panel = right
	right.custom_minimum_size.x = 230
	body.add_child(right)
	right.add_child(StudyUI.label("观战手记",20))
	detail = StudyUI.label("点击卡牌查看属性与技能",14)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(230,175)
	right.add_child(detail)
	right.add_child(StudyUI.button("切换选中法宝模式",func():
		if not selected.is_empty() and selected.side == "player": arena.change_mode(selected.index)))
	log_text = RichTextLabel.new()
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size",13)
	right.add_child(log_text)
	var bar := HFlowContainer.new()
	column.add_child(bar)
	start_button = StudyUI.button("开始战斗",start)
	bar.add_child(start_button)
	pause_button = StudyUI.button("暂停",func():model.paused = not model.paused)
	bar.add_child(pause_button)
	bar.add_child(StudyUI.button("重新布阵",reset))
	bar.add_child(StudyUI.button("默认阵容",func():
		model.reset()
		model.default_lineup()
		arena.rebuild()))
	bar.add_child(StudyUI.button("护阵示例",guard_lineup))
	bar.add_child(StudyUI.button("换组对手",func():
		model.reset()
		model.fill_enemies(true)
		arena.rebuild()))
	var stage_picker := SpinBox.new()
	stage_picker.min_value = 1
	stage_picker.max_value = 32
	stage_picker.prefix = "关卡 "
	stage_picker.value_changed.connect(func(value):
		model.stage = int(value)-1
		model.reset()
		model.fill_enemies()
		arena.rebuild())
	bar.add_child(stage_picker)
	if journey_battle:
		stage_picker.hide()
		for child in bar.get_children():
			if child is Button:
				if child.text == "换组对手": child.hide()
				elif child.text in ["重新布阵","默认阵容","护阵示例"]: formation_controls.append(child)
	var speed_picker := OptionButton.new()
	for name_value in ["0.5× 慢放","1× 正常","2× 加速","4× 快进"]: speed_picker.add_item(name_value)
	speed_picker.select(1)
	speed_picker.item_selected.connect(func(i):speed = [0.5,1.0,2.0,4.0][i])
	bar.add_child(speed_picker)
	message = StudyUI.label("拖动己方卡牌调整顺序 · 双击法宝切模式 · 右键移除 · 空格暂停",14)
	column.add_child(message)
	model.emitted.connect(record_event)
	model.finished.connect(finish)
	print("BATTLE_STUDY_READY cards=%d" % model.rules.cards.size())
func note(value: String) -> void:
	message.text = "阵容已更新" if value.is_empty() else value
func start() -> void:
	if model.start():
		accumulator = 0
		log_text.clear()
		log_text.append_text("战斗开始 · 优先攻击最左可承伤单位\n")
		arena.effects.clear()
		arena.particles.clear()
func reset() -> void:
	if journey_battle and model.phase == "victory": return
	model.reset()
	accumulator = 0
	arena.particles.clear()
	arena.rebuild()
	log_text.clear()
func _process(dt: float) -> void:
	if model.phase == "battle" and not model.paused:
		accumulator += minf(dt,.15)*speed
		while accumulator >= 1.0/120:
			model.advance(1.0/120)
			accumulator -= 1.0/120
	if not status: return
	detail_panel.visible = size.x >= 1250
	var names := {"prepare":"准备布阵","battle":"交战中","victory":"胜利","defeat":"战败","draw":"同归于尽"}
	status.text = "第 %d 关 · %s · %.1f 秒 · 己方 %d / %d · 对手 %d / %d" % [model.stage+1,names[model.phase],model.elapsed,BattleRules.living(model.player).size(),model.player.size(),BattleRules.living(model.enemy).size(),model.enemy.size()]
	start_button.disabled = model.phase != "prepare"
	pause_button.disabled = model.phase != "battle"
	pause_button.text = "继续" if model.paused else "暂停"
	if journey_battle:
		return_button.disabled = model.phase == "battle"
		for control in formation_controls: control.disabled = model.phase in ["battle","victory"]
	if not selected.is_empty(): show_detail(selected)
func show_detail(unit: Dictionary) -> void:
	selected = unit
	if not detail: return
	detail.text = "%s\n生命 %d / %d · 护盾 %d\n攻击 %.1f · 间隔 %.2fs\n外防 %d · 内防 %d\n累计伤害 %.0f · 治疗 %.0f\n\n%s" % [unit.name,unit.hp,unit.maxHp,unit.shield,unit.atk,unit.cd/1000.0,unit.physDef,unit.spellDef,unit.damageDealt,unit.healDone,unit.skillText]
	if unit.mode == "held": detail.text += "\n手持：不独立承伤，30% 基础血量并入道童；主动技能封印。"
func guard_lineup() -> void:
	if journey_battle and model.phase == "victory": return
	model.reset()
	log_text.clear()
	model.player.clear()
	for id in ["waci-yin","masuo","daotong","taomu-jian","tongjing","xiaohulu","qingfeng-jian","lihuo-shu"]:
		model.add_card(id)
	model.toggle_mode(3)
	arena.rebuild()
	note("护阵：瓦瓷印在前承伤，道童居中，桃木剑手持；战斗数值沿用原型")
func record_event(event: Dictionary) -> void:
	if event.type in ["death","revive"]:
		log_text.append_text("%.1fs  %s%s\n" % [model.elapsed,event.unit.name,"倒下" if event.type == "death" else "重聚"])
func finish(result: String) -> void:
	log_text.append_text("\n%s · %.1f 秒\n" % [{"victory":"此战告捷","defeat":"此战失利","draw":"同归于尽"}[result],model.elapsed])
	var ranked := model.player.duplicate()
	ranked.sort_custom(func(a,b):return a.damageDealt > b.damageDealt)
	for unit in ranked: log_text.append_text("%s：伤害 %.0f / 治疗 %.0f\n" % [unit.name,unit.damageDealt,unit.healDone])
	message.text = "结算完成；重新布阵可调整战术，或更换对手继续试验"
	if journey_battle:
		Journey.state.settle(result)
		Journey.save()
		message.text = "妖息已平，所得灵石已记入行囊。返回浮岛继续探路。" if result == "victory" else "此处妖息尚在。可以调整阵容再战，或返回浮岛退回来路。"
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_SPACE and model.phase == "battle": model.paused = not model.paused
