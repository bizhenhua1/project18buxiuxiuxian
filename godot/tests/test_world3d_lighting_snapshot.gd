extends SceneTree
const THEMES=preload("res://scripts/world3d/themes.gd")
const REFERENCE=preload("res://tests/fixtures/world3d_lighting_reference.gd")
func _initialize():call_deferred("run")
func run():
 ForestRoute.reset_frame();ForestRoute.configure(false)
 var compared:=0
 for theme in THEMES.KEYS:
  var world:=SegmentWorld.new(ForestArt.new(),THEMES.plan(theme),true)
  world.biome_lights=[Vector4(12,35,190,65),Vector4(-25,44,400,80)]
  var reference=REFERENCE.new();var current:=SegmentRenderer.new()
  for renderer in [reference,current]:
   renderer.world=world;renderer.camera_world=Vector2(3,20);renderer.environment=world.environment()
   renderer.combat_lights.assign([{"position":Vector3(3,21,90),"radius":30.0,"color":Color(.1,.7,1),"energy":.8}])
  for time in [0.0,.1,.3,1.0]:
   for renderer in [reference,current]:renderer.elapsed=time;renderer.battle_frame_shift=minf(.19,time)
   var material:=ShaderMaterial.new();material.shader=load("res://scripts/world3d/cutout.gdshader")
   reference.bind_combat_lights(material);reference.bind_biome(material)
   var snapshot:=current.combat_light_parameters();snapshot.merge(current.biome_parameters())
   for key in snapshot:
    assert(material.get_shader_parameter(key)==snapshot[key],"Changed original lighting parameter: "+theme+"/"+key)
    compared+=1
  reference.free();current.free()
 print("WORLD3D_LIGHTING_SNAPSHOT_PASS original parameter values=",compared)
 quit()
