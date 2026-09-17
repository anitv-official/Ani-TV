const BASES = ['https://wecimamax.com', 'https://wec.im'];
const headers = { 'User-Agent': 'AniTV-WecimaBridge/3.0', Accept: 'text/html,application/xhtml+xml' };
const cache = new Map();
function decode(v = '') { return v.replace(/&(?:amp|lt|gt|quot|#039|nbsp|#\d+);/g, m => ({'&amp;':'&','&lt;':'<','&gt;':'>','&quot;':'"','&#039;':"'",'&nbsp;':' '}[m] || String.fromCodePoint(Number(m.match(/#(\d+)/)?.[1] || 0)))); }
function strip(v = '') { return decode(v.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, ' ').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()); }
function abs(v, base = BASES[0]) { if (!v) return ''; try { return new URL(decode(v), base).href; } catch (_) { return ''; } }
function attr(html, name) { const m = html.match(new RegExp(`${name}=["']([^"']+)`, 'i')); return m ? decode(m[1]) : ''; }
function meta(html, property) { const a = new RegExp(`<meta[^>]+(?:property|name)=["']${property}["'][^>]+content=["']([^"']+)`, 'i'); const b = new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']${property}["']`, 'i'); return decode((html.match(a) || html.match(b) || [,''])[1]); }
function isCatalogItemUrl(value) { try { const p = new URL(value).pathname.replace(/\/+$/, ''); return /^\/(?:movies|shows)\/[^/]+(?:\/[^/]+)?$/i.test(p) && !/(?:\/genre\/|\/season(?:s)?\/|\/tag\/|\/category\/)/i.test(p); } catch (_) { return false; } }
function titleFrom(block, url = '') {
  const m = block.match(/<(?:h[1-4]|a|div|span)[^>]*>([\s\S]*?)<\/(?:h[1-4]|a|div|span)>/i);
  const value = strip(m?.[1] || attr(block, 'title'));
  if (value && !/^(home|تسجيل الدخول|facebook|قائمة الأفلام|قائمة المسلسلات|الحلقة السابقة)$/i.test(value) && !/^\d+\s+\d+\s+\d+$/.test(value)) return value;
  try { const p = new URL(url).pathname.split('/').filter(Boolean); const slug = p[1] || p[p.length - 1] || ''; const ep = p.length > 2 ? (p[2].match(/^\d+/) || [''])[0] : ''; const name = slug.replace(/[-_]+/g, ' ').replace(/\b\d{4}\b/g, '').trim(); return ep ? `${name} — الحلقة ${ep}` : (name || 'بدون عنوان'); } catch (_) { return 'بدون عنوان'; }
}
function imageFrom(block, base) { return abs((block.match(/<img[^>]+(?:data-src|data-lazy-src|src)=["']([^"']+)/i) || [,''])[1], base); }
function itemFrom(block, base) { const link = block.match(/href=["']([^"']+)["']/i); if (!link) return null; const url = abs(link[1], base); if (!isCatalogItemUrl(url)) return null; const series = new URL(url).pathname.startsWith('/shows/'); return { title: titleFrom(block, url), url, image_url: imageFrom(block, base), type: series ? 'مسلسل' : 'فيلم', category: 'wecima', source: 'Wecima', source_id: 'wecima' }; }
function catalogItems(html, base) { const out = []; const seen = new Set(); for (const m of html.matchAll(/<a[^>]+href=["']([^"']+)["'][^>]*>[\s\S]*?<\/a>/gi)) { const item = itemFrom(m[0], base); if (item && !seen.has(item.url)) { seen.add(item.url); out.push(item); } } return out; }
function directMediaUrl(value) { const url = abs(value); if (!url || !/^https?:/i.test(url)) return ''; return /\.(?:m3u8|mp4|mpd|webm)(?:[?#].*)?$/i.test(url.toLowerCase()) ? url : ''; }
function isAllowedPlayerUrl(value) { try { const host = new URL(value).hostname.toLowerCase().replace(/^www\./, ''); return ['streamtape.cc','luluvdo.com','uqload.net','streamwish.to','streamwish.fun','topcinemaa.com'].some(x => host === x || host.endsWith(`.${x}`)); } catch (_) { return false; } }
function extractServers(html) { const found = new Map(); const add = (raw, label = 'سيرفر مضمّن') => { const resolved = abs(raw); const url = directMediaUrl(resolved) || (isAllowedPlayerUrl(resolved) ? resolved : ''); if (!url || found.has(url)) return; found.set(url, { name: strip(label) || 'سيرفر مضمّن', url, type: directMediaUrl(url) ? 'direct' : 'player' }); }; for (const m of html.matchAll(/(?:src|data-src|data-url|data-video|file|url)=["']([^"']+)["']/gi)) add(m[1]); return [...found.values()]; }
function parseDetails(html, url, base) {
  const rawTitle = meta(html, 'og:title') || strip((html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) || html.match(/<title[^>]*>([\s\S]*?)<\/title>/i) || [,'فيلم بدون عنوان'])[1]);
  const parts = new URL(url).pathname.split('/').filter(Boolean);
  const slugName = (parts[1] || '').replace(/[-_]+/g, ' ').replace(/\b\d{4}\b/g, '').trim();
  const episodeFromUrl = parts[2] ? Number((parts[2].match(/^(\d+)/) || [,])[1]) : 0;
  const title = slugName && episodeFromUrl ? `${slugName} — الحلقة ${episodeFromUrl}` : rawTitle.replace(/\s*[-|].*(?:مشاهدة|wecima|اون لاين).*$/i, '').replace(/\s+/g, ' ').trim();
  const image = meta(html, 'og:image') || imageFrom(html, base);
  const description = meta(html, 'description') || strip((html.match(/<(?:div|p)[^>]*class=["'][^"']*(?:story|description|synopsis|wp-content)[^"']*["'][^>]*>([\s\S]*?)<\//i) || [,''])[1]);
  const episodes = []; const seen = new Set();
  for (const m of html.matchAll(/<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)) {
    const episodeUrl = abs(m[1], base); let path = ''; try { path = new URL(episodeUrl).pathname.replace(/\/+$/, ''); } catch (_) { continue; }
    if (!/^\/shows\/[^/]+\/[^/]+$/i.test(path) || /\/seasons?\//i.test(path) || /\/shows\/genre\//i.test(path) || seen.has(episodeUrl)) continue;
    const label = strip(m[2]); const basename = path.split('/').pop() || ''; const number = Number((label.match(/(?:الحلقة|episode)\s*(\d+)/i) || basename.match(/^(\d+)/) || [, episodes.length + 1])[1]);
    seen.add(episodeUrl); episodes.push({ title: `الحلقة ${number}`, url: episodeUrl, number });
  }
  return { title: title || 'فيلم بدون عنوان', url, image_url: image, description, category: 'wecima', type: /\/shows\//i.test(url) ? 'مسلسل' : 'فيلم', episodes: episodes.sort((a,b) => a.number - b.number), servers: extractServers(html) };
}
async function get(url) { const hit = cache.get(url); if (hit && hit.expires > Date.now()) return hit.value; const original = new URL(url); const candidates = [url, ...BASES.filter(b => !url.startsWith(b)).map(b => `${b}${original.pathname}${original.search}`)]; let last; for (const candidate of candidates) { try { const r = await fetch(candidate, { headers }); if (!r.ok) throw new Error(`Wecima ${r.status}`); const html = await r.text(); if (/Just a moment|cf-chl-|challenge-platform|cf-mitigated/i.test(html)) throw new Error('Cloudflare challenge'); if (html.length < 500) throw new Error('Wecima page is empty'); const value = { html, base: new URL(candidate).origin }; cache.set(url, { value, expires: Date.now() + 90000 }); return value; } catch (e) { last = e; } } throw last || new Error('Wecima unavailable'); }
module.exports = async function handler(req, res) { res.setHeader('Access-Control-Allow-Origin', '*'); res.setHeader('Cache-Control', 'public, max-age=30'); try { const { action = 'latest', page = '1', q = '', url = '' } = req.query; if (action === 'latest' || action === 'search') { const target = action === 'search' && q ? `${BASES[0]}/?s=${encodeURIComponent(q)}` : (Number(page) <= 1 ? `${BASES[0]}/` : `${BASES[0]}/page/${Math.max(1, Number(page))}/`); const result = await get(target); const items = catalogItems(result.html, result.base); return res.json({ items, page: Number(page), hasMore: items.length > 0 }); } if (!url || !BASES.some(b => url.startsWith(b))) return res.status(400).json({ error: 'invalid url' }); const result = await get(url); if (action === 'servers') return res.json({ url, servers: extractServers(result.html) }); return res.json(parseDetails(result.html, url, result.base)); } catch (e) { return res.status(502).json({ error: 'wecima bridge unavailable', message: e.message }); } };
module.exports._test = { isCatalogItemUrl, directMediaUrl, isAllowedPlayerUrl, catalogItems, extractServers, parseDetails };
