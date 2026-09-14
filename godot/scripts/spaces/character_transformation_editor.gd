extends "res://scripts/spaces/character_library.gd"
const TRANSFORM=preload("res://shaders/character_transform.gdshader")
const FIT=preload("res://scripts/spaces/skeleton_fit.gd")
const SAVE="user://character-transformation-presets.cfg"
var surfaces:Array=[]
var fitted:Array=[]
var effect_ready:=false
var progress:=0.0
var duration:=4.0
var effect_playing:=false
var mode:=0
var material_style:=0
var material_control:OptionButton
var opacity:=.4
var energy:=1.5
var glow:=Color("70ecdfff")
var progress_control:HSlider
var preset_name:LineEdit
var preset_list:OptionButton
var mode_control:OptionButton
var color_control:ColorPickerButton
var duration_control:SpinBox
var opacity_control:SpinBox
var energy_control:SpinBox
var height_top:=1.9
var height_bottom:=0.0
var skull_control:SpinBox
var head_scales:Dictionary={}
var display_control:OptionButton
var support:Label
func _ready():
 super()
 DisplayServer.window_set_title("角色转化效果编辑器")
 weapon_panel.hide()
 burst_note.get_parent().hide()
 var parent=info.get_parent()
 var panel:=VBoxContainer.new();parent.add_child(panel);parent.move_child(panel,1)
 var row:=HBoxContainer.new();panel.add_child(row)
 mode_control=OptionButton.new();mode_control.add_item("方案 1 · 幽灵全息化");mode_control.add_item("方案 2 · 全息骷髅替换");row.add_child(mode_control)
 mode_control.item_selected.connect(func(i):mode=i;update_effect())
 var start:=Button.new();start.text="播放转化";row.add_child(start);start.pressed.connect(func():progress=0;effect_playing=true)
 var pause:=Button.new();pause.text="暂停 / 继续";row.add_child(pause);pause.pressed.connect(func():effect_playing=not effect_playing)
 var reset:=Button.new();reset.text="还原角色";row.add_child(reset);reset.pressed.connect(func():progress=0;effect_playing=false;update_effect())
 progress_control=HSlider.new();progress_control.max_value=1;progress_control.step=.001;panel.add_child(progress_control)
 progress_control.value_changed.connect(func(v):progress=v;update_effect())
 var style_row:=HBoxContainer.new();panel.add_child(style_row)
 label(style_row,"转化材质",14)
 material_control=OptionButton.new();style_row.add_child(material_control)
 for title in ["原始 · 全息扫描","符纹 · 秘文流转","魂火 · 游丝焰光","墨影 · 脉络浮影"]:material_control.add_item(title)
 material_control.item_selected.connect(func(i):
  material_style=i
  glow=[Color("70ecdfff"),Color("d8b870"),Color("bba878"),Color("7eaa99")][i]
  color_control.color=glow
  energy_control.value=1.0 if i>0 else 1.5
  update_effect())
 var params:=HBoxContainer.new();panel.add_child(params)
 duration_control=number(params,"时长",.5,15,duration,func(v):duration=v)
 opacity_control=number(params,"全息不透明度",.1,1,opacity,func(v):opacity=v;update_effect())
 energy_control=number(params,"发光",0,5,energy,func(v):energy=v;update_effect())
 color_control=ColorPickerButton.new();color_control.color=glow;color_control.custom_minimum_size=Vector2(55,30);params.add_child(color_control);color_control.color_changed.connect(func(v):glow=v;update_effect())
 skull_control=number(params,"头骨放大",.25,4.0,1.0,func(v):
  head_scales[MODELS[selected_model].file]=v
  if effect_ready:rebuild_skull())
 var save_row:=HBoxContainer.new();panel.add_child(save_row)
 preset_name=LineEdit.new();preset_name.placeholder_text="模板名称";preset_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;save_row.add_child(preset_name)
 var save:=Button.new();save.text="保存模板";save_row.add_child(save);save.pressed.connect(save_preset)
 preset_list=OptionButton.new();save_row.add_child(preset_list);preset_list.item_selected.connect(load_preset)
 support=label(panel,"",14)
 var game_row:=HBoxContainer.new();panel.add_child(game_row)
 label(game_row,"游戏生命显示",14)
 display_control=OptionButton.new();display_control.add_item("血量 UI");display_control.add_item("模型转化");game_row.add_child(display_control)
 var game_data=preload("res://scripts/battle/health_transformation.gd").settings()
 head_scales=game_data.get("head_scales",{}).duplicate(true)
 display_control.select(1 if game_data.display=="transform" else 0)
 var publish:=Button.new();publish.text="保存到游戏 · 生命显示与转化方案";game_row.add_child(publish)
 publish.pressed.connect(func():
  var error=preload("res://scripts/battle/health_transformation.gd").save_game({"display":"ui" if display_control.selected==0 else "transform","mode":mode,"opacity":opacity,"energy":energy,"color":glow.to_html(),"head_scales":head_scales,"material_style":material_style})
  support.text="已保存，游戏中的 3D 角色将同步更新" if error==OK else "保存失败，请重试")
 mode=int(game_data.mode);mode_control.select(mode)
 material_style=int(game_data.get("material_style",0));material_control.select(material_style)
 opacity_control.value=float(game_data.opacity);energy_control.value=float(game_data.energy)
 glow=Color(game_data.color);color_control.color=glow
 effect_ready=true;setup_effect();refresh_presets()
func number(parent:Node,title:String,low:float,high:float,value:float,callback:Callable)->SpinBox:
 label(parent,title,14)
 var box:=SpinBox.new();box.min_value=low;box.max_value=high;box.step=.05;box.value=value;parent.add_child(box);box.value_changed.connect(callback);return box
func select_model(index:int):
 surfaces.clear();fitted.clear()
 super(index)
 if effect_ready:setup_effect()
func select_clip(clip_data:Dictionary):
 super(clip_data)
 if effect_ready:update_effect()
func setup_effect():
 surfaces.clear();effect_playing=false;progress=0
 var originals:Array=[];FIT.meshes(model,originals)
 height_bottom=INF;height_top=-INF
 for mesh in originals:
  var bounds:AABB=mesh.get_aabb()
  for corner in range(8):
   var point:Vector3=mesh.global_transform*bounds.get_endpoint(corner)
   height_bottom=minf(height_bottom,point.y);height_top=maxf(height_top,point.y)
 skull_control.set_value_no_signal(float(head_scales.get(MODELS[selected_model].file,1.0)))
 fitted=FIT.build(rig,skull_control.value)
 for mesh in originals:
  bake_reference_height(mesh)
  assign(mesh,false)
 for mesh in fitted:
  bake_reference_height(mesh)
  assign(mesh,true)
 support.text="绑定姿势高度基准 · 动作不会改变转化比例" if not fitted.is_empty() else "当前角色骨架不支持骷髅适配"
 update_effect()
func rebuild_skull():
 for mesh in fitted:
  for i in range(mesh.mesh.get_surface_count()):surfaces.erase(mesh.get_active_material(i))
  mesh.get_parent().remove_child(mesh);mesh.queue_free()
 fitted=FIT.build(rig,skull_control.value)
 for mesh in fitted:
  bake_reference_height(mesh);assign(mesh,true)
 update_effect()
func bake_reference_height(instance:MeshInstance3D):
 preload("res://scripts/spaces/transformation_height.gd").bake(instance,height_bottom,height_top)
func assign(mesh:MeshInstance3D,is_skeleton:bool):
 for i in range(mesh.mesh.get_surface_count()):
  var original=mesh.get_active_material(i)
  var material:=ShaderMaterial.new();material.shader=TRANSFORM
  if original is StandardMaterial3D:
   material.set_shader_parameter("base_texture",original.albedo_texture);material.set_shader_parameter("base_color",original.albedo_color)
  material.set_shader_parameter("skeleton_part",is_skeleton)
  mesh.set_surface_override_material(i,material);surfaces.append(material)
func update_effect():
 for material in surfaces:
  material.set_shader_parameter("material_style",material_style)
  material.set_shader_parameter("progress",progress);material.set_shader_parameter("mode",mode)
  material.set_shader_parameter("height_min",height_bottom);material.set_shader_parameter("height_max",height_top)
  material.set_shader_parameter("opacity",opacity);material.set_shader_parameter("emission_strength",energy);material.set_shader_parameter("glow_color",glow)
 if progress_control:progress_control.set_value_no_signal(progress)
func _process(dt:float):
 super(dt)
 if not effect_ready:return
 # Disable the unrelated hair burst controller in this standalone editor.
 if burst:burst.remaining=0
 if effect_playing:
  progress=minf(1,progress+dt/duration)
  if progress>=1:effect_playing=false
  update_effect()
func save_preset():
 var name:=preset_name.text.strip_edges()
 if name.is_empty():name="转化方案"
 var config:=ConfigFile.new();config.load(SAVE)
 config.set_value("presets",name,{"model":selected_model,"mode":mode,"duration":duration,"opacity":opacity,"energy":energy,"color":glow.to_html(),"head_scale":skull_control.value,"display":display_control.selected,"clip":selected.get("id",""),"material_style":material_style});config.save(SAVE);refresh_presets();support.text="模板已保存："+name
func refresh_presets():
 preset_list.clear();var config:=ConfigFile.new()
 if config.load(SAVE)==OK and config.has_section("presets"):
  for name in config.get_section_keys("presets"):preset_list.add_item(name)
func load_preset(index:int):
 var config:=ConfigFile.new()
 if config.load(SAVE)!=OK:return
 var name:=preset_list.get_item_text(index);var data:Dictionary=config.get_value("presets",name)
 display_control.select(int(data.get("display",0)))
 head_scales[MODELS[int(data.model)].file]=float(data.get("head_scale",head_scales.get(MODELS[int(data.model)].file,1.0)))
 select_model(int(data.model));mode=int(data.mode);mode_control.select(mode)
 material_style=int(data.get("material_style",0));material_control.select(material_style)
 duration_control.value=data.duration;opacity_control.value=data.opacity;energy_control.value=data.energy
 glow=Color(data.color);color_control.color=glow;preset_name.text=name
 for c in clips:
  if c.id==data.get("clip",""):select_clip(c);break
 update_effect()
