extends SceneTree
# Independent production entry. Never import world3d positions or camera data.
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/defense_route.tscn").instantiate();root.add_child(app)
 while not app.defense_ready:await process_frame
 app.reset_defense(false)
 for i in 30:await process_frame
 app.set_process(false)
 await RenderingServer.frame_post_draw
 var renderer=app.arena.scenery.renderer
 var screen_transform:Transform2D=app.arena.get_global_transform_with_canvas()
 var report:Dictionary={"source":"res://scenes/defense_route.tscn","window":[root.size.x,root.size.y],"arena_size":[app.arena.size.x,app.arena.size.y],"arena_origin":[app.arena.global_position.x,app.arena.global_position.y],"camera":[renderer.camera_world.x,renderer.camera_world.y],"heading":renderer.heading,"frame":app.live_template.current.duplicate(true),"cards":[],"actors":[]}
 report["content_rect_pixels"]=[screen_transform.origin.x,screen_transform.origin.y,(screen_transform.x*app.arena.size.x).length(),(screen_transform.y*app.arena.size.y).length()]
 report["renderer_size"]=[renderer.view_size.x,renderer.view_size.y]
 report["route_zone"]=app.route_zone.duplicate(true)
 report["distance"]=app.distance
 report["prop_visual_time"]=app.arena.visual_time
 report["lighting_inputs"]={}
 var lighting:Dictionary=renderer.combat_light_parameters();lighting.merge(renderer.biome_parameters())
 lighting.merge({"lantern_position":renderer.lantern_position(),"lantern_enabled":renderer.lantern_enabled,"atmosphere_time":renderer.elapsed,"region_tint":renderer.world.camera_region.space.ambient})
 for key in lighting:report.lighting_inputs[key]=var_to_str(lighting[key])
 report["forest_settings"]=ForestSettings.values.duplicate(true)
 report["sprites"]=[]
 for sprite in renderer.world.sprites:
  report.sprites.append({"texture":sprite.texture.resource_path,"position":[sprite.position.x,sprite.position.y],"width":sprite.w,"height":sprite.h})
 var space=renderer.world.camera_region.space
 report["space"]={"key":str(space.key),"ground_texture":space.ground_texture.resource_path,"ground_tint":space.ground_tint.to_html(),"ambient":space.ambient.to_html(),"top_color":space.top_color.to_html(),"depth_color":space.atmosphere.depth_color.to_html(),"haze_color":space.atmosphere.haze_color.to_html()}
 for card in app.arena.cards:
  if card.side!="player" or not card.unit.has("uid"):continue
  report.cards.append({"id":card.unit.get("cardId",card.unit.get("id","")),"uid":card.unit.uid,"slot":app.arena.world_slots.get(card.unit.uid,{}).duplicate(true),"rect":[card.position.x,card.position.y,card.size.x,card.size.y]})
 for actor in renderer.battle_actors:
  if not (actor.get("live_companion",false) or actor.get("live_character",false)):continue
  report.actors.append({"id":actor.id,"position":[actor.position.x,actor.position.y],"height":actor.h,"width":actor.w,"altitude":actor.altitude,"ground_anchor":[actor.ground_anchor.x,actor.ground_anchor.y]})
  var portrait=app.arena.equipped_actors.get(actor.id-200000)
  if portrait==null:continue
  var relative:Vector2=ForestRoute.to_camera(actor.position,renderer.camera_world,renderer.heading)
  var perspective:float=renderer.focal()/relative.y
  var ground:float=ForestEcology.height_at(actor.position)-ForestEcology.height_at(renderer.camera_world)
  report.actors.back()["relative_ground"]=ground
  report.actors.back()["depth"]=relative.y
  var foot:=Vector2(renderer.view_size.x*.5+relative.x*perspective,renderer.horizon_y()+(renderer.camera_height()-ground-actor.altitude)*perspective)
  var dimensions:=Vector2(actor.w,actor.h)*perspective
  var origin:Vector2=foot-actor.ground_anchor*dimensions
  var landmarks:Dictionary={}
  for bone_name in ["頭","首","手首.L","手首.R","足首.L","足首.R"]:
   var bone:int=portrait.rig.find_bone(bone_name)
   if bone<0:continue
   var uv:Vector2=portrait.actor_camera.unproject_position(portrait.rig.global_transform*portrait.rig.get_bone_global_pose(bone).origin)/Vector2(portrait.viewport.size)
   var screen:Vector2=screen_transform*(origin+uv*dimensions)
   landmarks[bone_name]=[screen.x,screen.y]
  report.actors.back()["model"]=portrait.model_key
  var pose:Array=[]
  for bone in portrait.rig.get_bone_count():
   var p:Vector3=portrait.rig.get_bone_pose_position(bone);var q:Quaternion=portrait.rig.get_bone_pose_rotation(bone);var s:Vector3=portrait.rig.get_bone_pose_scale(bone)
   pose.append({"name":portrait.rig.get_bone_name(bone),"p":[p.x,p.y,p.z],"q":[q.x,q.y,q.z,q.w],"s":[s.x,s.y,s.z]})
  report.actors.back()["bone_pose"]=pose
  report.actors.back()["body_yaw"]=portrait.body.rotation.y
  report.actors.back()["landmarks_pixels"]=landmarks
  report.actors.back()["portrait_rect_pixels"]=[(screen_transform*origin).x,(screen_transform*origin).y,(screen_transform.x*dimensions.x).length(),(screen_transform.y*dimensions.y).length()]
 root.get_texture().get_image().save_png("res://../tempassets/work/formal-battle-baseline.png")
 FileAccess.open("res://../tempassets/work/formal-battle-baseline.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 assert(not report.cards.is_empty())
 print("FORMAL_BATTLE_BASELINE_READY arena=",app.arena.size," cards=",report.cards.size()," independent formation and camera")
 quit()


