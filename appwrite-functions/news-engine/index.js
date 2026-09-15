import { randomUUID } from 'node:crypto';

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

const clean = (value = '') => value.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').replace(/<[^>]+>/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&#39;/g, "'").replace(/&quot;/g, '"').replace(/\s+/g, ' ').trim();
const tag = (xml, name) => clean((new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, 'i').exec(xml) || [,''])[1]);
const attr = (xml, name, key) => (new RegExp(`<${name}[^>]+${key}=["']([^"']+)["']`, 'i').exec(xml) || [,''])[1];

async function fetchText(url) {
  const response = await fetch(url, { headers: { accept: 'application/rss+xml, application/atom+xml, text/xml', 'user-agent': 'AniTV-NewsEngine/1.0' }, signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw new Error(`${response.status} ${url}`);
  return response.text();
}

function parseFeed(xml, source) {
  const blocks = [...xml.matchAll(/<(item|entry)(?:\s[^>]*)?>([\s\S]*?)<\/(?:item|entry)>/gi)].map(m => m[2]);
  return blocks.map(block => {
    const url = tag(block, 'link') || attr(block, 'link', 'href');
    const title = tag(block, 'title');
    const summary = tag(block, 'description') || tag(block, 'summary') || tag(block, 'content');
    const image = attr(block, 'media:content', 'url') || attr(block, 'media:thumbnail', 'url') || attr(block, 'enclosure', 'url');
    const date = tag(block, 'pubDate') || tag(block, 'published') || tag(block, 'updated');
    if (!url || !title) return null;
    return { source: source.name, sourceArticleId: url, sourceUrl: url, canonicalUrl: url.split('#')[0], titleOriginal: title, summaryOriginal: summary.slice(0, 600), imageUrl: image, category: classify(`${title} ${summary}`, source.category), tags: tags(`${title} ${summary}`), publishedAt: new Date(date || Date.now()).toISOString(), fetchedAt: new Date().toISOString() };
  }).filter(Boolean).slice(0, 30);
}

function classify(text, fallback) {
  const value = text.toLowerCase();
  if (/manga|manhwa|comic|graphic novel/.test(value)) return 'مانجا';
  if (/streaming|netflix|disney\+|hbo|max|prime video|paramount/.test(value)) return 'Streaming';
  if (/series|television|tv show|season/.test(value)) return 'مسلسلات';
  if (/drama|j-drama|k-drama/.test(value)) return 'دراما';
  if (/anime|animation|miyazaki|manga/.test(value)) return 'أنمي';
  if (/box office|award|oscar|emmy|golden globe/.test(value)) return 'أخبار مهمة';
  return fallback;
}
function tags(text) { return ['anime','manga','movie','series','streaming','award','box office'].filter(k => text.toLowerCase().includes(k)); }

async function translate(text, title = false) {
  if (!config.translationUrl || !config.translationKey) return text;
  const response = await fetch(config.translationUrl, { method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${config.translationKey}` }, body: JSON.stringify({ source: 'en', target: 'ar', text, instruction: title ? 'ترجم عنوان الخبر إلى عربية طبيعية مختصرة، وحافظ على أسماء الأعمال والشخصيات.' : 'ترجم أو أعد صياغة الملخص إلى عربية طبيعية مختصرة، ولا تضف معلومات غير موجودة.' }), signal: AbortSignal.timeout(20000) });
  if (!response.ok) throw new Error(`translation ${response.status}`);
  const body = await response.json();
  return body.translation || body.text || body.output || text;
}

async function appwrite(method, path, body) {
  if (!config.apiKey || !config.projectId) throw new Error('APPWRITE_API_KEY and APPWRITE_PROJECT_ID are required');
  const response = await fetch(`${config.endpoint}${path}`, { method, headers: { 'content-type': 'application/json', 'x-appwrite-project': config.projectId, 'x-appwrite-key': config.apiKey }, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw new Error(`Appwrite ${response.status}: ${await response.text()}`);
  return response.json();
}
async function listByCanonical(url) {
  const params = new URLSearchParams({ 'queries[]': JSON.stringify([`equal("canonicalUrl", "${url.replace(/"/g, '')}")`, 'limit(1)']) });
  const body = await appwrite('GET', `/tablesdb/${config.databaseId}/tables/${config.newsTableId}/rows?${params}`);
  return body.rows?.[0];
}
async function upsert(item) {
  const existing = await listByCanonical(item.canonicalUrl);
  const translatedTitle = await translate(item.titleOriginal, true);
  const translatedSummary = await translate(item.summaryOriginal, false);
  const data = { ...item, titleArabic: translatedTitle, summaryArabic: translatedSummary, translatedAt: new Date().toISOString(), updatedAt: new Date().toISOString(), searchText: `${translatedTitle} ${translatedSummary} ${item.titleOriginal} ${item.source} ${item.category} ${item.tags.join(' ')}`, likeCount: existing?.data?.likeCount || 0, commentCount: existing?.data?.commentCount || 0, engagementScore: (existing?.data?.likeCount || 0) + (existing?.data?.commentCount || 0) * 2 };
  if (existing) return appwrite('PATCH', `/tablesdb/${config.databaseId}/tables/${config.newsTableId}/rows/${existing.$id}`, { data });
  return appwrite('POST', `/tablesdb/${config.databaseId}/tables/${config.newsTableId}/rows`, { rowId: randomUUID(), data });
}

export async function run() {
  const results = [];
  for (const source of sources) {
    if (!source.feed) { results.push({ source: source.id, skipped: true }); continue; }
    try { const items = parseFeed(await fetchText(source.feed), source); for (const item of items) { try { await upsert(item); results.push({ source: source.id, url: item.canonicalUrl, ok: true }); } catch (error) { results.push({ source: source.id, url: item.canonicalUrl, ok: false, error: error.message }); } } }
    catch (error) { results.push({ source: source.id, ok: false, error: error.message }); }
  }
  return results;
}

export default async ({ res, log }) => {
  try {
    const results = await run();
    log?.(`AniTV News Engine processed ${results.length} feed items.`);
    return res.json({ ok: true, results });
  } catch (error) {
    log?.(`AniTV News Engine failed: ${error.message}`);
    return res.json({ ok: false, error: error.message }, 500);
  }
};

if (process.env.RUN_NEWS_ENGINE === 'true') run().then(result => console.log(JSON.stringify(result))).catch(error => { console.error(error); process.exitCode = 1; });
