extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 StyleLibrary.active=true
 root.size=Vector2i(1000,800)
 var world:=SegmentWorld.new(ForestArt.new(),LocalRouteSpec.plan({"theme":"forest"}))
 var sprite:Dictionary=world.sprites[0].duplicate()
 var marker:=Image.create(64,128,false,Image.FORMAT_RGBA8)
 var colors:Array[Color]=[Color.RED,Color.GREEN,Color.BLUE,Color.YELLOW]
 for y in range(128):
  for x in range(64):marker.set_pixel(x,y,colors[(0 if y<64 else 2)+(0 if x<32 else 1)])
 sprite.texture=ImageTexture.create_from_image(marker)
 sprite.position=Vector2(0,170);sprite.w=38.0;sprite.h=60.0;sprite.altitude=0.0
 sprite.ground_anchor=Vector2(.4,.85);sprite.root_cover=[];sprite.ecology_tint=Color.WHITE
 world.sprites=[sprite]
 var view:=SegmentView.new();root.add_child(view)
 view.position=Vector2(73,59);view.size=Vector2(800,600)
 view.setup(ForestArt.new(),world,1,ThemeDB.fallback_font)
 for flip in [false,true]:
  sprite.flip=flip
  if view.renderer.forest_batch:
   var old=view.renderer.forest_batch;view.renderer.remove_child(old);old.free();view.renderer.forest_batch=null
  for yaw in [0.0,.18]:
   view.sync(Vector2.ZERO,yaw,1,0,0,false,false,0)
   for i in range(8):await process_frame
   await RenderingServer.frame_post_draw
   var projected:Array=view.renderer._project_space(400,view.renderer.horizon_y(),view.renderer.focal())
   var box:Rect2=projected[0].rect
   var rendered:=root.get_texture().get_image()
   for j in range(4):
    var point:=view.position+box.position+box.size*Vector2(.25 if j%2==0 else .75,.25 if j<2 else .75)
    var actual:=rendered.get_pixelv(Vector2i(point))
    var expected:Color=colors[(j^1) if flip else j]
    if Vector3(actual.r-expected.r,actual.g-expected.g,actual.b-expected.b).length()>.12:
     push_error("GPU orientation/anchor mismatch: flip=%s yaw=%s quadrant=%s actual=%s expected=%s"%[flip,yaw,j,actual,expected]);quit(1);return
 print("FOREST_BATCH_ORIENTATION_PASS actual GPU: top/bottom, horizontal flip, asymmetric anchor, offset viewport, two headings")
 quit()
