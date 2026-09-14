const { Client, Account, Databases, TablesDB, Query, Storage, Users } = require('node-appwrite');

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

const deleteAccount = async ({ adminClient, payload, req, res, log, error }) => {
  const userId = typeof payload.userId === 'string' ? payload.userId.trim() : '';
  const password = typeof payload.password === 'string' ? payload.password : '';
  log(`delete_account entered; userIdPresent=${userId ? 'true' : 'false'}; passwordPresent=${password ? 'true' : 'false'}`);
  if (!userId || !password) {
    return json(res, 400, { ok: false, code: 'INVALID_INPUT', message: 'User identity and password are required.' });
  }
  // The Flutter Functions SDK may not forward the end-user session metadata
  // on createExecution. Password verification below is the required proof of
  // identity; when Appwrite does provide the header, still enforce the match.
  const authenticatedUserId = String(req.headers?.['x-appwrite-user-id'] ?? '').trim();
  log(`delete identity header present=${authenticatedUserId ? 'true' : 'false'}; matches=${authenticatedUserId ? String(authenticatedUserId === userId) : 'not_checked'}`);
  if (authenticatedUserId && authenticatedUserId !== userId) {
    return json(res, 401, { ok: false, code: 'AUTHENTICATION_REQUIRED', message: 'An authenticated session is required.' });
  }

  const users = new Users(adminClient);
  const tablesDB = new TablesDB(adminClient);
  const databases = new Databases(adminClient);
  const storage = new Storage(adminClient);
  const databaseId = required('APPWRITE_DATABASE_ID');
  const profilesTableId = required('APPWRITE_PROFILES_TABLE_ID');
  const favoritesTableId = required('APPWRITE_FAVORITES_TABLE_ID');
  const bucketId = required('APPWRITE_PROFILE_IMAGES_BUCKET_ID');

  let user;
  log('delete user lookup started');
  try {
    user = await users.get(userId);
    log('delete user lookup succeeded');
  } catch (err) {
    const details = errorDetails(err);
    error(`delete user lookup failed; code=${details.code}; type=${details.type}`);
    return Number(details.code) === 404
      ? json(res, 404, { ok: false, code: 'USER_NOT_FOUND', message: 'Account was not found.' })
      : serverError(res, 'USER_ERROR');
  }

  // Password verification is performed by Appwrite; the password is never logged.
  try {
    const account = new Account(adminClient);
    log('delete password verification started');
    await account.createEmailPasswordSession({ email: user.email, password });
    log('delete password verification succeeded');
  } catch (err) {
    const details = errorDetails(err);
    error(`delete password verification failed; code=${details.code}; type=${details.type}`);
    return Number(details.code) === 401
      ? json(res, 401, { ok: false, code: 'INVALID_CREDENTIALS', message: 'Unable to verify credentials.' })
      : serverError(res, 'AUTH_ERROR');
  }

  let profile;
  try {
    log('delete profile lookup started');
    const result = await tablesDB.listRows({ databaseId, tableId: profilesTableId, queries: [Query.limit(5000)] });
    profile = result.rows.find((row) => String(row.userId ?? '') === userId);
    log(`delete profile lookup succeeded; found=${profile ? 'true' : 'false'}`);
    if (profile && String(profile.userId ?? '') !== userId) {
      return json(res, 403, { ok: false, code: 'OWNERSHIP_CHECK_FAILED', message: 'Resource ownership could not be verified.' });
    }
  } catch (err) {
    const details = errorDetails(err);
    error(`delete profile lookup failed; code=${details.code}; type=${details.type}`);
    return serverError(res, 'PROFILE_ERROR');
  }

  try {
    log('delete favorites lookup started');
    const favorites = await databases.listDocuments({ databaseId, collectionId: favoritesTableId, queries: [Query.equal('userId', userId), Query.limit(5000)] });
    log(`delete favorites lookup succeeded; count=${favorites.documents.length}`);
    for (const favorite of favorites.documents) {
      if (String(favorite.data?.userId ?? '') !== userId) {
        return json(res, 403, { ok: false, code: 'OWNERSHIP_CHECK_FAILED', message: 'Resource ownership could not be verified.' });
      }
    }
    if (profile?.profileImageId) {
      await storage.deleteFile({ bucketId, fileId: String(profile.profileImageId) });
    }
    for (const favorite of favorites.documents) {
      await databases.deleteDocument({ databaseId, collectionId: favoritesTableId, documentId: favorite.$id });
    }
    if (profile) {
      await tablesDB.deleteRow({ databaseId, tableId: profilesTableId, rowId: profile.$id });
    }
    await users.delete({ userId });
    log('delete account completed');
    return json(res, 200, { ok: true });
  } catch (err) {
    const details = errorDetails(err);
    error(`delete account failed; code=${details.code}; type=${details.type}`);
    return serverError(res, 'DELETE_ERROR');
  }
};

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

    if (action !== 'delete_account' && (!username || (action !== 'check_username' && !password))) {
      return json(res, 400, { ok: false, code: 'INVALID_INPUT', message: 'Username and password are required.' });
    }
    if (action !== 'delete_account' && !/^[a-z0-9_]{3,24}$/.test(username)) {
      return json(res, 400, { ok: false, code: 'INVALID_USERNAME', message: 'Invalid username.' });
    }

    const adminClient = new Client()
      .setEndpoint(required('APPWRITE_ENDPOINT'))
      .setProject(required('APPWRITE_PROJECT_ID'))
      .setKey(required('APPWRITE_API_KEY'));
    const tablesDB = new TablesDB(adminClient);

    if (action === 'delete_account') {
      phase = 'account_deletion';
      log('delete_account action selected');
      return deleteAccount({ adminClient, payload, req, res, log, error });
    }

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
