// OSRP loading screen v1.0.43 - animated Osijek sunset (skyline drawn here), real FiveM load progress, tips
const $ = (id) => document.getElementById(id);

// ---------- skyline: Tvrđa houses, co-cathedral spire, towers, suspension bridge ----------
(() => {
  const svg = $('skyline');
  const NS = 'http://www.w3.org/2000/svg';
  const add = (tag, attrs, parent = svg) => { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); parent.appendChild(e); return e; };
  const far = add('g', { class: 'far' }), near = add('g', { class: 'near' }), lit = add('g', { class: 'lit' });
  let x = 0, seed = 7;
  const rnd = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
  while (x < 1600) {                                    // far blocks (new districts)
    const w = 30 + rnd() * 60, h = 60 + rnd() * 120;
    add('rect', { x, y: 420 - h - 40, width: w, height: h + 40 }, far);
    x += w + 4;
  }
  x = 0;
  while (x < 1600) {                                    // near old town: houses with pitched roofs + lit windows
    const w = 40 + rnd() * 50, h = 40 + rnd() * 50;
    if (x > 330 && x < 470) { x += 10; continue; }       // space for the cathedral
    add('path', { d: `M${x} 420 V${420 - h} L${x + w / 2} ${420 - h - 18} L${x + w} ${420 - h} V420 Z` }, near);
    for (let i = 0; i < 4; i++) if (rnd() < 0.45) add('rect', { x: x + 6 + rnd() * (w - 14), y: 420 - h + 8 + rnd() * (h - 20), width: 5, height: 7 }, lit);
    x += w + 2;
  }
  // co-cathedral of St. Peter and Paul: nave + 90 m tower + spire
  add('path', { d: 'M335 420 V330 L375 300 L415 330 V420 Z' }, near);
  add('path', { d: 'M384 420 V170 L398 150 L412 170 V420 Z' }, near);
  add('path', { d: 'M398 40 L388 150 L408 150 Z' }, near);
  add('rect', { x: 395, y: 230, width: 6, height: 12 }, lit);
  // suspension bridge over the Drava (two pylons + cable)
  const bx = 1080;
  add('rect', { x: bx, y: 300, width: 8, height: 120 }, near); add('rect', { x: bx + 300, y: 300, width: 8, height: 120 }, near);
  add('rect', { x: bx - 80, y: 404, width: 470, height: 6 }, near);
  add('path', { d: `M${bx - 80} 404 Q${bx + 4} 300 ${bx + 4} 300 Q${bx + 154} 395 ${bx + 304} 300 Q${bx + 304} 300 ${bx + 390} 404`, fill: 'none', stroke: '#1a1528', 'stroke-width': 3 });
  for (let i = 1; i < 12; i++) { const t = i / 12, cx = bx + 4 + t * 300, cy = 300 + (1 - Math.pow(2 * t - 1, 2)) * 47; add('rect', { x: cx, y: cy, width: 1.5, height: 404 - cy }, near); }
  // clouds
  const cl = $('clouds');
  for (let i = 0; i < 7; i++) {
    const c = document.createElement('div');
    c.className = 'cloud';
    c.style.top = (6 + Math.random() * 40) + '%';
    c.style.width = (12 + Math.random() * 18) + 'vw';
    c.style.animationDuration = (70 + Math.random() * 60) + 's';
    c.style.animationDelay = (-Math.random() * 120) + 's';
    cl.appendChild(c);
  }
})();

// ---------- parallax ----------
window.addEventListener('mousemove', (e) => {
  const dx = (e.clientX / innerWidth - 0.5) * -14, dy = (e.clientY / innerHeight - 0.5) * -8;
  document.querySelector('.scene').style.transform = `translate(${dx}px, ${dy}px) scale(1.02)`;
});

// ---------- tips ----------
const tips = [
  ['💡', 'Pritisni F7 za kartu Osijeka - klikni bilo gdje za GPS.'],
  ['🚲', 'Bike Osijek stanice su uz Dravu - E i izaberi svoj bicikl.'],
  ['🛴', 'BULET e-romobili: zelene stanice po gradu, E za najam.'],
  ['🍔', 'Gladan si? Kafić i beach bar imaju burek, sendviče i pizzu.'],
  ['🛍️', 'DRAVA CENTAR je pokraj bolnice - 8 trgovina pod jednim krovom.'],
  ['🌉', 'Pješački most noću svijetli ljubičasto i crveno.'],
  ['⚖️', 'Poštuj pravila servera - roleplay prije svega.'],
];
let ti = 0;
setInterval(() => {
  ti = (ti + 1) % tips.length;
  const t = document.querySelector('.tip');
  t.style.opacity = 0;
  setTimeout(() => { $('tipIcon').textContent = tips[ti][0]; $('tip').textContent = tips[ti][1]; t.style.opacity = 1; }, 400);
}, 5500);

// ---------- real progress from FiveM ----------
let best = 0;
const steps = [...document.querySelectorAll('#steps span')];
function show(p, txt) {
  best = Math.max(best, p);
  const v = Math.round(best * 100);
  $('fill').style.width = v + '%';
  $('pct').textContent = v + '%';
  if (txt) $('stage').textContent = txt;
  const k = Math.min(3, Math.floor(best * 4));
  steps.forEach((s, i) => { s.classList.toggle('done', i < k); s.classList.toggle('now', i === k); });
}
const names = { INIT_BEFORE_MAP_LOADED: 'Pripremam svijet', MAP: 'Učitavam kartu', INIT_AFTER_MAP_LOADED: 'Gradim Osijek', INIT_SESSION: 'Ulazim na server' };
window.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.eventName === 'loadProgress' && typeof d.loadFraction === 'number') show(d.loadFraction);
  if (d.eventName === 'startInitFunctionOrder' && names[d.type]) $('stage').textContent = names[d.type];
  if (d.eventName === 'startDataFileEntries') $('stage').textContent = 'Učitavam modele grada';
  if (d.eventName === 'performMapLoadFunction') $('stage').textContent = 'Postavljam ulice i zgrade';
});
show(0, 'Pripremam grad');

// ---------- v1.0.45: slideshow of our city (img/*.jpg, rendered from the map). The drawn sunset stays behind it. ----------
(() => {
  const PH = [
    ['img/katedrala.jpg', 'Tvrđa i Konkatedrala'], ['img/drava.jpg', 'Most preko Drave'], ['img/aerodrom.jpg', 'Zračna luka Osijek'],
    ['img/sjenjak.jpg', 'Sjenjak'],
  ];
  const box = $('photos'), cap = $('caption');
  const els = [];
  PH.forEach(([src], i) => {
    const d = document.createElement('div');
    d.className = 'ph' + (i % 2 ? ' alt' : '');
    const img = new Image();
    img.onload = () => { d.style.backgroundImage = `url(${src})`; d.dataset.ok = '1'; };
    img.src = src;
    box.appendChild(d); els.push(d);
  });
  let k = -1;
  const next = () => {
    const ok = els.map((e, i) => e.dataset.ok ? i : -1).filter((i) => i >= 0);
    if (!ok.length) return;                       // no photos (yet) -> the drawn scene is shown
    k = ok[(ok.indexOf(k) + 1) % ok.length];
    els.forEach((e, i) => { e.classList.remove('on'); if (i === k) { void e.offsetWidth; e.classList.add('on'); } });
    cap.classList.add('fade');
    setTimeout(() => { cap.querySelector('b').textContent = PH[k][1]; cap.classList.remove('fade'); }, 600);
  };
  setTimeout(next, 400);
  setInterval(next, 7000);
})();
