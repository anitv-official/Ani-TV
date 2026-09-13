const { Client, Account, TablesDB, Query, Users } = require('node-appwrite');

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
  let phase = 'request';
  try {
    log('request started');
    const payload = req.bodyJson && typeof req.bodyJson === 'object'
      ? req.bodyJson
      : (() => {
          try { return JSON.parse(req.body || '{}'); } catch (_) { return {}; }
        })();
    username = typeof payload.username === 'string' ? normalizeUsername(payload.username) : '';
    const action = typeof payload.action === 'string' ? payload.action : 'login';
    const password = typeof payload.password === 'string' ? payload.password : '';
    log(`username normalized: ${username || '[empty]'}`);

    if (!username || (action !== 'check_username' && !password)) {
      return json(res, 400, { ok: false, code: 'INVALID_INPUT', message: 'Username and password are required.' });
    }
    if (!/^[a-z0-9_]{3,24}$/.test(username)) {
      return json(res, 400, { ok: false, code: 'INVALID_USERNAME', message: 'Invalid username.' });
    }

    const adminClient = new Client()
      .setEndpoint(required('APPWRITE_ENDPOINT'))
      .setProject(required('APPWRITE_PROJECT_ID'))
      .setKey(required('APPWRITE_API_KEY'));
    const tablesDB = new TablesDB(adminClient);

    if (action === 'check_username') {
      phase = 'username_availability_lookup';
      try {
        const result = await tablesDB.listRows({
          databaseId: required('APPWRITE_DATABASE_ID'),
          tableId: required('APPWRITE_PROFILES_TABLE_ID'),
          queries: [Query.limit(5000)],
        });
        const currentDocumentId = typeof payload.currentDocumentId === 'string'
          ? payload.currentDocumentId.trim()
          : '';
        const taken = result.rows.some((row) =>
          normalizeUsername(String(row.username ?? '')) === username && String(row.$id ?? '') !== currentDocumentId,
        );
        return json(res, 200, { ok: true, available: !taken });
      } catch (err) {
        const details = errorDetails(err);
        error(`username availability lookup failed; code=${details.code}; type=${details.type}; message=${details.message}`);
        return serverError(res, 'PROFILE_ERROR');
      }
    }

    let result;
    phase = 'profiles_lookup';
    log('profiles lookup started');
    try {
      result = await tablesDB.listRows({
        databaseId: required('APPWRITE_DATABASE_ID'),
        tableId: required('APPWRITE_PROFILES_TABLE_ID'),
        queries: [Query.limit(5000)],
      });
    } catch (err) {
      const details = errorDetails(err);
      error(`profile lookup failed; code=${details.code}; type=${details.type}; message=${details.message}`);
      return serverError(res, 'PROFILE_ERROR');
    }
    log(`profiles lookup succeeded; rows=${Array.isArray(result.rows) ? result.rows.length : 0}`);

    // Query.equal is case-sensitive in Appwrite. Normalize locally so legacy
    // records such as "Looord" still work.
    const profile = result.rows.find((row) =>
      normalizeUsername(String(row.username ?? '')) === username,
    );
    log(`profile lookup result; found=${profile ? 'true' : 'false'}`);
    if (!profile) return invalidCredentials(res);

    phase = 'profile_user_id_extraction';
    const userId = String(profile.userId ?? '').trim();
    log(`profile userId extraction result; found=${userId ? 'true' : 'false'}`);
    if (!userId) return serverError(res, 'PROFILE_ERROR');

    let user;
    phase = 'users_get';
    log('Users.get started');
    try {
      const users = new Users(adminClient);
      user = await users.get(userId);
    } catch (err) {
      const details = errorDetails(err);
      error(`user lookup failed; code=${details.code}; type=${details.type}; message=${details.message}`);
      return serverError(res, 'USER_ERROR');
    }
    log(`Users.get succeeded; found=${user ? 'true' : 'false'}`);

    phase = 'email_extraction';
    const email = typeof user.email === 'string' ? user.email.trim() : '';
    log(`email extraction result; found=${email ? 'true' : 'false'} (${maskEmail(email)})`);
    if (!email) return serverError(res, 'USER_ERROR');

    phase = 'session_creation';
    log('createEmailPasswordSession started; client=admin-api-key; scope=sessions.write');
    try {
      const account = new Account(adminClient);
      const session = await account.createEmailPasswordSession({ email, password });
      log('createEmailPasswordSession succeeded');
      return json(res, 200, {
        ok: true,
        userId,
        secret: session.secret,
        expire: session.expire,
      });
    } catch (err) {
      const details = errorDetails(err);
      error(`createEmailPasswordSession failed; phase=${phase}; code=${details.code}; type=${details.type}; message=${details.message}`);
      // A 401 at this stage means Appwrite rejected the supplied credentials.
      // Other status codes are surfaced as server errors so configuration,
      // permission, rate-limit, and service failures are not misreported.
      return Number(details.code) === 401
        ? invalidCredentials(res)
        : serverError(res, 'SESSION_ERROR');
    }
  } catch (err) {
    const details = errorDetails(err);
    error(`request failed; phase=${phase}; username=${username || '[empty]'}; code=${details.code}; type=${details.type}; message=${details.message}`);
    return serverError(res);
  }
};
