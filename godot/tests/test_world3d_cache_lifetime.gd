extends SceneTree
const THEMES=preload("res://scripts/world3d/themes.gd")
func _initialize():call_deferred("run")
func counts()->Array:return [ForestEcology.textures.size(),SpaceAssets.textures.size(),SpaceAssets.shared_silhouettes.size(),StyleLibrary.cache.size()]
func run():
 ForestRoute.reset_frame();ForestRoute.configure(false)
 var warm:Array=[]
 for cycle in 3:
  for theme in THEMES.KEYS:
   var world:SegmentWorld=SegmentWorld.new(ForestArt.new(),THEMES.plan(theme))
   var reference:WeakRef=weakref(world)
   assert(not world.sprites.is_empty())
   world=null
   assert(reference.get_ref()==null,"World retained after scene owner release")
  await process_frame
  if cycle==0:warm=counts()
  else:assert(counts()==warm,"Repeated theme creation adds duplicate cached assets")
  print("WORLD3D_CACHE_CYCLE ",cycle," counts=",counts())
 print("WORLD3D_CACHE_LIFETIME_PASS 21 world creations released; shared cache count plateaus after warmup")
 quit()
