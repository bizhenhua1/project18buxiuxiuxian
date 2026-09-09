import bpy,sys,json,pathlib
sys.path.insert(0,'C:/Users/admin/.local/share/blender-tools')
# Installable extension source is copied to a Python package by setup.
import mmd_tools
mmd_tools.register()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.mmd_tools.import_model(filepath='F:/GitHub/project18buxiuxiuxian/tempassets/先知绑定模型/先知-踏雪来.pmx',scale=.1)
out=pathlib.Path('F:/GitHub/project18buxiuxiuxian/tempassets/work');out.mkdir(exist_ok=True)
report={'objects':[],'images':[]}
for ob in bpy.context.scene.objects:
    if ob.type=='ARMATURE':
        report['bones']=[{'name':b.name,'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None} for b in ob.data.bones]
    report['objects'].append({'name':ob.name,'type':ob.type,'dimensions':list(ob.dimensions)})
for im in bpy.data.images:report['images'].append({'name':im.name,'path':im.filepath,'size':list(im.size)})
(out/'seer-inspection.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'seer-source.blend'))
print('SEER_IMPORTED')
