from pathlib import Path
import re

a4 = Path('/tmp/a4.html').read_text(errors='ignore')
a3 = Path('/tmp/a3episode.html').read_text(errors='ignore')
pattern = re.compile(r'''<div[^>]+class=["'][^"']*anime-card-themex[^"']*["'][\s\S]{0,2600}?data-image=["']([^"']+)["'][\s\S]{0,700}?<a[^>]+href=["']([^"']*/anime/[^"']+)["'][^>]*(?:aria-label=["']([^"']+)["']|>[\s\S]*?<h3[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)</a>)''', re.I)
items = [(m.group(2), m.group(3) or m.group(4)) for m in pattern.finditer(a4)]
print('anime4up_cards', len(items), items[:3])
embed = re.findall(r'''(?:https?://anime3rb\.com)?/embed/[A-Za-z0-9-]+(?:\?[^"'\s<]+)?''', a3, re.I)
print('anime3rb_embeds', len(embed), embed[:3])
assert len(items) >= 10
assert any('/anime/' in url for url, _ in items)
assert embed
