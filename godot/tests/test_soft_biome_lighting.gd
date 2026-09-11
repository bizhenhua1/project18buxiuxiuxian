extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);set_meta("tour_biome","whale")
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.phase="choose";app.choose(-1);app.distance=app.stops()[0];app._sync_event_previews();app.prepare_encounter();app.phase="battle";app.arena.battle_mix=1;app.arena.entrance_progress=1
 app.arena.enemies_visible=true
 app.arena.world_anchor=ForestRoute.pose(app.distance,app.branch).position
 for i in 90:app._process(.016);await process_frame
 var r=app.arena.scenery.renderer
 assert(r.enemy_light_strength()==0)
 var enemy=r.enemy_light_tint();var team=r.environment_light_tint()
 assert(enemy.r>enemy.b and team.r>team.b)
 assert((team.r-team.b)<(enemy.r-enemy.b))
 assert(enemy.g>.7 and enemy.b>.7)
 assert(app.arena.seer.scene_light_tint==team)
 assert(app.arena.enemy_actor.team_key.light_color==Color("bedae0")*enemy)
 if app.discovery_actor:assert(app.discovery_actor.team_key.light_color==app.arena.enemy_actor.team_key.light_color)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/whale-soft-light.png")
 print("SOFT_BIOME_LIGHT_PASS continuous enemy color, no combat floodlight, weaker team tint")
 quit()
