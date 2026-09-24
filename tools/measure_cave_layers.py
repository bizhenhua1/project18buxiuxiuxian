"""Attribute sampled scene pixels to authored 2D layers, after native placement.

This is a diagnosis of the captured camera, not an art scoring function. It
helps distinguish 'more primary assets' from primary assets actually visible.
Sky, flat ground and actors are excluded from source-area denominators.
"""
import argparse
import json
from collections import Counter
from pathlib import Path

import numpy as np

from audit_cave_event_visibility import load_cards
from cave_art_cards import raycast


def measure(data, indices, width=256):
    cards, alphas = load_cards(data)
    rows = []
    for view in data['views']:
        if view['index'] not in indices:
            continue
        camera = list(view['camera_world_m'])
        camera[2] = -camera[2]
        if camera[2] <= 25 or abs(view['heading']) > 1e-6:
            raise ValueError('Attribution only supports selected-branch forward cameras')
        branch = 0 if view['branch'] == 2 else view['branch']
        selected = [c for c in cards if c.get('owner_branch') in (None, branch)
                    and c['z'] > camera[2] + .05]
        aspect = view['viewport'][0] / view['viewport'][1]
        shape = (round(width/aspect), width)
        _, owners = raycast(selected, camera, shape, alphas, aspect=aspect,
                            lens=view['lens'], horizon=view['horizon'])
        ids, counts = np.unique(owners[owners >= 0], return_counts=True)
        roles, sources = Counter(), Counter()
        visible = []
        total = int(counts.sum())
        for i, count in zip(ids, counts):
            card = selected[int(i)]
            roles[card['role']] += int(count)
            sources[card['asset']] += int(count)
            visible.append(dict(role=card['role'], source=card['asset'],
                                depth_m=card['z']-camera[2], samples=int(count)))
        rows.append(dict(view=view['index'], camera=camera, sample_size=shape,
                         scenery_samples=total,
                         roles={k:dict(samples=n, area_fraction=n/max(total,1))
                                for k,n in roles.most_common()},
                         sources={k:dict(samples=n, area_fraction=n/max(total,1))
                                  for k,n in sources.most_common()},
                         visible_layers=sorted(visible,key=lambda v:-v['samples'])))
    if len(rows) != len(set(indices)):
        raise ValueError('Some requested views are missing')
    return dict(status='diagnostic_not_visual_acceptance', views=rows,
                limitations=['flat floor occlusion approximation',
                             'no actor, fog, light or texture contrast weighting',
                             'sampled pixels do not prove temporal coverage'])


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--run',required=True)
    parser.add_argument('--views',type=int,nargs='+',required=True)
    args=parser.parse_args()
    folder=Path(args.run)
    data=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    result=measure(data,args.views)
    (folder/'layer-attribution.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps([dict(view=v['view'],roles=v['roles']) for v in result['views']]))
