extends RefCounted
const LOADOUT=preload("res://scripts/equipment/loadouts.gd")
const LABELS={"left":"左手","right":"右手","head":"头部","body":"衣服","jewel":"首饰","feet":"鞋子"}
var window:Window
var slots:Dictionary={}
var message:Label
var weapon_list:ItemList
var current_slot:="right"
var model_key:=""
var weapon_options:Array=[]
var route:Control
func populate(owner_route:Control):
 route=owner_route
 var roster:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_roster.json"))
 for i in roster.size():
  var id:String="character_"+str(i)
  var entry:Dictionary=roster[i]
  var b=preload("res://scripts/equipment/character_item.gd").new();b.text=entry.name
  var deployed:bool=route.model.player.any(func(u):return (u.cardType=="char" or u.get("portrait_kind","")=="person") and LOADOUT.model_for_unit(u)==entry.file)
  b.art=load("res://assets/character-portraits/"+entry.file.get_basename()+".png")
  b.tooltip_text=entry.name+" · 点击上阵/收回，长按装配"
  b.subtitle="已上阵 · 长按装配" if deployed else "点击上阵 · 长按装配"
  b.pressed.connect(func():
   if b.did_hold:return
   var index:int=-1
   for j in route.model.player.size():
    if (route.model.player[j].cardType=="char" or route.model.player[j].get("portrait_kind","")=="person") and LOADOUT.model_for_unit(route.model.player[j])==entry.file:index=j;break
   if index>=0:
    if route.model.player.filter(func(u):return u.cardType=="char").size()<=1:route.note("至少保留一位角色");return
    route.model.remove_at(index)
   else:route.note(route.model.add_card(id))
   route.arena.rebuild();route._refresh_kit();Journey.save())
  b.held.connect(func():open_loadout(entry.file,entry.name))
  route.kit_items.add_child(b)
func open_loadout(key:String,title:String):
 model_key=key
 window=Window.new();window.title=title+" · 装配";window.size=Vector2i(720,680);window.exclusive=true;window.transient=true;route.add_child(window)
 window.close_requested.connect(func():window.queue_free())
 var bg=PanelContainer.new();var skin=StyleBoxFlat.new();skin.bg_color=Color("101b1d");skin.border_color=Color("887451");skin.set_border_width_all(1);skin.content_margin_left=16;skin.content_margin_right=16;skin.content_margin_top=16;skin.content_margin_bottom=16;bg.add_theme_stylebox_override("panel",skin);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);window.add_child(bg)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);bg.add_child(column)
 var heading=Label.new();heading.text=title+" · 六槽装配";heading.add_theme_font_size_override("font_size",24);column.add_child(heading)
 var grid=GridContainer.new();grid.columns=3;column.add_child(grid);slots.clear()
 for key_slot in LABELS:
  var b=Button.new();b.custom_minimum_size=Vector2(215,74);grid.add_child(b);slots[key_slot]=b
  b.pressed.connect(func():
   current_slot=key_slot
   if key_slot not in ["left","right"]:message.text="该位置暂未开放装备";return
   message.text="选择装入"+LABELS[key_slot]+"的武器";weapon_list.visible=true)
 message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(message)
 weapon_list=ItemList.new();weapon_list.custom_minimum_size.y=290;weapon_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(weapon_list)
 weapon_options=LOADOUT.weapons()
 for w in weapon_options:weapon_list.add_item("卸下" if w.file.is_empty() else w.name+(" · 双手（占两槽）" if LOADOUT.two_handed(w.file) else " · 单手"))
 weapon_list.item_selected.connect(func(index):
  var error:String=LOADOUT.equip(model_key,current_slot,weapon_options[index].file)
  refresh();message.text=error if not error.is_empty() else "已保存 · "+LABELS[current_slot]+"装备已更新")
 var close=Button.new();close.text="完成装配";column.add_child(close);close.pressed.connect(func():window.queue_free())
 refresh();window.popup_centered()
func refresh():
 var data:Dictionary=LOADOUT.get_loadout(model_key)
 for slot in slots:
  var file:String=data[slot]
  slots[slot].text=LABELS[slot]+"\n"+("待开放" if slot not in ["left","right"] else "未装备" if file.is_empty() else LOADOUT.item(file).get("name",file))+("（双手占用）" if LOADOUT.two_handed(file) else "")
 message.text="动作方案："+{"mage":"法师","spear":"长矛","warrior":"战士","sword":"剑术","sword_shield":"剑盾","sword_dual":"双持剑术","unarmed":"未持武器"}.get(LOADOUT.profile(data),"")+" · 单手可双持或配盾，禁止双盾"
