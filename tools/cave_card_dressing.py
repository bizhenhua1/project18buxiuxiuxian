"""Sparse parented cave decorations, separate from enclosure coverage.

No lamp, light or decoration is stamped into the dense structure library.
Hanging source anchors refer to occupied pixels, not the canvas top border.
"""
import hashlib
import numpy as np
from PIL import Image
from cave_algorithm_lab import ROOT


def add_hanging(cards,route,seed=91):
    path='godot/assets/biomes/crystal/cards-study/stalactite-a.png'
    image=Image.open(ROOT/path);mask=np.asarray(image)[:,:,3]>=128
    ys,_=np.nonzero(mask);tip=(ys.max()+1)/image.height
    # The inspected connected cap is opaque here; assert source replacement
    # doesn't turn this authored attachment socket into empty background.
    cap_u=.5;cap_v=.20
    if not mask[int(cap_v*image.height),int(cap_u*image.width)]:
        raise ValueError('Hanging cap socket is transparent; replace/re-author socket')
    groups={}
    for card in cards:
        if card['role']!='crown':continue
        z=card['z']
        # Leave the currently tested compact fork entirely undressed.
        if not (1.5<z<route.start-2 or route.end+2<z<80):continue
        branch=card.get('branch',0)
        key=(branch,int(z//12))
        target=key[1]*12+5.0
        if key not in groups or abs(z-target)<abs(groups[key]['z']-target):groups[key]=card
    children=[];sources={}
    for key,parent in groups.items():
        value=int.from_bytes(hashlib.sha256(f'{seed}|hanging|{key}'.encode()).digest()[:8],'little')
        u=.34 if value%2 else .66
        if parent['asset'] not in sources:sources[parent['asset']]=np.asarray(Image.open(ROOT/parent['asset']))[:,:,3]>=128
        alpha=sources[parent['asset']];column=alpha[:,min(alpha.shape[1]-1,int(u*alpha.shape[1]))]
        rows=np.flatnonzero(column)
        if not len(rows):raise ValueError('Parent crown has no opaque attachment at selected column')
        lower=(rows[-1]+1)/alpha.shape[0]
        top=parent['y']+(1-lower)*parent['height']+.08
        # Maintain declared minimum tip height, don't squash the source.
        height=min(.72+.14*((value>>8)%100)/99,(top-2.10)/(tip-cap_v))
        if height<.4:continue
        width=height*image.width/image.height
        x=parent['x']+(u-.5)*parent['width'];z=parent['z']-.045
        y=top-(1-cap_v)*height
        initial_y=y
        # Seat a band of the cap, not just one pivot. The parent's sloping
        # lower silhouette can otherwise leave one side of the cap floating.
        contacts=[]
        for child_u in np.linspace(.15,.85,9):
            child_rows=np.flatnonzero(mask[:,min(image.width-1,int(child_u*image.width))])
            if not len(child_rows):continue
            child_top=child_rows[0]/image.height
            world_x=x+(child_u-.5)*width
            parent_u=.5+(world_x-parent['x'])/parent['width']
            if not 0<=parent_u<1:raise ValueError('Hanging cap extends outside parent source')
            parent_rows=np.flatnonzero(alpha[:,int(parent_u*alpha.shape[1])])
            if not len(parent_rows):raise ValueError('No parent material above hanging cap contact')
            parent_lower=parent['y']+(1-(parent_rows[-1]+1)/alpha.shape[0])*parent['height']
            y=max(y,parent_lower+.025-(1-child_top)*height)
            contacts.append([float(child_u),float(child_top),float(parent_u),float(parent_lower)])
        children.append(dict(role='ceiling-attachment',support_kind='ceiling_attachment',asset=path,
            x=x,z=z,y=y,width=width,height=height,uv=[0,0,1,1],
            owner_branch=parent.get('owner_branch'),branch=parent.get('branch',0),
            support_reference=[parent['x'],parent['z']],
            attachment=dict(parent_source=parent['asset'],parent_position=[parent['x'],parent['z']],
                            parent_uv=[u,lower],child_uv=[cap_u,cap_v],nominal_overlap_m=.08,
                            cap_contact_samples=contacts,seating_raise_m=y-initial_y),
            camera_independent=True))
    return sorted(cards+children,key=lambda c:c['z'])
