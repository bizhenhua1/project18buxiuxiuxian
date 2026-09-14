extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false)
 var path:="user://world3d-camera-test.json"
 stage.live_camera.active_path=path
 var original:Dictionary=stage.composition.duplicate(true)
 var changed:Dictionary=original.duplicate(true)
 changed.frames.battle.lens=float(original.frames.battle.lens)*.8
 changed.frames.travel.lens=float(original.frames.travel.lens)*.9
 var positions:Array=stage.team.map(func(actor):return actor.position)
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(changed))
 stage._process(.05)
 assert(float(stage.frame.lens)>float(changed.frames.battle.lens),"Edit must interpolate instead of snapping")
 for i in 120:stage._process(.05)
 assert(absf(float(stage.frame.lens)-float(changed.frames.battle.lens))<.0001)
 assert(stage.composition.battle_slots==original.battle_slots,"Camera edit must not rewrite standing positions")
 for i in stage.team.size():assert(stage.team[i].position==positions[i])
 # Saved angles can differ by a whole turn while describing the same view.
 for state in ["travel","event","battle"]:changed.frames[state].yaw=float(original.frames[state].yaw)+360.0
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(changed))
 stage.live_camera.clock=1
 var before_yaw:float=stage.frame.yaw
 stage._process(.05)
 assert(absf(wrapf(float(stage.frame.yaw)-before_yaw,-180.0,180.0))<.0001,"Equivalent saved yaw must not rotate the view")
 for i in 120:stage._process(.05)
 assert(not stage.live_camera_blending,"Equivalent full-turn angles must finish blending")
 for state in ["travel","event","battle"]:assert(stage.composition.frames[state]==stage.live_camera.data.frames[state],"Settled camera data must exactly match the saved snapshot")
 var accepted:Dictionary=stage.live_camera.data.duplicate(true)
 FileAccess.open(path,FileAccess.WRITE).store_string("{incomplete")
 stage.live_camera.clock=1;stage._process(.05)
 assert(stage.live_camera.data==accepted,"Incomplete save must retain the last valid snapshot")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("WORLD3D_LIVE_CAMERA_PASS smooth valid edits, world positions retained, invalid snapshot ignored; production file untouched")
 quit()
