class_name BattleParticles
extends Node2D
## Bounded one-shot native GPU emitters, one static AI brush stamp, no flipbooks.
const POOL_SIZE := 12
const PARTICLES_PER_EMITTER := 12
var pool: Array[Dictionary] = []
var materials := {}
var durations := {"damage":.28,"critical":.36,"heal":.65,"buff":.48,"death":.5}
var dropped := 0
var emitted_count := 0
var high_water := 0
var arena: BattleArena
func setup(value: BattleArena) -> void:
	arena = value
	for kind in durations: materials[kind] = make_material(kind)
	var texture: Texture2D = load("res://assets/fx/epic-toon/sparkle.png")
	for i in range(POOL_SIZE):
		var emitter := GPUParticles2D.new()
		emitter.emitting = false
		emitter.one_shot = true
		emitter.explosiveness = 1.0
		emitter.amount = PARTICLES_PER_EMITTER
		emitter.texture = texture
		emitter.local_coords = true
		emitter.fixed_fps = 60
		emitter.visibility_rect = Rect2(-180,-180,360,360)
		emitter.process_material = materials.damage
		add_child(emitter)
		pool.append({"node":emitter,"remaining":0.0,"uid":-1})
func make_material(kind: String) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	var gentle := kind in ["heal","buff"]
	material.direction = Vector3(0,-1,0)
	material.spread = 35 if gentle else 180
	material.gravity = Vector3(0,-15,0) if gentle else Vector3(0,110,0)
	material.initial_velocity_min = 24 if gentle else 65
	material.initial_velocity_max = 54 if gentle else 160
	material.damping_min = 12
	material.damping_max = 35
	material.angular_velocity_min = -100
	material.angular_velocity_max = 100
	material.angle_min = -180
	material.angle_max = 180
	material.scale_min = .13
	material.scale_max = .27 if kind == "critical" else .20
	# Preserve prior pixel footprint when using the larger source stamp.
	if kind != "death" or not StyleLibrary.active:
		material.scale_min *= 60.0/256.0
		material.scale_max *= 60.0/256.0
	if gentle:
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		material.emission_box_extents = Vector3(22,12,0)
	var color: Color = {"damage":Color("ffe2a0"),"critical":Color("fff0b6"),"heal":Color("8ae5ac"),"buff":Color("9bdde9"),"death":Color("928d79")}[kind]
	if StyleLibrary.active:
		color = {"damage":Color("e1b488"),"critical":Color("f5d9ac"),"heal":Color("87cacb"),"buff":Color("92bacb"),"death":Color("637782")}[kind]
	var gradient := Gradient.new()
	gradient.set_color(0,color)
	gradient.set_color(1,Color(color,0))
	gradient.add_point(.32,color)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_ramp = ramp
	return material
func burst(event: Dictionary) -> void:
	var kind: String = event.type
	if kind == "revive": kind = "heal"
	if kind == "damage" and event.get("crit",false): kind = "critical"
	if not materials.has(kind): return
	for slot in pool:
		if slot.remaining > 0: continue
		var emitter: GPUParticles2D = slot.node
		slot.uid = event.unit.uid
		slot.remaining = float(durations[kind])+.1
		emitter.position = arena.anchor(slot.uid)
		emitter.lifetime = durations[kind]
		if StyleLibrary.active:
			emitter.texture = StyleLibrary.texture("mist") if kind == "death" else load("res://assets/fx/epic-toon/sparkle.png")
		emitter.process_material = materials[kind]
		emitter.amount_ratio = 1.0 if kind == "critical" else .66 if kind in ["heal","buff"] else .5
		emitter.speed_scale = 0 if arena.model.paused else arena.owner_app.speed
		emitter.restart()
		emitter.emitting = true
		emitted_count += 1
		high_water = maxi(high_water,pool.filter(func(s):return s.remaining > 0).size())
		return
	dropped += 1
func advance(dt: float, speed: float, paused: bool) -> void:
	for slot in pool:
		var emitter: GPUParticles2D = slot.node
		emitter.speed_scale = 0 if paused else speed
		if slot.remaining <= 0: continue
		emitter.position = arena.anchor(slot.uid)
		if not paused: slot.remaining = maxf(0,slot.remaining-dt*speed)
func clear() -> void:
	for slot in pool:
		slot.remaining = 0
		slot.node.emitting = false
		slot.node.visible = false
		slot.node.restart()
		slot.node.emitting = false
		slot.node.visible = true
