class_name FairytaleCatalog
extends RefCounted
## Only asset-verified bundles are published; incomplete production files stay outside the menu.
static var scenes:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/fairytale_scenes.json"))
static var world_override:=""
static func entry(key:String)->Dictionary:
 for scene in scenes:
  if scene.id==key:return scene
 return {}
static func has_scene(key:String)->bool:return not entry(key).is_empty()
static func asset(key:String,file:String)->String:return "res://assets/fairytales/"+key+"/"+file
static func roster(key:String)->Array:
 var result:Array=[]
 if has_scene(key):
  for i in 3:result.append("tale_"+key+"_"+str(i))
 return result
static func lead_art(key:String)->String:return asset(key,"enemy-0.png").trim_prefix("res://")
static func append_cards(cards:Array)->void:
 var base:Dictionary={}
 for card in cards:
  if card.id=="huoli":base=card;break
 if base.is_empty():return
 for scene in scenes:
  for i in 3:
   var card:Dictionary=base.duplicate(true)
   card.id=roster(scene.id)[i];card.name=scene.enemies[i]
   card.art=asset(scene.id,"enemy-%d.png"%i).trim_prefix("res://")
   card.fairytale_enemy=true;card.portrait_kind="object";card.cardType="beast"
   card.hp=[120,85,65][i];card.atk=[12,10,8][i];card.cd=[1900,1500,1250][i]
   card.ranged=i==2;card.atkType="ranged" if i==2 else "melee"
   card.dmgType="spell" if i==2 else "phys";card.skill="none"
   card.skillText=scene.name+"的异变居民";cards.append(card)
