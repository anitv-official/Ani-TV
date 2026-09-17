const BASE = 'https://wecima.cx';
const headers = { 'User-Agent': 'AniTV-WecimaBridge/1.0 (licensed integration)', Accept: 'text/html,application/xhtml+xml' };
const cache = new Map();
function decode(v = '') { return v.replace(/&(?:amp|lt|gt|quot|#039|nbsp|#\d+);/g, m => ({'&amp;':'&','&lt;':'<','&gt;':'>','&quot;':'"','&#039;':"'",'&nbsp;':' '}[m] || String.fromCodePoint(Number(m.match(/#(\d+)/)?.[1] || 0)))); }
function strip(v = '') { return decode(v.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, ' ').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()); }
function abs(v, base = BASE) { if (!v) return ''; try { return new URL(v, base).href; } catch (_) { return ''; } }
function attr(html, name) { const m = html.match(new RegExp(`${name}=["']([^"']+)`, 'i')); return m ? decode(m[1]) : ''; }
function blocks(html, re) { return [...html.matchAll(re)].map(m => m[0]); }
function mediaUrl(v) { return /^(?:https?:|\/\/)/i.test(v) ? abs(v) : ''; }
function titleFrom(block) { return strip((block.match(/<(?:h[1-4]|a|div|span)[^>]*>([\s\S]*?)<\/(?:h[1-4]|a|div|span)>/i) || [,''])[1]) || attr(block, 'title') || 'بدون عنوان'; }
function imageFrom(block) { return abs((block.match(/<img[^>]+(?:data-src|data-lazy-src|src)=["']([^"']+)/i) || [,''])[1]); }
function itemFrom(block) {
  const link = block.match(/href=["']([^"']+)["']/i); if (!link) return null;
  const url = abs(link[1]); if (!url || url === BASE || /(?:page|category|tag|search)/i.test(url)) return null;
  const rawTitle = titleFrom(block); const isSeries = /مسلسل|series|season|حلقة|episode/i.test(block + rawTitle);
  return { title: rawTitle, url, image_url: imageFrom(block), type: isSeries ? 'مسلسل' : 'فيلم', category: 'wecima', source: 'Wecima', source_id: 'wecima' };
}
function extractServers(html, pageUrl) {
  const found = new Map();
  const add = (raw, label = '') => { const url = mediaUrl(raw.replace(/&amp;/g, '&')); if (!url || found.has(url) || url.includes('wecima.cx')) return; found.set(url, { name: strip(label) || `سيرفر ${found.size + 1}`, url, type: /\.m3u8|\.mp4|\.mpd/i.test(url) ? 'direct' : 'player' }); };
  for (const m of html.matchAll(/<(?:iframe|embed|video|source)[^>]+(?:src|data-src)=["']([^"']+)["'][^>]*>/gi)) add(m[1], 'مشغل');
  for (const m of html.matchAll(/<(?:a|button|div)[^>]*(?:data-(?:url|embed|src)|href)=["']([^"']+)["'][^>]*>([\s\S]*?)<\/(?:a|button|div)>/gi)) if (/سيرفر|server|مشاهدة|watch|play|تحميل/i.test(m[0])) add(m[1], m[2]);
  for (const m of html.matchAll(/https?:\/\/[^\s"'<>\\]+/gi)) if (/(?:m3u8|mp4|mpd|dood|vid|filemoon|voe|stream|uqload|mixdrop|ok\.ru|pixeldrain)/i.test(m[0])) add(m[0], 'رابط مستخرج');
  return [...found.values()];
}
function parseDetails(html, url) {
  const title = strip((html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) || html.match(/<title[^>]*>([\s\S]*?)<\/title>/i) || [,'فيلم بدون عنوان'])[1]);
  const image = imageFrom(html); const description = strip((html.match(/<(?:div|p)[^>]*class=["'][^"']*(?:story|description|synopsis|wp-content)[^"']*["'][^>]*>([\s\S]*?)<\//i) || [,''])[1]);
  const episodes = []; const seen = new Set();
  for (const m of html.matchAll(/<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)) if (/(?:حلقة|episode|season|مسلسل|series)/i.test(m[1] + m[2])) { const u = abs(m[1]); if (!seen.has(u) && u !== url) { seen.add(u); episodes.push({ title: strip(m[2]) || `الحلقة ${episodes.length + 1}`, url: u, number: Number((m[2].match(/\d+/) || [episodes.length + 1])[0]) }); } }
  return { title: title || 'فيلم بدون عنوان', url, image_url: image, description, category: 'wecima', type: /مسلسل|series|season|حلقة|episode/i.test(html) ? 'مسلسل' : 'فيلم', episodes: episodes.sort((a, b) => a.number - b.number), servers: extractServers(html, url) };
}
async function get(url) { const hit = cache.get(url); if (hit && hit.expires > Date.now()) return hit.value; const r = await fetch(url, { headers }); if (!r.ok) throw new Error(`Wecima ${r.status}`); const html = await r.text(); cache.set(url, { value: html, expires: Date.now() + 90000 }); return html; }
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*'); res.setHeader('Cache-Control', 'public, max-age=30');
  try {
    const { action = 'latest', page = '1', q = '', url = '' } = req.query;
    if (action === 'search' || action === 'latest') { const target = action === 'search' && q ? `${BASE}/?s=${encodeURIComponent(q)}` : `${BASE}/page/${Math.max(1, Number(page))}/`; const html = await get(target); const items = blocks(html, /<(?:article|div)[^>]*(?:class=["'][^"']*(?:post|item|film|movie|series)[^"']*)[\s\S]*?<\/(?:article|div)>/gi).map(itemFrom).filter(Boolean); return res.json({ items: [...new Map(items.map(x => [x.url, x])).values()], page: Number(page), hasMore: items.length > 0 }); }
    if (!url || !/^https?:\/\/wecima\.[^/]+/i.test(url)) return res.status(400).json({ error: 'invalid url' });
    const html = await get(url); return res.json(action === 'servers' ? { url, servers: extractServers(html, url) } : parseDetails(html, url));
  } catch (e) { return res.status(502).json({ error: 'wecima bridge unavailable', message: e.message }); }
};
