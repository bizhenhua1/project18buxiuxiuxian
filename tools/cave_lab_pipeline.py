"""One bounded research build. FAILS on rejected geometry; no game/art approval.

python tools/cave_lab_pipeline.py --exits 2 --out <new-relative-output-dir>
The engine and Blender paths can be overridden; no shell interpolation is used.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser()
    p.add_argument('--exits',type=int,choices=[2,3],required=True)
    p.add_argument('--out',required=True)
    p.add_argument('--organic',action='store_true')
    p.add_argument('--blender',default='C:/Program Files/Blender Foundation/Blender 4.2/blender.exe')
    p.add_argument('--godot',default='F:/GitHub/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
    a=p.parse_args();out=(ROOT/a.out).resolve();out.mkdir(parents=True,exist_ok=False)
    steps=[]
    def run(label,args):
        started=time.monotonic()
        completed=subprocess.run(args,cwd=ROOT,text=True,encoding='utf-8',errors='replace',capture_output=True)
        (out/(label+'.log')).write_text(completed.stdout+completed.stderr,encoding='utf-8')
        steps.append(dict(step=label,seconds=time.monotonic()-started,exit_code=completed.returncode))
        (out/'steps.json').write_text(json.dumps(steps,indent=2),encoding='utf-8')
        print(label,completed.returncode,flush=True)
        if completed.returncode:raise SystemExit(completed.returncode)
    command=[sys.executable,'tools/cave_lab_mesh.py','--exits',str(a.exits),'--out',str(out/'raw')]
    if a.organic:command+=['--organic']
    run('mesh',command)
    run('oracle',[sys.executable,'tools/cave_algorithm_lab.py','--oracle-spec',str(out/'raw/spec.json'),'--out',str(out/'oracle')])
    run('reduce',[a.blender,'--background','--factory-startup','--python','tools/blender/compile_cave_lab_mesh.py','--',
        '--source',str(out/'raw/spec.json'),'--out',str(out/'reduced'),'--ratio','.06'])
    run('audit',[a.blender,'--background','--factory-startup','--python','tools/blender/audit_cave_lab_mesh.py','--',
        '--spec',str(out/'reduced/spec.json'),'--oracle',str(out/'oracle/oracle.npz'),'--out',str(out/'triangle-audit.json')])
    evidence=json.loads((out/'triangle-audit.json').read_text(encoding='utf-8'))
    status=dict(status='rejected_geometry',art_accepted=False,
        worst_missing_pixels=evidence['worst_missing_pixels'],
        worst_p99_extra_depth_m=evidence['worst_p99_extra_depth_m'])
    if evidence['worst_missing_pixels'] or evidence['worst_p99_extra_depth_m']>3:
        (out/'status.json').write_text(json.dumps(status,indent=2),encoding='utf-8')
        raise SystemExit('Geometry rejected; stop before art and game integration.')
    run('native',[a.godot,'--path',str(ROOT/'godot'),'--script','res://tests/probe_cave_algorithm_lab.gd','--',
        '--spec='+str(out/'reduced/spec.json'),'--out='+str(out/'native')])
    status['status']='geometry_screen_passed_not_art_accepted'
    (out/'status.json').write_text(json.dumps(status,indent=2),encoding='utf-8')
    print(status['status'],flush=True)

if __name__=='__main__':main()
