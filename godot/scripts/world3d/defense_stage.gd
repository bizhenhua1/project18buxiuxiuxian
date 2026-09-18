extends "res://scripts/world3d/stage.gd"
var stage_light_enabled:=true
var storm_enabled:=true
var character_fill:=.42
var fallback:MultiMeshInstance3D
var corpse_fog
func _init():
 sim=preload("res://scripts/world3d/defense_adapter.gd").new()
func _ready():
 get_tree().set_meta("world3d_theme","forest")
 get_tree().set_meta("world3d_fork_test",0)
 await super()
 frame=composition.frames.battle.duplicate();camera_origin=encounter_anchor
 for i in team.size():team[i].position=slot_position(i);team[i].set_opacity(1)
 fallback=MultiMeshInstance3D.new();add_child(fallback)
 var mesh:=SphereMesh.new();mesh.radius=.035;mesh.height=.07;mesh.radial_segments=6;mesh.rings=3
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mesh.material=mat
 fallback.multimesh=MultiMesh.new();fallback.multimesh.transform_format=MultiMesh.TRANSFORM_3D;fallback.multimesh.use_colors=true;fallback.multimesh.mesh=mesh;fallback.multimesh.instance_count=128;fallback.multimesh.visible_instance_count=0
 corpse_fog=preload("res://scripts/world3d/defeat_clear.gd").new();add_child(corpse_fog);corpse_fog.setup(enemy_pool.size())
func enemy_pool_capacity(kind:int)->int:
 var count:=0
 for i in maxi(50,int(sim.config.total)):
  if int(sim.config.spawn_cycle[i%sim.config.spawn_cycle.size()])==kind:count+=1
 return count
func build_ui():
 super()
 for child in inspection_toggle.get_parent().get_children():
  if child not in [inspection_toggle,playback_button]:child.hide()
 for child in inspection_body.get_children():
  if child not in [label,actions]:child.hide()
 for key in action_buttons:action_buttons[key].hide()
 action_buttons["普通遭遇"].text="开始防守";action_buttons["普通遭遇"].show()
 action_buttons["50 来敌"].show();action_buttons["重新整备"].text="重新开始";action_buttons["重新整备"].show()
 var pulse:=Button.new();pulse.text="迟滞结界";actions.add_child(pulse);pulse.pressed.connect(func():sim.pulse())
 var prefs:=ConfigFile.new()
 if prefs.load("user://defense-presentation.cfg")==OK:
  stage_light_enabled=prefs.get_value("view","stage_light",true);storm_enabled=prefs.get_value("view","storm",true)
  character_fill=clampf(float(prefs.get_value("view","character_fill",.42)),0,.65)
 var light:=CheckButton.new();light.text="舞台补光";light.button_pressed=stage_light_enabled;inspection_body.add_child(light)
 light.toggled.connect(func(v):stage_light_enabled=v;save_preferences())
 var storm:=CheckButton.new();storm.text="StormMissile · 远程特效";storm.button_pressed=storm_enabled;inspection_body.add_child(storm)
 storm.toggled.connect(func(v):storm_enabled=v;save_preferences())
 var fill:=HSlider.new();fill.min_value=0;fill.max_value=.65;fill.step=.01;fill.value=character_fill;fill.tooltip_text="角色独立补光";inspection_body.add_child(fill)
 fill.value_changed.connect(func(v):character_fill=v;save_preferences())
func save_preferences():
 var prefs:=ConfigFile.new();prefs.load("user://defense-presentation.cfg")
 prefs.set_value("view","stage_light",stage_light_enabled);prefs.set_value("view","storm",storm_enabled);prefs.set_value("view","character_fill",character_fill);prefs.save("user://defense-presentation.cfg")
func configure_allies():
 super()
 for i in sim.allies.size():
  var ally:Dictionary=sim.allies[i];var source:Dictionary=units[i]
  ally.range=3.0 if i<3 else 15.0;ally.attack=maxf(14,source.atk)
  ally.cooldown=maxf(.5,source.cd/1000.0);ally.type=mini(i,4)
  if ally.leader:ally.hp=20.0;ally.max_hp=20.0
func start_battle(load_test:bool=true):
 if not ready_stage or phase!="prepare":return
 projectile_view.clear();sim.reset(load_test);configure_allies();pool_ids.clear();step_clock=0
 for slot in enemy_pool:slot.id=-1;slot.actor.hide();slot.actor.trigger("revive")
 sim.begin();phase="battle"
func reset_battle():
 if not can_reset():return
 if corpse_fog!=null:corpse_fog.clear()
 if fallback!=null:fallback.multimesh.visible_instance_count=0
 super()
func _process(delta:float):
 var previous_phase:String=phase
 if ready_stage:
  var lights=preload("res://scripts/battle/team_lighting.gd").profiles()
  for state in lights:
   if not stage_light_enabled:lights[state].road_energy=0.0
   lights[state].ambient=character_fill
  bridge.team_light_override=lights;projectile_view.enabled=storm_enabled
 super(delta)
 if not ready_stage:return
 if previous_phase=="battle" and phase in ["victory","defeat"]:
  # No pending hit belongs to the settled encounter. Release its target
  # references; the original simulation and damage rules remain unchanged.
  sim.shots.clear();sim.effects.clear()
 for ally in sim.allies:
  if ally.leader:ally.hp=sim.life
 if fallback:
  fallback.multimesh.visible_instance_count=0 if storm_enabled else mini(128,sim.projectiles.active.size())
  for i in fallback.multimesh.visible_instance_count:
   var shot:Dictionary=sim.projectiles.active[i]
   fallback.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,world_point(shot.pos)))
   fallback.multimesh.set_instance_color(i,Color("e1a294") if shot.enemy else Color("a1cdd7"))
 label.text="林间防线 · 防线 %d / 20 · 来敌 %d · 击败 %d · 漏过 %d"%[sim.life,sim.active_count(),sim.killed,sim.leaked]
func render_enemies(dt:float):
 super(dt)
 if corpse_fog==null:return
 corpse_fog.clear()
 for unit in sim.enemies:
  if unit.hp>0 or unit.state=="leaked" or not pool_ids.has(unit.id):continue
  var actor=pool_ids[unit.id].actor
  var duration:float=float(actor.library.clips.death.frames-1)/actor.library.clips.death.fps
  var removal_at:float=float(unit.changed)+maxf(5,duration)
  if sim.clock>=removal_at+corpse_fog.DURATION:
   actor.hide();unit.visual_removed=true;continue
  corpse_fog.entries.append({"node":actor,"actor":true,"origin":actor.position,"delay":removal_at,"alpha":1.0,"height":actor.scale.y*.4})
 corpse_fog.age=sim.clock;corpse_fog.advance(0,camera)
