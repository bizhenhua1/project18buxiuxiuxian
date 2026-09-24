"""Offline planar cleanup; does not remesh, shrinkwrap or move the silhouette.
Run with Blender --background --factory-startup --python this_file -- ...
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
import bmesh

p=argparse.ArgumentParser();p.add_argument('--source',required=True);p.add_argument('--out',required=True)
p.add_argument('--ratio',type=float,default=1.0)
p.add_argument('--critical-ratio',type=float,default=0.0)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
source=Path(a.source);out=Path(a.out);out.mkdir(parents=True,exist_ok=False)
spec=json.loads(source.read_text(encoding='utf-8'))
parts=json.loads((source.parent/spec['mesh_file']).read_text(encoding='utf-8'))
result=[];metrics=[]
for part in parts:
    mesh=bpy.data.meshes.new('lab_chunk')
    v=part['vertices']
    mesh.from_pydata(v,[],[(i,i+1,i+2) for i in range(0,len(v),3)])
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000003)
    # Only coplanar internal edges. Two degrees would smooth the intended
    # contour and change the experiment; use a much stricter angular tolerance.
    bmesh.ops.dissolve_limit(bm,angle_limit=math.radians(.01),use_dissolve_boundaries=False,
                            verts=list(bm.verts),edges=list(bm.edges))
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bm.normal_update()
    ratio=a.ratio
    if part.get('critical_skin',False):ratio=1.0
    if abs(part['z']+3.5-(10+spec['recipe']['transition']*.5))<3.5:
        ratio=max(ratio,a.critical_ratio)
    if ratio<1.0:
        from mathutils.bvhtree import BVHTree
        tree=BVHTree.FromBMesh(bm)
        bm.to_mesh(mesh)
        obj=bpy.data.objects.new('reduce_lab_chunk',mesh);bpy.context.scene.collection.objects.link(obj)
        modifier=obj.modifiers.new('bounded_candidate_decimation','DECIMATE');modifier.ratio=ratio
        modifier.use_collapse_triangulate=True
        deps=bpy.context.evaluated_depsgraph_get()
        evaluated=obj.evaluated_get(deps);simplified=evaluated.to_mesh()
        simplified.calc_loop_triangles()
        vertices=[[round(float(c),6) for c in simplified.vertices[i].co] for face in simplified.loop_triangles for i in face.vertices]
        error=max((tree.find_nearest(v.co)[3] or 0) for v in simplified.vertices)
        evaluated.to_mesh_clear();bpy.data.objects.remove(obj,do_unlink=True)
    else:
        vertices=[[round(float(c),6) for c in v.co] for f in bm.faces for v in f.verts]
        error=0
    result.append(dict(index=part['index'],z=part['z'],vertices=vertices))
    metrics.append(dict(chunk=part['index'],ratio=ratio,before=len(part['vertices'])//3,after=len(vertices)//3,max_vertex_surface_distance_m=error))
    bm.free();bpy.data.meshes.remove(mesh)
spec['triangles_before_cleanup']=spec['triangles'];spec['triangles']=sum(x['after'] for x in metrics)
(out/spec['mesh_file']).write_text(json.dumps(result,separators=(',',':')),encoding='utf-8')
(out/'spec.json').write_text(json.dumps(spec,indent=2),encoding='utf-8')
(out/'cleanup.json').write_text(json.dumps(dict(method='weld_then_optional_quadric_reduction',ratio=a.ratio,
    caution='Vertex distance is not a whole-surface proof; native silhouette and chunk seam recheck required.',parts=metrics),indent=2),encoding='utf-8')
print('CAVE_PLANAR_CLEANUP',spec['triangles_before_cleanup'],spec['triangles'])
