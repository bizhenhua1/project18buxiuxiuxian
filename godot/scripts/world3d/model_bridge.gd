extends RefCounted
## Read-only presentation of the existing BattleModel. The route remains its clock owner.
## Positions are world metres; UID, not formation index, owns each visible lifetime.
var model:BattleModel
var bodies:Dictionary={}
var effects:Array=[]
var generation:=-1
const MAX_CUES:=128
const MELEE_REACH:=1.2

func bind(source:BattleModel)->void:
	if model!=null and model.emitted.is_connected(on_event):model.emitted.disconnect(on_event)
	model=source;bodies.clear();effects.clear();generation=source.result_generation
	model.emitted.connect(on_event)

func release()->void:
	if model!=null and model.emitted.is_connected(on_event):model.emitted.disconnect(on_event)
	model=null;bodies.clear();effects.clear()

func sync(placement:Callable)->Array:
	assert(model!=null)
	if generation!=model.result_generation:
		generation=model.result_generation;bodies.clear();effects.clear()
	var result:Array=[];var live:Dictionary={}
	for source in model.player+model.enemy:
		var uid:int=source.uid;live[uid]=true
		var home:Vector3=placement.call(source)
		if not bodies.has(uid):
			bodies[uid]={"uid":uid,"home":home,"position":home,"state":"idle","changed":model.elapsed,"death_at":-1.0,"attack_at":-INF,"attack_seconds":.7,"target":-1,"frozen":home}
		var body:Dictionary=bodies[uid]
		var dt:=maxf(0,model.elapsed-float(body.get("last_sync",model.elapsed)));body.last_sync=model.elapsed
		body.home=home;body.side=source.side;body.index=source.index;body.card_id=source.cardId
		body.art=str(source.get("art",""));body.is_character=preload("res://scripts/world3d/party.gd").character(source)
		body.hp=float(source.hp);body.max_hp=float(source.maxHp);body.shield=float(source.shield)
		body.revive_seconds=maxf(0,float(source.get("reviveLeft",0))*.001)
		body.health_revealed=body.hp<body.max_hp
		var dead:bool=not BattleRules.alive(source)
		if dead:
			if body.death_at<0:
				body.death_at=model.elapsed;body.frozen=body.position;body.changed=model.elapsed
			body.state="death";body.position=body.frozen
		else:
			if body.death_at>=0:
				body.death_at=-1.0;body.state="revive";body.changed=model.elapsed;body.attack_at=-INF
			elif body.state=="revive":
				if model.elapsed-float(body.changed)>.7:body.state="returning"
			elif body.state=="returning":
				body.position=body.position.move_toward(home,1.2*dt)
				if body.position.distance_squared_to(home)<.000001:body.state="idle"
			elif model.elapsed-float(body.attack_at)<float(body.attack_seconds):body.state="attack"
			else:body.state="idle"
			if body.state not in ["revive","returning"]:body.position=home
		result.append(body)
	for uid in bodies.keys():
		if not live.has(uid):bodies.erase(uid)
	return result

func record_presented_position(uid:int,point:Vector3)->void:
	if bodies.has(uid) and bodies[uid].death_at<0:bodies[uid].position=point

func attack_position(uid:int)->Vector3:
	var body:Dictionary=bodies[uid]
	if body.state=="death":return body.frozen
	if body.state in ["revive","returning"]:return body.position
	if body.state!="attack" or not body.get("melee",false):return body.home
	var target:Dictionary=bodies.get(body.target,{})
	if target.is_empty():return body.home
	var delta:Vector3=target.position-body.home;delta.y=0
	var reach:=minf(MELEE_REACH,maxf(0,delta.length()-.4))
	if reach<=0:return body.home
	var t:=clampf((model.elapsed-float(body.attack_at))/maxf(.01,float(body.attack_seconds)),0,1)
	var weight:=smoothstep(0,.42,t) if t<.42 else 1-smoothstep(.55,1,t)
	return body.home+delta.normalized()*reach*weight

func on_event(event:Dictionary)->void:
	if event.type in ["shot","cast"]:
		var uid:int=event.from.uid
		if bodies.has(uid):
			var body:Dictionary=bodies[uid]
			body.attack_at=model.elapsed;body.changed=model.elapsed
			body.target=int(event.to.uid);body.melee=str(event.get("style",""))=="melee"
			# Presentation can use a full clip while original hit timing stays authoritative.
			body.attack_seconds=maxf(.7,float(event.get("duration",.7)));body.state="attack"
	# Store identities, not live source dictionaries, in the cosmetic queue.
	var cue:Dictionary={"type":event.type,"time":float(event.get("time",model.elapsed))}
	for key in ["from","to","unit"]:
		if event.has(key):cue[key]=int(event[key].uid)
	for key in ["amount","style","duration","crit","secondary"]:
		if event.has(key):cue[key]=event[key]
	if effects.size()>=MAX_CUES:effects.pop_front()
	effects.append(cue)

func take_effects()->Array:
	var result:=effects;effects=[];return result
