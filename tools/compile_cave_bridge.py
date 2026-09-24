"""Fit one 2D bridge assembly from measured opaque contours.

Side supports conceal the two outer ends; a foreground cap conceals the upper
rim. The aperture remains visible. This is a local research compiler, not a
general tunnel producer. Every image keeps its source aspect and fixed plane.
"""
import argparse
import copy
import json
from functools import lru_cache
from pathlib import Path
import numpy as np
from PIL import Image
from cave_card_junction import Junction
from cave_art_cards import add_ground_transitions
from compile_cave_formation_groups import parent_links

ROOT = Path(__file__).resolve().parents[1]


@lru_cache(None)
def pixels(path):
    return np.asarray(Image.open(ROOT / path).convert('RGBA'))[:, :, 3] >= 128


def outline(path, lower=False):
    mask = pixels(path)
    rows = []
    for u in np.linspace(.035, .965, 151):
        occupied = np.flatnonzero(mask[:, min(mask.shape[1] - 1, int(u * mask.shape[1]))])
        if len(occupied):
            v = (occupied[-1] + .5 if lower else occupied[0] + .5) / mask.shape[0]
            rows.append([u, v])
    return np.asarray(rows)


def world_points(card, uv):
    return np.c_[card['x'] + (uv[:, 0] - .5) * card['width'],
                 card['y'] + (1 - uv[:, 1]) * card['height'],
                 np.full(len(uv), card['z'])]


def covered(points, card, camera):
    cx, cy, cz = camera
    if card['z'] <= cz + .05:
        return np.zeros(len(points), dtype=bool)
    t = (card['z'] - cz) / (points[:, 2] - cz)
    x = cx + (points[:, 0] - cx) * t
    y = cy + (points[:, 1] - cy) * t
    u = .5 + (x - card['x']) / card['width']
    v = 1 - (y - card['y']) / card['height']
    valid = (t < 1) & (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
    alpha = pixels(card['asset'])
    result = np.zeros(len(points), dtype=bool)
    result[valid] = alpha[(v[valid] * alpha.shape[0]).astype(int), (u[valid] * alpha.shape[1]).astype(int)]
    return result


def visible(points, camera, lens=1., horizon=.48):
    p = points - np.asarray(camera)
    focal = .86 * lens
    with np.errstate(divide='ignore', invalid='ignore'):
        sx = .5 + p[:, 0] / p[:, 2] * focal / (1552 / 830)
        sy = horizon - p[:, 1] / p[:, 2] * focal
    return (p[:, 2] > .05) & (sx >= 0) & (sx <= 1) & (sy >= 0) & (sy <= 1)


def audit_joints(parts, cameras):
    crown, left, right, cap = parts
    top_uv = outline(crown['asset'])
    bottom_uv = outline(crown['asset'], True)
    # Terminal side contour samples include the upper and lower arcs. These
    # are authored support regions, not automatically inferred load mechanics.
    ends = np.vstack([a[(a[:, 0] < .17) | (a[:, 0] > .83)] for a in [top_uv, bottom_uv]])
    top = top_uv[(top_uv[:, 0] >= .17) & (top_uv[:, 0] <= .83)]
    lip = bottom_uv[(bottom_uv[:, 0] >= .32) & (bottom_uv[:, 0] <= .68)]
    end_p, top_p, lip_p = [world_points(crown, a) for a in [ends, top, lip]]
    report = dict(visible_end_samples=0, exposed_end_samples=0, visible_top_samples=0,
                  exposed_top_samples=0, visible_lip_samples=0, hidden_lip_samples=0)
    for camera in cameras:
        for name, points, occluders in [('end', end_p, [left, right, cap]), ('top', top_p, [left, right, cap])]:
            seen = visible(points, camera)
            concealed = np.zeros(len(points), dtype=bool)
            for support in occluders:
                concealed |= covered(points, support, camera)
            report['visible_' + name + '_samples'] += int(seen.sum())
            report['exposed_' + name + '_samples'] += int((seen & ~concealed).sum())
        seen = visible(lip_p, camera)
        hidden = covered(lip_p, cap, camera) | covered(lip_p, left, camera) | covered(lip_p, right, camera)
        report['visible_lip_samples'] += int(seen.sum())
        report['hidden_lip_samples'] += int((seen & hidden).sum())
    report['pass'] = (report['visible_end_samples'] > 0 and report['visible_top_samples'] > 0
                      and report['visible_lip_samples'] > 0 and not report['exposed_end_samples']
                      and not report['exposed_top_samples'] and not report['hidden_lip_samples'])
    return report


def compile_layout(source, z=59., branch=-1):
    route = Junction(source['route']['exits'])
    vars(route).update(source['route'])
    cards = source['cards']
    def template(role):
        choices = [c for c in cards if c['role'] == role and c.get('branch', 0) == branch and c['z'] > 51]
        if not choices:
            raise ValueError('Missing inspected assembly role: ' + role)
        return min(choices, key=lambda c: abs(c['z'] - z))
    original = template('crown')
    center = float(route.center(z, branch))
    left, right = [copy.deepcopy(template(role)) for role in ('outer-left', 'outer-right')]
    for support in [left, right]:
        support['x'] += center - float(route.center(support['z'], branch))
        support['z'] = z - .06
        support['bridge_support'] = True
    bottom = outline(original['asset'], True)
    v_center = float(np.interp(.5, bottom[:, 0], bottom[:, 1]))
    clearance = original['y'] + (1 - v_center) * original['height']
    cap_path = 'godot/assets/biomes/crystal/cards-study/crown-matte-e.png'
    cap_bottom = outline(cap_path, True)
    # Candidate distances include near-transit and oblique rays caused by the
    # permitted lateral camera rail. No free camera turn or zoom is introduced.
    cameras = [[float(route.center(cz + 1.6, branch)), eye, float(cz)]
               for cz in np.linspace(z - 14, z + .2, 72) for eye in [1.15, 1.3, 1.45]]
    trials = []
    accepted = None
    for scale in np.linspace(1., 1.7, 29):
        crown = dict(original, x=center, z=z, width=original['width'] * float(scale),
                     height=original['height'] * float(scale))
        crown['y'] = clearance - (1 - v_center) * crown['height']
        height = max(2.25, crown['height'] * 1.15)
        shape = pixels(cap_path)
        cap = dict(role='outer-crown', asset=cap_path, branch=branch, owner_branch=None,
                   x=center, z=z - .12, width=height * shape.shape[1] / shape.shape[0],
                   height=height, uv=[0, 0, 1, 1], bridge_cap=True,
                   support_reference=[center, z])
        uv = outline(crown['asset'])
        uv = uv[(uv[:, 0] > .17) & (uv[:, 0] < .83)]
        points = world_points(crown, uv)
        bounds = []
        for camera in cameras:
            seen = visible(points, camera)
            if not seen.any() or cap['z'] <= camera[2] + .05:
                continue
            p = points[seen]
            t = (cap['z'] - camera[2]) / (p[:, 2] - camera[2])
            projected_x = camera[0] + (p[:, 0] - camera[0]) * t
            projected_y = camera[1] + (p[:, 1] - camera[1]) * t
            cap_u = .5 + (projected_x - center) / cap['width']
            # Solve along the actual camera ray at the cap's foreground
            # depth. A same-plane overlap missed seven top samples: the
            # foreground cap moves relative to the upper rim in perspective.
            columns = np.clip((cap_u * shape.shape[1]).astype(int), 0, shape.shape[1] - 1)
            lower = np.array([(np.flatnonzero(shape[:, col])[-1] + .5) / shape.shape[0]
                              if shape[:, col].any() else 1. for col in columns])
            bounds.extend((projected_y - (1 - lower) * height).tolist())
        cap['y'] = float(min(bounds) - .02)
        parts = [crown, left, right, cap]
        audit = audit_joints(parts, cameras)
        trials.append(dict(scale=float(scale), audit=audit))
        if audit['pass']:
            accepted = copy.deepcopy(parts)
            break
    if accepted is None:
        raise ValueError('No bounded bridge fit: ' + json.dumps(trials[-1]))
    # Isolate this group instead of placing a whole new tunnel. Remove only
    # the competing primary components and their own decorative children.
    links = parent_links(cards)
    remove = {i for i, c in enumerate(cards) if c['role'] in ('left', 'right', 'crown')
              and c.get('branch', 0) == branch and z - 6 < c['z'] < z + 6}
    remove.update(i for i, parent in links.items() if parent in remove)
    result = copy.deepcopy(source)
    result['cards'] = [c for i, c in enumerate(result['cards']) if i not in remove]
    for role, part in zip(['bridge', 'left_support', 'right_support', 'cap'], accepted):
        part['study_bridge_role'] = role
        part['study_bridge_id'] = 'local-59-left'
    result['cards'].extend(add_ground_transitions(accepted, seed=705))
    result['cards'].sort(key=lambda c: c['z'])
    result['source_images'] = sorted({c['asset'] for c in result['cards']})
    result['visual_sweep_targets'] = [4., 6., 51., 53., 55., 56., 57., 58., 59., 60., 62., 65.]
    result['bridge_trial'] = dict(z=z, branch=branch, clearance_m=clearance,
        trials=trials, camera_count=len(cameras), accepted_scale=trials[-1]['scale'],
        removed_primary_and_children=len(remove),
        scope='one local 2D assembly, flat compiler support; native terrain recheck required')
    result['status'] = 'local_bridge_assembly_requires_native_art_review'
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--spec', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    result = compile_layout(json.loads(Path(args.spec).read_text(encoding='utf-8')))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=False)
    (out / 'fork.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result['bridge_trial']))
