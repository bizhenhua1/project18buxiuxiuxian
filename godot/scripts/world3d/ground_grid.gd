extends RefCounted
## Keep terrain triangles fixed in world space while recycling the visible patch.
## PlaneMesh subdivisions count EXTRA cuts, hence N - 1 for N one-metre cells.
const SIZE=Vector2(160,260)
## Static placement/diagnostics only. Match the actual PlaneMesh diagonal,
## including negative cells; continuous terrain height differs between vertices.
static func support_height(xz:Vector2)->float:
 var cell:=xz.floor();var f:=xz-cell
 if f.x+f.y<=1.0:
  var a:=vertex_height(cell)
  return a+(vertex_height(cell+Vector2.RIGHT)-a)*f.x+(vertex_height(cell+Vector2.DOWN)-a)*f.y
 var a:=vertex_height(cell+Vector2.ONE)
 return a+(vertex_height(cell+Vector2.DOWN)-a)*(1.0-f.x)+(vertex_height(cell+Vector2.RIGHT)-a)*(1.0-f.y)
static func vertex_height(xz:Vector2)->float:
 return ForestEcology.height_at(Vector2(xz.x,-xz.y)*20.0)/20.0
static func mesh()->PlaneMesh:
 var result:=PlaneMesh.new()
 result.size=SIZE
 result.subdivide_width=int(SIZE.x)-1
 result.subdivide_depth=int(SIZE.y)-1
 return result
static func patch_origin(camera_world:Vector2)->Vector3:
 return Vector3(floor(camera_world.x/20.0),0,floor(-camera_world.y/20.0-65.0))
