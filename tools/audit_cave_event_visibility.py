"""Check fixed 2D scenery against the actual event presentation envelopes.

The travelling leader's root cylinder cannot certify a battle. This measures
all declared unit/prop silhouettes along the real camera's rays. Model proxies
are conservative layout guides, NOT exact skinned-mesh visibility measurements.
No scene pixels are edited. Source images are sampled only for alpha.
"""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image
from cave_art_cards import raycast

ROOT = Path(__file__).resolve().parents[1]


def load_cards(data):
    cards = []
    alphas = {}
    for r in data['instances']:
        key = r['source']
        if key not in alphas:
            alphas[key] = np.asarray(Image.open(ROOT/'godot'/key.removeprefix('res://')).convert('RGBA'))[:, :, 3]
        x, y, nz = r['position_m']
        cards.append(dict(asset=key, x=x, y=y, z=-nz, width=r['width_m'],
                          height=r['height_m'], yaw=r['yaw'], uv=r['source_uv'],
                          owner_branch=r.get('owner_branch'), role=r['role']))
    return cards, alphas


def body_rays(body, camera, mask, samples=48):
    # Pixel-centred sampling avoids treating the transparent canvas as body.
    u, v = np.meshgrid((np.arange(samples)+.5)/samples, (np.arange(samples)+.5)/samples)
    px = ((1-u if body.get('flip') else u)*mask.shape[1]).astype(int)
    py = (v*mask.shape[0]).astype(int)
    opaque = mask[py, px] >= 128
    x, y, z = body['position_m']
    depth = z-camera[2]
    if depth <= .05:
        raise ValueError('Event body is at/behind the camera')
    dx = (x+(u-.5)*body['width_m']-camera[0])/depth
    dy = (y+(1-v)*body['height_m']-camera[1])/depth
    return dx, dy, opaque, depth


def audit(folder, max_occlusion=.05):
    data = json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    if not data.get('event_frames'):
        raise ValueError('No battle presentation frames: do not substitute travel checks')
    cards, alphas = load_cards(data)
    branch = data['branch']
    cards = [c for c in cards if c.get('owner_branch') in (None, branch)]
    rows = []
    for frame in data['event_frames']:
        camera = frame['camera_m']
        for body in frame['bodies']:
            if body.get('hidden'):continue
            mask = np.asarray(Image.open(folder/body['mask']).convert('RGBA'))[:, :, 3]
            # Live model proxies can deliberately supply a transparent sprite.
            # Reserve their full DECLARED rectangle, never silently skip them
            # or call an empty image proof that the unit is unobstructed.
            rectangular_proxy = not bool((mask >= 128).any())
            if rectangular_proxy:mask = np.full((2, 2), 255, dtype=np.uint8)
            dx, dy, opaque, depth = body_rays(body, camera, mask)
            count = int(opaque.sum())
            if not count:raise ValueError('Empty event body mask')
            distance, owner = raycast(cards, camera, dx.shape, alphas, ray_slopes=(dx, dy))
            blocked = opaque & (owner >= 0) & (distance < depth-.025)
            values, counts = np.unique(owner[blocked], return_counts=True)
            hits = [dict(role=cards[int(i)]['role'], source=cards[int(i)]['asset'],
                         card_index=int(i), samples=int(n)) for i, n in zip(values, counts)]
            rows.append(dict(tick=frame['tick'], body_id=body['id'],
                             rectangular_proxy=rectangular_proxy,
                             opaque_samples=count, blocked_samples=int(blocked.sum()),
                             occluded_fraction=float(blocked.sum()/count), blockers=hits))
    failures = [r for r in rows if r['occluded_fraction'] > max_occlusion]
    report = dict(status='rejected_event_envelope_occluded' if failures else 'sampled_event_envelope_clear_not_art_acceptance',
                  scope='declared sprite silhouettes incl model proxies; exact animated model visibility and all skill excursions unmeasured',
                  max_occlusion=max_occlusion, threshold_basis='research allowance for incidental edge dressing; not a product-wide standard',
                  bodies_checked=len(rows), rejected_bodies=len(failures), measurements=rows)
    (folder/'event-visibility.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='measurements'}))
    return 2 if failures else 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser();parser.add_argument('--run', required=True)
    args = parser.parse_args()
    raise SystemExit(audit(Path(args.run)))
