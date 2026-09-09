extends Control
const MODELS=preload("res://scripts/spaces/character_library.gd").MODELS
const SURFACE=preload("res://shaders/character_study.gdshader")
const EDGE=preload("res://shaders/character_study_outline.gdshader")
const PRESETS=[
 ["冷灰 · 清晰分层",1,.45,.035,.35,.78,.006,Color("#283d51")],
 ["暖纸 · 双阶阴影",1,.55,.08,.5,.65,.009,Color("#514638")],
 ["黑墨 · 粗线",2,.52,.03,.22,.55,.012,Color("#18232e")],
 ["蓝墨 · 细线",2,.40,.07,.4,.72,.005,Color("#283d55")],
 ["夜雾 · 柔和",3,.45,.12,.3,.70,.004,Color("#203246")],
 ["旧绘本 · 暖灰",3,.45,.16,.5,.62,.007,Color("#4d4038")]]
var viewport:SubViewport
var stage:Node3D
var body:Node3D
var rig:Skeleton3D
var camera:Camera3D
var light:Light3D
var materials:Array=[]
var originals:Array=[]
var retarget=preload("res://scripts/spaces/preview_retarget.gd").new()
var clip:Dictionary
var elapsed:=0.0
var playing:=true
var yaw:=.3
var selected_model:=0
var scheme:OptionButton
var templates:OptionButton
var light_kind:OptionButton
var sliders:Dictionary={}
var tint:ColorPickerButton
var light_tint:ColorPickerButton
var status:Label
var refreshing:=false
func label(parent:Node,text:String) -> Label:
 var l=Label.new();l.text=text;parent.add_child(l);return l
func select(parent:Node,title:String,items:Array,callback:Callable) -> OptionButton:
 label(parent,title)
 var box=OptionButton.new()
 for item in items:box.add_item(str(item))
 parent.add_child(box);box.item_selected.connect(callback);return box
func slider(parent:Node,title:String,key:String,lo:float,hi:float,value:float,step:float=.01):
 var line=HBoxContainer.new();parent.add_child(line)
 var name=label(line,title);name.size_flags_horizontal=SIZE_EXPAND_FILL
 var number=SpinBox.new();number.min_value=lo;number.max_value=hi;number.step=step;number.value=value;number.custom_minimum_size.x=110
 line.add_child(number);sliders[key]=number
 number.value_changed.connect(func(_v):update_settings())
func _ready():
 DisplayServer.window_set_title("角色 Shader 浏览器 · 独立试验")
 var bg=ColorRect.new();bg.color=Color("#10191e");bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(bg)
 var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 for k in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+k,16)
 add_child(margin)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",18);margin.add_child(row)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size.x=330;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;row.add_child(scroll)
 var panel=VBoxContainer.new();panel.custom_minimum_size.x=308;panel.add_theme_constant_override("separation",8);scroll.add_child(panel)
 label(panel,"角色渲染研究 · 不影响游戏")
 var names=[]
 for m in MODELS:names.append(m.name)
 select(panel,"角色",names,select_model)
 scheme=select(panel,"渲染方案",["原材质对照","赛璐璐 · 硬边色块","版画 · 分层排线","绘本 · 柔和暗部"],func(_i):refresh_templates())
 templates=select(panel,"参数模板",[],apply_preset)
 slider(panel,"明暗分界","threshold",.05,.95,.45)
 slider(panel,"边界柔和","softness",.005,.3,.04,.005)
 slider(panel,"暗部保留","ambient",0,2,.35)
 slider(panel,"贴图饱和度","saturation",0,1.5,.78)
 slider(panel,"描边厚度","width",0,.025,.006,.001)
 slider(panel,"排线强度","ink",0,1,.35)
 label(panel,"阴影颜色");tint=ColorPickerButton.new();tint.custom_minimum_size.y=32;tint.color=Color("#283d51");panel.add_child(tint);tint.color_changed.connect(func(_c):update_settings())
 light_kind=select(panel,"光源",["方向光 · 月光","点光 · 侧灯","聚光 · 手电"],func(_i):make_light())
 slider(panel,"光源水平角","light_yaw",-180,180,-45,1)
 slider(panel,"光源高度角","light_pitch",5,85,35,1)
 slider(panel,"光源强度","energy",0,6,2,.05)
 label(panel,"光源颜色");light_tint=ColorPickerButton.new();light_tint.custom_minimum_size.y=32;light_tint.color=Color("#e0e8ef");panel.add_child(light_tint);light_tint.color_changed.connect(func(_c):update_settings())
 slider(panel,"角色转向","yaw",-180,180,20,1)
 slider(panel,"镜头远近","zoom",1.8,5,2.8,.05)
 var pause=Button.new();pause.text="暂停 / 播放待机";panel.add_child(pause);pause.pressed.connect(func():playing=not playing)
 var export=Button.new();export.text="导出当前参数 JSON";panel.add_child(export);export.pressed.connect(save_parameters)
 var center=VBoxContainer.new();center.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(center)
 label(center,"原贴图 + 实时骨骼模型 | 调整左侧参数即时对照")
 var host=SubViewportContainer.new();host.stretch=true;host.size_flags_vertical=SIZE_EXPAND_FILL;host.size_flags_horizontal=SIZE_EXPAND_FILL;center.add_child(host)
 viewport=SubViewport.new();viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;host.add_child(viewport)
 stage=Node3D.new();viewport.add_child(stage)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("#202c32");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("#a4b4bf");env.environment.ambient_light_energy=.35;stage.add_child(env)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.position=Vector3(0,1.2,5);stage.add_child(camera);camera.look_at(Vector3(0,1,0));camera.current=true
 var floor=MeshInstance3D.new();floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(200,200)
 var floor_mat=StandardMaterial3D.new();floor_mat.albedo_color=Color("#263138");floor_mat.roughness=1;floor.material_override=floor_mat;stage.add_child(floor)
 status=label(center,"浏览器内材质独立复制，不覆盖模型或游戏参数。")
 make_light();select_model(0);scheme.select(1);refresh_templates()
func select_model(index:int):
 if not stage:return
 selected_model=index
 if body:body.queue_free()
 materials.clear();originals.clear()
 body=load("res://assets/characters3d/"+MODELS[index].file).instantiate();stage.add_child(body)
 inspect(body)
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_3d_motions.json"))
 retarget.configure(rig,data.bones);clip=data.clips.idle;retarget.load_clip(clip)
 body.scale=Vector3.ONE*1.8/(rig.get_bone_global_rest(rig.find_bone("頭")).origin.y+.2)
 elapsed=0;update_settings()
func inspect(node:Node):
 if node is Skeleton3D:rig=node
 if node is AnimationPlayer:node.active=false
 if node is MeshInstance3D:
  for i in range(node.mesh.get_surface_count()):
   var original=node.get_active_material(i)
   if not original is StandardMaterial3D:continue
   originals.append({"mesh":node,"surface":i,"material":original})
   var mat=ShaderMaterial.new();mat.shader=SURFACE
   mat.set_shader_parameter("base_texture",original.albedo_texture);mat.set_shader_parameter("textured",original.albedo_texture!=null);mat.set_shader_parameter("base_color",original.albedo_color)
   var edge=ShaderMaterial.new();edge.shader=EDGE;edge.set_shader_parameter("base_texture",original.albedo_texture);edge.set_shader_parameter("textured",original.albedo_texture!=null);edge.set_shader_parameter("opacity",original.albedo_color.a)
   mat.next_pass=edge;materials.append(mat)
 for child in node.get_children():inspect(child)
func refresh_templates():
 templates.clear()
 for i in range(PRESETS.size()):
  if PRESETS[i][1]==scheme.selected:templates.add_item(PRESETS[i][0],i)
 if templates.item_count>0:templates.select(0);apply_preset(0)
 else:update_settings()
func apply_preset(index:int):
 if templates.item_count==0:return
 var p=PRESETS[templates.get_item_id(index)]
 refreshing=true
 for i in range(6):sliders[["threshold","softness","ambient","saturation","width","ink"][i]].value=p[i+2] if i<5 else .35
 tint.color=p[7];refreshing=false;update_settings()
func make_light():
 if not stage:return
 if light:light.queue_free()
 light=DirectionalLight3D.new() if light_kind.selected==0 else OmniLight3D.new() if light_kind.selected==1 else SpotLight3D.new()
 stage.add_child(light);light.shadow_enabled=true
 if light is OmniLight3D:light.omni_range=8
 if light is SpotLight3D:light.spot_range=10;light.spot_angle=38;light.spot_attenuation=1.3
 update_settings()
func update_settings():
 if refreshing or not body or not light:return
 for i in range(materials.size()):
  var mat:ShaderMaterial=materials[i]
  for key in ["threshold","softness","ambient","saturation","ink"]:mat.set_shader_parameter(key,sliders[key].value)
  mat.set_shader_parameter("style",scheme.selected);mat.set_shader_parameter("shadow_color",tint.color)
  mat.next_pass.set_shader_parameter("width",sliders.width.value)
  mat.next_pass.set_shader_parameter("ink_color",Color("#0c1119"))
  originals[i].mesh.set_surface_override_material(originals[i].surface,originals[i].material if scheme.selected==0 else mat)
 body.rotation.y=deg_to_rad(sliders.yaw.value)
 camera.size=sliders.zoom.value
 var a=deg_to_rad(sliders.light_yaw.value);var elevation=deg_to_rad(sliders.light_pitch.value)
 light.position=Vector3(sin(a)*cos(elevation),sin(elevation),cos(a)*cos(elevation))*3+Vector3(0,1,0)
 light.look_at(Vector3(0,1,0));light.light_energy=sliders.energy.value;light.light_color=light_tint.color
func _process(dt:float):
 if not body or not playing:return
 elapsed+=dt;retarget.apply(fmod(elapsed,(clip.frames-1)/clip.fps))
func save_parameters():
 var data={"model":MODELS[selected_model].file,"scheme":scheme.selected,"light_type":light_kind.selected,"shadow_color":tint.color.to_html(),"light_color":light_tint.color.to_html()}
 for key in sliders:data[key]=sliders[key].value
 var dialog=FileDialog.new();dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE;dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.use_native_dialog=true;dialog.add_filter("*.json","Shader 参数");dialog.current_file="character-shader.json";add_child(dialog)
 dialog.file_selected.connect(func(path):
  var f=FileAccess.open(path,FileAccess.WRITE)
  if f:f.store_string(JSON.stringify(data,"  "));status.text="参数已导出："+path
  dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(.7)
