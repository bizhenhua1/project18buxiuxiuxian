"""Read-only video evidence extraction; no game or source-video modifications.

Example: python scripts/analyze_scene_reference_video.py --start 210 --end 223 --name cave-entry
Frames preserve source pixels. Contact sheets are labeled reduced previews only.
"""
import argparse
import json
from pathlib import Path

import cv2
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--start', type=float, required=True)
    parser.add_argument('--end', type=float, required=True)
    parser.add_argument('--rate', type=float, default=1)
    parser.add_argument('--name', required=True)
    args = parser.parse_args()
    assert args.end > args.start >= 0 and 0 < args.rate <= 30
    assert args.name.replace('-', '').replace('_', '').isalnum()
    out = ROOT / 'scene-production/references/video-study' / args.name
    out.mkdir(parents=True, exist_ok=False)
    cap = cv2.VideoCapture(str(ROOT / 'tmp/场景参考.mp4'))
    fps = cap.get(cv2.CAP_PROP_FPS)
    first = round(args.start * fps)
    last = round(args.end * fps)
    wanted = {round((args.start + i / args.rate) * fps)
              for i in range(int((args.end - args.start) * args.rate) + 1)}
    cap.set(cv2.CAP_PROP_POS_FRAMES, first)
    frames = []
    manifest = []
    for index in range(first, last + 1):
        ok, bgr = cap.read()
        if not ok:
            break
        if index not in wanted:
            continue
        sec = index / fps
        image = Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
        filename = f'{index:06d}.png'
        image.save(out / filename)
        frames.append((sec, image))
        manifest.append({'frame': index, 'seconds': sec, 'image': filename})
    cap.release()
    font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 18)
    for page in range((len(frames) + 15) // 16):
        sheet = Image.new('RGB', (1704, 1072), (22, 24, 28))
        draw = ImageDraw.Draw(sheet)
        for i, (sec, image) in enumerate(frames[page * 16:page * 16 + 16]):
            x, y = i % 4 * 426, i // 4 * 268
            sheet.paste(image.resize((426, 240)), (x, y + 28))
            milliseconds = round(sec * 1000)
            minutes, remainder = divmod(milliseconds, 60000)
            draw.text((x + 6, y + 4), f'{minutes:02d}:{remainder / 1000:06.3f}', font=font, fill='white')
        sheet.save(out / f'sheet-{page + 1}.jpg', quality=94)
    (out / 'frames.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'{args.name}: {len(frames)} source frames extracted')


if __name__ == '__main__':
    main()
