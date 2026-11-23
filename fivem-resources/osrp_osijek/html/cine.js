// v1.0.42 arrival film overlay: letterbox, titles per camera shot, welcome card, progress, skip hint
(() => {
  const el = document.createElement('div');
  el.className = 'cine hidden';
  el.innerHTML = `
    <div class="bar top"></div><div class="bar bot"></div>
    <div class="brand">OSRP <em>|</em> OSIJEK ROLEPLAY</div>
    <div class="title"><b>OSIJEK</b><span>Grad na Dravi</span></div>
    <div class="lower"><small></small><b></b><i></i></div>
    <div class="welcome"><div><b>Dobrodošli u Osijek</b><span></span></div></div>
    <div class="prog"><span></span></div>
    <div class="skip"><kbd>ENTER</kbd>preskoči</div>`;
  document.body.appendChild(el);
  const q = (s) => el.querySelector(s);
  const LOWER = {
    2: ['Let OS 1909', 'Prilaz Osijeku'],
    3: ['Zračna luka Osijek', 'Pista 09 · Klisa'],
    4: ['Slijetanje', 'Dobrodošli na tlo'],
    5: ['Zračna luka Osijek', 'Vožnja do terminala'],
    6: ['Terminal', 'Izlaz za putnike'],
  };
  function lower(shot) {
    const l = q('.lower');
    l.classList.remove('show');
    const d = LOWER[shot];
    if (!d) return;
    setTimeout(() => { q('.lower small').textContent = d[0]; q('.lower b').textContent = d[1]; l.classList.add('show'); }, 450);
  }
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.t !== 'cine') return;
    if (d.on === true) {
      el.classList.remove('hidden');
      requestAnimationFrame(() => el.classList.add('on'));
      q('.welcome').classList.remove('show');
      q('.prog span').style.width = '0';
    }
    if (d.on === false) { el.classList.remove('on'); setTimeout(() => el.classList.add('hidden'), 1300); }
    if (d.progress !== undefined) q('.prog span').style.width = (Math.min(1, d.progress) * 100) + '%';
    if (d.shot !== undefined) {
      q('.title').classList.toggle('show', d.shot === 1);
      lower(d.shot);
      if (d.shot === 7) {
        q('.lower').classList.remove('show');
        const now = new Date();
        q('.welcome span').textContent = now.toLocaleDateString('hr-HR', { weekday: 'long', day: 'numeric', month: 'long' }) + ' · OSRP';
        q('.welcome').classList.add('show');
      }
    }
  });
})();
