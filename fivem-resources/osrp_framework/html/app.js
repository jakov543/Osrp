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
    case 'hud':
      $('hName').textContent = d.name || '—';
      $('hJob').textContent = d.job || '—';
      $('hCash').textContent = money(d.cash);
      $('hBank').textContent = money(d.bank);
      break;
  }
});
