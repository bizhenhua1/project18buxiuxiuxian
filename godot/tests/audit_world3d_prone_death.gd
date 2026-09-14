extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage._process(0)
 for member in stage.team:member.hide()
 for item in stage.props:item.node.hide()
 var actor=stage.enemy_pool[0].actor
 actor.position=stage.world_point(Vector3(0,0,2));actor.scale=Vector3.ONE*.9;actor.show()
 actor.portrait_presenter.set_enabled(true);actor.portrait_presenter.configure_enemy(stage.camera,stage.bridge.focal());actor.portrait_presenter.sync()
 var clips:Array=actor.catalog.clips
 var ids:Array=["4_Anim_ARPGSamurai_Hit_knockdown_Death","5_ARPG_Warrior_Anim_rig_Hit_knockdown_Death","4_Anim_ARPGSamurai_Death_Airborne_End"]
 var report:Array=[]
 for id in ids:
  var entry:Dictionary=clips.filter(func(c):return c.id==id)[0]
  actor.library.clips.death=entry;actor.cache.erase("death");actor.play("death")
  var duration:float=float(entry.frames-1)/entry.fps
  for time in [0.0,duration]:
   actor.retarget.apply(time)
   var heights:Dictionary={}
   for name in ["頭","腰","足首.L","足首.R"]:
    var bone:int=actor.rig.find_bone(name)
    if bone>=0:heights[name]=(actor.rig.global_transform*actor.rig.get_bone_global_pose(bone)).origin.y-actor.global_position.y
   report.append({"clip":id,"time":time,"height_above_anchor":heights})
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../tempassets/work/prone-death-"+str(ids.find(id))+ ("-start" if time==0 else "-end")+".png")
 FileAccess.open("res://../tempassets/work/prone-death-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PRONE_DEATH_AUDIT ",JSON.stringify(report))
 quit()
