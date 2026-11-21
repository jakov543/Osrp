// OSRP accounts V1 - own register/login for the OSRP Launcher.
// Runs inside your FiveM server, reachable at http://SERVER_IP:30120/osrp_accounts/...
// Passwords are hashed with scrypt + salt; accounts and sessions are stored with FiveM KVP.

const crypto = require('crypto');

const SESSION_DAYS = 30;
const MAX_BODY = 4096;
const USER_RE = /^[A-Za-z0-9_]{3,16}$/;
const LOGIN_LIMIT = 8;                 // failed logins per IP ...
const LOGIN_WINDOW = 10 * 60 * 1000;   // ... per 10 minutes
const REGISTER_LIMIT = 3;              // new accounts per IP per hour

const attempts = new Map();            // key -> [timestamps]

function rateLimited(key, limit, windowMs) {
  const now = Date.now();
  const list = (attempts.get(key) || []).filter((t) => now - t < windowMs);
  attempts.set(key, list);
  return list.length >= limit;
}
function hit(key) {
  const list = attempts.get(key) || [];
  list.push(Date.now());
  attempts.set(key, list);
}

// ---------- storage (KVP) ----------
const accKey = (u) => 'osrp:acc:' + u.toLowerCase();
const sessKey = (t) => 'osrp:sess:' + t;

function readJson(key) {
  const raw = GetResourceKvpString(key);
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { return null; }
}
function writeJson(key, value) { SetResourceKvp(key, JSON.stringify(value)); }

// ---------- passwords ----------
function hashPassword(password, salt) {
  return crypto.scryptSync(password, salt, 64, { N: 16384, r: 8, p: 1 }).toString('hex');
}
function checkPassword(password, acc) {
  const a = Buffer.from(hashPassword(password, acc.salt), 'hex');
  const b = Buffer.from(acc.hash, 'hex');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function newSession(username) {
  const token = crypto.randomBytes(32).toString('hex');
  writeJson(sessKey(token), { username, expires: Date.now() + SESSION_DAYS * 86400000 });
  return token;
}
function getSession(token) {
  if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) return null;
  const s = readJson(sessKey(token));
  if (!s) return null;
  if (s.expires < Date.now()) { DeleteResourceKvp(sessKey(token)); return null; }
  return s;
}

// ---------- API ----------
function validCredentials(body) {
  if (!body || typeof body.username !== 'string' || typeof body.password !== 'string') return 'Upiši korisničko ime i lozinku.';
  if (!USER_RE.test(body.username)) return 'Korisničko ime: 3-16 znakova (slova, brojevi, _).';
  if (body.password.length < 6 || body.password.length > 64) return 'Lozinka mora imati 6-64 znakova.';
  return null;
}

const routes = {
  'POST /register': (body, ip) => {
    const err = validCredentials(body);
    if (err) return [400, { ok: false, error: err }];
    if (rateLimited('reg:' + ip, REGISTER_LIMIT, 3600000)) return [429, { ok: false, error: 'Previše novih računa. Pokušaj kasnije.' }];
    if (readJson(accKey(body.username))) return [409, { ok: false, error: 'To korisničko ime je zauzeto.' }];
    const salt = crypto.randomBytes(16).toString('hex');
    writeJson(accKey(body.username), {
      username: body.username, salt, hash: hashPassword(body.password, salt), created: Date.now()
    });
    hit('reg:' + ip);
    console.log(`[OSRP] Novi račun: ${body.username}`);
    return [200, { ok: true, username: body.username, token: newSession(body.username) }];
  },

  'POST /login': (body, ip) => {
    if (rateLimited('login:' + ip, LOGIN_LIMIT, LOGIN_WINDOW)) return [429, { ok: false, error: 'Previše pokušaja. Pričekaj 10 minuta.' }];
    const err = validCredentials(body);
    const acc = err ? null : readJson(accKey(body.username));
    if (!acc || !checkPassword(body.password, acc)) {
      hit('login:' + ip);
      return [401, { ok: false, error: 'Pogrešno korisničko ime ili lozinka.' }];
    }
    return [200, { ok: true, username: acc.username, token: newSession(acc.username) }];
  },

  'GET /me': (_body, _ip, token) => {
    const s = getSession(token);
    return s ? [200, { ok: true, username: s.username }] : [401, { ok: false, error: 'Prijava je istekla.' }];
  },

  'POST /logout': (_body, _ip, token) => {
    if (getSession(token)) DeleteResourceKvp(sessKey(token));
    return [200, { ok: true }];
  },

  'GET /status': () => [200, { ok: true, service: 'osrp_accounts', version: '1.0.7' }]
};

SetHttpHandler((req, res) => {
  const send = (code, obj) => {
    res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
    res.send(JSON.stringify(obj));
  };
  const route = routes[`${req.method} ${req.path}`];
  if (!route) return send(404, { ok: false, error: 'Not found' });

  const ip = String(req.address || '').split(':')[0];
  const auth = (req.headers && (req.headers.Authorization || req.headers.authorization)) || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';

  const run = (body) => {
    try {
      const [code, out] = route(body, ip, token);
      send(code, out);
    } catch (e) {
      console.log('[OSRP accounts] error: ' + e.message);
      send(500, { ok: false, error: 'Greška na serveru.' });
    }
  };

  if (req.method !== 'POST') return run(null);
  let body = '';
  let tooBig = false;
  req.setDataHandler((data) => {
    body += data;
    if (body.length > MAX_BODY) tooBig = true;
    if (tooBig) return send(413, { ok: false, error: 'Zahtjev je prevelik.' });
    let parsed = null;
    try { parsed = JSON.parse(body); } catch { return send(400, { ok: false, error: 'Neispravan zahtjev.' }); }
    run(parsed);
  });
});

console.log('[OSRP] osrp_accounts V1 spreman - /osrp_accounts/register, /login, /me, /logout');
