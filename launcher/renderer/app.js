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

// ---------- Google login ----------
async function initLogin() {
  const configured = await window.launcher.googleConfigured();
  $('googleNotice').hidden = configured;
  $('btnGoogle').disabled = !configured;
  $('btnGoogle').addEventListener('click', async () => {
    $('loginErr').textContent = '';
    $('btnGoogle').disabled = true;
    $('googleText').textContent = 'Čekam prijavu u pregledniku...';
    const r = await window.launcher.googleLogin();
    $('btnGoogle').disabled = false;
    $('googleText').textContent = 'Prijava s Googleom';
    if (!r.ok) { $('loginErr').textContent = r.error; return; }
    afterLogin();
  });
  $('btnGuest').addEventListener('click', async () => {
    await window.launcher.skipLogin();
    afterLogin();
  });
  $('btnLogout').addEventListener('click', async () => {
    await window.launcher.googleLogout();
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
  const a = acc || { name: '—' };
  $('pName').textContent = a.name || '—';
  $('pEmail').textContent = a.guest ? 'Gost' : (a.email || '');
  const av = $('avatar');
  av.textContent = '';
  if (a.picture && /^https:\/\/[\w.-]+\.googleusercontent\.com\//.test(a.picture)) {
    const img = document.createElement('img');
    img.src = a.picture;
    img.referrerPolicy = 'no-referrer';
    img.onerror = () => { av.textContent = (a.name || '?')[0].toUpperCase(); };
    av.appendChild(img);
  } else av.textContent = (a.name || '?')[0].toUpperCase();
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
  renderProfile(s.account);
  const configured = await window.launcher.googleConfigured();
  const loggedIn = s.account && (!s.account.guest || !configured);
  if (!loggedIn) show('login');
  else if (!s.ownershipConfirmed) show('own');
  else if (!s.gamePath) goGameSetup();
  else {
    show('main');
    refreshSettings();
    if (boot && boot.status) applyStatus(boot.status); else refreshStatus();
  }
})();
