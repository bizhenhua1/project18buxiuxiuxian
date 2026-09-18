extends "res://scripts/world3d/stage.gd"
const WAVE_TOTAL=60
var corpse_smoke
var skill_view
var tactical_ui
var souls:Array=[]
var roster:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/tactical_roster.json"))
func _init():sim=preload("res://scripts/tactical/simulation.gd").new()
func configure_allies():
 if corpse_smoke!=null:corpse_smoke.clear()
 super()
 sim.configure_tactics(team_slots)
 for i in team.size():
  var a:Dictionary=sim.allies[team_slots[i]]
  sim.roles.configure(a,roster[i])
  a.attack_durations=team[i].attacks.map(func(c):return float(c.frames-1)/float(c.fps))
  var clip:Dictionary=team[i].library.clips.death
  sim.allies[team_slots[i]].death_hold=maxf(float(sim.settings.death_hold_seconds),float(clip.frames-1)/float(clip.fps))
func _ready():
 await super()
 skill_view=preload("res://scripts/tactical/skill_view.gd").new();add_child(skill_view);skill_view.setup(self)
 corpse_smoke=preload("res://scripts/tactical/corpse_smoke.gd").new();add_child(corpse_smoke);corpse_smoke.setup(enemy_pool.size())
 inspection_panel.hide();encounter_panel.hide()
 for item in props:item.node.hide()
 tactical_ui=preload("res://scripts/tactical/interface.gd").new();tactical_ui.stage=self
 var layer:=CanvasLayer.new();layer.layer=10;add_child(layer);layer.add_child(tactical_ui)
 for actor in team:
  var orb:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.07;mesh.height=.14;orb.mesh=mesh
  var color:=Color(preload("res://scripts/battle/health_transformation.gd").settings().get("color","70ecdfff"))
  var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color;mat.emission_enabled=true;mat.emission=color;orb.material_override=mat;orb.hide();add_child(orb);souls.append(orb)
 DisplayServer.window_set_title("雾林 · 战术防守")
func begin_tactical():
 if not ready_stage:return
 phase="prepare";reset_battle()
 sim.config=sim.config.duplicate(true);sim.config.total=WAVE_TOTAL;sim.config.cap=30;sim.stress=false;sim.flashes.clear();sim.begin()
 phase="battle";hold_restart_camera=true;transition_frame.clear();frame=composition.frames.battle.duplicate();preview.hide()
 for i in team.size():team[i].position=world_point(sim.allies[team_slots[i]].pos)+Vector3.UP*float(profiles[team_slots[i]].clearance)/20
 if tactical_ui:tactical_ui.close_menu()
func _process(dt:float):
 var scale_time:float=float(sim.settings.slow_scale) if tactical_ui and tactical_ui.selected>=0 and phase=="battle" else 1.0
 super(dt*scale_time)
 if not ready_stage or not tactical_ui:return
 encounter_panel.hide();inspection_panel.hide()
 for i in team.size():
  var unit:Dictionary=sim.allies[team_slots[i]];var actor=team[i]
  souls[i].visible=unit.death_phase=="light"
  if unit.death_phase=="light":
   souls[i].position=world_point(unit.pos)+Vector3.UP*.7;actor.set_opacity(0)
  elif unit.death_phase=="respawn":actor.position=world_point(unit.home)+Vector3.UP*float(profiles[team_slots[i]].clearance)/20;actor.set_opacity(1)
 skill_view.sync()
 tactical_ui.refresh()
func sync_party_health(dt:float,instant:bool=false):
 var settings:Dictionary=preload("res://scripts/battle/health_transformation.gd").settings()
 for i in health_views.size():
  var a:Dictionary=sim.allies[team_slots[i]];var visual_hp:float=a.hp;var values:Dictionary=settings
  if a.get("death_phase","")=="fallen":
   var hold:float=a.get("death_hold",sim.settings.death_hold_seconds)
   var dissolve:float=smoothstep(hold-.5,hold,sim.clock-a.death_at)
   if dissolve>0:
    values=settings.duplicate();values.display="transform";visual_hp=a.max_hp*(1-dissolve)
  health_views[i].sync(dt,visual_hp,float(a.max_hp),values,instant)

func aim_yaw(unit:Dictionary)->float:
 var origin:Vector3=world_point(unit.pos)
 var forward:Vector3=-camera.global_basis.z;forward.y=0
 var destination:Vector3=camera.global_position+forward.normalized()*60
 var target_id:int=unit.get("aim_id",-1)
 if target_id>=0 and target_id<sim.enemies.size():
  var target:Dictionary=sim.enemies[target_id]
  if target.hp>0 and not target.resolved and unit.pos.distance_to(target.pos)<=unit.range+1:
   destination=world_point(target.pos)
 if unit.has("aim_point") and sim.clock<float(unit.get("aim_until",0)):destination=world_point(unit.aim_point)
 var direction:Vector3=destination-origin
 return atan2(direction.x,direction.z)
func sync_ally_facing(dt:float):
 if phase not in ["prepare","battle"]:return
 for i in team.size():
  var unit:Dictionary=sim.allies[team_slots[i]]
  if team[i].dead or unit.state in ["rising","returning"]:continue
  team[i].rotation.y=lerp_angle(team[i].rotation.y,aim_yaw(unit),1.0 if dt<=0 else 1-exp(-8*dt))
func render_enemies(dt:float):
 for e in sim.enemies:
  if e.hp>0:e.visual_removed=false
 super(dt)
 for e in sim.enemies:
  var target:int=e.get("aim_id",-1)
  if e.hp<=0 or e.resolved or target<0 or not pool_ids.has(e.id) or not sim.alive(sim.allies[target]):continue
  var direction:Vector3=world_point(sim.allies[target].pos)-world_point(e.pos)
  var actor=pool_ids[e.id].actor
  actor.rotation.y=lerp_angle(actor.rotation.y,atan2(direction.x,direction.z),1.0 if dt<=0 else 1-exp(-8*dt))

 if corpse_smoke!=null:corpse_smoke.sync(self)

func read_battle_units()->Array:
 var result:Array=[]
 for i in roster.size():
  var r:Dictionary=roster[i]
  result.append({"uid":i,"cardId":"investigator" if i==0 else "tactical_"+r.key,"cardType":"char","model_file":r.model,"maxHp":r.hp,"atk":r.attack,"cd":r.cooldown*1000})
 return result
func prepare_actor_equipment(actor,slot_index:int,refresh:bool=false):
 var data:Dictionary=roster[slot_index].loadout
 if not refresh or actor.applied_loadout!=data:actor.refresh_equipment(data)

func enemy_pool_capacity(kind:int)->int:
 # Corpses stay until the encounter ends: capacity must cover lifetime spawns,
 # not just simultaneous living enemies. Prewarm before combat, never mid-wave.
 var count:=0
 for i in WAVE_TOTAL:
  if int(sim.config.spawn_cycle[i%sim.config.spawn_cycle.size()])==kind:count+=1
 return maxi(count,super(kind))
