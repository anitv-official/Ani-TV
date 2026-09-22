const HOST = 'anime3rb.com';
const BASE_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
  Accept: 'text/html,application/xhtml+xml,application/json;q=0.8,*/*;q=0.7',
  'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
  'Cache-Control': 'no-cache',
};
const clean = (value) => String(value || '')
  .replace(/<[^>]*>/g, ' ')
  .replace(/&nbsp;/gi, ' ')
  .replace(/&amp;/gi, '&')
  .replace(/&#(?:x27|39);/gi, "'")
  .replace(/\s+/g, ' ')
  .trim();
const absolute = (base, value) => {
  try { return new URL(value, base).toString().split('#')[0]; } catch (_) { return ''; }
};
const validPage = (url) => {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' && (parsed.hostname === HOST || parsed.hostname.endsWith(`.${HOST}`));
  } catch (_) { return false; }
};
const numberFrom = (value) => {
  const urlMatch = /\/episode\/[^/?#]+\/(\d+)(?:[/?#]|$)/i.exec(String(value || ''));
  if (urlMatch) return Number(urlMatch[1]);
  const textMatch = /(?:الحلقة|حلقة|episode|ep\.?)[\s:_-]*(\d+)/i.exec(String(value || ''));
  return textMatch ? Number(textMatch[1]) : null;
};
const isChallenge = (response, body) => response.status === 403
  || response.headers.get('cf-mitigated') === 'challenge'
  || /(?:just a moment|enable javascript and cookies|challenge-platform)/i.test(String(body || ''));

async function readPage(url) {
  const direct = await fetch(url, { headers: { ...BASE_HEADERS, Referer: 'https://anime3rb.com/' } });
  const directBody = await direct.text();
  if (direct.ok && !isChallenge(direct, directBody)) return directBody;

  // This is the same public reader fallback already used by AniTV's HtmlClient.
  // It does not solve Cloudflare challenges, submit tokens, or impersonate a user.
  const readerUrl = `https://r.jina.ai/http://${new URL(url).host}${new URL(url).pathname}${new URL(url).search}`;
  const reader = await fetch(readerUrl, { headers: { Accept: 'text/plain', 'User-Agent': BASE_HEADERS['User-Agent'] } });
  const readerBody = await reader.text();
  if (!reader.ok || !readerBody.trim() || isChallenge(reader, readerBody)) {
    throw new Error(`Anime3rb page unavailable: HTTP ${direct.status}; public reader HTTP ${reader.status}`);
  }
  return readerBody;
}

function extractEpisodes(body, pageUrl) {
  const values = [];
  const seen = new Set();
  const add = (rawText, rawUrl) => {
    const url = absolute(pageUrl, rawUrl);
    if (!url || !validPage(url) || !/\/episode\//i.test(new URL(url).pathname)) return;
    const number = numberFrom(`${rawText} ${url}`);
    if (!Number.isInteger(number) || number < 0 || seen.has(url)) return;
    seen.add(url);
    values.push({ number, title: clean(rawText) || `Episode ${number}`, url });
  };

  for (const match of String(body).matchAll(/<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)) {
    add(match[2], match[1]);
  }
  for (const match of String(body).matchAll(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g)) {
    add(match[1], match[2]);
  }
  return values.sort((a, b) => a.number - b.number || a.url.localeCompare(b.url));
}

const supports = (source, itemId) => {
  const sourceId = String(source || '').trim().toLowerCase();
  return (sourceId === 'anime3rb' || sourceId === 'anime3rb.com' || !sourceId) && validPage(itemId);
};

async function latestEpisode({ source, itemId }) {
  if (!supports(source, itemId)) return null;
  const episodes = extractEpisodes(await readPage(itemId), itemId);
  return episodes.at(-1) || null;
}

module.exports = { id: 'anime3rb', supports, latestEpisode, extractEpisodes };
