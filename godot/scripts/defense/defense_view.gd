extends Node3D
const SIM=preload("res://scripts/defense/defense_sim.gd")
const ACTOR=preload("res://scripts/defense/defense_actor.gd")
var sim=SIM.new()
var pools:Array=[]
var friends:Array=[]
var missiles:Array=[]
var camera:Camera3D
var info:Label
var note:Label
var overlay:Control
var ready_sample:=false
var paused:=false
var accumulator:=0.0
var selected:=-1
var frames:Array[float]=[]
var loading_label:Label
var sample_elapsed:=0.0
var last_report:=0.0
func _ready():
 DisplayServer.window_set_title("雾林 · 防线战斗试验")
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("101b21")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("94afc0");env.environment.ambient_light_energy=.65
 add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-30,0);light.light_color=Color("d8d9c2");light.light_energy=1.25;add_child(light)
 camera=Camera3D.new();camera.position=Vector3(17,23,26);add_child(camera);camera.look_at(Vector3(0,0,-7));camera.fov=48;camera.current=true
 box(Vector3(0,-.3,-10),Vector3(18,.5,48),Color("283b39"))
 for z in range(-30,10,2):
  for x in range(-8,9,2):box(Vector3(x,-.04,z),Vector3(1.93,.09,1.93),Color("30423e") if (x+z)%4==0 else Color("354641"))
 for x in [-9,9]:
  for z in range(-30,10,4):
   box(Vector3(x,1,z),Vector3(.45,2,.45),Color("222d2c"))
   box(Vector3(x,2.3,z),Vector3(2.4,2.2,2.4),Color("1b302b"))
 box(Vector3(0,.025,8.5),Vector3(18,.08,.16),Color("deaa67"))
 for x in [-6,-3,0,3,6]:box(Vector3(x,.02,-10),Vector3(.025,.03,35),Color("48625b"))
 var canvas:=CanvasLayer.new();add_child(canvas)
 overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(overlay);overlay.draw.connect(draw_health)
 var panel:=PanelContainer.new();panel.position=Vector2(20,18);canvas.add_child(panel)
 var col:=VBoxContainer.new();panel.add_child(col)
 var title:=Label.new();title.text="守住提灯防线 · 独立单局";title.add_theme_font_size_override("font_size",24);col.add_child(title)
 info=Label.new();col.add_child(info)
 note=Label.new();note.text="五类来敌 / 普通怪越线扣 1 点 / 防线生命 20";col.add_child(note)
 var row:=HBoxContainer.new();col.add_child(row)
 button(row,"开始波次",func():sim.begin())
 button(row,"重新整备",func():restart(false))
 button(row,"50 敌人压测",func():restart(true);sim.begin())
 button(row,"暂停 / 继续",func():paused=not paused)
 button(row,"迟滞结界 [空格]",func():sim.pulse())
 var row2:=HBoxContainer.new();col.add_child(row2)
 for i in 5:
  var n=i
  button(row2,["护卫一","护卫二","护卫三","术师一","术师二"][i],func():selected=n)
 button(row2,"返回原游戏",func():get_tree().change_scene_to_file("res://scenes/mistwood_start.tscn"))
 var help:=Label.new();help.text="整备时：选队员后点击地面换位。战中：空格减速 4 秒，冷却 16 秒。\n疾行影会绕过交战；执咒者在射程内停步攻击；队友倒下后敌人继续推进。\n现有角色模型暂代五类怪物；本页不修改原战斗和存档。";col.add_child(help)
 loading_label=Label.new();loading_label.text="正在预热模型池…";col.add_child(loading_label)
 for spec in sim.config.enemies:ResourceLoader.load_threaded_request("res://assets/characters3d/"+spec.model)
 call_deferred("warm")
func button(row:Node,text:String,action:Callable):
 var b:=Button.new();b.text=text;b.pressed.connect(action);row.add_child(b)
func box(pos:Vector3,size:Vector3,color:Color):
 var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size
 var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=1;mesh.material=mat
 node.mesh=mesh;node.position=pos;add_child(node)
func warm():
 for kind in 5:
  var path="res://assets/characters3d/"+sim.config.enemies[kind].model
  while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await get_tree().process_frame
  var scene=ResourceLoader.load_threaded_get(path)
  var pool:Array=[]
  for i in 12:
   var actor=ACTOR.new();add_child(actor);actor.setup(scene,i);pool.append(actor)
   loading_label.text="预热模型 %d / 65"%(kind*12+i+1)
   await get_tree().process_frame
  pools.append(pool)
  var friend=ACTOR.new();add_child(friend);friend.setup(scene,0);friends.append(friend)
 for i in 80:
  var m:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.10;mesh.height=.20
  var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("88deec");mesh.material=mat;m.mesh=mesh;add_child(m);m.hide()
  missiles.append({"node":m,"active":false,"age":0.0,"duration":1.0,"from":Vector3.ZERO,"to":Vector3.ZERO})
 ready_sample=true;loading_label.text="模型池就绪 · 60 个敌人实例 / 最多 50 个存活 / 5 个队员"
 restart(false)
 if "--stress" in OS.get_cmdline_user_args():restart(true);sim.begin()
func restart(stress:bool):
 if not ready_sample:return
 sim.reset(stress);paused=false;accumulator=0;frames.clear();sample_elapsed=0;last_report=0
 for pool in pools:
  for actor in pool:actor.bound={};actor.hide()
 for m in missiles:m.active=false;m.node.hide()
 for i in 5:friends[i].bind(sim.allies[i],false)
func _process(dt:float):
 if not ready_sample:return
 frames.append(dt*1000)
 if frames.size()>600:frames.pop_front()
 sample_elapsed+=dt
 var advance_dt:=0.0 if paused else minf(dt,.1)
 accumulator+=advance_dt
 while accumulator>=.05:
  accumulator-=.05;sim.step(.05)
  for fx in sim.effects:
   for m in missiles:
    if not m.active:
     m.active=true;m.age=0;m.duration=maxf(.1,fx.duration);m.from=fx.from;m.to=fx.to;m.node.show()
     m.node.mesh.material.albedo_color=Color("eaa4b0") if fx.enemy else Color("8ce4ee")
     break
 for e in sim.enemies:
  if e.resolved and (e.state=="leaked" or sim.clock-e.changed>3):continue
  var found:=false
  for actor in pools[e.type]:
   if not actor.bound.is_empty() and actor.bound.id==e.id:found=true;break
  if not found:
   for actor in pools[e.type]:
    if actor.bound.is_empty():actor.bind(e,true);break
 for pool in pools:
  for actor in pool:actor.advance(advance_dt,sim.clock)
 for actor in friends:actor.advance(advance_dt,sim.clock)
 for m in missiles:
  if not m.active:continue
  m.age+=advance_dt
  var t=clampf(m.age/m.duration,0,1)
  m.node.position=m.from.lerp(m.to,t)
  if t>=1:m.active=false;m.node.hide()
 var phase={"prepare":"整备","battle":"交战","victory":"防守成功","defeat":"防线失守"}[sim.status]
 info.text="%s  |  防线 %d / 20  |  存活敌人 %d / 50  |  击败 %d  漏过 %d\n入场 %d / %d  ·  %d FPS  ·  平均 %.1f ms  ·  绘制调用 %d"%[phase,sim.life,sim.active_count(),sim.killed,sim.leaked,sim.spawned,50 if sim.stress else sim.config.total,Engine.get_frames_per_second(),average_ms(),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
 note.text="迟滞结界：%s  |  %s"%["可用" if sim.clock>=sim.spell_ready else "冷却 %.0f 秒"%(sim.spell_ready-sim.clock),"已暂停" if paused else "选中队员 %d；整备时点击地面换位"%(selected+1) if selected>=0 else "金色横线为突破线；按漏怪数量扣血"]
 overlay.queue_redraw()
 if sample_elapsed-last_report>=5:
  last_report=sample_elapsed
  print("DEFENSE_PROFILE elapsed=%.1f alive=%d peak=%d mean_ms=%.2f draws=%d"%[sample_elapsed,sim.active_count(),sim.peak,average_ms(),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
func average_ms()->float:
 var total:=0.0
 for f in frames:total+=f
 return total/maxi(1,frames.size())
func draw_health():
 if not ready_sample:return
 for list in [sim.enemies,sim.allies]:
  for u in list:
   if u.hp<=0 or u.get("resolved",false) or camera.is_position_behind(u.pos):continue
   var p:=camera.unproject_position(u.pos+Vector3.UP*(3.2 if u.boss else 2.05))
   overlay.draw_rect(Rect2(p-Vector2(18,0),Vector2(36,4)),Color("152321"))
   overlay.draw_rect(Rect2(p-Vector2(18,0),Vector2(36*u.hp/u.max_hp,4)),Color("d18c82") if u.has("resolved") else Color("8cdbca"))
   if not u.has("resolved") and u.id==selected:overlay.draw_circle(p-Vector2(0,10),4,Color("ffd69a"))
func _unhandled_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_SPACE:sim.pulse()
 if not ready_sample or sim.status!="prepare" or selected<0:return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  var origin=camera.project_ray_origin(event.position);var direction=camera.project_ray_normal(event.position)
  var hit=Plane(Vector3.UP,0).intersects_ray(origin,direction)
  if hit!=null:sim.allies[selected].pos=Vector3(clampf(hit.x,-7,7),0,clampf(hit.z,-1,7.5))
