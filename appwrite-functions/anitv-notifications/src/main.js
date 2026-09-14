const { Client, ID, Messaging } = require('node-appwrite');

const json = (res, statusCode, body) => res.json(body, statusCode);
const required = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};
const errorDetails = (error) => ({
  code: error?.code ?? 'unknown',
  type: error?.type ?? 'unknown',
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

module.exports = async ({ req, res, log, error }) => {
  log('Notification request received');
  const payload = parseBody(req);
  const actorId = authenticatedUserId(req);
  const type = payload.type;
  const userId = typeof payload.userId === 'string' ? payload.userId.trim() : '';
  const title = typeof payload.title === 'string' ? payload.title.trim() : '';
  const message = typeof payload.message === 'string' ? payload.message.trim() : '';

  if (!actorId) {
    log('Unauthorized request');
    return json(res, 401, { ok: false, code: 'AUTHENTICATION_REQUIRED' });
  }
  if (!validText(title, 120) || !validText(message, 4096)) {
    return json(res, 400, { ok: false, code: 'INVALID_NOTIFICATION_CONTENT' });
  }
  if (type !== 'user' && type !== 'broadcast') {
    return json(res, 400, { ok: false, code: 'INVALID_TYPE' });
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

  const client = new Client()
    .setEndpoint(required('APPWRITE_ENDPOINT'))
    .setProject(required('APPWRITE_PROJECT_ID'))
    .setKey(required('APPWRITE_API_KEY'));
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
