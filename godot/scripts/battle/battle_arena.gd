class_name BattleArena
extends Control
var model: BattleModel
var owner_app: Control
var cards: Array[BattleCard] = []
var textures := {}
var effects: Array[Dictionary] = []
var light_flashes:Array[Dictionary]=[]
var selected_uid := -1
var scenery: CorridorView
var vfx: Node2D
var sigil_font: SystemFont
var external_scenery := false
var equipment_open := false
var scene_enemy_sources:Dictionary={}
var formation_motion=preload("res://scripts/battle/formation_motion.gd").new()
var formation_ready:=false
var world_slots:Dictionary={}
var world_lineup:Array=[]
var world_anchor:=Vector2.ZERO
var world_facing:=0.0
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
var equipped_actors:Dictionary={}
var companion_actor:Node
var enemy_actor:Node
var seer:Node
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
	if StyleLibrary.active:
		var selection=ConfigFile.new();var hero_index:=0
		if selection.load("user://world-hero.cfg")==OK:hero_index=clampi(int(selection.get_value("hero","index",0)),0,preload("res://scripts/spaces/character_library.gd").MODELS.size()-1)
		enemy_actor=preload("res://scripts/battle/enemy_actor.gd").new();add_child(enemy_actor)
	rebuild()
func clean_path(path: String) -> String:
	path = StyleLibrary.path(path)
	if path.begins_with("res://"): return path.trim_prefix("res://")
	var derived := "assets/cleaned/"+path.get_file()
	return derived if path.begins_with("assets/style-e/") and ResourceLoader.exists("res://"+derived) else path
func art_for(unit: Dictionary) -> Texture2D:
	if StyleLibrary.active and (unit.get("cardType","")=="char" or unit.get("portrait_kind","")=="person") and unit.get("side","player")=="player":
		var model_file:String=preload("res://scripts/equipment/loadouts.gd").model_for_unit(unit)
		var portrait:String="res://assets/character-portraits/"+model_file.get_basename()+".png"
		if ResourceLoader.exists(portrait):
			if not art_textures.has(portrait):art_textures[portrait]=load(portrait)
			return art_textures[portrait]
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
	if StyleLibrary.active:_sync_equipped_actors()
	var lineup:Array=model.player.map(func(unit):return unit.uid)
	if lineup!=world_lineup:
		world_slots.clear()
		world_lineup=lineup
	var living_ids:Array=lineup+model.enemy.map(func(unit):return unit.uid)
	for uid in world_slots.keys():
		if uid not in living_ids:world_slots.erase(uid)
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
	if scenery.renderer is SegmentRenderer:
		scenery.renderer.combat_lights.clear()
		for light in light_flashes:
			if not model.paused:light.age+=dt*owner_app.speed
			if light.age>=light.duration:continue
			var pulse:Dictionary=light.duplicate()
			pulse.energy=light.strength*smoothstep(0,.035,light.age)*pow(1-light.age/light.duration,2)
			scenery.renderer.combat_lights.append(pulse)
		light_flashes=light_flashes.filter(func(light):return light.age<light.duration)
	if scenery.renderer is SegmentRenderer:
		for equipped in equipped_actors.values():equipped.scene_light_tint=scenery.renderer.environment_light_tint()
	if seer:
		var heroes=model.player.filter(func(u):return u.uid==seer.uid)
		if not heroes.is_empty():seer.bind_unit(heroes[0])
		if not heroes.is_empty() and float(heroes[0].hp)>0 and seer.defeated:seer.trigger("revive")
		seer.opening_run=external_scenery and owner_app.route_travel_speed()>TravelPace.WALK*1.1 and str(owner_app.get("phase")) in ["travel","approach"]
		var walk_input:float=float(owner_app.get("moving_envelope")) if external_scenery else 0.0
		if str(owner_app.get("phase")) in ["entering","clearing","encounter"] and not heroes.is_empty():walk_input=clampf(formation_motion.speed_of(heroes[0].uid)/TravelPace.WALK,0,1)
		seer.opening_run=seer.opening_run or (str(owner_app.get("phase")) in ["entering","clearing"] and not heroes.is_empty() and formation_motion.speed_of(heroes[0].uid)>TravelPace.WALK*1.1)
		seer.sync(dt,str(owner_app.get("phase")),walk_input,model.paused,owner_app.speed,scene_mode and not equipment_open,float(owner_app.get("presented_travel_distance")) if external_scenery else 0.0)
	for actor_uid in equipped_actors:
		var actor=equipped_actors[actor_uid]
		if actor==seer:continue
		var matches=model.player.filter(func(u):return u.uid==actor_uid)
		if matches.is_empty():continue
		actor.bind_unit(matches[0])
		actor.sync(dt,str(owner_app.get("phase")),0.0 if owner_app.phase=="clearing" else clampf(formation_motion.speed_of(actor_uid)/TravelPace.WALK,0,1),model.paused,owner_app.speed,scene_mode and not equipment_open)
	if enemy_actor:
		if scenery.renderer is SegmentRenderer:
			var light_tint:Color=scenery.renderer.enemy_light_tint()
			enemy_actor.team_key.light_color=Color("bedae0")*light_tint
		if not model.enemy.is_empty() and not model.enemy[0].get("fairytale_enemy",false):enemy_actor.bind_unit(model.enemy[0])
		elif enemy_actor.health_effect:enemy_actor.health_effect.unit={}
		enemy_actor.advance(dt,str(owner_app.get("phase")),model.paused,owner_app.speed,scene_mode and not model.enemy.is_empty(),entrance_progress)
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
	scenery.renderer.view_size=size
	scenery.renderer.minimum_focal=size.x*.15
	if scene_mode and not equipment_open and size.x>1 and size.y>1:layout_scene_units(0.0 if model.paused else dt*owner_app.speed)
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
func restore_victorious_party() -> void:
	for unit in model.player:
		BattleRules.reset(unit)
		unit.returning_to_slot=false
		var actor=equipped_actors.get(unit.uid)
		if actor:
			actor.trigger("revive")
			if actor.health_effect:actor.health_effect.progress=0.0
	for card in cards:
		if card.side!="player" or card.unit.is_empty():continue
		if card.has_meta("corpse_position"):card.scene_rest_position=card.get_meta("corpse_position")
		for key in ["corpse_position","return_position","exit_pose"]:
			if card.has_meta(key):card.remove_meta(key)
		card.motion_kind="";card.motion_age=10;card.motion_distance=0
		card.motion_origin=Vector2.ZERO;card.scene_motion_offset=Vector2.ZERO
		formation_motion.units[card.unit.uid]={"position":card.scene_rest_position,"target":card.scene_rest_position,"velocity":Vector2.ZERO}
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

func flash_light(unit:Dictionary,color:Color,strength:float,radius:float) -> void:
	if not scene_mode or not scenery.renderer is SegmentRenderer:return
	for card in cards:
		if card.unit.get("uid",-1)!=unit.get("uid",-2):continue
		var point:Vector2=card.scene_rest_position
		var altitude:float=22.0 if card.side=="player" else 28.0
		light_flashes.append({"position":Vector3(point.x,altitude,point.y),"color":color,"radius":radius,"strength":strength,"age":0.0,"duration":.42})
		while light_flashes.size()>4:light_flashes.pop_front()
		break
func on_event(event: Dictionary) -> void:
	var source_unit:Dictionary=event.get("from",event.get("unit",{}))
	var actor=equipped_actors.get(int(source_unit.get("uid",-2)))
	if actor and not (event.type=="shot" and event.get("secondary",false)):
		actor.trigger(event.type)
		if event.type=="shot":event.combo_stage=source_unit.get("combo_stage",1)
	if enemy_actor:
		var unit:Dictionary=event.get("from",event.get("unit",{}))
		if int(unit.get("uid",-2))==enemy_actor.uid:enemy_actor.trigger(event.type)
	# Generic combat events do not emit light; future luminous skills opt in explicitly.
	if event.type in ["shot","cast"] and not event.get("secondary",false):
		for card in cards:
			if card.unit.get("uid",-1) == event.from.uid:
				card.motion_age = 0
				card.motion_kind = "sword_combo" if event.type=="shot" and card.unit.get("sword_combo",false) else "attack" if event.type == "shot" else "heal"
				card.motion_direction = (anchor(event.to.uid)-anchor(event.from.uid)).normalized()
				if scene_mode:
					aim_motion(card,event.to.uid)
					if card.unit.get("sword_combo",false):
						var meter:float=seer.world_units_per_meter if seer else 30.0
						card.motion_distance=minf(card.scene_rest_position.distance_to(_unit_world_position(event.to.uid))*.18,meter*1.2)
	if event.type in ["damage","heal","revive","buff","death"]:
		particles.burst(event)
		var copy := event.duplicate()
		copy.age = 0.0
		copy.lane = effects.filter(func(e):return e.unit.uid == event.unit.uid and e.age < .5).size()%3
		effects.append(copy)
		for card in cards:
			if not card.unit.is_empty() and card.unit.uid == event.unit.uid:
				if event.type=="death":
					card.set_meta("corpse_position",card.scene_rest_position+card.scene_motion_offset)
					card.motion_distance=0;card.motion_origin=Vector2.ZERO;card.scene_motion_offset=Vector2.ZERO
				if event.type=="revive" and card.has_meta("corpse_position"):
					card.set_meta("return_position",card.get_meta("corpse_position"));card.remove_meta("corpse_position")
				card.flash = 1
				if event.type=="damage" and card.motion_kind=="sword_combo" and card.motion_age<float(card.unit.get("combo_duration",1.0)):continue
				card.motion_age = 0
				card.motion_kind = event.type
				if event.type == "damage":
					aim_motion(card,event.get("source",{}).get("uid",-1),true)
func draw_effects() -> void:
	for shot in model.shots:
		if shot.get("style", "") == "melee" or shot.from.get("sword_combo", false): continue
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

func layout_scene_units(dt:float=0.0) -> void:
	SceneFormation.update(self,dt)

func _unit_world_position(uid:int) -> Vector2:
	for card in cards:
		if card.unit.get("uid",-1)==uid:return card.scene_rest_position
	return Vector2.ZERO

func _sync_equipped_actors() -> void:
	var people:Array=model.player.filter(func(u):return u.cardType=="char" or u.get("portrait_kind","")=="person")
	var living_ids:Array=people.map(func(u):return u.uid)
	for id in equipped_actors.keys():
		if id not in living_ids:
			equipped_actors[id].queue_free();equipped_actors.erase(id)
	var roster:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_roster.json"))
	for unit in people:
		if not equipped_actors.has(unit.uid):
			var file:String=unit.get("model_file","isabella.glb")
			if unit.cardId=="daotong":
				var config=ConfigFile.new();config.load("user://world-hero.cfg")
				file=roster[clampi(int(config.get_value("hero","index",0)),0,roster.size()-1)].file
			var actor=preload("res://scripts/battle/equipped_actor.gd").new()
			actor.model_key=file;actor.model_scene=load("res://assets/characters3d/"+file);actor.ally=true;add_child(actor)
			equipped_actors[unit.uid]=actor
		equipped_actors[unit.uid].bind_unit(unit)
	var leaders:Array=people.filter(func(u):return u.cardId=="daotong")
	seer=equipped_actors.get(leaders[0].uid) if not leaders.is_empty() else equipped_actors.get(people[0].uid) if not people.is_empty() else null
	companion_actor=equipped_actors.get(people[1].uid) if people.size()>1 else null
