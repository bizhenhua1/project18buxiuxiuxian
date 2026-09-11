extends SceneTree
const L=preload("res://scripts/equipment/loadouts.gd")
func _initialize():call_deferred("run")
func run():
 var key="__equipment_test__"
 for item in L.weapons():assert(item.get("kind","") not in ["bow","arrow"])
 assert(L.equip(key,"left","").is_empty());assert(L.equip(key,"right","").is_empty())
 assert(L.equip(key,"right","spear_A.gltf").is_empty())
 assert(L.get_loadout(key).left=="spear_A.gltf" and L.get_loadout(key).right=="spear_A.gltf")
 assert(L.equip(key,"left","shield_A.gltf").is_empty());assert(L.get_loadout(key).right=="")
 assert(not L.equip(key,"right","shield_B.gltf").is_empty())
 assert(L.equip(key,"right","sword_B.gltf").is_empty());assert(L.profile(L.get_loadout(key))=="sword_shield")
 assert(L.equip(key,"left","dagger_A.gltf").is_empty());assert(L.profile(L.get_loadout(key))=="sword_dual")
 var actor=load("res://scripts/battle/equipped_actor.gd").new();actor.model_key=key;actor.model_scene=load("res://assets/characters3d/isabella.glb");root.add_child(actor)
 var unit={"uid":10,"hp":100,"cd":1500}
 for pair in [["staff_A.gltf","mage"],["spear_A.gltf","spear"],["hammer_B.gltf","warrior"],["sword_B.gltf","sword"]]:
  L.equip(key,"left","");L.equip(key,"right",pair[0]);actor.refresh_equipment();actor.bind_unit(unit)
  assert(actor.profile==pair[1]);actor.trigger("shot");actor.advance(.2,"battle",false,1,true)
  assert(actor.attacks.size()>=3 and actor.attachments.size()>0)
 var config=ConfigFile.new();config.load(L.SAVE);config.erase_section(key);config.save(L.SAVE)
 var rules=BattleRules.new();assert(rules.cards.filter(func(c):return c.cardType=="char").size()==25)
 var model=BattleModel.new();model.player.clear();assert(model.add_card("daotong").is_empty());assert(model.add_card("character_3").is_empty());assert(model.add_card("character_7").is_empty());assert(not model.add_card("character_7").is_empty())
 print("LOADOUT_PASS 24 characters, equip/save, no bows, two-hand occupancy, no double shield, dual wield, four animation profiles")
 quit()
