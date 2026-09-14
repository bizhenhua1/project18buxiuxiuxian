extends PanelContainer
var app
var heading:Label
var text:Label
var choices:HBoxContainer
var shown_key:=""
func setup(owner_app):
 app=owner_app;set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 offset_left=-350;offset_right=350;offset_top=-220;offset_bottom=-20
 var skin:=StyleBoxFlat.new();skin.bg_color=Color("101b1d");skin.border_color=Color("887451");skin.set_border_width_all(1)
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:skin.set_content_margin(side,16)
 add_theme_stylebox_override("panel",skin)
 var column:=VBoxContainer.new();add_child(column)
 heading=Label.new();heading.add_theme_font_size_override("font_size",22);heading.add_theme_color_override("font_color",Color("dccaa7"));column.add_child(heading)
 text=Label.new();text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size=Vector2(650,80);column.add_child(text)
 choices=HBoxContainer.new();column.add_child(choices)
func button(title:String,action:Callable,disabled:=false):
 var b:=Button.new();b.text=title;b.disabled=disabled;b.pressed.connect(action);choices.add_child(b)
func refresh():
 visible=app.phase in ["event","fork","victory","defeat"]
 if not visible:shown_key="";return
 var session=app.encounters
 var key:String=app.phase+str(session.cursor)+str(session.resolved)+str(session.stones)
 if key==shown_key:return
 shown_key=key
 for child in choices.get_children():choices.remove_child(child);child.queue_free()
 if app.phase=="fork":
  heading.text="岔路 · 听风辨路";text.text="一侧留有人迹，另一侧隐约传来异常气息。"
  for direction in ([-1,2,1] if app.world.plan.exits==3 else [-1,1]):button({-1:"沿左路",2:"沿直路",1:"沿右路"}[direction],func():app.choose_branch(direction))
 elif app.phase=="defeat":
  heading.text="暂歇 · 重整旗鼓";text.text="交锋暂歇，队伍需要重新站稳脚跟。\n休整后，将在原地再次迎战。"
  button("原地整备",func():app.reset_battle())
 elif app.phase=="victory" or session.resolved:
  heading.text="收获入囊 · %d 秘银"%session.stones;text.text=session.notice
  button("继续前进",func():app.start_travel())
 elif app.fork_test in [2,3]:
  heading.text="岔路测试 · 转弯完成";text.text="已沿选定路线前进。可继续测试另一种岔路，或从上方重复当前类型。"
  button("接着测试三岔" if app.fork_test==2 else "接着测试二岔",func():
   app.get_tree().set_meta("world3d_fork_test",3 if app.fork_test==2 else 2)
   app.get_tree().change_scene_to_file(str(app.get_meta("presentation_scene","res://scenes/world3d_stage.tscn"))))
 elif session.current().kind=="battle":
  heading.text="异变体挡路";text.text="前方的身影停住了。它察觉了你的靠近，挡在去路中央。\n你收紧手中的武器，准备迎战。"
  button("准备迎战",func():app.start_battle(false))
 else:
  var merchant:bool=session.current().get("event","")=="merchant"
  heading.text="歇脚行商" if merchant else "路遇档案员"
  text.text="行商将旧布铺开，露出随身带来的货物。\n“补给在这里。想找些别的？这张勘探许可或许用得上。”" if merchant else "他收拢药篓，朝你点了点头。\n“前面不好走。带些补给，或让我告诉你一处旧迹。”"
  button("勘探许可 · 4 秘银" if merchant else "调查旧迹",func():session.choose("fortune"),merchant and session.stones<4)
  button("带走补给",func():session.choose("supplies"))

