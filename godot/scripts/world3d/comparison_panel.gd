extends PanelContainer
const ROOT="res://../tempassets/work/"
const PAIRS=[["formal-travel-baseline.png","world3d-aligned-travel.png"],["formal-battle-baseline.png","world3d-aligned-baseline.png"]]
var stage
var previous_pause:=false
var picker:OptionButton
var pictures:Array=[]
var captions:Array=[]
var columns:Array=[]
var view_picker:OptionButton
func setup(owner_stage):
 stage=owner_stage
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var background:=StyleBoxFlat.new();background.bg_color=Color("0b100e")
 background.content_margin_left=12;background.content_margin_right=12;background.content_margin_top=12;background.content_margin_bottom=12
 add_theme_stylebox_override("panel",background)
 var box:=VBoxContainer.new();add_child(box)
 var toolbar:=HBoxContainer.new();box.add_child(toolbar)
 var title:=Label.new();title.text="构图对照 · 已采集画面";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;toolbar.add_child(title)
 picker=OptionButton.new();picker.add_item("行进");picker.add_item("战斗");toolbar.add_child(picker);picker.item_selected.connect(show_pair)
 view_picker=OptionButton.new()
 for label in ["两图并排","放大传统版","放大 3D 版"]:view_picker.add_item(label)
 toolbar.add_child(view_picker);view_picker.item_selected.connect(set_view)
 var close:=Button.new();close.text="返回试玩";toolbar.add_child(close);close.pressed.connect(dismiss)
 var note:=Label.new();note.text="左：传统版　右：独立 3D 版。静态采集不随编辑实时更新，也不代表过程镜头已完全一致。";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(note)
 var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(row)
 for side in 2:
  var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(column);columns.append(column)
  var caption:=Label.new();caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(caption);captions.append(caption)
  var picture:=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(picture);pictures.append(picture)
 hide()
func set_view(index:int):
 for side in 2:columns[side].visible=index==0 or index==side+1
func open():
 if visible:return
 previous_pause=stage.playback_paused;stage.set_playback_paused(true)
 show_pair(picker.selected);show()
func dismiss():
 if not visible:return
 hide();stage.set_playback_paused(previous_pause)
func show_pair(index:int):
 for side in 2:
  var path:String=ProjectSettings.globalize_path(ROOT+PAIRS[index][side])
  pictures[side].texture=null
  if not FileAccess.file_exists(path):captions[side].text="尚未采集此画面";continue
  var image:=Image.load_from_file(path)
  if image==null or image.is_empty():captions[side].text="采集图无法读取";continue
  pictures[side].texture=ImageTexture.create_from_image(image)
  captions[side].text=("传统版" if side==0 else "3D 版")+" · 文件时间 UTC "+Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path)).replace("T"," ")
