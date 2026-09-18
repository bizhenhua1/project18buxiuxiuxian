extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var s=shell.stage;s.set_process(false);s.begin_tactical()
 var id:int=s.team_slots[1];var a:Dictionary=s.sim.allies[id];a.skill=0
 s.sim.enemies.clear()
 for offset in [Vector3(0,0,-6),Vector3(4,0,-6),Vector3(0,0,-9),Vector3(0,0,-12)]:
  s.sim.spawn_enemy();var e:Dictionary=s.sim.enemies.back();e.pos=a.pos+offset;e.previous_pos=e.pos;e.activate_at=0;e.entry="road";e.entry_phase="advance";e.hp=1000;e.max_hp=1000
 s.sim.enemies[2].hp=0;s.sim.enemies[3].activate_at=s.sim.clock+100
 s.tactical_ui.select(id);s.tactical_ui.preview=true;s._process(0)
 var view=s.tactical_ui.range_view
 assert(view.affected==[s.sim.enemies[0].id],"Only live active enemies in the actual damage range are marked")
 assert(view.rings.multimesh.visible_instance_count==1)
 var mesh=view.floor_view.mesh
 view.sync(a.pos,s.sim.settings.skills[0],true)
 assert(view.floor_view.mesh==mesh,"Static previews must reuse their terrain mesh")
 var vertices:PackedVector3Array=view.wall_view.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 assert(absf(vertices[2].y-vertices[1].y-.65)<.001,"Walls must fade above a 0.65 metre height")
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/tactical-ground-range.png")
 view.sync(a.pos,s.sim.settings.skills[1],true)
 assert(view.affected.size()==1)
 view.sync(a.pos,{},false);assert(not view.visible and view.rings.multimesh.visible_instance_count==0)
 print("TACTICAL_RANGE_VIEW_PASS terrain floor, rising walls, shared hit query, pooled rings and cached geometry")
 quit()
