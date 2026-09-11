extends AspectRatioContainer
var app:Control
var view:SubViewport
var ready_preview:=false
var context:="battle"
var material_parameters:Dictionary={}
var profiles:Dictionary={}
var model_file:=""
func setup(file:String):
 ratio=16.0/9.0;size_flags_vertical=Control.SIZE_EXPAND_FILL;size_flags_horizontal=Control.SIZE_EXPAND_FILL
 view=SubViewport.new();view.size=Vector2i(1280,720);view.own_world_3d=true;view.world_2d=World2D.new();view.gui_disable_input=true
 var host=SubViewportContainer.new();host.stretch=true;add_child(host);host.add_child(view)
 var session=get_node("/root/Journey");session.resume()
 var old_state=session.state;var old_save=session.SAVE;var old_active=session.expedition_active;var old_fighting=session.fighting
 session.state=JourneyState.new();session.SAVE="user://shader-light-preview.json";session.expedition_active=true
 if not old_state.battle.player.is_empty():session.state.battle.player=old_state.battle.player.duplicate(true)
 StyleLibrary.active=true
 var zone=session.state.zones[0];zone.route_kind="straight";zone.route_profile="short_battle";zone.theme="forest";zone.battle_choice=true;session.state.pending=zone.id
 app=load("res://scenes/expedition_route.tscn").instantiate();view.add_child(app);app.set_process(false);app.set_process_input(false)
 app.set_anchors_preset(Control.PRESET_TOP_LEFT);app.size=Vector2(1328,890);app.arena.scene_mode=true;app.distance=app.stops()[0];app.prepare_encounter();app.phase="battle";app.arena.battle_mix=1;app.arena.entrance_progress=1;app.arena.scene_enemy_sources.clear()
 var pose=ForestRoute.pose(app.distance,app.branch);app.arena.world_anchor=pose.position;app.arena.world_facing=pose.heading
 for i in 100:app._process(.02)
 app.paused=true;app.model.paused=true;app.process_mode=Node.PROCESS_MODE_DISABLED
 session.state=old_state;session.SAVE=old_save;session.expedition_active=old_active;session.fighting=old_fighting
 for child in app.get_children():
  if child is CanvasItem and child!=app.arena:child.hide()
 ready_preview=true;replace_model(file);render()
func replace_model(file:String):
 if not ready_preview or file==model_file:return
 model_file=file
 var actor=app.arena.seer
 if not actor:return
 var next=preload("res://scripts/battle/equipped_actor.gd").new();next.model_key=file;next.model_scene=load("res://assets/characters3d/"+file);next.ally=true
 app.arena.add_child(next)
 var unit=app.model.player.filter(func(u):return u.uid==actor.uid)[0];next.bind_unit(unit);next.body.rotation=actor.body.rotation
 app.arena.equipped_actors[actor.uid]=next;app.arena.seer=next;next.retarget.apply(0);actor.queue_free()
func render():
 if not ready_preview:return
 var arena=app.arena;var r=arena.scenery.renderer
 app.phase="battle" if context=="battle" else "travel"
 arena.battle_mix=1.0 if context=="battle" else 0.0;arena.entrance_progress=1
 arena.enemies_visible=context=="battle";r.presentation_blend=arena.battle_mix
 arena.position=Vector2.ZERO;arena.scale=Vector2.ONE;arena.size=Vector2(view.size);arena.scenery.size=arena.size
 arena.scenery.renderer.team_light_override=profiles
 arena.scenery.renderer.set_battle_camera(arena.battle_mix)
 var frame:Dictionary=app.live_template.data.get("frames",{}).get(context,{"lateral":0,"forward":0,"height":58,"horizon":.29 if context=="battle" else .48,"lens":.92 if context=="battle" else 1.0,"yaw":0})
 var anchor:Vector2=arena.world_anchor;var heading:float=arena.world_facing
 r.editor_camera=frame
 var pos=anchor+Vector2(cos(heading),-sin(heading))*float(frame.lateral)+Vector2(sin(heading),cos(heading))*float(frame.forward)
 arena.scenery.sync(pos,heading+deg_to_rad(frame.yaw),0,0,app.branch,false,false,app.distance)
 # Let the game's own formation solver reach its saved targets, with time frozen afterwards.
 arena.formation_motion.units.clear()
 for i in 2:arena.layout_scene_units(.05)
 if context=="battle":
  for state in arena.formation_motion.units.values():state.position=state.target;state.velocity=Vector2.ZERO
 else:
  for i in 100:arena.layout_scene_units(.05)
 for actor in arena.equipped_actors.values():
  if actor==arena.seer:
   var slot:Dictionary=arena.world_slots.get(actor.uid,{})
   actor.body.rotation.y=PI+(.22 if slot.get("right_facing",false) else -.22) if context=="battle" else PI-.12
  actor.scene_light_tint=r.environment_light_tint()
  actor.team_light_override=profiles;actor.update_team_light(app.phase,0)
  if not material_parameters.is_empty():apply_material(actor.body)
  actor.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 arena._process(0);arena.scenery.sync_projection();r.queue_redraw()
func apply_material(node:Node):
 if node.get_script()==preload("res://scripts/battle/character_ink_material.gd"):
  node.set_meta("preview_parameters",material_parameters);node.refresh(material_parameters)
 for child in node.get_children():apply_material(child)

func _process(_dt:float):
 if ready_preview and app.arena.size!=Vector2(view.size):render()
