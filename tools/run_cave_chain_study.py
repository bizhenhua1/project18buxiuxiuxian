"""Actual two-fork traversal gate; separate from single-fork visual sweeps."""
import argparse,json,subprocess,time
from pathlib import Path
import numpy as np
from PIL import Image
from audit_cave_actor_clearance import audit as body_audit
from audit_cave_travel_composition import audit as camera_audit

ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--spec',required=True)
    p.add_argument('--out',required=True);p.add_argument('--first',type=int,choices=[-1,0,1],default=-1)
    p.add_argument('--second',type=int,choices=[-1,0,1],default=1);a=p.parse_args()
    out=Path(a.out).resolve();source=Path(a.spec).resolve();log=out.with_suffix('.log')
    if out.exists() or log.exists():raise ValueError('Use a fresh output directory')
    config=json.loads(source.read_text(encoding='utf-8'))
    if not config.get('chain'):raise ValueError('Missing precompiled chain')
    command=[a.godot,'--path',str(ROOT/'godot'),'--script','res://tests/study_c1_card_fork.gd','--',
             '--style2','--cards-spec='+str(source),'--run-dir='+str(out),'--chain-probe',
             '--branch='+str(a.first),'--second-choice='+str(a.second)]
    started=time.perf_counter()
    with log.open('w',encoding='utf-8') as handle:
        result=subprocess.run(command,stdout=handle,stderr=subprocess.STDOUT,cwd=ROOT,timeout=240)
    errors=[s for s in log.read_text(encoding='utf-8',errors='replace').splitlines() if s.startswith(('ERROR:','SCRIPT ERROR:','SHADER ERROR:'))]
    reasons=[]
    if result.returncode:reasons.append('native traversal did not reach all targets: '+str(result.returncode))
    if errors:reasons.append('native errors')
    manifest=out/'manifest.json'
    if not manifest.exists():reasons.append('missing manifest')
    else:
        data=json.loads(manifest.read_text(encoding='utf-8'))
        if len(data['chain_transitions'])!=1 or len(data['chain_choices'])!=2:reasons.append('expected two decisions and one connection')
        for row in data['chain_transitions']:
            if not np.allclose(row['before'],row['after'],atol=.01,rtol=0):reasons.append('route rail discontinuity')
        before=np.asarray(Image.open(out/'retirement-before.png')).astype(np.int16)
        after=np.asarray(Image.open(out/'retirement-after.png')).astype(np.int16)
        if np.abs(before-after).max()>1:reasons.append('retiring parent alternatives changes visible pixels')
        if body_audit(out,ROOT):reasons.append('actor/scenery overlap')
        if camera_audit(out):reasons.append('travel composition drift')
        subprocess.run([__import__('sys').executable,str(ROOT/'tools/audit_cave_card_capture.py'),'--run',str(out)],check=True)
        background=json.loads((out/'background-audit.json').read_text())
        if background['boundary_components']:reasons.append('background reaches viewport boundary')
    report=dict(status='rejected' if reasons else 'sampled_two_fork_traversal_not_art_acceptance',reasons=reasons,
                errors=errors,wall_seconds=time.perf_counter()-started,command=command,art_accepted=False,
                limitations=['two legs preloaded, not unbounded streaming','no battles/events in this probe',
                             'no animation/GPU performance acceptance','far end of second leg unfinished'])
    if out.exists():(out/'chain-gate.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))
    return 2 if reasons else 0

if __name__=='__main__':raise SystemExit(main())
