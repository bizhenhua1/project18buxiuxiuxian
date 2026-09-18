extends RefCounted
const LOADOUT=preload("res://scripts/equipment/loadouts.gd")
static func read_units()->Array:
 var path:="user://journey-v1.json"
 var tree=Engine.get_main_loop()
 if tree is SceneTree:
  var journey=tree.root.get_node_or_null("Journey")
  if journey!=null:path=journey.SAVE
 var data=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
 return units_from_save(data)
static func units_from_save(data:Variant)->Array:
 var model:=BattleModel.new()
 var raw:Variant=data.get("formation",[]) if data is Dictionary else []
 var formation:Array=raw if raw is Array else []
 if not formation.is_empty():
  model.player.clear();model.stage=2
  var world:Variant=data.get("world",{})
  if world is Dictionary and (world.get("map_index",0) is int or world.get("map_index",0) is float):model.stage=clampi(int(world.get("map_index",0))+2,2,31)
  for entry in formation:
   if not entry is Dictionary:continue
   var previous:Array=model.player.map(func(unit):return unit.uid)
   var error:=model.add_card(preload("res://scripts/journey/native_save_upgrade.gd").card_id(str(entry.get("id",""))))
   if error.is_empty() and entry.get("mode","")=="held":
    for i in model.player.size():
     if model.player[i].uid not in previous:model.toggle_mode(i);break
 if model.player.is_empty():model.default_lineup()
 if not model.player.any(func(u):return character(u)):
  model.player.append(model.rules.create_unit("investigator","player",model.player.size(),model.stage))
 return model.player.duplicate(true)
static func character(unit:Dictionary)->bool:
 return unit.get("cardType","")=="char" or unit.get("portrait_kind","")=="person"
static func slot(slots:Array,index:int,count:int,is_character:bool)->Dictionary:
 var coordinate:float=float(slots.size()-1)*.5 if count==1 else float(index)*(slots.size()-1)/maxi(1,count-1) if count!=slots.size() else float(index)
 var low:=clampi(int(floor(coordinate)),0,slots.size()-1);var high:=mini(low+1,slots.size()-1)
 var key:="character" if is_character else "prop"
 var result:Dictionary=slots[low][key].duplicate()
 for field in ["x","depth","height","clearance"]:result[field]=lerpf(float(slots[low][key].get(field,0)),float(slots[high][key].get(field,0)),coordinate-low)
 return result
