extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var presentation:bool="--presentation" in OS.get_cmdline_user_args()
 var fixed:bool="--fixed-step" in OS.get_cmdline_user_args()
 var stress:bool="--skill-stress" in OS.get_cmdline_user_args()
 var presentation_root=load("res://scenes/world3d_presentation.tscn" if presentation else "res://scenes/world3d_stage.tscn").instantiate();root.add_child(presentation_root)
 var app=presentation_root.stage if presentation else presentation_root
 while not app.ready_stage:await process_frame
 if "--no-projectile-lights" in OS.get_cmdline_user_args():
  app.projectile_view.lighting.settings.missile_light_enabled=false
  app.projectile_view.lighting.settings.missile_burst_enabled=false
  app.projectile_view.lighting.clear()
 var render_timing:bool="--render-timing" in OS.get_cmdline_user_args()
 var measured_viewport:RID=app.get_viewport().get_viewport_rid()
 if render_timing:RenderingServer.viewport_set_measure_render_time(measured_viewport,true)
 if "--profile-no-scenery" in OS.get_cmdline_user_args():app.scenery.hide()
 if "--portrait-projection" in OS.get_cmdline_user_args():app.portrait_mode=true
 if "--actor-atmosphere" in OS.get_cmdline_user_args():app.atmosphere_mode=true
 if "--no-outline-lod" in OS.get_cmdline_user_args():app.outline_lod_enabled=false
 if "--all-bones" in OS.get_cmdline_user_args():
  for entry in app.enemy_pool:
   entry.actor.retarget.evaluation_bones=PackedInt32Array(range(entry.actor.rig.get_bone_count()))
 if fixed:app.set_process(false);seed(714603)
 app.start_battle()
 if fixed:
  for i in 120:
   app._process(1.0/60);await process_frame
 else:await create_timer(2).timeout
 if "--no-pose-upload" in OS.get_cmdline_user_args():
  for entry in app.enemy_pool:entry.actor.retarget.submit_pose=false
 app.profiling=true;app.profile_usec.clear()
 if "--particle-breakdown" in OS.get_cmdline_user_args():
  for pool in app.projectile_view.pools.values():
   for fx in pool:fx.profile_particles=true;fx.spawn_usec=0;fx.update_usec=0
 if stress:
  for i in 32:
   app.sim.areas.add_zone(app.world_point(Vector3((i%8-3.5)*2,0,-4-int(i/8)*5)),1.8,1.0,.01,30,.2)
 var times:Array=[];var calls:Array=[];var active:Array=[]
 var frame_details:Array=[]
 var render_cpu:Array=[];var render_gpu:Array=[]
 var trace_frames:bool="--frame-details" in OS.get_cmdline_user_args()
 var skill_load_usec:=0;var peak_shots:=0;var peak_zones:=0;var spawned_shots:=0
 var start:=Time.get_ticks_usec();var last:=start
 while times.size()<480 if fixed else Time.get_ticks_usec()-start<8000000:
  var cpu_before:Dictionary=app.profile_usec.duplicate() if trace_frames else {}
  if stress:
   var skill_started:=Time.get_ticks_usec()
   if times.size()%15==0:spawned_shots+=apply_skill_load(app)
   skill_load_usec+=Time.get_ticks_usec()-skill_started
  if fixed:app._process(1.0/60)
  await process_frame
  var now:=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
  calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));active.append(app.pool_ids.size())
  if render_timing:
   render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(measured_viewport))
   render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(measured_viewport))
  if trace_frames:
   var cpu_delta:Dictionary={}
   for key in app.profile_usec:cpu_delta[key]=(float(app.profile_usec[key])-float(cpu_before.get(key,0)))/1000.0
   frame_details.append({"frame":times.size()-1,"wall_ms":times.back(),"cpu_ms":cpu_delta,"models":app.pool_ids.size(),"projectiles":app.sim.projectiles.active.size(),"draws":calls.back()})
  peak_shots=maxi(peak_shots,app.sim.projectiles.active.size());peak_zones=maxi(peak_zones,app.sim.areas.zones.size())
 times.sort();calls.sort();active.sort()
 var result={"frames":times.size(),"mean_ms":(last-start)/1000.0/times.size(),"p50_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"draw_calls_median":calls[calls.size()/2],"model_bindings_median":active[active.size()/2],"visible_chunks":app.scenery.visible_chunks,"total_chunks":app.scenery.chunks.size(),"storm_particles":true,"full_vfx":false,"cpu_ms_per_frame":{},"visual_pool_misses":app.projectile_view.dropped_visuals}
 result.p99_ms=times[mini(times.size()-1,int(times.size()*.99))]
 result.over_60fps_budget_percent=100.0*times.filter(func(ms):return ms>1000.0/60.0).size()/times.size()
 result.environment={"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"viewport":str(root.size),"theme":app.theme_key,"layout_seed":app.world.seed_value,"initial_exits":app.world.plan.exits,"arguments":Array(OS.get_cmdline_user_args())}
 result.sample_60fps_gate={"p95_within_budget":float(result.p95_ms)<=1000.0/60.0,"no_visual_pool_misses":app.projectile_view.dropped_visuals==0,"scope":"This measured sample only; not long-session, loading, all-skills or whole-game acceptance."}
 if trace_frames:
  frame_details.sort_custom(func(a,b):return a.wall_ms>b.wall_ms)
  result.slowest_frames=frame_details.slice(0,20)
 if render_timing:
  render_cpu.sort();render_gpu.sort()
  result.viewport_render_timing={"cpu_p50_ms":render_cpu[render_cpu.size()/2],"cpu_p95_ms":render_cpu[int(render_cpu.size()*.95)],"gpu_p50_ms":render_gpu[render_gpu.size()/2],"gpu_p95_ms":render_gpu[int(render_gpu.size()*.95)],"gpu_samples_nonzero":render_gpu.filter(func(ms):return ms>0).size(),"scope":"Engine viewport timing; delayed readback, not paired with the same script frame. Zero values may be unavailable."}
 if fixed:
  var final_units:Array=[]
  for e in app.sim.enemies:final_units.append([e.id,e.type,e.pos.x,e.pos.y,e.pos.z,e.hp,e.state])
  result["fixed_step"]=1.0/60;result["simulation_clock"]=app.sim.clock
  result["final_state_fingerprint"]=JSON.stringify(final_units).sha256_text()
 for key in app.profile_usec:result.cpu_ms_per_frame[key]=app.profile_usec[key]/1000.0/times.size()
 # Read texture data after timing, so diagnostics don't stall measured frames.
 var texture_memory:={"source_bytes":0,"additional_sampled_bytes":0,"source_count":app.scenery.by_texture.size(),"copied_count":0,"prepare_ms":app.scenery.texture_prepare_usec/1000.0}
 for source in app.scenery.by_texture:
  texture_memory.source_bytes+=source.get_image().get_data_size()
  var sampled:Texture2D=app.scenery.by_texture[source].get_shader_parameter("art")
  if sampled!=source:
   texture_memory.copied_count+=1;texture_memory.additional_sampled_bytes+=sampled.get_image().get_data_size()
 result["cutout_texture_storage"]=texture_memory
 result["shared_volley_muzzles"]=app.projectile_view.shared_muzzles
 result["shared_simultaneous_impacts"]=app.projectile_view.shared_impacts
 result["effect_demand"]={"requested":app.projectile_view.requested_by_kind,"dropped":app.projectile_view.dropped_by_kind,"active_peak":app.projectile_view.peak_by_kind,"particles_peak":app.projectile_view.particle_peak_by_kind}
 result["gpu_particle_curves"]=app.projectile_view.gpu_curves_enabled
 result["effect_capacities"]=app.projectile_view.capacities
 var motion_coverage:Dictionary={}
 for kind in app.projectile_view.pools:
  var layers:Array=app.projectile_view.pools[kind][0].layers
  motion_coverage[kind]={"analytic":layers.filter(func(layer):return layer.gpu_motion).size(),"hybrid":layers.filter(func(layer):return layer.gpu_current).size(),"total":layers.size()}
 result["gpu_motion_layers"]=motion_coverage
 result["gpu_particle_motion"]=app.projectile_view.gpu_motion_enabled
 if "--particle-breakdown" in OS.get_cmdline_user_args():
  var spawning:=0;var updating:=0
  for pool in app.projectile_view.pools.values():
   for fx in pool:spawning+=fx.spawn_usec;updating+=fx.update_usec
  result["particle_breakdown_ms"]={"spawn":spawning/1000.0/times.size(),"update":updating/1000.0/times.size()}
  var layer_costs:Array=[]
  for kind in app.projectile_view.pools:
   var totals:Dictionary={}
   for fx in app.projectile_view.pools[kind]:
    for layer in fx.layers:
     if not totals.has(layer.index):totals[layer.index]={"kind":kind,"layer":layer.index,"spawn_usec":0,"update_usec":0,"particle_steps":0,"initial_uploads":0,"reorder_uploads":0,"additive":bool(layer.data.material.additive),"analytic":layer.gpu_motion,"hybrid":layer.gpu_current}
     totals[layer.index].spawn_usec+=layer.profile_spawn_usec;totals[layer.index].update_usec+=layer.profile_update_usec;totals[layer.index].particle_steps+=layer.profile_particle_steps
     totals[layer.index].initial_uploads+=layer.profile_initial_uploads;totals[layer.index].reorder_uploads+=layer.profile_reorder_uploads
   for entry in totals.values():
    entry["update_ms_per_frame"]=entry.update_usec/1000.0/times.size();entry["spawn_ms_per_frame"]=entry.spawn_usec/1000.0/times.size();layer_costs.append(entry)
  layer_costs.sort_custom(func(a,b):return a.update_usec>b.update_usec)
  result["particle_layer_costs"]=layer_costs
 if app.projectile_view.render_batch!=null:result["batch_particles_dropped"]=app.projectile_view.render_batch.dropped
 result["scenery_drawn"]=app.scenery.visible
 if stress:result["skill_stress"]={"zones_peak":peak_zones,"projectiles_peak":peak_shots,"extra_projectiles_spawned":spawned_shots,"area_hits":app.sim.areas.hits,"extra_skill_cpu_ms":skill_load_usec/1000.0/times.size(),"damage_per_hit":.01,"visuals_may_be_pool_limited":true}
 result.skip_empty_particle_layers=app.projectile_view.pools.missile[0].skip_empty_layers
 result.cached_particle_shapes=app.projectile_view.pools.missile[0].cache_shape_frames
 result.visual_budget="ordinary" if app.projectile_view.ordinary_budget else "full-source"
 result.dense_vfx_instances=app.projectile_view.dense_instances
 result.projectile_lights={"flight":app.projectile_view.lighting.settings.missile_light_enabled,"burst":app.projectile_view.lighting.settings.missile_burst_enabled,"shared":app.projectile_view.lighting.shared_flights}
 result.vfx_prewarm_ms=app.projectile_view.prewarm_usec/1000.0
 var suppressed:=0
 for pool in app.projectile_view.pools.values():
  for fx in pool:suppressed+=fx.budget_skipped_spawns
 result.budget_skipped_particle_spawns=suppressed
 result.contact_mesh_lod=app.scenery.contact_lod_enabled
 print("WORLD3D_BENCH ",JSON.stringify(result))
 var suffix="profile-optimized" if "--optimized" in OS.get_cmdline_user_args() else "profile"
 if "--lighting-snapshot" in OS.get_cmdline_user_args():suffix="lighting-snapshot"
 if "--bone-pruning" in OS.get_cmdline_user_args():suffix="bone-pruning"
 if "--all-bones" in OS.get_cmdline_user_args():suffix="all-bones"
 if "--portrait-projection" in OS.get_cmdline_user_args():suffix="portrait-projection"
 if "--actor-atmosphere" in OS.get_cmdline_user_args():suffix+="-atmosphere"
 if "--no-outline-lod" in OS.get_cmdline_user_args():suffix+="-full-outline"
 if "--no-pose-upload" in OS.get_cmdline_user_args():suffix+="-no-pose-upload"
 if presentation:suffix+="-presentation"
 if "--compact-skins" in OS.get_cmdline_user_args():suffix+="-compact-skins"
 if fixed:suffix+="-fixed-step"
 if stress:suffix+="-skill-stress"
 suffix+="-gpu-curves" if app.projectile_view.gpu_curves_enabled else "-cpu-curves"
 if "--full-vfx-capacity" in OS.get_cmdline_user_args():suffix+="-full-capacity"
 if "--profile-no-scenery" in OS.get_cmdline_user_args():suffix+="-no-scenery"
 if "--batch-particles" in OS.get_cmdline_user_args():suffix+="-batched"
 if app.projectile_view.gpu_motion_enabled:suffix+="-gpu-motion"
 if app.projectile_view.gpu_motion_enabled:suffix+="-cohorts" if app.projectile_view.pools["missile"][0].particle_cohorts else "-no-cohorts"
 if "--particle-breakdown" in OS.get_cmdline_user_args():suffix+="-breakdown"
 if "--contact-bases" in OS.get_cmdline_user_args():suffix+="-contact-bases"
 if "--shared-atmosphere-clock" in OS.get_cmdline_user_args():suffix+="-shared-clock"
 if app.team[0].merge_surfaces_enabled:suffix+="-merged-surfaces"
 if "--bulk-particle-upload" in OS.get_cmdline_user_args():suffix+="-bulk-upload"
 if app.projectile_view.pools["missile"][0].cache_motion_uniforms:suffix+="-cached-motion-uniforms"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--theme="):suffix+="-theme-"+argument.get_slice("=",1)
 if app.scenery.bounded_ground:suffix+="-bounded-ground"
 if result.contact_mesh_lod:suffix+="-contact-lod"
 if not result.skip_empty_particle_layers:suffix+="-empty-updates"
 if not result.cached_particle_shapes:suffix+="-uncached-shapes"
 if app.projectile_view.ordinary_budget:suffix+="-ordinary-budget"
 if trace_frames:suffix+="-frame-details"
 if render_timing:suffix+="-render-timing"
 if "--prewarm-vfx" in OS.get_cmdline_user_args():suffix+="-prewarm-vfx"
 if "--no-projectile-lights" in OS.get_cmdline_user_args():suffix+="-no-projectile-lights"
 var f:=FileAccess.open("res://../tempassets/work/world3d-benchmark-"+suffix+".json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "))
 if "--capture-budget" in OS.get_cmdline_user_args():
  RenderingServer.force_draw()
  var light_suffix:="-no-projectile-lights" if "--no-projectile-lights" in OS.get_cmdline_user_args() else ""
  root.get_texture().get_image().save_png("res://../tempassets/work/forest-budget-"+str(result.visual_budget)+light_suffix+".png")
 if "--capture-effect-kinds" in OS.get_cmdline_user_args():
  app.set_process(false)
  var visible_effects:Dictionary={}
  for kind in app.projectile_view.pools:
   visible_effects[kind]=[]
   for fx in app.projectile_view.pools[kind]:
    if fx.visible:visible_effects[kind].append(fx)
  for selected in ["missile","impact","muzzle","none"]:
   for kind in visible_effects:
    for fx in visible_effects[kind]:fx.visible=kind==selected
   RenderingServer.force_draw()
   root.get_texture().get_image().save_png("res://../tempassets/work/forest-vfx-isolate-"+selected+".png")
  for kind in visible_effects:
   for fx in visible_effects[kind]:fx.show()
 quit()

func apply_skill_load(app)->int:
 # Immediate skills need the current positions even between periodic zone ticks.
 app.sim.areas.sync(app.sim.enemies,app.sim.skill_world,app.sim.clock)
 var center:Vector3=app.world_point(Vector3(0,0,-4))
 var ids:Array=app.sim.areas.index.nearest(center,20,12)
 var source:Dictionary=app.sim.allies[0]
 var origin:Vector3=app.sim.attack_origin(source,false)
 for id in ids:
  var target:Dictionary=app.sim.areas.targets[id]
  app.sim.projectiles.launch(origin,target.pos+Vector3.UP-origin,14,.01,false,3,source.id)
 app.sim.areas.burst(center,4,1,.01,Callable(app.sim,"hurt"))
 app.sim.areas.corridor(app.world_point(Vector3(-2,0,4)),app.world_point(Vector3(2,0,-24)),1,1,.01,Callable(app.sim,"hurt"))
 return ids.size()

