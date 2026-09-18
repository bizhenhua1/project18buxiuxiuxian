extends Control
const RANGE=preload("res://scripts/tactical/range.gd")
var stage
var selected:=-1
var hovered:=-1
var swapping:=false
var preview:=false
var panel:PanelContainer
var status_label:Label
var detail:Label
var skill:Button
var swap_button:Button
var forward:Button
var retreat:Button
var picker:OptionButton
var start:Button
var slot_bar:HBoxContainer
var selection_outline
var taunt_toggle:CheckButton
var projectile_picker:OptionButton
var range_view
func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 var box:=VBoxContainer.new();box.position=Vector2(18,14);add_child(box)
 status_label=Label.new();box.add_child(status_label)
 start=Button.new();start.text="开始战术防守 / 重新开始";box.add_child(start);start.pressed.connect(stage.begin_tactical)
 button(box,"技能测试 · 回满能量",func():
  for a in stage.sim.allies:
   if stage.sim.alive(a):a.energy=stage.sim.energy_limit(a))
 panel=PanelContainer.new();panel.position=Vector2(18,130);panel.custom_minimum_size=Vector2(295,0);add_child(panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color("111e1bee");style.border_color=Color("ad9870");style.set_border_width_all(1);style.set_content_margin_all(14);panel.add_theme_stylebox_override("panel",style)
 var column:=VBoxContainer.new();panel.add_child(column)
 detail=Label.new();column.add_child(detail)
 picker=OptionButton.new();column.add_child(picker)
 for spec in stage.sim.settings.skills:picker.add_item(spec.name+" · "+{"auto":"自动回能","attack":"攻击回能","hurt":"受击回能"}[spec.recharge])
 picker.item_selected.connect(func(index):
  if selected>=0:stage.sim.allies[selected].skill=index;stage.sim.allies[selected].energy=0;preview=true)
 var row:=HBoxContainer.new();column.add_child(row)
 skill=button(row,"释放技能",func():
  if stage.sim.cast(selected):close_menu())
 button(row,"查看范围",func():preview=not preview)
 swap_button=button(column,"换位 · 选择队友或空位",func():swapping=true;preview=false)
 forward=button(column,"职业移动",func():
  if stage.sim.command(selected,"advance"):close_menu())
 retreat=button(column,"撤退至站位",func():
  if stage.sim.command(selected,"retreat"):close_menu())
 button(column,"关闭 · 恢复正常速度",close_menu)
 taunt_toggle=CheckButton.new();taunt_toggle.text="特性 · 嘲讽相邻列";column.add_child(taunt_toggle)
 taunt_toggle.toggled.connect(func(value):
  if selected>=0:
   stage.sim.allies[selected].taunt=value
   if not value:
    for e in stage.sim.enemies:
     if e.get("taunted_by",-1)==selected:e.taunted_by=-1
    stage.sim.allies[selected].taunting.clear())
 projectile_picker=OptionButton.new();column.add_child(projectile_picker)
 projectile_picker.add_item("普攻 · 指向追踪");projectile_picker.add_item("普攻 · 固定弹道")
 projectile_picker.item_selected.connect(func(index):
  if selected>=0:stage.sim.allies[selected].projectile_mode="homing" if index==0 else "ballistic")
 panel.hide()
 selection_outline=preload("res://scripts/tactical/selection_outline.gd").new();stage.add_child(selection_outline);selection_outline.setup(stage,self)
 var outline_picker:=OptionButton.new();column.add_child(outline_picker)
 for title in selection_outline.STYLE_NAMES:outline_picker.add_item("描边 · "+title)
 outline_picker.select(selection_outline.style_index);outline_picker.item_selected.connect(selection_outline.set_style)
 range_view=preload("res://scripts/tactical/range_view.gd").new();stage.add_child(range_view);range_view.setup(stage)
 slot_bar=HBoxContainer.new();add_child(slot_bar);slot_bar.hide()
 for i in stage.sim.slots.size():
  var b:=button(slot_bar,"空位",func():
   if swapping:
    if stage.sim.swap(selected,i):close_menu()
   else:
    for a in stage.sim.allies:
     if a.get("tactical_active",false) and a.slot==i:select(a.id);break)
  b.custom_minimum_size=Vector2(90,42)
func button(parent:Node,text:String,callback:Callable)->Button:
 var b:=Button.new();b.text=text;parent.add_child(b);b.pressed.connect(callback)
 var style:=StyleBoxFlat.new();style.bg_color=Color("23372f");style.border_color=Color("6f7359");style.set_border_width_all(1);style.set_content_margin_all(7)
 b.add_theme_stylebox_override("normal",style)
 var hover:StyleBoxFlat=style.duplicate();hover.bg_color=Color("365346");b.add_theme_stylebox_override("hover",hover)
 return b
func close_menu():selected=-1;swapping=false;preview=false;panel.hide()
func select(id:int):selected=id;swapping=false;preview=false;picker.select(stage.sim.allies[id].skill);panel.show()
func anchor(id:int)->Vector2:
 return stage.camera.unproject_position(stage.world_point(stage.sim.allies[id].pos))
func hit(point:Vector2)->int:
 var best:=-1;var distance:=INF
 for i in stage.team.size():
  var actor=stage.team[i];var id:int=stage.team_slots[i]
  if not actor.visible or actor.opacity<.1:continue
  var foot:Vector2=stage.camera.unproject_position(actor.position)
  var top:Vector2=stage.camera.unproject_position(actor.position+Vector3.UP*1.8*actor.scale.y)
  var height:float=absf(foot.y-top.y);var rect:=Rect2(Vector2(foot.x-height*.27,minf(top.y,foot.y)),Vector2(height*.54,height))
  if rect.has_point(point) and point.distance_to((foot+top)*.5)<distance:distance=point.distance_to((foot+top)*.5);best=id
 return best
func _unhandled_input(event:InputEvent):
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:close_menu();get_viewport().set_input_as_handled()
 if not event is InputEventMouseButton or not event.pressed:return
 if event.button_index==MOUSE_BUTTON_RIGHT:close_menu();get_viewport().set_input_as_handled();return
 if event.button_index!=MOUSE_BUTTON_LEFT:return
 var id:=hit(event.position)
 if swapping:
  var slot:=-1
  if id>=0:slot=stage.sim.allies[id].slot
  else:
   var nearest:=40.0
   for i in stage.sim.slots.size():
    var p:Vector2=stage.camera.unproject_position(stage.world_point(stage.sim.slots[i]))
    if p.distance_to(event.position)<nearest:nearest=p.distance_to(event.position);slot=i
  if stage.sim.swap(selected,slot):close_menu()
 elif id>=0:select(id)
 else:close_menu()
 get_viewport().set_input_as_handled()
func refresh():
 slot_bar.visible=true;slot_bar.position=Vector2(maxf(10,(size.x-slot_bar.size.x)*.5),size.y-52)
 for i in slot_bar.get_child_count():
  var text:="%d · 空位"%(i+1)
  for a in stage.sim.allies:
   if a.get("tactical_active",false) and a.slot==i:text="%d · %s\n%.0f / %.0f"%[i+1,a.get("display_name","队友"),a.energy,stage.sim.energy_limit(a)]
  slot_bar.get_child(i).text=text
 hovered=hit(get_local_mouse_position())
 selection_outline.sync([hovered,selected])
 status_label.text="战术防守 · 防线 %d / %d · 来敌 %d · 击败 %d\n%s"%[stage.sim.life,int(stage.sim.config.life),stage.sim.spawned,stage.sim.killed,"指令选择中 · 20% 速度" if selected>=0 and stage.phase=="battle" else "点击我方角色下达指令 · 右键 / Esc 取消"]
 if stage.phase in ["victory","defeat"]:status_label.text+="\n"+("防守成功" if stage.phase=="victory" else "防线失守")
 if selected>=0:
  var a:Dictionary=stage.sim.allies[selected];var alive:bool=stage.sim.alive(a)
  detail.text="%s · %s\n生命 %.0f / %.0f   阻挡 %d / %d\n能量 %.1f / %.0f\n%s"%[a.get("display_name","队长" if selected==stage.team_slots[0] else "队员"),a.get("class_label",a.profession),a.hp,a.max_hp,a.blocked.size(),a.block,a.energy,stage.sim.energy_limit(a),"选择队友或地面空位" if swapping else "信息 · 技能与战场指令"]
  taunt_toggle.set_pressed_no_signal(a.taunt);projectile_picker.visible=not a.melee and a.get("role","")!="heal"
  projectile_picker.select(0 if a.projectile_mode=="homing" else 1)
  if a.taunt:detail.text+="\n嘲讽 · 引敌 %d / 剩余 %d"%[a.taunting.size(),maxi(0,a.block-a.blocked.size()-a.taunting.size())]
  skill.disabled=not alive or a.energy<stage.sim.energy_limit(a) or stage.phase!="battle"
  swap_button.disabled=not alive or stage.phase!="battle";forward.disabled=swap_button.disabled;retreat.disabled=swap_button.disabled
  forward.text={"剑士":"剑士 · 向前迎敌","术士":"术士 · 前移施法","先锋":"先锋 · 深入迎敌","守卫":"守卫 · 固守增挡 8 秒"}[a.profession]
  if a.profession!="守卫" and a.pos.z<=float(stage.sim.settings.advance_limit_z)+.01:forward.disabled=true;forward.text="已达前移边界"
  var spec:Dictionary=stage.sim.settings.skills[a.skill]
  picker.disabled=a.has("role")
  if spec.has("description"):detail.text+="\n"+spec.description
  if float(a.get("shield",0))>0:detail.text+="\n护盾 %.0f"%a.shield
  detail.text+="\n"+("直线贯通 · %s / 宽 %.1f 米"%["无限" if spec.get("infinite",false) else "%.1f 米"%(spec.length*.4),spec.width*.4] if spec.shape=="line" else "半径 %.1f 米"%(spec.radius*.4))
 if selected>=0 and preview:
  range_view.sync(stage.sim.allies[selected].pos,stage.sim.settings.skills[stage.sim.allies[selected].skill],true)
  detail.text+="\n%s · %d"%["范围内队友" if stage.sim.settings.skills[stage.sim.allies[selected].skill].get("target","")=="ally" else "范围内敌人",range_view.affected.size()]
 else:range_view.sync(Vector3.ZERO,{},false)
 queue_redraw()
func draw_range(origin:Vector3,spec:Dictionary,color:Color):
 var line:=PackedVector2Array()
 for p in RANGE.boundary(origin,spec):line.append(stage.camera.unproject_position(stage.world_point(p)+Vector3.UP*.04))
 if line.size()>2:
  draw_colored_polygon(line,color*Color(1,1,1,.12));draw_polyline(line,color,2,true)
func _draw():
 if not stage.ready_stage:return

 for flash in stage.sim.flashes:draw_range(flash.origin,flash.spec,Color(1,.8,.4,clampf((flash.until-stage.sim.clock)/.65,0,1)))
 if swapping:
  for i in stage.sim.slots.size():
   var p:Vector2=stage.camera.unproject_position(stage.world_point(stage.sim.slots[i]));draw_circle(p,18,Color(.5,.9,.75,.2));draw_arc(p,18,0,TAU,32,Color("b9e9d6"),2)
 for id in stage.team_slots:
  var a:Dictionary=stage.sim.allies[id];var p:=anchor(id)
  if a.death_phase=="respawn":
   var left:float=maxf(0,stage.sim.settings.respawn_seconds-(stage.sim.clock-a.death_at-float(a.get("death_hold",stage.sim.settings.death_hold_seconds))-stage.sim.settings.return_seconds))
   draw_string(ThemeDB.fallback_font,p,"重生 %.1f"%left,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e2cfa7"))
  else:
   draw_rect(Rect2(p+Vector2(-25,8),Vector2(50,4)),Color(.1,.16,.14,.8))
   draw_rect(Rect2(p+Vector2(-25,8),Vector2(50*a.energy/stage.sim.energy_limit(a),4)),Color("b8dba0"))


