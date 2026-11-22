// v1.0.25 NPC dialog window
(function () {
  const root = document.createElement('div');
  root.id = 'dlg';
  root.className = 'dlg dlg-bars hidden';
  root.innerHTML = '<div class="dlg-name" id="dlgName"></div><div class="dlg-role" id="dlgRole"></div>' +
    '<div class="dlg-text" id="dlgText"></div><div class="dlg-line"></div><div class="dlg-opts" id="dlgOpts"></div>' +
    '<button class="dlg-bye" id="dlgBye"></button><div class="dlg-hint">1-9 / klik · ESC</div>';
  document.body.appendChild(root);
  const res = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'osrp_osijek';
  const post = (n, d) => fetch(`https://${res}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d || {}) }).catch(() => {});
  let typing = null, opts = [], open = false;

  function type(el, text) {
    clearInterval(typing);
    el.textContent = '';
    let i = 0;
    typing = setInterval(() => { el.textContent = text.slice(0, ++i); if (i >= text.length) clearInterval(typing); }, 18);
  }
  function render(d) {
    document.getElementById('dlgName').textContent = d.name || '';
    document.getElementById('dlgRole').textContent = d.role || '';
    type(document.getElementById('dlgText'), d.text || '');
    const box = document.getElementById('dlgOpts');
    box.innerHTML = '';
    opts = d.opts || [];
    opts.forEach((o, k) => {
      const b = document.createElement('button');
      b.className = 'dlg-opt';
      b.innerHTML = `<i>${k + 1}</i>`;
      b.appendChild(document.createTextNode(o.text));
      b.onclick = () => post('dialogPick', { i: o.i });
      box.appendChild(b);
    });
    const bye = document.getElementById('dlgBye');
    bye.textContent = d.bye || 'Doviđenja!';
    bye.onclick = () => post('dialogClose');
  }
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.t !== 'dialog') return;
    open = !!d.show;
    root.classList.toggle('hidden', !open);
    if (open) render(d);
  });
  window.addEventListener('keydown', (e) => {
    if (!open) return;
    if (e.key === 'Escape' || e.key === 'Backspace') { post('dialogClose'); return; }
    const n = parseInt(e.key, 10);
    if (n >= 1 && n <= opts.length) post('dialogPick', { i: opts[n - 1].i });
  });
})();
