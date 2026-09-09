extends Control
const FX=preload("res://scripts/battle/epic_effect.gd")
var effects:Node2D
var chosen:=0
var looping:=true
var rate:=1.0
var timer:=0.0
var caption:Label
func _ready() -> void:
 DisplayServer.window_set_title("战斗特效 · Epic Toon 适配预览")
 var bg=ColorRect.new();bg.color=Color("10191e");bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(bg)
 var panel=VBoxContainer.new();panel.position=Vector2(22,24);panel.custom_minimum_size.x=285;add_child(panel)
 var title=Label.new();title.text="战斗特效 · 8 组适配";title.add_theme_font_size_override("font_size",24);panel.add_child(title)
 for i in range(FX.EFFECTS.size()):
  var b=Button.new();b.text=FX.EFFECTS[i].name;b.custom_minimum_size.y=46;panel.add_child(b)
  b.pressed.connect(func():chosen=i;play())
 var replay=Button.new();replay.text="重新播放";panel.add_child(replay);replay.pressed.connect(play)
 var loop=CheckButton.new();loop.text="循环预览";loop.button_pressed=true;panel.add_child(loop);loop.toggled.connect(func(v):looping=v)
 var speed=OptionButton.new()
 for text in ["0.5 倍速","1 倍速","2 倍速"]:speed.add_item(text)
 speed.select(1);panel.add_child(speed);speed.item_selected.connect(func(i):rate=[.5,1.0,2.0][i])
 var note=Label.new();note.text="原包静态贴图 + Godot 粒子与变换
不是 Unity 预制体原样转换
无序列帧；点击右侧任意位置播放";panel.add_child(note)
 effects=Node2D.new();add_child(effects)
 caption=Label.new();caption.position=Vector2(350,35);caption.add_theme_font_size_override("font_size",24);add_child(caption)
 play()
func play(at:Vector2=Vector2.ZERO) -> void:
 for child in effects.get_children():child.queue_free()
 var fx=FX.new();effects.add_child(fx);fx.position=at if at!=Vector2.ZERO else Vector2(size.x*.65,size.y*.52)
 fx.scale=Vector2.ONE*1.6;fx.setup(chosen);caption.text=FX.EFFECTS[chosen].name;timer=0
func _process(dt:float) -> void:
 timer+=dt*rate
 for child in effects.get_children():
  child.rate=rate;child.advance(dt)
 if looping and timer>1.9:play()
func _input(event:InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.position.x>340:play(event.position)
