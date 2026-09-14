extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 var service=app.actor_atmosphere;service.set_enabled(true)
 service.sync(app.bridge,true)
 var initial:int=service.parameter_writes
 assert(initial>0)
 service.sync(app.bridge,true)
 assert(service.parameter_writes==0,"Unchanged scene must not resubmit uniforms")
 var leader=app.team[0]
 leader.dead=true;leader.portrait_presenter.advance_anchor(.2,true)
 service.sync(app.bridge,true)
 for entry in service.entries:
  if entry.actor==leader:assert(is_equal_approx(entry.material.get_shader_parameter("portrait_vertical_offset"),leader.portrait_presenter.vertical_offset))
 service.sync(app.bridge,true);assert(service.parameter_writes==0)
 leader.dead=false;leader.portrait_presenter.advance_anchor(.4,true)
 service.sync(app.bridge,true)
 var actor=app.team[0];actor.hide();actor.position+=Vector3(.2,0,-.3)
 app.bridge.combat_lights.clear();app.bridge.combat_lights.append({"position":Vector3(12,13,14),"radius":20.0,"color":Color.RED,"energy":.5})
 service.sync(app.bridge,false)
 # A hidden pooled actor must catch up across multiple shared revisions.
 app.bridge.elapsed+=.1;service.sync(app.bridge,false)
 app.bridge.elapsed+=.1;service.sync(app.bridge,false)
 actor.show();service.sync(app.bridge,false)
 for entry in service.entries:
  if not entry.actor.visible:continue
  assert(entry.material.get_shader_parameter("portrait_weight")==0.0)
  if entry.actor==actor:
   assert(entry.material.get_shader_parameter("actor_anchor")==actor.global_position)
   assert(entry.material.get_shader_parameter("combat_light_positions")[0]==Vector4(12,13,14,20))
   assert(entry.material.get_shader_parameter("atmosphere_time")==app.bridge.elapsed)
 app.bridge.combat_lights.clear();app.bridge.elapsed+=.016
 service.sync(app.bridge,false)
 var animated:int=service.parameter_writes
 for entry in service.entries:
  if not entry.actor.visible:continue
  assert(entry.material.get_shader_parameter("combat_light_colors")[0].a==0,"Expired flash must clear on every material")
  assert(entry.material.get_shader_parameter("atmosphere_time")==app.bridge.elapsed)
 service.set_enabled(false);app.bridge.elapsed+=1;service.sync(app.bridge,true)
 assert(service.parameter_writes==0)
 service.set_enabled(true);service.sync(app.bridge,true)
 for entry in service.entries:
  if entry.actor.visible:assert(entry.material.get_shader_parameter("atmosphere_time")==app.bridge.elapsed)
 var pooled=app.enemy_pool[0].actor;pooled.position=Vector3(2,0,-5);pooled.show()
 service.sync(app.bridge,true)
 for entry in service.entries:
  if entry.actor==pooled:
   assert(entry.material.get_shader_parameter("actor_anchor")==pooled.global_position)
   assert(entry.material.get_shader_parameter("atmosphere_time")==app.bridge.elapsed)
 var entry_count:int=service.entries.size()
 var weapon_count:int=service.entries.filter(func(e):return e.weapon).size()
 assert(weapon_count>0)
 for cycle in 3:
  actor.portrait_presenter.set_enabled(cycle%2==0)
  actor.refresh_equipment();service.sync(app.bridge,cycle%2==0)
  for weapon in actor.portrait_presenter.weapons:
   assert(weapon.original!=weapon.mesh.mesh.surface_get_material(weapon.index),"Atmosphere must not mutate shared asset materials")
  assert(service.entries.size()==entry_count,"Repeated equipment refresh must not accumulate post passes")
  for entry in service.entries:
   if entry.weapon:
    for tail in entry.tails:assert(tail.next_pass==entry.material)
    assert(entry.material.get_shader_parameter("actor_anchor")==entry.actor.global_position)
 service.set_enabled(false)
 for entry in service.entries:
  for tail in entry.tails:assert(tail.next_pass==null)
 service.set_enabled(true)
 for slot in app.enemy_pool:slot.actor.show()
 service.sync(app.bridge,true);service.sync(app.bridge,true)
 var visible_groups:int=service.groups.values().filter(func(g):return g.actor.visible).size()
 var old_comparisons:int=visible_groups*(service.shared_parameters.size()+8)
 assert(service.parameter_comparisons==service.shared_parameters.size()+visible_groups*8)
 assert(service.parameter_comparisons<old_comparisons/2,"Common uniforms should be compared once for the whole scene")
 assert(service.parameter_writes==0)
 print("ATMOSPHERE_COMPARE_REDUCTION previous=",old_comparisons," current=",service.parameter_comparisons," visible groups=",visible_groups)
 print("WORLD3D_ATMOSPHERE_UPDATES_PASS initial=",initial," unchanged=0 animated_and_flash_clear=",animated," hidden return, expired flash, toggles")
 quit()
