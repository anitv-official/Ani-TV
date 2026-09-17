const BASES = ['https://wecimamax.com', 'https://wec.im'];
const headers = {
  'User-Agent': 'AniTV-WecimaBridge/2.0 (licensed integration)',
  Accept: 'text/html,application/xhtml+xml',
};
const cache = new Map();

function decode(value = '') {
  return value
    .replace(/&(?:amp|lt|gt|quot|#039|nbsp|#\d+);/g, (match) => ({
      '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#039;': "'", '&nbsp;': ' ',
    }[match] || String.fromCodePoint(Number(match.match(/#(\d+)/)?.[1] || 0))));
}
function strip(value = '') {
  return decode(value.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim());
}
function abs(value, base = BASES[0]) {
  if (!value) return '';
  try { return new URL(decode(value), base).href; } catch (_) { return ''; }
}
function attr(html, name) {
  const match = html.match(new RegExp(`${name}=["']([^"']+)`, 'i'));
  return match ? decode(match[1]) : '';
}
function isCatalogItemUrl(value) {
  try {
    const path = new URL(value).pathname.replace(/\/+$/, '');
    return /^\/(?:movies|shows)\/[^/]+(?:\/[^/]+)?$/i.test(path) &&
      !/(?:\/genre\/|\/season(?:s)?\/|\/tag\/|\/category\/)/i.test(path);
  } catch (_) { return false; }
}
function titleFrom(block, url = '') {
  const match = block.match(/<(?:h[1-4]|h[1-4]|a|div|span)[^>]*>([\s\S]*?)<\/(?:h[1-4]|a|div|span)>/i);
  const value = strip(match?.[1] || attr(block, 'title'));
  if (value && !/^(home|تسجيل الدخول|facebook|قائمة الأفلام|قائمة المسلسلات)$/i.test(value)) return value;
  try { return decode(new URL(url).pathname.split('/').filter(Boolean).pop() || 'بدون عنوان').replace(/[-_]+/g, ' '); } catch (_) { return 'بدون عنوان'; }
}
function imageFrom(block, base) {
  return abs((block.match(/<img[^>]+(?:data-src|data-lazy-src|src)=["']([^"']+)/i) || [,''])[1], base);
}
function itemFrom(block, base) {
  const link = block.match(/href=["']([^"']+)["']/i);
  if (!link) return null;
  const url = abs(link[1], base);
  if (!isCatalogItemUrl(url)) return null;
  const rawTitle = titleFrom(block, url);
  const isSeries = new URL(url).pathname.startsWith('/shows/');
  return {
    title: rawTitle,
    url,
    image_url: imageFrom(block, base),
    type: isSeries ? 'مسلسل' : 'فيلم',
    category: 'wecima',
    source: 'Wecima',
    source_id: 'wecima',
  };
}
function catalogItems(html, base) {
  const result = [];
  const seen = new Set();
  // Parse only links that are actual movie/show pages. Navigation, login and social links
  // are intentionally excluded even when the site changes its card markup.
  for (const match of html.matchAll(/<a[^>]+href=["']([^"']+)["'][^>]*>[\s\S]*?<\/a>/gi)) {
    const item = itemFrom(match[0], base);
    if (item && !seen.has(item.url)) { seen.add(item.url); result.push(item); }
  }
  return result;
}
function directMediaUrl(value) {
  const url = abs(value);
  if (!url || !/^https?:/i.test(url)) return '';
  const lower = url.toLowerCase();
  return /\.(?:m3u8|mp4|mpd|webm)(?:[?#].*)?$/i.test(lower) ? url : '';
}
function extractServers(html) {
  const found = new Map();
  const add = (raw, label = 'فيديو مباشر') => {
    const url = directMediaUrl(raw);
    if (!url || found.has(url)) return;
    found.set(url, { name: strip(label) || 'فيديو مباشر', url, type: 'direct' });
  };
  // Never expose iframe/embed/player pages: those are the source of ads and redirects.
  for (const match of html.matchAll(/(?:src|data-src|data-url|data-video|file|url)=["']([^"']+)["']/gi)) add(match[1]);
  for (const match of html.matchAll(/https?:\/\/[^\s"'<>\\]+/gi)) add(match[0]);
  return [...found.values()];
}
function parseDetails(html, url, base) {
  const title = strip((html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) || html.match(/<title[^>]*>([\s\S]*?)<\/title>/i) || [,'فيلم بدون عنوان'])[1]);
  const image = imageFrom(html, base);
  const description = strip((html.match(/<(?:div|p)[^>]*class=["'][^"']*(?:story|description|synopsis|wp-content)[^"']*["'][^>]*>([\s\S]*?)<\//i) || [,''])[1]);
  const episodes = [];
  const seen = new Set();
  for (const match of html.matchAll(/<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)) {
    const episodeUrl = abs(match[1], base);
    if (!/^https?:/i.test(episodeUrl) || !isCatalogItemUrl(episodeUrl) || episodeUrl === url || seen.has(episodeUrl)) continue;
    if (!/\/shows\//i.test(episodeUrl)) continue;
    const label = strip(match[2]);
    if (!/(?:حلقة|episode|season|مسلسل|series|\d+)/i.test(label + episodeUrl)) continue;
    seen.add(episodeUrl);
    const number = Number((label.match(/\d+/) || [episodes.length + 1])[0]);
    episodes.push({ title: label || `الحلقة ${number}`, url: episodeUrl, number });
  }
  return {
    title: title || 'فيلم بدون عنوان', url, image_url: image, description,
    category: 'wecima', type: /\/shows\//i.test(url) ? 'مسلسل' : 'فيلم',
    episodes: episodes.sort((a, b) => a.number - b.number), servers: extractServers(html),
  };
}
async function get(url) {
  const hit = cache.get(url);
  if (hit && hit.expires > Date.now()) return hit.value;
  const original = new URL(url);
  const candidates = [url, ...BASES.filter((base) => !url.startsWith(base)).map((base) => `${base}${original.pathname}${original.search}`)];
  let last;
  for (const candidate of candidates) {
    try {
      const response = await fetch(candidate, { headers });
      if (!response.ok) throw new Error(`Wecima ${response.status}`);
      const html = await response.text();
      if (/Just a moment|cf-chl-|challenge-platform|cf-mitigated/i.test(html)) throw new Error('Cloudflare challenge');
      if (html.length < 500) throw new Error('Wecima page is empty');
      const value = { html, base: new URL(candidate).origin };
      cache.set(url, { value, expires: Date.now() + 90000 });
      return value;
    } catch (error) { last = error; }
  }
  throw last || new Error('Wecima unavailable');
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cache-Control', 'public, max-age=30');
  try {
    const { action = 'latest', page = '1', q = '', url = '' } = req.query;
    if (action === 'latest' || action === 'search') {
      const target = action === 'search' && q
        ? `${BASES[0]}/?s=${encodeURIComponent(q)}`
        : (Number(page) <= 1 ? `${BASES[0]}/` : `${BASES[0]}/page/${Math.max(1, Number(page))}/`);
      const result = await get(target);
      const items = catalogItems(result.html, result.base);
      return res.json({ items, page: Number(page), hasMore: items.length > 0 });
    }
    if (!url || !BASES.some((base) => url.startsWith(base))) return res.status(400).json({ error: 'invalid url' });
    const result = await get(url);
    if (action === 'servers') return res.json({ url, servers: extractServers(result.html) });
    return res.json(parseDetails(result.html, url, result.base));
  } catch (error) {
    return res.status(502).json({ error: 'wecima bridge unavailable', message: error.message });
  }
};

module.exports._test = { isCatalogItemUrl, directMediaUrl, catalogItems, extractServers };
