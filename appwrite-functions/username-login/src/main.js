const { Client, Account, Databases, Query, Users } = require('node-appwrite');

const json = (res, statusCode, body) => res.json(body, statusCode);
const invalidCredentials = (res) => json(res, 401, {
  ok: false,
  code: 'INVALID_CREDENTIALS',
  message: 'Invalid username or password.',
});
const serverError = (res, code = 'SERVER_ERROR') => json(res, 500, {
  ok: false,
  code,
  message: 'Unable to sign in right now.',
});

const required = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};

const normalizeUsername = (value) => value.trim().toLowerCase();
const maskEmail = (email) => {
  if (typeof email !== 'string' || !email.includes('@')) return '[missing]';
  const [local, domain] = email.split('@');
  return `${local.slice(0, 1)}***@${domain}`;
};
const errorDetails = (err) => ({
  code: err?.code ?? 'unknown',
  type: err?.type ?? 'unknown',
  message: String(err?.message ?? 'unknown').replace(/[\r\n]/g, ' ').slice(0, 240),
});

module.exports = async ({ req, res, log, error }) => {
  let username = '';
  try {
    log('request started');
    const payload = req.bodyJson && typeof req.bodyJson === 'object'
      ? req.bodyJson
      : (() => {
          try { return JSON.parse(req.body || '{}'); } catch (_) { return {}; }
        })();
    username = typeof payload.username === 'string' ? normalizeUsername(payload.username) : '';
    const password = typeof payload.password === 'string' ? payload.password : '';
    log(`username normalized: ${username || '[empty]'}`);

    if (!username || !password) {
      return json(res, 400, { ok: false, code: 'INVALID_INPUT', message: 'Username and password are required.' });
    }
    if (!/^[a-z0-9_]{3,24}$/.test(username)) {
      return json(res, 400, { ok: false, code: 'INVALID_USERNAME', message: 'Invalid username.' });
    }

    const adminClient = new Client()
      .setEndpoint(required('APPWRITE_ENDPOINT'))
      .setProject(required('APPWRITE_PROJECT_ID'))
      .setKey(required('APPWRITE_API_KEY'));
    const databases = new Databases(adminClient);

    let result;
    try {
      result = await databases.listDocuments(
        required('APPWRITE_DATABASE_ID'),
        required('APPWRITE_PROFILES_TABLE_ID'),
        [Query.limit(5000)],
      );
    } catch (err) {
      const details = errorDetails(err);
      error(`profile lookup failed; code=${details.code}; type=${details.type}; message=${details.message}`);
      return serverError(res, 'PROFILE_ERROR');
    }

    // Query.equal is case-sensitive in Appwrite. Normalize locally so legacy
    // records such as "Looord" still work.
    const profile = result.documents.find((document) =>
      normalizeUsername(String(document.data?.username ?? '')) === username,
    );
    log(`profile found: ${profile ? 'true' : 'false'}`);
    if (!profile) return invalidCredentials(res);

    const userId = String(profile.data?.userId ?? '').trim();
    log(`userId found: ${userId ? 'true' : 'false'}`);
    if (!userId) return serverError(res, 'PROFILE_ERROR');

    let user;
    try {
      const users = new Users(adminClient);
      user = await users.get(userId);
    } catch (err) {
      const details = errorDetails(err);
      error(`user lookup failed; code=${details.code}; type=${details.type}; message=${details.message}`);
      return serverError(res, 'USER_ERROR');
    }
    log(`user found: ${user ? 'true' : 'false'}`);
    const email = typeof user.email === 'string' ? user.email.trim() : '';
    log(`email found: ${email ? 'true' : 'false'} (${maskEmail(email)})`);
    if (!email) return serverError(res, 'USER_ERROR');

    log('creating session');
    try {
      const account = new Account(adminClient);
      const session = await account.createEmailPasswordSession({ email, password });
      log('session creation succeeded');
      return json(res, 200, {
        ok: true,
        userId,
        secret: session.secret,
        expire: session.expire,
      });
    } catch (err) {
      const details = errorDetails(err);
      error(`session creation failed; code=${details.code}; type=${details.type}; message=${details.message}`);
      // A 401 from Appwrite at this stage is the only case exposed as bad
      // credentials. Permission/configuration failures remain server errors.
      return Number(details.code) === 401
        ? invalidCredentials(res)
        : serverError(res, 'SESSION_ERROR');
    }
  } catch (err) {
    const details = errorDetails(err);
    error(`request failed; username=${username || '[empty]'}; code=${details.code}; type=${details.type}; message=${details.message}`);
    return serverError(res);
  }
};
