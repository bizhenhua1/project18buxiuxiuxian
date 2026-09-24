"""Isolated real-game gate. Nonzero on native/shader errors or failed checks.

Successful execution certifies only this captured travel path, not art quality,
combat, resource export, GPU performance or a production-ready biome.
"""
import argparse
import json
import subprocess
import time
from pathlib import Path
import numpy as np
from PIL import Image
from audit_cave_actor_clearance import audit

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',required=True)
    parser.add_argument('--spec',required=True)
    parser.add_argument('--out',required=True)
    parser.add_argument('--branch',type=int,choices=[-1,0,1],required=True)
    parser.add_argument('--event-probe',action='store_true')
    parser.add_argument('--continuation-probe',action='store_true')
    parser.add_argument('--full-cycle',action='store_true',help='Actual battle, clearing, resumed travel; settled combat uses 8x existing game clock')
    parser.add_argument('--retire-behind',action='store_true',help='Verify removal of traversed art with a four-metre reverse guard')
    parser.add_argument('--visual-sweep',action='store_true',help='Eight artistic views, six simulation steps per presentation; no gameplay/motion acceptance')
    parser.add_argument('--background-reference',help='Unchanged camera/phase reference for rejecting new interior holes')
    args=parser.parse_args()
    if args.visual_sweep:
        if args.event_probe or args.full_cycle:raise ValueError('Visual sweep is not an event or full-cycle gate')
        args.continuation_probe=True
    if args.event_probe and args.continuation_probe:raise ValueError('Separate battle-entry and continued-travel probes')
    if args.full_cycle:args.event_probe=True;args.continuation_probe=True
    out=Path(args.out).resolve();spec=Path(args.spec).resolve()
    spec_data=json.loads(spec.read_text(encoding='utf-8'))
    if args.branch not in spec_data.get('portal',{}).get('branches',[]):
        raise ValueError('Chosen branch is absent from the compiled fork')
    if out.exists():raise ValueError('Output must be new; never overwrite evidence')
    out.parent.mkdir(parents=True,exist_ok=True)
    log_path=out.parent/(out.name+'.log')
    if log_path.exists():raise ValueError('Refuse overwriting a previous run log')
    command=[args.godot,'--path',str(ROOT/'godot'),'--script','res://tests/study_c1_card_fork.gd','--',
             '--style2','--cards-spec='+str(spec),'--branch='+str(args.branch),'--run-dir='+str(out)]
    if args.full_cycle:command.append('--full-cycle')
    else:
        if args.event_probe:command.append('--event-probe')
        if args.continuation_probe:command.append('--continuation-probe')
    if args.retire_behind:command.append('--retire-behind')
    if args.visual_sweep:command.append('--visual-sweep')
    started=time.perf_counter()
    with log_path.open('w',encoding='utf-8') as log:
        completed=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=240)
    errors=[line for line in log_path.read_text(encoding='utf-8',errors='replace').splitlines()
            if line.startswith(('ERROR:','SCRIPT ERROR:','SHADER ERROR:'))]
    reasons=[]
    if completed.returncode:reasons.append('native process failed: '+str(completed.returncode))
    if errors:reasons.append('native reported an engine/script/shader error')
    manifest=out/'manifest.json'
    if not manifest.exists():reasons.append('missing capture manifest')
    else:
        data=json.loads(manifest.read_text(encoding='utf-8'))
        before=np.asarray(Image.open(out/'retirement-before.png').convert('RGBA')).astype(np.int16)
        after=np.asarray(Image.open(out/'retirement-after.png').convert('RGBA')).astype(np.int16)
        delta=np.abs(before-after)
        comparison=dict(rgba_identical=bool(not delta.any()),max_channel_delta=int(delta.max()),
                        changed_pixels=int((delta.max(2)>0).sum()),alpha_identical=bool(not delta[:,:,3].any()),
                        tolerance='one RGB code value in 8-bit output; alpha must match exactly')
        (out/'retirement-comparison.json').write_text(json.dumps(comparison,indent=2),encoding='utf-8')
        if comparison['max_channel_delta']>1 or not comparison['alpha_identical']:reasons.append('retirement changes rendered image beyond one output quantization step')
        if args.retire_behind:
            if len(data.get('pruning',[]))!=3:reasons.append('missing traversed-art retirement milestones')
            for i,row in enumerate(data.get('pruning',[])):
                a=np.asarray(Image.open(out/f'prune-{i}-before.png').convert('RGBA')).astype(np.int16)
                b=np.asarray(Image.open(out/f'prune-{i}-after.png').convert('RGBA')).astype(np.int16)
                diff=np.abs(a-b)
                if diff.max()>1 or diff[:,:,3].any():reasons.append(f'traversed-art retirement {i} changes visible pixels')
                if row['chunks_after']>=row['chunks_before']:reasons.append(f'traversed-art retirement {i} released no batches')
        if audit(out,ROOT):reasons.append('actor envelope intersects opaque artwork')
        if args.event_probe:
            from audit_cave_event_visibility import audit as audit_event
            if audit_event(out):reasons.append('battle presentation envelopes occluded by scenery')
        if args.continuation_probe:
            from audit_cave_travel_composition import audit as audit_composition
            if audit_composition(out):reasons.append('leader composition drifts on continued travel')
        subprocess.run([__import__('sys').executable,str(ROOT/'tools/audit_cave_card_capture.py'),'--run',str(out)],check=True,cwd=ROOT)
        background=json.loads((out/'background-audit.json').read_text(encoding='utf-8'))
        if background['boundary_components']:reasons.append('diagnostic background reaches viewport boundary')
        if args.background_reference:
            from audit_cave_background_regression import audit as audit_background
            if audit_background(out,Path(args.background_reference)):
                reasons.append('new diagnostic background exposed relative to unchanged camera reference')
    report=dict(status='rejected' if reasons else 'sampled_visual_sweep_not_gameplay_or_art_acceptance' if args.visual_sweep else 'sampled_travel_checks_pass_not_art_accepted',
                visual_sweep=args.visual_sweep,wall_seconds=time.perf_counter()-started,
                event_entry_probe=args.event_probe,
                reasons=reasons,errors=errors,command=command,art_accepted=False,
                limitations=['sampled cylinder excludes animated extremities','terminal treatment unfinished',
                             'one actual battle and travel, no successor' if args.full_cycle else 'battle probe covers entry and two seconds only' if args.event_probe else 'no battle/events',
                             'no repeated forks','no export or full frame performance acceptance'])
    if out.exists():(out/'integration-gate.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))
    return 2 if reasons else 0


if __name__=='__main__':raise SystemExit(main())
