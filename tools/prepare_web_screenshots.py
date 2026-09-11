from pathlib import Path
from PIL import Image

source = Path('/home/ubuntu/Ani-TV/website/assets/screenshots')
target = Path('/home/ubuntu/Ani-TV/website/assets/web-screenshots')
target.mkdir(parents=True, exist_ok=True)
for path in sorted(source.glob('screen-*.png')):
    image = Image.open(path).convert('RGB')
    image.thumbnail((360, 520), Image.Resampling.LANCZOS)
    out = target / f'{path.stem}.webp'
    image.save(out, 'WEBP', quality=82, method=6)
    print(f'{out.name}: {image.size} {out.stat().st_size} bytes')
