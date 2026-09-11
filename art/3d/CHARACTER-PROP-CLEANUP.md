# 角色附属物清理

2026-09-11：16个角色清理独立宠物、玩偶、彩球、漂浮物以及自带武器。详细清单在 character-prop-cleanup.json。服装、头饰、身体、骨架和动画数据保留。不可明确判定为独立道具的装饰不做猜测删除。

原始 GLB 备份在 tempassets/work/character-originals/，原始导入素材仍保留。清理脚本 tools/blender/clean_character_props.py 仅筛选渲染 primitive，不重新绑定骨骼或重导出身体。重复运行从备份开始。

9组武器独立提取至 godot/assets/weapons/character-extracted/，包含剑、短刀、棍、法器和扇；manifest.json 记录来源。导出保留原比例、以包围盒中心为原点。握持挂点尚未标定，因此不自动加入装备目录，避免再次产生穿手和朝向错误。提取脚本 tools/blender/extract_character_weapons.py。

角色卡面已重新渲染。24个角色通过 test_character_batch.gd：骨架有效、动作映射有效、左右手挂点有效；另有全角色缩略图人工检查。
