extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1600,960);Engine.max_fps=60
 var app=load("res://scenes/vfx_preview.tscn").instantiate();root.add_child(app)
 for i in 10:await process_frame
 assert(app.asset_tabs.current_tab==1)
 assert(app.filtered.size()==132)
 var files:Dictionary={}
 for e in app.filtered:
  assert(e.behavior=="projectile")
  assert(not files.has(e.file));files[e.file]=true
 app.linked_only.button_pressed=true;app.refresh_assets()
 assert(not app.filtered.is_empty())
 for e in app.filtered:
  assert(not app.linked_effect(e.get("muzzle_id","")).is_empty())
  assert(not app.linked_effect(e.get("impact_id","")).is_empty())
 print("PROJECTILE_TAB_PASS unique=132 paired=",app.filtered.size())
 app.linked_only.button_pressed=false;app.refresh_assets()
 assert(app.entries.size()==1447)
 assert(app.entries.filter(func(e):return e.playable).size()==1440)
 assert(app.swept_hit(Vector3.ZERO,Vector3(0,0,-12),Vector3(0,0,-6),.3))
 assert(not app.swept_hit(Vector3.ZERO,Vector3(0,0,-12),Vector3(2,0,-6),.3))
 var picks=["SwordSlashThinWhite","SwordSlashThickWhite","FireballSoftMissileFire","ExplosionFireballSoftFire"]
 for name in picks:
  var found=app.entries.filter(func(e):return e.name==name)
  assert(not found.is_empty())
  app.select_entry(found[0])
  var expected="sword" if name.begins_with("Sword") else "staff" if name.contains("Missile") else ""
  if not expected.is_empty():assert(app.weapon_panel.items[app.weapon_panel.weapon].kind==expected)
  var captured:=false
  var seen:Dictionary={}
  for frame in 220:
   await process_frame
   for fx in app.fx_nodes:seen[fx.get_meta("entry_id")]=true
   if not captured and app.emitted:
    for j in 5:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://../tempassets/work/library-"+name+".png");captured=true
   if app.action_phase=="idle":break
  assert(captured)
  if name.contains("Missile"):
   assert(app.hit_count==1)
   assert(not app.current_entry.get("muzzle_id","").is_empty())
   assert(not app.matching_impact().is_empty())
   assert(seen.has(app.current_entry.muzzle_id))
   assert(seen.has(app.matching_impact().id))
  print("EFFECT_CHECK ",name)
 app.target_slots.select(0);var target_id:int=app.target_slots.get_selected_id();app.arrange()
 assert(app.target_slots.get_selected_id()==target_id)
 app.color_filter.select(1);app.refresh_assets()
 var color=app.color_filter.get_item_metadata(1)
 for entry in app.filtered:assert(entry.color==color)
 app.color_filter.select(0)
 app.mode_pick.select(1);app.arrange()
 var native=app.entries.filter(func(e):return e.name=="FireballSoftMissileFire")[0]
 app.select_entry(native)
 for frame in 45:await process_frame
 assert(not app.traditional() and app.game_preview.visible==false)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/library-independent.png")
 app.stop_action()
 app.mode_pick.select(0);app.arrange()
 assert(app.traditional() and app.game_preview.visible)
 var origin:Vector3=app.game_actor.body.position
 for i in 3:await process_frame
 assert(app.game_actor.body.position.is_equal_approx(origin))
 assert(app.game_actor.get_viewport()!=app.viewport)
 app.search.text="Fireball";app.refresh_assets()
 assert(app.filtered.size()>6)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/library-formation.png")
 print("EPIC_LIBRARY_PASS catalog/color filters, weapon binding, target retention, hit-on-arrival, traditional/native switching, stable formation")
 quit()
