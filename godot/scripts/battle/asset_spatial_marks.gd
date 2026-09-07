extends RefCounted
## Pixel annotations on the original PNG canvas; shared skins resolve via CARDS.
## Head clearance includes ears/antennae, excluding unrelated wing tips.
const MONSTERS := {
	"hound": {"size":Vector2(721,695), "bounds":Rect2(1,1,719,693), "head":Vector2(145,5)},
	"bell": {"size":Vector2(428,721), "bounds":Rect2(0,1,428,720), "head":Vector2(185,4)},
	"moth": {"size":Vector2(721,551), "bounds":Rect2(0,0,721,550), "head":Vector2(300,55)}
}
const PROPS := {
	"watch": {"placement":"floating", "clearance":22.0, "bob":1.0},
	"book": {"placement":"floating", "clearance":17.0, "bob":.7},
	"mask": {"placement":"floating", "clearance":19.0, "bob":.8},
	"lantern": {"placement":"grounded", "clearance":0.0, "bob":0.0}
}
static func asset_key(unit:Dictionary) -> String:
	var spec:Array=StyleLibrary.CARDS.get(unit.get("cardId",unit.get("id","")),[])
	return str(spec[0]) if StyleLibrary.active and not spec.is_empty() else ""
static func head_uv(unit:Dictionary,texture:Texture2D,flip:bool=false) -> Vector2:
	var mark:Dictionary=MONSTERS.get(asset_key(unit),{})
	var uv:=Vector2(.5,0)
	if not mark.is_empty():
		var crop:Rect2=mark.bounds
		uv=(mark.head-crop.position)/crop.size if texture.get_size()==crop.size else mark.head/mark.size
	if flip:uv.x=1-uv.x
	return uv
static func prop_mark(unit:Dictionary) -> Dictionary:
	return PROPS.get(asset_key(unit),{"placement":"floating","clearance":17.0,"bob":.7})
