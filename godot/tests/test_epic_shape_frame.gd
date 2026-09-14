extends SceneTree
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const OLD=preload("res://tests/fixtures/epic181_effect_reference.gd")
func _initialize():
 var old=OLD.new();var current=FX.new();var checked:=0
 for kind in 20:
  for enabled in [false,true]:
   var shape:Dictionary={"enabled":enabled,"type":kind,"radius":[[.4,1.2],[.8,1.5]],"radiusThickness":.65,"angle":37.0,"length":1.7,"donutRadius":.23,"m_Rotation":{"x":23.0,"y":-72.0,"z":16.0},"m_Scale":{"x":.7,"y":1.3,"z":.9},"m_Position":{"x":3.0,"y":-2.0,"z":7.0}}
   var frame=FX.ShapeFrame.new(shape)
   old.rng.seed=12345;current.rng.seed=12345
   for sample in 128:
    assert(old.emit_pose(shape)==current.emit_pose(shape,frame),"Shape frame cache changed emission transform")
    assert(old.rng.state==current.rng.state,"Shape frame cache changed random sequence")
    checked+=1
 old.free();current.free()
 print("EPIC_SHAPE_FRAME_PASS transforms=",checked," all shape cases, rotation/nonuniform scale/offset and exact RNG state")
 quit()
