"""Slice generated RGBA sheets at measured empty gutters; never cut painted pixels."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art/fairytales/corridor'


def cuts(mask, axis):
    projection = mask.any(axis=1-axis)
    length = len(projection)
    result = [0]
    for i in (1, 2):
        ideal = length*i/3
        candidates = np.flatnonzero(~projection)
        candidates = candidates[abs(candidates-ideal) < length*.10]
        if not len(candidates):
            raise ValueError(f'No empty gutter near {i}/3, manual review required')
        runs = np.split(candidates, np.flatnonzero(np.diff(candidates)>1)+1)
        best = min(runs, key=lambda r: abs(float(r.mean())-ideal)-min(len(r),30)*.5)
        result.append(int(best[len(best)//2]))
    return result+[length]


def main():
    supplement = json.loads((ART/'dressing-supplement-specs.json').read_text(encoding='utf-8'))
    specs = json.loads((ART/'dressing-specs.json').read_text(encoding='utf-8'))
    for scene, entries in supplement.items():
        source = ART/'raw'/f'{scene}-dressing.png'
        im = Image.open(source).convert('RGBA')
        rgba = np.array(im)
        # Discard only near-transparent generation residue, retaining antialiased art.
        rgba[rgba[:, :, 3] < 8] = 0
        mask = rgba[:, :, 3] > 0
        yc = cuts(mask, 0)
        accepted = []
        for row in range(3):
            y0, y1 = yc[row:row+2]
            xc = cuts(mask[y0:y1], 1)
            for col in range(3):
                x0, x1 = xc[col:col+2]
                part = Image.fromarray(rgba[y0:y1, x0:x1])
                bbox = part.getchannel('A').getbbox()
                assert bbox, (scene,row,col)
                # Cut lines themselves are empty; padding is restored after trimming.
                assert not mask[y0:y1,x0].any() and not mask[y0,x0:x1].any(), (scene,row,col)
                part = part.crop(bbox)
                padded = Image.new('RGBA', (part.width+16, part.height+16))
                padded.paste(part, (8,8))
                index = row*3+col
                key = entries[index][0]
                target = ROOT/f'godot/assets/fairytales/{scene}/dressing/{key}/prop.png'
                target.parent.mkdir(parents=True, exist_ok=True)
                padded.save(target)
                accepted.append({'index':index,'label':key,'grid':[row,col],'source_box':[x0,y0,x1,y1],
                    'crop_bbox':list(bbox),'output_size':list(padded.size),'edge_touch':False,'status':'accepted',
                    'image':target.relative_to(ROOT).as_posix()})
        (ART/f'{scene}-props.json').write_text(json.dumps({'input':source.relative_to(ROOT).as_posix(),
            'method':'measured transparent gutters; original art retained','accepted':accepted,'rejected':[]},indent=2)+'\n')
        specs[scene] = entries
        print(scene, len(accepted), 'complete props; no edge cut')
    (ART/'dressing-specs.json').write_text(json.dumps(specs,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__':
    main()
