import json,re,yaml,shutil,math
from pathlib import Path
from PIL import Image
BASE=Path(__file__).resolve().parents[1];SOURCE=BASE/'tempassets/vfx/epic-toon-1.81/source';OUT=BASE/'godot/assets/fx/epic181';OUT.mkdir(parents=True,exist_ok=True)
catalog=json.loads((SOURCE.parent/'catalog.json').read_text(encoding='utf-8'));BY={r['guid']:r for r in catalog['assets']}
NAMES=['SwordSlashThinWhite','SwordSlashThickWhite','SwordHitYellow','MuzzleFireballSoftFire','FireballSoftMissileFire','ExplosionFireballSoftFire']
def docs(path):
 text=path.read_text(encoding='utf-8-sig');return {int(m.group(2)):yaml.safe_load(m.group(3)) for m in re.finditer(r'^--- !u!(\d+) &(-?\d+)\n(.*?)(?=^---|\Z)',text,re.M|re.S)}
def curve(c,t):
 keys=c.get('m_Curve',[])
 if not keys:return 1
 if t<=keys[0]['time']:return keys[0]['value']
 for a,b in zip(keys,keys[1:]):
  if t<=b['time']:
   dt=b['time']-a['time'];u=(t-a['time'])/max(dt,1e-6)
   if not math.isfinite(a.get('outSlope',0)):return a['value']
   return (2*u**3-3*u*u+1)*a['value']+(u**3-2*u*u+u)*dt*a.get('outSlope',0)+(-2*u**3+3*u*u)*b['value']+(u**3-u*u)*dt*b.get('inSlope',0)
 return keys[-1]['value']
def mm(c):
 if not isinstance(c,dict):return [[float(c or 0)]*33]*2
 mode=c.get('minMaxState',0);hi=c.get('scalar',1);lo=c.get('minScalar',hi)
 if mode==0:return [[hi]*33]*2
 if mode==3:return [[lo]*33,[hi]*33]
 a=[curve(c.get('maxCurve',{}),i/32)*hi for i in range(33)]
 return [a,a] if mode==1 else [[curve(c.get('minCurve',{}),i/32)*hi for i in range(33)],a]
def rgba(c):return [c.get(k,1) for k in 'rgba']
def lerpkeys(keys,t):
 if t<=keys[0][0]:return keys[0][1]
 for a,b in zip(keys,keys[1:]):
  if t<=b[0]:return a[1]+(b[1]-a[1])*(t-a[0])/max(.00001,b[0]-a[0])
 return keys[-1][1]
def gradient(g):
 nc=g.get('m_NumColorKeys',2);na=g.get('m_NumAlphaKeys',2);result=[]
 for i in range(33):
  color=[]
  for k in 'rgba':
   count=na if k=='a' else nc;prefix='atime' if k=='a' else 'ctime'
   keys=sorted((g.get(prefix+str(j),0)/65535,g.get('key'+str(j),{}).get(k,1)) for j in range(count))
   color.append(lerpkeys(keys,i/32))
  result.append(color)
 return result
def colors(c):
 mode=c.get('minMaxState',0)
 if mode==0:return [[rgba(c.get('maxColor',{}))]*33]*2
 if mode==2:return [[rgba(c.get('minColor',{}))]*33,[rgba(c.get('maxColor',{}))]*33]
 hi=gradient(c.get('maxGradient',{}));return [gradient(c.get('minGradient',{})),hi] if mode==3 else [hi,hi]
def vec(d):return [d.get(k,0) for k in 'xyz']
def material(guid):
 rec=BY[guid];doc=next(iter(docs(SOURCE/rec['path']).values()))['Material'];props=doc['m_SavedProperties'];tex={k:v for pair in props.get('m_TexEnvs',[]) for k,v in pair.items()};t=tex.get('_MainTex',{}).get('m_Texture',{}).get('guid','');files=[]
 if t in BY:
  path=SOURCE/BY[t]['path'];shutil.copy2(path,OUT/path.name);files=[path.name]
 cs={k:v for pair in props.get('m_Colors',[]) for k,v in pair.items()};name=rec['path'];return {'texture':files[0] if files else '', 'tint':rgba(cs.get('_TintColor',cs.get('_Color',{}))), 'additive':('_ADD' in name or 'Additive' in name),'source':name}
output=[]
for name in NAMES:
 rec=next(r for r in catalog['assets'] if r['name']==name and r['extension']=='.prefab');ds=docs(SOURCE/rec['path']);objects={};transforms={};renderers={}
 for fid,d in ds.items():
  if 'GameObject'in d:objects[fid]=d['GameObject']['m_Name']
  if 'Transform'in d:transforms[d['Transform']['m_GameObject']['fileID']]=(fid,d['Transform'])
  if 'ParticleSystemRenderer'in d:renderers[d['ParticleSystemRenderer']['m_GameObject']['fileID']]=d['ParticleSystemRenderer']
 layers=[]
 for d in ds.values():
  if 'ParticleSystem'not in d:continue
  ps=d['ParticleSystem'];go=ps['m_GameObject']['fileID'];rd=renderers.get(go,{})
  if not rd.get('m_Enabled',1):continue
  initial=ps['InitialModule'];em=ps['EmissionModule'];shape=ps['ShapeModule'];size=ps['SizeModule'];rot=ps['RotationModule'];col=ps['ColorModule'];uv=ps['UVModule'];vel=ps['VelocityModule'];clamp=ps['ClampVelocityModule'];noise=ps['NoiseModule']
  mats=[material(m['guid']) for m in rd.get('m_Materials',[]) if m.get('guid') in BY]
  if not mats:continue
  transform=[];fid,tr=transforms[go]
  while True:
   q=tr['m_LocalRotation'];transform.insert(0,{'position':vec(tr['m_LocalPosition']),'scale':vec(tr['m_LocalScale']),'rotation':[q[k] for k in 'xyzw']})
   parent=tr['m_Father']['fileID']
   if not parent:break
   tr=ds[parent]['Transform']
  sheet=int(uv.get('enabled',0));tilex=int(uv.get('tilesX',1));tiley=int(uv.get('tilesY',1))
  # Random constant tile selection: split the source into separate static textures.
  if sheet and uv['frameOverTime']['minMaxState'] in [0,3]:
   src=Image.open(OUT/mats[0]['texture']);tiles=[]
   for j in range(tilex*tiley):
    path=Path(mats[0]['texture']);file=path.stem+'-tile'+str(j)+'.png';w=src.width//tilex;h=src.height//tiley;src.crop(((j%tilex)*w,(j//tilex)*h,(j%tilex+1)*w,(j//tilex+1)*h)).save(OUT/file);tiles.append(file)
   mats[0]['tiles']=tiles
  layer={'name':objects[go],'transforms':transform,'duration':ps['lengthInSec'],'loop':bool(ps['looping']),'local':not bool(ps.get('moveWithTransform',0)), 'delay':mm(ps['startDelay']),'start':{k:mm(initial[k]) for k in ['startLifetime','startSpeed','startSize','startRotation','gravityModifier']},'color':colors(initial['startColor']),'material':mats[0], 'render_mode':rd.get('m_RenderMode',0),'length_scale':rd.get('m_LengthScale',1),'shape':shape,'rate':mm(em['rateOverTime']),'distance_rate':mm(em['rateOverDistance']),'bursts':[{'time':b['time'],'count':mm(b['countCurve'])} for b in em.get('m_Bursts',[])[:em.get('m_BurstCount',0)]],'size':mm(size['curve']) if size.get('enabled') else mm(1),'rotation':mm(rot.get('curve',{})) if rot.get('enabled') else mm(0),'gradient':colors(col.get('gradient',{})) if col.get('enabled') else colors({}), 'velocity':{k:mm(vel.get(k,0)) for k in ['x','y','z']} if vel.get('enabled') else {},'damping':mm(clamp.get('magnitude',0)) if clamp.get('enabled') else mm(0),'dampen':clamp.get('dampen',0) if clamp.get('enabled') else 0,'noise':mm(noise.get('strength',0)) if noise.get('enabled') else mm(0)}
  layers.append(layer)
 output.append({'name':name,'source':rec['path'],'layers':layers});print(name,len(layers),flush=True)
(OUT/'effects.json').write_text(json.dumps(output,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
print('EXPORTED',len(output))
