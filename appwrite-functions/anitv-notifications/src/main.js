const crypto = require('node:crypto');
const { Client, ID, Messaging, TablesDB, Query } = require('node-appwrite');
const anime4up = require('./adapters/anime4up');
const faselhd = require('./adapters/faselhd');

const FAVORITES_DATABASE_ID = '6aa58db9001a5f53312d';
const FAVORITES_COLLECTION_ID = '6aa58e3a003b23556872';
const SUPABASE_URL = () => String(process.env.SUPABASE_URL || '').replace(/\/$/, '');
const SUPABASE_KEY = () => String(process.env.SUPABASE_SERVICE_ROLE_KEY || '');

const json = (res, statusCode, body) => res.json(body, statusCode);
const required = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};
const runtimeAppwriteKey = (req) => {
  // Appwrite provides this dynamic key automatically to Function executions.
  // The explicit API-key fallback is retained only for local/custom runners.
  return process.env.APPWRITE_FUNCTION_API_KEY
    || req.headers?.['x-appwrite-key']
    || req.headers?.['X-Appwrite-Key']
    || process.env.APPWRITE_API_KEY
    || '';
};
const appwriteClient = (req) => {
  const key = runtimeAppwriteKey(req);
  if (!key) throw new Error('Missing Appwrite Function execution key');
  return new Client()
    .setEndpoint(required('APPWRITE_ENDPOINT'))
    .setProject(required('APPWRITE_PROJECT_ID'))
    .setKey(key);
};
const errorDetails = (error) => ({
  code: error?.code ?? 'unknown',
  type: error?.type ?? 'unknown',
  message: String(error?.message ?? 'Unknown Appwrite error').replace(/\s+/g, ' ').slice(0, 240),
});
const parseBody = (req) => {
  if (req.bodyJson && typeof req.bodyJson === 'object') return req.bodyJson;
  try { return JSON.parse(req.body || '{}'); } catch (_) { return {}; }
};
const authenticatedUserId = (req) => String(
  req.headers?.['x-appwrite-user-id'] ?? req.headers?.['X-Appwrite-User-Id'] ?? '',
).trim();
const adminIds = () => new Set(
  String(process.env.ANITV_ADMIN_USER_IDS || '')
    .split(',').map((value) => value.trim()).filter(Boolean),
);
const validText = (value, max) => typeof value === 'string' && value.trim().length > 0 && value.trim().length <= max;
const requestMethod = (req) => String(req.method ?? 'POST').toUpperCase();
const header = (req, name) => {
  const headers = req.headers || {};
  return String(headers[name] ?? headers[name.toLowerCase()] ?? headers[name.toUpperCase()] ?? '').trim();
};
const sameSecret = (provided, expected) => {
  if (!provided || !expected) return false;
  const left = Buffer.from(provided);
  const right = Buffer.from(expected);
  return left.length === right.length && crypto.timingSafeEqual(left, right);
};
const supabaseConfigured = () => Boolean(SUPABASE_URL() && SUPABASE_KEY());
const supabaseRequest = async (path, options = {}) => {
  if (!supabaseConfigured()) return null;
  const response = await fetch(`${SUPABASE_URL()}/rest/v1/${path}`, {
    ...options,
    headers: { apikey: SUPABASE_KEY(), Authorization: `Bearer ${SUPABASE_KEY()}`, 'Content-Type': 'application/json', ...(options.headers || {}) },
  });
  if (!response.ok) throw new Error(`Supabase HTTP ${response.status}`);
  return response.status === 204 ? null : response.json();
};
const claimDelivery = async ({ userId, source, itemId, type, number }) => {
  if (!supabaseConfigured()) return true;
  const dedupeKey = [userId, source, itemId, type, number].join('|');
  const encoded = encodeURIComponent(dedupeKey);
  const existing = await supabaseRequest(`notification_deliveries?dedupe_key=eq.${encoded}&select=status&limit=1`);
  if (Array.isArray(existing) && existing.length > 0) {
    if (existing[0].status === 'sent' || existing[0].status === 'pending') return false;
    await supabaseRequest(`notification_deliveries?dedupe_key=eq.${encoded}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ status: 'pending', attempts: 0, last_error: null }) });
    return true;
  }
  await supabaseRequest('notification_deliveries', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ dedupe_key: dedupeKey, user_id: userId, source, item_id: itemId, type, content_number: String(number), status: 'pending' }) });
  return true;
};
const saveHistory = async ({ userId, title, body, type, itemId, source, payload }) => {
  if (!supabaseConfigured()) return;
  await supabaseRequest('notification_history', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ user_id: userId, title, body, type, item_id: itemId, source, url: itemId, payload }) });
};

const sourceAdapter = (favorite) => {
  const source = String(favorite.source || '').trim().toLowerCase();
  const itemId = String(favorite.itemId || '').trim();
  if (anime4up.supports(source, itemId)) return anime4up;
  if (faselhd.supports(source, itemId)) return faselhd;
  return null;
};

async function withRetry(operation, attempts, waitMs = 250) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try { return await operation(); } catch (error) {
      lastError = error;
      if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, waitMs * attempt));
    }
  }
  throw lastError;
}

async function runFavoriteScan({ rows, messaging, payload, log, error }) {
  const dryRun = payload.dryRun === true;
  const result = { scanned: 0, checked: 0, notified: 0, initialized: 0, skipped: 0, unsupported: 0, errors: 0, dryRun };
  log(`favorite scan started; dryRun=${dryRun}; supabase=${supabaseConfigured()}`);
  let cursor;
  const pageSize = 100;
  do {
    const queries = [Query.limit(pageSize)];
    if (cursor) queries.push(Query.cursorAfter(cursor));
    let documents;
    try {
      documents = await rows.listRows({ databaseId: FAVORITES_DATABASE_ID, tableId: FAVORITES_COLLECTION_ID, queries });
    } catch (readError) {
      const details = errorDetails(readError);
      error(`favorite rows read failed; code=${details.code}; type=${details.type}; message=${details.message}`);
      throw readError;
    }
    const page = documents.rows || [];
    result.scanned += page.length;
    log(`favorites page read; count=${page.length}; total=${result.scanned}`);
    for (const document of page) {
      const favorite = document || {};
      const userId = String(favorite.userId || '').trim();
      const itemId = String(favorite.itemId || '').trim();
      const title = String(favorite.title || 'AniTV').trim() || 'AniTV';
      const adapter = sourceAdapter(favorite);
      if (!userId || !itemId || !adapter) {
        result.unsupported += 1;
        continue;
      }
      result.checked += 1;
      try {
        const latest = await withRetry(() => adapter.latestEpisode({ source: favorite.source, itemId }), 2);
        const checkedAt = new Date().toISOString();
        if (!latest) {
          if (!dryRun) await rows.updateRow({ databaseId: FAVORITES_DATABASE_ID, tableId: FAVORITES_COLLECTION_ID, rowId: document.$id, data: { lastCheckedAt: checkedAt } });
          result.skipped += 1;
          continue;
        }
        const current = String(latest.number);
        const previous = String(favorite.lastNotifiedEpisode || '').trim();
        if (!previous) {
          if (!dryRun) await rows.updateRow({ databaseId: FAVORITES_DATABASE_ID, tableId: FAVORITES_COLLECTION_ID, rowId: document.$id, data: { lastNotifiedEpisode: current, lastCheckedAt: checkedAt } });
          result.initialized += 1;
          continue;
        }
        if (Number(latest.number) <= Number(previous)) {
          if (!dryRun) await rows.updateRow({ databaseId: FAVORITES_DATABASE_ID, tableId: FAVORITES_COLLECTION_ID, rowId: document.$id, data: { lastCheckedAt: checkedAt } });
          result.skipped += 1;
          continue;
        }
        const notificationType = String(favorite.contentType || favorite.type || 'anime').toLowerCase().includes('chapter') ? 'chapter' : 'episode';
        const source = String(favorite.source || adapter.id);
        const notificationPayload = { type: notificationType, itemId, url: itemId, title, source, episode: current };
        if (!dryRun) {
          const claimed = await claimDelivery({ userId, source, itemId, type: notificationType, number: current });
          if (!claimed) { result.skipped += 1; continue; }
          try {
            await withRetry(() => messaging.createPush({ messageId: ID.unique(), users: [userId], title: `حلقة جديدة: ${title}`, body: `تمت إضافة الحلقة ${current}`, data: notificationPayload, priority: 'high' }), 2);
            await saveHistory({ userId, title: `حلقة جديدة: ${title}`, body: `تمت إضافة الحلقة ${current}`, type: notificationType, itemId, source, payload: notificationPayload });
          } catch (deliveryError) {
            if (supabaseConfigured()) await supabaseRequest(`notification_deliveries?dedupe_key=eq.${encodeURIComponent([userId, source, itemId, notificationType, current].join('|'))}`, { method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ status: 'failed', attempts: 1, last_error: String(deliveryError.message || '').slice(0, 240) }) });
            throw deliveryError;
          }
          await rows.updateRow({ databaseId: FAVORITES_DATABASE_ID, tableId: FAVORITES_COLLECTION_ID, rowId: document.$id, data: { lastNotifiedEpisode: current, lastCheckedAt: checkedAt } });
        }
        result.notified += 1;
      } catch (scanError) {
        result.errors += 1;
        error(`favorite source error; document=${document.$id}; type=${scanError?.name || 'unknown'}; message=${String(scanError?.message || '').slice(0, 160)}`);
      }
    }
    cursor = page.length === pageSize ? page.at(-1)?.$id : null;
  } while (cursor);
  log(`favorite scan completed; scanned=${result.scanned}; checked=${result.checked}; notified=${result.notified}; errors=${result.errors}`);
  return result;
}
module.exports = async ({ req, res, log, error }) => {
  log('Notification request received');
  if (requestMethod(req) !== 'POST') {
    return json(res, 405, { ok: false, code: 'METHOD_NOT_ALLOWED', expected: 'POST' });
  }
  const payload = parseBody(req);
  const actorId = authenticatedUserId(req);
  const type = payload.type;
  const userId = typeof payload.userId === 'string' ? payload.userId.trim() : '';
  const title = typeof payload.title === 'string' ? payload.title.trim() : '';
  const message = typeof payload.message === 'string' ? payload.message.trim() : '';

  // Safe Appwrite Console smoke test. It never sends a notification and does
  // not bypass authentication for the real user/broadcast paths below.
  if (payload.type === 'health') {
    return json(res, 200, { ok: true, service: 'anitv-notifications', entrypoint: 'src/main.js' });
  }

  if (type === 'favorite_scan') {
    const expectedSecret = process.env.ANITV_FAVORITE_SCAN_SECRET;
    if (!expectedSecret) return json(res, 503, { ok: false, code: 'SCAN_NOT_CONFIGURED' });
    if (!sameSecret(header(req, 'x-anitv-favorite-scan-secret'), expectedSecret)) {
      return json(res, 403, { ok: false, code: 'INVALID_SCAN_SECRET' });
    }
    try {
      log('favorite scan: checking required environment variables');
      const requiredNames = ['APPWRITE_ENDPOINT', 'APPWRITE_PROJECT_ID', 'ANITV_FAVORITE_SCAN_SECRET'];
      const missing = requiredNames.filter((name) => !process.env[name]);
      if (!runtimeAppwriteKey(req)) missing.push('APPWRITE_FUNCTION_API_KEY');
      log(`favorite scan: environment presence checked; missing=${missing.length}`);
      if (missing.length > 0) return json(res, 503, { ok: false, code: 'SCAN_NOT_CONFIGURED', missing });
      log('favorite scan: initializing appwrite client');
      const client = appwriteClient(req);
      log('favorite scan: appwrite client ready');
      log('favorite scan: initializing tables api');
      const rows = new TablesDB(client);
      log('favorite scan: tables api ready');
      log('favorite scan: messaging api ready');
      return json(res, 200, { ok: true, type, ...(await runFavoriteScan({ rows, messaging: new Messaging(client), payload, log, error })) });
    } catch (scanError) {
      const details = errorDetails(scanError);
      error(`favorite scan failed; code=${details.code}; type=${details.type}; message=${details.message}`);
      return json(res, 502, { ok: false, code: 'SCAN_FAILED', error: { code: details.code, type: details.type, message: details.message } });
    }
  }

  if (!actorId) {
    log('Unauthorized request');
    return json(res, 401, { ok: false, code: 'AUTHENTICATION_REQUIRED' });
  }
  if (!validText(title, 120) || !validText(message, 4096)) {
    return json(res, 400, { ok: false, code: 'INVALID_NOTIFICATION_CONTENT', required: ['title', 'message'] });
  }
  if (type !== 'user' && type !== 'broadcast') {
    return json(res, 400, { ok: false, code: 'INVALID_TYPE', allowed: ['user', 'broadcast', 'health'] });
  }

  const admins = adminIds();
  if (type === 'broadcast' && !admins.has(actorId)) {
    log('Unauthorized broadcast request');
    return json(res, 403, { ok: false, code: 'ADMIN_REQUIRED' });
  }
  if (type === 'user' && (!userId || userId !== actorId) && !admins.has(actorId)) {
    log('Unauthorized user target request');
    return json(res, 403, { ok: false, code: 'TARGET_NOT_ALLOWED' });
  }
  if (type === 'user' && !userId) return json(res, 400, { ok: false, code: 'USER_ID_REQUIRED' });

  const client = appwriteClient(req);
  const messaging = new Messaging(client);
  const data = {};
  if (payload.data && typeof payload.data === 'object' && !Array.isArray(payload.data)) {
    for (const [key, value] of Object.entries(payload.data)) {
      if (typeof key === 'string' && key.length <= 64 && (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean')) {
        data[key] = String(value);
      }
    }
  }

  const params = {
    messageId: ID.unique(),
    title,
    body: message,
    data,
    priority: 'high',
  };
  if (type === 'user') {
    params.users = [userId];
  } else {
    const topicId = required('ANITV_BROADCAST_TOPIC_ID');
    params.topics = [topicId];
  }

  try {
    const result = await messaging.createPush(params);
    log('Notification sent successfully');
    return json(res, 200, { ok: true, messageId: result.$id, type });
  } catch (err) {
    const details = errorDetails(err);
    error(`Notification send failed; code=${details.code}; type=${details.type}`);
    return json(res, 502, { ok: false, code: 'DELIVERY_FAILED' });
  }
};

// Exported only to support local mock tests; Appwrite still invokes the
// default function above and no credentials are exposed by these helpers.
module.exports.runFavoriteScan = runFavoriteScan;
