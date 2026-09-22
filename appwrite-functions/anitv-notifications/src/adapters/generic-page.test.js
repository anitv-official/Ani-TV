const test = require('node:test');
const assert = require('node:assert/strict');
const adapter = require('./generic-page');

test('supports all configured content types with absolute item URLs', () => {
  for (const type of ['anime', 'manga', 'comic', 'movie', 'series', 'drama']) {
    assert.equal(adapter.supports('source', 'https://example.test/item', type), true);
  }
  assert.equal(adapter.supports('source', 'not-a-url', 'anime'), false);
  assert.equal(adapter.supports('source', 'https://example.test/item', 'unknown'), false);
});

test('extracts the latest episode marker from a page', async () => {
  const previousFetch = global.fetch;
  global.fetch = async () => ({ ok: true, text: async () => '<html>الحلقة 12 ثم Episode 13</html>' });
  try {
    const release = await adapter.latestRelease({ source: 'anime', itemId: 'https://example.test/anime', type: 'anime' });
    assert.deepEqual(release, { key: '13', number: '13', kind: 'episode' });
  } finally {
    global.fetch = previousFetch;
  }
});

test('extracts chapter markers and release dates', async () => {
  const previousFetch = global.fetch;
  global.fetch = async () => ({ ok: true, text: async () => '<time datetime="2026-09-22T10:00:00Z"></time> الفصل 8' });
  try {
    const chapter = await adapter.latestRelease({ source: 'manga', itemId: 'https://example.test/manga', type: 'manga' });
    assert.equal(chapter.kind, 'chapter');
    assert.equal(chapter.number, '8');
  } finally {
    global.fetch = previousFetch;
  }
});
