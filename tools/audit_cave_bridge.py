"""Validate a local bitmap bridge after native terrain placement.

Joint coverage and scene contribution are deliberately separate. A supported
bridge hidden behind older fill cards must not be called a successful visual
experiment. This reads source alpha and native transforms; it edits no images.
"""
import argparse
import json
from pathlib import Path

import numpy as np

from compile_cave_bridge import audit_joints, covered, outline, visible, world_points


PARTS = ('bridge', 'left_support', 'right_support', 'cap')


def convert(instance):
    if abs(instance['yaw']) > 1e-6 or instance['source_uv'] != [0, 0, 1, 1]:
        raise ValueError('Bridge audit requires fixed frontal, uncropped pictures')
    x, y, nz = instance['position_m']
    return dict(asset=instance['source'].replace('res://', 'godot/'),
                x=x, y=y, z=-nz, width=instance['width_m'],
                height=instance['height_m'], role=instance['role'])


def audit(data, bridge_id):
    records = data['instances']
    matches = [r for r in records if r.get('study_bridge_id') == bridge_id]
    by_role = {r['study_bridge_role']: r for r in matches}
    if len(matches) != 4 or set(by_role) != set(PARTS):
        raise ValueError('Expected exactly four uniquely labelled bridge parts')
    parts = [convert(by_role[role]) for role in PARTS]
    # Before portal selection, branch visibility uses a different ray gate.
    # Do not pretend a post-selection filter certifies those earlier views.
    frames = [v for v in data['views'] if -v['camera_world_m'][2] > 51]
    if not frames:
        raise ValueError('No captured post-selection bridge approach')
    cameras = [[v['camera_world_m'][0], v['camera_world_m'][1],
                -v['camera_world_m'][2]] for v in frames]
    if any(abs(v['heading']) > 1e-6 or v['lens'] != 1 or v['horizon'] != .48
           or v['viewport'] != [1552, 830] for v in frames):
        raise ValueError('Joint projection needs this fixed study camera contract')
    joints = audit_joints(parts, cameras)
    uv = outline(parts[0]['asset'], True)
    lip = world_points(parts[0], uv[(uv[:, 0] >= .32) & (uv[:, 0] <= .68)])
    samples = []
    for frame, camera in zip(frames, cameras):
        in_frame = visible(lip, camera)
        blockers = []
        hidden = np.zeros(len(lip), dtype=bool)
        branch = 0 if frame['branch'] == 2 else frame['branch']
        for i, record in enumerate(records):
            if record.get('study_bridge_id') == bridge_id:
                continue
            if record.get('owner_branch') not in (None, branch):
                continue
            depth = -record['position_m'][2]
            if not camera[2] + .05 < depth < parts[0]['z']:
                continue
            hits = in_frame & covered(lip, convert(record), camera)
            if hits.any():
                hidden |= hits
                blockers.append(dict(instance=i, role=record['role'],
                                     source=record['source'], samples=int(hits.sum())))
        samples.append(dict(view=frame['index'], camera=camera,
                            lip_in_frame=int(in_frame.sum()),
                            lip_hidden_by_other_cards=int(hidden.sum()),
                            lip_exposed_in_scene=int((in_frame & ~hidden).sum()),
                            blockers=blockers))
    return dict(status='sampled_native_joints_supported' if joints['pass']
                else 'rejected_native_bridge_connections',
                bridge_id=bridge_id, joints=joints, scene_contribution=samples,
                art_accepted=False,
                limitations=['sampled contours, not continuous motion proof',
                             'post-selection fixed camera only',
                             'lip contribution measures occlusion, not beauty',
                             'does not certify overall tunnel enclosure or diversity'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True)
    parser.add_argument('--bridge-id', default='local-59-left')
    args = parser.parse_args()
    folder = Path(args.run)
    result = audit(json.loads((folder / 'manifest.json').read_text(encoding='utf-8')),
                   args.bridge_id)
    (folder / 'bridge-audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'scene_contribution'}))
    print(json.dumps([{k: v for k, v in row.items() if k not in ('blockers', 'camera')}
                      for row in result['scene_contribution']]))
    raise SystemExit(0 if result['joints']['pass'] else 2)
