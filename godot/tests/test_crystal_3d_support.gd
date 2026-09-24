extends SceneTree

# No render capture: original cave assets have support contours and the chosen
# exit removes other branches.
func _initialize() -> void:call_deferred("run")

func run() -> void:
 var geometry=load("res://scripts/world3d/contact_geometry.gd")
 # A hollow large cutout has two real feet and a transparent doorway. A stray
 # one-pixel fragment below a foot must not redefine the support surface.
 var hollow:=Image.create(96,64,false,Image.FORMAT_RGBA8)
 hollow.fill(Color.TRANSPARENT)
 for x in range(0,24):
  for y in range(0,60):hollow.set_pixel(x,y,Color.WHITE)
 for x in range(72,96):
  for y in range(0,60):hollow.set_pixel(x,y,Color.WHITE)
 for x in range(24,72):
  for y in range(0,16):hollow.set_pixel(x,y,Color.WHITE)
 hollow.set_pixel(12,63,Color.WHITE)
 var hollow_profile:PackedFloat32Array=geometry.contact_profile(hollow)
 assert(hollow_profile.size()==17)
 assert(hollow_profile[2]<.95 and hollow_profile[14]<.95,"Single-pixel debris changed the support foot")
 assert(is_equal_approx(hollow_profile[8],hollow_profile[4]),"The empty doorway must borrow a real side foot")
 var small:=Image.create(32,64,false,Image.FORMAT_RGBA8)
 small.fill(Color.TRANSPARENT)
 for x in range(8,24):
  for y in range(8,42):small.set_pixel(x,y,Color.WHITE)
 var small_profile:PackedFloat32Array=geometry.contact_profile(small)
 assert(absf(small_profile[8]-42.0/64.0)<.01,"Transparent padding must not leave a small prop floating")
 var scenery=load("res://scripts/world3d/scenery.gd").new()
 root.add_child(scenery)
 var space:=SpaceType.new();space.key=&"crystal"
 var region:=RouteRegion.new();region.space=space
 for name in ["shell.png","prop-0.png","prop-1.png","prop-2.png","prop-3.png","prop-4.png","prop-5.png","prop-6.png","prop-7.png","prop-8.png"]:
  var texture:Texture2D=load("res://assets/biomes/crystal/"+name)
  var profile:PackedFloat32Array=geometry.contact_profile(texture.get_image())
  assert(profile.size()==17)
  for foot in profile:assert(foot>0.0 and foot<=1.0)
  var sprite:Dictionary={"texture":texture,"position":Vector2.ZERO,"route_s":0.0,"route_branch":0,"w":80.0,"h":80.0,"flip":false,"region":region,"ground_anchor":Vector2(.5,1)}
  if name=="shell.png":sprite.shell=true
  var groups:Dictionary={}
  scenery.add_sprite_to_groups(sprite,groups)
  assert(groups.size()==1 and groups.values()[0].grounded,"Cave art must receive source-derived ground contact: "+name)
 for branch in [0,-1,1,2]:
  var node:=MultiMeshInstance3D.new()
  node.set_meta("cave_route_branch",branch)
  scenery.add_child(node)
  scenery.chunks.append(node)
 var choice_s:float=(ForestRoute.PAUSE_AT+ForestRoute.JUNCTION)*.5
 var fade_length:float=clampf(ForestRoute.TURN_LENGTH*.15,60.0,100.0)
 scenery.restrict_to_branch(1,choice_s)
 assert(is_zero_approx(scenery.chunks[1].transparency),"Selection must not remove a tunnel on its first frame")
 scenery.restrict_to_branch(1,choice_s+fade_length*.5)
 assert(scenery.chunks[1].visible and scenery.chunks[3].visible,"Other exits must fade during the turn")
 assert(scenery.chunks[1].transparency>.0 and scenery.chunks[1].transparency<1.0)
 var late_sprite:Dictionary={"texture":load("res://assets/biomes/crystal/shell.png"),"position":Vector2(0,ForestRoute.JUNCTION+400.0),"route_s":ForestRoute.JUNCTION+400.0,"route_branch":-1,"w":510.0,"h":300.0,"flip":false,"region":region,"ground_anchor":Vector2(.5,1),"shell":true}
 var late_groups:Dictionary={}
 scenery.add_sprite_to_groups(late_sprite,late_groups)
 scenery.build_group(late_groups.values()[0])
 assert(scenery.chunks.back().transparency>.0 and scenery.chunks.back().transparency<1.0,"A late upload must inherit the current branch fade")
 scenery.restrict_to_branch(1,choice_s+fade_length)
 assert(scenery.chunks[0].visible)
 assert(not scenery.chunks[1].visible)
 assert(scenery.chunks[2].visible)
 assert(not scenery.chunks[3].visible)
 assert(not scenery.chunks.back().visible,"A late uploaded exit must also become hidden")
 var late_bridge:Dictionary=late_sprite.duplicate();late_bridge.route_branch=0;late_bridge.junction_bridge=true
 late_groups.clear();scenery.add_sprite_to_groups(late_bridge,late_groups);scenery.build_group(late_groups.values()[0])
 assert(scenery.chunks.back().visible,"The parent arch outer wing must remain available to fill the turn")
 var late_entry:Dictionary=late_sprite.duplicate();late_entry.route_branch=1;late_entry.junction_entry=true
 late_groups.clear();scenery.add_sprite_to_groups(late_entry,late_groups);scenery.build_group(late_groups.values()[0])
 assert(scenery.chunks.back().visible and is_zero_approx(scenery.chunks.back().transparency),"A late uploaded chosen entry must inherit the completed handoff")
 var bridge:=MultiMeshInstance3D.new();bridge.set_meta("cave_route_branch",0);bridge.set_meta("junction_role",1)
 scenery.add_child(bridge);scenery.chunks.append(bridge);scenery.apply_branch_visibility(bridge)
 assert(scenery.branch_visibility_allowed(bridge),"The parent arch outer wing must remain during the selected turn")
 var entry:=MultiMeshInstance3D.new();entry.set_meta("cave_route_branch",1);entry.set_meta("junction_role",2)
 scenery.add_child(entry);scenery.chunks.append(entry);scenery.apply_branch_visibility(entry)
 assert(scenery.branch_visibility_allowed(entry) and is_zero_approx(entry.transparency),"The selected entry must be fully present after the handoff")
 scenery.free()
 print("original cave support profiles and selected-branch isolation: OK")
 quit()
