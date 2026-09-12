import bpy, json, pathlib
out=pathlib.Path('F:/GitHub/project18buxiuxiuxian/tempassets/work/amplify-traversal')
out.mkdir(parents=True,exist_ok=True)
report={'rigs':[{ 'name':o.name,'bones':[b.name for b in o.data.bones][:25]} for o in bpy.data.objects if o.type=='ARMATURE'], 'actions':[{'name':a.name,'range':list(a.frame_range),'slots':[s.identifier for s in a.slots]} for a in bpy.data.actions]}
(out/'source-inventory.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('AMPLIFY_INVENTORY',len(report['actions']),report['rigs'])
