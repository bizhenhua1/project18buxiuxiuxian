extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1500,900)
 Engine.max_fps=60
 var app=load("res://scenes/combat_vfx_lab.tscn").instantiate();root.add_child(app)
 for frame in 6:await process_frame
 for kind in ["sword","sword","sword","sword","fire"]:
  app.start_action(kind)
  assert(app.active_kind==kind)
  var captured:=false
  for frame in 360:
   await process_frame
   if not captured and ((kind=="sword" and app.action_time/app.action_duration>.36) or (kind=="fire" and app.effects.flight_age>.4)):
    await RenderingServer.frame_post_draw
    app.viewport.get_texture().get_image().save_png("res://../tempassets/work/vfx-"+kind+".png");captured=true
   if app.active_kind.is_empty() and not app.effects.flight and app.effects.impact_age>1:break
  assert(captured)
  assert(app.active_kind.is_empty() and not app.effects.flight)
  assert(app.model.position.is_equal_approx(Vector3.ZERO))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/vfx-lab-ui.png")
 print("VFX_SAMPLE_PASS sword returns home; fire reaches target; snapshots rendered")
 quit()
