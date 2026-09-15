import { createHash } from 'node:crypto';

const config = {
  endpoint: process.env.APPWRITE_ENDPOINT || 'https://nyc.cloud.appwrite.io/v1',
  projectId: process.env.APPWRITE_PROJECT_ID,
  apiKey: process.env.APPWRITE_API_KEY,
  databaseId: process.env.APPWRITE_DATABASE_ID || '6aa58db9001a5f53312d',
  newsTableId: process.env.NEWS_TABLE_ID || 'community_news',
  translationUrl: process.env.TRANSLATION_API_URL,
  translationKey: process.env.TRANSLATION_API_KEY,
};

const sources = [
  { id: 'ann', name: 'Anime News Network', category: 'أنمي', feed: process.env.ANN_FEED_URL || 'https://www.animenewsnetwork.com/all/rss.xml?ann=1' },
  { id: 'crunchyroll', name: 'Crunchyroll News', category: 'أنمي', feed: process.env.CRUNCHYROLL_FEED_URL || 'https://www.crunchyroll.com/news/rss' },
  { id: 'oricon', name: 'ORICON', category: 'أخبار مهمة', feed: process.env.ORICON_FEED_URL || '' },
  { id: 'variety', name: 'Variety', category: 'أفلام', feed: process.env.VARIETY_FEED_URL || 'https://variety.com/feed/' },
  { id: 'deadline', name: 'Deadline', category: 'Streaming', feed: process.env.DEADLINE_FEED_URL || 'https://deadline.com/feed/' },
];

const LIMITS = { title: 512, summary: 600, url: 2048, searchText: 4096, tag: 64, tags: 20 };
const TRACKING_PARAMS = new Set(['fbclid', 'gclid', 'dclid', 'msclkid', 'mc_cid', 'mc_eid', 'ref', 'ref_src']);
const truncate = (value, limit) => Array.from(String(value ?? '')).slice(0, limit).join('');

export function clean(value = '') {
  return String(value).replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').replace(/<[^>]+>/g, ' ')
    .replace(/&#x27;|&#39;/gi, "'").replace(/&quot;/gi, '"').replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<').replace(/&gt;/gi, '>').replace(/&nbsp;/gi, ' ').replace(/\s+/g, ' ').trim();
}

const xmlTag = (xml, name) => clean((new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, 'i').exec(xml) || [, ''])[1]);
const xmlAttr = (xml, name, key) => (new RegExp(`<${name}[^>]+${key}=["']([^"']+)["']`, 'i').exec(xml) || [, ''])[1];

export function normalizeCanonicalUrl(value) {
  try {
    const parsed = new URL(String(value ?? '').trim());
    if (!/^https?:$/.test(parsed.protocol)) return '';
    parsed.hash = '';
    parsed.hostname = parsed.hostname.toLowerCase();
    if ((parsed.protocol === 'https:' && parsed.port === '443') || (parsed.protocol === 'http:' && parsed.port === '80')) parsed.port = '';
    for (const key of [...parsed.searchParams.keys()]) {
      const lower = key.toLowerCase();
      if (lower.startsWith('utm_') || TRACKING_PARAMS.has(lower)) parsed.searchParams.delete(key);
    }
    if (parsed.pathname.length > 1) parsed.pathname = parsed.pathname.replace(/\/+$/, '');
    return parsed.toString();
  } catch (_) { return ''; }
}

export function canonicalHash(value) {
  const normalized = normalizeCanonicalUrl(value);
  return normalized ? createHash('sha256').update(normalized).digest('hex') : '';
}

export function deterministicRowId(value) {
  const hash = canonicalHash(value);
  return hash ? `${hash.slice(0, 8)}-${hash.slice(8, 12)}-${hash.slice(12, 16)}-${hash.slice(16, 20)}-${hash.slice(20, 32)}` : '';
}

export function safeIsoDate(value, fallback = new Date()) {
  const date = value ? new Date(value) : fallback;
  return Number.isNaN(date.getTime()) ? fallback.toISOString() : date.toISOString();
}

export function validImageUrl(value) {
  try {
    const parsed = new URL(String(value ?? '').trim());
    return /^https?:$/.test(parsed.protocol) ? truncate(parsed.toString(), LIMITS.url) : '';
  } catch (_) { return ''; }
}

export function classify(text, fallback) {
  const value = clean(text).toLowerCase();
  if (/manga|manhwa|comic|graphic novel/.test(value)) return 'مانجا';
  if (/streaming|netflix|disney\+|hbo|max|prime video|paramount/.test(value)) return 'Streaming';
  if (/series|television|tv show|season/.test(value)) return 'مسلسلات';
  if (/drama|j-drama|k-drama/.test(value)) return 'دراما';
  if (/anime|animation|miyazaki|manga/.test(value)) return 'أنمي';
  if (/box office|award|oscar|emmy|golden globe/.test(value)) return 'أخبار مهمة';
  return fallback;
}

export function extractTags(text) {
  const value = clean(text).toLowerCase();
  return ['anime', 'manga', 'movie', 'series', 'streaming', 'award', 'box office']
    .filter((keyword) => value.includes(keyword)).slice(0, LIMITS.tags).map((keyword) => truncate(keyword, LIMITS.tag));
}

export function parseFeed(xml, source, now = new Date()) {
  const blocks = [...String(xml ?? '').matchAll(/<(item|entry)(?:\s[^>]*)?>([\s\S]*?)<\/(?:item|entry)>/gi)].map((match) => match[2]);
  return blocks.map((block) => {
    const rawUrl = clean(xmlTag(block, 'link') || xmlAttr(block, 'link', 'href'));
    const title = truncate(clean(xmlTag(block, 'title')), LIMITS.title);
    const canonicalUrl = normalizeCanonicalUrl(rawUrl);
    if (!rawUrl || !title || !canonicalUrl) return null;
    const summary = truncate(clean(xmlTag(block, 'description') || xmlTag(block, 'summary') || xmlTag(block, 'content')), LIMITS.summary);
    const image = validImageUrl(xmlAttr(block, 'media:content', 'url') || xmlAttr(block, 'media:thumbnail', 'url') || xmlAttr(block, 'enclosure', 'url'));
    const date = xmlTag(block, 'pubDate') || xmlTag(block, 'published') || xmlTag(block, 'updated');
    const text = `${title} ${summary}`;
    return {
      source: truncate(source.name, 128), sourceArticleId: truncate(rawUrl, LIMITS.url), sourceUrl: truncate(rawUrl, LIMITS.url),
      canonicalUrl: truncate(canonicalUrl, LIMITS.url), titleOriginal: title, summaryOriginal: summary, imageUrl: image,
      category: classify(text, source.category), tags: extractTags(text), publishedAt: safeIsoDate(date, now), fetchedAt: now.toISOString(),
    };
  }).filter(Boolean).slice(0, 30);
}

async function fetchText(url, attempts = 2) {
  let lastError;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await fetch(url, { headers: { accept: 'application/rss+xml, application/atom+xml, text/xml', 'user-agent': 'AniTV-NewsEngine/1.0' }, signal: AbortSignal.timeout(15000) });
      if (!response.ok) throw new Error(`feed ${response.status}`);
      return response.text();
    } catch (error) {
      lastError = error;
      if (attempt + 1 < attempts) await new Promise((resolve) => setTimeout(resolve, 250 * (attempt + 1)));
    }
  }
  throw lastError;
}

async function translate(text, title = false) {
  const fallback = truncate(clean(text), title ? LIMITS.title : LIMITS.summary);
  if (!config.translationUrl || !config.translationKey) return fallback;
  try {
    const response = await fetch(config.translationUrl, {
      method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${config.translationKey}` },
      body: JSON.stringify({ source: 'en', target: 'ar', text: fallback, instruction: title ? 'ترجم عنوان الخبر إلى عربية طبيعية مختصرة، وحافظ على أسماء الأعمال والشخصيات.' : 'ترجم أو أعد صياغة الملخص إلى عربية طبيعية مختصرة، ولا تضف معلومات غير موجودة.' }),
      signal: AbortSignal.timeout(20000),
    });
    if (!response.ok) throw new Error(`translation ${response.status}`);
    const body = await response.json();
    return truncate(clean(body.translation || body.text || body.output || '') || fallback, title ? LIMITS.title : LIMITS.summary);
  } catch (_) { return fallback; }
}

function safeInteger(value) {
  const number = typeof value === 'number' ? value : Number.parseInt(String(value ?? ''), 10);
  return Number.isSafeInteger(number) && number >= 0 ? number : 0;
}

function safeError(error) {
  return String(error?.message || error || 'unknown error')
    .replace(/(authorization|x-appwrite-key|api[_ -]?key|token|secret)\s*[:=]\s*[^\s,;]+/gi, '$1=[redacted]').slice(0, 300);
}

async function appwrite(method, path, body) {
  if (!config.apiKey || !config.projectId) throw new Error('Appwrite configuration is missing');
  const response = await fetch(`${config.endpoint}${path}`, {
    method, headers: { 'content-type': 'application/json', 'x-appwrite-project': config.projectId, 'x-appwrite-key': config.apiKey },
    body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) { const error = new Error(`Appwrite ${response.status}`); error.status = response.status; throw error; }
  return response.json();
}

async function listByCanonical(url) {
  const params = new URLSearchParams({ 'queries[]': JSON.stringify([`equal("canonicalUrl", "${url.replace(/"/g, '')}")`, 'limit(1)']) });
  const body = await appwrite('GET', `/tablesdb/${config.databaseId}/tables/${config.newsTableId}/rows?${params}`);
  return body.rows?.[0];
}

export async function upsert(item) {
  const existing = await listByCanonical(item.canonicalUrl);
  const translatedTitle = await translate(item.titleOriginal, true);
  const translatedSummary = await translate(item.summaryOriginal, false);
  const likeCount = safeInteger(existing?.data?.likeCount);
  const commentCount = safeInteger(existing?.data?.commentCount);
  const data = {
    ...item, titleOriginal: truncate(item.titleOriginal, LIMITS.title), summaryOriginal: truncate(item.summaryOriginal, LIMITS.summary),
    titleArabic: translatedTitle, summaryArabic: translatedSummary, translatedAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
    searchText: truncate(`${translatedTitle} ${translatedSummary} ${item.titleOriginal} ${item.source} ${item.category} ${item.tags.join(' ')}`, LIMITS.searchText),
    likeCount, commentCount, engagementScore: likeCount + commentCount * 2,
  };
  if (existing) return appwrite('PATCH', `/tablesdb/${config.databaseId}/tables/${config.newsTableId}/rows/${existing.$id}`, { data });
  const rowId = deterministicRowId(item.canonicalUrl);
  if (!rowId) throw new Error('Invalid canonical URL');
  try {
    return await appwrite('POST', `/tablesdb/${config.databaseId}/tables/${config.newsTableId}/rows`, { rowId, data });
  } catch (error) {
    if (error.status !== 409) throw error;
    const raced = await appwrite('GET', `/tablesdb/${config.databaseId}/tables/${config.newsTableId}/rows/${rowId}`);
    return appwrite('PATCH', `/tablesdb/${config.databaseId}/tables/${config.newsTableId}/rows/${raced.$id}`, { data });
  }
}

export async function run({ logger = () => {} } = {}) {
  const results = [];
  for (const source of sources) {
    if (!source.feed) { results.push({ source: source.id, skipped: true }); continue; }
    try {
      const items = parseFeed(await fetchText(source.feed), source);
      for (const item of items) {
        try { await upsert(item); results.push({ source: source.id, url: item.canonicalUrl, ok: true }); }
        catch (error) { logger(`News item failed for ${source.id}: ${safeError(error)}`); results.push({ source: source.id, url: item.canonicalUrl, ok: false, error: safeError(error) }); }
      }
    } catch (error) { logger(`News source failed for ${source.id}: ${safeError(error)}`); results.push({ source: source.id, ok: false, error: safeError(error) }); }
  }
  return results;
}

export default async ({ res, log }) => {
  try { const results = await run({ logger: (message) => log?.(message) }); log?.(`AniTV News Engine processed ${results.length} feed items.`); return res.json({ ok: true, results }); }
  catch (error) { log?.(`AniTV News Engine failed: ${safeError(error)}`); return res.json({ ok: false, error: 'News Engine failed' }, 500); }
};

if (process.env.RUN_NEWS_ENGINE === 'true') run({ logger: console.log }).then((result) => console.log(JSON.stringify(result))).catch((error) => { console.error(safeError(error)); process.exitCode = 1; });

export const testHelpers = { clean, normalizeCanonicalUrl, canonicalHash, deterministicRowId, safeIsoDate, validImageUrl, classify, extractTags, parseFeed, safeInteger };
export { sources, LIMITS };
