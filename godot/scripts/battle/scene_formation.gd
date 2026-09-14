class_name SceneFormation
extends RefCounted
const SpatialMarks = preload("res://scripts/battle/asset_spatial_marks.gd")
## World-space battle feet use the same projection and painter order as vegetation.
static func update(arena:BattleArena,dt:float=0.0) -> void:
	var renderer:=arena.scenery.renderer as SegmentRenderer
	if not renderer:return
	renderer.battle_actors.clear()
	arena.formation_ready=true
	arena.enemy_backdrop.visible=false;arena.player_backdrop.visible=false
	var people:Array=[];var props:Array=[]
	for card in arena.cards:
		card.scene_body_in_world=false
		if card.unit.is_empty():card.visible=false;continue
		if card.side=="player":
			if card.unit.get("portrait_kind","")=="person" or card.unit.cardType=="char":people.append(card)
			else:props.append(card)
	people.sort_custom(func(a,b):return a.index<b.index)
	# Keep the actual formation order, including props between characters.
	var player_order:Array=arena.cards.filter(func(c):return c.side=="player" and not c.unit.is_empty())
	player_order.sort_custom(func(a,b):return a.index<b.index)
	var lane_centers:Dictionary={}
	# Every card receives one equal angular sector, irrespective of character or prop.
	var arc_angles:Dictionary={}
	for i in range(player_order.size()):
		var t:float=(i+.5)/maxi(1,player_order.size())
		var angle:=lerpf(-PI/3,PI/3,t)
		arc_angles[player_order[i].unit.uid]=angle
		lane_centers[player_order[i].unit.uid]=.5+.46*sin(angle)
	var live_template=arena.owner_app.get("live_template")
	var template_enabled:bool=live_template!=null and not live_template.data.is_empty() and not arena.owner_app.has_meta("traditional_editor")
	if template_enabled:
		var model_uids:Array=[]
		for unit in arena.model.player:
			if arena.equipped_actors.has(unit.uid):model_uids.append(unit.uid)
		live_template.prepare_slots(arena.model.player,model_uids)
	var entering:bool=arena.owner_app.phase=="entering"
	var clock:float=arena.entrance_progress if entering else (1.0 if arena.owner_app.phase in ["battle","clearing","defeat","reviving"] else 0.0)
	var moving:bool=arena.owner_app.phase in ["travel","approach","sighting","encounter","choose"]
	var route_pose:Dictionary=ForestRoute.pose(float(arena.owner_app.distance),int(arena.owner_app.branch))
	var frame_heading:float=route_pose.heading if moving else arena.world_facing
	var frame_origin:Vector2=route_pose.position if moving else arena.world_anchor
	var right:=Vector2(cos(frame_heading),-sin(frame_heading))
	var forward:=Vector2(sin(frame_heading),cos(frame_heading))
	var leaving:bool=arena.owner_app.phase=="clearing"
	var reference:Vector2=route_pose.position
	if leaving:reference=ForestRoute.pose(float(arena.owner_app.distance)+arena.owner_app.EXIT_ADVANCE*smoothstep(0,1.4,float(arena.owner_app.clearing_time)),int(arena.owner_app.branch)).position
	arena.formation_motion.advance_reference(reference,arena.owner_app.phase in ["travel","approach"])
	# Frame once against the settled camera, not the changing transition camera.
	var settled_focal:float=renderer.focal()/renderer.combat_lens*.92
	var settled_eye:float=renderer.camera_height()-renderer.shoulder_lift+10
	var settled_horizon:float=renderer.horizon_y()+renderer.view_size.y*(renderer.battle_frame_shift-.19)
	if template_enabled:
		# The editor captured original world slots before camera editing. Keep that same
		# reference here: live camera changes must never move the travel destination.
		settled_focal=maxf(renderer.minimum_focal,minf(renderer.view_size.y*.86,renderer.view_size.x*.72))*float(ForestSettings.values.get("camera_lens",1.0))*.92
		settled_eye=float(ForestSettings.values.get("camera_height",58.0))+10
		settled_horizon=renderer.view_size.y*(float(ForestSettings.values.get("camera_horizon",.48))-.19)
	for card in arena.cards:
		if card.unit.is_empty():continue
		var live:bool=arena.seer!=null and card.side=="player" and card.unit.uid==arena.seer.uid
		var ally_actor=arena.equipped_actors.get(card.unit.uid)
		var ally_live:bool=ally_actor!=null and not live and card.side=="player"
		var enemy_live:bool=arena.enemy_actor!=null and card.side=="enemy" and card.index==0 and not card.unit.get("fairytale_enemy",false)
		var texture:Texture2D=arena.seer.texture() if live else arena.scene_art(card.unit,card.side)
		if ally_live:texture=ally_actor.texture()
		if enemy_live:texture=arena.enemy_actor.texture()
		if not texture:continue
		var person:=people.find(card)
		var source:Dictionary=arena.scene_enemy_sources.get(card.unit.uid,{})
		var reveal:float=arena.enemy_opacity*(1.0 if not source.is_empty() and not source.get("hidden",false) else smoothstep(.24,.48,clock)) if card.side=="enemy" else smoothstep(.35,.65,clock)
		if live:reveal=1.0
		card.visible=reveal>.001 and (card.side=="player" or arena.enemies_visible)
		card.modulate.a=reveal
		if not card.visible:continue
		# Plan the composition once. Camera movement/zoom never updates these dimensions.
		if not arena.world_slots.has(card.unit.uid):
			var x:=0.0;var depth:=0.0;var height:=0.0;var clearance:=0.0
			if card.side=="enemy":
				x=(card.index-(arena.model.enemy.size()-1)*.5)*46
				depth=226.0+8*(card.index%2);height=70 if enemy_live else 54
			else:
				var angle:float=arc_angles[card.unit.uid]
				var t:float=(player_order.find(card)+.5)/maxi(1,player_order.size())
				var radius:=maxf(22,(settled_eye-5)*settled_focal/maxf(1,arena.size.y*1.15-settled_horizon))
				# A shallow arc; the slight tilt retains left-to-right depth layering.
				depth=radius*(1.06-.12*cos(angle)-.10*t)
				x=(lane_centers[card.unit.uid]-.5)*arena.size.x*depth/settled_focal
				if person>=0:
					var baseline:=settled_horizon+settled_eye*settled_focal/226+arena.size.y*.015
					height=maxf(12,settled_eye-(baseline-settled_horizon)*depth/settled_focal)
					if live:height=38.0
					if ally_live:height*=1.35
				else:
					# Props occupy the same angular sectors on a slightly outer ring.
					depth*=1.55
					x=(lane_centers[card.unit.uid]-.5)*arena.size.x*depth/settled_focal
					height=15
					clearance=SpatialMarks.prop_mark(card.unit).clearance
			arena.world_slots[card.unit.uid]={"x":x,"depth":depth,"height":height,"clearance":clearance,"right_facing":lane_centers.get(card.unit.uid,.5)>.5}
		var slot:Dictionary=arena.world_slots[card.unit.uid]
		if template_enabled and card.side=="player":live_template.apply_slot(card.unit.uid,slot,dt)
		# Fixed default travel rig, independent of card order or hero slot.
		var travel_focal:=settled_focal/.92
		var travel_horizon:=settled_horizon+renderer.view_size.y*.19
		renderer.travel_eye_offset=38.0*.83+(arena.size.y*.60-travel_horizon)*32.0/travel_focal-(settled_eye-10)
		renderer.travel_lateral=0.0

		var world_height:float=slot.height
		if live:world_height*=arena.seer.frame_scale()
		elif ally_live:world_height*=ally_actor.frame_scale()
		elif enemy_live:world_height*=arena.enemy_actor.frame_scale()
		var altitude:float=slot.clearance
		var world_position:Vector2=frame_origin+right*float(slot.x)+forward*float(slot.depth)
		if card.side=="enemy" and not source.is_empty():
			var hop:=smoothstep(.06 if card.index==0 else .24,.70 if card.index==0 else .90,clock) if entering else 1.0
			world_position=source.position.lerp(world_position,hop)
			altitude+=sin(hop*PI)*(13 if card.index==0 else 19)
		if card.side=="player":
			var phase:String=arena.owner_app.phase
			var travel_distance:float=arena.owner_app.distance
			if leaving:travel_distance+=arena.owner_app.EXIT_ADVANCE*smoothstep(0,1.4,float(arena.owner_app.clearing_time))
			var travel_pose:Dictionary=ForestRoute.pose(travel_distance,int(arena.owner_app.branch))
			var travel_right:=Vector2(cos(travel_pose.heading),-sin(travel_pose.heading))
			var travel_forward:=Vector2(sin(travel_pose.heading),cos(travel_pose.heading))
			var travel_offset:Vector2=preload("res://scripts/traditional/travel_rig.gd").offset(arena.size.x,travel_focal)
			var travel_position:Vector2=travel_pose.position+travel_right*travel_offset.x+travel_forward*travel_offset.y
			if not live:travel_position+=travel_right*(card.index-2)*5-travel_forward*8
			var deployed:bool=phase in ["entering","battle","defeat","reviving"]
			var target:Vector2=world_position if deployed else travel_position
			if leaving and not live:target=card.scene_rest_position
			world_position=arena.formation_motion.move(card.unit.uid,target,travel_position,dt,(leaving and not live) or phase in ["defeat","reviving"] or (phase=="battle" and not template_enabled))
			if world_position.distance_to(target)>.7:arena.formation_ready=false
			if not live:
				if moving:reveal=0
				elif leaving:reveal*=1-smoothstep(0,.7,float(arena.owner_app.clearing_time))
			if person<0:altitude+=sin(arena.visual_time*2+card.unit.uid)*SpatialMarks.prop_mark(card.unit).bob
		if live and BattleRules.alive(card.unit):
			var facing:=PI-.12 if moving or leaving else PI+(.22 if slot.right_facing else -.22)
			arena.seer.body.rotation.y=lerp_angle(arena.seer.body.rotation.y,facing,1-exp(-8*dt))
		# Preserve the last presented pose, including any attack offset, for the fade.
		var hold_exit:bool=leaving and card.side=="player" and not live
		if hold_exit and not card.has_meta("exit_pose"):
			card.set_meta("exit_pose",{"position":card.scene_rest_position+card.scene_motion_offset,"altitude":altitude})
		elif not hold_exit and card.has_meta("exit_pose"):card.remove_meta("exit_pose")
		card.scene_rest_position=world_position
		var push:=motion_envelope(card.motion_kind,card.motion_age)
		if card.motion_kind=="sword_combo":
			var attack_t:float=card.motion_age/maxf(.1,float(card.unit.get("combo_duration",1.0)))
			push=smoothstep(0,.30,attack_t)*(1-smoothstep(.58,1.0,attack_t))
		card.scene_motion_offset=card.motion_world_direction*card.motion_distance*push+card.motion_origin*(1-smoothstep(0,.12,card.motion_age))
		world_position+=card.scene_motion_offset
		if hold_exit:
			world_position=card.get_meta("exit_pose").position
			altitude=card.get_meta("exit_pose").altitude
		if live or ally_live or enemy_live:
			if not BattleRules.alive(card.unit):
				if not card.has_meta("corpse_position"):card.set_meta("corpse_position",world_position)
				world_position=card.get_meta("corpse_position")
				card.scene_motion_offset=Vector2.ZERO
			elif card.has_meta("corpse_position"):
				card.set_meta("return_position",card.get_meta("corpse_position"));card.remove_meta("corpse_position")
			card.unit.returning_to_slot=card.has_meta("return_position")
			if card.has_meta("return_position"):
				var returning:Vector2=card.get_meta("return_position").move_toward(world_position,TravelPace.WALK*dt)
				if returning.distance_to(world_position)<.1:card.remove_meta("return_position");card.unit.returning_to_slot=false
				else:card.set_meta("return_position",returning)
				world_position=returning
		var relative:=ForestRoute.to_camera(world_position,renderer.camera_world,renderer.heading)
		var scale:=renderer.focal()/maxf(10,relative.y)
		var ground:=ForestEcology.height_at(world_position)-ForestEcology.height_at(renderer.camera_world)
		var foot:=Vector2(arena.size.x*.5+relative.x*scale,renderer.horizon_y()+(renderer.camera_height()-ground-altitude)*scale)
		var height:=world_height*scale
		var width:=height*texture.get_width()/float(texture.get_height())
		var battle_rect:=Rect2(foot-Vector2(width*.5,height),Vector2(width,height))
		card.scene_body_in_world=true
		var tint:=Color.WHITE if BattleRules.alive(card.unit) or live or ally_live or enemy_live else Color(.4,.4,.4,.45)
		tint.a*=reveal
		var actor:Dictionary={"edge_strength":smoothstep(0,.4,arena.model.elapsed) if card.side=="enemy" and arena.owner_app.phase in ["battle","clearing"] else 0.0,"actor":true,"born_at":-100.0,"hidden":false,"position":world_position,"texture":texture,"w":world_height*texture.get_width()/float(texture.get_height()),"h":world_height,"altitude":altitude,"ground_anchor":Vector2(.5,1),"flip":card.side=="player" and person>=0 and slot.right_facing,"kind":0,"id":200000+card.unit.uid,"region":renderer.world.camera_region,"motion":"static","ecology_tint":tint}
		if enemy_live:
			actor.live_enemy=true
			if arena.enemy_actor.dead:actor.edge_strength*=1-smoothstep(.3,1.4,arena.enemy_actor.elapsed)
			actor.ground_anchor=Vector2(.5,arena.enemy_actor.ground_uv())
			battle_rect.position.y+=height*(1-arena.enemy_actor.ground_uv())
		if live:
			actor.live_character=true;actor.flip=false
			actor.ground_anchor=Vector2(.5,lerpf(.93,arena.seer.ground_uv(),arena.seer.corpse_frame))
		if ally_live:
			actor.live_companion=true;actor.flip=false
			actor.ground_anchor=Vector2(.5,ally_actor.ground_uv())
			if BattleRules.alive(card.unit):ally_actor.body.rotation.y=PI+(.22 if slot.right_facing else -.22)
			battle_rect.position.y+=height*(1-ally_actor.ground_uv())
		renderer.battle_actors.append(actor)
		card.size=battle_rect.size+Vector2(0,38)
		card.scene_head_uv=arena.enemy_actor.head_uv() if enemy_live else SpatialMarks.head_uv(card.unit,texture,actor.flip)
		card.position=battle_rect.position
		card.modulate.a=reveal*smoothstep(.50,.90,arena.battle_mix)
		card.z_index=20

static func motion_envelope(kind:String,age:float) -> float:
	if kind=="attack":
		if age<.045:return -.12*smoothstep(0,.045,age)
		if age<.14:return lerpf(-.12,1,smoothstep(.045,.14,age))
		return 1-smoothstep(.14,.38,age)
	if kind=="damage":
		if age<.065:return smoothstep(0,.065,age)
		if age<.24:return 1-smoothstep(.065,.24,age)
		return -.10*sin(clampf((age-.24)/.12,0,1)*PI)
	return 0.0
