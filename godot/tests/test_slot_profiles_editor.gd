extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1600,1043)
 var editor=load("res://scenes/traditional_camera_editor.tscn").instantiate();editor.publish_path="user://slots-test-published.json";root.add_child(editor)
 for i in range(900):
  await process_frame
  if editor.ready_for_edit:break
 assert(editor.ready_for_edit);assert(editor.data.battle_slots.size()==8)
 editor.inputs.height.value+=2
 var cameras:Dictionary=editor.data.frames.duplicate(true)
 for i in range(8):
  editor.unit_index=i;editor.refresh_unit()
  editor.kind_picker.item_selected.emit(1)
  editor.unit_inputs.height.value=10+i
  var prop:Dictionary=editor.data.battle_slots[i].prop.duplicate(true)
  editor.kind_picker.item_selected.emit(0)
  editor.unit_inputs.height.value=38+i
  editor.unit_inputs.depth.value=32+i
  assert(editor.data.battle_slots[i].prop==prop,"Mode switching overwrote prop values")
  assert(editor.app.model.player[i].cardId=="daotong")
  assert(editor.app.arena.world_slots[editor.app.model.player[i].uid].height==38+i)
 assert(editor.data.frames==cameras,"Slot editing changed camera")
 editor.name_field.text="__slots_test__";editor.save_template()
 var saved=JSON.parse_string(FileAccess.get_file_as_string(editor.publish_path))
 assert(editor.valid(saved));assert(editor.SlotProfiles.valid(saved.battle_slots))
 assert(saved.frames.battle.height==cameras.battle.height)
 for i in range(editor.templates.item_count):
  if editor.templates.get_item_text(i)=="__slots_test__.json":editor.templates.select(i)
 editor.data.battle_slots[0].character.height=90;editor.load_selected()
 assert(editor.data.battle_slots[0].character.height==38)
 var controller=preload("res://scripts/traditional/live_template.gd").new();controller.data=saved
 for count in [1,3,8,10]:
  var party:Array=[]
  for i in range(count):party.append({"uid":i,"cardId":"test", "cardType":"char" if i%2==0 else "prop"})
  controller.prepare_slots(party)
  assert(controller.slot_targets.size()==count)
  for i in range(count):assert(controller.slot_targets[i].height>=38 if i%2==0 else controller.slot_targets[i].height<20)
 DirAccess.remove_absolute(editor.DIRECTORY+"/__slots_test__.json");DirAccess.remove_absolute(editor.publish_path)
 editor.unit_index=3;editor.refresh_unit()
 for i in range(4):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/slots-editor.png")
 print("SLOT_PROFILES_PASS 8 x 2 modes, 3D preview, independent save/load, 1/3/8/10 runtime units")
 quit()
