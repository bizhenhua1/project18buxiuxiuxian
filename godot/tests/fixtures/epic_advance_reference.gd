# Frozen pre-optimization particle update for numerical regression.
extends "res://scripts/spaces/epic181_effect.gd"
func advance(dt:float):
 age+=dt;var previous_position:=last_position;var travel:=global_position.distance_to(last_position);last_position=global_position
 for layer in layers:
  var d:Dictionary=layer.data;var time:float=age-sample(d.delay,0)
  if not stopped and time>=0 and (d.loop or time<d.duration):
   var cycle:=int(time/maxf(.01,d.duration));var local_time:=fmod(time,maxf(.01,d.duration))
   if cycle!=layer.cycle:layer.cycle=cycle;layer.burst=0
   var t:=local_time/maxf(.01,d.duration)
   layer.carry+=maxf(0,sample(d.rate,t))*dt+maxf(0,sample(d.distance_rate,t))*travel
   var count:=mini(CAP,int(layer.carry));layer.carry-=count
   for i in count:spawn(layer,previous_position.lerp(global_position,float(i+1)/maxi(1,count)))
   while layer.burst<d.bursts.size() and local_time>=d.bursts[layer.burst].time:
    if rng.randf()<=d.bursts[layer.burst].get("probability",1):
     for i in mini(CAP,int(sample(d.bursts[layer.burst].count,t))):spawn(layer,global_position)
    layer.burst+=1
  var alive:Array=[]
  for p in layer.particles:
   p.age+=dt
   if p.age>=p.life:continue
   var t:float=p.age/p.life;var random:float=p.random;var local:bool=d.get("local",false)
   var gravity:=Vector3.DOWN*9.81*sample(d.start.gravityModifier,t,random)*dt
   p.velocity+=global_basis.inverse()*gravity if local else gravity
   if not d.velocity.is_empty():
    var vel:=v([sample(d.velocity.x,t,random),sample(d.velocity.y,t,random),sample(d.velocity.z,t,random)])
    if local and d.get("velocity_world",false):vel=global_basis.inverse()*vel
    elif not local and not d.get("velocity_world",false):vel=global_basis*vel
    p.position+=vel*dt
   var limit:=sample(d.damping,t,random)
   if float(d.dampen)>0 and limit>0 and p.velocity.length()>limit:p.velocity=p.velocity.lerp(p.velocity.normalized()*limit,clampf(float(d.dampen)*dt*30,0,1))
   p.position+=p.velocity*dt;p.rotation+=sample(d.rotation,t,random)*dt
   var noise:=sample(d.noise,t,random)*.025
   var pos:Vector3=(p.position if local else to_local(p.position))+Vector3(sin(p.age*13+random*12),cos(p.age*17+random*6),sin(p.age*11))*noise
   var basis:Basis=layer.transform.basis
   if int(d.render_mode)!=4:
    basis=global_basis.orthonormalized().inverse()*camera.global_basis
    if int(d.render_mode)==1:
     var vel:Vector3=global_basis*p.velocity if local else p.velocity
     var projected:=Vector2(vel.dot(camera.global_basis.x),vel.dot(camera.global_basis.y))
     if projected.length()>.01:p.rotation=atan2(-projected.x,projected.y)
    if int(d.render_mode)==2:basis=global_basis.orthonormalized().inverse()*Basis(Vector3.RIGHT,PI*.5)
    basis=basis*Basis(Vector3.BACK,p.rotation)
   else:basis=Basis(Vector3.BACK,p.rotation)*basis
   var sz:float=maxf(.001,p.size*sample(d.size,t,random));var stretch:=Vector3.ONE
   if int(d.render_mode)==1:stretch.y=maxf(1,float(d.length_scale)+float(d.get("velocity_scale",0))*p.velocity.length()/sz)
   var index:=alive.size();layer.mm.set_instance_transform(index,Transform3D(basis.scaled(Vector3.ONE*sz*stretch),pos))
   var tile:float=p.tile;var sheet:Dictionary=d.get("sheet",{})
   if sheet.get("enabled",false):
    var frame:float=sample(sheet.frame,fmod(t*float(sheet.get("cycles",1)),1),random)+sample(sheet.start,0,random)
    tile=floor(fposmod(frame,.99999)*maxi(1,layer.tiles))
    if int(sheet.get("row_mode",0))==1:tile=int(sheet.get("row",0))*int(sheet.x)+fmod(tile,int(sheet.x))
   var color:=color_sample(d.color,0,random)*color_sample(d.gradient,t,random);layer.mm.set_instance_color(index,color);layer.mm.set_instance_custom_data(index,Color(tile,0,0,0));alive.append(p)
  layer.particles=alive;layer.mm.visible_instance_count=alive.size()
