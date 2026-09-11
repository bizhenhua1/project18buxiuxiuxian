extends Control
const Catalog=preload("res://scripts/spaces/biome_catalog.gd")
func _ready() -> void:
 StyleLibrary.active=true
 DisplayServer.window_set_title("雾林调查局 · 异域场景目录")
 var bg:=ColorRect.new();bg.color=Color("0c1319");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,40)
 add_child(margin)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",18);margin.add_child(column)
 column.add_child(StudyUI.label("异域调查 · 场景目录",30))
 column.add_child(StudyUI.label("独立随机布局 · 行进与无限战斗 · 共用已保存镜头",16))
 var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(row)
 var descriptions=["低垂岩层与隐秘矿脉","蓝雾、菌群与孢光","逼仄管廊与流动污水","肋壁与吞入的遗物","保留的旧版拱券长廊"]
 for i in range(5):
  var key:String=Catalog.TITLES.keys()[i]
  var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(box)
  var art:=TextureRect.new();art.texture=load("res://assets/biomes/%s/shell.png"%key);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.custom_minimum_size=Vector2(0,180);box.add_child(art)
  box.add_child(StudyUI.label(Catalog.TITLES[key],23))
  box.add_child(StudyUI.label(descriptions[i],16))
  var button:=AdventureSkin.button("进入 · 无限探索",func():
   get_tree().set_meta("tour_biome",key)
   get_tree().set_meta("tour_lap",1)
   get_tree().change_scene_to_file("res://scenes/endless_forest.tscn"))
  box.add_child(button)
 column.add_child(AdventureSkin.button("黑暗童话 · 十八个新场景",func():get_tree().change_scene_to_file("res://scenes/fairytale_hub.tscn")))
 var seeds:=HBoxContainer.new();column.add_child(seeds)
 var topology:=OptionButton.new()
 for label in ["路口：随机两岔 / 三岔","只看两岔","只看三岔"]:topology.add_item(label)
 topology.item_selected.connect(func(i):
  if i==0:get_tree().remove_meta("tour_exits")
  else:get_tree().set_meta("tour_exits",i+1))
 get_tree().remove_meta("tour_exits")
 seeds.add_child(topology)
 var events:=OptionButton.new()
 for label in ["事件：随机前后安排","先遇事再选路","选路后遇事"]:events.add_item(label)
 events.item_selected.connect(func(i):
  if i==0:get_tree().remove_meta("tour_event_placement")
  else:get_tree().set_meta("tour_event_placement","before" if i==1 else "after"))
 get_tree().remove_meta("tour_event_placement")
 seeds.add_child(events)
 seeds.add_child(StudyUI.label("场景与路线种子",16))
 var seed_box:=SpinBox.new();seed_box.min_value=1;seed_box.max_value=999999;seed_box.value=Catalog.seed_value;seeds.add_child(seed_box)
 seed_box.value_changed.connect(func(v):Catalog.seed_value=int(v))
 seeds.add_child(AdventureSkin.button("换一组随机布局",func():seed_box.value=randi_range(1,999999)))
 seeds.add_child(StudyUI.label("装饰密度",16))
 var density:=SpinBox.new();density.min_value=.5;density.max_value=2;density.step=.1;density.value=Catalog.density_scale;seeds.add_child(density)
 density.value_changed.connect(func(v):Catalog.density_scale=v)
 column.add_child(AdventureSkin.button("返回幽暗森林",func():
  get_tree().remove_meta("tour_biome")
  get_tree().change_scene_to_file("res://scenes/mistwood_start.tscn")))
