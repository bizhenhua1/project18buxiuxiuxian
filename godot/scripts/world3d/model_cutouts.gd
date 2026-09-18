extends Node3D
## Original image units live in the same depth-tested world as model characters.
## No simulation, portrait atlas, per-frame image reads or implicit enemy replacement.
var bindings:Dictionary={}
var geometry:Dictionary={}
var smoke
var atmosphere=preload("res://scripts/world3d/prop_atmosphere.gd").new()
var layout:Callable
var selected_side:="enemy"
var bridge

func setup(source_bridge,placement:Callable,side:="enemy"):
	bridge=source_bridge;layout=placement;selected_side=side
	smoke=preload("res://scripts/world3d/defeat_clear.gd").new();add_child(smoke)
	smoke.setup(32)

func texture_for(unit:Dictionary)->Texture2D:
	var path:String=str(unit.get("art",""))
	if not path.is_empty():
		if not path.begins_with("res://"):path="res://"+path
		if ResourceLoader.exists(path):return load(path)
	return load(StyleLibrary.card_path(str(unit.cardId)))

func sync(renderer,camera:Camera3D):
	var model:BattleModel=bridge.model
	var sources:Array=model.enemy if selected_side=="enemy" else model.player
	var live:Dictionary={};var rebuild:=false
	for unit in sources:
		var uid:int=unit.uid;live[uid]=true
		if not bridge.bodies.has(uid):continue
		var body:Dictionary=bridge.bodies[uid]
		var texture:Texture2D=texture_for(unit)
		if texture==null:continue
		if bindings.has(uid) and bindings[uid].source!=texture:
			bindings[uid].node.queue_free();bindings.erase(uid);rebuild=true
		if not bindings.has(uid):
			if not geometry.has(texture):
				var image:=texture.get_image();var bounds:=image.get_used_rect()
				geometry[texture]={"bottom":bounds.end.y,"height":image.get_height()}
			var node:=Sprite3D.new();node.texture=texture
			node.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
			node.transparent=true;node.shaded=true
			node.offset.y=float(geometry[texture].bottom)-texture.get_height()*.5
			node.pixel_size=float(layout.call(unit).get("height",54.0))/20/texture.get_height()
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node);bindings[uid]={"node":node,"source":texture,"uid":uid};rebuild=true
		var entry:Dictionary=bindings[uid]
		entry.node.position=bridge.attack_position(uid)
		bridge.record_presented_position(uid,entry.node.position)
		entry.node.modulate.a=1.0;entry.node.visible=true
	for uid in bindings.keys():
		if not live.has(uid):bindings[uid].node.queue_free();bindings.erase(uid);rebuild=true
	if rebuild:
		atmosphere=preload("res://scripts/world3d/prop_atmosphere.gd").new()
		var props:Array=[];var profiles:Array=[]
		for entry in bindings.values():
			# The previous material may have substituted its mipmapped texture.
			entry.node.texture=entry.source
			props.append({"node":entry.node,"slot":props.size()});profiles.append({"clearance":0.0})
		atmosphere.setup(props,profiles)
	# One bounded smoke mesh for all dead image units. Revive eligibility is
	# taken directly from the original rule's pending countdown.
	smoke.entries.clear();smoke.age=model.elapsed
	for uid in bindings:
		var body:Dictionary=bridge.bodies.get(uid,{})
		if body.is_empty() or body.death_at<0 or body.revive_seconds>0:continue
		smoke.entries.append({"node":bindings[uid].node,"actor":false,"origin":body.frozen,
			"delay":body.death_at+5.0,"alpha":1.0,"height":1.0})
	smoke.multimesh.visible_instance_count=0;smoke.advance(0,camera)
	atmosphere.sync(renderer,true)
