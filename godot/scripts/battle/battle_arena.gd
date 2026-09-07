class_name BattleArena
extends Control
var model: BattleModel
var owner_app: Control
var cards: Array[BattleCard] = []
var textures := {}
var effects: Array[Dictionary] = []
var selected_uid := -1
var scenery: CorridorView
var vfx: Node2D
var sigil_font: SystemFont
var external_scenery := false
var equipment_open := false
var scene_enemy_sources:Dictionary={}
var battle_mix := 0.0
var entrance_progress := 1.0
var formation_locked := false
var enemies_visible := true
var enemy_opacity := 1.0
var visual_time := 0.0
var art_textures := {}
var particles: BattleParticles
var show_card_names := false
var card_scale := 1.0
var scene_mode:=true
var relic_reverse:=true
var enemy_backdrop: AdventurePanel
var player_backdrop: AdventurePanel
func set_card_names(value: bool) -> void:
	show_card_names = value
	var config := ConfigFile.new()
	config.load("user://battle-presentation.cfg")
	config.set_value("cards","show_names",value)
	config.save("user://battle-presentation.cfg")
const PROJECTILES := {"taomu-jian":"sword","qingfeng-jian":"sword","xuantie-jian":"heavysword","kaishan-fu":"axe","waci-yin":"seal","masuo":"rope","tongjing":"mirror","xiaohulu":"gourd","juhun-fan":"fan"}
const PROJ_SIZE := {"sword":40,"heavysword":46,"axe":44,"seal":34,"rope":36,"mirror":30,"gourd":32,"fan":40}
func setup(state: BattleModel, app: Control, route_view: CorridorView = null) -> void:
	model = state
	owner_app = app
	var config := ConfigFile.new()
	if config.load("user://battle-presentation.cfg") == OK:
		show_card_names = bool(config.get_value("cards","show_names",false))
	scene_mode=StyleLibrary.active and bool(config.get_value("cards","scene_mode",true))
	sigil_font = SystemFont.new()
	sigil_font.font_names = PackedStringArray(["KaiTi","Microsoft YaHei"])
	clip_contents = true
	external_scenery = route_view != null
	if external_scenery:
		scenery = route_view
		add_child(scenery)
	else:
		var art := ForestArt.new()
		var forest := ForestWorld.new(art)
		scenery = CorridorView.new()
		add_child(scenery)
		scenery.setup(art,forest,1,get_theme_default_font())
	# Child order puts the formation frames above the scenery and below the cards.
	enemy_backdrop = AdventurePanel.new()
	enemy_backdrop.fill = Color(.045,.085,.073,.92)
	add_child(enemy_backdrop)
	player_backdrop = AdventurePanel.new()
	player_backdrop.fill = Color(.055,.10,.085,.94)
	add_child(player_backdrop)
	vfx = Node2D.new()
	vfx.z_index = 200
	vfx.draw.connect(draw_effects)
	add_child(vfx)
	model.emitted.connect(on_event)
	particles = BattleParticles.new()
	particles.z_index = 190
	add_child(particles)
	particles.setup(self)
	rebuild()
func clean_path(path: String) -> String:
	path = StyleLibrary.path(path)
	if path.begins_with("res://"): return path.trim_prefix("res://")
	var derived := "assets/cleaned/"+path.get_file()
	return derived if path.begins_with("assets/style-e/") and ResourceLoader.exists("res://"+derived) else path
func art_for(unit: Dictionary) -> Texture2D:
	var path: String = unit.get("art","")
	var id: String = unit.get("cardId",unit.get("id",""))
	if path.is_empty() and PROJECTILES.has(id): path = "assets/style-e/style-e-proj-%s.png" % PROJECTILES[id]
	if path.is_empty(): return null
	path = clean_path(path)
	if not art_textures.has(path):
		var source: Texture2D = load("res://"+path)
		var image := source.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var bounds := image.get_used_rect()
		if bounds.has_area(): image = image.get_region(bounds)
		if StyleLibrary.active and unit.get("portrait_kind","") == "person":
			image = image.get_region(Rect2i(int(image.get_width()*.08),0,int(image.get_width()*.84),int(image.get_height()*.59)))
		elif unit.get("cardType","") == "char": image = image.get_region(Rect2i(0,0,image.get_width(),int(image.get_height()*.72)))
		image.generate_mipmaps()
		art_textures[path] = ImageTexture.create_from_image(image)
	return art_textures[path]
func texture_for(path: String) -> Texture2D:
	path = clean_path(path)
	if not textures.has(path): textures[path] = load("res://"+path)
	return textures[path]
func rebuild() -> void:
	var previous := cards.duplicate()
	cards.clear()
	for side in ["enemy","player"]:
		var line: Array = model.enemy if side == "enemy" else model.player
		for i in range(model.cap()):
			var uid: int = line[i].uid if i < line.size() else -1
			var card: BattleCard
			for existing in previous:
				if existing.side == side and ((uid >= 0 and existing.unit.get("uid",-1) == uid) or (uid < 0 and existing.unit.is_empty() and existing.index == i)):
					card = existing
					break
			if card: previous.erase(card)
			else:
				card = BattleCard.new()
				add_child(card)
			card.arena = self
			card.side = side
			card.index = i
			if i < line.size(): card.unit = line[i]
			cards.append(card)
	for card in previous:
		remove_child(card)
		card.queue_free()
	if equipment_open: owner_app.call_deferred("_refresh_kit")
func select(unit: Dictionary) -> void:
	selected_uid = unit.uid
	owner_app.show_detail(unit)
func remove_card(index: int) -> void:
	if formation_locked: return
	if external_scenery and index < model.player.size() and index >= 0 and model.player[index].cardType == "char":
		owner_app.note("道童须留在随行阵中")
		return
	model.remove_at(index)
	rebuild()
func change_mode(index: int) -> void:
	if formation_locked: return
	owner_app.note(model.toggle_mode(index))
	rebuild()
func anchor(uid: int) -> Vector2:
	for card in cards:
		if not card.unit.is_empty() and card.unit.uid == uid: return card.position+card.size/2
	return size/2
func _process(dt: float) -> void:
	if not model: return
	particles.advance(dt,owner_app.speed,model.paused)
	if not model.paused: visual_time += dt*owner_app.speed
	var player_count := model.cap() if equipment_open else maxi(1,model.player.size())
	var largest_row := maxi(player_count,model.enemy.size())
	card_scale = minf(1.0,minf((size.x-48)/(largest_row*130.0+(largest_row-1)*5.0),(size.y-40)/740.0))
	var width := 130.0*card_scale
	var height := 280.0*card_scale
	var gap := 5.0*card_scale
	enemy_backdrop.position = Vector2.ZERO
	enemy_backdrop.size = Vector2(size.x,height+40)
	enemy_backdrop.visible = enemies_visible and not equipment_open and not model.enemy.is_empty()
	enemy_backdrop.modulate.a = enemy_opacity*(battle_mix if external_scenery else 1.0)
	player_backdrop.visible=true
	player_backdrop.position = Vector2(0,size.y-height-32)
	player_backdrop.size = Vector2(size.x,height+32)
	enemy_backdrop.queue_redraw()
	player_backdrop.queue_redraw()
	var start := (size.x-(width*player_count+gap*(player_count-1)))/2
	for card in cards:
		card.visible = (card.side == "player" and (equipment_open or not card.unit.is_empty())) or (card.side == "enemy" and enemies_visible and not equipment_open and not card.unit.is_empty())
		card.modulate.a = enemy_opacity if card.side == "enemy" else 1.0
		if card.side == "enemy":
			var begins := .67 if card.index == 0 else .78+minf(card.index,5)*.025
			card.modulate.a *= smoothstep(begins,minf(1,begins+.12),entrance_progress)
		card.z_index=0
		card.size = Vector2(width,height)
		var row_start := (size.x-(width*model.enemy.size()+gap*(model.enemy.size()-1)))/2 if card.side == "enemy" else start
		card.position = Vector2(row_start+card.index*(width+gap),20 if card.side == "enemy" else size.y-height-16)
		if not model.paused:
			card.flash = maxf(0,card.flash-dt*owner_app.speed*4)
			card.motion_age += dt*owner_app.speed
			if not card.unit.is_empty():
				card.displayed_hp = float(card.unit.hp) if card.displayed_hp < 0 else lerpf(card.displayed_hp,float(card.unit.hp),1-exp(-dt*owner_app.speed*14))
		card.queue_redraw()
	if scenery.renderer is SegmentRenderer:scenery.renderer.battle_actors.clear()
	# A continuous landscape behind both formations; combat only reframes its horizon.
	scenery.position = Vector2.ZERO
	scenery.size = size
	scenery.renderer.horizon_ratio = .48 if scene_mode else lerpf(.48,.43,battle_mix)
	if scenery.renderer is SegmentRenderer:scenery.renderer.set_battle_camera(battle_mix,scene_mode)
	if scene_mode and not equipment_open:layout_scene_units()
	if equipment_open:
		var extra := maxf(0,216-scenery.position.y)
		scenery.position.y += extra
		scenery.size.y -= extra
	# Keep the extremely wide combat strip inside the populated forest field.
	scenery.renderer.minimum_focal = size.x*.15
	if not external_scenery: scenery.sync(Vector2(0,250),0,visual_time,0,0,false,false)
	if not model.paused:
		for effect in effects: effect.age += dt*owner_app.speed
		effects = effects.filter(func(e):return e.age < 1.0)
	vfx.queue_redraw()
	queue_redraw()
func _draw() -> void:
	pass
func aim_motion(card:BattleCard,other_uid:int,recoil:bool=false) -> void:
	var other:BattleCard=null
	for view in cards:
		if view.unit.get("uid",-1)==other_uid:other=view;break
	card.motion_origin=card.scene_motion_offset
	if other==null:
		card.motion_world_direction=Vector2.ZERO;card.motion_distance=0;return
	var line:=other.scene_rest_position-card.scene_rest_position
	card.motion_world_direction=line.normalized()*(-1.0 if recoil else 1.0)
	card.motion_direction=(anchor(other_uid)-anchor(card.unit.uid)).normalized()*(-1.0 if recoil else 1.0)
	var renderer:=scenery.renderer
	var depth:float=ForestRoute.to_camera(card.scene_rest_position,renderer.camera_world,renderer.heading).y
	card.motion_distance=minf(line.length()*.12,clampf(depth*.055,1.5,10))*(.65 if recoil else 1.0)

func on_event(event: Dictionary) -> void:
	if event.type in ["shot","cast"]:
		for card in cards:
			if card.unit.get("uid",-1) == event.from.uid:
				card.motion_age = 0
				card.motion_kind = "attack" if event.type == "shot" else "heal"
				card.motion_direction = (anchor(event.to.uid)-anchor(event.from.uid)).normalized()
				if scene_mode:aim_motion(card,event.to.uid)
	if event.type in ["damage","heal","revive","buff","death"]:
		particles.burst(event)
		var copy := event.duplicate()
		copy.age = 0.0
		copy.lane = effects.filter(func(e):return e.unit.uid == event.unit.uid and e.age < .5).size()%3
		effects.append(copy)
		for card in cards:
			if not card.unit.is_empty() and card.unit.uid == event.unit.uid:
				card.flash = 1
				card.motion_age = 0
				card.motion_kind = event.type
				if event.type == "damage":
					aim_motion(card,event.get("source",{}).get("uid",-1),true)
func draw_effects() -> void:
	for shot in model.shots:
		var a := anchor(shot.from.uid)
		var b := anchor(shot.to.uid)
		if StyleLibrary.active:
			OccultEffects.shot(vfx,shot,a,b)
			continue
		var t: float = clampf(shot.age/shot.duration,0,1)
		var color := Color("dfb968") if shot.from.side == "player" else Color("cb7967")
		color = {"fireball":Color("f3a35c"),"bind":Color("9acde8"),"bolt":Color("c6b6ff"),"mend":Color("9eda9c")}.get(shot.from.get("spellKind",""),color)
		var secondary_scale := .72 if shot.secondary else 1.0
		if shot.style == "beam":
			var envelope := minf(t/.12,1.0)*clampf((1-t)/.38,0,1)
			vfx.draw_line(a,b,Color(color,envelope*.15),12*secondary_scale,true)
			vfx.draw_line(a,b,Color(color,envelope),4*secondary_scale,true)
			vfx.draw_line(a,b,Color(Color("fff4cf"),envelope),1,true)
			var spark := a.lerp(b,t)
			vfx.draw_circle(spark,7*secondary_scale,Color(color,envelope*.5))
			if PROJECTILES.has(shot.from.cardId):
				var beam_type: String = PROJECTILES[shot.from.cardId]
				vfx.draw_set_transform(spark,t*TAU if beam_type in ["seal","mirror"] else (b-a).angle())
				var edge: float = PROJ_SIZE[beam_type]*secondary_scale
				vfx.draw_texture_rect(texture_for("assets/style-e/style-e-proj-%s.png" % beam_type),Rect2(Vector2.ONE*-edge/2,Vector2.ONE*edge),false,Color(1,1,1,envelope))
				vfx.draw_set_transform(Vector2.ZERO)
			continue
		var p := a.lerp(b,t)
		if shot.style == "melee":
			var e := 1-pow(1-t,2)
			var control := (a+b)/2+(b-a).normalized().orthogonal()*clampf(a.distance_to(b)*.24,24,68)
			p = a.lerp(control,e).lerp(control.lerp(b,e),e)
		if PROJECTILES.has(shot.from.cardId):
			var type: String = PROJECTILES[shot.from.cardId]
			var tex := texture_for("assets/style-e/style-e-proj-%s.png" % type)
			var angle := (b-a).angle()
			if type in ["seal","mirror"]: angle = t*TAU
			if type == "gourd": angle = 0
			var edge: float = PROJ_SIZE[type]*secondary_scale
			vfx.draw_line(p-(b-a).normalized()*18,p,Color(color,.3),2,true)
			vfx.draw_set_transform(p,angle)
			vfx.draw_texture_rect(tex,Rect2(Vector2(-edge/2,-edge/2),Vector2(edge,edge)),false)
			vfx.draw_set_transform(Vector2.ZERO)
			continue
		if shot.style == "beam":
			vfx.draw_line(a,b,Color(color,1-t*.7),4,true)
			vfx.draw_line(a,b,Color("fff4cf"),1,true)
		else:
			vfx.draw_line(p-(b-a).normalized()*22,p,color,3,true)
			vfx.draw_circle(p,5,color)
	for event in effects:
		var origin := anchor(event.unit.uid)
		if StyleLibrary.active: OccultEffects.impact(vfx,event,origin)
		if event.age < .3:
			var fade: float = 1-event.age/.3
			if event.type in ["heal","revive","buff"]:
				vfx.draw_arc(origin,18+event.age*90,0,TAU,40,Color(.6,.9,.75,fade*.7),2,true)
		var rise: float = 54*(1-pow(1-minf(event.age/.36,1),2)) if event.age < .36 else 54-20*clampf((event.age-.36)/.22,0,1)+8*clampf((event.age-.58)/.42,0,1)
		var p := anchor(event.unit.uid)+Vector2(-42+(event.get("lane",0)-1)*18,-24-rise-event.get("lane",0)*15)
		var value: String = str(int(event.get("amount",0)))
		var color := Color("f0bd9c")
		match event.type:
			"damage": value = ("暴击 -" if event.get("crit",false) else "-")+value
			"heal":
				value = "+"+value
				color = Color("a6d89b")
			"revive":
				value = "重聚"
				color = Color("bfc1e8")
			"buff":
				value = "增益 +"+value
				color = Color("abd6d8")
			"death": value = "倒下"
		color.a = clampf((1-event.age)/.45,0,1)
		var font_size := 22 if event.get("crit",false) else 18
		vfx.draw_string_outline(get_theme_default_font(),p,value,HORIZONTAL_ALIGNMENT_CENTER,100,font_size,3,Color(0,0,0,color.a*.8))
		vfx.draw_string(get_theme_default_font(),p,value,HORIZONTAL_ALIGNMENT_CENTER,100,font_size,color)

func set_scene_mode(value:bool) -> void:
	scene_mode=value
	var config:=ConfigFile.new();config.load("user://battle-presentation.cfg")
	config.set_value("cards","scene_mode",value);config.save("user://battle-presentation.cfg")

func scene_art(unit:Dictionary,side:String) -> Texture2D:
	var id:String=unit.get("cardId",unit.get("id",""))
	var key:String=StyleLibrary.CARDS.get(id,["",""])[0]
	if side=="player":
		if key in ["agent","medium"]:key+="-rear"
		elif key=="watch":key="watch-reverse" if relic_reverse else "watch-front"
	var path:="res://assets/style2/"+key+".png"
	if ResourceLoader.exists(path):return texture_for(path)
	return art_for(unit)

func layout_scene_units() -> void:
	SceneFormation.update(self)
