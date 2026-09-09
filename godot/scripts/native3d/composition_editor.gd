extends Control
const DIRECTORY="res://data/native3d_camera_presets"
const STATES=["travel","event","battle"]
var viewport:SubViewport
var world:Node3D
var frame_key:="battle"
var data:Dictionary
var states:OptionButton
var units:OptionButton
var unit_index:=0
var inputs:Dictionary={}
var syncing:=false
var name_field:LineEdit
var templates:OptionButton
var notice:Label
var visible_check:CheckBox
var marker:MeshInstance3D
var preview_time:=-1.0
var preview_from:Dictionary
var preview_to:Dictionary
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var layout:=HBoxContainer.new();layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(layout)
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=310;layout.add_child(scroll)
 var panel:=VBoxContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(panel)
 var title:=Label.new();title.text="镜头与站位编辑器";title.add_theme_font_size_override("font_size",23);panel.add_child(title)
 states=OptionButton.new()
 for label in ["移动 · 默认跟随","事件 · 停留 / 选择","战斗 · 阵列构图"]:states.add_item(label)
 states.select(2);panel.add_child(states);states.item_selected.connect(func(i):capture();frame_key=STATES[i];refresh())
 label(panel,"镜头 · 位置与朝向")
 for spec in [["cx","左右位置",-20,20,.05],["cy","机位高度",.1,10,.05],["cz","前后位置",-20,20,.05],["pitch","俯仰角（负值向下）",-70,30,.5],["yaw","左右朝向",-90,90,.5],["fov","视野角度",20,100,1]]:field(panel,spec)
 label(panel,"事件点 · 同时作为构图参考点")
 for spec in [["ex","事件点左右",-20,20,.1],["ez","事件点前后",-30,10,.1]]:field(panel,spec)
 var marks:=CheckBox.new();marks.text="显示事件点标记";marks.button_pressed=true;panel.add_child(marks);marks.toggled.connect(func(v):if marker:marker.visible=v)
 label(panel,"角色与道具 · 独立空间站位")
 units=OptionButton.new()
 for value in ["我方 · 主角","我方 · 伊莎贝拉","我方 · 怀表","我方 · 书籍","敌方 · 左","敌方 · 中","敌方 · 右"]:units.add_item(value)
 panel.add_child(units);units.item_selected.connect(func(i):capture();unit_index=i;refresh())
 for spec in [["ux","左右位置",-20,20,.05],["uy","离地高度",-2,8,.05],["uz","前后位置",-30,15,.05],["turn","朝向角度",-180,180,1],["scale","显示尺寸",.2,3,.05]]:field(panel,spec)
 visible_check=CheckBox.new();visible_check.text="当前情境显示此单位";panel.add_child(visible_check);visible_check.toggled.connect(func(_v):changed())
 var names:=CheckBox.new();names.text="显示单位名称（辅助找站位）";panel.add_child(names)
 names.toggled.connect(func(v):
  if not world:return
  for i in range(world.health_labels.size()):
   world.health_labels[i].text=units.get_item_text(i);world.health_labels[i].visible=v)
 var plants:=CheckBox.new();plants.text="临时隐藏植被，检查遮挡";panel.add_child(plants)
 plants.toggled.connect(func(v):
  if not world:return
  for node in world.get_children():
   if node is MultiMeshInstance3D:node.visible=not v)
 label(panel,"模板 · 保存所有三个情境")
 name_field=LineEdit.new();name_field.text="我的镜头方案";panel.add_child(name_field)
 templates=OptionButton.new();panel.add_child(templates)
 action(panel,"保存 / 更新同名模板",save_template)
 action(panel,"读取选中模板",load_selected)
 action(panel,"恢复参考默认值",func():data=defaults();refresh())
 action(panel,"预览：移动 → 事件",func():start_preview("travel","event"))
 action(panel,"预览：事件 → 战斗",func():start_preview("event","battle"))
 action(panel,"预览：战斗 → 移动",func():start_preview("battle","travel"))
 action(panel,"停止预览，回到关键帧",func():preview_time=-1;refresh())
 notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.x=280;notice.text="负的前后坐标表示前方。预览仅用于比较关键帧，不代表最终过渡算法。";panel.add_child(notice)
 var right_panel:=VBoxContainer.new();right_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;layout.add_child(right_panel)
 var hint:=Label.new();hint.text="实时原生3D画面 · 修改后立即生效 · 存档包含镜头、我方、敌方及事件点";right_panel.add_child(hint)
 var aspect:=AspectRatioContainer.new();aspect.ratio=16.0/9.0;aspect.size_flags_vertical=Control.SIZE_EXPAND_FILL;aspect.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right_panel.add_child(aspect)
 var container:=SubViewportContainer.new();container.stretch=true;container.size_flags_horizontal=Control.SIZE_EXPAND_FILL;container.size_flags_vertical=Control.SIZE_EXPAND_FILL;aspect.add_child(container)
 viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
 world=load("res://scenes/native3d_forest.tscn").instantiate();world.set_meta("composition_editor",true);viewport.add_child(world);world.set_process(false)
 for child in world.get_children():
  if child is CanvasLayer:child.hide()
 for node in world.party+world.enemies:
  if node.has_method("advance"):node.advance(.01,Vector3.ZERO)
 for item in world.health_labels:item.visible=false
 marker=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.22;ring.outer_radius=.30;marker.mesh=ring
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("e8ba57");marker.material_override=mat;world.add_child(marker)
 data=defaults();refresh();list_templates()
func label(parent:Node,text:String) -> void:
 var node:=Label.new();node.text=text;parent.add_child(node)
func action(parent:Node,text:String,callback:Callable) -> void:
 var button:=Button.new();button.text=text;button.pressed.connect(callback);parent.add_child(button)
func field(parent:Node,spec:Array) -> void:
 var row:=HBoxContainer.new();parent.add_child(row);var text:=Label.new();text.text=spec[1];text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
 var spin:=SpinBox.new();spin.min_value=spec[2];spin.max_value=spec[3];spin.step=spec[4];spin.custom_minimum_size.x=100;row.add_child(spin);inputs[spec[0]]=spin;spin.value_changed.connect(func(_v):changed())
func defaults() -> Dictionary:
 var result:Dictionary={"version":1,"coordinate_system":"Godot metres, +Y up, -Z forward; origin is route arrival point","frames":{}}
 for key in STATES:
  var poses:Array=[]
  var locations:=[[-1.35,0,-1.7],[1.4,0,-1.3],[-.35,1.1,-3.4],[.85,1.1,-3.1],[-1.8,0,-10],[0,0,-10.5],[1.8,0,-10]]
  for i in range(7):
   var position:Array=locations[i].duplicate()
   if key!="battle" and i<4:position=[-.55+i*.15,0 if i<2 else 1.1,i*.45]
   poses.append({"position":position,"yaw":180.0 if i<2 else 0.0,"scale":1.0,"visible":key=="battle" or i==0 or (key=="event" and i>=4)})
  result.frames[key]={"camera":{"position":[0,1.6,1.0] if key=="battle" else [0,1.4,1.05],"pitch":-6.0 if key=="battle" else 0.0,"yaw":0.0,"fov":57.0},"event":[0,0,-5],"units":poses}
 return result
func capture() -> void:
 if syncing or data.is_empty():return
 var frame:Dictionary=data.frames[frame_key]
 frame.camera={"position":[inputs.cx.value,inputs.cy.value,inputs.cz.value],"pitch":inputs.pitch.value,"yaw":inputs.yaw.value,"fov":inputs.fov.value}
 frame.event=[inputs.ex.value,0,inputs.ez.value]
 frame.units[unit_index]={"position":[inputs.ux.value,inputs.uy.value,inputs.uz.value],"yaw":inputs.turn.value,"scale":inputs.scale.value,"visible":visible_check.button_pressed}
func changed() -> void:
 if syncing or data.is_empty():return
 preview_time=-1;capture();apply_frame(data.frames[frame_key])
func refresh() -> void:
 if data.is_empty():return
 syncing=true
 var frame:Dictionary=data.frames[frame_key];var cam:Dictionary=frame.camera;var unit:Dictionary=frame.units[unit_index]
 var values:Dictionary={"cx":cam.position[0],"cy":cam.position[1],"cz":cam.position[2],"pitch":cam.pitch,"yaw":cam.yaw,"fov":cam.fov,"ex":frame.event[0],"ez":frame.event[2],"ux":unit.position[0],"uy":unit.position[1],"uz":unit.position[2],"turn":unit.yaw,"scale":unit.scale}
 for key in values:inputs[key].value=values[key]
 visible_check.button_pressed=unit.visible;syncing=false;apply_frame(frame)
func vector(value:Array) -> Vector3:return Vector3(value[0],value[1],value[2])
func apply_frame(frame:Dictionary) -> void:
 world.camera.position=vector(frame.camera.position);world.camera.rotation_degrees=Vector3(frame.camera.pitch,frame.camera.yaw,0);world.camera.fov=frame.camera.fov
 var nodes:Array=world.party+world.enemies
 for i in range(nodes.size()):
  var pose:Dictionary=frame.units[i];nodes[i].position=vector(pose.position);nodes[i].rotation_degrees.y=pose.yaw;nodes[i].scale=Vector3.ONE*pose.scale;nodes[i].visible=pose.visible
 marker.position=vector(frame.event)+Vector3.UP*.025
 world.lamp.position=world.party[0].position+Vector3(.65,1.1,-.6)
func save_template() -> void:
 capture()
 var name:=name_field.text.strip_edges().validate_filename()
 if name.is_empty():notice.text="请填写模板名称。";return
 DirAccess.make_dir_recursive_absolute(DIRECTORY)
 var path:=DIRECTORY.path_join(name+".json")
 var file:=FileAccess.open(path,FileAccess.WRITE)
 if not file:notice.text="保存失败："+error_string(FileAccess.get_open_error());return
 file.store_string(JSON.stringify(data,"\t"));file.close();notice.text="已保存全部关键帧：\n"+ProjectSettings.globalize_path(path);list_templates()
func list_templates() -> void:
 templates.clear();DirAccess.make_dir_recursive_absolute(DIRECTORY)
 for file in DirAccess.get_files_at(DIRECTORY):
  if file.ends_with(".json"):templates.add_item(file)
func load_selected() -> void:
 if templates.item_count==0:return
 var path:=DIRECTORY.path_join(templates.get_item_text(templates.selected))
 var value=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not valid(value):notice.text="模板格式不完整，未覆盖当前设置。";return
 data=value;name_field.text=templates.get_item_text(templates.selected).trim_suffix(".json");preview_time=-1;refresh();notice.text="已读取三个情境。"
func valid(value) -> bool:
 if not value is Dictionary or value.get("version",0)!=1 or not value.has("frames"):return false
 for key in STATES:
  if not value.frames.has(key):return false
  var frame=value.frames[key]
  if not frame is Dictionary or not frame.has_all(["camera","event","units"]) or frame.units.size()!=7:return false
  if not frame.camera.has_all(["position","pitch","yaw","fov"]):return false
  if frame.camera.position.size()!=3 or frame.event.size()!=3:return false
  for unit in frame.units:
   if not unit.has_all(["position","yaw","scale","visible"]) or unit.position.size()!=3:return false
 return true
func start_preview(a:String,b:String) -> void:
 capture();preview_from=data.frames[a].duplicate(true);preview_to=data.frames[b].duplicate(true);preview_time=0
func _process(dt:float) -> void:
 if preview_time<0:return
 preview_time+=dt;var t:=smoothstep(0,2.0,preview_time)
 var frame:Dictionary=preview_to.duplicate(true)
 var pos:=vector(preview_from.camera.position).lerp(vector(preview_to.camera.position),t)
 frame.camera.position=[pos.x,pos.y,pos.z]
 for key in ["pitch","yaw","fov"]:frame.camera[key]=lerpf(preview_from.camera[key],preview_to.camera[key],t)
 for i in range(7):
  var a:Dictionary=preview_from.units[i];var b:Dictionary=preview_to.units[i]
  var location:=vector(a.position).lerp(vector(b.position),t)
  frame.units[i].position=[location.x,location.y,location.z];frame.units[i].visible=a.visible or b.visible
  frame.units[i].yaw=rad_to_deg(lerp_angle(deg_to_rad(a.yaw),deg_to_rad(b.yaw),t));frame.units[i].scale=lerpf(a.scale,b.scale,t)
 apply_frame(frame)
 if preview_time>=2:preview_time=-1;apply_frame(preview_to)
