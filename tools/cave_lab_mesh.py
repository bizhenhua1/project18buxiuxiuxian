"""Compile the tested hybrid free-volume rule to real short rock geometry.

Marching tetrahedra is used only OFFLINE for this inexpensive hypothesis tool.
It handles changing fork topology without joining mismatched arch vertices.
It does not build continuous outer walls: solids exist only in short ribs and
the medial fork saddle. One material can later share tiled world-scale texture.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import numpy as np
from cave_algorithm_lab import Recipe, ROOT, planes, smooth, poses, section, profile

OFFSETS=np.array([[0,0,0],[1,0,0],[1,1,0],[0,1,0],
                  [0,0,1],[1,0,1],[1,1,1],[0,1,1]],int)
TETS=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]


def field(p,r):
    x,y,z=p[...,0],p[...,1],p[...,2]
    center=r.offset*smooth((z-10)/r.transition)
    width,height,shift=profile(z,r)
    inner=np.full(x.shape,np.inf);outer=np.full(x.shape,np.inf)
    for side in ([-1,1] if r.exits==2 else [-1,0,1]):
        inner=np.minimum(inner,np.sqrt(((x-side*center-shift)/width)**2+(np.maximum(y-r.spring,0)/(height-r.spring))**2))
        outer=np.minimum(outer,np.sqrt(((x-side*center-shift)/(width+r.band))**2+(np.maximum(y-r.spring,0)/(height+r.band-r.spring))**2))
    shell=np.minimum((inner-1)*width,(1-outer)*(width+r.band))
    nodes=planes(r)
    warped_z=z-r.warp*(np.sin(x*1.17+y*.37)+.35*np.sin(x*.47-y*.83))
    index=np.clip(np.searchsorted(nodes,warped_z),1,len(nodes)-1)
    d=np.minimum(np.abs(warped_z-nodes[index]),np.abs(warped_z-nodes[index-1]))
    body=np.minimum(shell,r.thickness*.5-d)
    if r.method=='hybrid':
        saddle=np.minimum.reduce([shell,center+shift-x,x+center-shift,height-y,y+.12,z-10,10+r.transition+4-z])
        body=np.maximum(body,saddle)
    # Slight buried base, no raised planar bottom masquerading as ground.
    return np.minimum(body,y+.12)


def tetra_surface(bounds,spacing,r):
    axes=[np.arange(a,b+spacing*.1,spacing) for a,b in bounds]
    grid=np.stack(np.meshgrid(*axes,indexing='ij'),axis=-1)
    f=field(grid,r)
    shape=np.array(f.shape)-1
    origin=np.stack(np.meshgrid(*(np.arange(n) for n in shape),indexing='ij'),axis=-1).reshape(-1,3)
    values=np.stack([f[tuple((origin+v).T)] for v in OFFSETS],axis=1)
    active=(values.min(axis=1)<=0)&(values.max(axis=1)>0)
    origin=origin[active];values=values[active]
    positions=np.array([axes[0][0],axes[1][0],axes[2][0]])+(origin[:,None,:]+OFFSETS)*spacing
    triangles=[]
    for tet in TETS:
        v=values[:,tet]
        pos=positions[:,tet,:]
        code=np.sum((v>0)*np.array([1,2,4,8]),axis=1)
        for mask in range(1,15):
            select=code==mask
            if not select.any():continue
            inside=[i for i in range(4) if mask&(1<<i)]
            outside=[i for i in range(4) if not mask&(1<<i)]
            vv,pp=v[select],pos[select]
            def cut(a,b):
                t=vv[:,a]/(vv[:,a]-vv[:,b])
                return pp[:,a]+(pp[:,b]-pp[:,a])*t[:,None]
            if len(inside)==1:
                triangles.append(np.stack([cut(inside[0],b) for b in outside],axis=1))
            elif len(inside)==3:
                triangles.append(np.stack([cut(outside[0],a) for a in inside],axis=1))
            else:
                a,b=inside;c,d=outside
                p0,p1,p2,p3=cut(a,c),cut(a,d),cut(b,d),cut(b,c)
                triangles.extend([np.stack([p0,p1,p2],axis=1),np.stack([p0,p2,p3],axis=1)])
    if not triangles:return np.zeros((0,3,3))
    tri=np.concatenate(triangles)
    if r.method=='hybrid':
        # The fork nose can be arbitrarily thin. A voxel grid can erase it even
        # when globally refined. Replace this entire medial boundary with the
        # analytic, topology-preserving skin below, rather than adding voxels.
        mid=tri.mean(axis=1)
        extent=r.offset*smooth((mid[:,2]-10)/r.transition)
        _,height,shift=profile(mid[:,2],r)
        medial=(mid[:,2]>10)&(mid[:,2]<10+r.transition+4)&(np.abs(mid[:,0]-shift)<extent)&(mid[:,1]<height)&(mid[:,1]>-.12)
        tri=tri[~medial]
    normal=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])
    norm=np.linalg.norm(normal,axis=1)
    tri=tri[norm>1e-10];normal=normal[norm>1e-10]/norm[norm>1e-10,None]
    mid=tri.mean(axis=1)
    # Positive field is solid. Orient normals outwards, then reverse handedness
    # when +forward is converted to Godot's -Z below.
    reverse=field(mid+normal*.01,r)>field(mid-normal*.01,r)
    tri[reverse]=tri[reverse][:,[0,2,1]]
    tri=tri[:,[0,2,1]];tri[:,:,2]*=-1
    return tri


def divider_skin(r):
    """Preserve the bifurcation ridge explicitly. The tip z is the root of
    centre separation - two arch half-widths, separately at each height.
    This is the essential fork primitive; no column stacking or voxel guess.
    """
    rows=[(-.12,None),(0.,None),(r.spring,None)]+[(None,float(theta)) for theta in np.linspace(.04,np.pi/2,49)]
    ts=np.linspace(0,1,65)**2
    branches=[-1,1] if r.exits==2 else [-1,0,1]
    triangles=[]
    for left,right in zip(branches,branches[1:]):
        lgrid=[];rgrid=[]
        for fixed_y,theta in rows:
            factor=float(np.cos(theta)) if theta is not None else 1.0
            def gap(z):
                _,w=section(z,r)
                return (right-left)*r.offset*smooth((z-10)/r.transition)-2*w*factor
            lo,hi=10.,10+r.transition
            for _ in range(45):
                mid=(lo+hi)*.5
                if gap(mid)>0:hi=mid
                else:lo=mid
            tip=(lo+hi)*.5
            lr=[];rr=[]
            for t in ts:
                z=tip+t*(10+r.transition+4-tip)
                w,height,shift=profile(z,r);c=r.offset*smooth((z-10)/r.transition)
                y=r.spring+(height-r.spring)*np.sin(theta) if theta is not None else fixed_y
                lr.append([left*c+shift+w*factor,float(y),z])
                rr.append([right*c+shift-w*factor,float(y),z])
            lgrid.append(lr);rgrid.append(rr)
        a,b=np.array(lgrid),np.array(rgrid)
        def quad(p,q,s,t):triangles.extend([[p,q,s],[p,s,t]])
        for j in range(len(rows)-1):
            for k in range(len(ts)-1):
                quad(a[j,k],a[j+1,k],a[j+1,k+1],a[j,k+1])
                quad(b[j,k+1],b[j+1,k+1],b[j+1,k],b[j,k])
            quad(a[j,-1],a[j+1,-1],b[j+1,-1],b[j,-1])
        for k in range(len(ts)-1):
            quad(a[0,k+1],a[0,k],b[0,k],b[0,k+1])
            quad(a[-1,k],a[-1,k+1],b[-1,k+1],b[-1,k])
    result=np.array(triangles)
    result[:,:,2]*=-1
    return result[:,[0,2,1]]


def math_sqrt(value):return float(np.sqrt(value))


def main():
    p=argparse.ArgumentParser();p.add_argument('--out',required=True)
    p.add_argument('--exits',type=int,default=2);p.add_argument('--spacing',type=float,default=.25)
    p.add_argument('--refine-junction',action='store_true')
    p.add_argument('--organic',action='store_true')
    args=p.parse_args();out=ROOT/args.out;out.mkdir(parents=True,exist_ok=False)
    r=Recipe(method='hybrid',exits=args.exits,offset=3.4 if args.exits==2 else 5.,
             step=1.25,thickness=.8,band=1.6,forward_end=96.)
    if args.organic:
        r=Recipe(method='hybrid',exits=args.exits,offset=3.1 if args.exits==2 else 5.4,
                 radius=1.85,throat=1.10,height=3.,spring=.7,step=1.25,
                 thickness=.9,band=1.6,relief=.4,warp=.25,jitter=.15,seed=91,forward_end=96.)
    parts=[];count=0
    extent=r.offset+r.radius+r.band+r.relief+.5
    # Shared lattice origin at chunk boundaries avoids independent seam errors.
    for i,start in enumerate(np.arange(-2.,r.forward_end,7.)):
        step=args.spacing
        if args.refine_junction and abs(start+3.5-(10+r.transition*.5))<3.5:
            step*=.5
        tri=tetra_surface([(-extent,extent),(-.25,r.height+r.band+.5),(start,start+7)],step,r)
        count+=len(tri)
        parts.append(dict(index=i,z=float(start),vertices=np.round(tri.reshape(-1,3),6).tolist()))
    if r.method=='hybrid':
        tri=divider_skin(r);count+=len(tri)
        parts.append(dict(index=len(parts),z=10.,critical_skin=True,vertices=np.round(tri.reshape(-1,3),6).tolist()))
    mesh='hybrid-mesh.json'
    (out/mesh).write_text(json.dumps(parts,separators=(',',':')),encoding='utf-8')
    from dataclasses import asdict
    spec=dict(recipe=asdict(r),planes=planes(r).tolist(),lens=1.,horizon=.48,
              mesh_file=mesh,triangles=count,grid_spacing=args.spacing,
              shots=[dict(name=f'hybrid-{i}',pose=pose) for i,pose in enumerate(poses(r,9))])
    (out/'spec.json').write_text(json.dumps(spec,indent=2),encoding='utf-8')
    print(f'HYBRID_MESH exits={r.exits} triangles={count} parts={len(parts)}',flush=True)


if __name__=='__main__':main()
