const BASE = 'https://kolnovel.com';
const headers = { 'User-Agent': 'AniTV-NovelBridge/2.0 (authorized integration)', Accept: 'text/html' };
const cache = new Map();
function decode(value = '') { return value.replace(/&(?:amp|lt|gt|quot|#039|nbsp|#\d+);/g, m => ({'&amp;':'&','&lt;':'<','&gt;':'>','&quot;':'"','&#039;':"'",'&nbsp;':' '}[m] || String.fromCodePoint(Number(m.match(/#(\d+)/)?.[1] || 0)))); }
function strip(value = '') { return decode(value.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, ' ').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()); }
function attr(html, name) { const m = html.match(new RegExp(`${name}=["']([^"']+)`, 'i')); return m ? decode(m[1]) : ''; }
function abs(url) { if (!url) return ''; return url.startsWith('http') ? url : `${BASE}${url.startsWith('/') ? '' : '/'}${url}`; }
function blocks(html, re) { return [...html.matchAll(re)].map(m => m[0]); }
function first(html, patterns) { for (const re of patterns) { const m = html.match(re); if (m?.[1]) return strip(m[1]); } return ''; }
function seriesFromCard(card) {
  const link = card.match(/href=["']([^"']*\/series\/[^"']+)["']/i); if (!link) return null;
  const title = first(card, [/<h[1-4][^>]*class=["'][^"']*entry-title[^"']*["'][^>]*>([\s\S]*?)<\/h[1-4]>/i, /<h[1-4][^>]*>([\s\S]*?)<\/h[1-4]>/i]) || attr(card, 'title');
  const image = (card.match(/<img[^>]+(?:data-src|data-lazy-src|src)=["']([^"']+)/i) || [,''])[1];
  const desc = first(card, [/<(?:p|div)[^>]*class=["'][^"']*(?:excerpt|summary|description)[^"']*["'][^>]*>([\s\S]*?)<\//i]);
  return { title: title || 'رواية بدون عنوان', url: abs(link[1]), image_url: abs(image), synopsis: desc, source: 'KolNovel', type: 'رواية' };
}
function chapterFromLink(href, text, number) { const clean = strip(text); const n = number || (clean.match(/(?:الفصل|chapter)\s*([\d.]+)/i)?.[1] || ''); return { title: clean || (n ? `الفصل ${n}` : 'فصل الرواية'), url: abs(href), number: Number(n) || 0 }; }
function parseSeries(html, url) {
  const title = first(html, [/<h1[^>]*class=["'][^"']*entry-title[^"']*["'][^>]*>([\s\S]*?)<\/h1>/i, /<h1[^>]*>([\s\S]*?)<\/h1>/i]);
  const image = (html.match(/<img[^>]+(?:data-src|data-lazy-src|src)=["']([^"']+)["'][^>]*>/i) || [,''])[1];
  const synopsis = first(html, [/<div[^>]*class=["'][^"']*entry-content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i, /<div[^>]*class=["'][^"']*description[^"']*["'][^>]*>([\s\S]*?)<\/div>/i]);
  const chapters = [];
  for (const m of html.matchAll(/<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)) {
    if (/\/shaag\//i.test(m[1]) || /(?:chapter|الفصل|فصل)/i.test(m[1] + m[2])) chapters.push(chapterFromLink(m[1], m[2]));
  }
  const unique = [...new Map(chapters.filter(x => x.url !== url).map(x => [x.url, x])).values()].sort((a, b) => b.number - a.number);
  return { title: title || 'رواية بدون عنوان', url, image_url: abs(image), synopsis, source: 'KolNovel', type: 'رواية', chapters: unique };
}
function parseChapter(html, url) {
  const title = first(html, [/<h1[^>]*class=["'][^"']*(?:entry-title|chapter-title)[^"']*["'][^>]*>([\s\S]*?)<\/h1>/i, /<h1[^>]*>([\s\S]*?)<\/h1>/i, /<title[^>]*>([\s\S]*?)<\/title>/i]) || 'فصل الرواية';
  const main = (html.match(/<div[^>]*id=["']kol_content["'][^>]*>([\s\S]*?)(?=<div[^>]*kol-chapter-translator)/i) || html.match(/<(?:article|div)[^>]*(?:reading-content|chapter-content|epcontent|entry-content)[^>]*>([\s\S]*?)<\/(?:article|div)>/i) || [,''])[1];
  const content = strip(main || html);
  return { title, url, content: content.slice(0, 300000) };
}
async function get(url) { const hit = cache.get(url); if (hit && hit.expires > Date.now()) return hit.value; const response = await fetch(url, { headers }); if (!response.ok) throw new Error(`KolNovel ${response.status}`); const value = await response.text(); cache.set(url, { value, expires: Date.now() + 120000 }); return value; }
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*'); res.setHeader('Cache-Control', 'public, max-age=60');
  try {
    const { action = 'latest', page = '1', q = '', url = '' } = req.query;
    if (action === 'latest' || action === 'search') { const target = action === 'search' && q ? `${BASE}/?s=${encodeURIComponent(q)}&post_type=series` : `${BASE}/series/page/${Math.max(1, Number(page))}/`; const html = await get(target); const items = blocks(html, /<article[\s\S]*?<\/article>/gi).map(seriesFromCard).filter(Boolean); return res.json({ items, page: Number(page), hasMore: items.length > 0 }); }
    if (!url || !url.startsWith(BASE)) return res.status(400).json({ error: 'invalid url' });
    const html = await get(url); return res.json(action === 'chapter' ? parseChapter(html, url) : parseSeries(html, url));
  } catch (error) { return res.status(502).json({ error: 'novel bridge unavailable', message: error.message }); }
};
