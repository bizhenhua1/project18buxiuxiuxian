extends "res://scripts/spaces/vfx_library_3d.gd"
## Traditional gameplay remains 2.5D. The particle viewport is a projected overlay,
## never a replacement battlefield or a second source of character positions.
var game_preview
var game_actor
var game_card:Control
var driver_rig:Skeleton3D
var actor_origin:=Vector3.ZERO
var hand_pixel:=Vector2.ZERO
var last_tip_pixel:=Vector2.ZERO
var launch_pixel:=Vector2.ZERO
var arrival_pixel:=Vector2.ZERO
var launch_depth:=1.0
var arrival_depth:=1.0
var source_scale:=1.0
var arrival_scale:=1.0
var flight_fraction:=0.0
var flight_distance:=1.0
var saved_camera:Camera3D
var traditional_ready:=false
var overlay_host:SubViewportContainer
var missile_light_enabled:=true
var missile_light_energy:=.9
var missile_light_radius:=75.0
var missile_light_color:=Color("87cfff")
var missile_burst_enabled:=true
var missile_burst_energy:=1.25
var missile_burst_radius:=90.0
var missile_burst_duration:=.65
var missile_burst_rise:=.06
var missile_burst_color:=Color("a2dcff")
var light_profiles:Dictionary={}
var light_fields:Dictionary={}
var light_panel:VBoxContainer
var light_profile_path:="user://projectile-light-profiles.json"
const LIGHT_DEFAULTS={"missile_light_enabled":false,"missile_light_energy":.9,"missile_light_radius":75.0,"missile_light_color":"87cfff","missile_burst_enabled":true,"missile_burst_energy":1.25,"missile_burst_radius":90.0,"missile_burst_duration":.65,"missile_burst_rise":.06,"missile_burst_color":"a2dcff"}
var missile_light_position:=Vector3.ZERO
var missile_light_tail:=0.0
var missile_burst_age:=-1.0
var missile_light_base:Array[Dictionary]=[]
var missile_light_bound:=false
func build_ui():
 if FileAccess.file_exists(light_profile_path):
  var stored=JSON.parse_string(FileAccess.get_file_as_string(light_profile_path))
  if stored is Dictionary:light_profiles=stored
 super()
 var parent_panel=detail.get_parent()
 var panel:=VBoxContainer.new();parent_panel.add_child(panel)
 parent_panel.move_child(panel,target_slots.get_index()+1)
 button(panel,"StormMissile · 点光源实验",func():
  mode_pick.select(0);stop_action();arrange()
  for entry in projectile_entries():
   if entry.name.begins_with("StormMissile"):select_entry(entry);break)
 light_panel=VBoxContainer.new();panel.add_child(light_panel)
 for item in [["missile_light_enabled","启用当前子弹模拟光源"],["missile_burst_enabled","启用爆炸光源"]]:
  var field:=CheckButton.new();field.text=item[1];light_panel.add_child(field);light_fields[item[0]]=field
  field.toggled.connect(func(v):set(item[0],v))
 for item in [["missile_light_energy","飞行 · 强度",0,5,.05],["missile_light_radius","飞行 · 范围",1,220,1],["missile_burst_energy","爆炸 · 峰值强度",0,5,.05],["missile_burst_radius","爆炸 · 最大范围",1,300,1],["missile_burst_duration","爆炸 · 持续秒数",.1,3,.05],["missile_burst_rise","爆炸 · 达峰秒数",.01,.5,.01]]:
  var field:=spin(light_panel,item[1],item[2],item[3],item[4],get(item[0]));light_fields[item[0]]=field
  field.value_changed.connect(func(v):set(item[0],v))
 for item in [["missile_light_color","飞行 · 颜色"],["missile_burst_color","爆炸 · 颜色"]]:
  text_node(light_panel,item[1]);var field:=ColorPickerButton.new();field.edit_alpha=false;light_panel.add_child(field);light_fields[item[0]]=field
  field.color_changed.connect(func(v):set(item[0],v))
 button(light_panel,"保存当前子弹光源配置",save_light_profile)
 button(light_panel,"恢复当前子弹默认值",func():load_light_profile({}))
 text_node(panel,"实验仅作用于传统预览的地面与场景精灵；独立角色模型照明尚未桥接。")
func select_entry(entry:Dictionary,auto_play:bool=true):
 super(entry,false)
 load_light_profile(light_profiles.get(str(entry.get("file","")),{}))
 if light_panel:light_panel.visible=entry.get("behavior","")=="projectile"
 if auto_play:play_entry()
func load_light_profile(saved:Dictionary):
 for key in LIGHT_DEFAULTS:
  var value=saved.get(key,LIGHT_DEFAULTS[key])
  if key=="missile_light_enabled" and not saved.has(key):value=str(current_entry.get("name","")).begins_with("StormMissile")
  if key.ends_with("color"):value=Color(str(value))
  set(key,value)
  var field=light_fields.get(key)
  if field is CheckButton:field.set_pressed_no_signal(value)
  elif field is SpinBox:field.set_value_no_signal(value)
  elif field is ColorPickerButton:field.color=value
func save_light_profile():
 if current_entry.get("behavior","")!="projectile":return
 var profile:Dictionary={}
 for key in LIGHT_DEFAULTS:
  profile[key]=get(key).to_html(false) if key.ends_with("color") else get(key)
 light_profiles[str(current_entry.file)]=profile
 var file=FileAccess.open(light_profile_path,FileAccess.WRITE)
 if not file:status.text="光源配置保存失败";return
 file.store_string(JSON.stringify(light_profiles,"  "))
 status.text=current_entry.name+" · 光源配置已保存，下次选择自动读取"
func traditional()->bool:return traditional_ready and mode_pick.selected==0
func _ready():
 super()
 driver_rig=rig
 overlay_host=viewport.get_parent()
 game_preview=preload("res://scripts/spaces/shader_game_preview.gd").new()
 overlay_host.add_child(game_preview);game_preview.z_index=-1
 game_preview.set_anchors_and_offsets_preset(PRESET_FULL_RECT);game_preview.setup("");game_preview.set_process(false)
 mode_pick.set_item_text(0,"传统场景 · 投影算法测试");mode_pick.set_item_text(1,"原包资产 · 独立观察");mode_pick.remove_item(2);mode_pick.select(0);traditional_ready=true
 get_child(0).z_index=-5
 var composite:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type canvas_item; render_mode blend_premul_alpha;";composite.shader=shader;overlay_host.material=composite
 bind_game_actor();arrange()
 asset_tabs.current_tab=1
 status.text="默认使用原游戏场景与保存机位；武器挂点、远近尺寸、飞行和命中按投影算法适配。"
func select_model(index:int):
 if traditional():
  selected_model=index
  if is_instance_valid(game_actor):
   weapon_panel.weapon=0;weapon_panel.bind_model()
  game_preview.replace_model(MODELS[index].file);bind_game_actor(false);update_info()
 else:super(index);driver_rig=rig
func bind_game_actor(replace:bool=true):
 if not game_preview:return
 if replace:game_preview.replace_model(MODELS[selected_model].file)
 game_actor=game_preview.app.arena.seer
 if not game_actor:return
 for attach in game_actor.attachments:attach.hide()
 rig=game_actor.rig;retarget=RETARGET.new();retarget.configure(rig,catalog.bones)
 actor_origin=game_actor.body.position
 game_card=null
 for card in game_preview.app.arena.cards:
  if card.unit.get("uid",-1)==game_actor.uid:game_card=card;break
 choose_motion("9_EM_Idle");playing=false
 weapon_panel.bind_model()
func arrange():
 if camera_picker:camera_picker.disabled=traditional()
 if obstacle_toggle:obstacle_toggle.visible=not traditional()
 if not traditional():
  if game_preview:game_preview.hide()
  viewport.transparent_bg=false
  if overlay_host:overlay_host.material=null
  camera.projection=Camera3D.PROJECTION_PERSPECTIVE;floor_node.show()
  rig=driver_rig;retarget=RETARGET.new()
  if rig:retarget.configure(rig,catalog.bones)
  super()
  floor_node.hide()
  for node in stage.get_children():
   if node is WorldEnvironment:node.environment.background_mode=Environment.BG_COLOR;node.environment.background_color=neutral_background
  return
 game_preview.show();viewport.transparent_bg=true
 var composite:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type canvas_item; render_mode blend_premul_alpha;";composite.shader=shader;overlay_host.material=composite
 for node in stage.get_children():
  if node is VisualInstance3D or node==model:node.hide()
 for entry in targets:entry.body.hide()
 for node in allies:node.hide()
 model.hide();floor_node.hide();obstacle.hide()
 for node in stage.get_children():
  if node is WorldEnvironment:node.environment.background_mode=Environment.BG_CLEAR_COLOR
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9;camera.position=Vector3(0,0,30);camera.rotation=Vector3.ZERO
 if rig!=game_actor.rig:bind_game_actor(false)
 var old_source:=source_slots.get_selected_id();var old_target:=target_slots.get_selected_id()
 source_slots.clear()
 for unit in game_preview.app.model.player:
  if game_preview.app.arena.equipped_actors.has(int(unit.uid)):source_slots.add_item(unit.get("name",unit.cardId),int(unit.uid))
 var selected_index:=0
 for i in source_slots.item_count:
  if source_slots.get_item_id(i)==game_actor.uid:selected_index=i
 for i in source_slots.item_count:
  if source_slots.get_item_id(i)==old_source:selected_index=i
 source_slots.select(selected_index)
 target_slots.clear()
 for unit in game_preview.app.model.enemy:target_slots.add_item(unit.get("name",unit.cardId),int(unit.uid))
 if target_slots.item_count>1:target_slots.select(1)
 for i in target_slots.item_count:
  if target_slots.get_item_id(i)==old_target:target_slots.select(i);break
func stop_action():
 clear_missile_light()
 super()
 if is_instance_valid(game_actor):game_actor.body.position=actor_origin
func view_input(event:InputEvent):
 if traditional():return
 super(event)
func card_for(uid:int):
 for card in game_preview.app.arena.cards:
  if card.unit.get("uid",-1)==uid:return card
 return null
func pixel_to_fx(px:Vector2)->Vector3:
 var extent:=Vector2(viewport.size);var ratio:=extent.y/9
 return Vector3((px.x-extent.x*.5)/ratio,(extent.y*.5-px.y)/ratio,0)
func project_weapon(point:Vector3)->Vector2:
 var actor_px:Vector2=game_actor.actor_camera.unproject_position(point)
 return game_card.position+actor_px/Vector2(game_actor.viewport.size)*Vector2(game_card.size.x,game_card.size.y-38)
func scene_depth(uid:int)->float:
 return maxf(1,float(game_preview.app.arena.world_slots.get(uid,{}).get("depth",50)))
func card_scale(card:Control)->float:
 return clampf((card.size.y-38)/(float(viewport.size.y)/9)/1.8,.05,5)
func play_entry():
 if not traditional():super();return
 stop_action()
 if current_entry.is_empty() or not current_entry.playable:status.text="该条目没有可播放的粒子层。";return
 # A model may replace the selected card only inside this test. It never alters the roster.
 var source_id:=source_slots.get_selected_id()
 var picked=game_preview.app.arena.equipped_actors.get(source_id)
 if picked and picked!=game_actor:
  game_actor=picked;rig=picked.rig;actor_origin=picked.body.position
  retarget=RETARGET.new();retarget.configure(rig,catalog.bones)
 for attach in game_actor.attachments:attach.hide()
 game_card=card_for(game_actor.uid)
 var target=card_for(target_slots.get_selected_id())
 if not target or not game_card:return
 equip_for(current_entry.behavior)
 var behavior:String=current_entry.behavior
 if behavior=="slash":
  choose_motion("4_Anim_ARPGSamurai_Attack_Combo%d"%(combo_step+1));combo_step=(combo_step+1)%4
 elif behavior in ["projectile","muzzle","stream","beam"]:choose_motion("9_EM_RangeAttack")
 else:choose_motion("9_EM_Attack01")
 if clip_choice.selected>0:
  choose_motion("4_Anim_ARPGSamurai_Attack_Combo%d"%clip_choice.selected if clip_choice.selected<5 else ["9_EM_RangeAttack","9_EM_Attack01","9_EM_Attack02","9_EM_Special"][clip_choice.selected-5])
 looping=false;playing=true;action_phase="windup";action_clock=0;emitted=false;impact_sent=false;hit_count=0;flight_fraction=0
 action_length=maxf(.6,float(selected.frames-1)/selected.fps);release_at=action_length*(.24 if behavior=="slash" else .38)
 arrival_pixel=target.position+Vector2(target.size.x*.5,(target.size.y-38)*.5)
 launch_depth=scene_depth(game_actor.uid);arrival_depth=scene_depth(target_slots.get_selected_id())
 source_scale=card_scale(game_card);arrival_scale=card_scale(target)
 last_tip_pixel=project_weapon(weapon_tip())
 status.text=current_entry.name+" · 原游戏镜头 / 武器投影挂点 / 按远近缩放"
func create_fx(entry:Dictionary,at:Vector3)->Node3D:
 var fx=super(entry,at)
 if traditional() and fx:
  # The screen plane replaces physical world orientation only in this mode.
  for layer in fx.layers:
   if layer.data.get("local",false):continue
   layer.data=layer.data.duplicate(true)
  fx.scale=Vector3.ONE*fitted_scale(entry,source_scale)
 return fx
func impact():
 if not traditional():super();return
 if impact_sent:return
 if missile_light_enabled and missile_burst_enabled and current_entry.get("behavior","")=="projectile":
  missile_light_position=light_world_point(arrival_pixel,arrival_depth)
  missile_burst_age=0.0;missile_light_tail=missile_burst_duration
 impact_sent=true;hit_count+=1
 var related:=matching_impact()
 if not related.is_empty():
  var hit=create_fx(related,pixel_to_fx(arrival_pixel))
  if hit:hit.scale=Vector3.ONE*fitted_scale(related,arrival_scale)
 if is_instance_valid(active_fx):active_fx.stop_emitting()
 var enemy=game_preview.app.arena.equipped_actors.get(target_slots.get_selected_id())
 if enemy:enemy.trigger("damage")
 status.text=current_entry.name+" · 已命中 · "+str(related.get("name","原包未关联命中特效"))
func _process(dt:float):
 if not traditional():clear_missile_light();super(dt);return
 var step:=minf(dt,.05)*rate;action_clock+=step
 if not game_actor:return
 var wanted_ratio:=maxf(1,float(viewport.size.x))/maxf(1,float(viewport.size.y))
 if absf(game_preview.ratio-wanted_ratio)>.001:game_preview.ratio=wanted_ratio
 if game_preview.app.arena.size!=Vector2(game_preview.view.size):game_preview.render()
 if not selected.is_empty():
  if playing:elapsed=minf(elapsed+step,float(selected.frames-1)/selected.fps)
  retarget.apply(elapsed);weapon_panel.sample_weapon_motion()
 var tip:=project_weapon(weapon_tip());var hand:=project_weapon(grip_position())
 if action_phase=="windup":
  var behavior:String=current_entry.behavior
  if behavior=="slash":
   var t:=action_clock/action_length
   # Small movement stays inside the existing actor viewport; no camera or battlefield reset.
   game_actor.body.position=actor_origin+Vector3(0,0,-.22)*smoothstep(0,.22,t)*(1-smoothstep(.68,1,t))
  if not emitted and action_clock>=release_at:
   emitted=true;launch_pixel=tip
   flight_distance=maxf(.5,sqrt(pow((arrival_pixel.x-tip.x)/maxf(1,float(viewport.size.y)/9),2)+pow((arrival_depth-launch_depth)*.05,2)))
   var point:=pixel_to_fx(tip)
   if behavior in ["impact","ambient","ground"]:point=pixel_to_fx(arrival_pixel)
   if not current_entry.get("muzzle_id","").is_empty():
    for entry in entries:
     if entry.id==current_entry.muzzle_id:
      var muzzle=create_fx(entry,point)
      if muzzle:muzzle.rotation.z=atan2(-(arrival_pixel.y-tip.y),arrival_pixel.x-tip.x)-PI*.5
      break
   active_fx=create_fx(current_entry,point)
   if behavior in ["impact","ambient","ground"] and active_fx:active_fx.scale=Vector3.ONE*fitted_scale(current_entry,arrival_scale)
   if behavior=="projectile":action_phase="flight"
   elif behavior in ["stream","beam"]:action_phase="projected_stream"
  if behavior=="slash" and is_instance_valid(active_fx):
   var blade:=tip-hand;var angle:=atan2(-blade.y,blade.x)
   var center:=hand.lerp(tip,.55)
   var axis:=blade.normalized();center+=axis*mount_offset.y*60+Vector2(-axis.y,axis.x)*mount_offset.x*60
   active_fx.position=pixel_to_fx(center);active_fx.rotation=Vector3(0,0,angle)
   var blade_length:=blade.length()/(float(viewport.size.y)/9)
   active_fx.scale=Vector3.ONE*fx_scale*maxf(.08,blade_length*.8)
   if action_clock>=action_length*.46:impact()
  if action_clock>=action_length:
   if is_instance_valid(active_fx):active_fx.stop_emitting()
   game_actor.body.position=actor_origin;action_phase="tail"
 elif action_phase=="flight":
  flight_fraction=minf(1,flight_fraction+shot_speed*step/flight_distance)
  # Perspective-correct interpolation: never lerp screen coordinates at a fixed arrival time.
  var depth:=lerpf(launch_depth,arrival_depth,flight_fraction)
  var pixel:Vector2=(launch_pixel*launch_depth).lerp(arrival_pixel*arrival_depth,flight_fraction)/depth
  if is_instance_valid(active_fx):
   active_fx.position=pixel_to_fx(pixel)
   var size:=1/lerpf(1/source_scale,1/arrival_scale,flight_fraction)
   active_fx.scale=Vector3.ONE*fitted_scale(current_entry,size)
  if flight_fraction>=1:impact();action_phase="tail"
 elif action_phase=="projected_stream":
  if is_instance_valid(active_fx):
   var delta:=pixel_to_fx(arrival_pixel)-pixel_to_fx(tip);active_fx.position=pixel_to_fx(tip)
   if delta.length_squared()>.001:active_fx.basis=Basis.looking_at(delta.normalized()).scaled(Vector3.ONE*fx_scale*source_scale)
  if action_clock>=release_at+flight_distance/shot_speed:impact()
  if action_clock>=release_at+maxf(1.5,flight_distance/shot_speed):action_phase="tail"
 last_tip_pixel=tip
 for fx in fx_nodes.duplicate():
  fx.advance(step)
  if fx.finished():return_fx(fx)
 if current_entry.get("behavior","")=="slash" and action_phase=="windup" and is_instance_valid(active_fx):active_fx.align_mesh_highlight(pixel_to_fx(hand.lerp(tip,.6)))
 if action_phase=="tail" and fx_nodes.is_empty():action_phase="idle";playing=false;game_actor.body.position=actor_origin
 if repeat_fx and action_phase=="idle" and missile_light_tail<=0 and action_clock>maxf(2,action_length+1):play_entry()
 update_missile_light(step)

func update_missile_light(step:float)->void:
 if not missile_light_enabled or current_entry.get("behavior","")!="projectile":
  clear_missile_light();return
 var bursting:=missile_burst_age>=0
 var flying:=not bursting and action_phase=="flight" and is_instance_valid(active_fx)
 if flying:
  var depth:=lerpf(launch_depth,arrival_depth,flight_fraction)
  var pixel:Vector2=(launch_pixel*launch_depth).lerp(arrival_pixel*arrival_depth,flight_fraction)/depth
  missile_light_position=light_world_point(pixel,depth)
  missile_light_tail=.18
 elif bursting:
  missile_burst_age+=step
  missile_light_tail=maxf(0,missile_burst_duration-missile_burst_age)
 else:missile_light_tail=maxf(0,missile_light_tail-step)
 if missile_light_tail<=0:clear_missile_light();return
 var r=game_preview.app.arena.scenery.renderer
 if not missile_light_bound:
  missile_light_base=r.combat_lights.duplicate();missile_light_bound=true
 r.combat_lights=missile_light_base.duplicate()
 # Same world-space attenuation as other combat lights; no screen-space glow decal.
 var envelope:float=smoothstep(0,.12,flight_fraction) if flying else missile_light_tail/.18
 var radius:=missile_light_radius
 var color:=missile_light_color
 var energy:=missile_light_energy*envelope
 if bursting:
  # Independent impact pulse survives the projectile and holds at the hit point.
  var peak_time:=minf(missile_burst_rise,missile_burst_duration*.8)
  var rise:=smoothstep(0,peak_time,missile_burst_age)
  var fade:=1-smoothstep(peak_time,missile_burst_duration,missile_burst_age)
  energy=lerpf(missile_light_energy,missile_burst_energy,rise)*fade
  radius=lerpf(missile_light_radius,missile_burst_radius,rise)
  color=missile_light_color.lerp(missile_burst_color,rise)
 r.combat_lights.push_front({"position":missile_light_position,"radius":radius,"color":color,"energy":energy})
 game_preview.app.arena.scenery.sync_projection();r.queue_redraw()

func light_world_point(pixel:Vector2,depth:float)->Vector3:
 var r=game_preview.app.arena.scenery.renderer
 var x:float=(pixel.x-r.view_size.x*.5)*depth/r.focal()
 var height:float=r.camera_height()-(pixel.y-r.horizon_y())*depth/r.focal()
 var ground:Vector2=r.camera_world+Vector2(cos(r.heading)*x+sin(r.heading)*depth,-sin(r.heading)*x+cos(r.heading)*depth)
 return Vector3(ground.x,height,ground.y)

func clear_missile_light()->void:
 missile_light_tail=0
 missile_burst_age=-1
 if not missile_light_bound:return
 missile_light_bound=false
 if is_instance_valid(game_preview) and is_instance_valid(game_preview.app):
  var r=game_preview.app.arena.scenery.renderer
  r.combat_lights=missile_light_base.duplicate()
  game_preview.app.arena.scenery.sync_projection();r.queue_redraw()
 missile_light_base.clear()

func fitted_scale(entry:Dictionary,reference:float)->float:
 return fx_scale*reference*minf(1,1.1/maxf(1.1,estimate_radius(get_spec(entry))/maxf(.01,fx_scale)))

func load_formation():
 if not traditional():super();return
 stop_action()
 var app=game_preview.app
 app.live_template.poll(.6);app.live_template.prepare_slots(app.model.player,app.arena.equipped_actors.keys())
 for uid in app.live_template.slot_targets:
  if app.arena.world_slots.has(uid):
   for key in ["x","depth","height","clearance"]:app.arena.world_slots[uid][key]=app.live_template.slot_targets[uid][key]
 game_preview.render();arrange()
