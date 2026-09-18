const text = (value) => String(value || '').replace(/<[^>]*>/g, ' ').replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/\s+/g, ' ').trim();
const absolute = (base, raw) => { try { return new URL(raw, base).toString().split('#')[0]; } catch (_) { return ''; } };
const numberFrom = (value) => {
  const match = String(value || '').match(/(?:episode|ep|حلقة|الحلقة|e)[\s._:#-]*(\d+(?:\.\d+)?)/i) || String(value || '').match(/(?:^|[^\d])(\d+(?:\.\d+)?)(?:[^\d]|$)/);
  const number = Number(match?.[1]);
  return Number.isFinite(number) ? number : null;
};
const supports = (source, itemId) => /^(faselhd|fasel|cima-cloud)$/i.test(String(source || '')) && /^https?:\/\//i.test(String(itemId || ''));
async function latestEpisode({ source, itemId }) {
  if (!supports(source, itemId)) return null;
  const response = await fetch(itemId, { headers: { 'User-Agent': 'AniTV-Favorite-Scanner/1.0' } });
  if (!response.ok) throw new Error(`FaselHD HTTP ${response.status}`);
  const html = await response.text();
  const seen = new Set();
  const episodes = [];
  const pattern = /<(?:a|button)\b[^>]+(?:href|data-url|data-href|data-link)=["']([^"']+)["'][^>]*>([\s\S]*?)<\/(?:a|button)>/gi;
  for (const match of html.matchAll(pattern)) {
    const url = absolute(itemId, match[1]);
    const label = text(match[2]);
    const number = numberFrom(`${label} ${url}`);
    if (!url || seen.has(url) || number === null) continue;
    if (!/(episode|ep|حلقة|watch|play|series)/i.test(`${url} ${label}`)) continue;
    seen.add(url);
    episodes.push({ number, title: label || `Episode ${number}`, url });
  }
  episodes.sort((a, b) => a.number - b.number);
  return episodes.at(-1) || null;
}
module.exports = { id: 'faselhd', supports, latestEpisode };
