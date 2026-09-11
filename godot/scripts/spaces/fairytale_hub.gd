extends Control
var grid:GridContainer
var story_pick:OptionButton
func _ready()->void:
 StyleLibrary.active=true
 DisplayServer.window_set_title("黑暗童话 · 十八异境")
 var bg:=ColorRect.new();bg.color=Color("0c1519");bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(bg)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(margin)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
 var column:=VBoxContainer.new();margin.add_child(column)
 column.add_child(StudyUI.label("黑暗童话 · 故事之外的地方",30))
 var bar:=HBoxContainer.new();column.add_child(bar)
 story_pick=OptionButton.new();story_pick.add_item("全部故事");bar.add_child(story_pick)
 for title in ["小红帽","白雪公主","爱丽丝","吹笛人","木偶奇遇记","灰姑娘"]:story_pick.add_item(title)
 story_pick.item_selected.connect(func(_i):refresh())
 bar.add_child(AdventureSkin.button("返回六大主题",func():get_tree().change_scene_to_file("res://scenes/biome_hub.tscn")))
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=SIZE_EXPAND_FILL;column.add_child(scroll)
 grid=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",20);grid.add_theme_constant_override("v_separation",20);scroll.add_child(grid)
 refresh()
func refresh()->void:
 for child in grid.get_children():grid.remove_child(child);child.queue_free()
 for scene in FairytaleCatalog.scenes:
  if story_pick.selected>0 and scene.story!=story_pick.get_item_text(story_pick.selected):continue
  var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(300,0);box.size_flags_horizontal=SIZE_EXPAND_FILL;grid.add_child(box)
  var picture:=TextureRect.new();picture.texture=load(FairytaleCatalog.asset(scene.id,"structure.png"));picture.custom_minimum_size.y=175;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;box.add_child(picture)
  box.add_child(StudyUI.label(scene.name,23))
  var description:=StudyUI.label(scene.story+" · "+" / ".join(scene.enemies),14)
  description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(description)
  box.add_child(AdventureSkin.button("进入场景 · 探索与战斗",func():
   get_tree().set_meta("tour_biome",scene.id)
   get_tree().change_scene_to_file("res://scenes/endless_forest.tscn")))
  box.add_child(AdventureSkin.button("查看世界地块与怪物",func():
   get_tree().set_meta("fairytale_world",scene.id)
   get_tree().change_scene_to_file("res://scenes/fairytale_world.tscn")))
