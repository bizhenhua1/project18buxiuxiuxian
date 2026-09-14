extends SceneTree
const PARTY=preload("res://scripts/world3d/party.gd")
func _initialize():call_deferred("run")
func run():
 var slots:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/traditional_camera_active.json")).battle_slots
 for count in [2,8,10]:
  for character in [false,true]:
   var key:="character" if character else "prop"
   assert(PARTY.slot(slots,0,count,character).x==slots[0][key].x)
   assert(PARTY.slot(slots,count-1,count,character).x==slots[-1][key].x)
 var model:=BattleModel.new();model.player.clear()
 for id in ["character_0","character_1","sealed-book"]:assert(model.add_card(id).is_empty())
 assert(PARTY.LOADOUT.model_for_unit(model.player[0])!=PARTY.LOADOUT.model_for_unit(model.player[1]),"Distinct roster cards must retain distinct model files")
 assert(PARTY.character(model.player[0]) and not PARTY.character(model.player[2]))
 var actor=load("res://scripts/world3d/allied_actor.gd").new();root.add_child(actor);actor.setup("isabella.glb");actor.refresh_equipment()
 assert(not actor.attacks.is_empty())
 for i in actor.attacks.size()*2:
  actor.trigger("attack")
  assert(actor.library.clips.attack.id==actor.attacks[i%actor.attacks.size()].id,"Weapon combos must cycle without skipping")
 actor.trigger("death");actor.advance(10,Vector3.ZERO);assert(actor.dead and actor.visible,"Corpse remains after death clip")
 actor.trigger("revive");assert(not actor.dead and actor.combo==0)
 print("WORLD3D_PARTY_PASS roster identity, mixed slots, 10-card extents, equipped combos, corpse/revive")
 quit()
