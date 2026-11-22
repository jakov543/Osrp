// OSRP Osijek - minimap + big map (F7). Positions come in city coordinates (metres from Config.Origin).
// v1.0.35: redesigned - rounded radar with glow arrow and GPS distance, big map with sidebar (places, search, GPS), zoom buttons
const $ = (id) => document.getElementById(id);
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'osrp_osijek';
const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}) }).catch(() => {});

let META = { x0: -590, y1: 380, ppm: 3, w: 3540, h: 3540, landmarks: [] };
const ICONS = [
  ['Bolnica', '🏥', '#ef4444'], ['Policija', '🚓', '#3b82f6'], ['Oružarnica', '🔫', '#f97316'], ['Zračna', '✈️', '#38bdf8'],
  ['Konkatedrala', '⛪', '#f4b740'], ['Trojstva', '⛲', '#f4b740'], ['park', '🌳', '#22c55e'], ['Copacabana', '🏖️', '#facc15'],
  ['most', '🌉', '#a78bfa'], ['STIL', '👕', '#ec4899'], ['VOLT', '📱', '#38bdf8'], ['Promenada', '🚶', '#1fd6b6'], ['avenija', '🛣️', '#94a3b8'],
];
const st = { x: 0, y: 0, cam: 0, ped: 0, speed: 0, scale: 0.7, wp: null, wpName: null, route: [], players: [], street: '' };

const toPx = (x, y) => [(x - META.x0) * META.ppm, (META.y1 - y) * META.ppm];
const fromPx = (px, py) => [px / META.ppm + META.x0, META.y1 - py / META.ppm];
const dist = (x, y) => Math.hypot(x - st.x, y - st.y);
const fmtDist = (m) => (m >= 1000 ? (m / 1000).toFixed(1) + ' km' : Math.round(m) + ' m');

fetch('map.json').then((r) => r.json()).then((m) => { META = m; buildLandmarks(); buildPlaces(); }).catch(() => {});

// ---------------------------------------------------------------- markers
function iconFor(name) {
  for (const [k, ic, c] of ICONS) if (name.toLowerCase().includes(k.toLowerCase())) return [ic, c];
  return ['📍', '#94a3b8'];
}
const landmarkEls = { small: [], big: [] };
function makeMark(parent, cls, html, x, y, color) {
  const el = document.createElement('div');
  el.className = 'mk ' + cls;
  el.innerHTML = `<span>${html}</span>`;
  if (color) el.style.setProperty('--c', color);
  el.dataset.x = x; el.dataset.y = y;
  parent.appendChild(el);
  return el;
}
function buildLandmarks() {
  $('marks').innerHTML = ''; $('bigMarks').innerHTML = '';
  landmarkEls.small = []; landmarkEls.big = [];
  for (const l of META.landmarks || []) {
    const [ic, c] = iconFor(l[0]);
    if (ic === '🛣️' || ic === '🚶') continue;               // streets are in the list, not on the map
    landmarkEls.small.push(makeMark($('marks'), 'lm', ic, l[1], l[2], c));
    const b = makeMark($('bigMarks'), 'lm', ic, l[1], l[2], c);
    b.insertAdjacentHTML('beforeend', `<em>${l[0]}</em>`);
    b.querySelector('em').style.transform = 'translateX(-50%)';
    landmarkEls.big.push(b);
  }
  wpSmall = wpBig = null;
  if (st.wp) setWaypoint(st.wp);
}
function placeMark(el, rot, scale) {
  const [px, py] = toPx(+el.dataset.x, +el.dataset.y);
  el.style.transform = `translate(${px}px, ${py}px) rotate(${-rot}deg) scale(${1 / scale})`;
}
function setRoute(svg, pts, width) {
  if (!pts || pts.length < 2) { svg.innerHTML = ''; return; }
  const p = pts.map(([x, y]) => toPx(x, y).join(',')).join(' ');
  svg.setAttribute('width', META.w); svg.setAttribute('height', META.h);
  svg.innerHTML = `<polyline points="${p}" stroke-width="${width}" />`;
}

// ---------------------------------------------------------------- minimap
let wpSmall = null, wpBig = null;
const playerEls = [];
function renderRadar() {
  const clip = $('radar').querySelector('.clip');
  const cw = clip.clientWidth, ch = clip.clientHeight;
  if (!cw) return;
  const view = 140 + Math.min(1, st.speed / 30) * 220;                  // metres across, zooms out when driving
  const target = cw / (view * META.ppm);
  st.scale += (target - st.scale) * 0.08;
  const [px, py] = toPx(st.x, st.y);
  $('layer').style.transform = `rotate(${st.cam}deg) scale(${st.scale}) translate(${-px}px, ${-py}px)`;
  $('me').style.transform = `rotate(${st.cam - st.ped}deg)`;
  for (const el of landmarkEls.small) placeMark(el, st.cam, st.scale);
  if (wpSmall) placeMark(wpSmall, st.cam, st.scale);
  for (const el of playerEls) placeMark(el, st.cam, st.scale);
  const rx = cw / 2 - 13, ry = ch / 2 - 13, a = st.cam * Math.PI / 180;
  const n = $('north');
  n.style.left = (cw / 2 + Math.sin(a) * rx) + 'px';
  n.style.top = (ch / 2 - Math.cos(a) * ry) + 'px';
  const rs = $('route').querySelector('polyline');
  if (rs) rs.setAttribute('stroke-width', 8 / st.scale);
  const dd = $('rdDist');
  if (st.wp) { dd.classList.remove('hidden'); dd.textContent = '📍 ' + fmtDist(dist(st.wp[0], st.wp[1])); } else dd.classList.add('hidden');
}

function setPlayers(list) {
  while (playerEls.length > list.length) playerEls.pop().remove();
  while (playerEls.length < list.length) playerEls.push(makeMark($('marks'), 'pl', '', 0, 0));
  list.forEach((p, i) => { playerEls[i].dataset.x = p[0]; playerEls[i].dataset.y = p[1]; });
}

function nearestName(x, y) {
  let best = null, bd = 60;
  for (const l of META.landmarks || []) { const d = Math.hypot(l[1] - x, l[2] - y); if (d < bd) { bd = d; best = l[0]; } }
  return best;
}
function setWaypoint(wp) {
  st.wp = wp;
  if (wpSmall) { wpSmall.remove(); wpSmall = null; }
  if (wpBig) { wpBig.remove(); wpBig = null; }
  if (wp) {
    wpSmall = makeMark($('marks'), 'wp', '', wp[0], wp[1]);
    wpBig = makeMark($('bigMarks'), 'wp', '', wp[0], wp[1]);
  }
  updateSide();
  renderBig();
}

// ---------------------------------------------------------------- big map
const big = { open: false, s: 0.5, tx: 0, ty: 0, drag: null, moved: 0 };
let meBig = null;
function renderBig() {
  if (!big.open) return;
  $('bigLayer').style.transform = `translate(${big.tx}px, ${big.ty}px) scale(${big.s})`;
  $('big').classList.toggle('zoomed', big.s > 0.55);
  for (const el of landmarkEls.big) placeMark(el, 0, big.s);
  if (wpBig) placeMark(wpBig, 0, big.s);
  if (meBig) {
    meBig.dataset.x = st.x; meBig.dataset.y = st.y;
    placeMark(meBig, 0, big.s);
    meBig.querySelector('svg').style.transform = `translate(-50%, -50%) rotate(${-st.ped}deg)`;
  }
  const rb = $('bigRoute').querySelector('polyline');
  if (rb) rb.setAttribute('stroke-width', 7 / big.s);
}
function centerOn(x, y, s) {
  const v = $('view');
  if (s) big.s = s;
  const [px, py] = toPx(x, y);
  big.tx = v.clientWidth / 2 - px * big.s;
  big.ty = v.clientHeight / 2 - py * big.s;
  renderBig();
}
function zoomAt(mx, my, f) {
  const ns = Math.min(3, Math.max(0.15, big.s * f));
  big.tx = mx - (mx - big.tx) * (ns / big.s);
  big.ty = my - (my - big.ty) * (ns / big.s);
  big.s = ns;
  renderBig();
}
function openBig() {
  big.open = true;
  $('big').classList.remove('hidden');
  const v = $('view');
  if (!meBig) {
    meBig = makeMark($('bigMarks'), 'me2', '', st.x, st.y);
    meBig.querySelector('span').innerHTML = '<svg viewBox="0 0 24 28"><path d="M12 1 L22 26 L12 20 L2 26 Z"/></svg>';
  }
  centerOn(st.x, st.y, Math.min(1.2, Math.max(0.25, v.clientHeight / 1800)));
  $('search').value = '';
  buildPlaces();
  updateSide();
}
function closeBig(notify) {
  big.open = false;
  $('big').classList.add('hidden');
  if (notify) post('closeBig');
}

// sidebar: places list with GPS, current location, waypoint box
function buildPlaces() {
  const q = ($('search').value || '').toLowerCase().trim();
  const list = (META.landmarks || []).filter((l) => !q || l[0].toLowerCase().includes(q))
    .map((l) => ({ l, d: dist(l[1], l[2]) })).sort((a, b) => a.d - b.d);
  $('places').innerHTML = list.map(({ l, d }, i) => {
    const [ic, c] = iconFor(l[0]);
    return `<div class="place" data-i="${i}" style="--c:${c}"><i>${ic}</i><div><b>${l[0]}</b><small>${fmtDist(d)}</small></div><span class="go">GPS</span></div>`;
  }).join('') || '<small style="color:#8e9db0">Nema rezultata.</small>';
  $('places').querySelectorAll('.place').forEach((el) => {
    const l = list[+el.dataset.i].l;
    el.addEventListener('mouseenter', () => centerOn(l[1], l[2]));
    el.addEventListener('click', () => { st.wpName = l[0]; post('setWaypoint', { x: l[1], y: l[2] }); });
  });
}
function updateSide() {
  $('hereTxt').textContent = st.street || nearestName(st.x, st.y) || 'Osijek';
  const box = $('wpBox');
  if (st.wp) {
    box.classList.remove('hidden');
    $('wpTxt').textContent = (st.wpName || nearestName(st.wp[0], st.wp[1]) || 'Točka na karti') + ' · ' + fmtDist(dist(st.wp[0], st.wp[1]));
  } else { box.classList.add('hidden'); st.wpName = null; }
}
$('search').addEventListener('input', buildPlaces);
$('search').addEventListener('keydown', (e) => e.stopPropagation());
$('wpClear').addEventListener('click', () => post('clearWaypoint'));
$('zIn').addEventListener('click', () => { const v = $('view'); zoomAt(v.clientWidth / 2, v.clientHeight / 2, 1.35); });
$('zOut').addEventListener('click', () => { const v = $('view'); zoomAt(v.clientWidth / 2, v.clientHeight / 2, 1 / 1.35); });
$('zMe').addEventListener('click', () => centerOn(st.x, st.y));

const view = $('view');
view.addEventListener('wheel', (e) => {
  const r = view.getBoundingClientRect();
  zoomAt(e.clientX - r.left, e.clientY - r.top, e.deltaY < 0 ? 1.15 : 1 / 1.15);
});
view.addEventListener('mousedown', (e) => {
  if (e.target.closest('button')) return;
  if (e.button === 2) { post('clearWaypoint'); return; }
  big.drag = { x: e.clientX, y: e.clientY, tx: big.tx, ty: big.ty };
  big.moved = 0;
});
window.addEventListener('mousemove', (e) => {
  if (big.open) {
    const r = view.getBoundingClientRect();
    if (e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom) {
      const [x, y] = fromPx((e.clientX - r.left - big.tx) / big.s, (e.clientY - r.top - big.ty) / big.s);
      const nm = nearestName(x, y);
      $('cursorTxt').textContent = (nm ? nm + ' · ' : '') + fmtDist(dist(x, y)) + ' od tebe';
    } else $('cursorTxt').textContent = '';
  }
  if (!big.drag) return;
  const dx = e.clientX - big.drag.x, dy = e.clientY - big.drag.y;
  big.moved = Math.max(big.moved, Math.abs(dx) + Math.abs(dy));
  if (big.moved > 4) view.classList.add('drag');
  big.tx = big.drag.tx + dx; big.ty = big.drag.ty + dy;
  renderBig();
});
window.addEventListener('mouseup', (e) => {
  if (!big.drag) return;
  view.classList.remove('drag');
  if (big.moved < 5 && e.button === 0) {
    const r = view.getBoundingClientRect();
    const [x, y] = fromPx((e.clientX - r.left - big.tx) / big.s, (e.clientY - r.top - big.ty) / big.s);
    st.wpName = null;
    post('setWaypoint', { x, y });
  }
  big.drag = null;
});
view.addEventListener('contextmenu', (e) => e.preventDefault());
$('close').addEventListener('click', () => closeBig(true));
window.addEventListener('keydown', (e) => {
  if (big.open && (e.key === 'Escape' || e.key === 'F7' || e.key === 'Backspace')) closeBig(true);
});

// ---------------------------------------------------------------- messages from Lua
window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.t) {
    case 'radar': {
      const r = $('radar');
      r.classList.toggle('hidden', !d.show);
      if (d.left !== undefined) {
        r.style.left = (d.left * 100) + 'vw'; r.style.top = (d.top * 100) + 'vh';
        r.style.width = (d.w * 100) + 'vw'; r.style.height = (d.h * 100) + 'vh';
      }
      break;
    }
    case 'pos':
      st.x = d.x; st.y = d.y; st.cam = d.cam; st.ped = d.ped; st.speed = d.speed || 0;
      if (d.street) st.street = d.street;
      if (d.players) setPlayers(d.players);
      renderRadar();
      if (big.open) { renderBig(); updateSide(); }
      break;
    case 'wp': setWaypoint(d.wp); break;
    case 'route':
      setRoute($('route'), d.pts, 8 / st.scale);
      setRoute($('bigRoute'), d.pts, 7 / big.s);
      renderBig();
      break;
    case 'big': if (d.open) openBig(); else closeBig(false); break;
  }
});
