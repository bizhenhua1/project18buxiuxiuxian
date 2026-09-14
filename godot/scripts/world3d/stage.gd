extends Node3D
const P=preload("res://scripts/world3d/projection.gd")
const ACTOR=preload("res://scripts/world3d/actor.gd")
var projectile_view
var forest_background
var formation_scale_pending:=false
var area_view
var party_lighting
var actor_atmosphere=preload("res://scripts/world3d/actor_atmosphere.gd").new()
var prop_atmosphere=preload("res://scripts/world3d/prop_atmosphere.gd").new()
var atmosphere_mode:=false
var outline_lod=preload("res://scripts/world3d/outline_lod.gd").new()
var outline_lod_enabled:=true
var portrait_mode:=false
var projection_toggle:CheckButton
var profiling:=false
var profile_usec:Dictionary={}
var encounters=preload("res://scripts/world3d/encounters.gd").new()
var encounter_panel
var enemy_health_overlay
var health_views:Array=[]
var defeat_clear
var comparison_panel
var wave_error:=""
var route_segment=preload("res://scripts/world3d/route_segment.gd").new()
var route_number:=1
var pending_world:SegmentWorld
var planned_successor
var stream_extensions:=0
var environment_3d:Environment
const THEMES=preload("res://scripts/world3d/themes.gd")
var theme_key:="connected"
var theme_picker:OptionButton
var ground_contact_toggle:CheckButton
var vfx_budget_picker:OptionButton
var camera:Camera3D
var scenery
var world:SegmentWorld
var bridge:SegmentRenderer
var composition:Dictionary
var live_camera=preload("res://scripts/traditional/live_template.gd").new()
var live_camera_revision:=""
var live_camera_blending:=false
var sim=preload("res://scripts/world3d/combat_sim.gd").new()
var team:Array=[]
const PARTY=preload("res://scripts/world3d/party.gd")
const CHARACTER_FRAME=preload("res://scripts/world3d/character_framing.gd")
const TRAVEL_RIG=preload("res://scripts/traditional/travel_rig.gd")
var units:Array=[]
var profiles:Array=[]
var team_slots:Array=[]
var props:Array=[]
var first_leg:=true
var fork_test:int=0
var leg_walk_distance:=0.0
var enemy_pool:Array=[]
var pool_ids:Dictionary={}
var phase:="loading"
var ready_stage:=false
var distance:=0.0
var branch:=0
var next_event:=0.0
var encounter_anchor:=Vector2.ZERO
var camera_origin:=Vector2.ZERO
var camera_heading:=0.0
var travel_camera_offset:=Vector2.ZERO
var travel_camera_age:=0.0
var travel_camera_frame:Dictionary={}
const TRAVEL_CAMERA_SECONDS:=.9
var frame:Dictionary
var clock:=0.0
var step_clock:=0.0
var transition:=0.0
var transition_start:=Vector2.ZERO
var transition_velocity:=Vector2.ZERO
var camera_brake=preload("res://scripts/world3d/camera_brake.gd").new()
const STOP_CAMERA_SECONDS:=.8
var transition_frame:Dictionary={}
var battle_camera_clock:=0.0
const BATTLE_CAMERA_SECONDS:=.6
var hero_start:=Vector3.ZERO
var label:Label
var inspection_panel:PanelContainer
var inspection_body:VBoxContainer
var inspection_toggle:Button
var playback_paused:=false
var playback_button:Button
func set_playback_paused(value:bool):
 playback_paused=value
 playback_button.set_pressed_no_signal(value)
 playback_button.text="继续播放" if value else "暂停画面"
 encounter_panel.visible=false if value else phase in ["event","fork","victory","defeat"]
func set_inspection_expanded(expanded:bool):
 inspection_body.visible=expanded
 inspection_toggle.text="收起验证面板" if expanded else "展开验证面板"
 inspection_toggle.set_pressed_no_signal(expanded)
 get_tree().set_meta("world3d_inspection_expanded",expanded)
 inspection_panel.reset_size()
var actions:HBoxContainer
var action_buttons:Dictionary={}
var relic_reverse:=true
func toggle_relic_face():
 if not ready_stage:return
 relic_reverse=not relic_reverse
 for i in props.size():
  var item:Dictionary=props[i]
  if not item.get("two_faces",false):continue
  var texture:Texture2D=load("res://assets/style2/watch-reverse.png" if relic_reverse else "res://assets/style2/watch-front.png")
  prop_atmosphere.set_texture(i,texture)
  item.node.pixel_size=float(profiles[item.slot].height)/20/texture.get_height()
  item.node.offset.y=texture.get_height()*.5
var fork_buttons:Dictionary={}
var fork_controls:HBoxContainer
var fork_ui_state:=Vector2i(-1,-1)
var hold_restart_camera:=false
var has_prepared:=false
var debug:Label

var highlight_time:=0.0
var preview
var preview_age:=0.0
var preview_target:=Vector3.ZERO
var preview_route
var preview_branch:=0
var preview_station:=0.0
var preview_stop_station:=0.0
func _ready():
 sim.skill_world=Callable(self,"world_point")
 sim.emission_origin=Callable(self,"emission_origin")
 DisplayServer.window_set_title("雾林 · 3D迁移工程验证")
 ForestRoute.reset_frame();ForestRoute.configure(false)
 composition=JSON.parse_string(FileAccess.get_file_as_string("res://data/traditional_camera_active.json"));frame=composition.frames.battle.duplicate()
 theme_key=str(get_tree().get_meta("world3d_theme","connected"))
 if not get_tree().has_meta("world3d_theme"):
  for argument in OS.get_cmdline_user_args():
   if argument.begins_with("--theme="):theme_key=argument.trim_prefix("--theme=")
 if theme_key not in THEMES.KEYS:theme_key="connected"
 var initial_exits:=2;var layout_seed:=1842
 fork_test=int(get_tree().get_meta("world3d_fork_test",0))
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--initial-exits="):initial_exits=3 if argument.get_slice("=",1)=="3" else 2
  if argument.begins_with("--layout-seed="):layout_seed=int(argument.get_slice("=",1))
 if fork_test in [2,3]:initial_exits=fork_test
 var plan:RoutePlan=THEMES.plan(theme_key,initial_exits,layout_seed)
 # An explicit formal-route fixture allows independent renderer comparisons.
 # No production save is read or rewritten by this override.
 if get_tree().has_meta("world3d_route_fixture"):
  plan=LocalRouteSpec.plan(get_tree().get_meta("world3d_route_fixture"))
 route_segment.exits=plan.exits
 world=SegmentWorld.new(ForestArt.new(),plan)
 route_segment.seed_value=world.seed_value;route_segment.theme=theme_key
 bridge=SegmentRenderer.new();bridge.world=world;bridge.hide();add_child(bridge);bridge.environment=world.environment();bridge.lantern_enabled=true
 camera=Camera3D.new();add_child(camera);camera.current=true
 forest_background=preload("res://scripts/world3d/forest_background.gd").new();camera.add_child(forest_background)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("101923") if world.camera_region.space.key==&"forest" else world.camera_region.space.top_color
 environment_3d=env.environment
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("98afbf");env.environment.ambient_light_energy=.28;add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,-30,0);sun.light_color=Color("9eb6ca");sun.light_energy=.8
 # Party actors already receive the saved portrait key/rim rig on dedicated
 # layers. The scene sun would add an extra light absent from the reference.
 sun.light_cull_mask=1;add_child(sun)
 scenery=preload("res://scripts/world3d/scenery.gd").new()
 scenery.bounded_ground=bool(get_tree().get_meta("world3d_bounded_ground",scenery.bounded_ground))
 add_child(scenery);scenery.populate(world,route_segment)
 build_ui()
 units=PARTY.read_units()
 for i in units.size():profiles.append(PARTY.slot(composition.battle_slots,i,units.size(),PARTY.character(units[i])))
 for i in units.size():
  if PARTY.character(units[i]):team_slots.append(i)
 # The selected protagonist travels; array order must not change saved formation slots.
 for i in team_slots.size():
  if units[team_slots[i]].cardId=="investigator":
   var leader=team_slots.pop_at(i);team_slots.push_front(leader);break
 for slot_index in team_slots:
  var actor=preload("res://scripts/world3d/allied_actor.gd").new();add_child(actor)
  actor.setup(PARTY.LOADOUT.model_for_unit(units[slot_index]));actor.rotation.y=PI;actor.scale=Vector3.ONE*CHARACTER_FRAME.scale_for_slot(float(profiles[slot_index].height));team.append(actor)
  actor.refresh_equipment()
  await get_tree().process_frame
 for slot_index in units.size():
  if slot_index in team_slots:continue
  var prop:=Sprite3D.new();prop.texture=load("res://assets/style2/watch-reverse.png" if units[slot_index].cardId=="watchful-clock" else StyleLibrary.card_path(units[slot_index].cardId));prop.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;prop.transparent=true;prop.shaded=true
  var spec:Dictionary=profiles[slot_index]
  prop.pixel_size=spec.height/20/prop.texture.get_height();prop.offset.y=prop.texture.get_height()*.5;add_child(prop)
  props.append({"node":prop,"slot":slot_index,"two_faces":units[slot_index].cardId=="watchful-clock","bob":float(preload("res://scripts/battle/asset_spatial_marks.gd").prop_mark(units[slot_index]).bob),"bob_phase":float(units[slot_index].get("uid",slot_index))})
 prop_atmosphere.setup(props,profiles)
 for kind in 5:
  for n in [13,12,10,3,12][kind]:
   var actor=ACTOR.new();actor.retarget=preload("res://scripts/defense/defense_retarget.gd").new();add_child(actor);actor.setup(sim.config.enemies[kind].model);actor.hide()
   enemy_pool.append({"actor":actor,"kind":kind,"id":-1,"last":Vector3.ZERO,"state":""})
   await get_tree().process_frame
 preview=ACTOR.new();preview.retarget=preload("res://scripts/defense/defense_retarget.gd").new();add_child(preview);preview.setup("composer.glb");preview.hide();preview.scale=Vector3.ONE*(38.0/52.0)
 projectile_view=preload("res://scripts/world3d/projectile_view.gd").new();add_child(projectile_view);projectile_view.setup(self)
 if "--prewarm-vfx" in OS.get_cmdline_user_args():await projectile_view.prewarm()
 area_view=preload("res://scripts/world3d/area_view.gd").new();add_child(area_view)
 party_lighting=preload("res://scripts/world3d/party_lighting.gd").new();add_child(party_lighting);party_lighting.setup(team)
 defeat_clear.setup(enemy_pool.size()+team.size()+props.size())
 ready_stage=true;theme_picker.disabled=false;phase="prepare";reset_battle()
 var atmosphere_actors:Array=team+[preview]
 for slot in enemy_pool:atmosphere_actors.append(slot.actor)
 actor_atmosphere.setup(atmosphere_actors)
 for actor in team:
  var view=preload("res://scripts/world3d/health_view.gd").new();view.setup(actor,actor_atmosphere);health_views.append(view)
 outline_lod.setup(atmosphere_actors)
 if fork_test in [2,3]:
  distance=route_segment.junction_s-TravelPace.RUN*2.9
  camera_origin=route_segment.point(distance,0);frame=composition.frames.travel.duplicate()
  team[0].position=travel_destination(distance)
  for i in range(1,team.size()):team[i].set_opacity(0)
  for item in props:item.node.modulate.a=0
  start_travel()
 print("WORLD3D_STAGE_READY original sprites=",world.sprites.size()," imported cutouts=",scenery.imported_count," pooled enemies=",enemy_pool.size())
func build_ui():
 var canvas:=CanvasLayer.new();add_child(canvas)
 enemy_health_overlay=preload("res://scripts/world3d/enemy_health_overlay.gd").new();canvas.add_child(enemy_health_overlay)
 defeat_clear=preload("res://scripts/world3d/defeat_clear.gd").new();add_child(defeat_clear)
 encounter_panel=preload("res://scripts/world3d/encounter_panel.gd").new();canvas.add_child(encounter_panel);encounter_panel.setup(self);encounter_panel.hide()
 var panel:=PanelContainer.new();panel.position=Vector2(16,16);canvas.add_child(panel)
 inspection_panel=panel
 var wrapper:=VBoxContainer.new();panel.add_child(wrapper)
 inspection_toggle=Button.new();inspection_toggle.toggle_mode=true
 inspection_toggle.tooltip_text="只收起验证工具，不改变镜头、战斗和事件选项。"
 var toolbar:=HBoxContainer.new();wrapper.add_child(toolbar);toolbar.add_child(inspection_toggle)
 playback_button=Button.new();playback_button.text="暂停画面";playback_button.toggle_mode=true;toolbar.add_child(playback_button)
 playback_button.tooltip_text="冻结自动行进、战斗、镜头和动画；再次点击继续。验证面板仍可手动操作。"
 playback_button.toggled.connect(set_playback_paused)
 var comparison_button:=Button.new();comparison_button.text="构图对照";toolbar.add_child(comparison_button)
 var comparison_layer:=CanvasLayer.new();comparison_layer.layer=5;add_child(comparison_layer)
 comparison_panel=preload("res://scripts/world3d/comparison_panel.gd").new();comparison_layer.add_child(comparison_panel);comparison_panel.setup(self)
 comparison_button.pressed.connect(comparison_panel.open)
 for count in [2,3,0]:
  var test_button:=Button.new();test_button.text={2:"二岔测试",3:"三岔测试",0:"普通流程"}[count]
  toolbar.add_child(test_button)
  test_button.pressed.connect(func():
   if not ready_stage:return
   get_tree().set_meta("world3d_fork_test",count);get_tree().set_meta("world3d_theme",theme_key)
   get_tree().change_scene_to_file(str(get_meta("presentation_scene","res://scenes/world3d_stage.tscn"))))
 var column:=VBoxContainer.new();wrapper.add_child(column);inspection_body=column
 inspection_toggle.toggled.connect(set_inspection_expanded)
 set_inspection_expanded(bool(get_tree().get_meta("world3d_inspection_expanded",true)))
 theme_picker=OptionButton.new();theme_picker.disabled=true
 for name in THEMES.LABELS:theme_picker.add_item(name)
 theme_picker.select(THEMES.KEYS.find(theme_key));column.add_child(theme_picker)
 theme_picker.item_selected.connect(func(index):
  if not ready_stage:return
  theme_picker.disabled=true
  get_tree().set_meta("world3d_theme",THEMES.KEYS[index]);get_tree().change_scene_to_file(str(get_meta("presentation_scene","res://scenes/world3d_stage.tscn"))))
 label=Label.new();label.text="3D 迁移 · 正在预热原有资产";column.add_child(label)
 actions=HBoxContainer.new();column.add_child(actions)
 for item in [["开始行进",func():start_travel()],["50 来敌",func():start_battle()],["爆炸 AOE",func():cast_test(false)],["向前贯穿",func():cast_test(true)],["持续区域",func():cast_zone()],["继续前进",func():start_travel()],["重新整备",func():reset_battle()]]:
  var button:=Button.new();button.text=item[0];button.pressed.connect(item[1]);actions.add_child(button)
  action_buttons[item[0]]=button
 var normal_battle:=Button.new();normal_battle.text="普通遭遇";normal_battle.pressed.connect(func():start_battle(false));actions.add_child(normal_battle);actions.move_child(normal_battle,1);action_buttons["普通遭遇"]=normal_battle
 fork_controls=HBoxContainer.new();column.add_child(fork_controls)
 for direction in [-1,2,1]:
  var button:=Button.new();button.text={-1:"选择左路",2:"选择直路",1:"选择右路"}[direction];button.pressed.connect(func():choose_branch(direction));fork_controls.add_child(button);fork_buttons[direction]=button
 sync_fork_buttons()
 debug=Label.new();debug.text="共用一个 3D 场景与镜头 · 原撒布坐标 · 工程验证，尚未完成正式迁移";column.add_child(debug)
 var face_button:=Button.new();face_button.text="道具 · 正反";column.add_child(face_button)
 face_button.pressed.connect(toggle_relic_face);action_buttons["道具 · 正反"]=face_button
 projection_toggle=CheckButton.new();projection_toggle.text="传统角色构图（试验）";column.add_child(projection_toggle)
 projection_toggle.toggled.connect(func(value):portrait_mode=value)
 var atmosphere_toggle:=CheckButton.new();atmosphere_toggle.text="角色环境着色（试验）";column.add_child(atmosphere_toggle)
 atmosphere_toggle.set_pressed_no_signal(atmosphere_mode)
 atmosphere_toggle.toggled.connect(func(value):atmosphere_mode=value)
 vfx_budget_picker=OptionButton.new()
 vfx_budget_picker.add_item("特效：原包完整档（重开对比）")
 vfx_budget_picker.add_item("特效：普通攻击预算（重开对比）")
 vfx_budget_picker.tooltip_text="普通档减少装饰粒子与外围光晕；技能计算不变。切换会重新开始当前主题。"
 vfx_budget_picker.select(1 if bool(get_tree().get_meta("world3d_ordinary_vfx_budget","--ordinary-vfx-budget" in OS.get_cmdline_user_args())) else 0)
 column.add_child(vfx_budget_picker)
 vfx_budget_picker.item_selected.connect(func(index):
  if not ready_stage:return
  vfx_budget_picker.disabled=true
  get_tree().set_meta("world3d_ordinary_vfx_budget",index==1);get_tree().set_meta("world3d_theme",theme_key)
  get_tree().change_scene_to_file(str(get_meta("presentation_scene","res://scenes/world3d_stage.tscn"))))
 ground_contact_toggle=CheckButton.new();ground_contact_toggle.text="精细贴地（重开测试）"
 ground_contact_toggle.tooltip_text="对水晶类贴地底部使用更精细的网格；切换会重新开始当前主题测试。"
 ground_contact_toggle.set_pressed_no_signal(scenery.bounded_ground);column.add_child(ground_contact_toggle)
 ground_contact_toggle.toggled.connect(func(value):
  if not ready_stage:return
  ground_contact_toggle.disabled=true;theme_picker.disabled=true
  get_tree().set_meta("world3d_bounded_ground",value);get_tree().set_meta("world3d_theme",theme_key)
  get_tree().change_scene_to_file(str(get_meta("presentation_scene","res://scenes/world3d_stage.tscn"))))
func sync_fork_buttons():
 var state:=Vector2i(1 if phase=="fork" else 0,route_segment.exits)
 if state==fork_ui_state:return
 fork_ui_state=state;fork_controls.visible=phase=="fork"
 for direction in fork_buttons:
  var available:bool=route_segment.valid_exit(direction)
  fork_buttons[direction].visible=available
  fork_buttons[direction].disabled=phase!="fork" or not available
func configure_allies():
 # Resolve the saved equipment once before creating matching combat behavior.
 # Never rebuild weapon/animation resources in the per-frame battle loop.
 for actor in team:actor.refresh_equipment_if_changed()
 sim.allies.clear()
 for i in units.size():
  var profile:Dictionary=profiles[i];var source:Dictionary=units[i]
  var action_profile:String=team[team_slots.find(i)].profile if i in team_slots else "mage"
  sim.allies.append({"id":i,"leader":i==team_slots[0],"pos":Vector3(profile.x/8,0,8.5-(profile.depth-31)/8),"hp":float(source.maxHp),"max_hp":float(source.maxHp),"melee":action_profile not in ["mage","unarmed"],"range":17.0 if action_profile in ["mage","unarmed"] else 3.0,"attack":float(source.atk),"cooldown":maxf(.4,source.cd/1000.0),"next":0.0,"state":"idle","changed":0.0,"type":mini(i,4),"boss":false})
  if i in team_slots:
   var recovery:Dictionary=team[team_slots.find(i)].library.clips.rise
   sim.allies.back().revive_duration=float(recovery.frames-1)/recovery.fps
func position_on_route(s:float,offset:float=0)->Vector3:
 var p:=route_segment.point(s,branch,offset);return P.point(p,ForestEcology.height_at(p))
func travel_destination(s:float)->Vector3:
 var size:Vector2=get_viewport().get_visible_rect().size
 var offset:Vector2=TRAVEL_RIG.offset(size.x,TRAVEL_RIG.reference_focal(size))
 var pose:Dictionary=route_segment.pose(s,branch)
 var p:Vector2=pose.position+offset.rotated(-float(pose.heading))
 return P.point(p,ForestEcology.height_at(p))
func world_point(local:Vector3)->Vector3:
 var h:float=route_segment.pose(distance,branch).heading
 var p:Vector2=encounter_anchor+Vector2(local.x*8,31+(8.5-local.z)*8).rotated(-h)
 return P.point(p,ForestEcology.height_at(p)+local.y*20)
func slot_position(i:int)->Vector3:
 var slot:Dictionary=profiles[team_slots[i]]
 var h:float=route_segment.pose(distance,branch).heading
 var p:Vector2=encounter_anchor+Vector2(slot.x,slot.depth).rotated(-h)
 return P.point(p,ForestEcology.height_at(p)+slot.clearance)
func source_actor(id:int,enemy:bool):
 if enemy:return pool_ids[id].actor if pool_ids.has(id) else null
 var index:int=team_slots.find(id)
 return team[index] if index>=0 else null
func local_point(point:Vector3)->Vector3:
 var h:float=route_segment.pose(distance,branch).heading
 var route:=Vector2(point.x,-point.z)*20
 var p:Vector2=(route-encounter_anchor).rotated(h)
 return Vector3(p.x/8,point.y-ForestEcology.height_at(route)/20,8.5-(p.y-31)/8)
func emission_origin(source:Dictionary,enemy:bool)->Vector3:
 var actor=source_actor(source.id,enemy)
 if actor==null:return preload("res://scripts/world3d/combat_body.gd").center(source)
 var bone:int=actor.rig.find_bone("手首.R")
 if bone<0:return preload("res://scripts/world3d/combat_body.gd").center(source)
 var hand:Vector3=(actor.rig.global_transform*actor.rig.get_bone_global_pose(bone)).origin
 # Fixed-step simulation may have advanced beyond the rendered actor position.
 hand+=world_point(source.pos)-actor.global_position
 if not enemy:
  hand.y+=float(profiles[source.id].clearance)/20
 return local_point(hand)
func reset_battle():
 if not can_reset():return
 if defeat_clear!=null:defeat_clear.clear()
 if phase in ["battle","victory","defeat"]:hold_restart_camera=true
 # Restart restores allies in place without moving the camera.
 projectile_view.clear();sim.reset(true);configure_allies();pool_ids.clear();step_clock=0
 for slot in enemy_pool:slot.id=-1;slot.actor.hide();slot.actor.trigger("revive");slot.state=""
 for i in team.size():
  team[i].trigger("revive");team[i].set_opacity(1)
  if team[i].has_meta("attack_stamp"):team[i].remove_meta("attack_stamp")
  if not has_prepared:team[i].position=slot_position(i)
 has_prepared=true
 phase="prepare"
 sync_party_health(0,true)
func can_reset()->bool:
 if not ready_stage:return false
 if phase=="event":return encounters.current().kind=="battle" and not encounters.resolved
 return phase in ["prepare","battle","victory","defeat"]
func start_battle(load_test:bool=true):
 if not ready_stage:return
 if fork_test in [2,3]:return
 if phase=="fork":return
 if phase not in ["prepare","event"]:return
 if phase=="event" and (encounters.current().kind!="battle" or encounters.resolved):return
 var candidate:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json"))
 if not load_test:
  var wave:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/world3d_encounter_wave.json"))
  if not wave is Dictionary:wave_error="遭遇配置无法读取";return
  candidate.merge(wave,true)
 wave_error=preload("res://scripts/world3d/wave_capacity.gd").validate(candidate,enemy_pool,load_test)
 if not wave_error.is_empty():return
 var encounter_actor=preview if phase=="event" and preview.visible else null
 if phase=="event":apply_saved_formation()
 encounters.arrive()
 sim.config=candidate
 projectile_view.clear();sim.reset(load_test);configure_allies()
 if not load_test:sim.seed_encounter(world.seed_value,route_number,branch,distance,encounters.cursor)
 sim.begin();step_clock=0
 if not load_test and encounter_actor!=null:
  # The already visible encounter is the first member of the wave.
  sim.spawn_enemy();sim.next_spawn=float(sim.config.interval)
 for actor in team:
  actor.trigger("revive")
  if actor.has_meta("attack_stamp"):actor.remove_meta("attack_stamp")
 for slot in enemy_pool:slot.id=-1;slot.actor.hide();slot.actor.trigger("revive");slot.state=""
 pool_ids.clear()
 if encounter_actor!=null:adopt_encounter_actor(encounter_actor)
 else:preview.hide()
 transition_frame=frame.duplicate();battle_camera_clock=0
 phase="entering";transition=0;hero_start=team[0].position
func adopt_encounter_actor(actor):
 for enemy in sim.enemies:
  if sim.config.enemies[enemy.type].model!=actor.model_key:continue
  for slot in enemy_pool:
   if slot.kind!=enemy.type:continue
   # Swap identical model instances: keep the visible actor, reuse the spare
   # for the next preview, without enlarging the pool or copying a rig pose.
   preview=slot.actor;preview.hide();preview.scale=actor.scale
   slot.actor=actor;slot.id=enemy.id;slot.last=actor.position;slot.state="walk"
   pool_ids[enemy.id]=slot
   enemy.pos=local_point(actor.position);enemy.previous_pos=enemy.pos
   enemy.spawn_x=enemy.pos.x;enemy.spawn_z=enemy.pos.z;enemy.road_x=enemy.pos.x
   enemy.entry="road";enemy.entry_phase="advance";enemy.activate_at=0.0;enemy.born=-1.0;enemy.phase_started=0.0
   actor.set_opacity(1)
   return
 actor.hide()
func apply_saved_formation():
 # Adopt a validated snapshot at a new encounter, never during combat/restart.
 live_camera.poll(.5)
 if not live_camera.data.has("battle_slots"):return
 var saved:Array=live_camera.data.battle_slots
 if saved==composition.battle_slots:return
 composition.battle_slots=saved.duplicate(true)
 profiles.clear()
 formation_scale_pending=true
 for i in units.size():profiles.append(PARTY.slot(saved,i,units.size(),PARTY.character(units[i])))
 for item in props:
  item.node.pixel_size=profiles[item.slot].height/20/item.node.texture.get_height()
 prop_atmosphere.refresh_clearances(props,profiles)
func choose_branch(value:int):
 if phase!="fork" or not route_segment.valid_exit(value):return
 planned_successor=route_segment.successor(value,world.seed_value,route_number)
 var tail=world.plan.at(route_segment.end_s,value)
 planned_successor.theme=str(tail.space.key)
 pending_world=preload("res://scripts/world3d/successor_world.gd").build(planned_successor,tail.space,world.assets)
 scenery.upload_jobs.clear();scenery.trim_after(planned_successor.start_s)
 scenery.queue_sprites(pending_world.sprites,planned_successor)
 scenery.bind_route_segments([route_segment,planned_successor])
 encounters.choose_branch(value)
 branch=value;phase="event";start_travel()
func start_travel():
 if not ready_stage or phase not in ["prepare","victory","defeat","event"]:return
 if not encounters.depart():return
 hold_restart_camera=false
 if defeat_clear!=null:defeat_clear.clear()
 team[0].set_opacity(1)
 for actor in team:actor.trigger("revive")
 distance=maxf(distance,0);phase="travel"
 travel_camera_offset=camera_origin-route_segment.point(distance,branch)
 travel_camera_age=0.0
 travel_camera_frame=frame.duplicate()
 for slot in enemy_pool:slot.actor.hide()
 # Include the camera's final settling time in the three-second opening.
 # Starting the brake farther away would require it to accelerate to catch up.
 var leg:=TravelPace.RUN*(3.0-maxf(0,STOP_CAMERA_SECONDS-.7)) if first_leg else TravelPace.mixed_distance(branch!=0)
 leg_walk_distance=0.0 if first_leg else TravelPace.WALK*((1.4 if branch!=0 else 1.0)-TravelPace.BRAKE_SECONDS*.5)
 next_event=distance+leg
 if fork_test in [2,3] and branch==0:next_event=route_segment.junction_s
 if branch==0 and next_event>ForestRoute.JUNCTION-80:next_event=ForestRoute.JUNCTION
 preview_route=route_segment;preview_branch=branch
 preview_stop_station=next_event+130;preview_station=next_event+210
 preview_age=0;preview_target=preview_path_at(-preview_stop_station);preview.position=preview_path_at(-preview_station);preview.trigger("revive")
 # A pooled actor can retain its last battle/branch heading. Set the new
 # approach direction while invisible, before its first fade-in frame.
 var approach:Vector3=preview_path_at(-preview_station+.1)-preview.position
 if Vector2(approach.x,approach.z).length_squared()>.000001:preview.rotation.y=atan2(approach.x,approach.z)
 preview.set_opacity(0)
 preview.visible=fork_test==0 and encounters.current().kind=="battle" and not (branch==0 and is_equal_approx(next_event,ForestRoute.JUNCTION))
func refresh_camera_template(dt:float):
 live_camera.poll(dt)
 if live_camera.data.is_empty():return
 if live_camera.fingerprint!=live_camera_revision:
  live_camera_revision=live_camera.fingerprint;live_camera_blending=true
 if not live_camera_blending:return
 var settled:=true
 for state in ["travel","event","battle"]:
  P.blend_frame(composition.frames[state],live_camera.data.frames[state],1-exp(-7*dt))
  for key in live_camera.KEYS:
   var difference:float=float(composition.frames[state][key])-float(live_camera.data.frames[state][key])
   if key=="yaw":difference=wrapf(difference,-180.0,180.0)
   if absf(difference)>.00001:settled=false
 if settled:
  for state in ["travel","event","battle"]:composition.frames[state]=live_camera.data.frames[state].duplicate()
  live_camera_blending=false
func _process(dt:float):
 if not ready_stage:return
 if playback_paused:return
 var previous_camera_origin:=camera_origin
 var frame_start:=Time.get_ticks_usec() if profiling else 0
 dt=minf(dt,.05);clock+=dt
 refresh_camera_template(dt)
 if formation_scale_pending:
  formation_scale_pending=false
  for i in team.size():
   var target_scale:float=CHARACTER_FRAME.scale_for_slot(float(profiles[team_slots[i]].height))
   var target:Vector3=Vector3.ONE*target_scale
   team[i].scale=team[i].scale.lerp(target,1-exp(-dt*12))
   if team[i].scale.distance_to(target)>.0001:formation_scale_pending=true
   else:team[i].scale=target
 if preview.visible:
  advance_preview(dt)
 if phase=="travel":
  var speed:float=route_locomotion_speed()
  var progress:Dictionary=preload("res://scripts/world3d/travel_progress.gd").step(team[0].position,distance,next_event,speed/20*dt,Callable(self,"travel_destination"))
  distance=progress.distance
  move_hero(progress.target,dt,speed/20)
  handoff_route_if_ready()
  # Resolve the initial mismatch with zero endpoint velocity, then follow the
  # route exactly. Exponential decay starts fastest at departure and snaps the
  # framing forward even while the actor is only starting to leave its slot.
  travel_camera_age+=dt
  var travel_blend:float=smoothstep(0,1,travel_camera_age/TRAVEL_CAMERA_SECONDS)
  camera_origin=route_segment.point(distance,branch)+travel_camera_offset*(1-travel_blend)
  frame=travel_camera_frame.duplicate()
  P.blend_frame(frame,composition.frames.travel,travel_blend)
  for i in range(1,team.size()):team[i].set_opacity(maxf(0,team[i].opacity-dt*3))
  if next_event-distance<speed*.7:
   transition_velocity=(camera_origin-previous_camera_origin)/maxf(dt,.0001)
   transition_start=camera_origin;transition_frame=frame.duplicate();encounter_anchor=route_segment.point(next_event,branch);transition=0;phase="stopping"
   camera_brake.configure(transition_start,encounter_anchor,transition_velocity,STOP_CAMERA_SECONDS)
 elif phase=="stopping":
  transition=minf(1,transition+dt/STOP_CAMERA_SECONDS)
  # Hermite start tangent preserves the incoming route velocity; end tangent is
  # zero. A fresh smoothstep here would abruptly stop the already moving camera.
  var t:float=transition;var t2:float=t*t;var t3:float=t2*t
  camera_origin=(2*t3-3*t2+1)*transition_start+(t3-2*t2+t)*transition_velocity*STOP_CAMERA_SECONDS+(-2*t3+3*t2)*encounter_anchor
  if camera_brake.feasible:camera_origin=camera_brake.sample(t)
  frame=transition_frame.duplicate()
  P.blend_frame(frame,composition.frames.event,smoothstep(0,1,transition))
  # Braking belongs to the camera. The actor still follows the curved route,
  # with a physical distance budget instead of cutting across to its endpoint.
  var speed:float=route_locomotion_speed()
  var progress:Dictionary=preload("res://scripts/world3d/travel_progress.gd").step(team[0].position,distance,next_event,speed/20*dt,Callable(self,"travel_destination"))
  distance=progress.distance
  move_hero(progress.target,dt,speed/20)
  if transition>=1 and team[0].position.distance_to(travel_destination(next_event))<.05:
   first_leg=false;distance=next_event;phase="fork" if branch==0 and is_equal_approx(distance,ForestRoute.JUNCTION) else "event"
   if phase=="event":encounters.arrive()
 elif phase=="entering":
  transition+=dt
  move_hero(slot_position(0),dt,TravelPace.RUN/20)
  var arrived:bool=team[0].position.distance_to(slot_position(0))<.03
  for i in range(1,team.size()):
   var old:Vector3=team[i].position
   var walk_to_slot:bool=hold_restart_camera or team[i].opacity>.01
   team[i].position=old.move_toward(slot_position(i),TravelPace.RUN/20*dt) if walk_to_slot else slot_position(i)
   # A hidden ally is placed before fading in. Placement is not locomotion:
   # feeding that relocation as velocity selects a spurious first-frame run pose.
   team[i].advance(dt,(team[i].position-old)/maxf(dt,.0001) if walk_to_slot else Vector3.ZERO)
   team[i].set_opacity(minf(1,team[i].opacity+dt*3))
   arrived=arrived and team[i].position.distance_to(slot_position(i))<.03
  if arrived:phase="battle"
 elif phase=="battle":
  var sim_start:=Time.get_ticks_usec() if profiling else 0
  step_clock+=dt
  while step_clock>=.05:step_clock-=.05;sim.step(.05)
  if profiling:profile_usec["simulation"]=int(profile_usec.get("simulation",0))+Time.get_ticks_usec()-sim_start
  var crowd_start:=Time.get_ticks_usec() if profiling else 0
  render_enemies(dt)
  if profiling:profile_usec["crowd"]=int(profile_usec.get("crowd",0))+Time.get_ticks_usec()-crowd_start
  for i in team.size():
   var actor=team[i];var unit=sim.allies[team_slots[i]]
   if actor.opacity<1:actor.set_opacity(minf(1,actor.opacity+dt*3))
   if unit.hp<=0 and not actor.dead:actor.trigger("death")
   elif unit.hp>0 and actor.dead:
    actor.trigger("battle_revive");actor.remove_meta("attack_stamp")
   elif unit.hp>0 and unit.state=="attack" and actor.get_meta("attack_stamp",-1)!=unit.changed:
    actor.attack_seconds=float(unit.get("attack_duration",unit.cooldown*.9));actor.trigger("attack");actor.set_meta("attack_stamp",unit.changed)
   var previous_position:Vector3=actor.position
   if not actor.dead:
    var local:Vector3=unit.get("previous_pos",unit.pos).lerp(unit.pos,clampf(step_clock/.05,0,1))
    actor.position=world_point(local)+Vector3.UP*float(profiles[team_slots[i]].clearance)/20
   actor.advance(dt,(actor.position-previous_position)/maxf(dt,.0001) if unit.state=="returning" else Vector3.ZERO)
  if sim.status in ["victory","defeat"]:
   phase=sim.status;sim.projectiles.active.clear();sim.windups.clear();sim.areas.clear()
   if phase=="defeat":defeat_clear.begin(self)
   if phase=="victory":
    encounters.win()
    # Winning restores the party immediately. Keep each presentation anchor in
    # place; departure and the next encounter own subsequent movement.
    for unit in sim.allies:
     unit.hp=unit.max_hp;unit.state="idle";unit.erase("attack_origin");unit.erase("attack_target");unit.erase("attack_tip")
    for actor in team:
     actor.trigger("revive")
     if actor.has_meta("attack_stamp"):actor.remove_meta("attack_stamp")
    sync_party_health(0,true)
 else:
  for actor in team:actor.advance(dt,Vector3.ZERO)
  if phase in ["victory","defeat"]:sim.clock+=dt;render_enemies(dt)
 if phase=="victory":
  for i in range(1,team.size()):team[i].set_opacity(maxf(0,team[i].opacity-dt*3))
 for item in props:
  var spec:Dictionary=profiles[item.slot]
  var fading:bool=phase in ["travel","stopping","event","fork","victory"]
  # The departing formation owns its last world position until it disappears.
  # Route heading / the next encounter anchor must not drag visible cards.
  if not fading:
   var p:Vector2=encounter_anchor+Vector2(spec.x,spec.depth).rotated(-route_segment.pose(distance,branch).heading)
   var clearance:float=spec.clearance+sin(clock*2+item.bob_phase)*item.bob
   item.node.position=P.point(p,ForestEcology.height_at(p)+clearance)
   item.node.set_meta("presentation_clearance",clearance)
  item.node.modulate.a=move_toward(item.node.modulate.a,0.0 if fading else 1.0,dt*3)
 # Camera completion is independent of the hero's arrival. A short entry path
 # must not freeze the lens halfway between the saved event and battle frames.
 if phase in ["entering","battle"] and not hold_restart_camera and not transition_frame.is_empty():
  battle_camera_clock=minf(BATTLE_CAMERA_SECONDS,battle_camera_clock+dt)
  frame=transition_frame.duplicate()
  P.blend_frame(frame,composition.frames.battle,smoothstep(0,1,battle_camera_clock/BATTLE_CAMERA_SECONDS))
 var pose:=route_segment.pose(distance,branch)
 # Formal travel has a small authored body turn (scene_formation), independent
 # of road steering. Keep the spatial root/path intact and blend only the mesh.
 if not team[0].dead:
  var body_yaw:float=-.12 if portrait_mode and phase in ["travel","stopping"] else 0.0
  team[0].body.rotation.y=lerp_angle(team[0].body.rotation.y,body_yaw,1-exp(-8*dt))
 if not hold_restart_camera:camera_heading=lerp_angle(camera_heading,route_segment.pose(next_event,branch).heading if phase=="stopping" else pose.heading,1-exp(-dt*7))
 scenery.process_uploads()
 extend_route_if_needed()
 world.update_camera(minf(distance,route_segment.junction_s-.01) if branch==0 else distance,branch);bridge.environment=world.environment();bridge.camera_world=P.frame_origin(camera_origin,camera_heading,frame);bridge.heading=P.frame_heading(camera_heading,frame);bridge.elapsed=clock;bridge.view_size=get_viewport().get_visible_rect().size
 environment_3d.background_color=environment_3d.background_color.lerp(Color("101923") if world.camera_region.space.key==&"forest" else world.camera_region.space.top_color,1-exp(-dt*4))
 bridge.runtime_camera=frame;bridge.battle_frame_shift=.19 if phase not in ["travel"] else 0
 if phase in ["prepare","battle"]:
  for i in team.size():
   if team[i].dead:continue
   if sim.allies[team_slots[i]].state in ["rising","returning"]:continue
   var target_yaw:float=PI-bridge.heading+(.22 if profiles[team_slots[i]].x>0 else -.22)
   team[i].rotation.y=lerp_angle(team[i].rotation.y,target_yaw,1.0 if dt<=0 else 1-exp(-8*dt))
 P.configure(camera,bridge.view_size,bridge.camera_world,bridge.heading,frame.height,frame.lens,frame.horizon)
 forest_background.sync(bridge)
 for i in team.size():team[i].portrait_presenter.advance_anchor(dt,i==0)
 for slot in enemy_pool:
  if portrait_mode:slot.actor.portrait_presenter.configure_enemy(camera,bridge.focal())
 if portrait_mode:preview.portrait_presenter.configure_enemy(camera,bridge.focal())
 if phase in ["prepare","victory","defeat","event","fork"] and not live_camera_revision.is_empty():
  P.blend_frame(frame,composition.frames.event if phase in ["event","fork"] else composition.frames.battle,1-exp(-7*dt))
 var fx_start:=Time.get_ticks_usec() if profiling else 0
 projectile_view.advance(dt)
 if profiling:profile_usec["particles"]=int(profile_usec.get("particles",0))+Time.get_ticks_usec()-fx_start
 var scenery_start:=Time.get_ticks_usec() if profiling else 0
 scenery.update_view(bridge)
 party_lighting.sync(bridge.team_light(),bridge.environment_light_tint(),camera_heading)
 if profiling:profile_usec["scenery"]=int(profile_usec.get("scenery",0))+Time.get_ticks_usec()-scenery_start
 encounter_panel.refresh()
 area_view.sync(sim.areas.zones)
 if phase=="defeat":defeat_clear.advance(dt,camera)
 var atmosphere_start:=Time.get_ticks_usec() if profiling else 0
 actor_atmosphere.set_enabled(atmosphere_mode);actor_atmosphere.sync(bridge,portrait_mode)
 prop_atmosphere.sync(bridge,atmosphere_mode)
 sync_party_health(dt)
 enemy_health_overlay.sync(self)
 if profiling:profile_usec["actor_atmosphere"]=int(profile_usec.get("actor_atmosphere",0))+Time.get_ticks_usec()-atmosphere_start
 action_buttons["重新整备"].disabled=not can_reset()
 sync_fork_buttons()
 var can_depart:bool=phase in ["prepare","victory","defeat","event"] and (not encounters.arrived or encounters.resolved)
 action_buttons["开始行进"].disabled=not can_depart;action_buttons["继续前进"].disabled=not can_depart
 action_buttons["50 来敌"].disabled=phase not in ["prepare","event"] or (phase=="event" and (encounters.current().kind!="battle" or encounters.resolved))
 action_buttons["普通遭遇"].disabled=action_buttons["50 来敌"].disabled
 if projection_toggle.button_pressed!=portrait_mode:projection_toggle.set_pressed_no_signal(portrait_mode)
 for actor in team+[preview]:
  actor.portrait_presenter.set_enabled(portrait_mode);actor.portrait_presenter.sync()
 for slot in enemy_pool:
  slot.actor.portrait_presenter.set_enabled(portrait_mode);slot.actor.portrait_presenter.sync()
 outline_lod.sync(camera,bridge.view_size,portrait_mode,outline_lod_enabled)
 label.text="3D 迁移 · %s · 防线 %d / 20 · %d FPS"%[{"prepare":"整备","battle":"交战","travel":"行进","stopping":"接近事件","entering":"进入战位","event":"事件选择","fork":"岔路选择","victory":"胜利","defeat":"防线失守"}.get(phase,phase),sim.life,Engine.get_frames_per_second()]
 if not wave_error.is_empty():label.text+="\n无法开始遭遇："+wave_error
 debug.text="原撒布 %d 件 · 活跃分块 %d · 模型 %d · 同一 3D 空间"%[scenery.imported_count,scenery.visible_chunks,pool_ids.size()]
 if profiling:profile_usec["stage_total"]=int(profile_usec.get("stage_total",0))+Time.get_ticks_usec()-frame_start
func preview_path_at(reverse_station:float)->Vector3:
 var point:Vector2=preview_route.point(-reverse_station,preview_branch)
 return P.point(point,ForestEcology.height_at(point))
func advance_preview(dt:float):
 if preview_route==null:return
 preview_age+=dt;preview.set_opacity(minf(1,preview_age/.5))
 var old:Vector3=preview.position
 # A preview owns the route it was deployed on, even if the player crosses a
 # streamed segment boundary. Reverse station lets it approach along that road.
 var step:Dictionary=preload("res://scripts/world3d/travel_progress.gd").step(old,-preview_station,-preview_stop_station,TravelPace.MONSTER_WALK_SPEED/20*dt,Callable(self,"preview_path_at"))
 preview_station=-float(step.distance)
 preview.position=old.move_toward(step.target,TravelPace.MONSTER_WALK_SPEED/20*dt)
 preview.advance(dt,(preview.position-old)/maxf(dt,.0001))
func route_locomotion_speed()->float:
 if first_leg:return TravelPace.RUN
 # One pace envelope spans travel and camera braking. The camera state must
 # never restart running or rescale the speed to meet its own deadline.
 return lerpf(TravelPace.WALK,TravelPace.RUN,smoothstep(leg_walk_distance,leg_walk_distance+TravelPace.RUN*.25,maxf(0,next_event-distance)))
func sync_party_health(dt:float,instant:bool=false):
 var settings:Dictionary=preload("res://scripts/battle/health_transformation.gd").settings()
 for i in health_views.size():
  var unit:Dictionary=sim.allies[team_slots[i]]
  health_views[i].sync(dt,float(unit.hp),float(unit.max_hp),settings,instant)
func move_hero(target:Vector3,dt:float,speed:float):
 var actor=team[0];var old:Vector3=actor.position
 actor.position=actor.position.move_toward(target,speed*dt);actor.advance(dt,(actor.position-old)/maxf(dt,.0001))
func render_enemies(dt:float):
 for e in sim.enemies:
  if sim.clock<e.activate_at or e.state=="leaked":continue
  if not pool_ids.has(e.id):
   for slot in enemy_pool:
    if slot.id<0 and slot.kind==e.type:
     slot.id=e.id;slot.last=world_point(e.pos);pool_ids[e.id]=slot
     if e.hp>0:
      # Bind a new visible life with its own direction, never the previous
      # pooled creature's yaw. Existing/adopted actors retain smooth steering.
      var movement:Vector3=e.pos-e.previous_pos;movement.y=0
      if movement.length_squared()<.000001:movement=Vector3(sin(float(e.heading)),0,cos(float(e.heading)))
      var facing:Vector3=world_point(e.pos+movement)-world_point(e.pos)
      slot.actor.rotation.y=atan2(facing.x,facing.z)
     break
  if not pool_ids.has(e.id):continue
  var slot=pool_ids[e.id];var actor=slot.actor
  # Match traditional enemy birth fading without restarting it on pool reuse
  # or at attack/locomotion changes. Corpses must remain fully readable.
  var birth_alpha:float=1.0 if e.hp<=0 else smoothstep(0,.7,sim.clock-float(e.get("born",e.activate_at)))
  if not is_equal_approx(actor.opacity,birth_alpha):actor.set_opacity(birth_alpha)
  else:actor.visible=birth_alpha>.001
  # Once damage resolves, interpolation must not drag the corpse along the
  # final movement segment while the death animation has already begun.
  var p:Vector3=e.pos if e.hp<=0 else e.previous_pos.lerp(e.pos,step_clock/.05)
  actor.position=world_point(p);actor.scale=Vector3.ONE*(38.0/52.0)*e.body_scale
  var velocity:Vector3=(actor.position-slot.last)/maxf(dt,.0001);slot.last=actor.position
  actor.animate_unit(e,sim.clock,dt,velocity);slot.state=e.state
 for e in sim.enemies:
  if e.state=="leaked" and pool_ids.has(e.id):pool_ids[e.id].actor.hide()
func cast_test(pierce:bool):
 if phase!="battle":return
 sim.areas.sync(sim.enemies,sim.skill_world,sim.clock)
 var from:=world_point(Vector3(0,0,6))
 var hits:int=sim.areas.corridor(from,world_point(Vector3(0,0,-25)),.8,1.0,45,Callable(sim,"hurt")) if pierce else sim.areas.burst(world_point(Vector3(0,0,-3)),2.8,1.0,45,Callable(sim,"hurt"))
 print("WORLD3D_SKILL ","pierce" if pierce else "explosion"," targets=",hits," broad phase visited=",sim.areas.index.visited)
func cast_zone():
 if phase!="battle":return
 sim.areas.add_zone(world_point(Vector3(0,0,-3)),2.8,1,8,4,.5)

func extend_route_if_needed():
 if branch==0 or planned_successor!=null:return
 var tail:RouteRegion
 for region in world.plan.regions:
  if region.branch==branch and (tail==null or region.end>tail.end):tail=region
 if tail==null or distance<tail.end-1600:return
 var extension:=tail.duplicate() as RouteRegion
 extension.start=tail.end;extension.end=tail.end+1800;extension.key=StringName(str(tail.key)+"_chunk_"+str(int(extension.start)))
 var begin:=world.sprites.size()
 extension.space.layout.new().populate(world,extension)
 # Extend the existing biome interval, avoiding unbounded shader-region growth.
 tail.end=extension.end
 scenery.queue_sprites(world.sprites.slice(begin),route_segment);scenery.update_region_bounds(world)
 scenery.retire_before(distance-500)
 world.sprites=world.sprites.filter(func(sprite):return float(sprite.get("route_s",distance))>=distance-500)
 stream_extensions+=1

func handoff_route_if_ready():
 if planned_successor==null or pending_world==null or distance<planned_successor.start_s:return
 if "--visible-route-handoff" in OS.get_cmdline_user_args():
  var view_origin:Vector2=P.frame_origin(camera_origin,camera_heading,frame)
  var next_origin:Vector2=P.frame_origin(planned_successor.point(distance,0),planned_successor.heading,composition.frames.travel)
  if not scenery.route_nearby_ready(planned_successor,view_origin) or not scenery.route_nearby_ready(planned_successor,next_origin):return
 elif not scenery.upload_jobs.is_empty():return
 var previous=route_segment
 route_segment=planned_successor;planned_successor=null;route_number+=1
 world=pending_world;pending_world=null;bridge.world=world;branch=0
 ForestRoute.origin=route_segment.origin;ForestRoute.origin_s=route_segment.start_s;ForestRoute.origin_heading=route_segment.heading
 ForestRoute.JUNCTION=route_segment.junction_s;ForestRoute.TURN_LENGTH=route_segment.turn_length
 scenery.mist_source.source=world.sprites
 scenery.update_region_bounds(world);scenery.bind_route_segments([previous,route_segment])
 for pair in [["route_origin",route_segment.origin],["route_origin_s",route_segment.start_s],["route_origin_heading",route_segment.heading],["junction",route_segment.junction_s],["turn_length",route_segment.turn_length],["three_way",route_segment.exits==3]]:
  scenery.floor_material.set_shader_parameter(pair[0],pair[1])
 scenery.retire_before(distance-500)
