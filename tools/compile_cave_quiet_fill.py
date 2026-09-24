"""Controlled artwork ablation: unchanged routes, card transforms and density.

Replace only matching background sources, never paint, stretch or manufacture
variants in code. Generated alpha is measured again; source edit is not assumed
to preserve silhouette. Native capture must be repeated before adoption.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = 'godot/assets/biomes/crystal/cards-study/'
REPLACEMENTS = {'backing-b.png': 'backing-quiet-c.png', 'crown-c.png': 'crown-quiet-d.png'}


def compile_layout(source, all_fill=False, borderless=False, secondary=False):
    spec = json.loads(json.dumps(source))
    report = []
    replacements = dict(REPLACEMENTS)
    if all_fill:
        replacements.update({'backing-a.png': 'backing-quiet-c.png', 'crown-b.png': 'crown-quiet-d.png'})
    if borderless:
        replacements = {'backing-quiet-c.png': 'backing-matte-d.png', 'crown-quiet-d.png': 'crown-matte-e.png'}
    for old, new in replacements.items():
        before = np.asarray(Image.open(ROOT / ART / old).convert('RGBA'))
        after = np.asarray(Image.open(ROOT / ART / new).convert('RGBA'))
        if before.shape != after.shape:
            raise ValueError('Paint-only comparison requires identical canvas dimensions')
        a, b = before[:, :, 3] >= 128, after[:, :, 3] >= 128
        count = 0
        for card in spec['cards']:
            if card['asset'] != ART + old:
                continue
            # Infrequent primary crowns retain their authored drawing and
            # attachment contour. Only the continuous fill layer changes.
            if card['role'] not in ('outer-left', 'outer-right', 'outer-crown'):
                continue
            card['asset'] = ART + new
            count += 1
        report.append(dict(source=ART + old, replacement=ART + new, instances=count,
            sha256=hashlib.sha256((ROOT / ART / new).read_bytes()).hexdigest(),
            opaque_pixels_added=int((b & ~a).sum()), opaque_pixels_lost=int((a & ~b).sum()),
            changed_alpha_pixels=int((before[:, :, 3] != after[:, :, 3]).sum()),
            source_dimensions=[before.shape[1], before.shape[0]]))
    secondary_records = []
    if secondary:
        if not borderless or 'formation_groups_trial' not in source:
            raise ValueError('Secondary layer requires borderless fill and an explicit formation grouping')
        for group in source['formation_groups_trial']['groups']:
            missing = (set(('left', 'right', 'crown')) - set(group['expressive_roles'])).pop()
            role = 'outer-' + missing
            lo, hi = group['interval_m']
            candidates = [i for i, c in enumerate(spec['cards']) if c['role'] == role
                          and c.get('branch', 0) == group['branch'] and lo <= c['z'] < hi]
            if not candidates:
                continue
            index = min(candidates, key=lambda i: (abs(spec['cards'][i]['z'] - (lo + hi) * .5), i))
            # Restore one subordinate outlined silhouette in the direction
            # missing from the expressive pair. No new instances or transform.
            spec['cards'][index]['asset'] = source['cards'][index]['asset']
            secondary_records.append(dict(group=group['id'], role=role, card=index))
    spec['status'] = 'quiet_fill_source_comparison_requires_native_visual_review'
    spec['source_images'] = sorted({c['asset'] for c in spec['cards']})
    spec['quiet_fill_trial'] = dict(replacements=report, card_count_before=len(source['cards']),
        card_count_after=len(spec['cards']), transforms_unchanged=True,
        mode='borderless_fill' if borderless else 'all_continuous_fill' if all_fill else 'matching_source_only',
        secondary_silhouettes=secondary_records,
        limitations=['not a new assembly algorithm', 'new alpha requires rechecking',
                     'no art acceptance from source statistics'])
    return spec


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--spec', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--all-fill', action='store_true', help='Compare replacing all continuous fill, while retaining primary shoulders/crowns')
    parser.add_argument('--borderless', action='store_true', help='Compare independently generated borderless fill against quiet outlined fill')
    parser.add_argument('--secondary', action='store_true', help='Restore one secondary outlined silhouette per formation group')
    args = parser.parse_args()
    out = Path(args.out)
    result = compile_layout(json.loads(Path(args.spec).read_text(encoding='utf-8')), args.all_fill, args.borderless, args.secondary)
    out.mkdir(parents=True, exist_ok=False)
    (out / 'fork.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result['quiet_fill_trial']))
