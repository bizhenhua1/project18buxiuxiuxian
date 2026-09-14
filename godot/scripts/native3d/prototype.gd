extends Node3D
## Independent native-3D experiment. All visuals share this World3D and Camera3D.
const ACTOR=preload("res://scripts/native3d/actor.gd")
var camera:Camera3D
var route:=Curve3D.new()
var distance:=0.0
var traveled:=0.0
var phase:="travel"
var clock:=0.0
var event_index:=0
var event_at:=5.0
var party:Array=[]
var enemies:Array=[]
var paths:Dictionary={}
var battlefield:=Vector3.ZERO
var battle_forward:=Vector3.FORWARD
var battle_camera:=Vector3.ZERO
var battle_look:=Vector3.ZERO
var camera_look:=Vector3.ZERO
var camera_velocity:=Vector3.ZERO
var camera_mix:=0.0
var camera_plan:Dictionary={}
var planned_event:=-1.0
var composition=preload("res://scripts/native3d/template_layout.gd").new()
var model:=BattleModel.new()
var status:Label
var controls:HBoxContainer
var slot_choice:OptionButton
var hero_slot:=1
var paused:=false
var lamp:OmniLight3D
var health_labels:Array=[]
var settled:=false
var fogs:Array=[]
var fog_time:=0.0
var rng:=RandomNumberGenerator.new()
func ground(x:float,z:float) -> float:return .08*sin(x*.31)*sin(z*.17)
func at(s:float) -> Vector3:
 var p:=route.sample_baked(clampf(s,0,route.get_baked_length()),true)
 p.y=ground(p.x,p.z);return p
func forward(s:float) -> Vector3:return (at(s+.1)-at(maxf(0,s-.1))).normalized()
func right(f:Vector3) -> Vector3:return f.cross(Vector3.UP).normalized()
func _ready() -> void:
 DisplayServer.window_set_title("雾林 · 原生3D独立样板")
 rng.seed=48119
 route.bake_interval=.12
 route.add_point(Vector3.ZERO)
 route.add_point(Vector3(0,0,-40),Vector3(0,0,5),Vector3(0,0,-5))
 build_world();build_party();build_ui()
 camera=Camera3D.new();camera.fov=57;camera.near=.08;camera.far=100;add_child(camera);camera.current=true
 var f:=forward(1)
 var initial_frame:Dictionary=composition.camera_frame("travel",at(0),f)
 camera.position=initial_frame.position;camera_look=initial_frame.look;camera.fov=initial_frame.fov;camera.look_at(camera_look)
 model.finished.connect(finish)
 model.emitted.connect(combat_event)
 lamp=OmniLight3D.new();lamp.light_color=Color("d6d6ba");lamp.light_energy=2.2;lamp.omni_range=8;add_child(lamp)
 _process(0)
func build_party() -> void:
 model.player.clear()
 var ids:=["investigator","silent-medium","faceless-mask","sealed-book"] if has_meta("composition_editor") else ["investigator","silent-medium","faceless-mask","sealed-book","watchful-clock","soul-lantern","containment-record"]
 for id in ids:model.player.append(model.rules.create_unit(id,"player",model.player.size(),0))
 model.enemy=model.enemy.slice(0,3);model.health_multiplier=5;model.reset()
 for i in range(model.player.size()):
  var node:Node3D
  if i<2:
   node=ACTOR.new();add_child(node);node.setup("seer-treading-snow.glb" if i==0 else "isabella.glb")
  else:
   node=Sprite3D.new();node.texture=load("res://assets/style2/"+(["watch.png","book.png","mask.png","lantern.png","book.png"][(i-2)%5]));node.pixel_size=.002;node.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;add_child(node)
  node.position=Vector3(-.55+(i*.25),0,.7*i)
  party.append(node)
 for i in range(3):
  var node=ACTOR.new();add_child(node);node.setup("gentleman.glb");node.visible=false;enemies.append(node)
 for node in party+enemies:
  var label:=Label3D.new();label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=48;label.pixel_size=.0018;label.position.y=2.2 if health_labels.size()<2 or health_labels.size()>=party.size() else .65;label.modulate=Color("d5d0b6");node.add_child(label);health_labels.append(label)
func material(texture:String,cutout:bool=true) -> StandardMaterial3D:
 var mat:=StandardMaterial3D.new();mat.albedo_texture=load(texture);mat.roughness=1
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 if cutout:mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=.30;mat.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;mat.billboard_keep_scale=true
 return mat
func build_world() -> void:
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("111c26")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("81959f");env.environment.ambient_light_energy=.28
 env.environment.fog_enabled=true;env.environment.fog_light_color=Color("101c25");env.environment.fog_density=.014
 add_child(env)
 var moon:=DirectionalLight3D.new();moon.rotation_degrees=Vector3(-45,-35,0);moon.light_color=Color("a2bac8");moon.light_energy=.28;add_child(moon)
 var mesh:=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in range(-100,30,2):
  for x in range(-55,56,2):
   for v in [Vector2(x,z),Vector2(x,z+2),Vector2(x+2,z),Vector2(x+2,z),Vector2(x,z+2),Vector2(x+2,z+2)]:
    mesh.set_uv(v/4);mesh.add_vertex(Vector3(v.x,ground(v.x,v.y),v.y))
 mesh.generate_normals()
 var floor_node:=MeshInstance3D.new();floor_node.mesh=mesh.commit();floor_node.material_override=material("res://assets/style2/ground.png",false);add_child(floor_node)
 for branch in [-1,0,1]:
  var road:=SurfaceTool.new();road.begin(Mesh.PRIMITIVE_TRIANGLES)
  for k in range(24):
   var z0:float=-40-k;var z1:float=z0-1
   var x0:float=branch*k*.5;var x1:float=branch*(k+1)*.5
   for v in [Vector2(x0-1.4,z0),Vector2(x1-1.4,z1),Vector2(x0+1.4,z0),Vector2(x0+1.4,z0),Vector2(x1-1.4,z1),Vector2(x1+1.4,z1)]:
    road.set_uv(v/4);road.add_vertex(Vector3(v.x,ground(v.x,v.y)+.015,v.y))
  road.generate_normals()
  var surface:=MeshInstance3D.new();surface.mesh=road.commit();var mat:=material("res://assets/style2/ground.png",false);mat.albedo_color=Color(.66,.71,.70);surface.material_override=mat;add_child(surface)
 preload("res://scripts/native3d/forest_dressing.gd").new().populate(self)
func build_ui() -> void:
 var canvas:=CanvasLayer.new();add_child(canvas)
 var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);canvas.add_child(panel)
 var box:=VBoxContainer.new();panel.add_child(box)
 status=Label.new();status.add_theme_font_size_override("font_size",20);box.add_child(status)
 controls=HBoxContainer.new();box.add_child(controls)
 button("遭遇战",func():if phase=="travel":begin_event(false))
 button("交谈事件",func():if phase=="travel":begin_event(true))
 button("迎战",func():if phase=="dialogue":deploy())
 button("结束交谈",func():if phase=="dialogue":leave())
 button("测试战败",func():if phase=="battle":finish("defeat"))
 button("原地复活",revive)
 button("两岔路",func():if phase=="travel":phase="fork2")
 button("三岔路",func():if phase=="travel":phase="fork3")
 button("左路",func():choose(-1))
 button("直行",func():choose(0))
 button("右路",func():choose(1))
 var row:=HBoxContainer.new();box.add_child(row)
 slot_choice=OptionButton.new()
 for i in range(4):slot_choice.add_item("主角战斗位 %d"%(i+1))
 slot_choice.select(hero_slot);slot_choice.item_selected.connect(func(i):if phase=="travel":hero_slot=i)
 row.add_child(slot_choice)
 var pause:=Button.new();pause.text="暂停 / 继续";pause.pressed.connect(func():paused=not paused);row.add_child(pause)
 var reset:=Button.new();reset.text="重置样板";reset.pressed.connect(func():get_tree().reload_current_scene());row.add_child(reset)
 var hint:=Label.new();hint.text="独立3D样板 · 同一世界/摄像机 · 自动轮换战斗、交谈与岔路 · 可手动触发";row.add_child(hint)
func button(text:String,callback:Callable) -> void:
 var b:=Button.new();b.text=text;b.pressed.connect(callback);controls.add_child(b)
func plan_camera(stop:float) -> void:
 planned_event=stop
 battlefield=at(stop+3.8);battle_forward=forward(stop+2)
 var frame:Dictionary=composition.camera_frame("event",at(stop),battle_forward)
 battle_camera=frame.position;battle_look=frame.look
 camera_plan={"start":camera.position,"velocity":camera_velocity,"look":camera_look,"time":0.0,"duration":maxf(.8,(stop-distance)/1.6+.65),"start_fov":camera.fov,"fov":frame.fov}
func begin_event(talk:bool) -> void:
 if absf(planned_event-distance)>.08:plan_camera(distance)
 phase="dialogue" if talk else "entering";clock=0;settled=false
 var enemy_positions:Array=composition.enemy_slots(enemies.size())
 for i in range(enemies.size()):
  var local:Vector3=enemy_positions[i]
  enemies[i].visible=true;enemies[i].position=battlefield-battle_forward*local.z+right(battle_forward)*local.x+Vector3.UP*local.y;enemies[i].rotation.y=atan2(-battle_forward.x,-battle_forward.z)
  enemies[i].trigger("revive")
 if not talk:deploy()
func deploy() -> void:
 phase="entering";clock=0;paths.clear()
 var frame:Dictionary=composition.camera_frame("battle",battlefield,battle_forward)
 battle_camera=frame.position;battle_look=frame.look
 camera_plan={"start":camera.position,"velocity":camera_velocity.limit_length(.6),"look":camera_look,"time":0.0,"duration":1.5,"start_fov":camera.fov,"fov":frame.fov}
 var slots:Array=composition.player_slots(party.size(),hero_slot>=2)
 for i in range(party.size()):
  var local:Vector3=slots[i]
  var end:Vector3=battlefield+right(battle_forward)*local.x-battle_forward*local.z
  end.y=ground(end.x,end.z)+local.y
  if i>=2:party[i].scale=Vector3.ONE*composition.prop_scale()
  var start:Vector3=party[i].position
  paths[i]={"start":start,"a":start+battle_forward*2.0,"b":end-battle_forward*1.3,"end":end,"duration":maxf(1.0,start.distance_to(end)/2.5)}
  party[i].visible=true
  if party[i].has_method("set_opacity"):party[i].set_opacity(1.0)
  if party[i] is Sprite3D:party[i].modulate.a=1.0
func leave() -> void:
 phase="leaving";clock=0;paths.clear();camera_plan.clear();planned_event=-1
 var destination:=distance+9.0
 for i in range(2):
  var f:=forward(destination);var end:=at(destination)+right(f)*(-.55+(i*.15))-f*i*.4
  if i>=2:end.y+=1.1
  var start:Vector3=party[i].position
  paths[i]={"start":start,"a":start+battle_forward*2.4,"b":end-f*1.8,"end":end,"duration":maxf(1.4,start.distance_to(end)/2.5)}
 traveled=destination
func choose(side:int) -> void:
 if phase not in ["fork2","fork3"] or (phase=="fork2" and side==0):return
 var tail:Vector3=route.get_point_position(route.point_count-1)
 var direction:=forward(route.get_baked_length()-.2).rotated(Vector3.UP,-side*.46).normalized()
 route.set_point_out(route.point_count-1,forward(route.get_baked_length()-.2)*5)
 route.add_point(tail+direction*24,-direction*5,direction*5)
 phase="travel";event_index+=1;event_at=distance+6.4
func revive() -> void:
 if phase!="defeat":return
 model.reset()
 for node in party+enemies:
  if node.has_method("trigger"):node.trigger("revive")
 phase="reviving";clock=0
func finish(result:String) -> void:
 if phase!="battle":return
 if result=="victory":leave()
 else:
  phase="defeat"
  for node in party:
   if node.has_method("trigger"):node.trigger("death")
func combat_event(event:Dictionary) -> void:
 var node:Node3D
 if event.type in ["cast","shot"]:
  node=find_unit(event.from.uid)
  if node and node.has_method("trigger"):node.trigger("attack")
 elif event.type in ["damage","death"]:
  node=find_unit(event.unit.uid)
  if node and node.has_method("trigger"):node.trigger("hit" if event.type=="damage" else "death")
func find_unit(uid:int) -> Node3D:
 for i in range(model.player.size()):
  if model.player[i].uid==uid:return party[i]
 for i in range(model.enemy.size()):
  if model.enemy[i].uid==uid:return enemies[i]
 return null
func _process(delta:float) -> void:
 if not camera:return
 var dt:=minf(delta,.05) if not paused else 0.0
 clock+=dt;fog_time+=dt
 for i in range(fogs.size()):
  var fog:Sprite3D=fogs[i]
  if not fog.has_meta("origin"):fog.set_meta("origin",fog.position)
  fog.position=fog.get_meta("origin")+Vector3(sin(fog_time*.16+i)*.24,0,cos(fog_time*.12+i)*.12)
 var old:Array=[]
 for node in party:old.append(node.position)
 var f:=forward(maxf(1,distance));var r:=right(f)
 var camera_target:=camera.position;var look_target:=camera_look
 if phase=="travel":
  distance+=dt*1.6
  f=forward(maxf(1,distance));r=right(f)
  for i in range(party.size()):
   var target:=at(distance)+r*(-.55+i*.15)-f*i*.45
   if i>=2:target.y+=1.1
   party[i].position=party[i].position.lerp(target,1-exp(-dt*9));party[i].visible=i==0
  var travel_frame:Dictionary=composition.camera_frame("travel",at(distance),f)
  camera_target=travel_frame.position;look_target=travel_frame.look
  if camera_plan.is_empty():camera.fov=lerpf(camera.fov,travel_frame.fov,1-exp(-dt*5))
  if event_index%4!=2 and event_at-distance<=1.1 and planned_event<0:plan_camera(event_at)
  if distance>=event_at:
   if event_index%4==2:phase="fork2" if event_index%8==2 else "fork3"
   else:begin_event(event_index%4==1)
  if distance>65 and phase=="travel":
   get_tree().call_deferred("reload_current_scene");set_process(false);return
  if distance>route.get_baked_length()-3 and phase=="travel":
   var tail:=route.get_point_position(route.point_count-1);route.add_point(tail+f*25,-f*5,f*5)
 if phase in ["entering","dialogue","battle","reviving"]:
  camera_target=battle_camera;look_target=battle_look
 if phase in ["entering","leaving"]:
  settled=true
  for i in paths:
   var p:Dictionary=paths[i];var t:=clampf(clock/p.duration,0,1)
   party[i].position=p.start.bezier_interpolate(p.a,p.b,p.end,smoothstep(0,1,t))
   party[i].position.y=ground(party[i].position.x,party[i].position.z)+(float(p.end.y)-ground(p.end.x,p.end.z) if i>=2 else 0)
   if t<1:settled=false
  if phase=="leaving":
   party[1].set_opacity(1-smoothstep(.05,.55,clock))
   for i in range(2,party.size()):party[i].modulate.a=1-smoothstep(0,.65,clock)
   var progress:=smoothstep(0,2.7,clock)
   var travel_frame:Dictionary=composition.camera_frame("travel",at(traveled),forward(traveled))
   camera_target=camera.position.lerp(travel_frame.position,progress);look_target=travel_frame.look
   camera.fov=lerpf(camera.fov,travel_frame.fov,1-exp(-dt*4))
   if settled and clock>2.7:
    distance=traveled;event_index+=1;event_at=distance+6.4;phase="travel"
    for node in enemies:node.visible=false
  elif settled and camera.position.distance_to(battle_camera)<.04:
   model.reset();model.start();phase="battle";clock=0
 if phase=="reviving" and clock>.7:model.start();phase="battle"
 if phase=="battle":model.advance(dt)
 if phase not in ["defeat","reviving"]:
  var previous:=camera.position
  if not camera_plan.is_empty():
   camera_plan.time+=dt
   var t:=clampf(camera_plan.time/camera_plan.duration,0,1)
   var tangent:Vector3=camera_plan.velocity*camera_plan.duration
   camera.position=camera_plan.start*(2*t*t*t-3*t*t+1)+tangent*(t*t*t-2*t*t+t)+battle_camera*(-2*t*t*t+3*t*t)
   camera_look=camera_plan.look.lerp(battle_look,smoothstep(0,1,t))
   camera.fov=lerpf(camera_plan.start_fov,camera_plan.fov,smoothstep(0,1,t))
  else:
   camera.position=camera.position.lerp(camera_target,1-exp(-dt*4))
   camera_look=camera_look.lerp(look_target,1-exp(-dt*4))
  camera_velocity=(camera.position-previous)/maxf(dt,.001)
  camera.look_at(camera_look)
 for i in range(party.size()):
  if party[i].has_method("advance"):party[i].advance(dt,(party[i].position-old[i])/maxf(dt,.001))
 for node in enemies:node.advance(dt,Vector3.ZERO)
 lamp.position=party[0].position+f*.6+r*.65+Vector3.UP*1.1
 for i in range(health_labels.size()):
  var units:Array=model.player if i<party.size() else model.enemy
  var index:=i if i<party.size() else i-party.size()
  health_labels[i].text=str(int(units[index].hp));health_labels[i].visible=phase in ["battle","defeat","reviving"]
 status.text="原生3D森林 · "+{"travel":"沿路前进","entering":"向前分流入阵","battle":"战斗","dialogue":"交谈 / 选择","leaving":"向前汇合","defeat":"战败 · 原地重整","reviving":"原位恢复","fork2":"两岔路 · 选择方向","fork3":"三岔路 · 选择方向"}.get(phase,phase)
 slot_choice.disabled=phase!="travel"
