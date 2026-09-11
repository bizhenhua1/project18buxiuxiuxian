"""Export every Epic Toon 1.81 prefab, with explicit adaptation metadata."""
import json,re,yaml,shutil,math,functools
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
# Reuse the audited curve readers without running the six-effect export.
exec((ROOT/'tools/export_epic_preview.py').read_text(encoding='utf-8').split('output=[]')[0])
OUT=ROOT/'godot/assets/fx/epic181/library';OUT.mkdir(parents=True,exist_ok=True)
for d in ['effects','textures','meshes']:(OUT/d).mkdir(exist_ok=True)
LOADER=getattr(yaml,'CSafeLoader',yaml.SafeLoader)
@functools.lru_cache(maxsize=1800)
def docs(path):
 text=path.read_text(encoding='utf-8-sig')
 return {int(m.group(2)):yaml.load(m.group(3),Loader=LOADER) for m in re.finditer(r'^--- !u!(\d+) &(-?\d+)(?: stripped)?\n(.*?)(?=^---|\Z)',text,re.M|re.S)}
def compact(v):
 if isinstance(v,float):return round(v,6) if math.isfinite(v) else 0
 if isinstance(v,list):
  v=[compact(x) for x in v]
  return v
 if isinstance(v,dict):return {k:compact(x) for k,x in v.items()}
 return v
def curvepair(v):
 out=mm(v)
 return [a[:1] if all(x==a[0] for x in a) else a for a in out]
def colorpair(v):
 out=colors(v)
 return [a[:1] if all(x==a[0] for x in a) else a for a in out]
@functools.lru_cache()
def material(guid):
 rec=BY[guid];doc=next(iter(docs(SOURCE/rec['path']).values()))['Material']
 props=doc['m_SavedProperties'];tex={k:v for pair in props.get('m_TexEnvs',[]) for k,v in pair.items()}
 main=tex.get('_MainTex',{});t=main.get('m_Texture',{}).get('guid','')
 path=''
 if t in BY:
  source=SOURCE/BY[t]['path'];path='textures/'+t+source.suffix.lower();shutil.copy2(source,OUT/path)
 cs={k:v for pair in props.get('m_Colors',[]) for k,v in pair.items()}
 return {'texture':path,'tint':rgba(cs.get('_TintColor',cs.get('_Color',{}))),'additive':'_ADD' in rec['path'] or 'Additive' in rec['path'],'source':rec['path'],'gain':2 if '_TintColor' in cs else 1,'uv_scale':[main.get('m_Scale',{}).get(k,1) for k in 'xy'],'uv_offset':[main.get('m_Offset',{}).get(k,0) for k in 'xy']}
def transform(tr):
 q=tr.get('m_LocalRotation',{'x':0,'y':0,'z':0,'w':1})
 return {'position':vec(tr.get('m_LocalPosition',{})),'scale':vec(tr.get('m_LocalScale',{'x':1,'y':1,'z':1})),'rotation':[q[k] for k in 'xyzw']}
mesh_jobs={}
def mesh_ref(ref):
 guid=ref.get('guid','')
 if guid in BY and BY[guid]['extension']=='.fbx':
  mesh_jobs[guid]={'source':str(SOURCE/BY[guid]['path']),'output':str(OUT/'meshes'/str(guid+'.glb'))}
  return 'meshes/'+guid+'.glb'
 return ''
def convert(rec,stack=()):
 if rec['guid'] in stack:return [],['递归引用']
 ds=docs(SOURCE/rec['path']);transforms={};objects={};renderers={};warnings=set();layers=[]
 for fid,d in ds.items():
  if 'GameObject' in d:objects[fid]=d['GameObject'].get('m_Name','')
  if 'Transform' in d and 'm_GameObject' in d['Transform']:transforms[d['Transform']['m_GameObject']['fileID']]=d['Transform']
  if 'ParticleSystemRenderer' in d:renderers[d['ParticleSystemRenderer']['m_GameObject']['fileID']]=d['ParticleSystemRenderer']
 for d in ds.values():
  if 'ParticleSystem' not in d:continue
  ps=d['ParticleSystem'];go=ps['m_GameObject']['fileID'];rd=renderers.get(go,{})
  if not rd.get('m_Enabled',1):continue
  init=ps['InitialModule'];em=ps['EmissionModule'];shape=ps['ShapeModule'];uv=ps['UVModule']
  mats=[material(m['guid']) for m in rd.get('m_Materials',[]) if m.get('guid') in BY]
  if not mats:warnings.add('缺少粒子材质');continue
  chain=[];tr=transforms.get(go,{})
  while tr:
   chain.insert(0,transform(tr));parent=tr.get('m_Father',{}).get('fileID',0)
   tr=ds.get(parent,{}).get('Transform',{})
  def modulecurve(module,key,default=0):
   m=ps.get(module,{})
   return curvepair(m.get(key,default)) if m.get('enabled') else curvepair(default)
  size=ps['SizeModule'];rot=ps['RotationModule'];col=ps['ColorModule'];vel=ps['VelocityModule'];clamp=ps['ClampVelocityModule']
  simplified={k:shape.get(k,v) for k,v in {'enabled':0,'type':0,'angle':25,'length':1,'radiusThickness':1,'donutRadius':.2,'m_Position':{},'m_Rotation':{},'m_Scale':{'x':1,'y':1,'z':1}}.items()}
  rad=shape.get('radius',1)
  simplified['radius']=curvepair(rad.get('value',1) if isinstance(rad,dict) and 'value' in rad else rad)
  if shape.get('enabled') and shape.get('type') in [6,13,14]:warnings.add('网格表面发射为近似采样')
  if ps.get('TrailModule',{}).get('enabled'):warnings.add('粒子尾带未逐项还原')
  if ps.get('CollisionModule',{}).get('enabled'):warnings.add('原包场景碰撞未迁移')
  if ps.get('SubModule',{}).get('enabled'):warnings.add('子发射器未逐项还原')
  if ps.get('NoiseModule',{}).get('enabled'):warnings.add('噪声采用空间连续近似')
  if ps.get('LightsModule',{}).get('enabled'):warnings.add('粒子灯未启用')
  mesh=mesh_ref(rd.get('m_Mesh',{}))
  if int(rd.get('m_RenderMode',0))==4 and not mesh:warnings.add('使用基础网格替代内置网格')
  frame=uv.get('frameOverTime',{})
  layer={'name':objects.get(go,''),'transforms':chain,'duration':ps.get('lengthInSec',1),'loop':bool(ps.get('looping',False)),'local':int(ps.get('moveWithTransform',1))==0,
   'delay':curvepair(ps.get('startDelay',0)),'start':{k:curvepair(init.get(k,0 if k in ['startRotation','gravityModifier'] else 1)) for k in ['startLifetime','startSpeed','startSize','startRotation','gravityModifier']},
   'color':colorpair(init.get('startColor',{})),'material':mats[0],'render_mode':rd.get('m_RenderMode',0),'mesh':mesh,'length_scale':rd.get('m_LengthScale',1),'velocity_scale':rd.get('m_VelocityScale',0),
   'shape':simplified,'rate':curvepair(em.get('rateOverTime',0) if em.get('enabled') else 0),'distance_rate':curvepair(em.get('rateOverDistance',0) if em.get('enabled') else 0),
   'bursts':[{'time':b['time'],'count':curvepair(b.get('countCurve',1)),'cycles':b.get('cycleCount',1),'interval':b.get('repeatInterval',0),'probability':b.get('probability',1)} for b in em.get('m_Bursts',[])[:em.get('m_BurstCount',0)]] if em.get('enabled') else [],
   'size':modulecurve('SizeModule','curve',1),'rotation':modulecurve('RotationModule','curve',0),
   'gradient':colorpair(col.get('gradient',{})) if col.get('enabled') else colorpair({}),
   'velocity':{k:curvepair(vel.get(k,0)) for k in ['x','y','z']} if vel.get('enabled') else {},
   'velocity_world':bool(vel.get('inWorldSpace',False)),
   'damping':modulecurve('ClampVelocityModule','magnitude',0),'dampen':clamp.get('dampen',0) if clamp.get('enabled') else 0,'noise':modulecurve('NoiseModule','strength',0),
   'sheet':{'x':uv.get('tilesX',1),'y':uv.get('tilesY',1),'enabled':bool(uv.get('enabled')),'frame':curvepair(frame),'start':curvepair(uv.get('startFrame',0)),'cycles':uv.get('cycles',1),'animated':frame.get('minMaxState',0) in [1,2],'row_mode':uv.get('animationType',0),'row':uv.get('rowIndex',0)}
  }
  layers.append(layer)
 # Demo wrappers reference real prefabs. Resolve their dependencies, preserving nested transforms.
 for d in ds.values():
  inst=d.get('PrefabInstance',d.get('Prefab',{}))
  guid=inst.get('m_SourcePrefab',inst.get('m_ParentPrefab',{})).get('guid','')
  if guid in BY and BY[guid]['extension']=='.prefab':
   child,warn=convert(BY[guid],stack+(rec['guid'],));layers.extend(child);warnings.update(warn);warnings.add('演示包装：引用粒子，脚本与覆盖参数未执行')
 for key,label in [('LineRenderer','线段脚本'),('TrailRenderer','运动轨迹组件'),('MeshRenderer','静态装饰网格'),('MonoBehaviour','演示脚本')]:
  if any(key in d for d in ds.values()):warnings.add(label+'未自动执行')
 return layers,sorted(warnings)
COLORS=['Red','Blue','Green','Yellow','Purple','Pink','Orange','White','Black','Fire','Water','Dark','Light','Gold','Silver']
index=[]
for num,rec in enumerate(r for r in catalog['assets'] if r['extension']=='.prefab'):
 try:
  layers,warnings=convert(rec)
  path=rec['path'];name=rec['name'];parts=path.split('/')
  group=parts[3] if '/Prefabs/' in path else 'Demo';kind=parts[4] if len(parts)>4 else 'Other'
  color=next((c for c in COLORS if name.endswith(c)), 'Mixed')
  behavior='projectile' if kind=='Missiles' or '/Demo/Projectiles/' in path else 'slash' if 'SwordSlash' in name else 'beam' if kind in ['Laser','Lightning','Flamethrower'] else 'muzzle' if kind=='Muzzleflash' else 'impact' if any(x in kind for x in ['Explosion','Brawling','Blood']) or 'Hit' in name else 'ground' if any(x in kind for x in ['Zone','Portal','Healing','Level Up']) else 'ambient'
  meta={'id':rec['guid'],'name':name,'source':path,'group':group,'category':kind,'family':'/'.join(parts[5:-1]),'color':color,'behavior':behavior,'layers':len(layers),'warnings':warnings,'animated_sheet':any(l['sheet']['enabled'] and l['sheet']['animated'] for l in layers),'playable':bool(layers),'file':'effects/'+rec['guid']+'.json'}
  (OUT/meta['file']).write_text(json.dumps(compact({'name':name,'source':path,'layers':layers}),ensure_ascii=False,separators=(',',':')),encoding='utf-8')
  index.append(meta)
 except Exception as e:
  index.append({'id':rec['guid'],'name':rec['name'],'source':rec['path'],'group':'待处理','category':'待处理','family':'','color':'Mixed','behavior':'ambient','layers':0,'warnings':[str(e)],'animated_sheet':False,'playable':False,'file':''})
 if num%80==0:print(num,'processed',flush=True)
index.sort(key=lambda x:(x['group'],x['category'],x['family'],x['name']))
(OUT/'index.json').write_text(json.dumps(index,ensure_ascii=False,indent=1),encoding='utf-8')
(ROOT/'tempassets/work/epic-mesh-jobs.json').write_text(json.dumps(list(mesh_jobs.values())),encoding='utf-8')
print('DONE',len(index),'playable',sum(r['playable'] for r in index),'failed',sum(r['group']=='待处理' for r in index),'meshes',len(mesh_jobs),flush=True)

import runpy
runpy.run_path(str(ROOT/"tools/link_epic_library.py"),run_name="__main__")
