"""Thin expressive 2D formations as groups; never thin enclosure by accident.

This is an offline controlled comparison, not a universal production recipe.
Continuous fill and pre-bend gameplay space remain frozen. Surviving images
retain their original transforms, cutout sources and world identity. Children
are resolved to parents before selecting groups, then removed with the parent.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from cave_art_cards import add_ground_transitions
from cave_card_dressing import add_hanging
from cave_card_junction import Junction

PRIMARY = ('left', 'right', 'crown')


def parent_links(cards):
    """Resolve existing fixture children; reject ambiguous parents.

    Old fixture foot dressing has role/owner and a fixed depth offset instead
    of a durable parent ID. Resolve that provenance ONCE, not at runtime. The
    research fixture has zero-yaw ground cards; refuse to guess for tilted art.
    """
    by_role_depth = {}
    by_position = {}
    for i, card in enumerate(cards):
        by_role_depth.setdefault((card['role'], card.get('owner_branch'), round(card['z'], 5)), []).append(i)
        by_position.setdefault((card['asset'], round(card['x'], 5), round(card['z'], 5)), []).append(i)
    links = {}
    for i, child in enumerate(cards):
        if child['role'] == 'ground-transition':
            if abs(child.get('yaw', 0)) > 1e-8:
                raise ValueError('Legacy foot provenance cannot resolve a tilted parent')
            key = (child['parent_role'], child.get('owner_branch'), round(child['z'] + .12, 5))
            choices = [j for j in by_role_depth.get(key, [])
                       if abs(child['x'] - cards[j]['x']) <= cards[j]['width'] * .5]
        elif child.get('support_kind') == 'ceiling_attachment':
            attach = child['attachment']
            key = (attach['parent_source'], *[round(v, 5) for v in attach['parent_position']])
            choices = by_position.get(key, [])
        else:
            continue
        if len(choices) != 1:
            raise ValueError(f'Unresolved/ambiguous parent for card {i}: {choices}')
        links[i] = choices[0]
    return links


def compile_layout(source, cadence, start=51., seed=174, complete=False):
    if cadence <= 0:
        raise ValueError('Positive cadence required')
    cards = source['cards']
    links = parent_links(cards)
    eligible = {i for i, c in enumerate(cards) if c['role'] in PRIMARY and c['z'] >= start}
    keep = set(range(len(cards))) - eligible
    end = max(c['z'] for c in cards)
    groups = []
    new_primary = []
    route = Junction(source['route']['exits'])
    vars(route).update(source['route'])
    for branch in source['route']['branches']:
        rng = np.random.default_rng(seed + (branch + 1) * 7919)
        near = start
        index = 0
        previous_pair = None
        while near < end:
            far = min(end + .001, near + cadence * rng.uniform(.82, 1.18))
            # Two expressive directions per group, never another repeated
            # complete left+right+top frame. Deterministic world grouping.
            pair = int(rng.integers(3))
            if pair == previous_pair:
                pair = (pair + 1 + int(rng.integers(2))) % 3
            roles = (('left', 'crown'), ('right', 'crown'), ('left', 'right'))[pair]
            if rng.random() < .5:
                roles = tuple(reversed(roles))
            chosen = []
            authored = []
            for role, phase in zip(roles, (.25, .72)):
                target = near + (far - near) * phase
                if complete:
                    # Do not select again from an already sparse placement
                    # mask. That stacked two independent density filters and
                    # left entire 8m groups empty in the first ablation.
                    # Reuse inspected 2D source proportions/local placement,
                    # but let THIS grammar own the new primary positions.
                    pool = [i for i in eligible if cards[i]['role'] == role
                            and cards[i].get('branch', 0) == branch]
                    if not pool:
                        raise ValueError(f'No qualified template for branch {branch}, role {role}')
                    pool.sort(key=lambda i: (cards[i]['asset'], cards[i]['z']))
                    # Asset-library size must not advance the layout RNG and
                    # change later group intervals or expressive directions.
                    key = f'{seed}|{branch}|{index}|{role}|template'.encode()
                    pick = int.from_bytes(hashlib.sha256(key).digest()[:8], 'little')
                    template_index = pool[pick % len(pool)]
                    template = cards[template_index]
                    value = dict(template)
                    value['x'] += float(route.center(target, branch) - route.center(template['z'], branch))
                    value['z'] = target
                    value['study_group'] = f'{branch}:{index}'
                    new_primary.append(value)
                    authored.append(dict(role=role, z=target, template_index=template_index))
                    continue
                options = [i for i in eligible if cards[i].get('branch', 0) == branch
                           and cards[i]['role'] == role and near <= cards[i]['z'] < far]
                if not options:
                    continue
                picked = min(options, key=lambda i: (abs(cards[i]['z'] - target), i))
                keep.add(picked)
                chosen.append(picked)
            groups.append(dict(id=f'{branch}:{index}', branch=branch, interval_m=[near, far],
                               expressive_roles=list(roles), source_indices=chosen, authored=authored))
            near = far
            index += 1
            previous_pair = pair
    for child, parent in links.items():
        if parent not in keep:
            keep.discard(child)
    result = json.loads(json.dumps(source))
    source_hash = hashlib.sha256(json.dumps(cards, sort_keys=True).encode()).hexdigest()
    result['cards'] = []
    for i, card in enumerate(cards):
        if i not in keep:
            continue
        c = dict(card, study_id=f'{source_hash[:12]}:{i}')
        if i in links:
            c['study_parent_id'] = f'{source_hash[:12]}:{links[i]}'
        result['cards'].append(c)
    if new_primary:
        new_cards = add_ground_transitions(new_primary, seed=seed)
        if source.get('hanging'):
            new_cards = add_hanging(new_cards, route, seed=seed)
        children = parent_links(new_cards)
        for i, c in enumerate(new_cards):
            c['study_id'] = f'{source_hash[:12]}:new:{i}'
            if i in children:
                c['study_parent_id'] = f'{source_hash[:12]}:new:{children[i]}'
        result['cards'].extend(new_cards)
        result['cards'].sort(key=lambda c: c['z'])
    result['source_images'] = sorted({c['asset'] for c in result['cards']})
    result['formation_groups_trial'] = dict(
        cadence_m=cadence, start_m=start, seed=seed, groups=groups,
        source_cards_sha256=source_hash, before=len(cards), after=len(result['cards']),
        mode='authored_complete_groups' if complete else 'thin_existing_sparse_placements',
        authored_primary=len(new_primary),
        empty_groups=sum(not g['source_indices'] and not g['authored'] for g in groups),
        expressive_removed=len(eligible - keep), children_removed=sum(i not in keep for i in links),
        frozen_roles=['outer-left', 'outer-right', 'outer-crown', 'medial-rock'],
        criterion='two expressive directions per group; continuous fill remains unchanged',
        limitations=['research cadence, not production standard', 'removing art can expose gaps',
                     'fewer instances alone is not a quality or frame-rate proof'])
    result['status'] = '2d_formation_group_ablation_requires_visual_and_coverage_review'
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--spec', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--cadence', type=float, required=True)
    parser.add_argument('--complete', action='store_true', help='Group grammar owns primary placement; do not re-thin an already sparse mask')
    args = parser.parse_args()
    source = json.loads(Path(args.spec).read_text(encoding='utf-8'))
    result = compile_layout(source, args.cadence, complete=args.complete)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=False)
    (out / 'fork.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in result['formation_groups_trial'].items() if k != 'groups'}))
