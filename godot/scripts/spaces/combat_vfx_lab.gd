extends "res://scripts/spaces/character_library.gd"
var effects:Node3D
var victim:Node3D
var victim_motion=RETARGET.new()
var active_kind:=""
var action_time:=0.0
var action_duration:=1.0
var hit_sent:=false
var combo_index:=0
var battle_camera:=true
var target_point:=Vector3(0,1,-4.2)
var tip_mesh:MeshInstance3D
var tip_local:=Vector3.ZERO
var hit_time:=10.0
var status_text:Label
func _ready():
 super()
 DisplayServer.window_set_title("战斗特效样板 · 剑击 / 火球术")
 select_model(3);looping=false;playing=false
 effects=preload("res://scripts/spaces/combat_vfx_sample.gd").new();stage.add_child(effects);effects.set_process(false);effects.impacted.connect(func(_kind):hit_time=0)
 victim=load("res://assets/characters3d/gentleman.glb").instantiate();stage.add_child(victim);disable_players(victim)
 var vr=find_rig(victim);var h=vr.get_bone_global_rest(vr.find_bone("頭")).origin.y+.2;victim.scale=Vector3.ONE*1.8/h;victim.position=Vector3(0,0,-4.2);victim.rotation.y=0
 victim_motion.configure(vr,catalog.bones)
 for clip in clips:
  if clip.id=="9_EM_Idle":victim_motion.load_clip(clip);victim_motion.apply(0);break
 var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(14,18);floor.mesh=plane;floor.position=Vector3(0,-.02,-3)
 var m:=StandardMaterial3D.new();m.albedo_texture=load("res://assets/world-six/forest/ground.png");m.uv1_scale=Vector3(5,6,1);m.roughness=1;floor.material_override=m;stage.add_child(floor)
 for child in stage.get_children():
  if child is MeshInstance3D and child!=floor:child.hide()
  if child is WorldEnvironment:child.environment.background_color=Color("101a1e");child.environment.ambient_light_energy=.35
 var bar:=VBoxContainer.new();bar.position=Vector2(410,16);add_child(bar)
 var row:=HBoxContainer.new();bar.add_child(row)
 for spec in [["剑击 · 连招 1—4","sword"],["火球术","fire"]]:
  var b:=Button.new();b.text=spec[0];b.custom_minimum_size=Vector2(155,42);row.add_child(b);b.pressed.connect(start_action.bind(spec[1]))
 var camera_button:=Button.new();camera_button.text="切换：战斗 / 自由机位";row.add_child(camera_button);camera_button.pressed.connect(func():battle_camera=not battle_camera;distance=7)
 status_text=Label.new();bar.add_child(status_text);status_text.text="选择角色后点击测试。剑击向前 0.85 米，命中后退回；火球在场景中飞行。"
func choose(id:String):
 for clip in clips:
  if clip.id==id:select_clip(clip);return
func find_tip(node:Node,hand:Vector3,best:Dictionary):
 if node is MeshInstance3D:
  var box:AABB=node.mesh.get_aabb()
  for i in 8:
   var point:=box.get_endpoint(i);var d:float=node.to_global(point).distance_squared_to(hand)
   if d>best.distance:best.distance=d;best.mesh=node;best.point=point
 for child in node.get_children():find_tip(child,hand,best)
func start_action(kind:String):
 if not active_kind.is_empty():return
 active_kind=kind;action_time=0;hit_sent=false;model.position=Vector3.ZERO;model.rotation.y=PI
 effects.samples.clear();tip_mesh=null
 if kind=="sword":
  for i in weapon_panel.items.size():
   if weapon_panel.items[i].file=="sword_1handed_A.gltf" or weapon_panel.items[i].get("kind","")=="sword":weapon_panel.weapon=i;weapon_panel.picker.select(i);break
  weapon_panel.bind_model();choose("4_Anim_ARPGSamurai_Attack_Combo%d"%(combo_index+1));combo_index=(combo_index+1)%4
  if weapon_panel.visual:
   var hand:Vector3=rig.to_global(rig.get_bone_global_pose(rig.find_bone("手首.R")).origin)
   var best={"distance":0.0,"mesh":null,"point":Vector3.ZERO};find_tip(weapon_panel.visual,hand,best);tip_mesh=best.mesh;tip_local=best.point
 else:
  weapon_panel.weapon=0;weapon_panel.picker.select(0);weapon_panel.bind_model();choose("9_EM_RangeAttack")
 action_duration=maxf(.8,float(selected.frames-1)/selected.fps);looping=false;rate=1
 status_text.text="剑击 %d · 武器实际轨迹 / 独立命中碎屑"%combo_index if kind=="sword" else "火球术 · 网格火焰 / 世界空间余烬 / 到达后爆裂"
func _process(dt:float):
 super(dt)
 if battle_camera and camera:
  camera.position=Vector3(2.8,2.1,4.2);camera.look_at(Vector3(0,.85,-1.9));camera.fov=48
 if not effects:return
 if not active_kind.is_empty() and not playing and elapsed<action_duration-.02:return
 dt*=rate
 effects._process(dt)
 hit_time+=dt
 victim_motion.apply(fmod(hit_time,1.0))
 victim.rotation.z=sin(minf(hit_time/.32,1)*PI)*-.12 if hit_time<.32 else 0
 if active_kind.is_empty():return
 action_time+=dt
 var t:=action_time/action_duration
 if active_kind=="sword":
  var move:=smoothstep(0,.3,t)*(1-smoothstep(.7,1,t));model.position.z=-.85*move
  if t>.18 and t<.58 and is_instance_valid(tip_mesh):
   var hand:Vector3=rig.to_global(rig.get_bone_global_pose(rig.find_bone("手首.R")).origin)
   var tip:=tip_mesh.to_global(tip_local);effects.blade(hand.lerp(tip,.2),tip)
  if t>=.46 and not hit_sent:hit_sent=true;effects.impact(target_point,"sword")
 elif t>=.38 and not hit_sent:
  hit_sent=true;var hand:Vector3=rig.to_global(rig.get_bone_global_pose(rig.find_bone("手首.R")).origin);effects.launch(hand,target_point,.85)
 if t>=1:
  model.position=Vector3.ZERO;active_kind="";playing=false

