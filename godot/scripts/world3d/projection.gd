extends RefCounted
# Route units are 1/20 metre. Preserve vertical cutouts using an off-axis frustum.
const UNITS:=20.0
static func frame_origin(origin:Vector2,heading:float,frame:Dictionary)->Vector2:
 return origin+Vector2(cos(heading),-sin(heading))*float(frame.get("lateral",0))+Vector2(sin(heading),cos(heading))*float(frame.get("forward",0))
static func frame_heading(heading:float,frame:Dictionary)->float:
 return heading+deg_to_rad(float(frame.get("yaw",0)))
static func blend_frame(current:Dictionary,target:Dictionary,weight:float):
 for key in ["height","lens","horizon","forward","lateral"]:
  current[key]=lerpf(float(current.get(key,0)),float(target.get(key,0)),weight)
 current.yaw=rad_to_deg(lerp_angle(deg_to_rad(float(current.get("yaw",0))),deg_to_rad(float(target.get("yaw",0))),weight))
static func point(p:Vector2,height:float=0.0)->Vector3:
 return Vector3(p.x,height,-p.y)/UNITS
static func configure(camera:Camera3D,viewport_size:Vector2,origin:Vector2,heading:float,eye:float,lens:float,horizon:float):
 var focal:=minf(viewport_size.y*.86,viewport_size.x*.72)*lens
 var near_plane:=.05
 var height:=near_plane*viewport_size.y/focal
 camera.keep_aspect=Camera3D.KEEP_HEIGHT
 camera.set_frustum(height,Vector2(0,(horizon-.5)*height),near_plane,110)
 camera.position=point(origin,eye+ForestEcology.height_at(origin));camera.rotation=Vector3(0,-heading,0)
static func project_reference(p:Vector2,height:float,size:Vector2,origin:Vector2,heading:float,eye:float,lens:float,horizon:float)->Vector2:
 var relative:=ForestRoute.to_camera(p,origin,heading)
 var f:=minf(size.y*.86,size.x*.72)*lens
 return Vector2(size.x*.5+relative.x*f/relative.y,size.y*horizon+(eye+ForestEcology.height_at(origin)-height)*f/relative.y)
