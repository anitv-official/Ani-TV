const test = require('node:test');
const assert = require('node:assert/strict');
const adapter = require('./manga-swat');

const response = (status, body) => ({
  status,
  ok: status >= 200 && status < 300,
  json: async () => body,
});

test('parses valid Manga Swat chapter pages', () => {
  const page = adapter.parsePage({
    results: [
      { id: 42, chapter: '3.5', title: 'الفصل 3.5' },
      { id: 41, chapter: '3', title: 'الفصل 3' },
    ],
    next: null,
  });
  assert.equal(page.chapters.length, 2);
  assert.equal(page.chapters[0].number, 3.5);
  assert.equal(page.chapters[0].releaseKey, 'swat:chapter:42');
});

test('selects the highest chapter independently of API ordering', async () => {
  const previousFetch = global.fetch;
  const pages = [
    { results: [{ id: 90, chapter: '10' }, { id: 120, chapter: '12' }], next: null },
  ];
  global.fetch = async () => response(200, pages.shift());
  try {
    const latest = await adapter.latestChapter({ source: 'swat', itemId: 'swat://series/7/example' });
    assert.deepEqual(latest, {
      id: '120',
      number: '12',
      kind: 'chapter',
      releaseKey: 'swat:chapter:120',
      title: 'الفصل 12',
      url: 'swat://chapter/120',
    });
  } finally {
    global.fetch = previousFetch;
  }
});

test('releaseKey is stable when page order changes', async () => {
  const previousFetch = global.fetch;
  let call = 0;
  global.fetch = async () => {
    call += 1;
    const results = call === 1
      ? [{ id: 200, chapter: '2' }, { id: 201, chapter: '3' }]
      : [{ id: 201, chapter: '3' }, { id: 200, chapter: '2' }];
    return response(200, { results, next: null });
  };
  try {
    const first = await adapter.latestChapter({ source: 'swat', itemId: 'swat://series/7/example' });
    const second = await adapter.latestChapter({ source: 'swat', itemId: 'swat://series/7/example' });
    assert.equal(first.releaseKey, 'swat:chapter:201');
    assert.equal(second.releaseKey, first.releaseKey);
  } finally {
    global.fetch = previousFetch;
  }
});

test('follows pagination and chooses the latest chapter across pages', async () => {
  const previousFetch = global.fetch;
  const calls = [];
  global.fetch = async (url) => {
    calls.push(url);
    return calls.length === 1
      ? response(200, { results: [{ id: 1, chapter: '1' }], next: 'https://appswat.com/v2/api/v2/series/7/chapters/?page=2' })
      : response(200, { results: [{ id: 2, chapter: '2' }], next: null });
  };
  try {
    const latest = await adapter.latestChapter({ source: 'swat', itemId: 'swat://series/7/example' });
    assert.equal(latest.releaseKey, 'swat:chapter:2');
    assert.equal(calls.length, 2);
  } finally {
    global.fetch = previousFetch;
  }
});

test('fails closed on malformed API response', async () => {
  const previousFetch = global.fetch;
  global.fetch = async () => response(200, { results: 'not-an-array' });
  try {
    await assert.rejects(
      adapter.latestChapter({ source: 'swat', itemId: 'swat://series/7/example' }),
      /malformed chapters response/,
    );
  } finally {
    global.fetch = previousFetch;
  }
});

test('fails closed on API failure', async () => {
  const previousFetch = global.fetch;
  global.fetch = async () => response(503, { detail: 'temporarily unavailable' });
  try {
    await assert.rejects(
      adapter.latestChapter({ source: 'swat', itemId: 'swat://series/7/example' }),
      /HTTP 503/,
    );
  } finally {
    global.fetch = previousFetch;
  }
});

test('rejects invalid Favorites without calling the API', async () => {
  const previousFetch = global.fetch;
  let called = false;
  global.fetch = async () => { called = true; return response(200, { results: [] }); };
  try {
    assert.equal(adapter.supports('swat', 'https://appswat.com/series/7'), false);
    assert.equal(adapter.supports('swat', 'swat://chapter/7'), false);
    assert.equal(await adapter.latestChapter({ source: 'swat', itemId: 'swat://chapter/7' }), null);
    assert.equal(called, false);
  } finally {
    global.fetch = previousFetch;
  }
});
