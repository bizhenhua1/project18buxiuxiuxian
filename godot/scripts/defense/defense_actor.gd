extends Node3D
const RETARGET=preload("res://scripts/spaces/preview_retarget.gd")
static var motions:Dictionary={}
static var buffers:Dictionary={}
var rig:Skeleton3D
var body:Node3D
var retarget=RETARGET.new()
var bound:Dictionary={}
var state:=""
var tick:=0.0
var age:=0.0
var offset:=0.0
var last_changed:=-1.0
func setup(scene:PackedScene,index:int):
 if motions.is_empty():
  motions=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_3d_motions.json"))
  for key in motions.clips:buffers[key]=FileAccess.get_file_as_bytes(motions.clips[key].file).to_float32_array()
 body=scene.instantiate();add_child(body);prepare(body)
 retarget.configure(rig,motions.bones)
 var head:=rig.find_bone("頭")
 var height:=rig.get_bone_global_rest(head).origin.y+.2 if head>=0 else 1.8
 body.scale=Vector3.ONE*1.8/maxf(.1,height)
 offset=index*.139;hide()
func prepare(node:Node):
 if node is Skeleton3D:rig=node
 if node is AnimationPlayer:node.active=false
 if node is MeshInstance3D:
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child in node.get_children():prepare(child)
func bind(unit:Dictionary,enemy:bool):
 bound=unit;state="";age=0;tick=0;last_changed=-1
 rotation.y=0 if enemy else PI
 scale=Vector3.ONE*float(unit.get("body_scale",1.6 if unit.boss else 1.0))
 show()
func advance(dt:float,clock:float):
 if bound.is_empty():return
 position=bound.pos
 if bound.state=="leaked" or (bound.state=="death" and clock-bound.changed>3.0):
  hide();bound={};return
 var desired:String=bound.state
 if desired!=state or not is_equal_approx(last_changed,float(bound.changed)):
  last_changed=float(bound.changed)
  state=desired;age=0;tick=1
  retarget.data=buffers[state];retarget.frames=int(motions.clips[state].frames);retarget.fps=float(motions.clips[state].fps)
 age+=dt;tick+=dt
 # Animation LOD only; world movement remains continuous each rendered frame.
 var period:=1.0/(12.0 if position.z< -10 else 24.0)
 if tick>=period:
  tick=fmod(tick,period)
  var duration:float=(retarget.frames-1)/retarget.fps
  retarget.apply(fmod(age+offset,duration) if state in ["walk","idle"] else minf(age,duration))
