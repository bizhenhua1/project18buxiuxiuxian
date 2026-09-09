extends Node2D
## Static source stamps animated by transforms and native GPU particles. No flipbooks.
const ROOT="res://assets/fx/epic-toon/"
const EFFECTS=[
 {"name":"斩击 · 金色裂光","stamp":"slash","color":"e7c193"},
 {"name":"冲击 · 扩散环","stamp":"ring","color":"8fd6e0"},
 {"name":"施法 · 符文","stamp":"magic_runecircle","color":"aab7ff"},
 {"name":"护盾 · 结界","stamp":"shield_magic","color":"7fcbd2"},
 {"name":"雷击 · 电弧","stamp":"lightning1","color":"afcaff"},
 {"name":"治疗 · 星屑","stamp":"sparkle","color":"9ad8bf"},
 {"name":"诅咒 · 幽魂","stamp":"evil_spirit","color":"bb93d1"},
 {"name":"毒雾 · 气泡","stamp":"bubble","color":"8cba83"}]
var age:=0.0
var rate:=1.0
var duration:=1.5
var kind:=0
var layers:Array[Sprite2D]=[]
var emitter:GPUParticles2D
func setup(index:int) -> void:
 kind=index
 var spec:Dictionary=EFFECTS[index]
 var tint=Color(spec.color)
 for name in ["glow",str(spec.stamp)]:
  var s=Sprite2D.new();s.texture=load(ROOT+name+".png")
  var mat=CanvasItemMaterial.new();mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;s.material=mat
  s.modulate=tint;add_child(s);layers.append(s)
 emitter=GPUParticles2D.new();emitter.emitting=false;emitter.one_shot=true;emitter.explosiveness=.92
 emitter.amount=32;emitter.lifetime=.9;emitter.texture=load(ROOT+("bubble" if kind==7 else "sparkle")+".png")
 emitter.visibility_rect=Rect2(-400,-400,800,800)
 var m=ParticleProcessMaterial.new();m.particle_flag_disable_z=true
 m.direction=Vector3(0,-1,0);m.spread=180 if kind<5 else 45
 m.initial_velocity_min=35;m.initial_velocity_max=150
 m.gravity=Vector3(0,-35 if kind>=5 else 45,0);m.damping_min=20;m.damping_max=50
 m.scale_min=.025;m.scale_max=.085
 var gradient=Gradient.new();gradient.set_color(0,tint);gradient.set_color(1,Color(tint,0))
 var ramp=GradientTexture1D.new();ramp.gradient=gradient;m.color_ramp=ramp
 emitter.process_material=m
 var blend=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;emitter.material=blend
 add_child(emitter);emitter.restart();emitter.emitting=true
func advance(dt:float) -> void:
 age+=dt*rate
 emitter.speed_scale=rate
 var t=clampf(age/duration,0,1)
 for i in range(layers.size()):
  var s=layers[i]
  var size=220.0 if i==0 else 170.0
  var envelope=pow(1.0-t,1.4)*minf(age/.06,1.0)
  if kind in [2,3,6,7]:envelope=sin(t*PI)
  s.modulate.a=envelope*(.32 if i==0 else 1.0)
  var growth=lerpf(.55,1.5,t) if kind==1 else lerpf(.85,1.12,t)
  s.scale=Vector2.ONE*size/float(s.texture.get_width())*growth
  if i==1 and kind==2:s.rotation=t*1.3
  if i==1 and kind==4:s.modulate.a*=.65+.35*sin(age*65)
  if i==1 and kind>=5:s.position.y=-t*35
 if age>=duration:queue_free()
