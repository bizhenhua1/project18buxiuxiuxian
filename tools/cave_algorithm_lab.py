"""Cheap, reproducible CUTOUT geometry experiments. No finished art or game saves.

This is a rejection tool, NOT an art acceptance score. The reference is the
continuous free volume; candidates are discrete zero-thickness cutout sections.
Comparing independent arches against the UNION of route apertures exposes the
otherwise easy-to-miss error of a sibling arch blocking the selected route.
Coordinates: metres, +Z forward, Y up. Projection mirrors projection.gd.
"""
from __future__ import annotations
import argparse
import itertools
import json
import math
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Recipe:
    method: str = "union"
    step: float = 1.5
    band: float = 1.5
    transition: float = 12.0
    offset: float = 3.4
    exits: int = 2
    radius: float = 2.1
    throat: float = 1.25
    height: float = 3.7
    spring: float = 1.1
    jitter: float = 0.0
    seed: int = 37
    depth_nodes: tuple = ()
    thickness: float = 0.0
    relief: float = 0.0
    warp: float = 0.0
    forward_end: float = 82.0


def smooth(t):
    t = np.clip(t, 0, 1)
    return t*t*t*(10 + t*(-15 + 6*t))


def geology_noise(z,seed):
    k=np.floor(np.asarray(z)/7.3)
    t=np.asarray(z)/7.3-k
    def hashed(i):
        value=np.sin(i*127.1+seed*.618033)*43758.5453
        return (value-np.floor(value))*2-1
    return hashed(k)+(hashed(k+1)-hashed(k))*smooth(t)


def profile(z,r):
    """One shared, slowly varying cavity. Decorations never define this void.
    Variation is seeded and continuous; widths grow outwards from the reserved
    walk envelope. Height and lateral visual offset vary independently.
    """
    w=r.radius+(r.throat-r.radius)*smooth((np.asarray(z)-10)/5)
    w+=(r.radius-r.throat)*smooth((np.asarray(z)-10-r.transition)/5)
    w+=r.relief*.5*(1+geology_noise(z,r.seed))
    h=r.height+r.relief*.35*geology_noise(np.asarray(z)+11,r.seed)
    shift=r.relief*.2*geology_noise(np.asarray(z)+26,r.seed)
    return w,h,shift


def section(z, r):
    """Keep the actual curved apertures, never merge into a rectangular plaza.

    All branches use the same finite transition; parallel headings afterwards.
    This fixture deliberately retains siblings to TEST whether they're hidden.
    """
    t = (z - 10.0) / r.transition
    x = r.offset * smooth(t)
    w,_,shift=profile(z,r)
    branches = [-1, 1] if r.exits == 2 else [-1, 0, 1]
    centers = [float(b*x+shift) for b in branches] if z > 10 else [float(shift)]
    return centers, float(w)


def inside(x, y, c, width, height, spring):
    return ((x-c)/width)**2 + (np.maximum(y-spring, 0)/(height-spring))**2 < 1


def swept_section(z, r):
    """Conservative free volume for a short solid rib, not just its centre.

    Width is monotone between the known taper endpoints. Centre movement is
    monotone on the finite S transition. Bounding both over a rib interval
    gives a capsule aperture that contains EVERY intermediate route section.
    This prevents adding thickness from putting rock through the walking path.
    """
    a, b = z-r.thickness*.5, z+r.thickness*.5
    checkpoints = [a, b]+[v for v in [10., 15., 10+r.transition, 15+r.transition] if a < v < b]
    width = max(section(v, r)[1] for v in checkpoints)
    lo = r.offset*smooth((a-10)/r.transition)
    hi = r.offset*smooth((b-10)/r.transition)
    branches = [-1, 1] if r.exits == 2 else [-1, 0, 1]
    ranges = [tuple(sorted([float(sign*lo), float(sign*hi)])) for sign in branches]
    return ranges, width


def rib_occupancy(x, y, z, r):
    ranges, width = swept_section(z, r)
    free = np.zeros(np.broadcast_shapes(np.shape(x), np.shape(y)), bool)
    outer = np.zeros_like(free)
    for lo, hi in ranges:
        nearest = np.clip(x, lo, hi)
        free |= inside(x, y, nearest, width, r.height, r.spring)
        outer |= inside(x, y, nearest, width+r.band, r.height+r.band, r.spring)
    return outer & ~free


def divider_occupancy(x, y, z, r):
    """A local rock saddle BETWEEN exits, not new left/right corridor walls.
    Keep the vanishing nose continuous when one opening separates into several.
    Discrete independent arches otherwise sample past this thin wedge entirely.
    """
    if not 10 < z < 10+r.transition+4:
        return np.zeros(np.broadcast_shapes(np.shape(x), np.shape(y)), bool)
    centers, _ = section(z, r)
    return occupancy(x, y, z, r) & (x >= min(centers)) & (x <= max(centers)) & (y < profile(z,r)[1]) & (y >= 0)


def occupancy(x, y, z, r, reference=False):
    centers, width = section(z, r)
    height=profile(z,r)[1]
    free = np.zeros(np.broadcast_shapes(np.shape(x), np.shape(y)), bool)
    outer = np.zeros_like(free)
    independent = np.zeros_like(free)
    for c in centers:
        hole = inside(x, y, c, width, height, r.spring)
        mass = inside(x, y, c, width+r.band, height+r.band, r.spring)
        free |= hole
        outer |= mass
        independent |= mass & ~hole
    if reference:
        return ~free
    return independent if r.method == "independent" else outer & ~free


def planes(r, end=None):
    if end is None:end=r.forward_end
    if r.depth_nodes:
        return np.array(r.depth_nodes)
    rng = np.random.default_rng(r.seed)
    result = []
    z = -2.0
    while z <= end:
        result.append(z)
        z += r.step * rng.uniform(1-r.jitter, 1+r.jitter)
    return np.array(result)


def rays(size, lens=1.0, horizon=.48, aspect=None):
    w, h = size
    yy, xx = np.mgrid[:h, :w]
    f = min(h*.86, w*.72)*lens
    dx=(xx+.5-w*.5)/f
    if aspect is not None:
        # Keep the actual game viewport aspect when using a coarse ray grid.
        # Grid dimensions are sampling density, not an alternative camera.
        focal=min(.86,aspect*.72)*lens
        return ((xx+.5)/w-.5)*aspect/focal,(horizon-(yy+.5)/h)/focal
    return dx, (h*horizon-yy-.5)/f


def reference_cast(r,pose,size,lens=1.,horizon=.48,aspect=None):
    """Conservative distance-bound march through the continuous free volume.
    Fixed 20cm steps miss narrow fork noses and can mislabel an earlier real
    surface as an error. Inside any ellipse, (1-rho)*min(axis) is a lower bound
    on distance to that ellipse's boundary. Exit from the UNION must exit this
    containing ellipse too. Divide by a bound on longitudinal deformation.
    A 2mm termination bound replaces the old fixed 20cm reference sampling.
    """
    cx,eye,cz=pose;dx,dy=rays(size,lens,horizon,aspect)
    floor=np.full(dx.shape,np.inf);down=dy<0;floor[down]=-eye/dy[down]
    depth=np.full(dx.shape,.05);result=np.full(dx.shape,np.inf)
    active=np.ones(dx.shape,bool)
    deformation=1+1.875*r.offset/r.transition+2*1.875*abs(r.radius-r.throat)/5+r.relief
    length=np.sqrt(1+dx*dx+dy*dy)
    for iteration in range(1200):
        if not active.any():break
        z=cz+depth;x=cx+dx*depth;y=eye+dy*depth
        centers=r.offset*smooth((z-10)/r.transition)
        width,height,shift=profile(z,r)
        value=np.full(dx.shape,np.inf)
        for b in ([-1,1] if r.exits==2 else [-1,0,1]):
            rho=np.sqrt(((x-b*centers-shift)/width)**2+(np.maximum(y-r.spring,0)/(height-r.spring))**2)
            value=np.minimum(value,(rho-1)*np.minimum(width,height-r.spring))
        hit=active&(value>=-.002)
        result[hit]=depth[hit];active[hit]=False
        ground=active&(depth>=floor)
        result[ground]=floor[ground];active[ground]=False
        active&=(z<r.forward_end)
        depth[active]+=np.maximum(.001,-value[active]/(deformation*length[active]))
    if active.any():
        # A nearly tangent ray can make tiny safe steps for a long time. Finish
        # only those exceptional rays on a 2mm grid instead of stalling the
        # entire batch or silently labelling them background.
        for iy,ix in np.argwhere(active):
            ds=np.arange(depth[iy,ix],max(depth[iy,ix]+.002,r.forward_end-cz),.002)
            z=cz+ds;x=cx+dx[iy,ix]*ds;y=eye+dy[iy,ix]*ds
            centers=r.offset*smooth((z-10)/r.transition)
            width,height,shift=profile(z,r);value=np.full(ds.shape,np.inf)
            for b in ([-1,1] if r.exits==2 else [-1,0,1]):
                rho=np.sqrt(((x-b*centers-shift)/width)**2+(np.maximum(y-r.spring,0)/(height-r.spring))**2)
                value=np.minimum(value,(rho-1)*np.minimum(width,height-r.spring))
            hits=np.flatnonzero(value>=-.002)
            if len(hits):result[iy,ix]=ds[hits[0]]
    return np.minimum(result,floor),np.zeros(dx.shape,np.int16)


def cast(r, pose, size=(96, 60), reference=False, lens=1.0, horizon=.48):
    if reference:
        return reference_cast(r,pose,size,lens,horizon)
    cx, eye, cz = pose
    dx, dy = rays(size, lens, horizon)
    distance = np.full(dx.shape, np.inf)
    floor = dy < 0
    distance[floor] = -eye/dy[floor]
    owner = np.full(dx.shape, -1, np.int16)  # -1 = floor or terminal view
    nodes = planes(r)
    if reference:
        samples = [(float(z), float(z), i) for i, z in enumerate(np.arange(cz+.05, 82, .2))]
    elif r.thickness:
        # Sample along short solids; native triangle rendering later checks
        # actual surfaces. This discrete ray march is a SCREEN, not proof.
        n = max(2, math.ceil(r.thickness/.12)+1)
        samples = sorted((float(z+v), float(z), i) for i, z in enumerate(nodes)
                         for v in np.linspace(-r.thickness*.5, r.thickness*.5, n))
        if r.method == 'hybrid':
            samples = sorted(samples+[(float(z), float(z), -2) for z in np.arange(10,10+r.transition+4,.1)])
    else:
        samples = [(float(z), float(z), i) for i, z in enumerate(nodes)]
        if r.method == 'card-hybrid':
            # 2D is the primary scene representation. Test the narrow question
            # of whether only the fork's medial connector needs thickness.
            # This must NOT silently install solid ribs along the whole route.
            samples = sorted(samples+[(float(z),float(z),-2) for z in np.arange(10,10+r.transition+4,.1)])
    for z, centre, i in samples:
        d = z-cz
        if d <= .05:
            continue
        eligible = d < distance
        if not eligible.any():
            break
        solid = (divider_occupancy(cx+dx*d, eye+dy*d,z,r) if i == -2 and not reference else
                 occupancy(cx+dx*d, eye+dy*d,z,r) if r.method in ['loft','hybrid'] and not reference else
                 rib_occupancy(cx+dx*d, eye+dy*d, centre, r) if r.thickness and not reference
                 else occupancy(cx+dx*d, eye+dy*d, z, r, reference))
        hit = eligible & solid
        distance[hit] = d
        owner[hit] = 1000 if i == -2 else i
    return distance, owner


def poses(r, count=31, branch=1):
    for z in np.linspace(4, 10+r.transition+9, count):
        yield [float(branch*r.offset*smooth((z-10)/r.transition)), 1.3, float(z)]


def clear_path(r):
    """Audit a 0.45m half-width, 1.8m high locomotion clearance capsule box.
    This is an explicit prototype bound, not a measured party collider.
    """
    violations = 0
    branches = [-1, 1] if r.exits == 2 else [-1, 0, 1]
    for z in planes(r):
        if z < 4 or z > 10+r.transition+9:
            continue
        for b in branches:
            c = b*r.offset*smooth((z-10)/r.transition)
            for dx in [-.45, 0, .45]:
                solid = (rib_occupancy(c+dx, np.array([.2, 1, 1.8]), z, r) if r.thickness and r.method not in ['loft','hybrid']
                         else occupancy(c+dx, np.array([.2, 1, 1.8]), z, r))
                if solid.any():
                    violations += 1
    return violations


def marker_visible(r, pose, branch, target_z):
    """Can an eye see a human-height point down a specified continuation?
    No deletion is allowed until the sibling's whole visible bound is hidden;
    these point tests are only rejection evidence, NOT a safe unload proof.
    """
    tx = branch*r.offset*smooth((target_z-10)/r.transition)
    delta = target_z-pose[2]
    if delta <= .05:
        return False
    # Gate on frustum: a ray outside the viewport is not visible.
    dx, dy = (tx-pose[0])/delta, (1.1-pose[1])/delta
    if abs(dx) > .8/.86 or not ((.48-1)/.86 <= dy <= .48/.86):
        return False
    nodes = planes(r)
    samples = [(z, z) for z in nodes] if not r.thickness else sorted(
        (z+v, z) for z in nodes for v in np.linspace(-r.thickness*.5, r.thickness*.5, math.ceil(r.thickness/.12)+1))
    for z, centre in samples:
        if pose[2]+.05 < z < target_z:
            t = (z-pose[2])/delta
            x, y = pose[0]+t*(tx-pose[0]), pose[1]+t*(1.1-pose[1])
            if (rib_occupancy(x, y, centre, r) if r.thickness and r.method not in ['loft','hybrid'] else occupancy(x, y, z, r)):
                return False
    return True


def evaluate(r, sample_count=25, size=(80, 50), references=None):
    leak = 0.0
    delay = []
    worst = None
    for index, pose in enumerate(poses(r, sample_count)):
        ref = references[index] if references is not None else cast(r, pose, size, True)[0]
        depth, _ = cast(r, pose, size)
        structural = np.isfinite(ref) & (ref < 55)
        missing = structural & ~np.isfinite(depth)
        rate = float(missing.sum()/max(1, structural.sum()))
        if worst is None or rate > leak:
            worst = pose
        leak = max(leak, rate)
        valid = structural & np.isfinite(depth)
        delay.append(float(np.percentile(np.maximum(depth[valid]-ref[valid], 0), 99)))
    after = [r.offset, 1.3, 10+r.transition+3]
    siblings = [-1] if r.exits == 2 else [-1, 0]
    visible_siblings = sum(marker_visible(r, after, b, after[2]+d)
                           for b in siblings for d in [5, 10, 20])
    intrusion = clear_path(r)
    separation = r.offset*(2 if r.exits == 2 else 1)-2*r.radius
    return dict(recipe=asdict(r), max_missing_fraction=leak,
                max_p99_extra_depth_m=max(delay), clearance_violations=intrusion,
                visible_sibling_markers=visible_siblings,
                settled_divider_width_m=separation,
                section_count=len(planes(r)), worst_pose=worst,
                # Structural screening tolerances, NOT approved art thresholds.
                screened=leak == 0 and intrusion == 0 and max(delay) <= 3.0 and separation >= .8-1e-8)


def adapt(base, max_rounds=6):
    """Offline set-cover over offending rays; never move sections at runtime.

    Missing coverage suggests concrete world-space section depths. Greedily
    choose depths that intercept most offending rays without entering ANY
    route aperture. This shares structure among camera poses and branches.
    Training and held-out camera grids are distinct; no art pass is inferred.
    """
    size = (96, 60)
    dx, dy = rays(size)
    training = list(poses(base, 37))
    refs = [cast(base, p, size, True)[0] for p in training]
    r = base
    history = []
    for iteration in range(max_rounds):
        bad_rays = []
        for pose, ref in zip(training, refs):
            depth, _ = cast(r, pose, size)
            valid = np.isfinite(ref) & (ref < 55)
            bad = valid & ((depth > ref+2.5) | ~np.isfinite(depth))
            if bad.any():
                n = int(bad.sum())
                bad_rays.append(np.column_stack([np.full(n, pose[0]), np.full(n, pose[1]),
                    np.full(n, pose[2]), dx[bad], dy[bad], ref[bad], depth[bad]]))
        if not bad_rays:
            break
        batch = np.concatenate(bad_rays)
        # Preserve source crossing depths; rounding a thin divider can erase it.
        candidates = np.unique(batch[:, 2]+batch[:, 5])
        if len(candidates) > 500:
            candidates = candidates[np.linspace(0, len(candidates)-1, 500).astype(int)]
        remaining = np.ones(len(batch), bool)
        added = []
        for _ in range(12):
            best = None
            best_hit = None
            score = 0
            for z in candidates:
                distance = z-batch[:, 2]
                eligible = remaining & (distance > .05) & (distance < batch[:, 6]) & (distance <= batch[:, 5]+2.5)
                if not eligible.any():
                    continue
                hit = eligible & occupancy(batch[:, 0]+batch[:, 3]*distance,
                    batch[:, 1]+batch[:, 4]*distance, float(z), r)
                value = int(hit.sum())
                if value > score:
                    score, best, best_hit = value, float(z), hit
            if best is None:
                break
            added.append(best)
            remaining[best_hit] = False
            if not remaining.any():
                break
        history.append(dict(round=iteration, offending_rays=len(batch),
                            residual_rays=int(remaining.sum()), added_depths=added))
        if not added:
            break
        r = Recipe(**(asdict(r) | {'depth_nodes': tuple(sorted(set(planes(r).tolist()+added)))}))
    return r, history


def render(r, pose, size=(640, 400)):
    depth, owner = cast(r, pose, size)
    dx, dy = rays(size)
    pixels = np.zeros((*depth.shape, 3), np.uint8)
    pixels[:] = [220, 35, 150]  # conspicuous unoccluded background, no fog
    finite = np.isfinite(depth)
    floor = finite & (owner < 0)
    xx = pose[0]+dx*np.where(finite, depth, 0)
    zz = pose[2]+np.where(finite, depth, 0)
    grid = (np.floor(xx)+np.floor(zz)).astype(int) % 2
    pixels[floor] = np.where(grid[floor, None] == 0, [49, 60, 64], [67, 77, 80])
    structural = owner >= 0
    palette = np.array([[136, 164, 182], [165, 185, 198], [103, 140, 163], [189, 197, 197]])
    pixels[structural] = palette[owner[structural] % len(palette)]
    return Image.fromarray(pixels)


def export_ribs(r, destination):
    """True low-poly short ribs. No longitudinal side walls or image stretching.
    The arched opening and its swept clearance are identical to the search.
    Each piece is extruded only over its explicit thickness interval.
    """
    from shapely import Polygon, unary_union, constrained_delaunay_triangles
    def aperture(lo, hi, width, height):
        def cap(c):
            theta = np.linspace(0, math.pi, 25)
            return Polygon([(c-width, -.02), (c+width, -.02)]+
                           [(c+width*math.cos(t), r.spring+(height-r.spring)*math.sin(t)) for t in theta])
        return unary_union([cap(lo), cap(hi)]).convex_hull
    result = []
    for index, z in enumerate(planes(r)):
        ranges, width = swept_section(z, r)
        free = unary_union([aperture(a,b,width,r.height) for a,b in ranges])
        outer = unary_union([aperture(a,b,width+r.band,r.height+r.band) for a,b in ranges])
        solid = outer.difference(free)
        vertices = []
        def triangle(a,b,c):
            vertices.extend([a,b,c])
        def p(xy, depth):
            return [float(xy[0]),float(xy[1]),-float(depth)]
        front, back = z-r.thickness*.5, z+r.thickness*.5
        for polygon in ([solid] if solid.geom_type=='Polygon' else solid.geoms):
            for tri in constrained_delaunay_triangles(polygon).geoms:
                a,b,c = list(tri.exterior.coords)[:3]
                triangle(p(a,front),p(b,front),p(c,front))
                triangle(p(c,back),p(b,back),p(a,back))
            for ring in [polygon.exterior]+list(polygon.interiors):
                points = list(ring.coords)
                for a,b in zip(points, points[1:]):
                    triangle(p(a,front),p(b,front),p(b,back))
                    triangle(p(a,front),p(b,back),p(a,back))
        result.append(dict(index=index,z=float(z),vertices=vertices))
    destination.write_text(json.dumps(result, separators=(',',':')),encoding='utf-8')
    return sum(len(x['vertices'])//3 for x in result)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True)
    parser.add_argument('--adaptive', action='store_true')
    parser.add_argument('--ribs', action='store_true')
    parser.add_argument('--oracle', choices=['2','3'])
    parser.add_argument('--oracle-spec')
    args = parser.parse_args()
    out = ROOT / args.out
    out.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    if args.oracle or args.oracle_spec:
        exits=int(args.oracle or 2)
        r=Recipe(**json.loads((ROOT/args.oracle_spec).read_text(encoding='utf-8'))['recipe']) if args.oracle_spec else Recipe(method='hybrid',exits=exits,offset=3.4 if exits==2 else 5.,step=1.25,thickness=.8,band=1.6)
        ps=list(poses(r,71));dx,dy=rays((80,50))
        reference=np.array([cast(r,p,(80,50),True)[0].ravel() for p in ps])
        np.savez_compressed(out/'oracle.npz',poses=ps,reference=reference,directions=np.column_stack([dx.ravel(),dy.ravel()]))
        (out/'recipe.json').write_text(json.dumps(asdict(r),indent=2),encoding='utf-8')
        return
    if args.ribs:
        findings=[]
        for exits, step, thickness in itertools.product([2,3], [2.,3.], [.8,1.5]):
            r=Recipe(exits=exits,offset=3.4 if exits==2 else 5.,transition=12.,
                     step=step,band=1.6,thickness=thickness)
            checked=evaluate(r,31,(96,60));findings.append(checked)
            print(f'RIB {exits} step={step} depth={thickness} {json.dumps({k:checked[k] for k in ["screened","max_missing_fraction","max_p99_extra_depth_m","visible_sibling_markers"]})}',flush=True)
        for exits in [2,3]:
            options=sorted([x for x in findings if x['recipe']['exits']==exits],
                key=lambda x:(x['max_missing_fraction'],x['max_p99_extra_depth_m'],x['section_count']))
            r=Recipe(**options[0]['recipe']);tag=f'{exits}way-ribs'
            checked=evaluate(r,103,(160,100));checked['held_out']=True;findings.append(checked)
            shots=[dict(name=f'{tag}-{i}',pose=p) for i,p in enumerate(poses(r,7))]
            spec=dict(recipe=asdict(r),planes=planes(r).tolist(),shots=shots,lens=1.,horizon=.48)
            spec['mesh_file']=tag+'-mesh.json'
            spec['triangles']=export_ribs(r,out/spec['mesh_file'])
            (out/f'{tag}.json').write_text(json.dumps(spec,indent=2),encoding='utf-8')
            print(f'RIB_REFINE {exits} {json.dumps({k:checked[k] for k in ["screened","max_missing_fraction","max_p99_extra_depth_m","section_count"]})}',flush=True)
        (out/'results.json').write_text(json.dumps(dict(seconds=time.monotonic()-started,
            status='short_solids_geometry_only',results=findings),indent=2),encoding='utf-8')
        return
    if args.adaptive:
        findings = []
        for exits in [2, 3]:
            # Required width is derived from settled corridor + divider space,
            # rather than inheriting the two-way offset for a three-way fork.
            offset = 3.4 if exits == 2 else 2*2.1+.8
            base = Recipe(exits=exits, offset=offset, transition=12.,
                          step=2.5, band=1.6, jitter=.2, seed=91)
            result, history = adapt(base)
            checked = evaluate(result, 103, (160, 100))
            checked['adaptation'] = history
            findings.append(checked)
            tag = f'{exits}way-adaptive'
            shots = []
            for i, pose in enumerate(poses(result, 7)):
                render(result, pose).save(out/f'{tag}-{i}.png')
                shots.append(dict(name=f'{tag}-{i}', pose=pose))
            (out/f'{tag}.json').write_text(json.dumps(dict(recipe=asdict(result),
                planes=planes(result).tolist(), shots=shots, lens=1., horizon=.48), indent=2), encoding='utf-8')
            print(f'ADAPT {exits} {json.dumps({k: checked[k] for k in ["screened", "max_missing_fraction", "max_p99_extra_depth_m", "section_count", "visible_sibling_markers"]})}', flush=True)
        (out/'results.json').write_text(json.dumps(dict(seconds=time.monotonic()-started,
            status='held_out_geometry_only', results=findings), indent=2), encoding='utf-8')
        return
    results = []
    # Cache the continuous volume once per topology/route, not per scatter rule.
    for exits, transition in itertools.product([2, 3], [8., 12., 16.]):
        base = Recipe(exits=exits, transition=transition)
        refs = [cast(base, pose, (80, 50), True)[0] for pose in poses(base, 25)]
        for method, step, band in itertools.product(['independent', 'union'], [1., 2., 3.], [.65, 1.3, 2.]):
            r = Recipe(method=method, step=step, band=band, exits=exits, transition=transition)
            results.append(evaluate(r, references=refs))
        print(f'SCREEN exits={exits} transition={transition} completed={len(results)}', flush=True)
    passed = sorted((x for x in results if x['screened']),
                    key=lambda x: (x['visible_sibling_markers'], x['section_count'], x['recipe']['band']))
    refinements = []
    # Different seed and nonperiodic depth spacing challenge the chosen bounds.
    for exits in [2, 3]:
        options = [x for x in passed if x['recipe']['exits'] == exits]
        if not options:
            continue
        winner = Recipe(**options[0]['recipe'])
        for jitter in [0., .25]:
            r = Recipe(**(asdict(winner) | {'jitter': jitter, 'seed': 91}))
            checked = evaluate(r, 101, (160, 100))
            refinements.append(checked)
            print(f'REFINE exits={exits} jitter={jitter} pass={checked["screened"]}', flush=True)
            tag = f'{exits}way-jitter{jitter}'
            shotposes = list(poses(r, 7))
            shots = []
            for i, pose in enumerate(shotposes):
                frame = render(r, pose)
                frame.save(out/f'{tag}-{i}.png')
                shots.append(dict(name=f'{tag}-{i}', pose=pose))
            (out/f'{tag}.json').write_text(json.dumps(dict(recipe=asdict(r),
                planes=planes(r).tolist(), shots=shots, lens=1., horizon=.48), indent=2), encoding='utf-8')
    report = dict(status='geometry_screen_only_not_art_accepted',
        seconds=time.monotonic()-started, candidates=len(results),
        coarse_screen_passes=len(passed), results=results, refinements=refinements,
        caveats=['No finished asset compatibility, terrain, combat or visual acceptance.',
                 '0.2m reference and sampled camera poses are not a continuous proof.',
                 'Sibling point visibility can reject unloading but cannot authorize it.',
                 '3m depth-delay tolerance is a lab rejection bound, not an art standard.'])
    (out/'results.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({k: report[k] for k in ['seconds', 'candidates', 'coarse_screen_passes']}, indent=2))


if __name__ == '__main__':
    main()
