extends SceneTree
const PARTY=preload("res://scripts/world3d/party.gd")
func _initialize():
 var save={"world":{"map_index":7},"formation":[{"id":"character_0"},{"id":"night-warden"},{"id":"sealed-book","mode":"held"},{"id":"character_1"}]}
 var before:=JSON.stringify(save)
 var units:Array=PARTY.units_from_save(save)
 assert(units.size()==4)
 var book:Dictionary=units.filter(func(unit):return unit.cardId=="sealed-book")[0]
 assert(book.mode=="held","Sorting a spell to the end must not lose the relic's held mode")
 for unit in units:assert(unit.stageSnap==9,"Native team must use the saved adventure progression")
 var reference:=BattleModel.new();reference.player.clear();reference.stage=9
 for id in ["character_0","sealed-book","character_1","night-warden"]:assert(reference.add_card(id).is_empty())
 for i in reference.player.size():
  if reference.player[i].cardId=="sealed-book":reference.toggle_mode(i);break
 for unit in units:
  var match:Dictionary=reference.player.filter(func(other):return other.cardId==unit.cardId)[0]
  assert(unit.maxHp==match.maxHp and unit.atk==match.atk and unit.cd==match.cd)
 assert(PARTY.LOADOUT.model_for_unit(units[0])!=PARTY.LOADOUT.model_for_unit(units[2]))
 assert(JSON.stringify(save)==before,"Reading must not rewrite the save")
 assert(not PARTY.units_from_save({"formation":"invalid"}).is_empty())
 print("WORLD3D_SAVED_PARTY_PASS progression, reordered held relic, roster identity, stats parity, nonmutating read")
 quit()
