extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../tempassets/work/fairytales"))
 assert(not FairytaleCatalog.scenes.is_empty())
 for spec in FairytaleCatalog.scenes:
  var key:String=spec.id
  for file in ["ground.png","cliff.png","structure.png","prop-0.png","prop-1.png","prop-2.png","prop-3.png","enemy-0.png","enemy-1.png","enemy-2.png"]:
   assert(ResourceLoader.exists(FairytaleCatalog.asset(key,file)))
  set_meta("tour_biome",key);set_meta("tour_event_placement","before")
  var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
  app.set_process(false);app.arena.set_process(false)
  assert(str(app.world.plan.regions[0].space.key)==key)
  assert(app.world.sprites.size()>30)
  var corridor_count:=0
  var dressing_textures:Dictionary={}
  for sprite in app.world.sprites:
   if not sprite.get("actor",false):assert(sprite.texture.resource_path.contains("fairytales"))
   if sprite.texture.resource_path.contains("/corridor-"):corridor_count+=1
   if sprite.texture.resource_path.contains("/dressing/"):dressing_textures[sprite.texture.resource_path]=true
  assert(corridor_count>0,"Generated corridor art was not placed: "+key)
  if FileAccess.file_exists(FairytaleCatalog.asset(key,"dressing.json")):
   assert(dressing_textures.size()>=6,"Too few distinct dressing assets placed: "+key)
  for i in 30:app._process(1.0/60)
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/fairytales/"+key+"-travel.png")
  # Progress normally into the next reachable event; no invented camera/teleport fixture.
  for i in 1200:
   app._process(1.0/60)
   if app.phase=="choose":app.choose(-1)
   if app.phase in ["sighting","encounter"]:break
  app.start_battle()
  for i in 90:app._process(1.0/60)
  assert(app.phase=="battle")
  assert(app.model.enemy.size()==3)
  for unit in app.model.enemy:
   assert(unit.get("fairytale_enemy",false));assert(unit.art.contains(key))
   assert(not unit.get("health_transformation_active",false))
  assert(app.discovery_actor==null)
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/fairytales/"+key+"-battle.png")
  root.remove_child(app);app.queue_free();await process_frame
  FairytaleCatalog.world_override=key
  var journey:=JourneyState.new()
  var world: IslandModel=journey.world
  FairytaleCatalog.world_override=""
  assert(world.blocked.size()==3)
  for marker in world.blocked.values():assert(marker.art==FairytaleCatalog.lead_art(key))
  journey.pending=journey.zones[0].id
  assert(journey.prepare_battle())
  for unit in journey.battle.enemy:assert(unit.art.contains(key))
  for cell in world.cells:
   assert(cell.theme==key);assert(cell.base.contains(key))
   if cell.feat!=null:assert(ResourceLoader.exists("res://"+cell.feat.src))
  var view:=IslandView3D.new();root.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  world.preview_all=true;world.zoom=1.5;world.zoom_goal=1.5
  view.setup(world,IslandAssets.new())
  for i in 6:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/fairytales/"+key+"-world.png")
  root.remove_child(view);view.queue_free();await process_frame
  print("FAIRYTALE_PASS ",key)
 print("FAIRYTALES_PASS count=",FairytaleCatalog.scenes.size())
 var hub=load("res://scenes/fairytale_hub.tscn").instantiate();root.add_child(hub)
 for i in 4:await process_frame
 assert(hub.grid.get_child_count()==FairytaleCatalog.scenes.size())
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/fairytales/catalog.png")
 quit()
