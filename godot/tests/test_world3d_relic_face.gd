extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 var app=shell.stage
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 var found:=false
 for i in app.props.size():
  var item:Dictionary=app.props[i]
  if not item.two_faces:continue
  found=true
  var anchor:Vector3=item.node.position
  var height:float=item.node.texture.get_height()*item.node.pixel_size
  var opacity:float=item.node.modulate.a
  for reverse in [false,true]:
   app.action_buttons["道具 · 正反"].pressed.emit()
   assert(app.relic_reverse==reverse)
   assert(app.prop_atmosphere.entries[i].source.resource_path.ends_with("watch-reverse.png" if reverse else "watch-front.png"))
   assert(item.node.position==anchor and item.node.modulate.a==opacity)
   assert(is_equal_approx(item.node.pixel_size*item.node.texture.get_height(),height))
   var sampled:Texture2D=app.prop_atmosphere.entries[i].material.get_shader_parameter("art")
   assert(sampled==item.node.texture)
   assert(sampled.get_image().has_mipmaps() and sampled.get_size()==item.node.texture.get_size())
 assert(found)
 var cached_count:int=app.prop_atmosphere.texture_cache.size()
 for enabled in [false,true,false,true]:
  app.atmosphere_mode=enabled;app._process(0)
  for i in app.props.size():
   var node:Sprite3D=app.props[i].node
   assert(node.texture.get_image().has_mipmaps())
   assert(node.material_override==app.prop_atmosphere.entries[i].material if enabled else node.material_override==null)
 assert(app.prop_atmosphere.texture_cache.size()==cached_count,"Display switches must reuse prepared textures")
 app.start_travel();app._process(.05)
 var positions:Array=app.props.map(func(item):return item.node.position)
 var opacity:float=app.props[0].node.modulate.a
 app.action_buttons["道具 · 正反"].pressed.emit()
 assert(app.props[0].node.modulate.a==opacity and app.phase=="travel")
 app._process(.05)
 for i in app.props.size():assert(app.props[i].node.position==positions[i])
 print("WORLD3D_RELIC_FACE_PASS UI toggle, texture/material, fixed anchor/height, departure fade")
 quit()
