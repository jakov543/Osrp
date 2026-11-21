// OSRP Launcher V1 - main process
const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { execFile, spawn } = require('child_process');
const http = require('http');
const crypto = require('crypto');
const { Readable } = require('stream');
const { pipeline } = require('stream/promises');

const APP_CONFIG = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));
const SETTINGS_FILE = () => path.join(app.getPath('userData'), 'settings.json');

// GTA V editions (Legacy = 271590, Enhanced = 3240220 on Steam)
const GAME_EXES = ['GTA5.exe', 'GTA5_Enhanced.exe'];
const STORE_LINKS = {
  steam: 'https://store.steampowered.com/app/271590/',
  epic: 'https://store.epicgames.com/p/grand-theft-auto-v',
  rockstar: 'https://www.rockstargames.com/gta-v',
  fivem: 'https://fivem.net/',
  fivemLicense: 'https://fivem.net/terms'
};
// ---------- FiveM client (installed + started by the OSRP launcher) ----------
const FIVEM_DOWNLOAD = 'https://runtime.fivem.net/client/FiveM.exe'; // official client (GTA V Legacy)
const fivemDir = () => path.join(process.env.LOCALAPPDATA || app.getPath('appData'), 'FiveM');
const fivemExe = () => path.join(fivemDir(), 'FiveM.exe');
const fivemInstalled = () => exists(fivemExe()) && fs.existsSync(path.join(fivemDir(), 'FiveM.app'));

// FiveM only starts when its parent is Explorer or a browser, so everything FiveM-related goes through explorer.exe
function openViaExplorer(target) {
  return new Promise((resolve, reject) => {
    if (process.platform !== 'win32') return shell.openExternal(target).then(resolve, reject);
    const winDir = process.env.SystemRoot || process.env.windir || 'C:\\Windows';
    const child = spawn(path.join(winDir, 'explorer.exe'), [target], { detached: true, stdio: 'ignore', windowsHide: false });
    child.on('error', reject);
    child.unref();
    setTimeout(resolve, 300); // explorer.exe hands off and exits; its exit code is not meaningful
  });
}

// FiveM registers the fivem:// link when installed - works wherever the player installed it
function fivemProtocolRegistered() {
  return new Promise((resolve) => {
    if (process.platform !== 'win32') return resolve(false);
    execFile('reg', ['query', 'HKCU\\Software\\Classes\\fivem\\shell\\open\\command', '/ve'], { windowsHide: true }, (err, out) => {
      if (!err && out && /FiveM/i.test(out)) return resolve(true);
      execFile('reg', ['query', 'HKCR\\fivem\\shell\\open\\command', '/ve'], { windowsHide: true }, (err2, out2) =>
        resolve(!err2 && !!out2 && /FiveM/i.test(out2)));
    });
  });
}
async function fivemReady() { return fivemInstalled() || (await fivemProtocolRegistered()); }

function sendProgress(data) {
  if (win && !win.isDestroyed()) win.webContents.send('fivem:progress', data);
}

async function downloadFiveM() {
  fs.mkdirSync(fivemDir(), { recursive: true });
  const tmp = fivemExe() + '.download';
  const res = await fetch(FIVEM_DOWNLOAD);
  if (!res.ok || !res.body) throw new Error('Preuzimanje nije uspjelo (HTTP ' + res.status + ').');
  const total = Number(res.headers.get('content-length')) || 0;
  let got = 0;
  const body = Readable.fromWeb(res.body);
  body.on('data', (chunk) => {
    got += chunk.length;
    sendProgress({ stage: 'download', fraction: total ? got / total : 0, mb: (got / 1048576).toFixed(1) });
  });
  await pipeline(body, fs.createWriteStream(tmp));
  if (got < 100 * 1024) throw new Error('Preuzeta datoteka je neispravna.');
  fs.renameSync(tmp, fivemExe());
}

function waitFor(check, timeoutMs, everyMs = 3000) {
  return new Promise((resolve) => {
    const start = Date.now();
    const t = setInterval(() => {
      if (check()) { clearInterval(t); resolve(true); }
      else if (Date.now() - start > timeoutMs) { clearInterval(t); resolve(false); }
    }, everyMs);
  });
}

// Installs FiveM if needed (player already accepted the license in the launcher), then connects to OSRP
async function ensureFiveMAndConnect() {
  if (!(await fivemReady())) {
    if (!exists(fivemExe())) {
      sendProgress({ stage: 'download', fraction: 0, mb: '0.0' });
      await downloadFiveM();
    }
    sendProgress({ stage: 'install' });
    await openViaExplorer(fivemExe());
    const ok = await waitFor(fivemInstalled, 15 * 60 * 1000);
    if (!ok) throw new Error('Instalacija klijenta traje predugo. Završi postavljanje u otvorenom prozoru pa pritisni IGRAJ ponovno.');
    await new Promise((r) => setTimeout(r, 8000));
  }
  sendProgress({ stage: 'connect' });
  return launchServer();
}

// ---------- Google login (OAuth 2.0 desktop flow with PKCE) ----------
const b64url = (buf) => buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const googleConfigured = () => !!(APP_CONFIG.google && APP_CONFIG.google.clientId);

function googleLogin() {
  return new Promise((resolve, reject) => {
    if (!googleConfigured()) return reject(new Error('Google prijava nije postavljena.'));
    const { clientId, clientSecret } = APP_CONFIG.google;
    const verifier = b64url(crypto.randomBytes(32));
    const challenge = b64url(crypto.createHash('sha256').update(verifier).digest());
    const state = b64url(crypto.randomBytes(16));
    let finished = false;

    const server = http.createServer(async (req, res) => {
      const url = new URL(req.url, 'http://127.0.0.1');
      if (url.pathname !== '/') { res.writeHead(404); return res.end(); }
      const code = url.searchParams.get('code');
      const okState = url.searchParams.get('state') === state;
      const page = (msg) => `<!DOCTYPE html><meta charset="utf-8"><body style="background:#07090d;color:#e8edf4;font-family:Segoe UI,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0"><div style="text-align:center"><h1 style="color:#19c3a6;letter-spacing:6px">OSRP</h1><p>${msg}</p></div>`;
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      if (!code || !okState) {
        res.end(page('Prijava otkazana. Možeš zatvoriti ovu karticu.'));
        return done(new Error('Prijava je otkazana.'));
      }
      res.end(page('Prijava uspjela! Vrati se u OSRP launcher.'));
      try {
        const redirect = `http://127.0.0.1:${server.address().port}`;
        const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({
            code, client_id: clientId, client_secret: clientSecret || '',
            redirect_uri: redirect, grant_type: 'authorization_code', code_verifier: verifier
          })
        });
        const token = await tokenRes.json();
        if (!token.access_token) throw new Error(token.error_description || 'Google nije vratio token.');
        const info = await fetch('https://openidconnect.googleapis.com/v1/userinfo', {
          headers: { Authorization: 'Bearer ' + token.access_token }
        }).then((r) => r.json());
        const account = { name: info.name || info.email, email: info.email, picture: info.picture || null, id: info.sub };
        saveSettings({ ...loadSettings(), account });
        done(null, account);
      } catch (e) { done(e); }
    });

    const timer = setTimeout(() => done(new Error('Prijava je istekla. Pokušaj ponovno.')), 5 * 60 * 1000);
    function done(err, account) {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      server.close();
      if (win && !win.isDestroyed()) { if (win.isMinimized()) win.restore(); win.focus(); }
      err ? reject(err) : resolve(account);
    }

    server.on('error', (e) => done(e));
    server.listen(0, '127.0.0.1', () => {
      const redirect = `http://127.0.0.1:${server.address().port}`;
      const auth = new URL('https://accounts.google.com/o/oauth2/v2/auth');
      auth.search = new URLSearchParams({
        client_id: clientId, redirect_uri: redirect, response_type: 'code',
        scope: 'openid email profile', code_challenge: challenge, code_challenge_method: 'S256',
        state, prompt: 'select_account'
      }).toString();
      shell.openExternal(auth.toString());
    });
  });
}

const ALLOWED_LINKS = new Set([...Object.values(STORE_LINKS), APP_CONFIG.discord, APP_CONFIG.website].filter(Boolean));

// ---------- settings ----------
function loadSettings() {
  try { return JSON.parse(fs.readFileSync(SETTINGS_FILE(), 'utf8')); }
  catch { return { ownershipConfirmed: false, gamePath: null, platform: null, account: null, fivemLicense: false }; }
}
function saveSettings(s) {
  try {
    fs.mkdirSync(path.dirname(SETTINGS_FILE()), { recursive: true });
    fs.writeFileSync(SETTINGS_FILE(), JSON.stringify(s, null, 2));
  } catch (e) { console.error('Settings save failed:', e.message); }
  return s;
}

// ---------- game detection ----------
function exists(p) { try { return fs.statSync(p).isFile(); } catch { return false; } }

function findExeInFolder(folder) {
  if (!folder) return null;
  for (const exe of GAME_EXES) {
    const full = path.join(folder, exe);
    if (exists(full)) return full;
  }
  return null;
}

function guessPlatform(exePath) {
  const p = exePath.toLowerCase();
  if (p.includes('steamapps')) return 'steam';
  if (p.includes('epic')) return 'epic';
  return 'rockstar';
}

function regQuery(key, value) {
  return new Promise((resolve) => {
    if (process.platform !== 'win32') return resolve(null);
    execFile('reg', ['query', key, '/v', value], { windowsHide: true }, (err, stdout) => {
      if (err || !stdout) return resolve(null);
      const line = stdout.split(/\r?\n/).find((l) => l.includes(value));
      if (!line) return resolve(null);
      const m = line.match(/REG_\w+\s+(.+)$/);
      resolve(m ? m[1].trim() : null);
    });
  });
}

function steamLibraries() {
  const roots = ['C:\\Program Files (x86)\\Steam', 'C:\\Program Files\\Steam'];
  const libs = new Set(roots);
  for (const root of roots) {
    const vdf = path.join(root, 'steamapps', 'libraryfolders.vdf');
    try {
      const txt = fs.readFileSync(vdf, 'utf8');
      for (const m of txt.matchAll(/"path"\s+"([^"]+)"/g)) libs.add(m[1].replace(/\\\\/g, '\\'));
    } catch { /* steam not installed here */ }
  }
  return [...libs];
}

async function detectGame() {
  const candidates = [];

  // Registry (Rockstar / Steam / Epic installs write these)
  const regKeys = [
    ['HKLM\\SOFTWARE\\WOW6432Node\\Rockstar Games\\Grand Theft Auto V', 'InstallFolder'],
    ['HKLM\\SOFTWARE\\WOW6432Node\\Rockstar Games\\GTAV', 'InstallFolderSteam'],
    ['HKLM\\SOFTWARE\\WOW6432Node\\Rockstar Games\\GTAV', 'InstallFolderEpic'],
    ['HKLM\\SOFTWARE\\WOW6432Node\\Rockstar Games\\Grand Theft Auto V Enhanced', 'InstallFolder']
  ];
  for (const [k, v] of regKeys) {
    let val = await regQuery(k, v);
    if (val) {
      if (val.toLowerCase().endsWith('.exe')) val = path.dirname(val);
      candidates.push(val);
    }
  }

  // Steam libraries
  for (const lib of steamLibraries()) {
    candidates.push(path.join(lib, 'steamapps', 'common', 'Grand Theft Auto V'));
    candidates.push(path.join(lib, 'steamapps', 'common', 'Grand Theft Auto V Enhanced'));
  }

  // Common default folders on every drive letter
  for (const d of 'CDEFGH') {
    candidates.push(`${d}:\\Program Files\\Rockstar Games\\Grand Theft Auto V`);
    candidates.push(`${d}:\\Program Files\\Rockstar Games\\Grand Theft Auto V Enhanced`);
    candidates.push(`${d}:\\Program Files\\Epic Games\\GTAV`);
    candidates.push(`${d}:\\Epic Games\\GTAV`);
    candidates.push(`${d}:\\SteamLibrary\\steamapps\\common\\Grand Theft Auto V`);
    candidates.push(`${d}:\\Games\\Grand Theft Auto V`);
  }

  for (const folder of candidates) {
    const exe = findExeInFolder(folder);
    if (exe) return { found: true, gamePath: exe, platform: guessPlatform(exe) };
  }
  return { found: false };
}

function validateExe(exePath) {
  if (!exePath || !exists(exePath)) return { ok: false, error: 'Datoteka ne postoji.' };
  const name = path.basename(exePath);
  if (!GAME_EXES.some((e) => e.toLowerCase() === name.toLowerCase())) {
    return { ok: false, error: 'Odaberi GTA5.exe ili GTA5_Enhanced.exe.' };
  }
  const size = fs.statSync(exePath).size;
  if (size < 20 * 1024 * 1024) return { ok: false, error: 'Ovo ne izgleda kao pravi GTA5.exe (premala datoteka).' };
  return { ok: true, edition: name.toLowerCase().includes('enhanced') ? 'enhanced' : 'legacy' };
}

// ---------- launching ----------
function launchSingleplayer(settings) {
  const edition = settings.gamePath && settings.gamePath.toLowerCase().includes('enhanced') ? 'enhanced' : 'legacy';
  switch (settings.platform) {
    case 'steam':
      return shell.openExternal(edition === 'enhanced' ? 'steam://rungameid/3240220' : 'steam://rungameid/271590');
    case 'epic':
      return shell.openExternal('com.epicgames.launcher://apps/9d2d0eb64d5c44529cece33fe2a46482?action=launch&silent=true');
    default: {
      // Rockstar version: PlayGTAV.exe starts the game through the Rockstar Launcher
      const folder = path.dirname(settings.gamePath);
      const play = path.join(folder, 'PlayGTAV.exe');
      const target = exists(play) ? play : settings.gamePath;
      return openViaExplorer(target);
    }
  }
}

function launchServer() {
  // FiveM uses the player's own GTA V install
  const addr = serverAddress();
  if (!/^[\w.-]+(:\d+)?$/.test(addr)) return Promise.reject(new Error('Bad server address'));
  return openViaExplorer(`fivem://connect/${addr}`);
}

// ---------- server address (config.json default, player can change it in Settings) ----------
const ADDR_RE = /^[a-zA-Z0-9.-]{1,253}:\d{2,5}$/;
function serverAddress() {
  const s = loadSettings();
  return s.serverAddress && ADDR_RE.test(s.serverAddress) ? s.serverAddress : APP_CONFIG.serverAddress;
}

// ---------- server status ----------
async function getServerStatus() {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 4000);
    const base = `http://${serverAddress()}`;
    const [info, players] = await Promise.all([
      fetch(`${base}/info.json`, { signal: ctrl.signal }).then((r) => r.json()),
      fetch(`${base}/players.json`, { signal: ctrl.signal }).then((r) => r.json())
    ]);
    clearTimeout(t);
    return { online: true, address: serverAddress(), players: players.length, max: Number(info.vars && info.vars.sv_maxClients) || 48 };
  } catch {
    return { online: false, address: serverAddress() };
  }
}

// ---------- windows ----------
const ICON = path.join(__dirname, 'renderer', 'assets', 'icon.png');
let win = null;
let splash = null;
let bootResult = null;

function createSplash() {
  splash = new BrowserWindow({
    width: 440,
    height: 500,
    frame: false,
    resizable: false,
    transparent: true,
    center: true,
    alwaysOnTop: true,
    skipTaskbar: false,
    icon: ICON,
    show: false,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true }
  });
  splash.loadFile(path.join(__dirname, 'renderer', 'splash.html'));
  splash.once('ready-to-show', () => splash.show());
  splash.webContents.once('did-finish-load', runBoot);
}

function splashStep(text, progress) {
  if (splash && !splash.isDestroyed()) splash.webContents.send('splash:step', { text, progress });
}

// Real startup work shown on the splash screen
async function runBoot() {
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  splashStep('Pokrećem OSRP...', 0.1);
  await wait(500);

  splashStep('Učitavam postavke...', 0.25);
  let settings = loadSettings();
  await wait(350);

  splashStep('Tražim GTA V...', 0.45);
  if (!settings.gamePath || !validateExe(settings.gamePath).ok) {
    const r = await detectGame();
    if (r.found) settings = saveSettings({ ...settings, gamePath: r.gamePath, platform: r.platform });
  }
  await wait(350);

  splashStep('Spajam se na OSRP server...', 0.7);
  const status = await getServerStatus();
  await wait(300);

  splashStep('Pripremam launcher...', 0.9);
  bootResult = { settings, status };
  createMain();
}

function createMain() {
  win = new BrowserWindow({
    width: 1200,
    height: 720,
    minWidth: 1000,
    minHeight: 620,
    frame: false,
    backgroundColor: '#07090d',
    icon: ICON,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.once('ready-to-show', async () => {
    splashStep('Spremno!', 1);
    await new Promise((r) => setTimeout(r, 450));
    if (splash && !splash.isDestroyed()) splash.close();
    splash = null;
    win.show();
  });
  win.on('closed', () => { win = null; });
}

// ---------- IPC ----------
const APP_VERSION = require('./package.json').version; // stays 1.0.0 (V1)
ipcMain.handle('app:info', () => ({ version: APP_VERSION, config: APP_CONFIG, stores: STORE_LINKS }));
ipcMain.handle('settings:get', () => loadSettings());
ipcMain.handle('ownership:confirm', () => saveSettings({ ...loadSettings(), ownershipConfirmed: true }));
ipcMain.handle('game:detect', async () => {
  const r = await detectGame();
  if (r.found) saveSettings({ ...loadSettings(), gamePath: r.gamePath, platform: r.platform });
  return r;
});
ipcMain.handle('game:browse', async () => {
  const res = await dialog.showOpenDialog(win, {
    title: 'Odaberi GTA5.exe',
    defaultPath: 'C:\\Program Files',
    properties: ['openFile'],
    filters: [{ name: 'GTA V', extensions: ['exe'] }]
  });
  if (res.canceled || !res.filePaths[0]) return { ok: false, canceled: true };
  const exe = res.filePaths[0];
  const v = validateExe(exe);
  if (!v.ok) return v;
  saveSettings({ ...loadSettings(), gamePath: exe, platform: guessPlatform(exe) });
  return { ok: true, gamePath: exe, platform: guessPlatform(exe), edition: v.edition };
});
ipcMain.handle('game:setPlatform', (_e, platform) => {
  if (!['steam', 'epic', 'rockstar'].includes(platform)) return loadSettings();
  return saveSettings({ ...loadSettings(), platform });
});
ipcMain.handle('game:reset', () => saveSettings({ ownershipConfirmed: false, gamePath: null, platform: null, account: null, fivemLicense: false }));
ipcMain.handle('fivem:acceptLicense', () => saveSettings({ ...loadSettings(), fivemLicense: true }));
ipcMain.handle('fivem:status', async () => ({ installed: await fivemReady() }));
ipcMain.handle('google:configured', () => googleConfigured());
ipcMain.handle('google:login', async () => {
  try { return { ok: true, account: await googleLogin() }; }
  catch (e) { return { ok: false, error: e.message }; }
});
ipcMain.handle('google:logout', () => saveSettings({ ...loadSettings(), account: null }));
ipcMain.handle('account:skip', () => {
  // Guest mode only exists while the server owner has not set up Google login
  if (googleConfigured()) return loadSettings();
  return saveSettings({ ...loadSettings(), account: { guest: true, name: 'Gost' } });
});
ipcMain.handle('game:play', async (_e, mode) => {
  const s = loadSettings();
  if (!s.ownershipConfirmed) return { ok: false, error: 'Prvo potvrdi da imaš igru.' };
  if (!s.gamePath || !validateExe(s.gamePath).ok) return { ok: false, error: 'GTA V nije pronađen. Odaberi GTA5.exe.' };
  try {
    if (mode === 'server') {
      const ready = await fivemReady();
      if (!ready && !s.fivemLicense) return { ok: false, needLicense: true };
      if (s.gamePath.toLowerCase().includes('enhanced') && !ready) {
        shell.openExternal(STORE_LINKS.fivem);
        return { ok: false, error: 'Za GTA V Enhanced preuzmi "FiveM for GTAV Enhanced" sa stranice koja se otvorila, pa pritisni IGRAJ.' };
      }
      await ensureFiveMAndConnect();
    } else await launchSingleplayer(s);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
});
ipcMain.handle('server:status', () => getServerStatus());
ipcMain.handle('server:getAddress', () => serverAddress());
ipcMain.handle('server:setAddress', (_e, addr) => {
  const a = String(addr || '').trim();
  if (a === '') { saveSettings({ ...loadSettings(), serverAddress: null }); return { ok: true, address: serverAddress() }; }
  if (!ADDR_RE.test(a)) return { ok: false, error: 'Upiši adresu kao IP:port, npr. 127.0.0.1:30120' };
  saveSettings({ ...loadSettings(), serverAddress: a });
  return { ok: true, address: a };
});
ipcMain.handle('boot:result', () => bootResult);
ipcMain.handle('link:open', (_e, url) => {
  if (ALLOWED_LINKS.has(url)) shell.openExternal(url);
});
ipcMain.on('win:minimize', () => win && win.minimize());
ipcMain.on('win:close', () => win && win.close());

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win) { if (win.isMinimized()) win.restore(); win.focus(); }
  });
  app.whenReady().then(createSplash);
}
app.on('window-all-closed', () => app.quit());
