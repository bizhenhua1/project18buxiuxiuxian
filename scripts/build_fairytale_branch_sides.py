"""Trim transparent padding and author standalone side-prop placement metadata."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
for scene,height in [('alice_tea',300),('snow_mirror',315)]:
    source=ROOT/f'art/fairytales/corridor/raw/{scene}-branch-side.png'
    im=Image.open(source).convert('RGBA')
    box=im.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox()
    assert box and box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height, (scene,box,im.size)
    prop=im.crop(box)
    out=Image.new('RGBA',(prop.width+24,prop.height+24))
    out.paste(prop,(12,12))
    folder=ROOT/f'godot/assets/fairytales/{scene}'
    out.save(folder/'branch-side.png')
    (folder/'branch-side.json').write_text(json.dumps({'file':'branch-side.png','role':'side',
        'ground_anchor':[.5,(12+prop.height)/out.height], 'suggested_canvas_height':height*out.height/prop.height,
        'source_box':box,'image_size':out.size,'edge_touch':False},indent=2)+'\n')
    print(scene,'side ready',out.size)
