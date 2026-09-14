extends RefCounted
# Bounds include every billboard yaw, flipped art and off-centre root-cover anchors.
static func enclosing(position:Vector3,size:Vector2,anchor:Vector2)->AABB:
 var radius:=maxf(absf(anchor.x),absf(1-anchor.x))*size.x
 return AABB(position+Vector3(-radius,(anchor.y-1)*size.y,-radius),Vector3(radius*2,size.y,radius*2)).grow(.001)

static func visible(box:AABB,origin:Vector2,heading:float,half_width_over_focal:float)->bool:
 var center:=box.get_center();var half:=box.size*.5
 var relative:=ForestRoute.to_camera(Vector2(center.x,-center.z)*20,origin,heading)
 var c:=absf(cos(heading));var s:=absf(sin(heading))
 var x_extent:float=(c*half.x+s*half.z)*20
 var depth_extent:float=(s*half.x+c*half.z)*20
 var farthest:=relative.y+depth_extent
 if farthest<1 or relative.y-depth_extent>1700:return false
 return absf(relative.x)-x_extent<=farthest*half_width_over_focal
