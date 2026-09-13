const { Client, Account, Databases, Query, Users } = require('node-appwrite');

const json = (res, statusCode, body) => res.json(body, statusCode);
const invalidCredentials = (res) => json(res, 401, {
  ok: false,
  code: 'INVALID_CREDENTIALS',
  message: 'Invalid username or password.',
});

const required = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};

const normalizeUsername = (value) => value.trim().toLowerCase();

module.exports = async ({ req, res, error }) => {
  try {
    const payload = req.bodyJson && typeof req.bodyJson === 'object'
      ? req.bodyJson
      : (() => {
          try { return JSON.parse(req.body || '{}'); } catch (_) { return {}; }
        })();
    const username = typeof payload.username === 'string' ? normalizeUsername(payload.username) : '';
    const password = typeof payload.password === 'string' ? payload.password : '';

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

    // Query.equal is case-sensitive in Appwrite. Read the bounded profile set
    // and normalize locally so legacy records such as "Looord" still work.
    const result = await databases.listDocuments(
      required('APPWRITE_DATABASE_ID'),
      required('APPWRITE_PROFILES_TABLE_ID'),
      [Query.limit(5000)],
    );
    const profile = result.documents.find((document) =>
      normalizeUsername(String(document.data?.username ?? '')) === username,
    );
    if (!profile) return invalidCredentials(res);

    const userId = String(profile.data?.userId ?? '');
    if (!userId) return invalidCredentials(res);

    // Appwrite verifies the password here; the password is never stored or logged.
    const users = new Users(adminClient);
    const user = await users.get(userId);
    const account = new Account(adminClient);
    const session = await account.createEmailPasswordSession({ email: user.email, password });

    return json(res, 200, {
      ok: true,
      userId,
      secret: session.secret,
      expire: session.expire,
    });
  } catch (err) {
    // Never log request data, passwords, API keys, emails, or user IDs.
    const isCredentialFailure = err && (err.code === 401 || err.code === 404);
    if (!isCredentialFailure) error(`Username login failed: ${err.message || 'unknown error'}`);
    return isCredentialFailure
      ? invalidCredentials(res)
      : json(res, 500, { ok: false, code: 'FUNCTION_ERROR', message: 'Unable to sign in right now.' });
  }
};
