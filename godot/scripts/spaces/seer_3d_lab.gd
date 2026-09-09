extends "res://scripts/spaces/character_3d_lab.gd"
func _init() -> void:
 model_path="res://assets/characters3d/seer-treading-snow.glb"
 title_text="先知 · 踏雪来 / 法师动作适配"
 subtitle="原模型贴图与绑定"
 initial_clip="EM_Idle"
 labels={"EM_Idle":"待机","EM_Walk":"行走","EM_Run":"奔跑","EM_Attack01":"攻击一","EM_Attack02":"攻击二","EM_Attack03":"攻击三","EM_RangeAttack":"远程","EM_Special":"特殊","EM_Death":"倒下"}
func _ready() -> void:
 super._ready()
 model.scale=Vector3.ONE*1.65
 for child in get_children():
  if child is DirectionalLight3D:
   child.light_energy*=.45
   child.light_color=child.light_color.lerp(Color.WHITE,.65)
func play_clip(name:String) -> void:
 super.play_clip(name)
 if name!="EM_Death":
  target=Vector3(0,1.6,0);pitch=.13;distance=6.6
