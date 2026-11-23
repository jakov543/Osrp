// v1.0.43 Bike Osijek chooser (osrp_osijek/bikes.lua)
(() => {
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'osrp_osijek';
  const call = (n, d) => fetch(`https://${RES}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(d || {}) }).catch(() => {});
  const el = document.createElement('div');
  el.className = 'bk hidden';
  el.innerHTML = `
    <div class="bk-panel">
      <div class="bk-head"><small>BIKE OSIJEK</small><b>Izaberi bicikl</b><span>Besplatni gradski bicikli · vrati ga bilo gdje</span></div>
      <div class="bk-list"></div>
      <div class="bk-info"><p></p>
        <div class="bk-stat"><em>Brzina</em><i><u data-s="speed"></u></i><span data-v="speed"></span></div>
        <div class="bk-stat"><em>Upravljanje</em><i><u data-s="handling"></u></i><span data-v="handling"></span></div>
        <div class="bk-stat"><em>Udobnost</em><i><u data-s="comfort"></u></i><span data-v="comfort"></span></div>
      </div>
      <div class="bk-col"><small>BOJA OKVIRA</small><div class="bk-sw" data-k="c1"></div><small>DETALJI</small><div class="bk-sw" data-k="c2"></div></div>
      <div class="bk-foot"><button class="bk-cancel">Odustani</button><button class="bk-take">Uzmi bicikl</button></div>
    </div>
    <div class="bk-hint">Bicikl se okreće · klikni boje da vidiš izgled</div>`;
  document.body.appendChild(el);
  const q = (s) => el.querySelector(s);
  const S = { bikes: [], colours: [], i: 0, c1: 27, c2: 0 };
  const pick = () => call('bikePick', { i: S.i + 1, c1: S.c1, c2: S.c2 });
  function info() {
    const b = S.bikes[S.i];
    q('.bk-info p').textContent = b.desc;
    ['speed', 'handling', 'comfort'].forEach((k) => { q(`[data-s=${k}]`).style.width = b[k] + '%'; q(`[data-v=${k}]`).textContent = b[k]; });
    el.querySelectorAll('.bk-card').forEach((c, i) => c.classList.toggle('sel', i === S.i));
  }
  function swatches() {
    el.querySelectorAll('.bk-sw').forEach((box) => {
      const k = box.dataset.k;
      box.innerHTML = S.colours.map((c) => `<button title="${c.n}" data-id="${c.id}" style="background:${c.hex}" class="${c.id === S[k] ? 'sel' : ''}"></button>`).join('');
      box.querySelectorAll('button').forEach((b) => b.addEventListener('click', () => {
        S[k] = +b.dataset.id;
        box.querySelectorAll('button').forEach((x) => x.classList.toggle('sel', x === b));
        pick();
      }));
    });
  }
  function open(d) {
    S.bikes = d.bikes || []; S.colours = d.colours || []; S.i = 0; S.c1 = 27; S.c2 = 0;
    q('.bk-list').innerHTML = S.bikes.map((b, i) => `<div class="bk-card" style="transition-delay:${0.05 * i}s"><em>${b.type}</em><b>${b.name}</b></div>`).join('');
    el.querySelectorAll('.bk-card').forEach((c, i) => c.addEventListener('click', () => { S.i = i; info(); pick(); }));
    swatches(); info();
    el.classList.remove('hidden');
    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('on')));
  }
  function close() { el.classList.remove('on'); setTimeout(() => el.classList.add('hidden'), 450); }
  q('.bk-take').addEventListener('click', () => call('bikeTake', { i: S.i + 1, c1: S.c1, c2: S.c2 }));
  q('.bk-cancel').addEventListener('click', () => call('bikeClose'));
  window.addEventListener('keydown', (e) => {
    if (el.classList.contains('hidden')) return;
    if (e.key === 'Escape' || e.key === 'Backspace') call('bikeClose');
    if (e.key === 'Enter') call('bikeTake', { i: S.i + 1, c1: S.c1, c2: S.c2 });
    if (e.key === 'ArrowDown' || e.key === 'ArrowRight') { S.i = (S.i + 1) % S.bikes.length; info(); pick(); }
    if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') { S.i = (S.i - 1 + S.bikes.length) % S.bikes.length; info(); pick(); }
  });
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.t !== 'bikes') return;
    if (d.open) open(d); else close();
  });
})();
