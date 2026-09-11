class_name BattleCard
extends Control
var arena: Control
var unit: Dictionary = {}
var side := "player"
var index := 0
var flash := 0.0
var hovered := false
var motion_age := 10.0
var motion_kind := ""
var motion_direction := Vector2.UP
var scene_rest_position:=Vector2.ZERO
var motion_world_direction:=Vector2.ZERO
var motion_distance:=0.0
var scene_motion_offset:=Vector2.ZERO
var motion_origin:=Vector2.ZERO
var displayed_hp := -1.0
var scene_body_in_world:=false
var scene_head_uv:=Vector2(.5,0)
var equipment_press:=0
func accent() -> Color:
	return {"violet":Color("b57bff"),"gold":Color("e8c25a"),"jade":Color("6ed89a"),"mint":Color("7eefb0"),"steel":Color("9bb4c8"),"crimson":Color("e07058"),"amber":Color("d4a04a")}.get(unit.get("theme","gold"),Color("e8c25a"))
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_entered.connect(func():hovered = true)
	mouse_exited.connect(func():hovered = false)
func _get_tooltip(_position: Vector2) -> String:
	if arena.scene_mode and not arena.equipment_open:return ""
	if unit.is_empty(): return "准备阶段可将卡牌拖到此处"
	return "%s · 攻击 %.1f · 间隔 %.2fs\n%s\n%s" % [unit.name,unit.atk,unit.cd/1000.0,unit.skillText,"手持：不独立承伤，血量按比例并入道童" if unit.mode == "held" else "生命 %d / %d · 护盾 %d" % [unit.hp,unit.maxHp,unit.shield]]
func text_at(value: String, point: Vector2, font_size: int, color := Color("d8d6bd"), width := -1.0) -> void:
	draw_string(get_theme_default_font(),point,value,HORIZONTAL_ALIGNMENT_CENTER,width,font_size,color)
func _draw() -> void:
	if arena.scene_mode and not arena.equipment_open:
		draw_scene_unit();return
	var offset := Vector2.ZERO
	var zoom := 1.0
	if not unit.is_empty():
		if BattleRules.alive(unit) and unit.cardType == "fabao" and unit.mode != "held": offset.y = sin(arena.visual_time*TAU/3.4+unit.uid*1.7)*2.2
		if motion_kind == "attack" and motion_age < .38:
			var t := motion_age/.38
			var envelope := minf(t/.3,1.0) if t < .52 else (1-t)/.48
			offset += motion_direction*envelope*(20 if unit.mode == "held" else 8)
			zoom += envelope*(.08 if unit.mode == "held" else .035)
		elif motion_kind == "damage" and motion_age < .22: offset.x += sin(motion_age*100)*(1-motion_age/.22)*4
	draw_set_transform_matrix(Transform2D(0,Vector2.ONE*zoom,0,size/2+offset-size*zoom/2))
	var rect := Rect2(Vector2.ZERO,size)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("182019")
	if not unit.is_empty():
		box.bg_color = Color("29291d") if unit.cardType == "char" else Color("23202b") if unit.cardType == "spell" else Color("182b29") if side == "player" else Color("2a2320")
	if hovered: box.bg_color = box.bg_color.lightened(.07)
	box.border_color = Color("8b7952") if side == "player" else Color("775647")
	if not unit.is_empty():
		box.bg_color = Color("151c29")
		box.border_color = accent().darkened(.25) if BattleRules.alive(unit) else Color("50514d")
		box.shadow_color = Color(accent(),.18 if BattleRules.alive(unit) else 0)
		box.shadow_size = 3
	box.set_border_width_all(1)
	box.set_corner_radius_all(0)
	if not unit.is_empty() and arena.selected_uid == unit.uid:
		box.border_color = Color("e6cb7c")
		box.set_border_width_all(2)
	if not unit.is_empty() and BattleRules.target(arena.model.player if side == "player" else arena.model.enemy).get("uid",-1) == unit.uid:
		box.border_color = Color("e6cb7c")
		box.shadow_size = 7
	draw_style_box(box,rect)

	if unit.is_empty():
		draw_texture_rect(AdventureSkin.part("seal"),Rect2(Vector2(size.x/2-14,size.y/2-20),Vector2(28,36)),false,Color(1,1,1,.18))
		return
	var live := BattleRules.alive(unit)
	var faded := Color.WHITE if live else Color(.3,.3,.3,.8)
	var image_rect := Rect2(Vector2(size.x*.035,size.y*.025),Vector2(size.x*.93,size.y*.85))
	var texture: Texture2D = arena.art_for(unit)
	if texture:
		var art_rect := portrait_rect(texture)
		if side == "enemy" and motion_kind == "attack" and motion_age < .28:
			var pose := CreatureMotion.sample(unit.cardId,motion_age/.28)
			art_rect = Rect2(art_rect.get_center()-art_rect.size*pose.squash/2,art_rect.size*pose.squash)
		draw_portrait(texture,art_rect,image_rect,faded)
	else:
		var sigils := {"fireball":["离","火",Color("d18a66")],"bind":["冰","缚",Color("9abac8")],"bolt":["天","雷",Color("d1b66f")],"mend":["回","春",Color("9dc89b")]}
		var spec: Array = sigils.get(unit.spellKind,["灵","术",Color("c2b384")])
		var center := image_rect.get_center()
		var radius := minf(image_rect.size.x*.43,image_rect.size.y*.46)
		var tint: Color = spec[2] if live else Color("65615a")
		draw_circle(center,radius,Color(tint,.06))
		draw_arc(center,radius,0,TAU,64,Color(tint,.65),1,true)
		draw_arc(center,radius+4,-PI*.8,PI*.6,48,Color(tint,.3),1,true)
		var font_size := int(clampf(radius*.72,12,26))
		draw_string(arena.sigil_font,center+Vector2(-radius,-2),spec[0],HORIZONTAL_ALIGNMENT_CENTER,radius*2,font_size,tint)
		draw_string(arena.sigil_font,center+Vector2(-radius,font_size),spec[1],HORIZONTAL_ALIGNMENT_CENTER,radius*2,font_size,tint)
	if unit.cardType == "char":
		var capacity: int = 2+arena.model.mods.get("handSlots",0)
		var used: int = arena.model.player.filter(func(u):return u.mode == "held").size()
		for slot in range(capacity):
			var at := Vector2(size.x-13,32+slot*14)
			draw_circle(at,6,Color("ad873b") if slot >= used else Color("423b2b"))
			draw_texture_rect(arena.texture_for("assets/style-e/style-e-ui-fist.png"),Rect2(at-Vector2(5,5),Vector2(10,10)),false,Color(1,1,1,1 if slot >= used else .35))
	if arena.show_card_names:
		draw_string(arena.sigil_font,Vector2(2,size.y*.055),unit.name,HORIZONTAL_ALIGNMENT_CENTER,size.x-4,int(20*size.x/130),Color("efd790"))
	var mode: String = "手持" if unit.mode == "held" else "操控" if unit.cardType == "fabao" else "识海" if unit.cardType == "spell" else "御兽" if unit.cardType == "beast" else "角色"
	if side == "enemy": mode = "敌方"
	elif StyleLibrary.active and unit.get("portrait_kind","") == "person": mode = "调查员"
	if not live: mode = "重聚 %.1fs" % (unit.reviveLeft/1000.0) if unit.reviveLeft > 0 else "已倒下"
	text_at("%d级 · %s" % [arena.model.stage+1,StyleLibrary.words(mode)],Vector2(0,size.y*.69),maxi(9,int(10*size.x/130)),Color("b9c3a5"),size.x)
	var radius := size.x*37.5/130.0
	var center := Vector2(size.x*.5,size.y*.83)
	if unit.get("health_transformation_active",false):
		if hovered or arena.show_card_names:text_at(unit.name,Vector2(-50,-8),14,Color("efd790"),size.x+100)
		return
	draw_circle(center,radius,Color("281b1a"))
	var inherited: bool = live and (unit.mode == "held" or unit.cardType == "spell")
	var hp_ratio: float = clampf((unit.hp if displayed_hp < 0 else displayed_hp)/float(maxi(1,unit.maxHp)),0,1)
	if inherited:
		if unit.mode == "held": draw_texture_rect(arena.texture_for("assets/style-e/style-e-ui-fist.png"),Rect2(center-Vector2.ONE*(radius-2),Vector2.ONE*(radius-2)*2),false)
		else: text_at("识",center+Vector2(-20,5),14,Color("c9b9df"),40)
	elif hp_ratio > 0: liquid(center,radius-3,hp_ratio,Color("ef3e1f"))
	if not inherited and hp_ratio > .05:
		var liquid_y := (radius-3)*(1-2*hp_ratio)
		var half := sqrt(maxf(0,(radius-3)*(radius-3)-liquid_y*liquid_y))
		draw_line(center+Vector2(-half,liquid_y+1),center+Vector2(half,liquid_y+1),Color(1,.87,.71,.48),maxf(1,size.x*.025),true)
	draw_arc(center,radius-3,PI*1.14,PI*1.86,40,Color(1,.94,.81,.18),maxf(1,radius*.09),true)
	if unit.shield > 0 and not inherited: liquid(center,radius-3,clampf(unit.shield/float(unit.maxHp),0,1),Color(.6,.86,.97,.6))
	draw_arc(center,size.x*40/130,0,TAU,96,Color("41594c"),size.x*4/130,true)
	draw_arc(center,size.x*40/130,-PI/2,-PI/2+TAU*clampf(1-unit.cdLeft/float(unit.cd),0,1),96,Color("ddca69") if live else Color("63665e"),size.x*4/130,true)
	if not inherited: text_at(str(int(unit.hp)),center+Vector2(-radius,radius*.31),clampi(int(radius*.77),12,29),Color("fff1d3"),radius*2)
	if unit.shield > 0: text_at("盾%d" % unit.shield,Vector2(0,size.y-4),10,Color("9bd7d4"),size.x)
	if unit.soulStacks > 0: text_at("魂%d" % unit.soulStacks,Vector2(0,38),11,Color("c4acdf"),size.x)
	if live and unit.shield > 0: draw_arc(center,radius+6,0,TAU,64,Color(.55,.8,.84,.7),1.4,true)
	if unit.reviveLeft > 0:
		var ratio: float = 1-unit.reviveLeft/maxf(unit.reviveMs,1)
		draw_line(Vector2(8,size.y-2),Vector2(8+(size.x-16)*ratio,size.y-2),Color("adb8de"),2)
	if flash > 0:
		var tint := Color("a6e9a0") if motion_kind == "heal" else Color("adc9f7") if motion_kind in ["revive","buff"] else Color("f5c1a0")
		draw_rect(rect,Color(tint,flash*.18))
# Bounds are based on alpha-trimmed assets, not the transparent source canvas.
# Character crops use upper-body composition; objects and beasts keep their whole silhouette.
func portrait_rect(texture: Texture2D) -> Rect2:
	var box := Rect2(Vector2(size.x*.075,size.y*.09),Vector2(size.x*.85,size.y*.55))
	if (unit.get("cardType","") == "char" or unit.get("portrait_kind","") == "person"):
		box = Rect2(Vector2(size.x*.035,size.y*.10),Vector2(size.x*.93,size.y*.75))
	var factor := minf(box.size.x/texture.get_width(),box.size.y/texture.get_height())
	var dims := texture.get_size()*factor
	var origin := box.get_center()-dims/2
	if (unit.get("cardType","") == "char" or unit.get("portrait_kind","") == "person"): origin.y = box.position.y
	return Rect2(origin,dims)
func draw_portrait(texture: Texture2D, destination: Rect2, mask: Rect2, tint: Color) -> void:
	var clipped := destination.intersection(mask)
	if not clipped.has_area(): return
	var fade_start := mask.position.y+mask.size.y*.70
	var fade_end := mask.position.y+mask.size.y*.83
	# Batch the opaque area, subdividing only the narrow fade band. No frame assets.
	var y := clipped.position.y
	while y < clipped.end.y:
		var next := minf(clipped.end.y,fade_start if y < fade_start else y+1.5)
		if y >= fade_end: break
		var strip := Rect2(clipped.position.x,y,clipped.size.x,next-y)
		var uv := Rect2((strip.position-destination.position)/destination.size*texture.get_size(),strip.size/destination.size*texture.get_size())
		var alpha := 1.0-smoothstep(fade_start,fade_end,(y+next)*.5)
		draw_texture_rect_region(texture,strip,uv,Color(tint,tint.a*alpha))
		y = next
func liquid(center: Vector2, radius: float, ratio: float, tint: Color) -> void:
	var top := radius*(1-2*ratio)
	for row in range(int(ceil(top)),int(radius)+1):
		var y := float(row)
		var half := sqrt(maxf(0,radius*radius-y*y))
		draw_line(center+Vector2(-half,y),center+Vector2(half,y),tint.darkened(pow(clampf((y+radius)/(radius*2),0,1),1.4)*.82),1.2,true)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		equipment_press+=1
		if event.pressed and arena.equipment_open and side=="player" and not unit.is_empty() and (unit.cardType=="char" or unit.get("portrait_kind","")=="person"):
			_open_equipment_after_hold(equipment_press,get_global_mouse_position())
	if event is InputEventMouseButton and event.pressed:
		if not unit.is_empty(): arena.select(unit)
		if side != "player": return
		if event.button_index == MOUSE_BUTTON_RIGHT: arena.remove_card(index)
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click: arena.change_mode(index)
func _get_drag_data(_position: Vector2) -> Variant:
	equipment_press+=1
	if arena.formation_locked or side != "player" or unit.is_empty() or not arena.model.can_edit(): return null
	var preview := StudyUI.label(unit.name,20)
	set_drag_preview(preview)
	return {"formation_index":index}
func _can_drop_data(_position: Vector2,data: Variant) -> bool:
	return not arena.formation_locked and side == "player" and arena.model.can_edit() and data is Dictionary and (data.has("formation_index") or data.has("card_id"))
func _drop_data(_position: Vector2,data: Variant) -> void:
	if data.has("formation_index"): arena.model.move(data.formation_index,index)
	else: arena.owner_app.note(arena.model.add_card(data.card_id,index))
	arena.rebuild()

func draw_scene_unit() -> void:
	if unit.is_empty():return
	var texture:Texture2D=arena.scene_art(unit,side)
	if not texture:return
	var foot:=Vector2(size.x*.5,size.y-38)
	var offset:=Vector2.ZERO
	if motion_kind=="attack" and motion_age<.30:offset=motion_direction*sin(motion_age/.30*PI)*16
	if motion_kind=="damage" and motion_age<.22:offset.x=sin(motion_age*90)*(1-motion_age/.22)*5
	var hovering:bool=unit.cardType in ["fabao","spell"]
	if hovering:offset.y+=sin(arena.visual_time*2+unit.uid)*4
	draw_set_transform(foot,0,Vector2(1,.20))
	if not scene_body_in_world:draw_circle(Vector2.ZERO,minf(size.x*.35,55),Color(0,0,0,.30))
	draw_set_transform(Vector2.ZERO)
	var live:=BattleRules.alive(unit)
	var tint:=Color.WHITE if live else Color(.4,.4,.4,.45)
	if flash>0:tint=tint.lerp(Color(1.4,1.2,1.2),flash*.6)
	var art_rect:=Rect2(offset,Vector2(size.x,size.y-38))
	if side=="player" and unit.get("cardId",unit.get("id",""))=="masuo":art_rect.position.x+=art_rect.size.x;art_rect.size.x=-art_rect.size.x
	if not scene_body_in_world:draw_texture_rect(texture,art_rect,false,tint)
	if unit.get("health_transformation_active",false):return
	var center:=foot+Vector2(0,17)
	center.y=minf(center.y,arena.size.y-position.y-26)
	var radius:=15.0
	if side=="enemy":
		center=Vector2(size.x,size.y-38)*scene_head_uv-Vector2(0,radius+9)
	draw_circle(center,radius,Color("281b1a"))
	var inherited:bool=unit.mode=="held" or unit.cardType=="spell"
	if not inherited:
		liquid(center,radius-2,clampf(unit.hp/float(maxi(1,unit.maxHp)),0,1),Color("ef3e1f"))
	text_at("持" if unit.mode=="held" else "术" if inherited else str(int(unit.hp)),center+Vector2(-22,5),12,Color("fff1d3"),44)
	draw_arc(center,radius+2,0,TAU,48,Color("41594c"),2,true)
	draw_arc(center,radius+2,-PI/2,-PI/2+TAU*clampf(1-unit.cdLeft/maxf(1,unit.cd),0,1),48,accent(),2,true)
	if hovered or arena.show_card_names:
		var name_origin:=center+Vector2(-80,-24) if side=="enemy" else Vector2(-50,-8)
		text_at(unit.name,name_origin,14,Color("efd790"),160 if side=="enemy" else size.x+100)

func _open_equipment_after_hold(token:int,at:Vector2) -> void:
	await get_tree().create_timer(.55).timeout
	if token!=equipment_press or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or get_global_mouse_position().distance_to(at)>8 or not arena.equipment_open:return
	var owner=arena.owner_app
	if owner.get("roster_ui"):
		owner.roster_ui.route=owner
		owner.roster_ui.open_loadout(preload("res://scripts/equipment/loadouts.gd").model_for_unit(unit),unit.name)
