extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var journey=root.get_node("Journey")
 journey.SAVE="user://native-party-editor-test.json"
 journey.state=JourneyState.new();journey.state.stones=137
 var editor=load("res://scripts/world3d/party_editor.gd").new();root.add_child(editor)
 editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 editor.setup(journey.state.battle.player)
 var units_before:String=JSON.stringify(journey.state.battle.player)
 editor.move_unit(0,1)
 assert(JSON.stringify(journey.state.battle.player)==units_before,"Editing mutated live party before saving")
 assert(editor.save_formation())
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(journey.SAVE))
 assert(saved.stones==137 and saved.formation[1].id=="watchful-clock")
 var restored:Array=preload("res://scripts/world3d/party.gd").units_from_save(saved)
 assert(restored.size()==editor.model.player.size())
 for i in restored.size():assert(restored[i].cardId==editor.model.player[i].cardId)
 while editor.model.player.size()>1:
  var remove_index:int=-1
  for i in editor.model.player.size():
   if not preload("res://scripts/world3d/party.gd").character(editor.model.player[i]):remove_index=i;break
  editor.remove_unit(remove_index if remove_index>=0 else editor.model.player.size()-1)
 editor.remove_unit(0);assert(editor.model.player.size()==1,"Removed final character")
 editor.add_card("character_0")
 assert(editor.model.player.size()==2)
 var file:String=preload("res://scripts/equipment/loadouts.gd").model_for_unit(editor.model.player.back())
 editor.equipment.open_loadout(file,"装配验证")
 assert(editor.equipment.slots.size()==6)
 editor.equipment.window.queue_free()
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-party-editor.png")
 journey.state=null;DirAccess.remove_absolute(journey.SAVE)
 print("PARTY_EDITOR_PASS isolated edits, order, save and restore, last character guard, roster add, six equipment slots")
 quit()
