const { Client, Account, Databases, Query } = require('node-appwrite');

const json = (res, statusCode, body) =>
  res.json(body, statusCode);

const required = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};

module.exports = async ({ req, res, log, error }) => {
  try {
    const payload = req.bodyJson || (() => {
      try { return JSON.parse(req.body || '{}'); } catch (_) { return {}; }
    })();
    const username = typeof payload.username === 'string' ? payload.username.trim().toLowerCase() : '';
    const password = typeof payload.password === 'string' ? payload.password : '';

    if (!username || !password) {
      return json(res, 400, { ok: false, code: 'INVALID_INPUT', message: 'Username and password are required.' });
    }
    if (!/^[a-z0-9][a-z0-9_.-]{2,99}$/.test(username)) {
      return json(res, 400, { ok: false, code: 'INVALID_USERNAME', message: 'Invalid username.' });
    }

    const endpoint = required('APPWRITE_ENDPOINT');
    const projectId = required('APPWRITE_PROJECT_ID');
    const apiKey = required('APPWRITE_API_KEY');
    const databaseId = required('APPWRITE_DATABASE_ID');
    const profilesTableId = required('APPWRITE_PROFILES_TABLE_ID');

    const adminClient = new Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);
    const databases = new Databases(adminClient);

    const result = await databases.listDocuments(
      databaseId,
      profilesTableId,
      [Query.equal('username', username), Query.limit(1)],
    );
    if (!result.documents.length) {
      // Keep the response intentionally generic; never reveal whether an
      // email or account exists.
      return json(res, 401, { ok: false, code: 'INVALID_CREDENTIALS', message: 'Invalid username or password.' });
    }

    const profile = result.documents[0];
    const userId = String(profile.userId || '');
    if (!userId) {
      return json(res, 401, { ok: false, code: 'INVALID_CREDENTIALS', message: 'Invalid username or password.' });
    }

    // A server API key is used only inside this Function. Appwrite validates
    // the password and returns a one-time session secret; no password is
    // stored or logged. The email is never returned to the mobile client.
    const users = new (require('node-appwrite').Users)(adminClient);
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
    // Do not log request bodies or credentials. Appwrite authentication
    // failures intentionally collapse to the same public response.
    const code = err && (err.code === 401 || err.code === 404) ? 'INVALID_CREDENTIALS' : 'FUNCTION_ERROR';
    if (code === 'FUNCTION_ERROR') error(`Username login failed: ${err.message || 'unknown error'}`);
    return json(res, code === 'INVALID_CREDENTIALS' ? 401 : 500, {
      ok: false,
      code,
      message: code === 'INVALID_CREDENTIALS' ? 'Invalid username or password.' : 'Unable to sign in right now.',
    });
  }
};
