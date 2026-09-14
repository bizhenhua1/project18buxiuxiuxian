extends RefCounted
# Reconstruct the production close-up camera analytically, without a viewport.
static func parameters(anchor_view:Vector3,model_scale:float,pixel_height:float)->Dictionary:
 if pixel_height<=125:return {"portrait_near_view":Transform3D.IDENTITY,"portrait_near_params":Vector3.ZERO}
 var eye:Vector3=-anchor_view/model_scale
 eye.z=maxf(.6,eye.z)
 var center:=Vector3(0,.9,0)
 var view:=Transform3D(Basis.looking_at(center-eye),eye).affine_inverse()
 var from_view:=view*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE/model_scale),-anchor_view/model_scale)
 var fov:float=clampf(rad_to_deg(2*atan(1.3/maxf(.3,eye.distance_to(center)))),4,110)
 var focal:float=1.3/tan(deg_to_rad(fov)*.5)
 var ground:Vector3=view*Vector3.ZERO
 return {"portrait_near_view":from_view,"portrait_near_params":Vector3(smoothstep(125,160,pixel_height),model_scale*focal,ground.y/-ground.z)}
static func offset(point_view:Vector3,parameters:Dictionary)->Vector2:
 var q:Vector3=parameters.portrait_near_view*point_view
 var p:Vector3=parameters.portrait_near_params
 return Vector2(q.x/-q.z,q.y/-q.z-p.z)*p.y
