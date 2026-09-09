extends RefCounted
## Presentation camera only. Real-time critically damped tracking has no speed multiplier.
var initialized:=false
var position:=Vector2.ZERO
var velocity:=Vector2.ZERO
var angle:=0.0
var blend:=0.0
var blend_velocity:=0.0
var reference_origin:=Vector2.ZERO
var reference_ready:=false
func advance_reference(origin:Vector2) -> void:
 if reference_ready:position+=origin-reference_origin
 reference_origin=origin;reference_ready=true
const RESPONSE:=24.0
func reset(at:Vector2,facing:float,mix:float) -> void:
 initialized=true;position=at;velocity=Vector2.ZERO;angle=facing;blend=mix;blend_velocity=0
func advance(target:Vector2,facing:float,mix:float,dt:float,paused:bool=false) -> void:
 if not initialized:reset(target,facing,mix)
 if paused:return
 # Exact critically damped solution for this frame's target, no Euler instability.
 var step:=clampf(dt,0,.1)
 var decay:=exp(-RESPONSE*step)
 var error:=position-target
 var impulse:=velocity+RESPONSE*error
 position=target+(error+impulse*step)*decay
 velocity=(velocity-RESPONSE*impulse*step)*decay
 angle=lerp_angle(angle,facing,1-exp(-10.0*step))
 var difference:=blend-mix
 var force:=blend_velocity+RESPONSE*difference
 blend=mix+(difference+force*step)*decay
 blend_velocity=(blend_velocity-RESPONSE*force*step)*decay

var walk_clock:=0.0
var walk_weight:=0.0
var walk_offset:=0.0
func advance_walk(movement:float,dt:float,paused:bool) -> void:
 if paused:return
 var step:=clampf(dt,0,.1)
 # Camera breathing is a presentation rhythm; gameplay multipliers cannot turn it into vibration.
 walk_weight=lerpf(walk_weight,clampf(movement,0,1),1-exp(-8.0*step))
 walk_clock=fmod(walk_clock+step*walk_weight,TAU/8.2)
 walk_offset=sin(walk_clock*8.2)*3.0*walk_weight
