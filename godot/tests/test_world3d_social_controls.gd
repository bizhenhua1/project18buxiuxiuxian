extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 app.encounters.sequence=[{"kind":"social","event":"merchant"},{"kind":"battle","reward":2}]
 app.encounters.cursor=0;app.encounters.arrived=true;app.encounters.resolved=false;app.encounters.stones=0
 app.phase="event";app._process(0)
 assert(not app.can_reset() and app.action_buttons["重新整备"].disabled)
 assert(app.action_buttons["50 来敌"].disabled)
 app.reset_battle();app.start_battle();app.start_travel()
 assert(app.phase=="event" and not app.encounters.resolved,"Unresolved dialogue must not turn into combat preparation or departure")
 app.encounter_panel.refresh()
 var buttons=app.encounter_panel.choices.get_children()
 assert(buttons.size()==2 and buttons[0].disabled)
 buttons[1].pressed.emit()
 assert(app.encounters.resolved)
 var reward:int=app.encounters.stones
 buttons[1].pressed.emit();assert(app.encounters.stones==reward,"Duplicate click must not duplicate rewards")
 app.encounter_panel.refresh()
 assert(app.encounter_panel.choices.get_child_count()==1)
 app.encounter_panel.choices.get_child(0).pressed.emit()
 assert(app.phase=="travel" and app.encounters.cursor==1,"Completed dialogue must continue to the next event")
 print("WORLD3D_SOCIAL_CONTROLS_PASS blocked combat reset, real dialogue buttons, duplicate reward protection, departure")
 quit()
