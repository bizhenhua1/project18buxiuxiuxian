import unreal,json,pathlib
base=pathlib.Path('F:/GitHub/project18buxiuxiuxian')
mapping=json.loads((base/'tempassets/work/pack-map.json').read_text(encoding='utf8'))
result={};report=[]
for path,meta in mapping.items():
 if meta['pack'] not in ['7','8'] or '/Animation' not in path:continue
 obj=unreal.load_asset(path)
 if not isinstance(obj,unreal.AnimSequence):continue
 names=[str(n) for n in unreal.AnimationLibrary.get_animation_track_names(obj)]
 tracks={}
 for bone in ['weapon_r','weapon_l']:
  if bone not in names:continue
  poses=[unreal.AnimationLibrary.get_bone_pose_for_time(obj,bone,i/30.0,False) for i in range(int(obj.sequence_length*30)+1)]
  tracks[bone]={'positions':[[v.translation.x,v.translation.y,v.translation.z] for v in poses],'rotations':[[v.rotation.x,v.rotation.y,v.rotation.z,v.rotation.w] for v in poses]}
 key=meta['pack']+'_'+obj.get_name()
 report.append({'clip':key,'weapon_tracks':list(tracks),'bones':names if not report else []})
 if 'weapon_r' in tracks:
  t=tracks['weapon_r'];ps=t['positions'];qs=t['rotations']
  if ps and qs and (max(sum((a-b)**2 for a,b in zip(q,qs[0])) for q in qs)>.00001 or max(sum((a-b)**2 for a,b in zip(q,ps[0])) for q in ps)>.001):result[key]=t
(base/'godot/assets/weapons/weapon_tracks.json').write_text(json.dumps(result),encoding='utf8')
(base/'tempassets/work/weapon-track-audit.json').write_text(json.dumps(report),encoding='utf8')
unreal.log('WEAPON_TRACKS_EXPORTED '+str(len(result)))
