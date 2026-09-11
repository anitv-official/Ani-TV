from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter

source = Path('/home/ubuntu/Ani-TV/docs/screenshots')
target = Path('/home/ubuntu/Ani-TV/website/assets/screenshots')
target.mkdir(parents=True, exist_ok=True)

for path in sorted(source.glob('screen-*.png')):
    image = Image.open(path).convert('RGB')
    image = ImageEnhance.Color(image).enhance(1.22)
    image = ImageEnhance.Contrast(image).enhance(1.08)
    image = ImageEnhance.Sharpness(image).enhance(1.10)
    image.save(target / path.name, optimize=True)
    print(f'{path.name}: {image.size} -> {target / path.name}')
