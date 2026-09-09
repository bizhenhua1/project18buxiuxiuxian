extends Control
const RETARGET=preload("res://scripts/spaces/preview_retarget.gd")
const MODELS=[
 {"name":"先知 · 踏雪来","file":"seer-treading-snow.glb"},
 {"name":"梦游绅士","file":"gentleman.glb"},
 {"name":"作曲家 · 布鲁克斯的颜料师","file":"composer.glb"},
 {"name":"伊莎贝拉","file":"isabella.glb"},
 {"name":"约瑟夫 · 盛夏光影","file":"joseph-summer.glb"},
 {"name":"作曲家 · 澄明的理性","file":"composer-reason.glb"},
 {"name":"作曲家 · 被遗忘的乔治","file":"composer-george.glb"},
 {"name": "赤宴", "file": "scarlet-banquet.glb"},
 {"name": "红蝶 · 十三娘", "file": "geisha-thirteen.glb"},
 {"name": "红夫人 · 悦乐酷洛米", "file": "mary-kuromi.glb"},
 {"name": "击球手 · 冠军舵手", "file": "batter-helmsman.glb"},
 {"name": "拉拉队员 · 奇趣美乐蒂", "file": "cheerleader-melody.glb"},
 {"name": "囚徒", "file": "prisoner.glb"},
 {"name": "摄影师 · 梦境大耳狗", "file": "joseph-cinnamoroll.glb"},
 {"name": "摄影师 · 亡灵之主（老态）", "file": "joseph-necromancer-old.glb"},
 {"name": "摄影师 · 亡灵之主（幼态）", "file": "joseph-necromancer-young.glb"},
 {"name": "古董商 · 填海平", "file": "antiquarian.glb"},
 {"name": "幸运儿 · 蛋小黄的好朋友", "file": "lucky-egg.glb"},
 {"name": "隐士", "file": "hermit.glb"},
 {"name": "愚人金", "file": "fools-gold.glb"},
 {"name": "园丁 · 异想Hello Kitty", "file": "gardener-kitty.glb"},
 {"name": "园丁 · Hello Kitty（達答）", "file": "gardener-kitty-dada.glb"},
 {"name": "KING-h1", "file": "king-h1.glb"},
 {"name": "ROOK", "file": "rook.glb"}]
var weapon_panel:VBoxContainer
var catalog:Dictionary
var clips:Array=[]
var model:Node3D
var rig:Skeleton3D
var retarget=RETARGET.new()
var stage:Node3D
var camera:Camera3D
var viewport:SubViewport
var list:VBoxContainer
var search:LineEdit
var pack_tabs:TabBar
var pack_ids:Array=["all"]
var categories:OptionButton
var info:Label
var counter:Label
var timeline:HSlider
var play_button:Button
var selected:Dictionary={}
var selected_model:=0
var elapsed:=0.0
var playing:=true
var looping:=true
var rate:=1.0
var yaw:=.25
var pitch:=.12
var distance:=4.2
var dragging:=false
var slider_update:=false
var motion_buttons:Array[Button]=[]
var model_buttons:Array[Button]=[]
func _ready() -> void:
 DisplayServer.window_set_title("3D 主角 · 模型与动作预览")
 catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"));clips=catalog.clips
 for c in clips:c.category="制作与采集" if str(c.get("pack",""))=="6" else category(c.name)
 var bg:=ColorRect.new();bg.color=Color("10191e");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for key in ["margin_left","margin_right","margin_top","margin_bottom"]:margin.add_theme_constant_override(key,16)
 add_child(margin)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);margin.add_child(row)
 var left_scroll:=ScrollContainer.new();left_scroll.custom_minimum_size.x=240;left_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;row.add_child(left_scroll)
 var left:=VBoxContainer.new();left.custom_minimum_size.x=220;left_scroll.add_child(left)
 label(left,"角色",24)
 for i in range(MODELS.size()):
  var btn:=Button.new();btn.text=MODELS[i].name;btn.custom_minimum_size=Vector2(220,54);btn.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;left.add_child(btn);btn.toggle_mode=true;model_buttons.append(btn);btn.pressed.connect(select_model.bind(i))
 label(left,"原模型贴图 · 共享动作库",14)
 label(left,"左键拖动：旋转
滚轮：缩放
右侧点击动作播放",16)
 var reset:=Button.new();reset.text="重置镜头";left.add_child(reset);reset.pressed.connect(func():yaw=.25;pitch=.12;distance=4.2)
 var back:=Button.new();back.text="正面 / 背面";left.add_child(back);back.pressed.connect(func():yaw+=PI)
 var fixed:=CheckButton.new();fixed.text="原地预览（锁定水平位移）";fixed.button_pressed=true;left.add_child(fixed);fixed.toggled.connect(func(v):retarget.in_place=v)
 var note:=Label.new();note.text="可在上方武器面板装配手持武器。椅子和载具未装配。
复杂动作的衣摆穿插仍需精修。";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.custom_minimum_size.x=210;left.add_child(note)
 var center:=VBoxContainer.new();center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(center)
 info=label(center,"模型与动作预览",20)
 var container:=SubViewportContainer.new();container.stretch=true;container.size_flags_vertical=Control.SIZE_EXPAND_FILL;container.size_flags_horizontal=Control.SIZE_EXPAND_FILL;center.add_child(container)
 viewport=SubViewport.new();viewport.size=Vector2i(700,750);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X;container.add_child(viewport)
 container.gui_input.connect(view_input)
 stage=Node3D.new();viewport.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("19262d");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("bdced7");env.environment.ambient_light_energy=.55;stage.add_child(env)
 for spec in [[Vector3(-35,-25,0),.85],[Vector3(-25,135,0),.65]]:
  var light:=DirectionalLight3D.new();light.rotation_degrees=spec[0];light.light_energy=spec[1];stage.add_child(light)
 var floor_mesh:=MeshInstance3D.new();var plane:=CylinderMesh.new();plane.top_radius=1.4;plane.bottom_radius=1.4;plane.height=.06;floor_mesh.mesh=plane;floor_mesh.position.y=-.05
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("304048");floor_mesh.material_override=mat;stage.add_child(floor_mesh)
 camera=Camera3D.new();camera.fov=38;camera.current=true;stage.add_child(camera)
 timeline=HSlider.new();timeline.step=.001;center.add_child(timeline);timeline.value_changed.connect(func(v):
  if not slider_update:elapsed=v;retarget.apply(elapsed))
 var bar:=HBoxContainer.new();center.add_child(bar)
 play_button=Button.new();play_button.text="暂停";bar.add_child(play_button);play_button.pressed.connect(func():playing=not playing;play_button.text="暂停" if playing else "播放")
 var restart:=Button.new();restart.text="从头播放";bar.add_child(restart);restart.pressed.connect(func():elapsed=0;playing=true;play_button.text="暂停")
 var loop:=CheckButton.new();loop.text="循环";loop.button_pressed=true;bar.add_child(loop);loop.toggled.connect(func(v):looping=v)
 var speed:=OptionButton.new()
 for v in ["0.25×","0.5×","1×","1.5×","2×"]:speed.add_item(v)
 speed.select(2);bar.add_child(speed);speed.item_selected.connect(func(i):rate=[.25,.5,1.0,1.5,2.0][i])
 var right:=VBoxContainer.new();right.custom_minimum_size.x=335;row.add_child(right)
 label(right,"动作库",24);counter=label(right,"",14)
 pack_tabs=TabBar.new();pack_tabs.tab_alignment=TabBar.ALIGNMENT_LEFT;pack_tabs.scrolling_enabled=true;right.add_child(pack_tabs);pack_tabs.add_tab("全部")
 for pack in catalog.get("packs",[]):
  pack_ids.append(str(pack.id));pack_tabs.add_tab(pack.label);pack_tabs.set_tab_tooltip(pack_tabs.tab_count-1,"%s · %d 段"%[pack.label,pack.count])
 pack_tabs.tab_changed.connect(func(_i):refresh_list())
 search=LineEdit.new();search.placeholder_text="搜索动作名称，例如 Walk、Idle";right.add_child(search);search.text_changed.connect(func(_v):refresh_list())
 categories=OptionButton.new();right.add_child(categories);categories.add_item("全部")
 for c in ["移动与待机","攻击与施法","防御与闪避","受击与死亡","跳跃与翻越","制作与采集","交互与其他"]:categories.add_item(c)
 categories.item_selected.connect(func(_i):refresh_list())
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;right.add_child(scroll)
 list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
 weapon_panel=preload("res://scripts/spaces/weapon_preview.gd").new();left.add_child(weapon_panel);left.move_child(weapon_panel,1);weapon_panel.setup(self)
 select_model(0);refresh_list()
 var initial:Array=clips.filter(func(c):return c.name=="EM_Idle")
 if not initial.is_empty():select_clip(initial[0])
func label(parent:Node,text:String,font_size:int) -> Label:
 var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",font_size);parent.add_child(l);return l
func category(name:String) -> String:
 var n:=name.to_lower()
 if matches(n,["death","dead","die_","_die","hit","hurt","damage","knock"]):return "受击与死亡"
 if matches(n,["dodge","block","parry","guard","defend","evade","roll"]):return "防御与闪避"
 if matches(n,["attack","punch","kick","shoot","cast","special","combo","thrust","haymaker","backhand","swing","slash","equip","draw","sheath"]):return "攻击与施法"
 if matches(n,["jump","vault","fall","airborne","landing"]):return "跳跃与翻越"
 if matches(n,["walk","run","idle","turn","strafe","crouch","crawl","sprint","jog","brake","locomotion"]):return "移动与待机"
 return "交互与其他"
func matches(n:String,words:Array) -> bool:
 for word in words:
  if n.contains(word):return true
 return false
func refresh_list() -> void:
 for child in list.get_children():list.remove_child(child);child.queue_free()
 motion_buttons.clear()
 var group:=categories.get_item_text(categories.selected);var found:=0
 for clip in clips:
  if pack_tabs.current_tab>0 and str(clip.get("pack",""))!=pack_ids[pack_tabs.current_tab]:continue
  if group!="全部" and clip.category!=group:continue
  if not search.text.is_empty() and not str(clip.name).to_lower().contains(search.text.to_lower()):continue
  found+=1
  var b:=Button.new();b.text=clip.name;b.tooltip_text=str(clip.get("group",""))+" · "+clip.category+" · %.2f 秒"%((clip.frames-1)/clip.fps);b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;b.custom_minimum_size=Vector2(310,34);b.toggle_mode=true;b.button_pressed=selected.get("id","")==clip.id;list.add_child(b);b.pressed.connect(select_clip.bind(clip));motion_buttons.append(b)
 counter.text="%d / %d 段 · 点击播放"%[found,clips.size()]
func find_rig(node:Node) -> Skeleton3D:
 if node is AnimationPlayer:node.active=false
 if node is Skeleton3D:return node
 for child in node.get_children():
  var result:=find_rig(child)
  if result:return result
 return null
func disable_players(node:Node) -> void:
 if node is AnimationPlayer:node.active=false
 for child in node.get_children():disable_players(child)
func select_model(index:int) -> void:
 selected_model=index
 for i in range(model_buttons.size()):model_buttons[i].button_pressed=i==index
 if model:stage.remove_child(model);model.queue_free()
 model=load("res://assets/characters3d/"+MODELS[index].file).instantiate();stage.add_child(model);disable_players(model)
 rig=find_rig(model);retarget.configure(rig,catalog.bones)
 var head:=rig.find_bone("頭")
 if head<0:head=rig.find_bone("頭調整")
 var height:float=rig.get_bone_global_rest(head).origin.y+.20 if head>=0 else 1.8
 model.scale=Vector3.ONE*1.8/maxf(height,.1)
 if not selected.is_empty():retarget.apply(elapsed)
 if weapon_panel:weapon_panel.bind_model()
 update_info()
func select_clip(clip:Dictionary) -> void:
 selected=clip;retarget.load_clip(clip);elapsed=0;playing=true;play_button.text="暂停";timeline.max_value=(clip.frames-1)/clip.fps;retarget.apply(0)
 for b in motion_buttons:b.button_pressed=b.text==clip.name
 update_info()
func update_info() -> void:
 info.text=MODELS[selected_model].name+"
"+str(selected.get("name","请选择动作"))
func _process(dt:float) -> void:
 if not selected.is_empty():
  var duration:float=(selected.frames-1)/selected.fps
  if playing:
   elapsed+=dt*rate
   if elapsed>duration:
    if looping:elapsed=fmod(elapsed,maxf(duration,.001))
    else:elapsed=duration;playing=false;play_button.text="播放"
  retarget.apply(elapsed)
  slider_update=true;timeline.value=elapsed;slider_update=false
 if weapon_panel:weapon_panel.sample_weapon_motion()
 if camera:
  var target:=Vector3(0,.95,0);camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance;camera.look_at(target)
func view_input(event:InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
  if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:distance=maxf(1.4,distance*.9)
  if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance=minf(12,distance/.9)
 if event is InputEventMouseMotion and dragging:yaw-=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.005,-.5,1.1)
