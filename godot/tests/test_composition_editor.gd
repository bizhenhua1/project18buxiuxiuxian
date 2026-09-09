extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1600,1000)
 var app=load("res://scenes/native3d_editor.tscn").instantiate();root.add_child(app)
 for i in range(4):await process_frame
 assert(app.valid(app.data))
 app.inputs.cy.value=2.15
 assert(is_equal_approx(app.world.camera.position.y,2.15))
 app.unit_index=5;app.refresh();app.inputs.uz.value=-12
 assert(is_equal_approx(app.world.enemies[1].position.z,-12))
 app.name_field.text="__editor_roundtrip_test";app.save_template()
 app.inputs.cy.value=3
 for i in range(app.templates.item_count):
  if app.templates.get_item_text(i)=="__editor_roundtrip_test.json":app.templates.select(i)
 app.load_selected();assert(is_equal_approx(app.inputs.cy.value,2.15))
 assert(is_equal_approx(app.data.frames.battle.units[5].position[2],-12))
 DirAccess.remove_absolute(app.DIRECTORY.path_join("__editor_roundtrip_test.json"))
 app.data=app.defaults();app.frame_key="battle";app.unit_index=0;app.units.select(0);app.refresh()
 app.name_field.text="参考初始构图"
 if not FileAccess.file_exists(app.DIRECTORY.path_join("参考初始构图.json")):app.save_template()
 app.start_preview("travel","event")
 for i in range(85):app._process(.025)
 assert(app.preview_time<0)
 app.frame_key="battle";app.refresh()
 for i in range(3):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/composition-editor.png")
 print("COMPOSITION_EDITOR_PASS edits, three-state template roundtrip, preview")
 quit()
