const HOSTS = ['anime4up.bond', 'anime4up.rest', '4b.1i2cqoi.shop', 'w1.anime4up.rest'];

const text = (value) => String(value || '')
  .replace(/<[^>]*>/g, ' ')
  .replace(/&nbsp;/gi, ' ')
  .replace(/&amp;/gi, '&')
  .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
  .replace(/\s+/g, ' ')
  .trim();

const absolute = (base, raw) => {
  try { return new URL(raw, base).toString().split('#')[0]; } catch (_) { return ''; }
};

const isUtility = (url) => /\/(page|forum|category|genre|tag|search|privacy|terms|contact)\//i.test(url);
const episodeNumber = (value) => {
  const matches = [...String(value || '').matchAll(/(?:episode|ep|حلقة|الحلقة|e)\s*[-_.:#]*\s*(\d+(?:\.\d+)?)/ig)];
  const fallback = [...String(value || '').matchAll(/(?:^|[^\d])(\d+(?:\.\d+)?)(?:[^\d]|$)/g)];
  const raw = matches.at(-1)?.[1] || fallback.at(-1)?.[1];
  const number = Number(raw);
  return Number.isFinite(number) ? number : null;
};

const supports = (source, itemId) => {
  const value = String(itemId || '');
  try {
    const host = new URL(value).hostname.toLowerCase();
    return (source === 'anime4up' || !source) && HOSTS.some((candidate) => host.endsWith(candidate));
  } catch (_) { return false; }
};

async function latestEpisode({ source, itemId }) {
  if (!supports(source, itemId)) return null;
  const response = await fetch(itemId, { headers: { 'User-Agent': 'AniTV-Favorite-Scanner/1.0' } });
  if (!response.ok) throw new Error(`Anime4Up HTTP ${response.status}`);
  const html = await response.text();
  const seen = new Set();
  const episodes = [];
  const pattern = /<(?:a|button)\b[^>]+(?:href|data-url|data-href|data-link)=["']([^"']+)["'][^>]*>([\s\S]*?)<\/(?:a|button)>/gi;
  for (const match of html.matchAll(pattern)) {
    const url = absolute(itemId, match[1]);
    if (!url || url === itemId || seen.has(url) || isUtility(url)) continue;
    const label = text(match[2]);
    const decoded = decodeURIComponent(url);
    const number = episodeNumber(`${label} ${decoded}`);
    if (number === null) continue;
    if (!/(\/episode|\/watch|\/play|حلقة|episode)/i.test(`${url} ${label}`) && number === null) continue;
    seen.add(url);
    episodes.push({ number, title: label || `Episode ${number}`, url });
  }
  episodes.sort((a, b) => a.number - b.number);
  return episodes.length ? episodes.at(-1) : null;
}

module.exports = { id: 'anime4up', supports, latestEpisode };
