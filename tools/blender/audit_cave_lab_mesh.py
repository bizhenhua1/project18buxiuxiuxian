"""Independent BVH ray test of the ACTUAL exported triangles, not the SDF.
Uses saved hold-out camera rays from the Python reference and the production
projection already checked by Godot. No user interaction or screenshots needed.
"""
import argparse,json,sys,time
from pathlib import Path
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
p=argparse.ArgumentParser();p.add_argument('--spec',required=True);p.add_argument('--oracle',required=True);p.add_argument('--out',required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);start=time.monotonic()
spec_path=Path(a.spec);spec=json.loads(spec_path.read_text(encoding='utf-8'))
parts=json.loads((spec_path.parent/spec['mesh_file']).read_text(encoding='utf-8'))
vertices=[Vector(v) for part in parts for v in part['vertices']]
tree=BVHTree.FromPolygons(vertices,[(i,i+1,i+2) for i in range(0,len(vertices),3)],all_triangles=True)
oracle=np.load(a.oracle);directions=oracle['directions'];rows=[]
for pose,reference in zip(oracle['poses'],oracle['reference']):
    origin=Vector((pose[0],pose[1],-pose[2]));actual=[]
    for slope in directions:
        direction=Vector((slope[0],slope[1],-1))
        hit=tree.ray_cast(origin,direction.normalized(),140)[0]
        depth=(-hit.z-pose[2]) if hit is not None else float('inf')
        if slope[1]<0:depth=min(depth,-pose[1]/slope[1])
        actual.append(depth)
    actual=np.asarray(actual);valid=np.isfinite(reference)&(reference<55)
    missing=valid&~np.isfinite(actual);both=valid&np.isfinite(actual)
    difference=np.zeros(actual.shape);difference[both]=actual[both]-reference[both]
    delayed=np.flatnonzero(difference>3)
    examples=[]
    for pixel in delayed[::max(1,len(delayed)//5)][:5]:
        distance=reference[pixel];slope=directions[pixel]
        examples.append(dict(pixel=int(pixel),expected=[float(pose[0]+slope[0]*distance),float(pose[1]+slope[1]*distance),float(pose[2]+distance)],expected_depth=float(distance),actual_depth=float(actual[pixel])))
    missing_examples=[]
    for pixel in np.flatnonzero(missing)[:5]:
        distance=reference[pixel];slope=directions[pixel]
        missing_examples.append(dict(pixel=int(pixel),expected=[float(pose[0]+slope[0]*distance),float(pose[1]+slope[1]*distance),float(pose[2]+distance)]))
    rows.append(dict(pose=pose.tolist(),missing_pixels=int(missing.sum()),missing_examples=missing_examples,delayed_examples=examples,
        p99_extra_depth_m=float(np.percentile(np.maximum(actual[both]-reference[both],0),99)),
        p99_early_depth_m=float(np.percentile(np.maximum(reference[both]-actual[both],0),99))))
report=dict(seconds=time.monotonic()-start,triangles=len(vertices)//3,cameras=len(rows),
    rays_per_camera=len(directions),worst_missing_pixels=max(r['missing_pixels'] for r in rows),
    worst_p99_extra_depth_m=max(r['p99_extra_depth_m'] for r in rows),rows=rows)
Path(a.out).write_text(json.dumps(report,indent=2),encoding='utf-8')
print('CAVE_TRIANGLE_AUDIT',json.dumps({k:v for k,v in report.items() if k!='rows'}))
