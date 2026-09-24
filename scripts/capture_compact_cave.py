"""Bounded candidate replay. Keeps prior reference captures intact."""
from pathlib import Path
import subprocess,sys,json
root=Path(__file__).resolve().parents[1]
out=root/(sys.argv[1] if len(sys.argv)>1 else 'art/compact-cave-review/v1')
out.mkdir(parents=True,exist_ok=True)
cases=sys.argv[2:] or ['entry','junction2','junction3','left','right','center','battle','departure']
results=[]
for case in cases:
 dest=out/case
 if dest.exists():raise SystemExit('Refusing to overwrite '+str(dest))
 cmd=['F:/GitHub/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe','--path',str(root/'godot'),'--script','res://tests/capture_fairytale_3d_representative.gd','--','crystal','--run-dir='+str(dest),'--case='+('junction' if case.startswith('junction') else case),'--exits='+('2' if case in ['entry','junction2'] else '3'),'--frames=30','--compact-cave-workflow']
 r=subprocess.run(cmd,cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
 log=r.stdout+r.stderr;(out/(case+'.log')).write_text(log,encoding='utf-8')
 ok=r.returncode==0 and 'REP_CAPTURE_COMPLETE' in log and 'SCRIPT ERROR' not in log
 results.append({'case':case,'captured':ok});print(case,ok,flush=True)
 (out/'results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
 if not ok:raise SystemExit(log[-3000:])
