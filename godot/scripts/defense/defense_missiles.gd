extends Node
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LIB="res://assets/fx/epic181/library/"
var app
var viewport:SubViewport
var camera:Camera3D
var pool:Dictionary={}
var flights:Array=[]
var particles:Array=[]
var bursts:Array=[]
var settings:Dictionary={}
var entries:Dictionary={}
func setup(owner_app):
 app=owner_app
 var catalog=JSON.parse_string(FileAccess.get_file_as_string(LIB+"index.json"))
 var missile:Dictionary={}
 for entry in catalog:
  if entry.name=="StormMissile":missile=entry;break
 for pair in [["missile",missile.id],["muzzle",missile.muzzle_id],["impact",missile.impact_id]]:
  for entry in catalog:
   if entry.id==pair[1]:entries[pair[0]]=entry;break
 settings=preload("res://scripts/spaces/vfx_preview.gd").LIGHT_DEFAULTS.duplicate();settings.missile_light_enabled=true
 var path="user://projectile-light-profiles.json"
 if FileAccess.file_exists(path):
  var saved=JSON.parse_string(FileAccess.get_file_as_string(path))
  if saved is Dictionary:settings.merge(saved.get(missile.file,{}),true)
 var overlay:=SubViewportContainer.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.stretch=true;overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.z_index=185;app.arena.add_child(overlay)
 var mat:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type canvas_item; render_mode blend_premul_alpha;";mat.shader=shader;overlay.material=mat
 viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.transparent_bg=true;viewport.own_world_3d=true;overlay.add_child(viewport)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9;camera.position=Vector3(0,0,20);camera.current=true;viewport.add_child(camera)
 for key in entries:
  pool[key]=[]
  var spec=JSON.parse_string(FileAccess.get_file_as_string(LIB+entries[key].file))
  for i in 12:
   var effect=FX.new();viewport.add_child(effect);effect.setup(spec,camera,LIB);effect.hide();effect.stopped=true;pool[key].append(effect)
func point(p:Vector3)->Vector3:
 var px:Vector2=app.defense_screen(p);var extent:Vector2=app.arena.size
 return Vector3((px.x-extent.x*.5)*9/extent.y,(extent.y*.5-px.y)*9/extent.y,0)
func emit_fx(key:String,p:Vector3):
 for fx in pool[key]:
  if fx.visible:continue
  fx.age=0;fx.stopped=false;fx.show();fx.position=point(p);fx.last_position=fx.position;fx.scale=Vector3.ONE*.45
  fx.set_meta("defense_kind",key)
  for layer in fx.layers:layer.particles.clear();layer.carry=0;layer.burst=0;layer.cycle=-1
  particles.append(fx);return fx
 return null
func launch(event:Dictionary):
 var fx=emit_fx("missile",event.from)
 emit_fx("muzzle",event.from)
 flights.append({"fx":fx,"from":event.from,"to":event.to,"age":0.0,"duration":event.duration})
func clear():
 flights.clear();bursts.clear();particles.clear()
 for bucket in pool.values():
  for fx in bucket:fx.hide();fx.stopped=true
func light(p:Vector3,energy:float,radius:float,color:Color)->Dictionary:
 var w:Vector2=app.defense_world(p)
 return {"position":Vector3(w.x,p.y*20,w.y),"energy":energy,"radius":radius,"color":color}
func advance(dt:float):
 var lights:Array=[]
 for shot in flights:
  shot.age+=dt
  var t=clampf(shot.age/maxf(.01,shot.duration),0,1);var p:Vector3=shot.from.lerp(shot.to,t)
  if is_instance_valid(shot.fx):shot.fx.position=point(p)
  if settings.missile_light_enabled:lights.append(light(p,settings.missile_light_energy,settings.missile_light_radius,Color(settings.missile_light_color)))
  if t>=1:
   if is_instance_valid(shot.fx):shot.fx.stopped=true
   emit_fx("impact",shot.to);bursts.append({"pos":shot.to,"age":0.0})
 flights=flights.filter(func(s):return s.age<s.duration)
 for burst in bursts:
  burst.age+=dt
  if settings.missile_burst_enabled:
   var peak=minf(settings.missile_burst_rise,settings.missile_burst_duration*.8)
   var rise=smoothstep(0,peak,burst.age);var fade=1-smoothstep(peak,settings.missile_burst_duration,burst.age)
   lights.push_front(light(burst.pos,lerpf(settings.missile_light_energy,settings.missile_burst_energy,rise)*fade,lerpf(settings.missile_light_radius,settings.missile_burst_radius,rise),Color(settings.missile_light_color).lerp(Color(settings.missile_burst_color),rise)))
 bursts=bursts.filter(func(b):return b.age<settings.missile_burst_duration)
 for fx in particles:
  if fx.get_meta("defense_kind","")!="missile" and fx.age>.35:fx.stopped=true
  fx.advance(dt)
  if fx.finished():fx.hide();fx.stopped=true
 particles=particles.filter(func(fx):return fx.visible)
 # The existing scene shader has four light slots; prioritize impacts and cap total energy.
 lights=lights.slice(0,4)
 for entry in lights:entry.energy/=sqrt(maxi(1,lights.size()))
 app.arena.scenery.renderer.combat_lights.assign(lights)
