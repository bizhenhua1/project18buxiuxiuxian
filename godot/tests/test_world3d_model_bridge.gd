extends SceneTree
const Bridge=preload("res://scripts/world3d/model_bridge.gd")
func place(unit:Dictionary)->Vector3:
	return Vector3(float(unit.index)*1.5,0,2 if unit.side=="player" else -5)
func _initialize():call_deferred("run")
func run():
	var model:=BattleModel.new();var bridge=Bridge.new();bridge.bind(model)
	var before:=JSON.stringify([model.player,model.enemy,model.elapsed,model.phase])
	bridge.sync(place)
	assert(before==JSON.stringify([model.player,model.enemy,model.elapsed,model.phase]),"Presentation mutated original rules")
	var uid:int=model.player[0].uid
	var original:Dictionary=bridge.bodies[uid]
	model.move(0,2);bridge.sync(place)
	assert(is_same(original,bridge.bodies[uid]),"Formation index must not own visual identity")
	var source:Dictionary=model.player.filter(func(u):return u.uid==uid)[0]
	var death_position:=Vector3(.5,0,1)
	bridge.record_presented_position(uid,death_position)
	source.hp=0;source.status="corpse";bridge.sync(place)
	assert(bridge.bodies[uid].position==death_position)
	source.index=7;bridge.sync(place)
	assert(bridge.bodies[uid].position==death_position,"Dead body was dragged by formation")
	source.reviveLeft=2500;bridge.sync(place);assert(bridge.bodies[uid].revive_seconds==2.5)
	source.hp=source.maxHp;source.status="alive";source.reviveLeft=0
	bridge.sync(place);assert(bridge.bodies[uid].state=="revive")
	assert(bridge.attack_position(uid)==death_position,"Revival teleported to formation")
	model.elapsed+=.8;bridge.sync(place)
	var previous:Vector3=bridge.attack_position(uid)
	model.elapsed+=.05;bridge.sync(place)
	assert(previous.distance_to(bridge.attack_position(uid))<=.06001,"Revive return exceeds natural speed")
	bridge.release();assert(not model.emitted.is_connected(bridge.on_event))
	# The same seeded combat, with and without presentation, must have identical
	# every-tick HP/shields, result, elapsed time and shot lifetimes.
	var a:=BattleModel.new();var b:=BattleModel.new()
	b.player=a.player.duplicate(true);b.enemy=a.enemy.duplicate(true)
	assert(a.start() and b.start());bridge.bind(b)
	for tick in 2400:
		a.advance(.05);b.advance(.05);bridge.sync(place)
		for row in bridge.bodies.values():
			var point:Vector3=bridge.attack_position(row.uid)
			if row.state!="death":assert(point.distance_to(row.home)<=Bridge.MELEE_REACH+.0001)
			bridge.record_presented_position(row.uid,point)
		bridge.take_effects()
		assert(JSON.stringify([a.player,a.enemy,a.phase,a.elapsed,a.shots])==JSON.stringify([b.player,b.enemy,b.phase,b.elapsed,b.shots]),"3D presentation changed combat result")
		if a.phase!="battle":break
	assert(a.phase!="battle","Fixture did not reach a result")
	bridge.release()
	print("MODEL_BRIDGE_PASS read-only rules, stable UID, corpse lock, revive, bounded melee, full combat parity result=",a.phase)
	quit()
