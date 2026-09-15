import test from 'node:test';
import assert from 'node:assert/strict';
import { classify, deterministicRowId, extractTags, normalizeCanonicalUrl, parseFeed, safeIsoDate, validImageUrl } from './index.js';

test('normalizes tracking parameters, fragments, host casing, and trailing slash', () => {
  assert.equal(normalizeCanonicalUrl('HTTPS://Example.COM/news/item/?utm_source=x&keep=1#top'), 'https://example.com/news/item?keep=1');
});

test('creates a stable UUID-shaped deduplication row id', () => {
  const first = deterministicRowId('https://example.com/news/item');
  assert.equal(first, deterministicRowId('https://example.com/news/item#fragment'));
  assert.match(first, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
});

test('handles invalid dates with a valid fallback', () => {
  assert.equal(safeIsoDate('not-a-date', new Date('2026-01-01T00:00:00Z')), '2026-01-01T00:00:00.000Z');
});

test('skips feed entries without title or link and parses valid RSS entries', () => {
  const xml = '<rss><channel><item><title><![CDATA[Valid News]]></title><link>https://example.com/news/1</link><description><![CDATA[<p>Short summary</p>]]></description><pubDate>not-a-date</pubDate></item><item><title>No link</title></item></channel></rss>';
  const items = parseFeed(xml, { name: 'Test', category: 'أنمي' }, new Date('2026-01-01T00:00:00Z'));
  assert.equal(items.length, 1);
  assert.equal(items[0].titleOriginal, 'Valid News');
  assert.equal(items[0].publishedAt, '2026-01-01T00:00:00.000Z');
});

test('classifies and extracts existing categories and tags', () => {
  assert.equal(classify('A new anime streaming series', 'أخبار مهمة'), 'Streaming');
  assert.deepEqual(extractTags('anime streaming award'), ['anime', 'streaming', 'award']);
});

test('rejects invalid image URLs without failing the item', () => {
  assert.equal(validImageUrl('javascript:alert(1)'), '');
  assert.equal(validImageUrl('https://cdn.example.com/poster.jpg'), 'https://cdn.example.com/poster.jpg');
});
