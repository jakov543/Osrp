// OSRP framework NUI
const $ = (id) => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'osrp_framework';
const post = (name, data) => fetch(`https://${resource}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}),
}).catch(() => {});
const money = (n) => '$' + Number(n || 0).toLocaleString('hr-HR');
const esc = (t) => String(t ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

// ================= character selection / creator / spawn (v1.0.16) =================
const M = { chars: [], max: 3, sel: null, sex: 'm', outfit: 1, rot: 0, spawn: null, sending: false };
const show = (id) => ['pChars', 'pCreate', 'pSpawn'].forEach((p) => $(p).classList.toggle('hidden', p !== id));

function look() {
  return { face: +$('cFace').value, skin: +$('cSkin').value, hair: +$('cHair').value, hairColor: +$('cHairC').value, outfit: M.outfit };
}
function previewNew() { post('preview', { sex: M.sex, appearance: look(), rot: M.rot }); updateCard(); }
function updateCard(c) {
  const d = c || {
    firstname: $('cFirst').value.trim() || '—', lastname: $('cLast').value.trim() || '—', sex: M.sex,
    height: +$('cHeight').value, dob: $('cDob').value, nationality: $('cNation').value,
  };
  $('iFirst').textContent = (d.firstname || '—').toUpperCase();
  $('iLast').textContent = (d.lastname || '—').toUpperCase();
  $('iSex').textContent = d.sex === 'f' ? 'Ž' : 'M';
  $('iHeight').textContent = (d.height || 180) + ' cm';
  $('iDob').textContent = d.dob ? d.dob.split('-').reverse().join('.') + '.' : '—';
  $('iNation').textContent = d.nationality || 'Hrvatska';
}

function renderChars() {
  const list = $('charList');
  list.innerHTML = '';
  M.chars.forEach((c) => {
    const el = document.createElement('div');
    el.className = 'ch' + (M.sel === c.cid ? ' on' : '');
    el.innerHTML = `<div class="n">${esc(c.firstname)} ${esc(c.lastname)}</div><span class="j">${esc(c.job)}</span>
      <div class="m"><span>Gotovina <b>${money(c.cash)}</b></span><span>Banka <b>${money(c.bank)}</b></span></div>
      <div class="acts"><button class="go play">▶ Odaberi</button><button class="danger del">Obriši</button></div>`;
    el.addEventListener('click', (e) => {
      if (e.target.closest('.acts')) return;
      M.sel = c.cid; M.rot = 0;
      post('preview', { sex: c.sex, appearance: c.appearance, rot: 0 });
      $('idCard').classList.remove('hidden');
      updateCard(c);
      renderChars();
    });
    el.querySelector('.play').addEventListener('click', () => post('selectChar', { cid: c.cid }));
    const del = el.querySelector('.del');
    del.addEventListener('click', () => {
      if (!del.classList.contains('sure')) { del.classList.add('sure'); del.textContent = 'Sigurno?'; return; }
      post('deleteChar', { cid: c.cid });
      M.sel = null; $('idCard').classList.add('hidden'); post('preview', {});
    });
    list.appendChild(el);
  });
  if (M.chars.length < M.max) {
    const n = document.createElement('div');
    n.className = 'ch new';
    n.innerHTML = '<span style="font-size:22px">＋</span> Novi lik';
    n.addEventListener('click', openCreate);
    list.appendChild(n);
  }
  for (let i = M.chars.length + 1; i < M.max; i++) {
    const e = document.createElement('div');
    e.className = 'ch empty';
    e.textContent = 'Slobodno mjesto';
    list.appendChild(e);
  }
}

function openCreate() {
  show('pCreate');
  $('err').textContent = '';
  $('idCard').classList.remove('hidden');
  M.sending = false; $('go').disabled = false;
  previewNew();
  $('cFirst').focus();
}

document.querySelectorAll('.sex button').forEach((b) => b.addEventListener('click', () => {
  M.sex = b.dataset.sex;
  document.querySelectorAll('.sex button').forEach((x) => x.classList.toggle('on', x === b));
  previewNew();
}));
[['cFace', 'vFace', 1], ['cSkin', 'vSkin', 1], ['cHair', 'vHair', 1], ['cHairC', 'vHairC', 1], ['cHeight', 'vHeight', 0]].forEach(([i, v, add]) => {
  $(i).addEventListener('input', () => {
    $(v).textContent = add ? (+$(i).value + 1) : $(i).value + ' cm';
    if (i === 'cHeight') updateCard(); else previewNew();
  });
});
['cFirst', 'cLast', 'cDob', 'cNation'].forEach((i) => $(i).addEventListener('input', () => updateCard()));
['Casual', 'Jakna', 'Odijelo', 'Sport'].forEach((name, k) => {
  const b = document.createElement('button');
  b.textContent = name;
  if (k === 0) b.classList.add('on');
  b.addEventListener('click', () => {
    M.outfit = k + 1;
    document.querySelectorAll('#cOutfits button').forEach((x) => x.classList.toggle('on', x === b));
    previewNew();
  });
  $('cOutfits').appendChild(b);
});
$('rotL').addEventListener('click', () => { M.rot = (M.rot + 45) % 360; previewNew(); });
$('rotR').addEventListener('click', () => { M.rot = (M.rot + 315) % 360; previewNew(); });
$('cBack').addEventListener('click', () => { show('pChars'); $('idCard').classList.add('hidden'); post('preview', {}); });
$('go').addEventListener('click', () => {
  if (M.sending) return;
  const firstname = $('cFirst').value.trim(), lastname = $('cLast').value.trim(), dob = $('cDob').value;
  if (firstname.length < 2 || lastname.length < 2) { $('err').textContent = 'Upiši ime i prezime (min. 2 slova).'; return; }
  if (!dob) { $('err').textContent = 'Upiši datum rođenja.'; return; }
  $('err').textContent = '';
  M.sending = true; $('go').disabled = true;
  post('createChar', { firstname, lastname, dob, sex: M.sex, height: +$('cHeight').value, nationality: $('cNation').value, appearance: look() });
  setTimeout(() => { M.sending = false; $('go').disabled = false; }, 2500);
});

function openSpawn(d) {
  $('idCard').classList.add('hidden');
  show('pSpawn');
  $('spawnWho').textContent = d.name;
  M.spawn = null; $('spawnGo').disabled = true;
  const list = $('spawnList');
  list.innerHTML = '';
  d.points.forEach((p) => {
    const el = document.createElement('div');
    el.className = 'sp' + (p.disabled ? ' off' : '');
    el.innerHTML = `<div class="ic">${p.icon || '📍'}</div><div><b>${esc(p.label)}</b><small>${esc(p.desc || '')}</small></div>`;
    el.addEventListener('click', () => {
      M.spawn = p.id; $('spawnGo').disabled = false;
      list.querySelectorAll('.sp').forEach((x) => x.classList.toggle('on', x === el));
      post('previewSpawn', { id: p.id });
    });
    list.appendChild(el);
  });
}
$('spawnGo').addEventListener('click', () => { if (M.spawn) post('chooseSpawn', { id: M.spawn }); });

// ================= notifications =================
function gtaToHtml(t) {
  let html = esc(t).replace(/~n~/g, '<br>').replace(/~h~/g, '');
  const map = { r: 'c-r', g: 'c-g', y: 'c-y', b: 'c-b', o: 'c-o', p: 'c-p' };
  let open = 0;
  html = html.replace(/~([a-zA-Z])~/g, (_, c) => {
    let out = '';
    if (open) { out += '</span>'; open = 0; }
    if (map[c]) { out += `<span class="${map[c]}">`; open = 1; }
    return out;
  });
  if (open) html += '</span>';
  return html.replace(/~[A-Z_]+~/g, '');
}
const ICON = { info: 'i', success: '✓', error: '!', warning: '⚠' };
function notify(text, kind, time) {
  if (!ICON[kind]) {
    const t = String(text || '');
    kind = t.includes('~r~') ? 'error' : t.includes('~g~') ? 'success' : (t.includes('~y~') || t.includes('~o~')) ? 'warning' : 'info';
  }
  time = time || 5500;
  const el = document.createElement('div');
  el.className = 'note ' + kind;
  el.innerHTML = `<div class="ni">${ICON[kind]}</div><div class="nt">${gtaToHtml(text)}</div><div class="np" style="animation-duration:${time}ms"></div>`;
  const box = $('notes');
  box.appendChild(el);
  while (box.children.length > 5) box.firstChild.remove();
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 380); }, time);
}

// ================= weapon + status =================
function setWeapon(d) {
  const w = $('weapon');
  if (!d.show) { w.classList.add('hidden'); return; }
  w.classList.remove('hidden');
  w.classList.toggle('up', !$('speedo').classList.contains('hidden'));
  $('wName').textContent = d.name;
  if (d.melee) { $('wClip').textContent = '∞'; $('wTotal').textContent = ''; $('wClip').classList.remove('low'); return; }
  $('wClip').textContent = d.clip;
  $('wTotal').textContent = '/ ' + Math.max(0, d.total - d.clip);
  $('wClip').classList.toggle('low', d.clip <= Math.max(2, d.clipMax * 0.2));
}
// v1.0.27: status rings live in their own bar above the location box
(() => {
  const st = document.querySelector('.h-status');
  if (st) { st.classList.add('stbar'); st.classList.remove('h-status'); st.id = 'stbar'; document.body.appendChild(st); st.style.display = 'none'; }
})();
function setStatus(d) {
  const clamp = (v) => Math.max(0, Math.min(100, v));
  $('stHp').style.width = clamp(d.hp) + '%';
  $('stAr').style.width = clamp(d.ar) + '%';
  $('stSp').style.width = clamp(d.st) + '%';
  $('stHp').closest('.st').style.setProperty('--v', clamp(d.hp));
  $('stAr').closest('.st').style.setProperty('--v', clamp(d.ar));
  $('stSp').closest('.st').style.setProperty('--v', clamp(d.st));
  [['stHp', d.hp], ['stAr', d.ar], ['stSp', d.st]].forEach(([id, v]) => { $(id).closest('.st').dataset.v = Math.round(clamp(v)); });
  $('stHp').closest('.st').classList.toggle('low', d.hp < 25);
  $('stMic').classList.toggle('on', !!d.talk);
  $('hId').textContent = 'ID ' + d.id;
  $('hOnline').textContent = (d.online || 1) + ' online';
  $('hClock').textContent = d.time || '';
}

window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.action) {
    case 'openMenu':
      M.chars = d.chars || []; M.max = d.max || 3; M.sel = null;
      $('cNation').innerHTML = (d.nations || ['Hrvatska']).map((n) => `<option>${esc(n)}</option>`).join('');
      $('menu').classList.remove('hidden');
      $('idCard').classList.add('hidden');
      show('pChars');
      renderChars();
      if (!M.chars.length) openCreate();
      break;
    case 'openSpawn': $('menu').classList.remove('hidden'); openSpawn(d); break;
    case 'closeMenu': $('menu').classList.add('hidden'); break;
    case 'creatorError': $('err').textContent = d.message || 'Greška.'; M.sending = false; $('go').disabled = false; break;
    case 'loading':
      $('loading').classList.toggle('hidden', !d.show);
      if (d.text) $('ldText').textContent = d.text;
      if (d.progress !== undefined) $('ldBar').style.width = Math.round(d.progress * 100) + '%';
      break;
    case 'notify': notify(d.text, d.kind, d.time); break;
    case 'death': setDeath(d); break;
    case 'weapon': setWeapon(d); break;
    case 'status': setStatus(d); break;
    case 'showHud': $('hud').classList.remove('hidden'); break;
    case 'hideHud': ['hud', 'loc', 'speedo', 'weapon'].forEach((i) => $(i).classList.add('hidden')); if ($('stbar')) $('stbar').style.display = 'none'; break;
    case 'hud': setHud(d); break;
    case 'loc': setLoc(d); break;
    case 'veh': setVeh(d); break;
  }
});

// ---------- HUD v1.0.12 ----------
const shown = { cash: 0, bank: 0 };
let first = true;

function countTo(el, key, to) {
  const from = shown[key];
  shown[key] = to;
  if (first || from === to) { el.textContent = money(to); return; }
  const t0 = performance.now();
  const step = (t) => {
    const k = Math.min(1, (t - t0) / 600);
    el.textContent = money(Math.round(from + (to - from) * (1 - Math.pow(1 - k, 3))));
    if (k < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
  const diff = to - from;
  const dl = $('hDelta');
  dl.textContent = (diff > 0 ? '+' : '-') + money(Math.abs(diff)) + (key === 'bank' ? ' banka' : '');
  dl.className = 'h-delta ' + (diff > 0 ? 'plus' : 'minus');
  void dl.offsetWidth;
  dl.classList.add('show');
}

function setHud(d) {
  $('hName').textContent = d.name || '—';
  $('hJob').textContent = d.job || 'Nezaposlen';
  countTo($('hCash'), 'cash', Number(d.cash || 0));
  countTo($('hBank'), 'bank', Number(d.bank || 0));
  first = false;
}

function setLoc(d) {
  const box = $('loc');
  box.classList.toggle('hidden', !d.show);
  box.style.left = `calc(${(d.left * 100).toFixed(3)}vw + 14px)`;
  box.style.top = `${(d.bottom * 100).toFixed(3)}vh`;
  $('lDir').textContent = d.dir || 'S';
  $('lStreet').textContent = d.street || '—';
  $('lZone').textContent = d.zone || 'Osijek';
  $('lTime').textContent = d.time || '';
  const sb = $('stbar');
  if (sb) {
    sb.style.display = d.show ? 'flex' : 'none';
    sb.style.left = `calc(${(d.left * 100).toFixed(3)}vw + 14px)`;
    sb.style.top = `calc(${(d.bottom * 100).toFixed(3)}vh - 96px)`;
  }
}

// tick marks on the dial
(() => {
  const g = $('ticks');
  for (let i = 0; i <= 12; i++) {
    const a = (i / 12) * 270 * Math.PI / 180;
    const r1 = 72, r2 = i % 3 === 0 ? 64 : 68;
    const l = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    l.setAttribute('x1', 100 + r1 * Math.cos(a)); l.setAttribute('y1', 100 + r1 * Math.sin(a));
    l.setAttribute('x2', 100 + r2 * Math.cos(a)); l.setAttribute('y2', 100 + r2 * Math.sin(a));
    g.appendChild(l);
  }
})();

function setVeh(d) {
  const s = $('speedo');
  if (!d.show) { s.classList.add('hidden'); return; }
  s.classList.remove('hidden');
  $('sSpeed').textContent = d.speed;
  $('sRpm').style.strokeDasharray = `${(Math.max(0, Math.min(1, d.rpm)) * 75).toFixed(2)} 100`;
  const g = $('sGear');
  const gear = d.reverse ? 'R' : (d.speed < 1 ? 'N' : String(d.gear || 1));
  g.textContent = gear;
  g.classList.toggle('r', gear === 'R');
  const f = $('sFuel'), e = $('sEng');
  f.style.width = (d.fuel * 100).toFixed(0) + '%'; f.classList.toggle('low', d.fuel < 0.15);
  e.style.width = (d.engine * 100).toFixed(0) + '%'; e.classList.toggle('low', d.engine < 0.3);
  $('sLight').classList.toggle('on', !!d.lights);
}

// ---------- v1.0.25 death screen ----------
function setDeath(d) {
  const box = $('death');
  if (!d.show) { box.classList.add('hidden'); return; }
  box.classList.remove('hidden');
  const total = Math.max(1, d.total || 60), left = Math.max(0, d.left || 0);
  $('d-left').textContent = left;
  $('d-arc').style.strokeDashoffset = (326.7 * (1 - left / total)).toFixed(1);
  $('d-e').classList.toggle('off', left > 0);
  $('d-g').classList.toggle('done', !!d.called);
  $('d-gtxt').textContent = d.called ? 'hitna je pozvana' : 'pozovi hitnu (112)';
  $('d-status').textContent = d.status || '';
}

// ---------- v1.0.36 STIL clothing store + VOLT shop / inventory ----------
(() => {
  const FW = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'osrp_framework';
  const call = (n, d) => fetch(`https://${FW}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(d || {}) })
    .then((r) => r.json()).catch(() => ({}));
  const C = { cats: [], start: {}, cam: 'body' };
  const label = (c) => (c.prop && c.d < 0 ? 'ništa' : `${c.d + 1} / ${c.maxD}`);
  function total() {
    let t = 0;
    for (const c of C.cats) if (c.d !== C.start[c.key][0] || c.t !== C.start[c.key][1]) t += c.price;
    $('clTotal').textContent = '$' + t;
  }
  function drawRow(c) {
    const el = document.getElementById('cl_' + c.key);
    el.classList.toggle('changed', c.d !== C.start[c.key][0] || c.t !== C.start[c.key][1]);
    el.querySelector('.dv').textContent = label(c);
    el.querySelector('.tv').textContent = `${c.t + 1} / ${c.maxT}`;
  }
  function step(c, what, dir) {
    if (what === 'd') {
      const min = c.prop ? -1 : 0;
      c.d += dir;
      if (c.d >= c.maxD) c.d = min;
      if (c.d < min) c.d = c.maxD - 1;
      c.t = 0;
    } else {
      c.t = (c.t + dir + c.maxT) % c.maxT;
    }
    if (C.cam !== c.cam) { C.cam = c.cam; call('clothesCam', { cam: c.cam }); }
    call('clothesSet', { key: c.key, d: c.d, t: c.t }).then((r) => {
      if (r && r.maxD !== undefined) { c.maxD = r.maxD; c.maxT = r.maxT; if (c.t >= c.maxT) c.t = 0; }
      drawRow(c); total();
    });
    drawRow(c); total();
  }
  function openClothes(cats) {
    C.cats = cats; C.start = {}; C.cam = 'body';
    cats.forEach((c) => { C.start[c.key] = [c.d, c.t]; });
    $('clList').innerHTML = cats.map((c) => `
      <div class="cl-row" id="cl_${c.key}"><i>${c.icon}</i>
        <div><b>${c.label}</b><small>${c.price ? '$' + c.price : 'besplatno'}</small></div>
        <div class="cl-ctl">
          <div class="stp"><em>MOD</em><button data-k="${c.key}" data-w="d" data-s="-1">‹</button><span class="dv"></span><button data-k="${c.key}" data-w="d" data-s="1">›</button></div>
          <div class="stp"><em>BOJA</em><button data-k="${c.key}" data-w="t" data-s="-1">‹</button><span class="tv"></span><button data-k="${c.key}" data-w="t" data-s="1">›</button></div>
        </div></div>`).join('');
    cats.forEach(drawRow); total();
    $('clothes').classList.remove('hidden');
  }
  $('clList').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    const c = C.cats.find((x) => x.key === b.dataset.k);
    if (c) step(c, b.dataset.w, +b.dataset.s);
  });
  document.querySelectorAll('.cl-cam button').forEach((b) => b.addEventListener('click', () => {
    if (b.dataset.cam) { C.cam = b.dataset.cam; call('clothesCam', { cam: b.dataset.cam }); }
    else call('clothesCam', { turn: +b.dataset.turn, cur: C.cam });
  }));
  $('clBuy').addEventListener('click', () => call('clothesBuy'));
  $('clCancel').addEventListener('click', () => call('shopClose'));

  const S = { mode: 'tech', items: [], owned: {} };
  function drawShop() {
    const inv = S.mode === 'inv';
    $('shTitle').textContent = inv ? 'MOJE STVARI' : 'VOLT';
    $('shSub').textContent = inv ? 'Inventar · F2' : 'Elektronika';
    const list = inv ? S.items.filter((i) => (S.owned[i.id] || 0) > 0) : S.items;
    $('shGrid').innerHTML = list.map((i) => `
      <div class="sh-card">${S.owned[i.id] ? `<span class="own">x${S.owned[i.id]}</span>` : ''}
        <div class="ic">${i.icon}</div><b>${i.label}</b><p>${i.desc}</p>
        ${inv ? `<button class="use" data-use="${i.id}">Koristi</button>` : `<button data-buy="${i.id}">Kupi · $${i.price}</button>`}
      </div>`).join('') || '<div class="sh-empty">Nemaš ništa. Kupi stvari u VOLT trgovini (odmah do oružarnice).</div>';
  }
  $('shGrid').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    if (b.dataset.buy) call('shopBuy', { id: b.dataset.buy });
    if (b.dataset.use) call('shopUse', { id: b.dataset.use });
  });
  $('shClose').addEventListener('click', () => call('shopClose'));
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && (!$('shop').classList.contains('hidden') || !$('clothes').classList.contains('hidden'))) call('shopClose');
  });
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'clothesOpen') openClothes(d.cats || []);
    if (d.action === 'shopOpen') { S.mode = d.mode; S.items = d.items || []; S.owned = d.owned || {}; drawShop(); $('shop').classList.remove('hidden'); }
    if (d.action === 'shopItems') { S.owned = d.owned || {}; drawShop(); }
    if (d.action === 'shopClose') { $('shop').classList.add('hidden'); $('clothes').classList.add('hidden'); }
  });
})();
