extends SceneTree
const UPGRADE=preload("res://scripts/journey/native_save_upgrade.gd")
func _initialize():call_deferred("run")
func run():
 var rules:=BattleRules.new()
 for old in UPGRADE.IDS:
  assert(rules.card(old).is_empty())
  assert(not rules.card(UPGRADE.card_id(old)).is_empty())
 var old_save:=JourneyState.new().to_save()
 old_save.formation=[{"id":UPGRADE.IDS.keys()[0],"mode":""},{"id":UPGRADE.IDS.keys()[1],"mode":"held"}]
 var restored:=JourneyState.new()
 assert(restored.restore(old_save))
 assert(restored.battle.player[0].cardId=="investigator")
 assert(restored.battle.player[1].cardId=="sealed-book" and restored.battle.player[1].mode=="held")
 var baseline:=rules.create_unit("investigator","player")
 var upgraded:=baseline.duplicate(true)
 var old_mods={"realmLayers":100,"realmBreaks":100}
 rules.player_mods(baseline,{})
 rules.player_mods(upgraded,old_mods)
 assert(baseline.atk==upgraded.atk and baseline.maxHp==upgraded.maxHp)
 assert(UPGRADE.migrate_value(old_mods).is_empty())
 var nested=UPGRADE.migrate_value({"formation":old_save.formation,"slots":{UPGRADE.IDS.keys()[1]:Vector2(2,3)}})
 assert(nested.formation[1].id=="sealed-book")
 assert(nested.slots["sealed-book"]==Vector2(2,3))
 assert(StyleLibrary.active)
 for card in rules.cards:
  if not str(card.get("art","")).is_empty():assert(FileAccess.file_exists("res://"+str(card.art).trim_prefix("res://")),card.art)
 print("NATIVE_THEME_PASS catalog, asset references, legacy formation/config migration, removed progression modifiers")
 quit()
