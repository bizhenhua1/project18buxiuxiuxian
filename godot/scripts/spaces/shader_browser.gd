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
const TEMPLATE_SAVE="user://shader-browser-templates.cfg"
const GAME_MATERIAL=preload("res://scripts/battle/character_ink_material.gd")
const TEAM=preload("res://scripts/battle/team_lighting.gd")
var team_profiles:Dictionary={}
var lighting_context:="travel"
var team_inputs:Dictionary={}
var team_color:ColorPickerButton
var road_color:ColorPickerButton
var controls_scroll:ScrollContainer
var team_state:OptionButton
var game_preview:Control
var solo_host:SubViewportContainer
var preview_parent:VBoxContainer
var saved_templates:Dictionary={}
var template_name:LineEdit
var model_select:OptionButton
var dragging:=false
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
 var scroll=ScrollContainer.new();controls_scroll=scroll;scroll.custom_minimum_size.x=330;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;row.add_child(scroll)
 var panel=VBoxContainer.new();panel.custom_minimum_size.x=308;panel.add_theme_constant_override("separation",8);scroll.add_child(panel)
 label(panel,"角色渲染研究 · 预览与保存")
 var saved=ConfigFile.new()
 if saved.load(TEMPLATE_SAVE)==OK:saved_templates=saved.get_value("templates","entries",{})
 var names=[]
 for m in MODELS:names.append(m.name)
 model_select=select(panel,"角色",names,select_model)
 scheme=select(panel,"渲染方案",["原材质对照","赛璐璐 · 硬边色块","版画 · 分层排线","绘本 · 柔和暗部"],func(_i):refresh_templates())
 templates=select(panel,"参数模板",[],apply_preset)
 slider(panel,"明暗分界","threshold",.05,.95,.45)
 slider(panel,"边界柔和","softness",.005,.3,.04,.005)
 slider(panel,"暗部保留","ambient",0,2,.35)
 slider(panel,"贴图饱和度","saturation",0,1.5,.78)
 slider(panel,"描边厚度","width",0,.025,.006,.001)
 slider(panel,"排线强度","ink",0,1,.35)
 label(panel,"阴影颜色");tint=ColorPickerButton.new();tint.custom_minimum_size.y=32;tint.color=Color("#283d51");panel.add_child(tint);tint.color_changed.connect(func(_c):update_settings())
 light_kind=select(panel,"展台光源（仅展台）",["方向光 · 月光","点光 · 侧灯","聚光 · 手电"],func(_i):make_light())
 slider(panel,"光源水平角","light_yaw",-180,180,-45,1)
 slider(panel,"光源高度角","light_pitch",-89,89,35,1)
 slider(panel,"光源强度","energy",0,50,2,.05)
 sliders.energy.allow_greater=true
 label(panel,"光源颜色");light_tint=ColorPickerButton.new();light_tint.custom_minimum_size.y=32;light_tint.color=Color("#e0e8ef");panel.add_child(light_tint);light_tint.color_changed.connect(func(_c):update_settings())
 slider(panel,"角色转向","yaw",-180,180,20,1)
 slider(panel,"镜头远近","zoom",1.8,5,2.8,.05)
 var pause=Button.new();pause.text="暂停 / 播放待机";panel.add_child(pause);pause.pressed.connect(func():playing=not playing)
 template_name=LineEdit.new();template_name.placeholder_text="模板名称（同名保存覆盖）";panel.add_child(template_name)
 var save=Button.new();save.text="保存模板";panel.add_child(save);save.pressed.connect(save_template)
 var apply=Button.new();apply.text="保存到游戏 · 材质与队伍灯光";panel.add_child(apply);apply.pressed.connect(apply_to_game)
 team_profiles=TEAM.profiles()
 label(panel,"游戏队伍灯光 · 移动 / 战斗独立保存")
 team_state=select(panel,"编辑情境",["移动光源","战斗光源"],func(i):show_game("travel" if i==0 else "battle"))
 team_state.allow_reselect=true
 for spec in [["x","角色灯 · 左右",-30,30],["y","角色灯 · 高度",-30,30],["z","角色灯 · 前后",-30,30],["energy","角色灯 · 强度",0,50],["range","角色灯 · 范围",.1,100],["ambient","环境补光",0,20],["rim","轮廓补光",0,20],["road_x","道路灯 · 左右",-500,500],["road_y","道路灯 · 高度",-100,500],["road_z","道路灯 · 前后",-500,1000],["road_energy","道路灯 · 强度",0,50],["road_radius","道路灯 · 范围",1,1000]]:
  var row_light=HBoxContainer.new();panel.add_child(row_light);var title=label(row_light,spec[1]);title.size_flags_horizontal=SIZE_EXPAND_FILL
  var spin=SpinBox.new();spin.min_value=spec[2];spin.max_value=spec[3];spin.step=.1;row_light.add_child(spin);team_inputs[spec[0]]=spin
  spin.allow_greater=true
  spin.allow_lesser=spec[0] in ["x","y","z","road_x","road_y","road_z"]
  spin.value_changed.connect(func(_v):team_changed())
 label(panel,"角色灯颜色");team_color=ColorPickerButton.new();panel.add_child(team_color);team_color.color_changed.connect(func(_v):team_changed())
 label(panel,"道路灯颜色");road_color=ColorPickerButton.new();panel.add_child(road_color);road_color.color_changed.connect(func(_v):team_changed())
 switch_lighting("travel")
 var export=Button.new();export.text="导出当前参数 JSON";panel.add_child(export);export.pressed.connect(save_parameters)
 var center=VBoxContainer.new();preview_parent=center;center.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(center)
 label(center,"展台支持拖动旋转 · 游戏实景使用已保存的镜头与站位")
 var modes=HBoxContainer.new();center.add_child(modes)
 var battle=Button.new();battle.text="进入游戏战斗机位与站位";modes.add_child(battle);battle.pressed.connect(func():show_game("battle"))
 var travel=Button.new();travel.text="预览游戏移动机位";modes.add_child(travel);travel.pressed.connect(func():show_game("travel"))
 var solo=Button.new();solo.text="返回单角色展台";modes.add_child(solo);solo.pressed.connect(func():solo_host.show();if game_preview:game_preview.hide())
 var publish=Button.new();publish.text="保存到游戏";modes.add_child(publish);publish.pressed.connect(apply_to_game)
 var host=SubViewportContainer.new();host.stretch=true;host.size_flags_vertical=SIZE_EXPAND_FILL;host.size_flags_horizontal=SIZE_EXPAND_FILL;center.add_child(host)
 solo_host=host
 host.gui_input.connect(drag_character)
 viewport=SubViewport.new();viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;host.add_child(viewport)
 stage=Node3D.new();viewport.add_child(stage)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("#202c32");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("#a4b4bf");env.environment.ambient_light_energy=.35;stage.add_child(env)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.position=Vector3(0,1.2,5);stage.add_child(camera);camera.look_at(Vector3(0,1,0));camera.current=true
 var floor=MeshInstance3D.new();floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(200,200)
 var floor_mat=StandardMaterial3D.new();floor_mat.albedo_color=Color("#263138");floor_mat.roughness=1;floor.material_override=floor_mat;stage.add_child(floor)
 status=label(center,"模板包含材质、展台与两套队伍灯光；保存到游戏后自动生效。")
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
 if game_preview:game_preview.replace_model(MODELS[index].file);refresh_game()
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
func drag_character(event:InputEvent):
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
 if event is InputEventMouseMotion and dragging:
  if not event.button_mask&MOUSE_BUTTON_MASK_LEFT:dragging=false;return
  sliders.yaw.value=wrapf(sliders.yaw.value+event.relative.x*.5,-180,180)
func refresh_templates():
 templates.clear()
 for i in range(PRESETS.size()):
  if PRESETS[i][1]==scheme.selected:
   templates.add_item(PRESETS[i][0],i);templates.set_item_metadata(templates.item_count-1,{"builtin":i})
 for name in saved_templates:
  if int(saved_templates[name].scheme)==scheme.selected:
   templates.add_item("已保存 · "+name);templates.set_item_metadata(templates.item_count-1,{"saved":name})
 if templates.item_count>0:templates.select(0);apply_preset(0)
 else:update_settings()
func apply_preset(index:int):
 if templates.item_count==0:return
 var entry:Dictionary=templates.get_item_metadata(index)
 if entry.has("saved"):
  template_name.text=entry.saved;restore_parameters(saved_templates[entry.saved]);return
 var p=PRESETS[entry.builtin]
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
  mat.set_shader_parameter("environment_fill",.35);mat.set_shader_parameter("environment_fill_color",Color("a4b4bf"))
  mat.set_shader_parameter("style",scheme.selected);mat.set_shader_parameter("shadow_color",tint.color)
  mat.next_pass.set_shader_parameter("width",sliders.width.value)
  mat.next_pass.set_shader_parameter("ink_color",Color("#0c1119"))
  originals[i].mesh.set_surface_override_material(originals[i].surface,originals[i].material if scheme.selected==0 else mat)
 body.rotation.y=deg_to_rad(sliders.yaw.value)
 camera.size=sliders.zoom.value
 var a=deg_to_rad(sliders.light_yaw.value);var elevation=deg_to_rad(sliders.light_pitch.value)
 light.position=Vector3(sin(a)*cos(elevation),sin(elevation),cos(a)*cos(elevation))*3+Vector3(0,1,0)
 light.look_at(Vector3(0,1,0));light.light_energy=sliders.energy.value;light.light_color=light_tint.color
 refresh_game()
func _process(dt:float):
 if not body or not playing:return
 elapsed+=dt;retarget.apply(fmod(elapsed,(clip.frames-1)/clip.fps))
func parameters() -> Dictionary:
 var data={"model":MODELS[selected_model].file,"scheme":scheme.selected,"light_type":light_kind.selected,"shadow_color":tint.color.to_html(),"light_color":light_tint.color.to_html()}
 for key in sliders:data[key]=sliders[key].value
 data.team_lights=team_profiles.duplicate(true)
 return data
func restore_parameters(data:Dictionary):
 refreshing=true
 team_profiles=TEAM.profiles(data.get("team_lights",TEAM.defaults()))
 scheme.select(int(data.scheme));light_kind.select(int(data.light_type))
 for key in sliders:
  if data.has(key):sliders[key].value=data[key]
 tint.color=Color(data.shadow_color);light_tint.color=Color(data.light_color)
 for i in MODELS.size():
  if MODELS[i].file==data.model:model_select.select(i);select_model(i);break
 refreshing=false;switch_lighting(lighting_context);make_light();update_settings()
func save_template():
 var name=template_name.text.strip_edges()
 if name.is_empty():status.text="请先填写模板名称";return
 var data=parameters();var entries=saved_templates.duplicate(true);entries[name]=data
 var config=ConfigFile.new();config.set_value("templates","entries",entries)
 if config.save(TEMPLATE_SAVE)!=OK:status.text="模板保存失败";return
 saved_templates=entries;refresh_templates()
 for i in templates.item_count:
  if templates.get_item_metadata(i).get("saved","")==name:templates.select(i);break
 restore_parameters(data);status.text="模板已保存："+name
func apply_to_game():
 status.text="已保存到游戏：角色材质及移动、战斗两套队伍灯光已更新。" if GAME_MATERIAL.save_game(parameters())==OK else "保存到游戏失败"
func save_parameters():
 var data=parameters()
 var dialog=FileDialog.new();dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE;dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.use_native_dialog=true;dialog.add_filter("*.json","Shader 参数");dialog.current_file="character-shader.json";add_child(dialog)
 dialog.file_selected.connect(func(path):
  var f=FileAccess.open(path,FileAccess.WRITE)
  if f:f.store_string(JSON.stringify(data,"  "));status.text="参数已导出："+path
  dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(.7)

func switch_lighting(context:String):
 lighting_context=context
 refreshing=true;team_state.select(0 if context=="travel" else 1)
 for key in team_inputs:team_inputs[key].value=team_profiles[context][key]
 team_color.color=Color(team_profiles[context].color);road_color.color=Color(team_profiles[context].road_color)
 refreshing=false
 if game_preview:game_preview.context=context;refresh_game()
func team_changed():
 if refreshing:return
 for key in team_inputs:team_profiles[lighting_context][key]=team_inputs[key].value
 team_profiles[lighting_context].color=team_color.color.to_html();team_profiles[lighting_context].road_color=road_color.color.to_html()
 refresh_game()
func show_game(context:String):
 switch_lighting(context)
 if not game_preview:
  status.text="正在加载游戏实景与已保存的镜头站位……"
  game_preview=preload("res://scripts/spaces/shader_game_preview.gd").new();preview_parent.add_child(game_preview)
  preview_parent.move_child(game_preview,preview_parent.get_child_count()-2)
  game_preview.material_parameters=material_data();game_preview.profiles=team_profiles;game_preview.context=context
  game_preview.setup(MODELS[selected_model].file)
 solo_host.hide();game_preview.show();refresh_game()
 controls_scroll.ensure_control_visible(team_state)
 status.text="游戏实景 · "+("战斗机位与站位" if context=="battle" else "移动机位")+"；左侧可独立调整对应队伍灯光。"
func material_data() -> Dictionary:
 var data=GAME_MATERIAL.DEFAULTS.duplicate();data.merge(parameters(),true);return data
func refresh_game():
 if not game_preview or refreshing:return
 game_preview.profiles=team_profiles;game_preview.material_parameters=material_data();game_preview.render()
