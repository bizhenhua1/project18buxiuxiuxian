extends RefCounted
const CAPACITY=7200
var rows:Array=[]
var cursor:=0
var started:=Time.get_ticks_msec()
func sample(app) -> void:
 if not app.arena or not app.arena.scenery:return
 var r=app.arena.scenery.renderer
 var gpu=Vector2.ZERO
 var gpu_horizon=0.0
 if r.forest_batch:
  gpu=r.forest_batch.material.get_shader_parameter("camera_world")
  gpu_horizon=float(r.forest_batch.material.get_shader_parameter("horizon"))
 var actors:Array=[]
 for actor in r.battle_actors:
  if actor.get("live_character",false):actors=[actor.position.x,actor.position.y,actor.h,actor.altitude]
 var row=[(Time.get_ticks_msec()-started)*.001,app.phase,app.speed,app.distance,app.camera.x,app.camera.y,app.heading,r.horizon_y(),r.camera_height(),r.focal(),gpu.x,gpu.y,gpu_horizon,actors]
 if rows.size()<CAPACITY:rows.append(row)
 else:rows[cursor]=row;cursor=(cursor+1)%CAPACITY
func save(app) -> String:
 var ordered=rows.slice(cursor)+rows.slice(0,cursor)
 var path=ProjectSettings.globalize_path("res://../tempassets/work/camera-user-trace.json")
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:return ""
 file.store_string(JSON.stringify({"scene":app.scene_file_path,"settings":ForestSettings.values,"columns":["seconds","phase","speed","distance","camera_x","camera_z","heading","horizon","eye","focal","gpu_camera_x","gpu_camera_z","gpu_horizon","hero_x_z_height_altitude"],"samples":ordered}))
 return path
