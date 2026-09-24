"""Read-only source inspection. No pixel editing or automatic art approval.

Generate measured alpha/contact data for authored roles before assembling.
The role definitions below are human interpretation, not inferred from alpha.
"""
import json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'godot/assets/biomes/crystal/cards-study'
ROLES={'shoulder-left-a':('left_shoulder','ground'),
       'shoulder-left-b':('left_shoulder','ground'),
       'shoulder-right-a':('right_shoulder','ground'),
       'shoulder-right-b':('right_shoulder','ground'),
       'crown-a':('concave_crown','upper_overlap'),
       'crown-b':('concave_crown','upper_overlap'),
       'crown-c':('concave_crown','upper_overlap'),
       'scree-a':('ground_transition','ground'),
       'medial-seam-a':('narrow_medial_seam','ground'),
       'backing-a':('outer_side_backing','ground'),
       'backing-b':('outer_side_backing','ground')}
ROLES['stalactite-a']=('hanging_formation','ceiling_attachment')
ROLES['backing-quiet-c']=('outer_side_backing','ground')
ROLES['crown-quiet-d']=('concave_crown','upper_overlap')
ROLES['backing-matte-d']=('outer_side_backing','ground')
ROLES['crown-matte-e']=('concave_crown','upper_overlap')
ROLES['backing-geology-e']=('outer_side_backing','ground')
ROLES['roof-coverage-a']=('overhead_coverage','upper_overlap')
ROLES['shoulder-left-covered-c']=('left_shoulder_continuation','ground')
ROLES['shoulder-right-covered-c']=('right_shoulder_continuation','ground')

def main():
    assets=[]
    for name,(role,support) in ROLES.items():
        path=FOLDER/(name+'.png');image=Image.open(path).convert('RGBA')
        array=np.asarray(image);mask=array[:,:,3]>=128;ys,xs=np.nonzero(mask)
        columns=[];upper=[]
        for u in np.linspace(.01,.99,65):
            x=min(image.width-1,int(u*image.width));occupied=np.flatnonzero(mask[:,x])
            if len(occupied):
                columns.append([float(u),float((occupied[-1]+1)/image.height)])
                upper.append([float(u),float(occupied[0]/image.height)])
        # Transparent canvas margins must not determine the contact band.
        # Measure the lowest tenth of the occupied silhouette instead.
        band_start=(ys.max()+1-.1*(ys.max()+1-ys.min()))/image.height
        contact=[p for p in columns if p[1]>=band_start] if support=='ground' else []
        asset=dict(id=name,role=role,support_kind=support,status='candidate_not_approved',
                   source=str(path.relative_to(ROOT)).replace('\\','/'),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                   prompt=name+'.prompt.txt',pixel_size=list(image.size),alpha_cutoff=.5,
                   opaque_bbox_px=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],
                   touches_canvas=bool(mask[0].any() or mask[-1].any() or mask[:,0].any() or mask[:,-1].any()),
                   effective_opaque_fraction=float(mask.mean()),
                   alpha_lower_outline_uv=columns,alpha_upper_outline_uv=upper,ground_bearing_candidates_uv=contact,
                   transforms=dict(uniform_scale_only=True,mirror_allowed=False,per_frame_billboard=False),
                   provenance='built_in_image_generation; original generated alpha retained',
                   limitations=['source count is not a diversity acceptance','view-angle envelope not accepted','assembly and full-route validation pending'])
        if role=='concave_crown':
            bottom=lambda u:max(y for x,y in columns if abs(x-u)<.04)
            asset['center_lower_edge_higher_than_both_shoulders']=bool(bottom(.5)<min(bottom(.15),bottom(.85)))
        if role=='overhead_coverage':
            asset['continuation_edges']=['top','left','right']
            asset['continuation_contract']='Clipped edges must be outside the camera or behind other authored art in native motion checks; opaque coverage is not proof of hidden rectangle edges.'
        if role in ('left_shoulder_continuation','right_shoulder_continuation'):
            asset['continuation_edges']=['top']
            asset['continuation_contract']='Planted foot is rigid; the cropped upper edge must continue behind overhead art in the whole camera domain.'
        assets.append(asset)
    output=FOLDER/'assets.json'
    output.write_text(json.dumps(dict(status='measured_candidates_not_art_acceptance',assets=assets),ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps([dict(id=a['id'],pixels=a['pixel_size'],touches_canvas=a['touches_canvas'],crown=a.get('center_lower_edge_higher_than_both_shoulders')) for a in assets]))

if __name__=='__main__':main()
