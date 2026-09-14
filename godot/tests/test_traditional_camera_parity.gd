extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1600,1043)
 var editor=load("res://scenes/traditional_camera_editor.tscn").instantiate();root.add_child(editor)
 for i in range(900):
  await process_frame
  if editor.ready_for_edit:break
 editor.frame_key="travel";editor.refresh();editor.set_process(false)
 var app=editor.app;var arena=app.arena;var r=arena.scenery.renderer
 var hero=arena.cards.filter(func(c):return c.side=="player" and c.unit.get("cardId","")=="investigator")[0]
 var before:Vector2=hero.position/arena.size
 var before_size:Vector2=hero.size/arena.size
 var camera:Vector2=r.camera_world
 # Same scene, same physical actor, same 16:9 content area. Switch only the
 # editor/runtime projection path; window/UI dimensions are deliberately different.
 app.remove_meta("traditional_editor");r.editor_camera={}
 app.live_template.data=editor.data.duplicate(true);app.live_template.current=editor.data.frames.travel.duplicate(true);app.live_template.clock=-100
 app.size=Vector2(1600,170+1552.0/(float(editor.viewport.size.x)/editor.viewport.size.y))
 app.presentation_camera.reset(camera,r.heading,0)
 app.presentation_camera.reference_origin=ForestRoute.pose(app.distance,app.branch).position
 app.presentation_camera.reference_ready=true
 app.paused=true;app._process(0)
 var after:Vector2=hero.position/arena.size
 var after_size:Vector2=hero.size/arena.size
 print("PARITY position=",before," / ",after," size=",before_size," / ",after_size)
 assert(before.distance_to(after)<.002,"Editor/runtime travel framing differs")
 assert(absf(before_size.y-after_size.y)<.02,"Editor/runtime actor scale differs")
 print("TRADITIONAL_PARITY_PASS normalized travel projection")
 quit()
