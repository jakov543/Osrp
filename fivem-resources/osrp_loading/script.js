// OSRP V1 loading screen - uses FiveM's real load progress
const fill = document.getElementById('fill');
const pct = document.getElementById('pct');
const tip = document.getElementById('tip');
const stage = document.getElementById('stage');

const tips = [
  'Učitavanje grada Osijeka...',
  'Poštuj pravila servera.',
  'Pridruži se OSRP Discordu za novosti.',
  'Vozi pažljivo kroz grad!',
  'Dobrodošao na OSRP - Osijek Roleplay.'
];
let tipIndex = 0;
setInterval(() => {
  tipIndex = (tipIndex + 1) % tips.length;
  tip.style.opacity = 0;
  setTimeout(() => { tip.textContent = tips[tipIndex]; tip.style.opacity = 1; }, 400);
}, 5000);

let best = 0;
window.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.eventName === 'loadProgress' && typeof d.loadFraction === 'number') {
    best = Math.max(best, d.loadFraction);
    const p = Math.round(best * 100);
    fill.style.width = p + '%';
    pct.textContent = p + '%';
    stage.textContent = p < 40 ? 'Učitavanje mape' : p < 80 ? 'Učitavanje grada' : 'Skoro gotovo';
  }
});
