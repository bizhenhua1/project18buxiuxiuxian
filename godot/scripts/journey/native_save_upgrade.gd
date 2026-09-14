extends RefCounted
## Import pre-rename native saves; these strings never enter the active content catalog.
const IDS = {"daotong": "investigator", "taomu-jian": "sealed-book", "waci-yin": "watchful-clock", "masuo": "silent-medium", "tongjing": "faceless-mask", "xiaohulu": "soul-lantern", "juhun-fan": "containment-record", "qingfeng-jian": "night-warden", "xuantie-jian": "stopped-clock", "kaishan-fu": "oathbreaker-mask", "lihuo-shu": "scarlet-edict", "bingfu-jue": "silence-contract", "tianlei-yin": "severed-moment", "huichun-shu": "ember-renewal", "huoli": "bone-hound", "caoshe": "bell-walker", "yewu": "dream-moth", "jinchan": "ashwing", "shujing": "forest-mourner", "yezhu": "rabid-hound", "xiaoqiao": "nightwing", "shanyang": "bone-wanderer", "huangfeng": "rift-moth", "shitoujing": "bell-guardian"}
const WORDS = {"道童": "提灯调查员", "桃木剑": "封缄之书", "瓦瓷印": "窥时怀表", "麻索": "缄默灵媒", "铜镜": "无面假面", "小葫芦": "引魂提灯", "聚魂幡": "收容记录", "青锋剑": "巡夜守卫", "玄铁重剑": "停摆之钟", "开山斧": "破誓假面", "离火术": "赤印敕令", "冰缚诀": "静默契约", "天雷引": "断刻裁决", "回春术": "余烬复苏", "火狸": "面骸猎犬", "草蛇": "丧钟行者", "野乌": "窥梦蛾", "金蟾": "灰翼眷属", "鼠精": "林中送葬者", "野猪": "失控猎犬", "小蛟": "夜翼", "山羊": "骨面徘徊者", "黄蜂": "裂梦飞蛾", "石头精": "钟骸守门人", "仙途 · 原生制作样本": "雾林调查局 · 黑暗童话", "仙途": "雾林调查局", "归云居": "灯下寓所", "云岫": "雾林行记", "灵石": "秘银", "灵草圃": "药草圃", "灵木园": "苗木园", "一圃灵草": "一圃药草", "机缘": "线索", "法宝": "封印物", "识海法术": "契约术式", "识海": "术式", "妖物": "异变体", "妖息": "异常气息", "妖势": "敌势", "妖兽": "异变生物", "御兽": "使役", "采药人": "档案员", "有缘人": "同行者", "寻宝符": "勘探许可", "妖火": "诅咒火焰", "妖光": "异光", "灵气": "幽光", "灵雨润泽": "温暖余烬", "灵性": "感知", "蛟息": "夜息", "引天雷": "引雷光", "修出剑心后参与剑阵连携": "获得共鸣后参与连锁攻击", "属剑类可入剑阵": "可参与连锁攻击", "属剑类": "连锁类", "剑阵": "连锁", "魂力": "回响", "魂噬": "回响冲击", "幡叠": "记录叠", "灵篆流转": "秘文流转", "墨灵": "墨影"}
static func card_id(value:String)->String:return IDS.get(value,value)
static func journal_line(value:String)->String:
 for old in WORDS:value=value.replace(old,WORDS[old])
 return value
static func import_settings():
 var destination:=ProjectSettings.globalize_path("user://")
 var previous:=OS.get_data_dir().path_join("Godot/app_userdata/仙途 · 原生制作样本")
 if not DirAccess.dir_exists_absolute(previous):return
 copy_missing(previous,destination)
static func copy_missing(source:String,destination:String):
 DirAccess.make_dir_recursive_absolute(destination)
 for file in DirAccess.get_files_at(source):
  var target:=destination.path_join(file)
  if not FileAccess.file_exists(target):
   if DirAccess.copy_absolute(source.path_join(file),target)==OK:migrate_file(target)
 for folder in DirAccess.get_directories_at(source):copy_missing(source.path_join(folder),destination.path_join(folder))
static func migrate_value(value:Variant)->Variant:
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:
   if key in ["realmLayers","realmBreaks"]:continue
   result[migrate_value(key)]=migrate_value(value[key])
  return result
 if value is Array:return value.map(migrate_value)
 if value is String:
  if value in IDS:return IDS[value]
  return journal_line(value).replace("fabaoAtkPct","relicAtkPct").replace("fabaoHpPct","relicHpPct")
 return value
static func migrate_file(path:String):
 if path.get_extension()=="json":
  var data=JSON.parse_string(FileAccess.get_file_as_string(path))
  if data is Dictionary or data is Array:
   var file:=FileAccess.open(path,FileAccess.WRITE)
   if file:file.store_string(JSON.stringify(migrate_value(data)))
 elif path.get_extension()=="cfg":
  var config:=ConfigFile.new()
  if config.load(path)!=OK:return
  for section in config.get_sections():
   for key in config.get_section_keys(section):config.set_value(section,key,migrate_value(config.get_value(section,key)))
  config.save(path)
