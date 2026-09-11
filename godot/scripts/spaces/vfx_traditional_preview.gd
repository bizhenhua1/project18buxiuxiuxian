extends Control
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LABELS=["剑光 · 细斩 + 受击","剑光 · 重劈 + 受击","物理受击 · 独立","火球术 · 完整三阶段","火球 · 释放","火球 · 爆裂"]
var specs:Array
var preview:Control
var viewport:SubViewport
var fx_world:Node3D
var camera:Camera3D
var effects:Array=[]
var chosen:=0
var looping:=false
var rate:=1.0
var timer:=10.0
var pending_hit:=false
var projectile:Node3D
var start_point:=Vector3.ZERO
var end_point:=Vector3.ZERO
var flight_duration:=.8
var battle_test:=true
var source_pick:OptionButton
var target_pick:OptionButton
var caption:Label
var background:ColorRect
var scale_factor:=.8
var source_uid:=-1
var target_uid:=-1
func label(text:String)->Label:
 var node:=Label.new();node.text=text;return node
func _ready():
 DisplayServer.window_set_title("VFX 特效预览 · Epic Toon FX 1.81")
 specs=JSON.parse_string(FileAccess.get_file_as_string("res://assets/fx/epic181/effects.json"))
 var bg:=ColorRect.new();bg.color=Color("10191e");bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(bg)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
 add_child(margin);var row:=HBoxContainer.new();margin.add_child(row)
 var panel:=VBoxContainer.new();panel.custom_minimum_size.x=275;row.add_child(panel)
 var title:=label("Epic Toon FX 1.81");title.add_theme_font_size_override("font_size",24);panel.add_child(title)
 for i in LABELS.size():
  var b:=Button.new();b.text=LABELS[i];b.custom_minimum_size.y=42;panel.add_child(b);b.pressed.connect(func():chosen=i;play())
 var mode:=CheckButton.new();mode.text="游戏实际机位与当前队伍";mode.button_pressed=true;panel.add_child(mode);mode.toggled.connect(func(v):battle_test=v;preview.app.visible=v;background.visible=not v;clear_effects())
 panel.add_child(label("攻击者 / 释放位置"));source_pick=OptionButton.new();panel.add_child(source_pick)
 panel.add_child(label("敌方目标 / 命中位置"));target_pick=OptionButton.new();panel.add_child(target_pick)
 var refresh:=Button.new();refresh.text="重新读取游戏站位";panel.add_child(refresh);refresh.pressed.connect(reload_positions)
 var repeat:=Button.new();repeat.text="重新播放";panel.add_child(repeat);repeat.pressed.connect(play)
 var loop:=CheckButton.new();loop.text="循环预览";panel.add_child(loop);loop.toggled.connect(func(v):looping=v)
 var speed:=OptionButton.new()
 for text in ["0.25 倍速","0.5 倍速","1 倍速"]:speed.add_item(text)
 speed.select(2);panel.add_child(speed);speed.item_selected.connect(func(i):rate=[.25,.5,1.0][i])
 panel.add_child(label("整体尺寸（保留原包比例）"));var spin:=SpinBox.new();spin.min_value=.1;spin.max_value=1.5;spin.step=.05;spin.value=scale_factor;panel.add_child(spin);spin.value_changed.connect(func(v):scale_factor=v)
 panel.add_child(label("首批 6 个原包预制体\n网格、贴图、曲线与发射配置适配\n烟雾随机选图，无逐帧播放\nGodot 适配，非 Unity 原生回放\n测试不扣血、不修改存档"))
 var right:=VBoxContainer.new();right.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(right);caption=label("选择左侧效果开始，可更换攻击者和目标。");right.add_child(caption)
 preview=preload("res://scripts/spaces/shader_game_preview.gd").new();right.add_child(preview);preview.setup("")
 background=ColorRect.new();background.set_anchors_and_offsets_preset(PRESET_FULL_RECT);background.color=Color("18252b");background.visible=false;preview.view.add_child(background)
 var overlay:=SubViewportContainer.new();overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT);overlay.stretch=true;overlay.mouse_filter=MOUSE_FILTER_IGNORE;preview.view.add_child(overlay)
 var composite:=ShaderMaterial.new();var composite_shader:=Shader.new();composite_shader.code="shader_type canvas_item; render_mode blend_premul_alpha;";composite.shader=composite_shader;overlay.material=composite
 viewport=SubViewport.new();viewport.size=preview.view.size;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;overlay.add_child(viewport)
 fx_world=Node3D.new();viewport.add_child(fx_world);camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9;camera.position=Vector3(0,0,20);camera.current=true;fx_world.add_child(camera);fill_units()
func reload_positions():
 clear_effects()
 var app=preview.app
 app.live_template.poll(.6)
 app.live_template.prepare_slots(app.model.player,app.arena.equipped_actors.keys())
 for uid in app.live_template.slot_targets:
  if app.arena.world_slots.has(uid):
   for key in ["x","depth","height","clearance"]:
    app.arena.world_slots[uid][key]=app.live_template.slot_targets[uid][key]
 preview.render();fill_units()
func fill_units():
 source_pick.clear();target_pick.clear()
 for unit in preview.app.model.player:source_pick.add_item(unit.get("name",unit.cardId),int(unit.uid))
 for unit in preview.app.model.enemy:target_pick.add_item(unit.get("name",unit.cardId),int(unit.uid))
 for i in source_pick.item_count:
  if preview.app.arena.equipped_actors.has(source_pick.get_item_id(i)):source_pick.select(i);break
func point(uid:int,hand:bool)->Vector3:
 var px:Vector2=preview.app.arena.anchor(uid)
 if battle_test:
  for card in preview.app.arena.cards:
   if card.unit.get("uid",-2)!=uid:continue
   px=card.position+Vector2(card.size.x*.5,(card.size.y-38)*.48)
   var actor=preview.app.arena.equipped_actors.get(uid)
   if hand and actor and actor.rig:
    var bone:int=actor.rig.find_bone("手首.R")
    if bone>=0:
     var projected:Vector2=actor.actor_camera.unproject_position(actor.rig.to_global(actor.rig.get_bone_global_pose(bone).origin))
     px=card.position+projected/Vector2(actor.viewport.size)*Vector2(card.size.x,card.size.y-38)
 else:px=Vector2(preview.view.size)* (Vector2(.29,.64) if hand else Vector2(.66,.40))
 var extent:=Vector2(preview.view.size)
 var pixels_per_unit:=extent.y/9.0
 return Vector3((px.x-extent.x*.5)/pixels_per_unit,(extent.y*.5-px.y)/pixels_per_unit,0)
func add_effect(index:int,at:Vector3)->Node3D:
 var fx:=FX.new();fx_world.add_child(fx);fx.position=at;fx.scale=Vector3.ONE*scale_factor;fx.setup(specs[index],camera);effects.append(fx);return fx
func clear_effects():
 for fx in effects:fx.queue_free()
 effects.clear();projectile=null;pending_hit=false;timer=10
func play():
 if not fx_world:return
 clear_effects();timer=0
 source_uid=source_pick.get_selected_id();target_uid=target_pick.get_selected_id();start_point=point(source_uid,true);end_point=point(target_uid,false)
 caption.text=LABELS[chosen]+" · "+("读取游戏保存的战斗机位与站位" if battle_test else "独立效果观察")
 var actor=preview.app.arena.equipped_actors.get(source_uid)
 if actor:actor.trigger("shot")
 match chosen:
  0,1:add_effect(chosen,start_point);pending_hit=true
  2:add_effect(2,end_point)
  3:
   add_effect(3,start_point);projectile=add_effect(4,start_point);pending_hit=true
  4:add_effect(3,start_point)
  5:add_effect(5,end_point)
func _process(dt:float):
 if not fx_world:return
 dt*=rate;timer+=dt
 for actor in preview.app.arena.equipped_actors.values():actor.advance(dt,"battle",false,1.0,true,1.0)
 if is_instance_valid(projectile) and pending_hit:projectile.position=start_point.lerp(end_point,minf(1,timer/flight_duration))
 if pending_hit and timer>=(flight_duration if chosen==3 else .25):
  add_effect(5 if chosen==3 else 2,end_point);pending_hit=false
  if is_instance_valid(projectile):projectile.stopped=true
  var target_actor=preview.app.arena.equipped_actors.get(target_uid)
  if target_actor:target_actor.trigger("damage")
 for fx in effects.duplicate():
  fx.advance(dt)
  if fx.finished():effects.erase(fx);fx.queue_free()
 if looping and timer>2.5:play()
