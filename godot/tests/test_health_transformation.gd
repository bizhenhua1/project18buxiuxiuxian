extends SceneTree
func _initialize():call_deferred("run")
func run():
 var Effect=load("res://scripts/battle/health_transformation.gd")
 var existed:=FileAccess.file_exists(Effect.SAVE)
 var backup:=FileAccess.get_file_as_bytes(Effect.SAVE) if existed else PackedByteArray()
 var actor=load("res://scripts/battle/enemy_actor.gd").new();root.add_child(actor);actor.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var unit={"uid":881,"hp":100.0,"maxHp":100.0};actor.bind_unit(unit)
 var effect=actor.health_effect;effect.set_process(false)
 for mode in [0,1]:
  assert(Effect.save_game({"display":"transform","mode":mode,"opacity":.4,"energy":1.5,"color":"70ecdfff","material_style":2})==OK)
  for hp in [100.0,25.0,75.0,0.0,100.0]:
   unit.hp=hp
   for i in range(60):effect._process(.016)
   assert(is_equal_approx(effect.progress,1.0-hp/100.0))
   assert(unit.health_transformation_active)
   for entry in effect.ink.surfaces:assert(entry.material.get_shader_parameter("material_style")==2)
   if mode==1:
    for mat in effect.skeleton_materials:assert(mat.get_shader_parameter("material_style")==2)
   await create_timer(.05).timeout
   await RenderingServer.frame_post_draw
   if mode==1 and hp==25:actor.viewport.get_texture().get_image().save_png("F:/GitHub/project18buxiuxiuxian/tempassets/work/runtime-health-skeleton.png")
 var scales={"gentleman.glb":1.35,"isabella.glb":.8}
 Effect.save_game({"head_scales":scales})
 effect._process(.016)
 assert(is_equal_approx(effect.skull_scale,1.35))
 assert(is_equal_approx(float(Effect.settings().head_scales["isabella.glb"]),.8))
 assert(Effect.save_game({"display":"ui","mode":1,"opacity":.4,"energy":1.5,"color":"70ecdfff"})==OK)
 effect._process(.016)
 assert(not unit.health_transformation_active and not effect.active)
 for mesh in effect.skeletons:assert(not mesh.visible)
 for entry in effect.ink.surfaces:assert(entry.material.shader==effect.INK.SURFACE)
 var unused=load("res://scripts/battle/enemy_actor.gd").new();root.add_child(unused)
 unused.health_effect._process(.016);assert(unused.health_effect.unit.is_empty())
 if existed:
  var file:=FileAccess.open(Effect.SAVE,FileAccess.WRITE);file.store_buffer(backup);file.close()
 else:DirAccess.remove_absolute(Effect.SAVE)
 Effect.next_poll=0
 print("HEALTH_TRANSFORMATION_PASS both schemes, damage/heal/death/revive, UI restore, unbound preview")
 quit()
