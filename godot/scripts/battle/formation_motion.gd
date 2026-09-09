extends RefCounted
## Persistent world positions. Phase changes replace destinations, never current poses.
var units:Dictionary={}
var reference_ready:=false
var reference_origin:=Vector2.ZERO
func advance_reference(origin:Vector2,transport:bool) -> void:
 # Movement along the route is shared translation, not an error for the formation
 # spring to chase. The spring only resolves the remaining formation offset.
 if reference_ready and transport:
  var displacement:=origin-reference_origin
  for state in units.values():
   state.position+=displacement
   state.target+=displacement
 reference_origin=origin
 reference_ready=true
func move(uid:int,target:Vector2,spawn:Vector2,dt:float,freeze:bool=false) -> Vector2:
 if not units.has(uid):units[uid]={"position":spawn,"velocity":Vector2.ZERO,"target":target}
 var state:Dictionary=units[uid]
 state.target=target
 if freeze or dt<=0:return state.position
 var step:=minf(dt,.1)
 var error:Vector2=state.position-target
 var impulse:Vector2=state.velocity+8*error
 var decay:=exp(-8*step)
 var next:Vector2=target+(error+impulse*step)*decay
 var displacement:Vector2=(next-state.position).limit_length(TravelPace.RUN*step)
 state.position+=displacement
 state.velocity=(state.velocity-8*impulse*step)*decay
 state.velocity=state.velocity.limit_length(TravelPace.RUN)
 return state.position
func speed_of(uid:int) -> float:
 return units[uid].velocity.length() if units.has(uid) else 0.0
