extends Control
var home: HomeState
var view: HomeMapView
var status: Label
var selection: Label
var note: Label
var moving := Vector2i(-999,-999)
func _ready() -> void:
	Journey.resume()
	home = Journey.home
	theme = StudyUI.theme()
	var column := StudyUI.column(self)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := StudyUI.label("灯下寓所 · 我的主岛",32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(StudyUI.button("森林场景调校",func():
		get_tree().set_meta("forest_lab_return_style",StyleLibrary.active)
		get_tree().change_scene_to_file("res://scenes/forest_lab.tscn")))
	top.add_child(StudyUI.button("表现样本",func():get_tree().change_scene_to_file("res://scenes/study_hub.tscn")))
	status = StudyUI.label("",18)
	column.add_child(status)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	view = HomeMapView.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(450,250)
	body.add_child(view)
	view.setup(home.world,IslandAssets.new())
	view.world.get_child(0).environment.background_color = Color("172c2d")
	var ambience := IslandAmbience.new()
	view.world.add_child(ambience)
	ambience.setup(view)
	view.cell_selected.connect(select_cell)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation",12)
	scroll.add_child(side)
	side.add_child(StudyUI.label("一方居所，万里归途",23))
	selection = StudyUI.label("",17)
	selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(selection)
	side.add_child(StudyUI.button("开拓选中封土 · 10 秘银",func():act(home.unlock(home.selected))))
	for kind in HomeState.PLANTS:
		var key: String = kind
		side.add_child(StudyUI.button("布置 %s · %d 秘银" % [HomeState.PLANTS[key].name,HomeState.PLANTS[key].cost],func():act(home.plant(home.selected,key))))
	side.add_child(StudyUI.button("搬迁选中种植 → 再点空地",func():
		if home.plots.has(home.selected):
			moving = home.selected
			home.message = "请选择已解锁空地；再点原地取消。"))
	side.add_child(StudyUI.button("收获成熟草木",func():home.harvest(); Journey.save()))
	note = StudyUI.label("",16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(note)
	side.add_child(StudyUI.label("云外出征",23))
	for index in range(3):
		var destination := index
		var depart_button := StudyUI.button(["青岚屿 · 林径与洞口","流霞洲 · 云谷与行商","苍石岛 · 岩隙与旧事"][index],func():
			Journey.depart(destination)
			get_tree().change_scene_to_file("res://scenes/journey.tscn"))
		depart_button.disabled = Journey.expedition_active
		side.add_child(depart_button)
	if Journey.expedition_active:
		side.add_child(StudyUI.button("继续尚未返航的出征",func():get_tree().change_scene_to_file("res://scenes/journey.tscn")))
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	bottom.add_child(StudyUI.button("↶ 转向",func():home.world.rotate_view(-1)))
	bottom.add_child(StudyUI.button("转向 ↷",func():home.world.rotate_view(1)))
	bottom.add_child(StudyUI.label("点击地块安排种植 · 滚轮缩放 · 草木在游戏运行时生长",15))
	refresh()
func select_cell(p: Vector2i) -> void:
	if moving != Vector2i(-999,-999):
		if p == moving: home.message = "已取消搬迁。"
		else: act(home.relocate(moving,p))
		moving = Vector2i(-999,-999)
	home.selected = p
	refresh()
func act(ok: bool) -> void:
	if not ok: home.message = "暂不能操作：请检查秘银、相邻解锁条件和地块占用。"
	Journey.save()
	refresh()
func _process(dt: float) -> void:
	home.world.advance(dt)
	refresh()
func refresh() -> void:
	status.text = "主岛仓储 · 秘银 %d   |   已开拓 %d / %d   |   返航 %d 次" % [home.bank,home.unlocked.size(),home.world.cells.size(),home.returns]
	var p := home.selected
	selection.text = "选中地块 · %d，%d\n" % [p.x-7,p.y-7]
	if home.plots.has(p):
		var plot: Dictionary = home.plots[p]
		var spec: Dictionary = HomeState.PLANTS[plot.kind]
		selection.text += "%s · 生长 %d%%\n成熟收获 %d 秘银" % [spec.name,100*plot.growth/spec.period,spec.yield]
	elif p == home.world.player: selection.text += "归航点 · 为出发与返回保留"
	elif p == Vector2i(10,8): selection.text += "护岛古木 · 常驻景观"
	elif p == HomeState.COTTAGE: selection.text += "归云小居 · 出征所得在此入库"
	else: selection.text += "空地 · 可安排种植" if home.unlocked.has(p) else "封土 · 需要从相邻领地开拓"
	note.text = home.message
