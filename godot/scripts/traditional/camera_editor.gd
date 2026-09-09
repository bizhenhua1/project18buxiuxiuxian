extends Control
const DIRECTORY="res://data/traditional_camera_presets"
const STATES=["travel","event","battle"]
const KEYS=["lateral","forward","height","horizon","lens","yaw"]
var app:Control
var viewport:SubViewport
var inputs:Dictionary={}
var snapshots:Dictionary={}
var data:Dictionary={}
var original:Dictionary={}
var frame_key:="battle"
var syncing:=false
var name_field:LineEdit
var templates:OptionButton
var notice:Label
var states:OptionButton
var ready_for_edit:=false
var guide:Control
var show_guides:=true
var publish_path:String=preload("res://scripts/traditional/live_template.gd").ACTIVE
const UNIT_KEYS=["x","depth","height","clearance"]
var unit_inputs:Dictionary={}
var unit_picker:OptionButton
var unit_panel:VBoxContainer
var unit_index:=0
var base_slots:Dictionary={}
var default_units:Array=[]
var unit_hint:Label
const SlotProfiles=preload("res://scripts/traditional/slot_profiles.gd")
var kind_picker:OptionButton
var original_player:Array=[]
var default_profiles:Array=[]

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var layout:=HBoxContainer.new();layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(layout)
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=330;layout.add_child(scroll)
 var panel:=VBoxContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(panel)
 label(panel,"传统模式 · 镜头编辑器")
 states=OptionButton.new()
 for title in ["移动 · 越肩跟随","事件 · 停留 / 选择","战斗 · 战场构图"]:states.add_item(title)
 states.select(2);panel.add_child(states)
 states.item_selected.connect(func(i):frame_key=STATES[i];refresh())
 label(panel,"相对事件停靠点的机位")
 for spec in [["lateral","左右位置",-100,100,.5],["forward","前后位置（正值向前）",-150,100,.5],["height","机位高度",1,140,.5],["horizon","地平线高度比例",-.3,.9,.005],["lens","镜头倍率",.35,2.5,.01],["yaw","左右朝向（度）",-40,40,.5]]:field(panel,spec)
 var help:=Label.new();help.text="地平线比例越小，地平线越靠上。\n传统模式以高度和地平线模拟俯视；\n镜头倍率越大，画面越近。\n调镜头不会重新计算角色站位。";panel.add_child(help)
 var check:=CheckBox.new();check.text="显示中轴 / 地平线 / 构图线";check.button_pressed=true;panel.add_child(check)
 check.toggled.connect(func(v):show_guides=v;if guide:guide.queue_redraw())
 action(panel,"恢复当前情境初始机位",func():if ready_for_edit:data.frames[frame_key]=original.frames[frame_key].duplicate(true);refresh())
 unit_panel=VBoxContainer.new();panel.add_child(unit_panel)
 label(unit_panel,"战斗 · 8个位置 × 角色 / 道具")
 unit_picker=OptionButton.new();unit_panel.add_child(unit_picker)
 unit_picker.item_selected.connect(func(i):unit_index=i;refresh_unit();if guide:guide.queue_redraw())
 kind_picker=OptionButton.new();kind_picker.add_item("角色 · 3D模型");kind_picker.add_item("道具 · 图片");unit_panel.add_child(kind_picker)
 kind_picker.item_selected.connect(func(i):
  if not ready_for_edit:return
  data.battle_slots[unit_index].preview_kind="character" if i==0 else "prop"
  refresh_unit();apply_frame())
 for spec in [["x","左右位置",-120,120,.5],["depth","前后位置（越大越远）",5,220,.5],["height","显示高度 / 尺寸",1,120,.5],["clearance","离地高度（悬浮）",0,100,.5]]:unit_field(spec)
 unit_hint=Label.new();unit_hint.text="每个位置的两种模式分别保存。\n黄色框标出预览物件，切换模式不会覆盖另一套。";unit_panel.add_child(unit_hint)
 action(unit_panel,"恢复此单位初始占位",func():
  if not ready_for_edit:return
  var kind:String=data.battle_slots[unit_index].preview_kind
  data.battle_slots[unit_index][kind]=default_profiles[unit_index][kind].duplicate(true);refresh_unit();apply_frame())
 action(unit_panel,"恢复全部我方初始占位",func():
  if not ready_for_edit:return
  data.battle_slots=default_profiles.duplicate(true);refresh_unit();apply_frame())
 label(panel,"模板 · 保存镜头与战斗占位")
 name_field=LineEdit.new();name_field.text="我的传统镜头方案";panel.add_child(name_field)
 templates=OptionButton.new();panel.add_child(templates)
 action(panel,"保存 / 更新同名模板",save_template)
 action(panel,"读取选中模板",load_selected)
 notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.x=300;notice.text="正在加载传统场景与三个情境……";panel.add_child(notice)
 var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;layout.add_child(right)
 label(right,"传统2.5D实景 · 16:9构图 · 静止关键帧（不运行战斗）")
 var aspect:=AspectRatioContainer.new();aspect.ratio=16.0/9.0;aspect.size_flags_vertical=Control.SIZE_EXPAND_FILL;aspect.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.add_child(aspect)
 var container:=SubViewportContainer.new();container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;aspect.add_child(container)
 viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.world_2d=World2D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.gui_disable_input=true;container.add_child(viewport)
 # Isolated session: never load, write, or reset the player's expedition save.
 var session=get_node("/root/Journey");session.set_process(false)
 session.SAVE="user://traditional-editor-preview.json";session.state=JourneyState.new();session.expedition_active=true
 StyleLibrary.active=true
 var zone:Dictionary=session.state.zones[0];zone.route_kind="straight";zone.route_profile="short_battle";zone.theme="forest";zone.battle_choice=true;session.state.pending=zone.id
 app=load("res://scenes/expedition_route.tscn").instantiate();app.set_meta("traditional_editor",true);viewport.add_child(app);app.set_process(false);app.set_process_input(false)
 await get_tree().process_frame
 app.size=Vector2(1328,890);app.arena.scene_mode=true;app.choose(-1)
 while app.is_social():app.encounter_step+=1
 app.distance=app.stops()[app.encounter_step];app.fork_transit_time=app.FORK_TRANSIT_SECONDS
 app.prepare_encounter();app.phase="travel";app.paused=true;app.bob=false
 var pose:Dictionary=ForestRoute.pose(app.distance,app.branch)
 app.camera=pose.position;app.heading=pose.heading;app.arena.world_anchor=pose.position;app.arena.world_facing=pose.heading
 app.arena.battle_mix=0;app.presentation_camera.reset(app.camera,app.heading,0)
 app._process(0);app._process(0)
 data={"version":1,"mode":"traditional_2_5d","coordinates":"route units; lateral=right, forward=ahead relative to encounter stop; horizon is normalized screen Y","frames":{}}
 take_snapshot("travel")
 app.phase="encounter";app.paused=false
 for i in range(45):app._process(.05)
 take_snapshot("event")
 app.start_battle()
 for i in range(180):
  if app.phase=="battle":break
  app._process(.05)
 app.phase="battle";app.arena.battle_mix=1;app.arena.entrance_progress=1;app.arena.scene_enemy_sources.clear();app.arena.enemies_visible=true
 app.model.paused=true;app.arena._process(0)
 take_snapshot("battle")
 original_player=app.model.player.duplicate(true)
 base_slots=app.arena.world_slots.duplicate(true)
 var occurrences:Dictionary={}
 for unit in app.model.player:
  if not base_slots.has(unit.uid):continue
  var id:String=unit.cardId
  var occurrence:int=occurrences.get(id,0);occurrences[id]=occurrence+1
  var slot:Dictionary=base_slots[unit.uid]
  var entry:Dictionary={"card_id":id,"occurrence":occurrence,"kind":"character" if unit.get("portrait_kind","")=="person" or unit.cardType=="char" else "prop"}
  for key in UNIT_KEYS:entry[key]=slot["clearance" if key=="clearance" else key]
  default_units.append(entry)
  unit_picker.add_item("位置 %d" % default_units.size())
 data.battle_units=default_units.duplicate(true);data.version=3
 data.battle_slots=SlotProfiles.build(data.battle_units);default_profiles=data.battle_slots.duplicate(true)
 original=data.duplicate(true)
 app.paused=true;app.process_mode=Node.PROCESS_MODE_DISABLED
 for child in app.get_children():
  if child is CanvasItem and child!=app.arena:child.hide()
 app.arena.position=Vector2.ZERO
 guide=Control.new();guide.mouse_filter=Control.MOUSE_FILTER_IGNORE;guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);viewport.add_child(guide);guide.draw.connect(draw_guides)
 ready_for_edit=true;refresh();list_templates()
 notice.text="已读取当前传统场景参数。保存包含三个镜头和我方战斗占位；保存后会同步到传统游戏。"
 load_latest()

func take_snapshot(key:String) -> void:
 var r=app.arena.scenery.renderer
 var anchor:Vector2=app.arena.world_anchor
 var delta:Vector2=ForestRoute.to_camera(r.camera_world,anchor,app.arena.world_facing)
 var base_focal:float=maxf(r.minimum_focal,minf(r.view_size.y*.86,r.view_size.x*.72))
 data.frames[key]={"lateral":delta.x,"forward":delta.y,"height":r.camera_height(),"horizon":r.horizon_y()/r.view_size.y,"lens":r.focal()/base_focal,"yaw":rad_to_deg(r.heading-app.arena.world_facing)}
 snapshots[key]={"motion":app.arena.formation_motion.units.duplicate(true),"mix":app.arena.battle_mix,"phase":app.phase,"sources":app.arena.scene_enemy_sources.duplicate(true),"enemies":app.arena.enemies_visible}

func label(parent:Node,text:String) -> void:
 var value:=Label.new();value.text=text;parent.add_child(value)
func action(parent:Node,text:String,callback:Callable) -> void:
 var button:=Button.new();button.text=text;button.pressed.connect(callback);parent.add_child(button)
func field(parent:Node,spec:Array) -> void:
 var row:=HBoxContainer.new();parent.add_child(row)
 var text:=Label.new();text.text=spec[1];text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
 var spin:=SpinBox.new();spin.min_value=spec[2];spin.max_value=spec[3];spin.step=spec[4];spin.custom_minimum_size.x=105;row.add_child(spin);inputs[spec[0]]=spin
 spin.value_changed.connect(func(_value):
  if syncing or not ready_for_edit:return
  for key in KEYS:data.frames[frame_key][key]=inputs[key].value
  apply_frame())
func refresh() -> void:
 if not ready_for_edit:return
 syncing=true
 states.select(STATES.find(frame_key))
 for key in KEYS:inputs[key].value=data.frames[frame_key][key]
 syncing=false;refresh_unit();apply_frame()
func apply_frame() -> void:
 var frame:Dictionary=data.frames[frame_key];var snap:Dictionary=snapshots[frame_key]
 var arena=app.arena;var r=arena.scenery.renderer
 app.phase=snap.phase;arena.battle_mix=snap.mix;arena.enemies_visible=snap.enemies
 arena.scene_enemy_sources=snap.sources.duplicate(true);arena.formation_motion.units=snap.motion.duplicate(true)
 arena.world_slots=base_slots.duplicate(true)
 sync_preview_units()
 if frame_key=="battle":
  for i in range(8):
   var entry:Dictionary=data.battle_slots[i][data.battle_slots[i].preview_kind]
   var unit:Dictionary=app.model.player[i]
   if unit.is_empty():continue
   var slot:Dictionary=arena.world_slots[unit.uid]
   for key in UNIT_KEYS:slot[key]=entry[key]
   slot.right_facing=float(slot.x)>0
   var direction:float=arena.world_facing
   var position:Vector2=arena.world_anchor+Vector2(cos(direction),-sin(direction))*float(slot.x)+Vector2(sin(direction),cos(direction))*float(slot.depth)
   arena.formation_motion.units[unit.uid]={"position":position,"target":position,"velocity":Vector2.ZERO}
   if unit.cardId=="daotong" and arena.seer:arena.seer.body.rotation.y=PI+(.22 if slot.right_facing else -.22)
 arena.scale=Vector2.ONE;arena.position=Vector2.ZERO;arena.size=Vector2(viewport.size);arena.scenery.size=arena.size
 r.editor_camera=frame.duplicate();r.presentation_blend=snap.mix;r.bob_enabled=false;r.presentation_bob=0
 var angle:float=arena.world_facing
 var camera:Vector2=arena.world_anchor+Vector2(cos(angle),-sin(angle))*float(frame.lateral)+Vector2(sin(angle),cos(angle))*float(frame.forward)
 arena.scenery.sync(camera,angle+deg_to_rad(frame.yaw),0,0,app.branch,false,false,app.distance)
 arena._process(0);arena.scenery.sync_projection();r.queue_redraw()
 if guide:guide.queue_redraw()
func draw_guides() -> void:
 if not show_guides or not ready_for_edit:return
 var s:=Vector2(viewport.size);var color:=Color(1,.8,.4,.55)
 guide.draw_line(Vector2(s.x*.5,0),Vector2(s.x*.5,s.y),Color(1,1,1,.22),1)
 guide.draw_line(Vector2(0,s.y*float(data.frames[frame_key].horizon)),Vector2(s.x,s.y*float(data.frames[frame_key].horizon)),color,1)
 for t in [.3333,.6667]:guide.draw_line(Vector2(0,s.y*t),Vector2(s.x,s.y*t),Color(1,1,1,.16),1)
 if frame_key=="battle" and unit_index<data.battle_units.size():
  var unit:Dictionary=app.model.player[unit_index]
  for card in app.arena.cards:
   if card.side=="player" and not unit.is_empty() and card.unit.get("uid")==unit.uid:
    var rect:=Rect2(card.position,card.size-Vector2(0,38))
    guide.draw_rect(rect,Color(1,.8,.25,.9),false,2)
    unit_hint.text="位置 %d · %s" % [unit_index+1,"角色" if data.battle_slots[unit_index].preview_kind=="character" else "道具"]+( "\n当前在画幅外，请调整左右 / 前后位置。" if not Rect2(Vector2.ZERO,s).intersects(rect) else "\n正的前后位置越大，单位离停靠点越远。")
func save_template() -> void:
 if not ready_for_edit:return
 var title:=name_field.text.strip_edges().validate_filename()
 if title.is_empty():notice.text="请填写模板名称。";return
 DirAccess.make_dir_recursive_absolute(DIRECTORY)
 var file=FileAccess.open(DIRECTORY+"/"+title+".json",FileAccess.WRITE)
 if not file:notice.text="保存失败："+error_string(FileAccess.get_open_error());return
 data["name"]=title;file.store_string(JSON.stringify(data,"  "));file.close();list_templates()
 var active:String=publish_path
 var published=FileAccess.open(active+".tmp",FileAccess.WRITE)
 if not published:notice.text="模板已保存，但游戏同步失败，请再次保存。";return
 published.store_string(JSON.stringify(data,"  "));published.close()
 if DirAccess.rename_absolute(active+".tmp",active)!=OK:notice.text="模板已保存，但游戏同步失败，请再次保存。";return
 notice.text="已保存并同步到传统游戏："+title+"\n位置：godot/data/traditional_camera_presets/"
func list_templates() -> void:
 templates.clear()
 for path in DirAccess.get_files_at(DIRECTORY):
  if path.ends_with(".json"):templates.add_item(path)
func valid(value:Variant) -> bool:
 if not value is Dictionary or value.get("mode","")!="traditional_2_5d" or not value.get("frames") is Dictionary:return false
 for state in STATES:
  if not value.frames.get(state) is Dictionary:return false
  for key in KEYS:
   var number=value.frames[state].get(key)
   if not (number is float or number is int) or not is_finite(float(number)):return false
   if number<inputs[key].min_value or number>inputs[key].max_value:return false
 if value.has("battle_slots") and not SlotProfiles.valid(value.battle_slots):return false
 if value.has("battle_units"):
  if not value.battle_units is Array or value.battle_units.size()>64:return false
  var seen:Dictionary={}
  for entry in value.battle_units:
   if not entry is Dictionary or not entry.get("card_id") is String:return false
   if not entry.get("occurrence") is float and not entry.get("occurrence") is int:return false
   if float(entry.occurrence)<0 or float(entry.occurrence)!=floor(float(entry.occurrence)):return false
   var binding:String=entry.card_id+":"+str(int(entry.occurrence))
   if seen.has(binding):return false
   seen[binding]=true
   for key in UNIT_KEYS:
    var number=entry.get(key)
    if not (number is float or number is int) or not is_finite(float(number)):return false
    if number<unit_inputs[key].min_value or number>unit_inputs[key].max_value:return false
 return true
func load_selected() -> void:
 if not ready_for_edit or templates.selected<0:return
 var value=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"/"+templates.get_item_text(templates.selected)))
 if not valid(value):notice.text="模板格式或参数范围不符；需要传统模式镜头模板。";return
 data=value
 # Match by card and duplicate occurrence, never by ephemeral battle UID.
 # Old camera-only templates acquire defaults in memory, without rewriting the file.
 var incoming:Array=data.get("battle_units",[])
 var resolved:Array=default_units.duplicate(true)
 for i in range(resolved.size()):
  for entry in incoming:
   if entry.card_id==resolved[i].card_id and int(entry.occurrence)==int(resolved[i].occurrence):resolved[i]=entry.duplicate(true);break
 data.battle_units=resolved;data.version=3
 if not data.has("battle_slots"):data.battle_slots=SlotProfiles.build(resolved)
 name_field.text=templates.get_item_text(templates.selected).trim_suffix(".json");refresh();notice.text="已读取："+name_field.text+"\n镜头与我方占位仅在编辑器预览，再次保存即可同步到传统游戏。"

func _process(_dt:float) -> void:
 if ready_for_edit and app.arena.size!=Vector2(viewport.size):apply_frame()

func unit_field(spec:Array) -> void:
 var row:=HBoxContainer.new();unit_panel.add_child(row)
 var title:=Label.new();title.text=spec[1];title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title)
 var spin:=SpinBox.new();spin.min_value=spec[2];spin.max_value=spec[3];spin.step=spec[4];spin.custom_minimum_size.x=105;row.add_child(spin);unit_inputs[spec[0]]=spin
 spin.value_changed.connect(func(_value):
  if syncing or not ready_for_edit or frame_key!="battle":return
  for key in UNIT_KEYS:data.battle_slots[unit_index][data.battle_slots[unit_index].preview_kind][key]=unit_inputs[key].value
  apply_frame())
func refresh_unit() -> void:
 unit_panel.visible=frame_key=="battle"
 if not ready_for_edit or data.battle_units.is_empty():return
 unit_index=clampi(unit_index,0,data.battle_units.size()-1);unit_picker.select(unit_index)
 syncing=true
 kind_picker.select(0 if data.battle_slots[unit_index].preview_kind=="character" else 1)
 for key in UNIT_KEYS:unit_inputs[key].value=data.battle_slots[unit_index][data.battle_slots[unit_index].preview_kind][key]
 syncing=false
func find_unit(entry:Dictionary) -> Dictionary:
 var occurrence:=0
 for unit in app.model.player:
  if unit.cardId!=entry.card_id:continue
  if occurrence==int(entry.occurrence):return unit
  occurrence+=1
 return {}
func load_latest() -> void:
 var latest_time:=0;var latest_index:=-1
 for i in range(templates.item_count):
  var path:String=DIRECTORY+"/"+templates.get_item_text(i)
  var time:=FileAccess.get_modified_time(path)
  if time>latest_time and valid(JSON.parse_string(FileAccess.get_file_as_string(path))):latest_index=i;latest_time=time
 if latest_index>=0:templates.select(latest_index);load_selected()

func sync_preview_units() -> void:
 # One cached 3D preview texture can illustrate any number of character slots.
 # Runtime identities stay separate from the slot/type calibration schema.
 var character:Dictionary=original_player.filter(func(u):return u.cardId=="daotong")[0]
 var prop:Dictionary=original_player.filter(func(u):return u.cardId=="waci-yin")[0]
 for i in range(app.model.player.size()):
  var source:Dictionary=original_player[i]
  if frame_key=="battle":source=character if data.battle_slots[i].preview_kind=="character" else prop
  var unit:Dictionary=app.model.player[i]
  unit.clear();unit.merge(source.duplicate(true));unit.uid=original_player[i].uid;unit.index=i
