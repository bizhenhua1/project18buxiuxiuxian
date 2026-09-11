extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.model.phase="prepare";app.model.player.clear()
 for id in ["character_1","character_3","character_7","character_9","character_12","character_15","character_18","character_22"]:app.model.add_card(id)
 app.arena.rebuild();assert(app.arena.equipped_actors.size()==8)
 app.phase="battle";app.arena.battle_mix=1;app.arena.entrance_progress=1
 app.arena.world_anchor=ForestRoute.pose(app.distance,app.branch).position
 for j in 90:app._process(.016);await process_frame
 var renderer=app.arena.scenery.renderer
 renderer.forest_batch.sync(renderer)
 var slots={}
 for actor in renderer.battle_actors:
  if not actor.get("live_companion",false):continue
  var slot:int=actor.live_texture_slot
  assert(not slots.has(slot));slots[slot]=true
  assert(renderer.forest_batch.material.get_shader_parameter("live_ally_%d"%slot)==actor.texture)
  var packed_index:int=renderer.forest_batch.dynamic_indices[actor.id]
  var found=false
  for batch_slot in renderer.forest_batch.dynamic_slots:
   var data=renderer.forest_batch.batch.get_instance_custom_data(batch_slot)
   if int(data.r)==packed_index:
    assert(int(data.a)/64==16+slot);found=true;break
  assert(found)
 assert(slots.size()==7)
 var portraits={}
 for unit in app.model.player:
  var texture=app.arena.art_for(unit)
  assert(texture.resource_path.begins_with("res://assets/character-portraits/"))
  assert(not portraits.has(texture.resource_path));portraits[texture.resource_path]=true
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/roster-battle-fixed.png")
 var positions={}
 for actor in renderer.battle_actors:
  if actor.get("live_companion",false):positions[actor.id]=actor.position
 app.phase="clearing";app.clearing_time=0
 for tick in 20:
  app._process(.016);await process_frame
  for actor in renderer.battle_actors:
   if positions.has(actor.id):assert(actor.position.distance_to(positions[actor.id])<.001)
 app.phase="travel";app.open_kit();app.kit_tab=1;app._refresh_kit();app._update_ui()
 assert(app.kit_items.get_child_count()==24)
 app._process(0)
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/roster-ui.png")
 app.roster_ui.open_loadout("isabella.glb","伊莎贝拉")
 assert(app.roster_ui.slots.size()==6)
 for i in 5:await process_frame
 print("ROSTER_UI_PASS 24 entries, eight distinct model textures and portraits, six equipment slots");quit()
