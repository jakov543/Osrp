// OSRP startup loading window
window.launcher.onSplashStep(({ text, progress }) => {
  const p = Math.round(Math.max(0, Math.min(1, progress)) * 100);
  document.getElementById('text').textContent = text;
  document.getElementById('pct').textContent = p + '%';
  document.getElementById('fill').style.width = p + '%';
});
