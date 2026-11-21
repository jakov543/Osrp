// OSRP framework NUI
const $ = (id) => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'osrp_framework';
let sex = 'm';
let sending = false;

const money = (n) => '$' + Number(n || 0).toLocaleString('hr-HR');

document.querySelectorAll('.sex button').forEach((b) => b.addEventListener('click', () => {
  sex = b.dataset.sex;
  document.querySelectorAll('.sex button').forEach((x) => x.classList.toggle('on', x === b));
}));

$('go').addEventListener('click', async () => {
  if (sending) return;
  const firstname = $('firstname').value.trim();
  const lastname = $('lastname').value.trim();
  const dob = $('dob').value;
  if (firstname.length < 2 || lastname.length < 2) { $('err').textContent = 'Upiši ime i prezime (min. 2 slova).'; return; }
  if (!dob) { $('err').textContent = 'Upiši datum rođenja.'; return; }
  $('err').textContent = '';
  sending = true;
  $('go').disabled = true;
  try {
    await fetch(`https://${resource}/submitCharacter`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify({ firstname, lastname, dob, sex })
    });
  } catch (e) { /* server answers with osrp:spawn or osrp:characterError */ }
  setTimeout(() => { sending = false; $('go').disabled = false; }, 1500);
});

window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.action) {
    case 'openCreator': $('creator').classList.remove('hidden'); $('firstname').focus(); break;
    case 'closeCreator': $('creator').classList.add('hidden'); break;
    case 'creatorError': $('err').textContent = d.message || 'Greška.'; sending = false; $('go').disabled = false; break;
    case 'showHud': $('hud').classList.remove('hidden'); break;
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
