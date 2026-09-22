const test = require('node:test');
const assert = require('node:assert/strict');
const adapter = require('./anime3rb');

const response = (status, body, headers = {}) => ({
  status,
  ok: status >= 200 && status < 300,
  headers: { get: (name) => headers[name.toLowerCase()] || null },
  text: async () => body,
});

test('extracts and sorts Anime3rb episode links from HTML', () => {
  const episodes = adapter.extractEpisodes(`
    <a href="/episode/show/12"><span>الحلقة 12</span></a>
    <a href="/episode/show/2">الحلقة 2</a>
    <a href="/episode/show/1">الحلقة 1</a>
  `, 'https://anime3rb.com/titles/show');
  assert.deepEqual(episodes.map((episode) => episode.number), [1, 2, 12]);
});

test('uses the public reader fallback after a Cloudflare challenge', async () => {
  const previousFetch = global.fetch;
  const calls = [];
  global.fetch = async (url) => {
    calls.push(String(url));
    if (calls.length === 1) return response(403, 'challenge', { 'cf-mitigated': 'challenge' });
    return response(200, '[الحلقة 12](https://anime3rb.com/episode/show/12)');
  };
  try {
    const latest = await adapter.latestEpisode({ source: 'anime3rb', itemId: 'https://anime3rb.com/titles/show' });
    assert.equal(latest.number, 12);
    assert.match(calls[1], /^https:\/\/r\.jina\.ai\/http:\/\/anime3rb\.com/);
  } finally {
    global.fetch = previousFetch;
  }
});

test('does not claim non-Anime3rb URLs', () => {
  assert.equal(adapter.supports('anime3rb', 'https://example.com/titles/show'), false);
});
