class_name SceneFormation
extends RefCounted
const SpatialMarks = preload("res://scripts/battle/asset_spatial_marks.gd")
## World-space battle feet use the same projection and painter order as vegetation.
static func update(arena:BattleArena) -> void:
	var renderer:=arena.scenery.renderer as SegmentRenderer
	if not renderer:return
	renderer.battle_actors.clear()
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
	var total:=0.0
	for view in player_order:total+=3.0 if view in people else 1.0
	var cursor:=0.0
	for view in player_order:
		var weight:=3.0 if view in people else 1.0
		var lane:=.05+.9*(cursor+weight*.5)/maxf(total,1)
		# Monotone remapping leaves a central sightline without changing card order.
		lane_centers[view.unit.uid]=remap(lane,.05,.5,.05,.36) if lane<=.5 else remap(lane,.5,.95,.64,.95)
		cursor+=weight
	# Divide each free interval among its consecutive props, preserving card order.
	var run:Array=[]
	var left_edge:=.10
	for i in range(player_order.size()+1):
		var view=player_order[i] if i<player_order.size() else null
		if view!=null and view not in people:
			run.append(view);continue
		var right_edge:float=maxf(left_edge+.02,lane_centers[view.unit.uid]-.08) if view!=null else .90
		for j in range(run.size()):lane_centers[run[j].unit.uid]=lerpf(left_edge,right_edge,(j+.5)/run.size())
		run.clear()
		if view!=null:left_edge=lane_centers[view.unit.uid]+.14
	var deployed:=arena.battle_mix
	var entering:bool=arena.owner_app.phase=="entering"
	var clock:float=arena.entrance_progress if entering else deployed
	var right:=Vector2(cos(renderer.heading),-sin(renderer.heading))
	var forward:=Vector2(sin(renderer.heading),cos(renderer.heading))
	var leaving:bool=arena.owner_app.phase=="clearing"
	var exit_t:float=1-deployed if leaving else 0.0
	# Frame once against the settled camera, not the changing transition camera.
	var settled_focal:float=renderer.focal()/renderer.combat_lens*.92
	var settled_eye:float=renderer.camera_height()-renderer.shoulder_lift+10
	var settled_horizon:float=renderer.horizon_y()+renderer.view_size.y*(renderer.battle_frame_shift-.19)
	for card in arena.cards:
		if card.unit.is_empty():continue
		var texture:=arena.scene_art(card.unit,card.side)
		if not texture:continue
		var person:=people.find(card)
		var source:Dictionary=arena.scene_enemy_sources.get(card.unit.uid,{})
		var reveal:float=arena.enemy_opacity*(1.0 if not source.is_empty() and not source.get("hidden",false) else smoothstep(.24,.48,clock)) if card.side=="enemy" else smoothstep(.18,.85,deployed)
		card.visible=reveal>.001 and (card.side=="player" or arena.enemies_visible)
		card.modulate.a=reveal
		if not card.visible:continue
		var x:=0.0;var z:=0.0;var world_height:=0.0;var altitude:=0.0
		if card.side=="enemy":
			var slot:int=card.index
			x=(slot-(arena.model.enemy.size()-1)*.5)*46
			z=210.0+8*(card.index%2);world_height=54.0
		elif person>=0:
			# Left means farther into the scene. Keep every character foot below the viewport.
			var far_depth:float=maxf(22,(settled_eye-5)*settled_focal/maxf(1,arena.size.y*1.15-settled_horizon))
			var rank:float=person/float(maxi(1,people.size()-1))
			var target_depth:float=far_depth*lerpf(1.0,.78,rank)
			z=target_depth-16
			world_height=46.0
			altitude=0.0
		else:
			var arc_x:float=clampf((lane_centers[card.unit.uid]-.5)/.46,-1,1)
			# A shallow companion arc: outer slots must not recede into roadside trees.
			z=44.0-8.0*sqrt(maxf(0,1-arc_x*arc_x))
			var placement:=SpatialMarks.prop_mark(card.unit)
			world_height=15.0
			# Clearance is above local terrain, not an offset in screen pixels.
			altitude=placement.clearance+sin(arena.visual_time*2+card.unit.uid)*placement.bob
		if card.side=="player":
			var lane:float=lane_centers[card.unit.uid]
			var target_x:float=(lane-.5)*arena.size.x*(z+16)/settled_focal
			x=target_x
		var world_position:=renderer.camera_world+right*x+forward*(z+16*deployed)
		if card.side=="enemy" and not source.is_empty():
			var hop:=smoothstep(.06 if card.index==0 else .24,.70 if card.index==0 else .90,clock)
			world_position=source.position.lerp(world_position,hop)
			world_height=lerpf(source.h,world_height,deployed)
			altitude=lerpf(source.get("altitude",0.0),altitude,hop)+sin(hop*PI)*(13 if card.index==0 else 19)
			texture=source.texture
		if card.side=="player" and person>=0:
			var rest_depth:float=z+16
			var rest_ground:=ForestEcology.height_at(world_position)-ForestEcology.height_at(renderer.camera_world)
			var enemy_baseline:float=settled_horizon+settled_eye*settled_focal/226
			var head_line:float=enemy_baseline+arena.size.y*.015
			var framed_height:float=maxf(12,settled_eye-rest_ground-altitude-(head_line-settled_horizon)*rest_depth/settled_focal)
			world_height=framed_height
		if card.side=="player":
			if entering:
				var chase:=smoothstep(.10,.90,clock)
				world_position-=forward*(z+28)*(1-chase)
				if person>=0:altitude+=absf(sin(clock*PI*5))*1.1*(1-chase)
			elif leaving:
				# Camera advances 36 extra units; the team walks only eight.
				world_position-=forward*28*exit_t
				if person>=0:altitude+=absf(sin(exit_t*PI*4))*.65
			var visible_depth:float=ForestRoute.to_camera(world_position,renderer.camera_world,renderer.heading).y
			reveal*=smoothstep(maxf(12,(z+16)*.70),maxf(25,(z+16)*.97),visible_depth) if entering else smoothstep(12,25,visible_depth)
			card.visible=reveal>.001
			if not card.visible:continue
		card.scene_rest_position=world_position
		var push:=motion_envelope(card.motion_kind,card.motion_age)
		card.scene_motion_offset=card.motion_world_direction*card.motion_distance*push+card.motion_origin*(1-smoothstep(0,.12,card.motion_age))
		world_position+=card.scene_motion_offset
		var relative:=ForestRoute.to_camera(world_position,renderer.camera_world,renderer.heading)
		var scale:=renderer.focal()/maxf(10,relative.y)
		var ground:=ForestEcology.height_at(world_position)-ForestEcology.height_at(renderer.camera_world)
		var foot:=Vector2(arena.size.x*.5+relative.x*scale,renderer.horizon_y()+(renderer.camera_height()-ground-altitude)*scale)
		var height:=world_height*scale
		var width:=height*texture.get_width()/float(texture.get_height())
		var battle_rect:=Rect2(foot-Vector2(width*.5,height),Vector2(width,height))
		card.scene_body_in_world=true
		var tint:=Color.WHITE if BattleRules.alive(card.unit) else Color(.4,.4,.4,.45)
		tint.a*=reveal
		var actor:Dictionary={"edge_strength":smoothstep(0,.4,arena.model.elapsed) if card.side=="enemy" and arena.owner_app.phase in ["battle","clearing"] else 0.0,"actor":true,"born_at":-100.0,"hidden":false,"position":world_position,"texture":texture,"w":world_height*texture.get_width()/float(texture.get_height()),"h":world_height,"altitude":altitude,"ground_anchor":Vector2(.5,1),"flip":card.side=="player" and person>=0 and lane_centers[card.unit.uid]>.5,"kind":0,"id":200000+card.unit.uid,"region":renderer.world.camera_region,"motion":"static","ecology_tint":tint}
		renderer.battle_actors.append(actor)
		card.size=battle_rect.size+Vector2(0,38)
		card.scene_head_uv=SpatialMarks.head_uv(card.unit,texture,actor.flip)
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
