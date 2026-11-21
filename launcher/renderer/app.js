// OSRP Launcher V1 - main window
const $ = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let INFO = null;

function show(screen) {
  document.querySelectorAll('.screen').forEach((s) => s.classList.remove('active'));
  $('screen-' + screen).classList.add('active');
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

const PLATFORM_NAMES = { steam: 'Steam', epic: 'Epic Games', rockstar: 'Rockstar' };

// ---------- OSRP account (own login) ----------
let authMode = 'login';

function setAuthMode(mode) {
  authMode = mode;
  document.querySelectorAll('.auth-tab').forEach((t) => t.classList.toggle('on', t.dataset.mode === mode));
  $('pass2Wrap').hidden = mode !== 'register';
  $('btnAuth').textContent = mode === 'register' ? 'Napravi račun' : 'Prijavi se';
  $('authText').textContent = mode === 'register'
    ? 'Napravi besplatni OSRP račun. Korisničko ime: 3-16 znakova (slova, brojevi, _).'
    : 'Prijavi se svojim OSRP računom.';
  $('authPass').autocomplete = mode === 'register' ? 'new-password' : 'current-password';
  $('loginErr').textContent = '';
}

async function initLogin() {
  document.querySelectorAll('.auth-tab').forEach((t) => t.addEventListener('click', () => setAuthMode(t.dataset.mode)));
  $('authForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const user = $('authUser').value.trim();
    const pass = $('authPass').value;
    $('loginErr').textContent = '';
    if (!/^[A-Za-z0-9_]{3,16}$/.test(user)) { $('loginErr').textContent = 'Korisničko ime: 3-16 znakova (slova, brojevi, _).'; return; }
    if (pass.length < 6) { $('loginErr').textContent = 'Lozinka mora imati najmanje 6 znakova.'; return; }
    if (authMode === 'register' && pass !== $('authPass2').value) { $('loginErr').textContent = 'Lozinke se ne podudaraju.'; return; }
    $('btnAuth').classList.add('loading');
    const r = authMode === 'register' ? await window.launcher.register(user, pass) : await window.launcher.login(user, pass);
    $('btnAuth').classList.remove('loading');
    if (!r.ok) {
      $('loginErr').textContent = r.error;
      $('btnGuest').hidden = !r.offline;
      return;
    }
    $('btnGuest').hidden = true;
    $('authPass').value = '';
    $('authPass2').value = '';
    afterLogin();
  });
  const showAddr = async () => { $('loginAddr').textContent = await window.launcher.getServerAddress(); };
  showAddr();
  $('btnLoginAddr').addEventListener('click', async () => {
    $('loginAddrEdit').hidden = !$('loginAddrEdit').hidden;
    $('loginAddrInput').value = await window.launcher.getServerAddress();
  });
  $('btnLoginAddrSave').addEventListener('click', async () => {
    const r = await window.launcher.setServerAddress($('loginAddrInput').value);
    if (!r.ok) { $('loginErr').textContent = r.error; return; }
    $('loginErr').textContent = '';
    $('loginAddrEdit').hidden = true;
    showAddr();
  });
  $('btnGuest').addEventListener('click', async () => {
    await window.launcher.guest($('authUser').value.trim());
    $('btnGuest').hidden = true;
    afterLogin();
  });
  $('btnLogout').addEventListener('click', async () => {
    await window.launcher.logout();
    setAuthMode('login');
    show('login');
  });
}

async function afterLogin() {
  const s = await window.launcher.getSettings();
  renderProfile(s.account);
  if (!s.ownershipConfirmed) show('own');
  else if (!s.gamePath) goGameSetup();
  else goMain();
}

function renderProfile(acc) {
  const name = (acc && acc.name) || '—';
  $('pName').textContent = name;
  $('pEmail').textContent = acc && acc.guest ? 'Bez računa' : 'OSRP račun';
  $('avatar').textContent = name[0] ? name[0].toUpperCase() : '?';
}

// ---------- ownership ----------
function initOwnership() {
  $('ownCheck').addEventListener('change', (e) => ($('btnOwn').disabled = !e.target.checked));
  $('btnOwn').addEventListener('click', async () => {
    await window.launcher.confirmOwnership();
    goGameSetup();
  });
  document.querySelectorAll('.store').forEach((b) =>
    b.addEventListener('click', () => window.launcher.openLink(INFO.stores[b.dataset.store]))
  );
}

// ---------- game setup ----------
function setPlatformChip(p) {
  document.querySelectorAll('.chip').forEach((c) => c.classList.toggle('on', c.dataset.p === p));
}

function setGameFound(gamePath, platform) {
  $('pathBox').textContent = gamePath;
  $('detectText').textContent = 'GTA V je pronađen! Provjeri platformu i nastavi.';
  $('gameErr').textContent = '';
  setPlatformChip(platform);
  $('btnGameNext').disabled = false;
}

async function runDetect() {
  $('detectText').textContent = 'Tražim GTA5.exe na tvom računalu...';
  $('pathBox').innerHTML = '<span class="spinner"></span>';
  $('btnGameNext').disabled = true;
  const r = await window.launcher.detectGame();
  if (r.found) setGameFound(r.gamePath, r.platform);
  else {
    $('pathBox').textContent = 'Nije pronađeno';
    $('detectText').textContent = 'Nisam našao igru automatski. Odaberi GTA5.exe ručno (mapa gdje je instaliran GTA V).';
  }
}

function initGameSetup() {
  $('btnDetect').addEventListener('click', runDetect);
  $('btnBrowse').addEventListener('click', async () => {
    const r = await window.launcher.browseGame();
    if (r.canceled) return;
    if (!r.ok) { $('gameErr').textContent = r.error; return; }
    setGameFound(r.gamePath, r.platform);
  });
  document.querySelectorAll('.chip').forEach((c) =>
    c.addEventListener('click', async () => {
      setPlatformChip(c.dataset.p);
      await window.launcher.setPlatform(c.dataset.p);
    })
  );
  $('btnGameNext').addEventListener('click', goMain);
}

async function goGameSetup() {
  show('game');
  const s = await window.launcher.getSettings();
  if (s.gamePath) setGameFound(s.gamePath, s.platform);
  else runDetect();
}

// ---------- main ----------
function renderNews() {
  const news = INFO.config.news || [];
  const html = (list) => list.map((n) =>
    `<div class="news-item">${n.tag ? `<span class="tag">${escapeHtml(n.tag)}</span>` : ''}<h3>${escapeHtml(n.title)}</h3><p>${escapeHtml(n.text)}</p></div>`
  ).join('');
  $('newsHome').innerHTML = html(news.slice(0, 2));
  $('newsAll').innerHTML = html(news);
}

async function refreshSettings() {
  const s = await window.launcher.getSettings();
  $('setPath').textContent = s.gamePath || '—';
  $('setPlatform').textContent = PLATFORM_NAMES[s.platform] || '—';
  if (document.activeElement !== $('addrInput')) $('addrInput').value = await window.launcher.getServerAddress();
  $('setVer').textContent = 'v' + INFO.version + ' (V1)';
  $('miniGame').textContent = s.gamePath ? (PLATFORM_NAMES[s.platform] || 'GTA V') : 'Nije pronađen';
}

function applyStatus(st) {
  const on = !!(st && st.online);
  ['sDot', 'sDot2'].forEach((id) => ($(id).className = 'sdot ' + (on ? 'on' : 'off')));
  $('sTitle').textContent = on ? 'OSRP je ONLINE' : 'Server je offline';
  $('sSub').textContent = on ? `${st.players} / ${st.max} igrača` : (st.address || '');
  $('sTitle2').textContent = on ? 'Online' : 'Offline';
  $('sSub2').textContent = on ? `${st.players} / ${st.max} igrača` : 'Server trenutno nije dostupan';
  $('ssFill').style.width = on ? Math.min(100, (st.players / st.max) * 100) + '%' : '0';
  $('miniServer').textContent = on ? 'Online' : 'Offline';
  $('miniPlayers').textContent = on ? `${st.players} / ${st.max}` : '—';
}

async function refreshStatus() {
  applyStatus(await window.launcher.serverStatus());
}

function openLicense() {
  $('licCheck').checked = false;
  $('licOk').disabled = true;
  $('licModal').classList.add('show');
}

function initLicense() {
  $('licCheck').addEventListener('change', (e) => ($('licOk').disabled = !e.target.checked));
  $('licLink').addEventListener('click', (e) => { e.preventDefault(); window.launcher.openLink(INFO.stores.fivemLicense); });
  $('licCancel').addEventListener('click', () => $('licModal').classList.remove('show'));
  $('licOk').addEventListener('click', async () => {
    await window.launcher.acceptFiveMLicense();
    $('licModal').classList.remove('show');
    launch('server');
  });
  window.launcher.onFiveMProgress((d) => {
    if (d.stage === 'download') {
      $('ovText').textContent = `Preuzimam OSRP klijent... ${d.mb} MB`;
      $('ovFill').style.width = Math.round((d.fraction || 0) * 100) + '%';
    } else if (d.stage === 'install') {
      $('ovText').textContent = 'Instalacija klijenta - završi postavljanje u prozoru koji se otvorio (Rockstar prijava)...';
      $('ovFill').style.width = '100%';
    } else if (d.stage === 'connect') {
      $('ovText').textContent = 'Spajam se na OSRP...';
      $('ovFill').style.width = '100%';
    }
  });
}

async function launch(mode) {
  $('playErr').textContent = '';
  $('overlay').classList.add('show');
  const steps = mode === 'server'
    ? ['Provjeravam GTA V...', 'Provjeravam OSRP klijent...']
    : ['Provjeravam GTA V...', 'Pokrećem GTA V...'];
  for (let i = 0; i < steps.length; i++) {
    $('ovText').textContent = steps[i];
    $('ovFill').style.width = ((i + 1) / steps.length) * 100 + '%';
    await sleep(550);
  }
  const r = await window.launcher.play(mode);
  await sleep(600);
  $('overlay').classList.remove('show');
  $('ovFill').style.width = '0';
  if (r.needLicense) return openLicense();
  if (!r.ok) $('playErr').textContent = r.error;
}

function initMain() {
  renderNews();
  document.querySelectorAll('.nav').forEach((b) =>
    b.addEventListener('click', () => {
      document.querySelectorAll('.nav').forEach((x) => x.classList.remove('active'));
      document.querySelectorAll('.tab').forEach((x) => x.classList.remove('active'));
      b.classList.add('active');
      $('tab-' + b.dataset.tab).classList.add('active');
      if (b.dataset.tab === 'settings') refreshSettings();
    })
  );
  $('btnPlay').addEventListener('click', () => launch('server'));
  $('btnSingle').addEventListener('click', () => launch('single'));
  $('btnChangeGame').addEventListener('click', goGameSetup);
  $('btnAddr').addEventListener('click', async () => {
    const r = await window.launcher.setServerAddress($('addrInput').value);
    $('addrMsg').className = 'addr-msg ' + (r.ok ? 'ok' : 'bad');
    $('addrMsg').textContent = r.ok ? 'Spremljeno: ' + r.address : r.error;
    if (r.ok) { $('addrInput').value = r.address; refreshStatus(); }
  });
  $('btnReset').addEventListener('click', async () => {
    await window.launcher.reset();
    $('ownCheck').checked = false;
    $('btnOwn').disabled = true;
    show('login');
  });
  $('lnkDiscord').addEventListener('click', () => window.launcher.openLink(INFO.config.discord));
}

function goMain() {
  show('main');
  refreshSettings();
  refreshStatus();
}

// ---------- start (splash window already did the loading) ----------
(async function start() {
  $('btnMin').addEventListener('click', () => window.launcher.minimize());
  $('btnClose').addEventListener('click', () => window.launcher.close());

  INFO = await window.launcher.info();
  $('ver').textContent = 'v' + INFO.version;
  await initLogin();
  initLicense();
  initOwnership();
  initGameSetup();
  initMain();
  setInterval(() => { if ($('screen-main').classList.contains('active')) refreshStatus(); }, 30000);

  const boot = await window.launcher.bootResult();
  const s = (boot && boot.settings) || (await window.launcher.getSettings());
  const acc = await window.launcher.checkAccount();
  renderProfile(acc.account);
  if (!acc.loggedIn) {
    show('login');
    if (acc.expired) $('loginErr').textContent = 'Prijava je istekla. Prijavi se ponovno.';
  }
  else if (!s.ownershipConfirmed) show('own');
  else if (!s.gamePath) goGameSetup();
  else {
    show('main');
    refreshSettings();
    if (boot && boot.status) applyStatus(boot.status); else refreshStatus();
  }
})();
