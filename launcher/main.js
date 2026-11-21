// Osijek Launcher V1 - main process
const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { execFile, spawn } = require('child_process');

const APP_CONFIG = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));
const SETTINGS_FILE = () => path.join(app.getPath('userData'), 'settings.json');

// GTA V editions (Legacy = 271590, Enhanced = 3240220 on Steam)
const GAME_EXES = ['GTA5.exe', 'GTA5_Enhanced.exe'];
const STORE_LINKS = {
  steam: 'https://store.steampowered.com/app/271590/',
  epic: 'https://store.epicgames.com/p/grand-theft-auto-v',
  rockstar: 'https://www.rockstargames.com/gta-v',
  fivem: 'https://fivem.net/'
};
const ALLOWED_LINKS = new Set([...Object.values(STORE_LINKS), APP_CONFIG.discord, APP_CONFIG.website].filter(Boolean));

// ---------- settings ----------
function loadSettings() {
  try { return JSON.parse(fs.readFileSync(SETTINGS_FILE(), 'utf8')); }
  catch { return { ownershipConfirmed: false, gamePath: null, platform: null }; }
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
      const child = spawn(target, [], { cwd: folder, detached: true, stdio: 'ignore' });
      child.on('error', (e) => console.error('Launch error:', e.message));
      child.unref();
      return Promise.resolve();
    }
  }
}

function launchServer() {
  // FiveM uses the player's own GTA V install
  const addr = APP_CONFIG.serverAddress;
  if (!/^[\w.-]+(:\d+)?$/.test(addr)) return Promise.reject(new Error('Bad server address'));
  return shell.openExternal(`fivem://connect/${addr}`);
}

// ---------- window ----------
let win;
function createWindow() {
  win = new BrowserWindow({
    width: 1180,
    height: 700,
    minWidth: 980,
    minHeight: 600,
    frame: false,
    backgroundColor: '#07090d',
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.once('ready-to-show', () => win.show());
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
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
ipcMain.handle('game:reset', () => saveSettings({ ownershipConfirmed: false, gamePath: null, platform: null }));
ipcMain.handle('game:play', async (_e, mode) => {
  const s = loadSettings();
  if (!s.ownershipConfirmed) return { ok: false, error: 'Prvo potvrdi da imaš igru.' };
  if (!s.gamePath || !validateExe(s.gamePath).ok) return { ok: false, error: 'GTA V nije pronađen. Odaberi GTA5.exe.' };
  try {
    if (mode === 'server') await launchServer();
    else await launchSingleplayer(s);
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
});
ipcMain.handle('server:status', async () => {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 4000);
    const base = `http://${APP_CONFIG.serverAddress}`;
    const [info, players] = await Promise.all([
      fetch(`${base}/info.json`, { signal: ctrl.signal }).then((r) => r.json()),
      fetch(`${base}/players.json`, { signal: ctrl.signal }).then((r) => r.json())
    ]);
    clearTimeout(t);
    return { online: true, players: players.length, max: Number(info.vars?.sv_maxClients) || 48 };
  } catch {
    return { online: false };
  }
});
ipcMain.handle('link:open', (_e, url) => {
  if (ALLOWED_LINKS.has(url)) shell.openExternal(url);
});
ipcMain.on('win:minimize', () => win && win.minimize());
ipcMain.on('win:close', () => win && win.close());

app.whenReady().then(createWindow);
app.on('window-all-closed', () => app.quit());
