const crypto = require('node:crypto');

const supportedTypes = new Set(['anime', 'manga', 'comic', 'movie', 'series', 'drama']);
const clean = (value) => String(value || '').replace(/<[^>]*>/g, ' ').replace(/&nbsp;/gi, ' ').replace(/\s+/g, ' ').trim();
const numberFrom = (text, type) => {
  const marker = type === 'manga' || type === 'comic' ? '(?:chapter|ch|الفصل|فصل)' : '(?:episode|ep|حلقة|الحلقة|الموسم|season)';
  const matches = [...String(text).matchAll(new RegExp(`${marker}\\s*[-_.:#]*\\s*(\\d+(?:\\.\\d+)?)`, 'ig'))];
  return matches.at(-1)?.[1] || null;
};
const dateFrom = (html) => {
  const match = /(?:dateModified|datePublished|uploadDate|releaseDate)"?\s*[:=]\s*"([^" ]+)"/i.exec(html)
    || /<time[^>]+datetime=["']([^"']+)["']/i.exec(html);
  return match?.[1] || null;
};

const supports = (source, itemId, type) => {
  if (!supportedTypes.has(String(type || '').toLowerCase())) return false;
  try { return /^https?:$/i.test(new URL(String(itemId)).protocol); } catch (_) { return false; }
};

async function latestRelease({ source, itemId, type }) {
  if (!supports(source, itemId, type)) return null;
  const response = await fetch(itemId, { headers: { 'User-Agent': 'AniTV-Favorite-Scanner/1.0' } });
  if (!response.ok) throw new Error(`Content source HTTP ${response.status}`);
  const html = await response.text();
  const text = clean(html);
  const number = numberFrom(text, type);
  if (number) return { key: number, number, kind: type === 'manga' || type === 'comic' ? 'chapter' : 'episode' };
  const date = dateFrom(html);
  if (date && ['movie', 'series', 'drama'].includes(String(type).toLowerCase())) {
    const parsed = new Date(date);
    if (!Number.isNaN(parsed.getTime())) {
      const key = parsed.toISOString();
      return { key, number: key, kind: 'release' };
    }
  }
  return null;
}

module.exports = {
  id: 'generic-page',
  supports,
  latestRelease,
  fingerprint(value) { return crypto.createHash('sha1').update(String(value)).digest('hex'); },
};
