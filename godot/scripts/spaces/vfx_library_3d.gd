extends "res://scripts/spaces/character_library.gd"
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LIB="res://assets/fx/epic181/library/"
const GROUPS={"Combat":"战斗","Environment":"环境","Interactive":"交互","Demo":"演示组合","待处理":"待处理","Misc":"其他","2D":"二维"}
const TYPES={"Sword":"剑光","Missiles":"飞弹","Muzzleflash":"释放","Explosions":"爆炸","Magic":"魔法","Lightning":"闪电","Laser":"激光","Healing":"治疗","Zone":"领域","Portals":"传送门","Fire":"火焰","Smoke":"烟雾","Water":"水","Weather":"天气","Blood":"受击","Brawling":"打击"}
const COLORS={"Mixed":"混合 / 其他","Red":"红","Blue":"蓝","Green":"绿","Yellow":"黄","Purple":"紫","Pink":"粉","Orange":"橙","White":"白","Black":"黑","Fire":"火","Water":"水","Dark":"暗","Light":"亮","Gold":"金","Silver":"银"}
var asset_tabs:TabBar
var linked_only:CheckButton
var entries:Array=[]
var filtered:Array=[]
var group_filter:OptionButton
var type_filter:OptionButton
var color_filter:OptionButton
var family_filter:OptionButton
var mode_pick:OptionButton
var results:ItemList
var count_label:Label
var detail:Label
var current_entry:Dictionary={}
var source_slots:OptionButton
var target_slots:OptionButton
var character_pick:OptionButton
var status:Label
var fx_nodes:Array=[]
var spec_cache:Dictionary={}
var pool:Dictionary={}
var targets:Array=[]
var allies:Array=[]
var party:Array=[]
var floor_node:MeshInstance3D
var obstacle:MeshInstance3D
var base_position:=Vector3.ZERO
var target_body:Node3D
var target_motion
var target_center:=Vector3.ZERO
var action_clock:=0.0
var action_length:=1.0
var action_phase:="idle"
var release_at:=.3
var impact_sent:=false
var emitted:=false
var active_fx:Node3D
var shot_position:=Vector3.ZERO
var shot_speed:=8.0
var fx_scale:=1.0
var mount_offset:=Vector3.ZERO
var sword_radius:=1.0
var previous_tip:=Vector3.ZERO
var tip_node:MeshInstance3D
var tip_local:=Vector3.ZERO
var combo_step:=0
var flight_limit:=5.0
var repeat_fx:=false
var camera_mode:=0
var camera_frame:Dictionary={}
var asset_duration:=3.0
var fx_tick:=0.0
var hit_count:=0
var control_loading:=false
var source_positions:Array=[]
var allow_sheet:=true
var raw_radius:=2.0
var raw_focus:=Vector3(0,1,-4)
var calibration_fields:Array=[]
var clip_choice:OptionButton
var camera_picker:OptionButton
var obstacle_toggle:CheckButton
var neutral_background:=Color("27343b")
func _ready():
 DisplayServer.window_set_title("Epic Toon FX · 全量资产与 3D 战斗测试")
 catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"));clips=catalog.clips
 entries=JSON.parse_string(FileAccess.get_file_as_string(LIB+"index.json"))
 build_ui();build_stage()
 selected_model=3;select_model(3);choose_motion("9_EM_Idle");playing=false
 load_formation();refresh_assets()
 var first:=entries.filter(func(e):return e.name=="SwordSlashThinWhite")
 if not first.is_empty():select_entry(first[0],false)
func text_node(parent:Node,text:String)->Label:
 var l:=Label.new();l.text=text;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(l);return l
func option(parent:Node,caption:String,values:Array)->OptionButton:
 text_node(parent,caption);var o:=OptionButton.new();parent.add_child(o)
 for value in values:o.add_item(str(value))
 return o
func button(parent:Node,caption:String,callback:Callable):
 var b:=Button.new();b.text=caption;b.custom_minimum_size.y=32;parent.add_child(b);b.pressed.connect(callback);return b
func build_ui():
 var bg:=ColorRect.new();bg.color=Color("10191e");bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(bg)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(margin)
 for k in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+k,12)
 var row:=HBoxContainer.new();margin.add_child(row)
 var left:=VBoxContainer.new();left.custom_minimum_size.x=300;row.add_child(left)
 text_node(left,"EPIC TOON FX 1.81 · 资产库")
 asset_tabs=TabBar.new();asset_tabs.add_tab("全部特效");asset_tabs.add_tab("飞行道具");left.add_child(asset_tabs)
 asset_tabs.tab_changed.connect(change_asset_tab)
 linked_only=CheckButton.new();linked_only.text="仅看完整出手＋命中配套";linked_only.visible=false;left.add_child(linked_only)
 linked_only.toggled.connect(func(_v):refresh_assets())
 search=LineEdit.new();search.placeholder_text="搜索：名称 / 系列 / Fireball / Sword";left.add_child(search);search.text_changed.connect(func(_v):refresh_assets())
 group_filter=option(left,"用途",["全部"]);type_filter=option(left,"类别",["全部"]);family_filter=option(left,"系列",["全部"]);color_filter=option(left,"配色",["全部"])
 populate_filter(group_filter,"group",GROUPS);populate_filter(type_filter,"category",TYPES);populate_filter(family_filter,"family",{});populate_filter(color_filter,"color",COLORS)
 for picker in [group_filter,type_filter,family_filter,color_filter]:picker.item_selected.connect(func(_i):refresh_assets())
 var sheet:=CheckButton.new();sheet.text="包含原包粒子贴图动画";sheet.button_pressed=true;left.add_child(sheet);sheet.toggled.connect(func(v):allow_sheet=v;refresh_assets())
 count_label=text_node(left,"")
 results=ItemList.new();results.size_flags_vertical=SIZE_EXPAND_FILL;results.custom_minimum_size.y=180;left.add_child(results);results.item_selected.connect(func(i):select_entry(filtered[i]))
 var center:=VBoxContainer.new();center.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(center)
 info=text_node(center,"")
 mode_pick=option(center,"观察方式",["持武器联动 · 共用 3D 空间","原包资产独立观察","游戏队伍站位 · 共用 3D 空间"])
 mode_pick.item_selected.connect(func(_i):stop_action();arrange();play_entry())
 var host:=SubViewportContainer.new();host.stretch=true;host.size_flags_vertical=SIZE_EXPAND_FILL;center.add_child(host);host.gui_input.connect(view_input)
 viewport=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(900,700);viewport.msaa_3d=Viewport.MSAA_2X;host.add_child(viewport)
 var bar:=HBoxContainer.new();center.add_child(bar)
 button(bar,"重新播放",play_entry);button(bar,"停止",stop_action)
 var repeat:=CheckButton.new();repeat.text="循环";bar.add_child(repeat);repeat.toggled.connect(func(v):repeat_fx=v)
 var speed:=OptionButton.new()
 for v in ["0.25 倍速","0.5 倍速","1 倍速"]:speed.add_item(v)
 speed.select(2);bar.add_child(speed);speed.item_selected.connect(func(i):rate=[.25,.5,1.0][i])
 status=text_node(center,"")
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=245;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;row.add_child(scroll)
 var right:=VBoxContainer.new();right.custom_minimum_size.x=228;scroll.add_child(right)
 character_pick=option(right,"测试角色（替换选中站位）",MODELS.map(func(m):return m.name));character_pick.select(3)
 character_pick.item_selected.connect(func(i):stop_action();select_model(i);arrange();play_entry())
 source_slots=option(right,"我方位置",["主角"]);source_slots.item_selected.connect(func(_i):stop_action();arrange();play_entry())
 target_slots=option(right,"敌方目标",["左侧","中间","右侧"]);target_slots.select(1);target_slots.item_selected.connect(func(_i):stop_action();arrange();play_entry())
 clip_choice=option(right,"动作",["自动匹配 / 剑连招轮换","剑 · 连招 1","剑 · 连招 2","剑 · 连招 3","剑 · 连招 4","法师 · 远程施法","法师 · 攻击 1","法师 · 攻击 2","法师 · 特殊施法"])
 var cams:=option(right,"摄像机",["战斗机位","自由旋转","俯视检查"])
 camera_picker=cams;cams.item_selected.connect(func(i):camera_mode=i)
 button(right,"重读已保存机位与站位",func():stop_action();load_formation();arrange())
 text_node(right,"独立观察：拖动转镜头、滚轮缩放。传统场景沿用游戏机位。")
 var backdrop:=option(right,"独立观察底色",["中性灰","深色","浅色"])
 backdrop.item_selected.connect(func(i):
  neutral_background=[Color("27343b"),Color("090d11"),Color("a8b2b8")][i]
  for node in stage.get_children():
   if node is WorldEnvironment:node.environment.background_color=neutral_background)
 var scale_spin:=spin(right,"特效整体尺寸",.05,5,.05,1)
 scale_spin.value_changed.connect(func(v):fx_scale=v)
 var speed_spin:=spin(right,"飞弹速度（米 / 秒）",1,30,.5,8);speed_spin.value_changed.connect(func(v):shot_speed=v)
 for axis in 3:
  var field:=spin(right,["挂点 · 横向","挂点 · 沿武器","挂点 · 法线"][axis],-2,2,.01,0)
  calibration_fields.append(field)
  field.value_changed.connect(func(v):mount_offset[axis]=v)
 var block:=CheckButton.new();obstacle_toggle=block;block.text="显示遮挡测试石柱";right.add_child(block);block.toggled.connect(func(v):obstacle.visible=v)
 detail=text_node(right,"");detail.custom_minimum_size.x=225
 text_node(right,"原素材及发射参数的 Godot 适配。\n下方逐项列出近似 / 缺失组件。\n预览不改变正式战斗或装备存档。")
 # Existing anatomy-based weapon mounting and animation-track code is reused without saving equipment.
 weapon_panel=preload("res://scripts/spaces/weapon_preview.gd").new();add_child(weapon_panel);weapon_panel.hide()
 pack_tabs=TabBar.new();pack_tabs.add_tab("全部");add_child(pack_tabs);pack_tabs.hide()
 categories=OptionButton.new();add_child(categories);categories.hide()
 play_button=Button.new();timeline=HSlider.new();burst_note=Label.new()
 add_child(play_button);add_child(timeline);add_child(burst_note);play_button.hide();timeline.hide();burst_note.hide()
 weapon_panel.setup(self)
func spin(parent:Node,caption:String,low:float,high:float,step:float,value:float)->SpinBox:
 text_node(parent,caption);var s:=SpinBox.new();s.min_value=low;s.max_value=high;s.step=step;s.value=value;parent.add_child(s);return s
func populate_filter(picker:OptionButton,key:String,translations:Dictionary):
 var values:Array=[]
 for e in entries:
  if not str(e[key]).is_empty() and not e[key] in values:values.append(e[key])
 values.sort()
 picker.set_item_metadata(0,"")
 for value in values:
  picker.add_item(translations.get(value,value));picker.set_item_metadata(picker.item_count-1,value)
func change_asset_tab(index:int):
 stop_action()
 for picker in [group_filter,type_filter,family_filter,color_filter]:picker.select(0)
 search.text=""
 linked_only.visible=index==1
 refresh_assets()
 if index==1 and not filtered.is_empty():
  var first=filtered[0]
  for entry in filtered:
   if entry.name=="FireballSoftMissileFire":first=entry;break
  select_entry(first)
func linked_effect(id:String)->Dictionary:
 for entry in entries:
  if entry.id==id and entry.playable:return entry
 return {}
func projectile_entries()->Array:
 # Demo wrappers reference the same projectile file; keep the fullest original pairing.
 var unique:Dictionary={}
 for entry in entries:
  if entry.behavior!="projectile" or not entry.playable:continue
  var previous:Dictionary=unique.get(entry.file,{})
  var score:=int(not entry.get("muzzle_id","").is_empty())+int(not entry.get("impact_id","").is_empty())
  var old_score:=int(not previous.get("muzzle_id","").is_empty())+int(not previous.get("impact_id","").is_empty())
  if previous.is_empty() or score>old_score:unique[entry.file]=entry
 return unique.values()
func refresh_assets():
 if not results:return
 filtered.clear();results.clear()
 var source:Array=projectile_entries() if asset_tabs.current_tab==1 else entries
 for e in source:
  if asset_tabs.current_tab==1 and linked_only.button_pressed and (linked_effect(e.get("muzzle_id","")).is_empty() or linked_effect(e.get("impact_id","")).is_empty()):continue
  if not allow_sheet and e.animated_sheet:continue
  if not search.text.is_empty() and not (e.name+" "+e.family+" "+TYPES.get(e.category,e.category)).to_lower().contains(search.text.to_lower()):continue
  var match_filters:=true
  for pair in [[group_filter,"group"],[type_filter,"category"],[family_filter,"family"],[color_filter,"color"]]:
   var value=pair[0].get_item_metadata(pair[0].selected)
   if value!="" and e[pair[1]]!=value:match_filters=false
  if not match_filters:continue
  filtered.append(e);results.add_item(e.name+("  [待处理]" if not e.playable else ""))
  results.set_item_tooltip(results.item_count-1,e.source)
 count_label.text="%d / %d 项 · 单击播放"%[filtered.size(),source.size()]
func build_stage():
 stage=Node3D.new();viewport.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("152028")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("afc6d0");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-35,0);light.light_energy=1.1;light.shadow_enabled=true;stage.add_child(light)
 floor_node=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(24,28);floor_node.mesh=plane;floor_node.position=Vector3(0,-.025,-6)
 var mat:=StandardMaterial3D.new();mat.albedo_texture=load("res://assets/world-six/forest/ground.png");mat.uv1_scale=Vector3(8,8,1);mat.roughness=1;floor_node.material_override=mat;stage.add_child(floor_node)
 obstacle=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(1.1,2,1);obstacle.mesh=box;obstacle.position=Vector3(.1,1,-5);obstacle.visible=false
 var stone:=StandardMaterial3D.new();stone.albedo_color=Color("69757a");obstacle.material_override=stone;stage.add_child(obstacle)
 camera=Camera3D.new();camera.current=true;camera.fov=48;camera.near=.05;camera.far=150;stage.add_child(camera);distance=8;pitch=.22;yaw=.45
 for i in 3:
  var node=load("res://assets/characters3d/gentleman.glb").instantiate();stage.add_child(node);disable_players(node)
  var r=find_rig(node);node.scale=Vector3.ONE*1.8/(r.get_bone_global_rest(r.find_bone("頭")).origin.y+.2)
  var motion=RETARGET.new();motion.configure(r,catalog.bones)
  for c in clips:
   if c.id=="9_EM_Idle":motion.load_clip(c);motion.apply(0);break
  node.position=Vector3((i-1)*1.8,0,-8);targets.append({"body":node,"motion":motion,"rig":r})
func load_formation():
 var snapshot=preload("res://scripts/spaces/shader_game_preview.gd").new();add_child(snapshot);snapshot.hide();snapshot.setup("");snapshot.set_process(false)
 party.clear();source_slots.clear()
 camera_frame=snapshot.app.live_template.data.get("frames",{}).get("battle",{}).duplicate()
 for unit in snapshot.app.model.player:
  var actor=snapshot.app.arena.equipped_actors.get(unit.uid)
  var slot:Dictionary=snapshot.app.arena.world_slots.get(unit.uid,{}).duplicate()
  var item={"name":unit.get("name",unit.cardId),"file":actor.model_key if actor else "","slot":slot,"texture":snapshot.app.arena.scene_art(unit,"player")}
  party.append(item);source_slots.add_item(item.name)
 snapshot.queue_free()
 if party.is_empty():party.append({"name":"测试角色","file":MODELS[selected_model].file,"slot":{"x":-16,"depth":45},"texture":null});source_slots.add_item("测试角色")
 for i in party.size():
  if not party[i].file.is_empty():source_slots.select(i);break
func update_info():
 if info:info.text=current_entry.get("name","请选择资产")+" · "+MODELS[selected_model].name
func slot_position(slot:Dictionary)->Vector3:
 return Vector3(float(slot.get("x",0))*.05,0,-float(slot.get("depth",45))*.05)
func arrange():
 for node in allies:node.queue_free()
 allies.clear()
 var battle:=mode_pick.selected==2
 base_position=slot_position(party[source_slots.selected].slot) if battle else Vector3(0,0,-2.7)
 model.position=base_position;model.rotation.y=PI;model.visible=mode_pick.selected!=1
 for i in targets.size():targets[i].body.visible=mode_pick.selected!=1;targets[i].body.position=Vector3((i-1)*1.8,0,-8)
 if battle:
  for i in party.size():
   if i==source_slots.selected:continue
   var p:Dictionary=party[i];var node:Node3D
   if not p.file.is_empty():
    node=load("res://assets/characters3d/"+p.file).instantiate();stage.add_child(node);disable_players(node);var r=find_rig(node)
    node.scale=Vector3.ONE*1.8/(r.get_bone_global_rest(r.find_bone("頭")).origin.y+.2)
    var motion=RETARGET.new();motion.configure(r,catalog.bones)
    for c in clips:
     if c.id=="9_EM_Idle":motion.load_clip(c);motion.apply(0);break
    node.rotation.y=PI
   else:
    var sprite:=Sprite3D.new();sprite.texture=p.texture;sprite.pixel_size=.002;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
    node=sprite;stage.add_child(node)
   node.position=slot_position(p.slot)
   if p.file.is_empty():node.position.y=.8+float(p.slot.get("clearance",0))*.025
   allies.append(node)
 target_body=targets[target_slots.selected].body;target_motion=targets[target_slots.selected].motion;target_center=target_body.position+Vector3(0,1.0,0)
func choose_motion(id:String):
 for clip in clips:
  if clip.id==id:select_clip(clip);return
func select_entry(entry:Dictionary,auto_play:bool=true):
 stop_action();current_entry=entry;mount_offset=Vector3.ZERO
 for i in filtered.size():
  if filtered[i].id==entry.id:results.select(i);results.ensure_current_is_visible();break
 for field in calibration_fields:field.set_value_no_signal(0)
 update_info()
 detail.text="%s\n%s · %s\n%d 个粒子层\n%s\n%s"%[entry.name,TYPES.get(entry.category,entry.category),COLORS.get(entry.color,entry.color),entry.layers,"原包粒子贴图动画" if entry.animated_sheet else "无时间序列贴图", "\n".join(entry.warnings) if not entry.warnings.is_empty() else "基础粒子参数已适配"]
 if entry.behavior=="projectile":
  var muzzle:=linked_effect(entry.get("muzzle_id",""))
  var hit:=linked_effect(entry.get("impact_id",""))
  detail.text+="\n\n完整攻击预览\n我方出手："+str(muzzle.get("name","原包未关联"))+"\n飞行："+entry.name+"\n敌方命中："+str(hit.get("name","原包未关联"))+"\n出手时释放，到达目标后播放命中。"
 arrange()
 if auto_play:play_entry()
func equip_for(behavior:String):
 var kind:="sword" if behavior=="slash" else "staff"
 var index:=0
 if behavior not in ["ambient","ground","impact"]:
  for i in weapon_panel.items.size():
   if weapon_panel.items[i].get("kind","")==kind:index=i;break
 weapon_panel.weapon=index;weapon_panel.picker.select(index);weapon_panel.shield_enabled=false;weapon_panel.bind_model();tip_node=null
 if weapon_panel.visual:
  var best={"distance":0.0,"node":null,"point":Vector3.ZERO}
  find_weapon_tip(weapon_panel.visual,grip_position(),best);tip_node=best.node;tip_local=best.point;sword_radius=sqrt(best.distance)
func find_weapon_tip(node:Node,hand:Vector3,best:Dictionary):
 if node is MeshInstance3D:
  var box:AABB=node.mesh.get_aabb()
  for i in 8:
   var point:=box.get_endpoint(i);var d:float=node.to_global(point).distance_squared_to(hand)
   if d>best.distance:best.distance=d;best.node=node;best.point=point
 for child in node.get_children():find_weapon_tip(child,hand,best)
func grip_position()->Vector3:
 if is_instance_valid(weapon_panel.visual):return weapon_panel.visual.global_position
 var bone:=rig.find_bone("手首.R")
 return rig.to_global(rig.get_bone_global_pose(bone).origin) if bone>=0 else model.position+Vector3(0,1,0)
func weapon_tip()->Vector3:
 return tip_node.to_global(tip_local) if is_instance_valid(tip_node) else grip_position()+Vector3(0,.2,0)
func get_spec(entry:Dictionary)->Dictionary:
 if not spec_cache.has(entry.id):spec_cache[entry.id]=JSON.parse_string(FileAccess.get_file_as_string(LIB+entry.file))
 return spec_cache[entry.id]
func create_fx(entry:Dictionary,at:Vector3)->Node3D:
 if not entry.get("playable",false):return null
 var fx:Node3D
 var cached:Array=pool.get(entry.id,[])
 if not cached.is_empty():
  fx=cached.pop_back();fx.age=0;fx.stopped=false;fx.visible=true
  for l in fx.layers:l.particles.clear();l.carry=0;l.burst=0;l.cycle=-1
 else:
  fx=FX.new();stage.add_child(fx);fx.setup(get_spec(entry),camera,LIB);
  if entry.behavior=="slash":
   for layer in fx.layers:
    if int(layer.data.render_mode)==4:layer.data=layer.data.duplicate(true);layer.data.local=true
 fx.set_meta("entry_id",entry.id)
 fx.position=at;fx.basis=Basis.IDENTITY.scaled(Vector3.ONE*fx_scale);fx.last_position=at;fx_nodes.append(fx);return fx
func return_fx(fx:Node3D):
 fx_nodes.erase(fx);fx.visible=false;fx.stopped=true
 var id:String=fx.get_meta("entry_id");var bucket:Array=pool.get(id,[])
 if bucket.size()<3:bucket.append(fx);pool[id]=bucket
 else:fx.queue_free()
 while pool.size()>12:
  var oldest=pool.keys()[0]
  for node in pool[oldest]:node.queue_free()
  pool.erase(oldest)
func stop_action():
 for fx in fx_nodes.duplicate():return_fx(fx)
 active_fx=null;action_phase="idle";playing=false;action_clock=0;impact_sent=false;emitted=false
 if model:model.position=base_position
func play_entry():
 stop_action()
 if current_entry.is_empty() or not current_entry.playable:status.text="该条目尚无可播放的粒子层，请查看右侧说明。";return
 arrange();hit_count=0;equip_for(current_entry.behavior);looping=false
 action_phase="windup";action_clock=0;fx_tick=0;impact_sent=false;emitted=false
 var behavior:String=current_entry.behavior
 if mode_pick.selected==1:
  model.hide();action_phase="asset";playing=false
  active_fx=create_fx(current_entry,Vector3(0,1,-4));asset_duration=3.0
  raw_radius=estimate_radius(get_spec(current_entry));raw_focus=active_fx.position
  if behavior=="projectile":raw_radius=maxf(raw_radius,4.5);raw_focus.z=-7
  if behavior in ["ground","ambient"]:active_fx.position.y=0
 else:
  if behavior=="slash":
   choose_motion("4_Anim_ARPGSamurai_Attack_Combo%d"%(combo_step+1));combo_step=(combo_step+1)%4
  elif behavior in ["projectile","beam","stream","muzzle"]:choose_motion("9_EM_RangeAttack")
  else:choose_motion("9_EM_Attack01")
  if clip_choice.selected>0:
   var id:String="4_Anim_ARPGSamurai_Attack_Combo%d"%clip_choice.selected if clip_choice.selected<5 else ["9_EM_RangeAttack","9_EM_Attack01","9_EM_Attack02","9_EM_Special"][clip_choice.selected-5]
   choose_motion(id)
  action_length=maxf(.6,float(selected.frames-1)/selected.fps);release_at=action_length*(.24 if behavior=="slash" else .38)
  previous_tip=weapon_tip();playing=true
 status.text="播放 "+current_entry.name+" · "+("原包独立粒子观察" if mode_pick.selected==1 else "武器挂点 / 世界坐标 / 深度遮挡")
func matching_impact()->Dictionary:
 if not current_entry.get("impact_id","").is_empty():
  for e in entries:
   if e.id==current_entry.impact_id:return e
 var name:String=current_entry.name
 var direct=name.replace("Missile","Explosion")
 for e in entries:
  if e.name==direct and e.playable:return e
 var candidates=entries.filter(func(e):return e.playable and e.behavior=="impact" and e.color==current_entry.color)
 var token:="SwordHit" if current_entry.behavior=="slash" else "FireballSoft" if name.contains("FireballSoft") else "Fireball" if name.contains("Fireball") else "Magic" if name.contains("Magic") else ""
 if not token.is_empty():
  for e in candidates:
   if e.name.contains(token):return e
 return {}
func impact():
 if impact_sent:return
 impact_sent=true;hit_count+=1
 var related:=matching_impact()
 if not related.is_empty():create_fx(related,target_center)
 for c in clips:
  if c.id=="9_EM_Hit":target_motion.load_clip(c);target_motion.apply(0);break
 if is_instance_valid(active_fx):active_fx.stop_emitting()
 status.text=current_entry.name+" · 已命中目标"+(" · 无对应原包命中特效，未追加替代效果" if related.is_empty() else " · "+related.name)
func swept_hit(a:Vector3,b:Vector3,center:Vector3,radius:float)->bool:
 var delta:=b-a;var t:=clampf((center-a).dot(delta)/maxf(delta.length_squared(),.00001),0,1)
 return (a+delta*t).distance_squared_to(center)<=radius*radius
func slash_frame()->Transform3D:
 var hand:=grip_position();var tip:=weapon_tip();var x:Vector3=(tip-hand).normalized()
 if x.length_squared()<.1:x=Vector3.RIGHT
 var movement:Vector3=tip-previous_tip;var normal:=x.cross(movement).normalized()
 if normal.length_squared()<.1:normal=model.global_basis.z.cross(x).normalized()
 if normal.length_squared()<.1:normal=Vector3.UP
 var y:Vector3=normal.cross(x).normalized()
 return Transform3D(Basis(x,y,normal),hand.lerp(tip,.55)+Basis(x,y,normal)*mount_offset)
func estimate_radius(spec:Dictionary)->float:
 var radius:=1.0
 for layer in spec.layers:
  var size:float=0;var speed:float=0;var life:float=0
  for line in layer.start.startSize:
   for value in line:size=maxf(size,float(value))
  for line in layer.start.startSpeed:
   for value in line:speed=maxf(speed,absf(float(value)))
  for line in layer.start.startLifetime:
   for value in line:life=maxf(life,float(value))
  var shape_radius:=0.0
  for line in layer.shape.radius:
   for value in line:shape_radius=maxf(shape_radius,float(value))
  radius=maxf(radius,minf(25,size*.5+shape_radius+speed*minf(life,.6)))
 return clampf(radius*fx_scale,1.2,25)
func update_camera():
 if camera_mode==1:
  var target:=Vector3(0,1,-4);camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance;camera.look_at(target);camera.fov=48
 elif camera_mode==2:
  camera.position=Vector3(0,12,-4);camera.rotation_degrees=Vector3(-90,0,0);camera.fov=60
 elif mode_pick.selected==1:
  camera.fov=48;camera.position=raw_focus+Vector3(.35,.28,1).normalized()*raw_radius*2.8;camera.look_at(raw_focus)
 elif mode_pick.selected==2:
  camera.position=Vector3(float(camera_frame.get("lateral",0))*.05,float(camera_frame.get("height",38))*.05,-float(camera_frame.get("forward",0))*.05)
  camera.fov=rad_to_deg(2*atan(.5/(.86*float(camera_frame.get("lens",.9)))))
  camera.rotation=Vector3(-atan((.5-float(camera_frame.get("horizon",.235)))*2*tan(deg_to_rad(camera.fov)*.5)),deg_to_rad(camera_frame.get("yaw",0)),0)
 else:
  camera.position=Vector3(4,3,3);camera.look_at(Vector3(0,1,-4));camera.fov=48
func view_input(event:InputEvent):
 super(event)
 if event is InputEventMouseMotion and dragging:camera_mode=1
 if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:camera_mode=1
func _process(dt:float):
 if not stage:return
 var step:=minf(dt,.05)*rate;action_clock+=step
 if not selected.is_empty():
  if playing:elapsed=minf(elapsed+step,float(selected.frames-1)/selected.fps)
  retarget.apply(elapsed)
  weapon_panel.sample_weapon_motion()
 update_camera()
 if action_phase=="asset":
  if current_entry.behavior=="projectile" and is_instance_valid(active_fx):
   active_fx.position.z-=shot_speed*step*.5
   if active_fx.position.z<-12:active_fx.stop_emitting()
  if action_clock>=asset_duration:
   if is_instance_valid(active_fx):active_fx.stop_emitting()
   action_phase="tail"
 elif action_phase=="windup":
  var behavior:String=current_entry.behavior
  if behavior=="slash":
   var direction:Vector3=(target_center-base_position);direction.y=0;direction=direction.normalized()
   var t:=action_clock/action_length;model.position=base_position+direction*.85*smoothstep(0,.22,t)*(1-smoothstep(.68,1,t))
  if not emitted and action_clock>=release_at:
   emitted=true
   var at:=weapon_tip()+mount_offset
   if behavior=="slash":at=slash_frame().origin
   elif behavior in ["impact","ground","ambient"]:at=target_center if behavior=="impact" else target_body.position
   if not current_entry.get("muzzle_id","").is_empty():
    for e in entries:
     if e.id==current_entry.muzzle_id:create_fx(e,at);break
   active_fx=create_fx(current_entry,at)
   if behavior=="projectile":shot_position=at;action_phase="flight"
   elif behavior in ["beam","stream"]:action_phase=behavior
  if behavior=="slash" and is_instance_valid(active_fx):
   var frame:=slash_frame();active_fx.global_transform=frame.scaled_local(Vector3.ONE*fx_scale*maxf(.3,sword_radius))
   if action_clock>=action_length*.46:impact()
  previous_tip=weapon_tip()
  if action_clock>=action_length:
   if is_instance_valid(active_fx):active_fx.stop_emitting()
   model.position=base_position;action_phase="tail"
 elif action_phase=="flight":
  var old:=shot_position;shot_position=shot_position.move_toward(target_center,shot_speed*step)
  if is_instance_valid(active_fx):
   active_fx.position=shot_position
   var heading:=target_center-old
   if heading.length_squared()>.001:active_fx.basis=Basis.looking_at(heading.normalized()).scaled(Vector3.ONE*fx_scale)
  if swept_hit(old,shot_position,target_center,.32):impact();action_phase="tail"
  elif action_clock>flight_limit+action_length:
   if is_instance_valid(active_fx):active_fx.stop_emitting()
   action_phase="tail"
 elif action_phase=="stream":
  if is_instance_valid(active_fx):
   var from:=weapon_tip();var delta:=target_center-from;active_fx.position=from
   if delta.length_squared()>.001:active_fx.basis=Basis.looking_at(delta.normalized()).scaled(Vector3.ONE*fx_scale)
   for layer in active_fx.layers:
    for p in layer.particles:
     var point:Vector3=active_fx.to_global(p.position) if layer.data.get("local",false) else p.position
     if point.distance_to(target_center)<.5:impact()
   if action_clock>release_at+1.5:active_fx.stop_emitting();action_phase="tail"
 elif action_phase=="beam":
  if is_instance_valid(active_fx):
   var from:=weapon_tip();var delta:=target_center-from;active_fx.position=from
   if delta.length_squared()>.001:active_fx.basis=Basis.looking_at(delta.normalized()).scaled(Vector3(fx_scale,fx_scale,delta.length()))
  if action_clock>release_at+.25:impact()
  if action_clock>release_at+1:action_phase="tail"
 for fx in fx_nodes.duplicate():
  fx.advance(step)
  if fx.finished():return_fx(fx)
 if action_phase=="tail" and fx_nodes.is_empty():
  action_phase="idle";model.position=base_position;playing=false
 if repeat_fx and action_phase=="idle" and action_clock>maxf(2,action_length+1):play_entry()
