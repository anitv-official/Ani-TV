const API_BASE = 'https://appswat.com/v2/api/v2';
const SOURCE_ID = 'swat';
const MAX_PAGES = 80;

const numberFrom = (value) => {
  const match = String(value ?? '').match(/\d+(?:\.\d+)?/);
  if (!match) return null;
  const number = Number(match[0]);
  return Number.isFinite(number) ? number : null;
};

const canonicalNumber = (number) => Number.isInteger(number)
  ? String(number)
  : String(number).replace(/0+$/, '').replace(/\.$/, '');

const seriesIdFrom = (itemId) => {
  const match = /^swat:\/\/series\/(\d+)(?:\/[^/?#]*)?(?:[?#].*)?$/i.exec(String(itemId || '').trim());
  return match?.[1] || null;
};

const supports = (source, itemId) => {
  const sourceId = String(source || '').trim().toLowerCase();
  return (sourceId === SOURCE_ID || !sourceId) && seriesIdFrom(itemId) !== null;
};

const pageUrl = (seriesId) => `${API_BASE}/series/${encodeURIComponent(seriesId)}/chapters/`;

const validNextUrl = (value) => {
  if (!value || value === 'null') return null;
  try {
    const parsed = new URL(String(value), API_BASE);
    if (parsed.protocol !== 'https:' || parsed.hostname !== 'appswat.com') return null;
    return parsed.toString();
  } catch (_) {
    return null;
  }
};

const chapterFrom = (raw) => {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const id = String(raw.id ?? '').trim();
  if (!id) return null;
  const rawChapter = String(raw.chapter ?? '').trim();
  const rawTitle = String(raw.title ?? '').trim();
  const number = numberFrom(rawChapter || rawTitle);
  if (number === null) return null;
  const numberText = canonicalNumber(number);
  const publishedAt = String(raw.publishedAt ?? raw.updatedAt ?? raw.createdAt ?? '').trim();
  const publishedTimestamp = publishedAt ? Date.parse(publishedAt) : Number.NaN;
  return {
    id,
    number,
    numberText,
    title: rawTitle || `الفصل ${numberText}`,
    releaseKey: `swat:chapter:${id}`,
    publishedTimestamp: Number.isFinite(publishedTimestamp) ? publishedTimestamp : null,
    raw,
  };
};

const compareChapters = (left, right) => {
  if (left.number !== right.number) return left.number - right.number;
  if ((left.publishedTimestamp ?? -Infinity) !== (right.publishedTimestamp ?? -Infinity)) {
    return (left.publishedTimestamp ?? -Infinity) - (right.publishedTimestamp ?? -Infinity);
  }
  return left.id.localeCompare(right.id);
};

const parsePage = (body) => {
  if (!body || typeof body !== 'object' || Array.isArray(body) || !Array.isArray(body.results)) {
    throw new Error('Manga Swat API malformed chapters response');
  }
  const chapters = body.results.map(chapterFrom).filter(Boolean);
  return { chapters, next: validNextUrl(body.next) };
};

const fetchPage = async (url) => {
  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'AniTV-Favorite-Scanner/1.0',
    },
  });
  if (!response.ok) throw new Error(`Manga Swat API HTTP ${response.status}`);
  let body;
  try {
    body = await response.json();
  } catch (_) {
    throw new Error('Manga Swat API returned invalid JSON');
  }
  return parsePage(body);
};

async function latestChapter({ source, itemId }) {
  if (!supports(source, itemId)) return null;
  const seriesId = seriesIdFrom(itemId);
  let next = pageUrl(seriesId);
  const chapters = [];
  let pages = 0;
  while (next && pages < MAX_PAGES) {
    pages += 1;
    const page = await fetchPage(next);
    chapters.push(...page.chapters);
    next = page.next;
  }
  if (next) throw new Error(`Manga Swat API pagination exceeded ${MAX_PAGES} pages`);
  if (chapters.length === 0) return null;
  chapters.sort(compareChapters);
  const latest = chapters.at(-1);
  return {
    id: latest.id,
    number: latest.numberText,
    kind: 'chapter',
    releaseKey: latest.releaseKey,
    title: latest.title,
    url: `swat://chapter/${encodeURIComponent(latest.id)}`,
  };
}

module.exports = {
  id: SOURCE_ID,
  supports,
  latestChapter,
  parsePage,
  chapterFrom,
  compareChapters,
};
