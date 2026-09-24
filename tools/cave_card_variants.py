"""Offline source allocation from sampled co-visibility, not runtime randomness.

The graph estimates recognizable repetition using BASE source visibility.
New silhouettes require the normal post-assignment geometry/visual gates.
Residual conflict is evidence for library/assembly review, not art approval.
"""
import hashlib
from itertools import combinations
import numpy as np
from PIL import Image
from cave_algorithm_lab import ROOT
from cave_art_cards import raycast


def allocate(cards,shots,portal,pools,seed,threshold=.003):
    identities={i:f"{seed}|{c['role']}|{c.get('branch',0)}|{c['z']:.6f}" for i,c in enumerate(cards) if c['role'] in pools}
    hashes={i:int.from_bytes(hashlib.sha256(s.encode()).digest()[:8],'little') for i,s in identities.items()}
    families={i:tuple(pools[cards[i]['role']]) for i in identities}
    baseline={i:hashes[i]%len(families[i]) for i in identities}
    alphas={p:np.asarray(Image.open(ROOT/p).convert('RGBA'))[:,:,3] for p in {c['asset'] for c in cards}}
    edges={};peak={}
    for shot in shots:
        _,owner=raycast(cards,shot['pose'],(128,80),alphas,1552/830,shot.get('lens',1.),shot.get('horizon',.48),portal,shot.get('branch'))
        ids,counts=np.unique(owner[owner>=0],return_counts=True)
        groups={}
        for i,count in zip(ids,counts):
            i=int(i);area=float(count)/owner.size
            if i in families and area>=threshold:groups.setdefault(families[i],[]).append((i,area))
        for family,visible in groups.items():
            peak[family]=max(peak.get(family,0),len(visible))
            for (a,area_a),(b,area_b) in combinations(visible,2):
                key=(min(a,b),max(a,b));edges[key]=edges.get(key,0)+min(area_a,area_b)/len(shots)
    neighbours={i:[] for i in identities}
    for (a,b),weight in edges.items():
        neighbours[a].append((b,weight));neighbours[b].append((a,weight))
    order=sorted(identities,key=lambda i:(-sum(w for _,w in neighbours[i]),hashes[i]))
    colors={}
    for i in order:
        costs=[sum(w for j,w in neighbours[i] if colors.get(j)==c) for c in range(len(families[i]))]
        best=min(costs);ties=[c for c,v in enumerate(costs) if v==best]
        colors[i]=ties[hashes[i]%len(ties)]
    # Fixed bounded improvement; never reroll until an arbitrary score is green.
    for _ in range(4):
        changed=False
        for i in order:
            costs=[sum(w for j,w in neighbours[i] if colors[j]==c) for c in range(len(families[i]))]
            best=min(range(len(costs)),key=lambda c:costs[c])
            if costs[best]<costs[colors[i]]-1e-12:colors[i]=best;changed=True
        if not changed:break
    score=lambda coloring:sum(w for (a,b),w in edges.items() if coloring[a]==coloring[b])
    if score(colors)>score(baseline):colors=baseline
    report=dict(method='weighted_co_visibility_graph_bounded_greedy',poses=len(shots),
                visibility_threshold_fraction=threshold,threshold_scope='research salience observation, not an art pass threshold',
                graph_nodes=len(identities),conflict_edges=len(edges),single_source_conflict_weight=sum(edges.values()),
                hash_assignment_conflict_weight=score(baseline),selected_assignment_conflict_weight=score(colors),
                remaining_equal_source_edges=sum(colors[a]==colors[b] for a,b in edges),
                peak_visible_family_instances=[dict(sources=list(k),instances=v) for k,v in peak.items()],
                limitations=['based on original silhouettes; rerun actual assembled alpha tests',
                             'does not measure semantic distinctness, quietness, atmosphere or aesthetic quality'])
    return {i:families[i][colors[i]] for i in colors},report
