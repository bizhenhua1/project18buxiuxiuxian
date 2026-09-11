"""Read-only Unity package audit and safe local extraction. Does not execute scripts."""
import tarfile,json,re,csv,hashlib,collections,html,gzip,shutil
from pathlib import Path,PurePosixPath
from PIL import Image
BASE=Path(__file__).resolve().parents[1]
PACKAGE=BASE/'tempassets/vfx/Epic Toon FX 1.81.unitypackage'
OUT=BASE/'tempassets/vfx/epic-toon-1.81'
OUT.mkdir(parents=True,exist_ok=True)
def value(text,key,default=''):
 m=re.search(r'^\s*'+re.escape(key)+r':\s*([^\n]+)',text,re.M);return m.group(1).strip() if m else default
def modules(text):
 return {m.group(1):m.group(2) for m in re.finditer(r'^  (\w+Module):\n(.*?)(?=^  \w+:|\Z)',text,re.M|re.S)}
def main():
 records=[];byguid={};texts={};preview_dir=OUT/'previews';preview_dir.mkdir(exist_ok=True)
 uncompressed=OUT/"package.tar"
 if not uncompressed.exists():
  with gzip.open(PACKAGE,"rb") as source,uncompressed.open("wb") as dest:shutil.copyfileobj(source,dest)
 with tarfile.open(uncompressed) as archive:
  members={m.name:m for m in archive.getmembers() if m.isfile()}
  for member in members:
   if not member.endswith('/pathname'):continue
   guid=member.split('/')[0]
   path=archive.extractfile(members[member]).read().decode('utf-8-sig').splitlines()[0].rstrip('\x00')
   logical=PurePosixPath(path)
   if logical.is_absolute() or '..' in logical.parts or not path.startswith('Assets/'):raise ValueError(path)
   if guid+'/asset' not in members:continue
   data=archive.extractfile(members[guid+'/asset']).read();dest=OUT/'source'/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
   if guid+'/asset.meta' in members:dest.with_name(dest.name+'.meta').write_bytes(archive.extractfile(members[guid+'/asset.meta']).read())
   rec={'guid':guid,'path':path,'name':logical.stem,'extension':logical.suffix.lower(),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
   if guid+'/preview.png' in members:
    image_data=archive.extractfile(members[guid+'/preview.png']).read()
    if image_data.startswith(b'\x89PNG'): (preview_dir/(guid+'.png')).write_bytes(image_data);rec['preview']='previews/'+guid+'.png'
   if rec['extension'] in ['.prefab','.mat','.cs','.shader','.txt','.unity']:
    text=data.decode('utf-8-sig',errors='replace');texts[guid]=text;rec['references']=sorted(set(re.findall(r'guid: ([0-9a-f]{32})',text)))
   if rec['extension']=='.png':
    im=Image.open(dest);rec['size']=list(im.size)
   records.append(rec);byguid[guid]=rec
 for rec in records:
  text=texts.get(rec['guid'],'')
  if rec['extension']=='.mat':
   rec['shader']=value(text,'m_Shader');rec['textures']=[byguid[g]['path'] for g in rec.get('references',[]) if g in byguid and byguid[g]['extension']=='.png']
  if rec['extension']!='.prefab':continue
  rec['category']=rec['path'].split('Epic Toon FX/',1)[-1].rsplit('/',1)[0]
  rec['family']=rec['category']
  rec['particle_systems']=[]
  for body in re.findall(r'^ParticleSystem:\n(.*?)(?=^---|\Z)',text,re.M|re.S):
   mods=modules(body);uv=mods.get('UVModule','');trail=mods.get('TrailModule','')
   ps={'game_object':value(body,'m_GameObject'),'duration':value(body,'lengthInSec'),'loop':value(body,'looping'),'move_with_transform_raw':value(body,'moveWithTransform'),'max_particles':value(mods.get('InitialModule',''),'maxNumParticles'), 'modules':[k for k,v in mods.items() if value(v,'enabled')=='1'],'texture_sheet':value(uv,'enabled')=='1','tiles_x':value(uv,'tilesX'),'tiles_y':value(uv,'tilesY'),'trails':value(trail,'enabled')=='1'}
   frame=re.search(r'^    frameOverTime:\n(.*?)(?=^    \w+:|\Z)',uv,re.M|re.S)
   mode=value(frame.group(1),'minMaxState') if frame else ''
   ps['uv_frame_mode']=mode
   ps['sheet_usage']='off' if not ps['texture_sheet'] else 'constant_or_random_tile' if value(uv,'timeMode','0')=='0' and mode in ['0','3'] else 'animated_or_curve'
   rec['particle_systems'].append(ps)
  rec['layers']=len(rec['particle_systems'])
  rec['texture_sheet_layers']=sum(p['texture_sheet'] for p in rec['particle_systems'])
  rec['animated_sheet_layers']=sum(p['sheet_usage']=='animated_or_curve' for p in rec['particle_systems'])
  rec['trail_layers']=sum(p['trails'] for p in rec['particle_systems'])
  rec['renderer_modes']=dict(collections.Counter(re.findall(r'^  m_RenderMode: (\d+)',text,re.M)))
  rec['child_prefabs']=[byguid[g]['path'] for g in rec.get('references',[]) if g in byguid and byguid[g]['extension']=='.prefab']
  rec['materials']=[byguid[g]['path'] for g in rec.get('references',[]) if g in byguid and byguid[g]['extension']=='.mat']
  rec['scripts']=[byguid[g]['path'] for g in rec.get('references',[]) if g in byguid and byguid[g]['extension']=='.cs']
  closure=set();pending=list(rec.get('references',[]))
  while pending:
   g=pending.pop()
   if g in closure:continue
   closure.add(g)
   if g in byguid:pending.extend(byguid[g].get('references',[]))
  rec['dependency_paths']=sorted(byguid[g]['path'] for g in closure if g in byguid)
  rec['textures']=sorted(byguid[g]['path'] for g in closure if g in byguid and byguid[g]['extension']=='.png')
  rec['external_guids']=sorted(g for g in closure if g not in byguid)
 prefabs=[r for r in records if r['extension']=='.prefab']
 summary={'package':PACKAGE.name,'sha256':hashlib.sha256(PACKAGE.read_bytes()).hexdigest(),'counts':dict(collections.Counter(r['extension'] for r in records)),'families':dict(sorted(collections.Counter(r['family'] for r in prefabs).items())),'prefabs_with_inline_particles':sum(r['layers']>0 for r in prefabs),'prefabs_with_sheet_modules':sum(r['texture_sheet_layers']>0 for r in prefabs),'prefabs_with_trails':sum(r['trail_layers']>0 for r in prefabs),'particle_layers':sum(r['layers'] for r in prefabs),'previews':sum('preview'in r for r in prefabs)}
 (OUT/'catalog.json').write_text(json.dumps({'summary':summary,'assets':records},ensure_ascii=False,indent=2),encoding='utf-8')
 with (OUT/'prefabs.csv').open('w',newline='',encoding='utf-8-sig') as f:
  cols=['name','category','layers','texture_sheet_layers','animated_sheet_layers','trail_layers','materials','textures','scripts'];w=csv.DictWriter(f,fieldnames=cols,extrasaction='ignore');w.writeheader();w.writerows(prefabs)
 compact=[{k:r.get(k,[]) for k in ['name','category','path','preview','layers','texture_sheet_layers','animated_sheet_layers','trail_layers','textures','materials','scripts','child_prefabs']} for r in prefabs]
 data=json.dumps(compact,ensure_ascii=False).replace('</','<\/')
 page='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>Epic Toon FX 1.81 · 本地资产目录</title><style>body{margin:24px;background:#111b20;color:#ddded4;font:15px system-ui}h1{color:#e8c589}input,select{padding:12px;background:#243239;color:white;border:1px solid #66736e;margin:4px}#grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:12px}.card{background:#1d292e;border:1px solid #455053;padding:14px}.card img{width:100px;height:100px;object-fit:contain;float:right}.path{font-size:12px;overflow-wrap:anywhere;color:#a3b7b9}summary{cursor:pointer}a{color:#d6ba80}li{overflow-wrap:anywhere}header{position:sticky;top:0;background:#111b20;padding:12px;z-index:1}</style><h1>Epic Toon FX 1.81 · 预制体目录</h1><p>预制体附图是 Unity 图标，因此这里展示依赖贴图，不代表组合后的动态效果。粒子切片与时间动画已分别标记；预制体引用父级时，内嵌粒子数量不代表完整效果数量。</p><header><input id="q" placeholder="搜索 sword / fireball / heal" size="32"><select id="cat"><option value="">全部分类</option></select><label><input type="checkbox" id="sheet">仅无内嵌动画切片</label><span id="count"></span></header><div id="grid"></div><script>const data=DATA;const cats=[...new Set(data.map(x=>x.category.split('/').slice(0,3).join('/')))].sort();const cat=document.getElementById('cat');for(const c of cats){let o=document.createElement('option');o.value=c;o.textContent=c;cat.append(o)}function esc(s){return String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;')}function render(){let a=data.filter(x=>(x.name+' '+x.category).toLowerCase().includes(q.value.toLowerCase())&&(!cat.value||x.category.startsWith(cat.value))&&(!sheet.checked||!x.animated_sheet_layers));count.textContent=a.length+' 项';grid.innerHTML=a.map(x=>`<article class="card">${x.textures.length?`<img title="依赖贴图，非动态效果" loading="lazy" src="${encodeURI('source/'+(x.textures.find(t=>/slash|fireball|fire[0-9]|lightning|shield/i.test(t))||x.textures[0]))}">`:''}<b>${esc(x.name)}</b><p>${x.layers} 层粒子 · ${x.texture_sheet_layers} 层切片（动画 ${x.animated_sheet_layers}） · ${x.trail_layers} 层拖尾</p><p class="path">${esc(x.category)}</p><details><summary>依赖与原文件</summary><a href="${encodeURI('source/'+x.path)}">Unity 预制体原文件</a><p>贴图</p><ul>${x.textures.map(t=>`<li><a href="${encodeURI('source/'+t)}">${esc(t.split('/').pop())}</a></li>`).join('')}</ul><p>材质 ${x.materials.length}；脚本 ${x.scripts.length}；引用预制体 ${x.child_prefabs.length}</p></details></article>`).join('')}q.oninput=cat.onchange=sheet.onchange=render;render();</script></html>'''.replace('DATA',data)
 (OUT/'index.html').write_text(page,encoding='utf-8')
 print(json.dumps({k:v for k,v in summary.items() if k!='families'},ensure_ascii=False,indent=2))
 print('category groups',dict(collections.Counter('/'.join(r['category'].split('/')[:3]) for r in prefabs)))
if __name__=='__main__':main()
