extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,960)
 var app=load("res://scenes/shader_browser.tscn").instantiate();root.add_child(app)
 for i in range(5):await process_frame
 app.playing=false
 for style in [1,2,3]:
  app.scheme.select(style);app.refresh_templates()
  assert(app.templates.item_count==2)
  for preset in range(2):
   app.templates.select(preset);app.apply_preset(preset)
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../art/3d/seer/shader-%d-%d.png"%[style,preset])
 for model in range(1,7):
  app.select_model(model)
  assert(app.materials.size()>0)
  app.retarget.apply(.3)
  for i in range(2):await process_frame
 for kind in range(3):
  app.light_kind.select(kind);app.make_light()
  app.sliders.energy.value=2.5
  await process_frame
 app.select_model(0)
 app.scheme.select(0);app.refresh_templates()
 for i in range(app.materials.size()):
  assert(app.originals[i].mesh.get_surface_override_material(app.originals[i].surface)==app.originals[i].material)
 app.scheme.select(1);app.refresh_templates()
 var arena=BattleArena.new();arena.scene_mode=true;arena.equipment_open=false
 var card=BattleCard.new();card.arena=arena
 assert(card._get_tooltip(Vector2.ZERO)=="")
 arena.equipment_open=true;assert(card._get_tooltip(Vector2.ZERO)!="")
 card.free();arena.free()
 print("SHADER_BROWSER_PASS 7 models, 3 schemes/6 presets, 3 lights, original comparison, hidden tooltip")
 quit()
