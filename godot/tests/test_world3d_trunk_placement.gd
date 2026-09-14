extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 shell.stage.set_process(false)
 var layout=preload("res://scripts/world3d/trunk_placement.gd").new()
 # Frozen pre-resumable implementation is the independent behavior reference.
 var repeated=preload("res://tests/trunk_placement_reference.gd").new()
 if layout.partial_resolution:repeated=preload("res://scripts/world3d/trunk_placement.gd").new()
 var tested:=0
 var prepared:Array=layout.prepare(shell.stage.world.sprites,shell.stage.route_segment)
 var prepared_again:Array=repeated.prepare(shell.stage.world.sprites,shell.stage.route_segment)
 var original_entries:Dictionary=layout.entries.duplicate(true)
 var index:=0
 for source in shell.stage.world.sprites:
  var original:Vector2=source.position
  var placed:Dictionary=layout.place(prepared[index])
  var again:Dictionary=repeated.place(prepared_again[index]);index+=1
  assert(source.position==original,"Placement mutated legacy source")
  assert(placed.position==again.position,"Placement must be deterministic")
  assert(placed.position.distance_to(original)<=24.001,"Placement exceeded the displacement budget")
  assert(placed.w==source.w and placed.h==source.h and placed.texture==source.texture)
  if placed.position!=original:
   assert(shell.stage.route_segment.lane_distance(placed.position)>=maxf(26,ForestEcology.half_width(source.route_s-shell.stage.route_segment.start_s))+source.trunk_radius+8)
   tested+=1
 assert(tested>0,"Fixture did not exercise relocation")
 var generation_checks:int=layout.checks
 var overlaps_before:=0;var overlaps_after:=0
 var ids:Array=layout.entries.keys()
 for a in ids.size():
  for b in range(a+1,ids.size()):
   var before_hit:bool=layout.overlap(original_entries[ids[a]],original_entries[ids[b]])
   var after_hit:bool=layout.overlap(layout.entries[ids[a]],layout.entries[ids[b]])
   if before_hit:overlaps_before+=1
   if after_hit:overlaps_after+=1
   assert(not after_hit or before_hit,"Relocation introduced a new trunk overlap")
   if layout.partial_resolution and after_hit:
    assert(layout.penetration(layout.entries[ids[a]],layout.entries[ids[b]])<=layout.penetration(original_entries[ids[a]],original_entries[ids[b]])+0.0001,"Placement deepened an existing overlap")
 assert(overlaps_after<overlaps_before)
 var before:int=layout.buckets.size();layout.retire_before(INF)
 assert(layout.buckets.is_empty() and layout.entries.is_empty(),"Retired placement data leaked")
 print("WORLD3D_TRUNK_PLACEMENT_PASS moved=",tested," unresolved=",layout.unresolved," checks=",generation_checks," overlaps=",overlaps_before," -> ",overlaps_after," retired_cells=",before," solve_ms=",layout.solve_total_usec/1000.0," peak_step_ms=",layout.solve_peak_usec/1000.0)
 quit()
