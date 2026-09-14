extends SceneTree
const LOADOUT=preload("res://scripts/equipment/loadouts.gd")
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 var actor=app.team[0];var saved:=LOADOUT.get_loadout(actor.model_key)
 var expected:=LOADOUT.profile(saved)
 var temporary:Dictionary=saved.duplicate(true)
 var kind:String="sword" if expected=="mage" else "staff"
 for item in LOADOUT.weapons():
  if item.get("kind","")==kind:
   temporary.right=item.file;temporary.left=item.file if LOADOUT.two_handed(item.file) else "";break
 actor.refresh_equipment(temporary)
 assert(actor.profile!=expected,"Fixture must use a different temporary rendered weapon")
 var position:Vector3=actor.position;var camera:Transform3D=app.camera.transform
 app.reset_battle()
 assert(actor.applied_loadout==saved and actor.profile==expected,"Reset must apply saved equipment to the actual model")
 var unit:Dictionary=app.sim.allies[app.team_slots[0]]
 assert(unit.melee==(expected not in ["mage","unarmed"]))
 assert(actor.position==position and app.camera.transform==camera,"Equipment synchronization must preserve framing and position")
 var attachments:Array=actor.attachments.duplicate()
 app.reset_battle()
 assert(actor.attachments==attachments,"Unchanged loadout must reuse attachments")
 assert(LOADOUT.get_loadout(actor.model_key)==saved,"Test must not write player equipment")
 print("WORLD3D_EQUIPMENT_SYNC_PASS saved equipment, render/combat profile agreement, unchanged resource reuse, no save writes")
 quit()
