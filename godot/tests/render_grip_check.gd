extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/character_library.tscn").instantiate();root.add_child(app)
 app.select_model(5);app.weapon_panel.weapon=5;app.weapon_panel.shield_enabled=true;app.weapon_panel.bind_model()
 var idle=app.clips.filter(func(c):return str(c.get("pack",""))=="7" and "Idle" in c.name)
 if not idle.is_empty():app.select_clip(idle[0])
 app.yaw=-.8
 for i in 15:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/grip-check.png")
 print("GRIP_RENDER_PASS");quit()
