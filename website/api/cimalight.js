const BASE = 'https://e.cimalight.co';
const cache = new Map();
const headers = {
  'User-Agent': 'AniTV-CimaLight-PublicBridge/1.0',
  Accept: 'text/html,application/xhtml+xml',
};

const CATEGORIES = {
  latest: '/main31',
  movies: '/category.php?cat=online-movies3',
  arabicMovies: '/category.php?cat=arabic-movies9',
  foreignMovies: '/category.php?cat=english-movies2',
  turkishMovies: '/category.php?cat=turkish-movies',
  indianMovies: '/category.php?cat=indian-movies1',
  animeMovies: '/category.php?cat=anime-movies1',
  series: '/all-series.php',
  episodes: '/episodes.php',
  arabicSeries: '/category.php?cat=arabic-series16',
  foreignSeries: '/category.php?cat=english-series7',
  turkishSeries: '/category.php?cat=turkish-series20',
  asianSeries: '/category.php?cat=asian-series',
  animeSeries: '/category.php?cat=anime2',
};

function absolute(value = '') {
  if (!value) return '';
  if (value.startsWith('//')) return `https:${value}`;
  if (value.startsWith('http')) return value;
  return `${BASE}${value.startsWith('/') ? '' : '/'}${value}`;
}

function decode(value = '') {
  return value
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#039;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)));
}

function strip(value = '') {
  return decode(value.replace(/<script[\s\S]*?<\/script>/gi, '').replace(/<style[\s\S]*?<\/style>/gi, '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim());
}

function unique(items) {
  return [...new Map(items.filter(Boolean).map(item => [item.url, item])).values()];
}

function attr(tag, name) {
  const match = tag.match(new RegExp(`${name}=["']([^"']+)`, 'i'));
  return match ? decode(match[1]) : '';
}

function parseCard(block) {
  const link = block.match(/<a[^>]+href=["']([^"']*watch\.php\?vid=[^"']+)["'][^>]*>/i);
  if (!link) return null;
  const tag = link[0];
  const title = attr(tag, 'title') || strip((block.match(/<h[1-4][^>]*>[\s\S]*?<\/h[1-4]>/i) || ['',''])[0]);
  const image = (block.match(/<img[^>]+(?:src|data-src)=["']([^"']+)/i) || ['',''])[1];
  const duration = strip((block.match(/pm-label-duration[^>]*>([\s\S]*?)<\//i) || ['',''])[1]);
  const quality = strip((block.match(/(?:hot|quality)[^>]*>[\s\S]*?<\/span>/i) || ['',''])[0]);
  return {
    id: new URL(absolute(link[1])).searchParams.get('vid') || '',
    title: strip(title),
    url: absolute(link[1]),
    image_url: absolute(image),
    duration,
    quality,
    source: 'CimaLight',
  };
}

function parseCards(html) {
  const blocks = html.match(/<li[^>]*>[\s\S]*?watch\.php\?vid=[\s\S]*?<\/li>/gi) || [];
  return unique(blocks.map(parseCard));
}

function meta(html, name) {
  const re = new RegExp(`<meta[^>]+itemprop=["']${name}["'][^>]+content=["']([^"']*)`, 'i');
  return decode((html.match(re) || ['',''])[1]);
}

function parseDetails(html, url) {
  const title = strip((html.match(/<h1[^>]*itemprop=["']name["'][^>]*>([\s\S]*?)<\/h1>/i) || ['',''])[1]);
  const description = meta(html, 'description') || strip((html.match(/<div[^>]*itemprop=["']description["'][^>]*>([\s\S]*?)<\/div>/i) || ['',''])[1]);
  const image = meta(html, 'thumbnailUrl') || meta(html, 'image');
  const categoryText = strip((html.match(/<dt>\s*الاقسام\s*<\/dt>[\s\S]*?<dd[^>]*>([\s\S]*?)<\/dd>/i) || ['',''])[1]);
  const tags = [...html.matchAll(/<a[^>]+href=["'][^"']*tag\.php[^"']*["'][^>]*>([\s\S]*?)<\/a>/gi)].map(m => strip(m[1]));
  const related = parseCards(html);
  return {
    title,
    url,
    image_url: absolute(image),
    description,
    duration: meta(html, 'duration'),
    upload_date: meta(html, 'uploadDate') || meta(html, 'datePublished'),
    content_url: meta(html, 'contentUrl'),
    categories: categoryText ? categoryText.split('»').map(x => x.trim()).filter(Boolean) : [],
    tags: [...new Set(tags)],
    episodes: related,
    source: 'CimaLight',
  };
}

async function fetchHtml(url) {
  const cached = cache.get(url);
  if (cached && cached.expires > Date.now()) return cached.value;
  const response = await fetch(url, { headers, redirect: 'follow' });
  if (!response.ok) throw new Error(`CimaLight returned ${response.status}`);
  const value = await response.text();
  cache.set(url, { value, expires: Date.now() + 90_000 });
  return value;
}

function pageUrl(path, page) {
  if (!page || Number(page) <= 1) return absolute(path);
  const join = path.includes('?') ? '&' : '?';
  return absolute(`${path}${join}page=${Math.max(1, Number(page))}`);
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cache-Control', 'public, max-age=60');
  try {
    const { action = 'latest', category = 'latest', page = '1', url = '' } = req.query;
    if (action === 'search') {
      return res.status(501).json({ error: 'search_not_available', message: 'CimaLight search endpoint is disallowed by its public robots policy; use categories and latest pages.' });
    }
    if (action === 'index' || action === 'latest' || action === 'category') {
      const path = CATEGORIES[category] || CATEGORIES.latest;
      const html = await fetchHtml(pageUrl(path, page));
      const items = parseCards(html);
      return res.json({ source: 'CimaLight', category, page: Number(page), items, hasMore: items.length > 0, publicOnly: true });
    }
    if (action === 'details') {
      if (!url || !url.startsWith(`${BASE}/watch.php?vid=`)) return res.status(400).json({ error: 'invalid_public_watch_url' });
      const html = await fetchHtml(url);
      return res.json(parseDetails(html, url));
    }
    return res.status(400).json({ error: 'unsupported_action', actions: ['latest', 'index', 'category', 'details'] });
  } catch (error) {
    return res.status(502).json({ error: 'cimalight_public_bridge_unavailable', message: error.message });
  }
};

module.exports.categories = CATEGORIES;
