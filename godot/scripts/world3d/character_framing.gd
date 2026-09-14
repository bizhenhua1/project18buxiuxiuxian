extends RefCounted
# SceneFormation.height describes the entire 2.6 m portrait camera frame,
# including transparent margins, not the model's normalized 1.8 m head height.
const PORTRAIT_HEIGHT:=2.6
const ROUTE_UNITS_PER_METRE:=20.0
static func scale_for_slot(height:float)->float:
 return height/(PORTRAIT_HEIGHT*ROUTE_UNITS_PER_METRE)
