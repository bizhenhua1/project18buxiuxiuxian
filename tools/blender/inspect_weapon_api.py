import unreal,json,pathlib
out={}
for n in dir(unreal.AnimationLibrary):
 if 'bone_pose' in n or 'track' in n:out[n]=getattr(unreal.AnimationLibrary,n).__doc__
pathlib.Path('F:/GitHub/project18buxiuxiuxian/tempassets/work/weapon-api.json').write_text(json.dumps(out),encoding='utf8')
