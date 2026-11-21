// Osijek Launcher V1 - renderer
const $ = (id) => document.getElementById(id);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let INFO = null;
let selectedPlatform = null;

function show(screen) {
  document.querySelectorAll('.screen').forEach((s) => s.classList.remove('active'));
  $('screen-' + screen).classList.add('active');
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// ---------- own loading screen ----------
async function bootLoading() {
  const steps = ['Učitavanje...', 'Provjera datoteka...', 'Učitavam postavke...', 'Spajam se na Osijek...', 'Spremno!'];
  for (let i = 0; i < steps.length; i++) {
    $('loadText').textContent = steps[i];
    $('loadFill').style.width = ((i + 1) / steps.length) * 100 + '%';
    await sleep(380);
  }
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
  selectedPlatform = p;
  document.querySelectorAll('.chip').forEach((c) => c.classList.toggle('on', c.dataset.p === p));
}

function setGameFound(gamePath, platform) {
  $('pathBox').textContent = gamePath;
  $('detectText').textContent = 'GTA V je pronađen!';
  $('gameErr').textContent = '';
  setPlatformChip(platform);
  $('btnGameNext').disabled = false;
}

async function runDetect() {
  $('detectText').textContent = 'Tražim GTA5.exe na tvom računalu...';
  $('pathBox').textContent = '...';
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

function goGameSetup() {
  show('game');
  runDetect();
}

// ---------- main ----------
async function refreshSettingsTab() {
  const s = await window.launcher.getSettings();
  $('setPath').textContent = s.gamePath || '—';
  $('setPlatform').textContent = s.platform || '—';
  $('setServer').textContent = INFO.config.serverAddress;
}

async function refreshStatus() {
  const st = await window.launcher.serverStatus();
  $('sDot').className = 'sdot ' + (st.online ? 'on' : 'off');
  $('sTitle').textContent = st.online ? 'Osijek je ONLINE' : 'Server je offline';
  $('sSub').textContent = st.online ? `${st.players} / ${st.max} igrača` : INFO.config.serverAddress;
}

async function launch(mode) {
  $('playErr').textContent = '';
  $('overlay').classList.add('show');
  const steps = mode === 'server'
    ? ['Provjeravam GTA V...', 'Pokrećem FiveM...', 'Spajam se na Osijek...']
    : ['Provjeravam GTA V...', 'Pokrećem GTA V...'];
  for (let i = 0; i < steps.length; i++) {
    $('ovText').textContent = steps[i];
    $('ovFill').style.width = ((i + 1) / steps.length) * 100 + '%';
    await sleep(500);
  }
  const r = await window.launcher.play(mode);
  await sleep(600);
  $('overlay').classList.remove('show');
  $('ovFill').style.width = '0';
  if (!r.ok) $('playErr').textContent = r.error;
}

function initMain() {
  const news = INFO.config.news || [];
  $('news').innerHTML = news.map((n) =>
    `<div class="news-item"><h3>${escapeHtml(n.title)}</h3><p>${escapeHtml(n.text)}</p></div>`).join('');

  document.querySelectorAll('.nav').forEach((b) =>
    b.addEventListener('click', () => {
      document.querySelectorAll('.nav').forEach((x) => x.classList.remove('active'));
      document.querySelectorAll('.tab').forEach((x) => x.classList.remove('active'));
      b.classList.add('active');
      $('tab-' + b.dataset.tab).classList.add('active');
      if (b.dataset.tab === 'settings') refreshSettingsTab();
    })
  );

  $('btnPlay').addEventListener('click', () => launch('server'));
  $('btnSingle').addEventListener('click', () => launch('single'));
  $('btnChangeGame').addEventListener('click', goGameSetup);
  $('btnReset').addEventListener('click', async () => {
    await window.launcher.reset();
    $('ownCheck').checked = false;
    $('btnOwn').disabled = true;
    show('own');
  });
  $('lnkDiscord').addEventListener('click', () => window.launcher.openLink(INFO.config.discord));
  $('lnkFivem').addEventListener('click', () => window.launcher.openLink(INFO.stores.fivem));
}

function goMain() {
  show('main');
  refreshStatus();
}

// ---------- start ----------
(async function start() {
  $('btnMin').addEventListener('click', () => window.launcher.minimize());
  $('btnClose').addEventListener('click', () => window.launcher.close());

  INFO = await window.launcher.info();
  $('ver').textContent = 'v' + INFO.version;
  initOwnership();
  initGameSetup();
  initMain();
  setInterval(() => { if ($('screen-main').classList.contains('active')) refreshStatus(); }, 30000);

  await bootLoading();
  const s = await window.launcher.getSettings();
  if (!s.ownershipConfirmed) show('own');
  else if (!s.gamePath) goGameSetup();
  else goMain();
})();
