extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage._process(0);stage.set_inspection_expanded(false)
 var view=stage.health_views[0];var actor=stage.team[0]
 var camera:Transform3D=stage.camera.transform;var anchor:Vector3=actor.position
 var settings={"display":"transform","mode":0,"opacity":.4,"energy":1.5,"color":"70ecdfff","material_style":1}
 view.sync(1,50,100,settings)
 assert(view.active and is_equal_approx(view.progress,.5))
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-health-ghost.png")
 view.sync(.2,100,100,settings);assert(view.progress==0,"Healing must reverse conversion")
 settings.mode=1;settings.head_scales={actor.model_key:1.15}
 view.sync(.3,25,100,settings)
 assert(view.active and not view.skeletons.is_empty() and is_equal_approx(view.skull_scale,1.15))
 for mesh in view.skeletons:assert(mesh.visible and mesh.skin!=null)
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-health-skeleton.png")
 actor.portrait_presenter.set_enabled(false);view.sync(.2,50,100,settings)
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 actor.portrait_presenter.set_enabled(true)
 # Exercise real reset/victory boundaries without writing editor preferences.
 var config=load("res://scripts/battle/health_transformation.gd")
 var saved:Dictionary=config.cached;var saved_poll:int=config.next_poll
 config.cached=settings;config.next_poll=Time.get_ticks_msec()+60000
 view.sync(1,0,100,settings)
 view.sync(.05,100,100,settings)
 assert(view.progress>0 and view.progress<1,"Battle healing must remain gradual")
 stage.sim.allies[stage.team_slots[0]].hp=0
 stage.sync_party_health(1)
 assert(view.progress==1)
 stage.reset_battle()
 assert(view.progress==0,"Reprepare must clear conversion before another frame")
 stage.sim.allies[stage.team_slots[0]].hp=0
 stage.sync_party_health(1)
 stage.phase="battle";stage.sim.status="victory"
 stage._process(0)
 assert(stage.phase=="victory" and view.progress==0,"Victory must restore appearance immediately")
 for material in view.skeleton_materials:assert(material.get_shader_parameter("progress")==0)
 for material in view.atmosphere:assert(material.get_shader_parameter("health_ghost_progress")==0)
 config.cached=saved;config.next_poll=saved_poll
 view.sync(.2,100,100,{"display":"ui"})
 assert(not view.active and actor.position==anchor and stage.camera.transform==camera)
 for mesh in view.skeletons:assert(not mesh.visible)
 for i in actor.portrait_presenter.surfaces.size():assert(actor.portrait_presenter.surfaces[i].material.shader==view.originals[i].replacement)
 print("WORLD3D_HEALTH_VIEW_PASS ghost, gradual healing, immediate reset/victory, both projections, fixed camera/root")
 quit()
