extends RefCounted
const SAVE="user://character-loadouts.cfg"
static var revision:=0
static func weapons() -> Array:
 var all:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/catalog.json"))
 return all.filter(func(w):return w.get("kind","") not in ["bow","arrow"])
static func item(file:String) -> Dictionary:
 for w in weapons():
  if w.file==file:return w
 return {}
static func two_handed(file:String) -> bool:
 return item(file).get("kind","") in ["spear","halberd","staff"] or file in ["axe_B.gltf","hammer_B.gltf","sword_E.gltf"]
static func get_loadout(key:String) -> Dictionary:
 var config=ConfigFile.new();config.load(SAVE)
 var result={}
 for slot in ["left","right","head","body","jewel","feet"]:result[slot]=str(config.get_value(key,slot,"sword_B.gltf" if key=="isabella.glb" and slot=="right" else ""))
 return result
static func equip(key:String,slot:String,file:String) -> String:
 if slot not in ["left","right"]:return "该位置暂未开放装备"
 if not file.is_empty() and item(file).is_empty():return "不可用的武器"
 var data=get_loadout(key);var other:String="left" if slot=="right" else "right"
 if two_handed(str(data[slot])) or two_handed(str(data[other])):data.left="";data.right=""
 if two_handed(file):data.left=file;data.right=file
 else:
  if item(file).get("kind","")=="shield" and item(data[other]).get("kind","")=="shield":return "不能同时装备两面盾牌"
  data[slot]=file
 var config=ConfigFile.new();config.load(SAVE)
 for k in data:config.set_value(key,k,data[k])
 if config.save(SAVE)!=OK:return "装备保存失败"
 revision+=1;return ""
static func profile(data:Dictionary) -> String:
 var primary:String=data.right if not str(data.right).is_empty() and item(data.right).get("kind","")!="shield" else data.left
 var kind:String=item(primary).get("kind","")
 if kind in ["staff","wand"]:return "mage"
 if kind in ["spear","halberd"]:return "spear"
 if kind in ["hammer","axe","fistweapon"]:return "warrior"
 if kind in ["sword","dagger"]:return "sword_shield" if item(data.left).get("kind","")=="shield" or item(data.right).get("kind","")=="shield" else "sword_dual" if not str(data.left).is_empty() and not str(data.right).is_empty() and not two_handed(primary) else "sword"
 return "unarmed"

static func model_for_unit(unit:Dictionary) -> String:
 if unit.has("model_file"):return unit.model_file
 if unit.get("cardId",unit.get("id",""))=="daotong":
  var config=ConfigFile.new();config.load("user://world-hero.cfg")
  var roster:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_roster.json"))
  return roster[clampi(int(config.get_value("hero","index",0)),0,roster.size()-1)].file
 return "isabella.glb"
