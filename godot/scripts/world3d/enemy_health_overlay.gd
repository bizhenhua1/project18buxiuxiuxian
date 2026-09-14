extends Node2D
var bars:Array=[]
var heads:Dictionary={}
func sync(stage):
 var next:Array=[]
 if stage.phase=="battle":
  var viewport_size:Vector2=stage.bridge.view_size
  for unit in stage.sim.enemies:
   if unit.hp<=0 or unit.get("resolved",false) or not unit.get("health_revealed",false):continue
   if not stage.pool_ids.has(unit.id):continue
   var actor=stage.pool_ids[unit.id].actor
   append_bar(next,stage,unit,actor,viewport_size,false)
  for i in stage.team.size():
   var unit:Dictionary=stage.sim.allies[stage.team_slots[i]]
   if unit.hp<=0 or unit.hp>=unit.max_hp:continue
   # Use the effective view state, including unsupported-mode fallback.
   if i<stage.health_views.size() and stage.health_views[i].active:continue
   append_bar(next,stage,unit,stage.team[i],viewport_size,true)
  for item in stage.props:
   var unit:Dictionary=stage.sim.allies[item.slot]
   if unit.hp<=0 or unit.hp>=unit.max_hp or not item.node.visible or item.node.modulate.a<=.01:continue
   var point:Vector3=item.node.global_position
   if stage.camera.is_position_behind(point):continue
   var screen:Vector2=stage.camera.unproject_position(point)+Vector2(0,10)
   if not Rect2(Vector2.ZERO,viewport_size).has_point(screen):continue
   next.append({"id":unit.id,"ally":true,"prop":true,"position":screen,"fraction":clampf(float(unit.hp)/maxf(.001,float(unit.max_hp)),0,1),"alpha":item.node.modulate.a})
 if next!=bars:bars=next;queue_redraw()
func append_bar(next:Array,stage,unit:Dictionary,actor,viewport_size:Vector2,ally:bool):
 if not actor.visible or actor.opacity<=.01:return
 if not heads.has(actor):heads[actor]=actor.rig.find_bone("頭")
 var bone:int=heads[actor]
 if bone<0:return
 var point:Vector3=(actor.rig.global_transform*actor.rig.get_bone_global_pose(bone)).origin
 # Party portraits have large headwear; leave space above the head anchor.
 point+=Vector3.UP*(.4 if ally else .18)*actor.scale.y
 if stage.portrait_mode:point=actor.portrait_presenter.presented_attachment(point,stage.camera)
 if stage.camera.is_position_behind(point):return
 var screen:Vector2=stage.camera.unproject_position(point)
 screen.y-=8
 if not Rect2(Vector2.ZERO,viewport_size).has_point(screen):return
 next.append({"id":unit.id,"ally":ally,"position":screen,"fraction":clampf(float(unit.hp)/maxf(.001,float(unit.max_hp)),0,1),"alpha":actor.opacity})
func _draw():
 for bar in bars:
  var left:Vector2=bar.position-Vector2(14,0)
  draw_line(left,bar.position+Vector2(14,0),Color("26332d")*Color(1,1,1,bar.alpha),3)
  draw_line(left,left+Vector2(28*bar.fraction,0),Color("8aaa96" if bar.ally else "b68583")*Color(1,1,1,bar.alpha),3)
