extends SceneTree
const GAME=preload("res://scripts/battle/character_ink_material.gd")
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,960)
 var paths=[GAME.SAVE,"user://shader-browser-templates.cfg"]
 var backups={}
 for path in paths:
  if FileAccess.file_exists(path):backups[path]=FileAccess.get_file_as_bytes(path)
 var app=load("res://scenes/shader_browser.tscn").instantiate();root.add_child(app)
 for i in 5:await process_frame
 app.playing=false
 var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;app.drag_character(down)
 var motion=InputEventMouseMotion.new();motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.relative=Vector2(100,0);app.drag_character(motion)
 var drag_ok=is_equal_approx(app.sliders.yaw.value,70.0) and is_equal_approx(app.body.rotation.y,deg_to_rad(70.0))
 app.scheme.select(2);app.refresh_templates();app.sliders.threshold.value=.63;app.sliders.width.value=.008
 app.light_kind.select(2);app.make_light();app.sliders.energy.value=3.1
 app.team_inputs.energy.value=.7;app.switch_lighting("battle");app.team_inputs.energy.value=3.7
 app.template_name.text="测试保存模板";var expected=app.parameters();app.save_template()
 var saved=ConfigFile.new();saved.load(app.TEMPLATE_SAVE)
 var saved_ok=same(saved.get_value("templates","entries")["测试保存模板"],expected)
 app.saved_templates=saved.get_value("templates","entries")
 app.sliders.threshold.value=.2
 for i in app.templates.item_count:
  if app.templates.get_item_metadata(i).get("saved","")=="测试保存模板":app.apply_preset(i);break
 var restored_ok=same(app.parameters(),expected)
 var model=Node3D.new();var mesh=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.material_override=null
 mesh.mesh.material=StandardMaterial3D.new();model.add_child(mesh);root.add_child(model);GAME.apply(model)
 app.apply_to_game()
 var controller=model.get_child(1);controller._process(.6)
 var game_ok=is_equal_approx(mesh.get_active_material(0).get_shader_parameter("threshold"),.63)
 game_ok=game_ok and is_equal_approx(mesh.get_active_material(0).next_pass.get_shader_parameter("width"),.008)
 game_ok=game_ok and is_equal_approx(GAME.settings().team_lights.battle.energy,3.7) and is_equal_approx(GAME.settings().team_lights.travel.energy,.7)
 var disk=ConfigFile.new();disk.load(GAME.SAVE);game_ok=game_ok and not disk.get_value("material","parameters").has("light_type")
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/shader-controls.png")
 for path in paths:
  if backups.has(path):var f=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(backups[path]);f.close()
  elif FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 GAME.next_poll=0
 print([drag_ok,saved_ok,restored_ok,game_ok]);assert(drag_ok);assert(saved_ok);assert(restored_ok);assert(game_ok)
 print("SHADER_CONTROLS_PASS drag, template save/restore, live game material update, independent travel/battle team lights persisted")
 quit()

func same(a:Dictionary,b:Dictionary) -> bool:
 for key in b:
  if b[key] is Dictionary:
   if not same(a[key],b[key]):return false
  elif b[key] is float:
   if not is_equal_approx(float(a[key]),b[key]):return false
  elif a[key]!=b[key]:return false
 return true
