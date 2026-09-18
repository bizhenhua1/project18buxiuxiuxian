extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var journey=root.get_node("Journey")
 journey.SAVE="user://native-party-apply-test.json";journey.state=JourneyState.new()
 journey.state.stones=173;assert(journey.save())
 assert(change_scene_to_file("res://scenes/defense_3d.tscn")==OK)
 await scene_changed
 var shell=current_scene
 while not shell.kit:await process_frame
 shell.kit.pressed.emit()
 var editor=shell.get_node("PartyEditor")
 editor.remove_unit(0);editor.add_card("character_0");editor.move_unit(editor.model.player.size()-2,-1)
 var expected:Array=editor.model.player.map(func(unit):return unit.cardId)
 # Trigger the actual save button, including its scene reload signal.
 var apply:Button=editor.get_child(0).get_children().back().get_child(0)
 apply.pressed.emit()
 await scene_changed
 shell=current_scene
 while not shell.kit:await process_frame
 assert(shell.stage.units.map(func(unit):return unit.cardId)==expected,"Saved party was not loaded by the next 3D scene")
 var party=load("res://scripts/world3d/party.gd")
 for i in shell.stage.team.size():
  var slot:int=shell.stage.team_slots[i]
  var expected_model:String=party.LOADOUT.model_for_unit(shell.stage.units[slot])
  assert(shell.stage.team[i].model_key==expected_model)
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(journey.SAVE))
 assert(saved.stones==173)
 journey.state=null;DirAccess.remove_absolute(journey.SAVE)
 print("PARTY_APPLY_PASS actual save button, scene reload, formation order, native model identities and progress preserved")
 quit()
