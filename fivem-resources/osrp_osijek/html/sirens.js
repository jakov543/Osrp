// OSRP v1.0.46 - Croatian two-tone siren ("dvotonac", hi-lo) made live with WebAudio, one voice per vehicle.
// sirens.lua sends { t: 'siren', list: [{ id, vol, pan, amb }] } ~8 times a second.
(() => {
  let ctx = null;
  const voices = new Map();
  const HI = 588, LO = 440, HALF = 0.58;        // Hz and seconds per tone (police); ambulance is a bit slower and lower

  function audio() {
    if (!ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      ctx = new AC();
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  }

  function voice(amb) {
    const a = audio();
    const osc = a.createOscillator();
    osc.type = 'sawtooth';
    const osc2 = a.createOscillator();          // second partial makes it sound like a horn speaker, not a beep
    osc2.type = 'square';
    const mix2 = a.createGain(); mix2.gain.value = 0.25;
    const lp = a.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 2600; lp.Q.value = 0.8;
    const bp = a.createBiquadFilter(); bp.type = 'peaking'; bp.frequency.value = 1400; bp.gain.value = 5;
    const gain = a.createGain(); gain.gain.value = 0;
    const pan = a.createStereoPanner ? a.createStereoPanner() : null;
    osc.connect(lp); osc2.connect(mix2); mix2.connect(lp); lp.connect(bp); bp.connect(gain);
    if (pan) { gain.connect(pan); pan.connect(a.destination); } else gain.connect(a.destination);
    const hi = amb ? HI * 0.92 : HI, lo = amb ? LO * 0.92 : LO, half = amb ? HALF * 1.15 : HALF;
    // schedule the hi-lo pattern 10 minutes ahead (cheap: two setValueAtTime per tone)
    const t0 = a.currentTime + 0.02;
    for (let k = 0; k < 600 / half; k++) {
      const f = k % 2 ? lo : hi;
      osc.frequency.setValueAtTime(f, t0 + k * half);
      osc2.frequency.setValueAtTime(f * 2, t0 + k * half);
    }
    osc.start(t0); osc2.start(t0);
    return { osc, osc2, gain, pan, born: a.currentTime };
  }

  function kill(id) {
    const v = voices.get(id);
    if (!v) return;
    const a = audio();
    v.gain.gain.setTargetAtTime(0, a.currentTime, 0.08);
    setTimeout(() => { try { v.osc.stop(); v.osc2.stop(); } catch (e) {} }, 600);
    voices.delete(id);
  }

  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.t !== 'siren') return;
    const list = d.list || [];
    if (!list.length && !voices.size) return;
    const a = audio();
    if (!a) return;
    const keep = new Set();
    list.forEach((s) => {
      keep.add(s.id);
      let v = voices.get(s.id);
      if (!v || v.born + 590 < a.currentTime) { if (v) kill(s.id); v = voice(s.amb); voices.set(s.id, v); }
      v.gain.gain.setTargetAtTime(Math.max(0, Math.min(1, s.vol)) * 0.35, a.currentTime, 0.06);
      if (v.pan) v.pan.pan.setTargetAtTime(s.pan || 0, a.currentTime, 0.06);
    });
    [...voices.keys()].forEach((id) => { if (!keep.has(id)) kill(id); });
  });
})();
