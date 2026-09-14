extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 var service=app.prop_atmosphere
 assert(service.entries.size()==app.props.size() and not app.props.is_empty())
 service.sync(app.bridge,true);service.sync(app.bridge,true)
 assert(service.writes==0,"Unchanged props must not resubmit parameters")
 var positions:Array=[]
 for item in app.props:positions.append(item.node.position)
 app.bridge.combat_lights.assign([{"position":Vector3(2,3,4),"radius":12.0,"color":Color.BLUE,"energy":.4}])
 app.props[0].node.modulate.a=.3;service.sync(app.bridge,true)
 for i in service.entries.size():
  var entry=service.entries[i]
  assert(entry.node.material_override==entry.material)
  assert(entry.node.position==positions[i])
  assert(is_equal_approx(entry.material.get_shader_parameter("opacity"),entry.node.modulate.a))
  assert(entry.material.get_shader_parameter("combat_light_positions")[0]==Vector4(2,3,4,12))
 app.bridge.combat_lights.clear();service.sync(app.bridge,true)
 for entry in service.entries:assert(entry.material.get_shader_parameter("combat_light_colors")[0].a==0)
 service.sync(app.bridge,false)
 for entry in service.entries:assert(entry.node.material_override==null)
 app.props[0].node.modulate.a=1;service.sync(app.bridge,true)
 assert(service.entries[0].material.get_shader_parameter("opacity")==1.0)
 service.sync(app.bridge,true);assert(service.writes==0)
 print("WORLD3D_PROP_ATMOSPHERE_PASS stationary fade, flash expiry, toggle restoration, unchanged uniforms")
 quit()
