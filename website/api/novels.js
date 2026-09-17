const BASE = 'https://kolnovel.com';
const headers = { 'User-Agent': 'AniTV-NovelBridge/1.0 (authorized integration)', 'Accept': 'text/html' };
const cache = new Map();

function decode(value = '') {
  return value.replace(/&(?:amp|lt|gt|quot|#039|nbsp|#\d+);/g, m => {
    const named = {'&amp;':'&','&lt;':'<','&gt;':'>','&quot;':'"','&#039;':"'",'&nbsp;':' '};
    if (named[m]) return named[m];
    const numeric = m.match(/#(\d+)/); return numeric ? String.fromCodePoint(Number(numeric[1])) : m;
  });
}
function strip(value = '') { return decode(value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()); }
function attr(html, name) { const m = html.match(new RegExp(`${name}=["']([^"']+)`, 'i')); return m ? decode(m[1]) : ''; }
function abs(url) { if (!url) return ''; return url.startsWith('http') ? url : `${BASE}${url.startsWith('/') ? '' : '/'}${url}`; }
function blocks(html, re) { return [...html.matchAll(re)].map(m => m[0]); }
function seriesFromCard(card) {
  const link = card.match(/href=["']([^"']*\/series\/[^"']+)["']/i);
  if (!link) return null;
  const title = strip((card.match(/<h[1-4][^>]*>([\s\S]*?)<\/h[1-4]>/i) || [,''])[1]) || attr(card, 'title');
  const image = (card.match(/<img[^>]+(?:src|data-src)=["']([^"']+)/i) || [,''])[1];
  const desc = strip((card.match(/<(?:p|div)[^>]*class=["'][^"']*(?:excerpt|summary|description)[^"']*["'][^>]*>([\s\S]*?)<\//i) || [,''])[1]);
  return { title: title || 'بدون عنوان', url: abs(link[1]), image_url: abs(image), synopsis: desc, source: 'KolNovel', type: 'رواية' };
}
function chapterFromLink(href, text) { return { title: strip(text) || 'فصل', url: abs(href) }; }
function parseSeries(html, url) {
  const item = seriesFromCard(html) || { title: strip((html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) || [,''])[1]), url, image_url: '' };
  const chapters = [];
  for (const m of html.matchAll(/<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)) {
    if (/\/shaag|chapter|فصل/i.test(m[1] + m[2]) && !m[1].includes('#/') && !m[2].includes('{{')) chapters.push(chapterFromLink(m[1], m[2]));
  }
  return { ...item, url, chapters: [...new Map(chapters.map(x => [x.url, x])).values()] };
}
function parseChapter(html, url) {
  const title = strip((html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) || [,''])[1]) || 'فصل رواية';
  const main = (html.match(/<div[^>]*id=["']kol_content["'][^>]*>([\s\S]*?)(?=<div[^>]*kol-chapter-translator)/i) || html.match(/<article[^>]*(?:reading-content|chapter-content|entry-content)[^>]*>([\s\S]*?)<\/article>/i) || [,''])[1];
  const content = strip(main || html.replace(/<script[\s\S]*?<\/script>/gi, '').replace(/<style[\s\S]*?<\/style>/gi, ''));
  return { title, url, content: content.slice(0, 300000) };
}
async function get(url) {
  const hit = cache.get(url); if (hit && hit.expires > Date.now()) return hit.value;
  const response = await fetch(url, { headers });
  if (!response.ok) throw new Error(`KolNovel ${response.status}`);
  const value = await response.text(); cache.set(url, { value, expires: Date.now() + 120000 }); return value;
}
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*'); res.setHeader('Cache-Control', 'public, max-age=60');
  try {
    const { action = 'latest', page = '1', q = '', url = '' } = req.query;
    if (action === 'latest' || action === 'search') {
      const target = action === 'search' && q ? `${BASE}/?s=${encodeURIComponent(q)}&post_type=series` : `${BASE}/series/page/${Math.max(1, Number(page))}/`;
      const html = await get(target);
      const items = blocks(html, /<article[\s\S]*?<\/article>/gi).map(seriesFromCard).filter(Boolean);
      return res.json({ items, page: Number(page), hasMore: items.length > 0 });
    }
    if (!url || !url.startsWith(BASE)) return res.status(400).json({ error: 'invalid url' });
    const html = await get(url);
    return res.json(action === 'chapter' ? parseChapter(html, url) : parseSeries(html, url));
  } catch (error) { return res.status(502).json({ error: 'novel bridge unavailable', message: error.message }); }
}
