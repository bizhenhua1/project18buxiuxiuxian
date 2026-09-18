extends Control
# Match expedition_route._layout_ui's content rectangle, including its UI scale.
# Keep the underlying stage standalone for profiling and projection diagnostics.
var container:SubViewportContainer
var viewport:SubViewport
var stage
var title:Label
func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var background:=ColorRect.new();background.color=Color("0b100e");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
 container=SubViewportContainer.new();container.stretch=true;container.hide();add_child(container)
 viewport=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
 title=Label.new();title.text="林间防线 · 战术防守";title.add_theme_color_override("font_color",Color("d6cbb1"));title.add_theme_font_size_override("font_size",24);add_child(title)
 resized.connect(layout_content);layout_content()
 var loading:=Label.new();loading.text="正在准备场景与角色…";loading.set_anchors_and_offsets_preset(Control.PRESET_CENTER);add_child(loading)
 stage=load("res://scenes/tactical_stage.tscn").instantiate()
 # The formal game uses orthographic portraits within a perspective world.
 # Preserve that character framing in the presentation entry; world positions,
 # collision, depth and the profiling stage's defaults remain independent.
 stage.portrait_mode=true
 stage.atmosphere_mode=true
 stage.set_meta("presentation_scene","res://scenes/tactical_presentation.tscn")
 viewport.add_child(stage)
 while not stage.ready_stage:
  loading.text="正在准备场景与角色… %d / 50"%stage.enemy_pool.size()
  await get_tree().process_frame
 # Submit the final camera, formation and material state before exposing the
 # viewport. During asynchronous model setup actors still sit at the origin.
 stage._process(0)
 await get_tree().process_frame
 container.show();loading.queue_free()
func layout_content():
 if not container:return
 var factor:=clampf(minf(size.x/1600.0,size.y/960.0),.65,3.0)
 var logical:=size/factor
 container.position=Vector2(24,88)*factor
 container.scale=Vector2.ONE*factor
 container.size=logical-Vector2(48,170)
 title.position=Vector2(40,18)*factor;title.scale=Vector2.ONE*factor

