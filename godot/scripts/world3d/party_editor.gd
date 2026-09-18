extends PanelContainer
signal applied
const PARTY=preload("res://scripts/world3d/party.gd")
var model:=BattleModel.new()
var equipment=preload("res://scripts/equipment/kit_roster.gd").new()
var lineup:VBoxContainer
var message:Label
var character_items:Array=[]
func setup(units:Array):
 var skin:=StyleBoxFlat.new();skin.bg_color=Color("101918");skin.border_color=Color("887451");skin.set_border_width_all(1)
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:skin.set_content_margin(side,16)
 add_theme_stylebox_override("panel",skin)
 model.player=units.duplicate(true);model.stage=2;model.restat()
 equipment.route=self
 var column:=VBoxContainer.new();add_child(column)
 var heading:=Label.new();heading.text="随行整备 · 调整站位后保存应用";column.add_child(heading)
 message=Label.new();column.add_child(message)
 var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=330;body.add_child(scroll)
 lineup=VBoxContainer.new();lineup.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(lineup)
 var tabs:=TabContainer.new();tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(tabs)
 var people:=GridContainer.new();people.columns=3
 var relics:=VBoxContainer.new()
 for pair in [["角色",people],["神秘道具",relics]]:
  var page:=ScrollContainer.new();page.name=pair[0];tabs.add_child(page);page.add_child(pair[1])
 var roster:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_roster.json"))
 for i in roster.size():
  var entry:Dictionary=roster[i];var id:String="character_"+str(i)
  var item=preload("res://scripts/equipment/character_item.gd").new()
  item.text=entry.name;item.subtitle="点击上阵 · 长按装配";item.custom_minimum_size=Vector2(160,160)
  item.art=load("res://assets/character-portraits/"+entry.file.get_basename()+".png");people.add_child(item)
  character_items.append({"item":item,"file":entry.file})
  item.pressed.connect(func():
   if not item.did_hold:add_card(id))
  item.held.connect(func():equipment.open_loadout(entry.file,entry.name))
 for spec in model.rules.cards:
  if spec.pool=="enemy" or PARTY.character(spec):continue
  var id:String=spec.id
  var button:=Button.new();button.text=spec.name;button.tooltip_text=spec.skillText;relics.add_child(button)
  button.pressed.connect(func():add_card(id))
 var buttons:=HBoxContainer.new();column.add_child(buttons)
 var apply:=Button.new();apply.text="保存并应用";buttons.add_child(apply);apply.pressed.connect(func():
  if save_formation():applied.emit()
  else:message.text="保存失败，阵容尚未应用")
 var close:=Button.new();close.text="关闭";buttons.add_child(close);close.pressed.connect(queue_free)
 refresh()
func add_card(id:String):
 message.text=model.add_card(id);refresh()
func remove_unit(index:int):
 if PARTY.character(model.player[index]) and model.player.filter(PARTY.character).size()<=1:
  message.text="至少保留一位角色";return
 model.remove_at(index);refresh()
func move_unit(index:int,offset:int):
 model.move(index,clampi(index+offset,0,model.player.size()-1));refresh()
func refresh():
 for entry in character_items:
  var deployed:bool=model.player.any(func(unit):return PARTY.character(unit) and PARTY.LOADOUT.model_for_unit(unit)==entry.file)
  entry.item.subtitle="已上阵 · 长按装配" if deployed else "点击上阵 · 长按装配"
 for child in lineup.get_children():lineup.remove_child(child);child.queue_free()
 for i in model.player.size():
  var unit:Dictionary=model.player[i]
  var row:=HBoxContainer.new();lineup.add_child(row)
  var title:=Label.new();title.text="%d · %s"%[i+1,unit.name];title.custom_minimum_size.x=145;row.add_child(title)
  for pair in [["↑",func():move_unit(i,-1)],["↓",func():move_unit(i,1)],["收回",func():remove_unit(i)]]:
   var button:=Button.new();button.text=pair[0];button.pressed.connect(pair[1]);row.add_child(button)
  if PARTY.character(unit):
   var equip:=Button.new();equip.text="装配";row.add_child(equip)
   equip.pressed.connect(func():equipment.open_loadout(PARTY.LOADOUT.model_for_unit(unit),unit.name))
  elif unit.cardType=="relic":
   var mode:=Button.new();mode.text="持用" if unit.mode=="held" else "摆放";row.add_child(mode)
   mode.pressed.connect(func():message.text=model.toggle_mode(i);refresh())
func save_formation()->bool:
 Journey.resume()
 var before:Array=Journey.state.battle.player
 Journey.state.battle.player=model.player.duplicate(true)
 if Journey.save():return true
 Journey.state.battle.player=before
 return false
