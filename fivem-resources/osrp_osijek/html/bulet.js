// v1.0.33 BULET ride panel
(function () {
  const el = document.createElement('div');
  el.className = 'bulet hidden';
  el.innerHTML = '<div class="bt">BULET <small>E-ROMOBIL</small></div><div class="bs"><span id="buS">0</span> <em>km/h</em></div>' +
    '<div class="row"><span>Vrijeme</span><b id="buT">00:00</b></div><div class="row"><span>Cijena</span><b id="buC">$0</b></div>' +
    '<div class="bat"><span id="buB" style="width:100%"></span></div><div class="row"><span>Baterija</span><b id="buBp">100%</b></div>' +
    '<div class="hint">W/A/S/D vožnja · F kraj vožnje</div>';
  document.body.appendChild(el);
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.t !== 'bulet') return;
    el.classList.toggle('hidden', !d.show);
    if (!d.show) return;
    document.getElementById('buS').textContent = d.speed;
    document.getElementById('buT').textContent = d.time;
    document.getElementById('buC').textContent = '$' + d.cost;
    document.getElementById('buB').style.width = d.battery + '%';
    document.getElementById('buBp').textContent = d.battery + '%';
  });
})();
