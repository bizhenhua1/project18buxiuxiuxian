extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1600,1000)
 var app=load("res://scenes/character_transformation_editor.tscn").instantiate();root.add_child(app)
 app.model.hide()
 var source=load("res://assets/characters3d/transformation-skeleton.glb").instantiate();app.stage.add_child(source)
 var rig=app.FIT.rig_of(source);source.scale=Vector3.ONE*1.6/rig.get_bone_global_rest(rig.find_bone("頭")).origin.y
 var nodes:Array=[];app.FIT.meshes(source,nodes)
 for mesh in nodes:app.assign(mesh,true)
 app.mode=1;app.progress=1;app.update_effect()
 await create_timer(.3).timeout
 await RenderingServer.frame_post_draw
 app.viewport.get_texture().get_image().save_png("F:/GitHub/project18buxiuxiuxian/tempassets/work/skeleton-source.png")
 quit()

