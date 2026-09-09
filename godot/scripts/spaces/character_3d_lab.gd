extends Node3D
var model:Node3D
var model_path:="res://assets/characters3d/lantern-investigator.glb"
var title_text:="提灯调查员  /  LANTERN KEEPER"
var subtitle:="5.5 头身"
var initial_clip:="Idle"
var player:AnimationPlayer
var camera:Camera3D
var yaw:=.32
var pitch:=.13
var distance:=5.8
var target:=Vector3(0,1.65,0)
var dragging:=false
var turning:=false
var labels={"Idle":"待机","Walk":"行走","Run":"奔跑","Attack":"攻击","Hit":"受击","Defeat":"倒下"}
var hint:Label
func _ready() -> void:
 DisplayServer.window_set_title(title_text)
 get_viewport().msaa_3d=Viewport.MSAA_4X
 var world:=WorldEnvironment.new();world.environment=Environment.new()
 world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("0c151c")
 world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color=Color("849aab");world.environment.ambient_light_energy=.48
 world.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 add_child(world)
 var floor_mesh:=MeshInstance3D.new();var plane:=CylinderMesh.new()
 plane.top_radius=1.65;plane.bottom_radius=1.7;plane.height=.12;floor_mesh.mesh=plane;floor_mesh.position.y=-.06
 var slate:=StandardMaterial3D.new();slate.albedo_color=Color("182630");slate.roughness=.86
 floor_mesh.material_override=slate;add_child(floor_mesh)
 for spec in [[Vector3(-35,-25,0),Color("ffe1b1"),1.2],[Vector3(-25,135,0),Color("69b9cd"),1.5]]:
  var light:=DirectionalLight3D.new();light.rotation_degrees=spec[0];light.light_color=spec[1];light.light_energy=spec[2];add_child(light)
 model=load(model_path).instantiate();add_child(model)
 player=find_player(model)
 assert(player!=null)
 for name in player.get_animation_list():
  if name in ["Idle","Walk","Run","EM_Idle","EM_Walk","EM_Run"]:player.get_animation(name).loop_mode=Animation.LOOP_LINEAR
 camera=Camera3D.new();camera.fov=39;camera.current=true;add_child(camera)
 var canvas:=CanvasLayer.new();add_child(canvas)
 var heading:=Label.new();heading.text=title_text;heading.position=Vector2(28,22);heading.add_theme_font_size_override("font_size",26);canvas.add_child(heading)
 hint=Label.new();hint.text="5.5 头身 · 原创风格化角色\n拖动旋转 · 滚轮拉近 · 选择动作";hint.position=Vector2(30,64);hint.add_theme_font_size_override("font_size",16);canvas.add_child(hint)
 var bar:=HBoxContainer.new();bar.position=Vector2(28,get_viewport().get_visible_rect().size.y-76);bar.add_theme_constant_override("separation",9);canvas.add_child(bar)
 for name in labels:
  var b:=Button.new();b.text=labels[name];b.custom_minimum_size=Vector2(84,42);b.pressed.connect(func():play_clip(name));bar.add_child(b)
 var pause:=Button.new();pause.text="暂停 / 继续";pause.pressed.connect(func():player.active=not player.active);bar.add_child(pause)
 var turn:=Button.new();turn.text="自动转台";turn.pressed.connect(func():turning=not turning);bar.add_child(turn)
 var reset:=Button.new();reset.text="重置视角";reset.pressed.connect(func():yaw=.32;pitch=.13;distance=5.8;target=Vector3(0,1.65,0));bar.add_child(reset)
 get_viewport().size_changed.connect(func():bar.position.y=get_viewport().get_visible_rect().size.y-76)
 play_clip(initial_clip)
func find_player(node:Node) -> AnimationPlayer:
 if node is AnimationPlayer:return node
 for child in node.get_children():
  var found:=find_player(child)
  if found:return found
 return null
func play_clip(name:String) -> void:
 if name in ["Defeat","EM_Death"]:
  pitch=.5;distance=7.0;target=Vector3(0,.8,0)
 elif player.current_animation in ["Defeat","EM_Death"]:
  pitch=.13;distance=5.8;target=Vector3(0,1.65,0)
 player.active=true;player.play(name,.12)
 hint.text="%s · 当前动作：%s\n拖动旋转 · 滚轮拉近 · 选择动作"%[subtitle,labels[name]]
func _process(dt:float) -> void:
 if turning:yaw+=dt*.25
 camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
 camera.look_at(target)
func _unhandled_input(event:InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
  if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:distance=maxf(2.0,distance*.9)
  if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance=minf(10,distance/ .9)
 if event is InputEventMouseMotion and dragging:
  yaw-=event.relative.x*.006;pitch=clampf(pitch+event.relative.y*.004,-.15,.8)
