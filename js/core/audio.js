/* =========================================================================
 * VAMPIRE CITY — audio.js
 * Procedural WebAudio SFX + ambient music. No external assets.
 * Lazily resumes on first user gesture.
 * ========================================================================= */
(function () {
  'use strict';
  const VAMP = (window.VAMP = window.VAMP || {});

  let ctx = null, master = null, musicGain = null, sfxGain = null;
  let ambGain = null, duckGain = null, duckLP = null;       // ambience bed + sidechain duck + feed-muffle
  let enabled = true, started = false, ambStarted = false;
  let musicTimer = null, musicStep = 0;
  let volume = { master: 0.8, music: 0.5, sfx: 0.9, amb: 0.6 };
  // radio stations: named procedural moods that override driving music feel
  const STATIONS = [
    { name: 'KLUX 666.6 — Gothic Synth', scale: [0, 3, 5, 7, 10, 12, 15], tenLock: 0.2, noteType: 'triangle', color: '#c79bff' },
    { name: 'Bloodwave 88.5 — Industrial', scale: [0, 2, 5, 7, 9, 12, 14], tenLock: 0.75, noteType: 'sawtooth', color: '#ff5a5a' },
    { name: 'Eternal Night 93.1 — Dark Jazz', scale: [0, 3, 6, 10, 13, 15], tenLock: 0.05, noteType: 'sine', color: '#5aafff' },
    { name: 'STATIC — Off', scale: [], tenLock: null, noteType: 'sine', color: '#888' },
  ];
  let radioIdx = 0, radioActive = false; // radioActive = player is in a vehicle
  let noiseBuf = null;                                       // shared 2s noise buffer (kills per-shot alloc)
  // persistent heartbeat nodes + state
  const hb = { thump: null, lp: null, gain: null, intensity: 0, acc: 0, bpm: 50 };
  // ambience bed nodes/state
  const amb = { wind: null, traffic: null, rain: null, windG: null, trafficG: null, rainG: null, lfo: null, sirenT: 12 };
  const fs = { lastIdx: -999 };                              // footstep cadence

  function ensure() {
    if (ctx) return ctx;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) { enabled = false; return null; }
    ctx = new AC();
    master = ctx.createGain(); master.gain.value = volume.master; master.connect(ctx.destination);
    // duck path: ambience + music route through duckGain → duckLP → master; SFX bypasses (hits stay loud)
    duckLP = ctx.createBiquadFilter(); duckLP.type = 'lowpass'; duckLP.frequency.value = 20000; duckLP.connect(master);
    duckGain = ctx.createGain(); duckGain.gain.value = 1; duckGain.connect(duckLP);
    musicGain = ctx.createGain(); musicGain.gain.value = volume.music; musicGain.connect(duckGain);
    ambGain = ctx.createGain(); ambGain.gain.value = volume.amb; ambGain.connect(duckGain);
    sfxGain = ctx.createGain(); sfxGain.gain.value = volume.sfx; sfxGain.connect(master);
    buildNoise();
    buildHeartbeat();
    return ctx;
  }

  function buildNoise() {
    if (noiseBuf || !ctx) return;
    const n = Math.floor(ctx.sampleRate * 2);
    noiseBuf = ctx.createBuffer(1, n, ctx.sampleRate);
    const w = noiseBuf.getChannelData(0);
    for (let i = 0; i < n; i++) w[i] = Math.random() * 2 - 1;
  }

  // two always-on low oscillators pulsed per beat — never recreated
  function buildHeartbeat() {
    if (hb.thump || !ctx) return;
    hb.gain = ctx.createGain(); hb.gain.value = 1;
    hb.lp = ctx.createBiquadFilter(); hb.lp.type = 'lowpass'; hb.lp.frequency.value = 150;
    hb.thump = ctx.createGain(); hb.thump.gain.value = 0.0001;
    const o1 = ctx.createOscillator(); o1.type = 'sine'; o1.frequency.value = 46;
    const o2 = ctx.createOscillator(); o2.type = 'sine'; o2.frequency.value = 92;
    const o2g = ctx.createGain(); o2g.gain.value = 0.4;
    o1.connect(hb.thump); o2.connect(o2g); o2g.connect(hb.thump);
    hb.thump.connect(hb.lp); hb.lp.connect(hb.gain); hb.gain.connect(ambGain);
    o1.start(); o2.start();
  }
  function pulseHeart(amp) {
    if (!ctx) return;
    const now = ctx.currentTime, peak = 0.20 * amp;
    hb.thump.gain.cancelScheduledValues(now);
    hb.thump.gain.setValueAtTime(0.0001, now);
    hb.thump.gain.linearRampToValueAtTime(peak, now + 0.03);
    hb.thump.gain.exponentialRampToValueAtTime(0.0001, now + 0.12);
    hb.thump.gain.setValueAtTime(0.0001, now + 0.14);
    hb.thump.gain.linearRampToValueAtTime(peak * 0.7, now + 0.17);
    hb.thump.gain.exponentialRampToValueAtTime(0.0001, now + 0.28);
  }

  function resume() {
    ensure();
    if (ctx && ctx.state === 'suspended') ctx.resume();
    if (!started && ctx) { started = true; startMusic(); }
    if (!ambStarted && ctx) { ambStarted = true; startAmbience(); }
  }

  function tone(opts) {
    if (!enabled) return;
    ensure(); if (!ctx) return;
    const t0 = ctx.currentTime;
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = opts.type || 'sine';
    o.frequency.setValueAtTime(opts.f0 || 220, t0);
    if (opts.f1 !== undefined) o.frequency.exponentialRampToValueAtTime(Math.max(1, opts.f1), t0 + (opts.dur || 0.2));
    const peak = opts.gain === undefined ? 0.3 : opts.gain;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + (opts.attack || 0.005));
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + (opts.dur || 0.2));
    o.connect(g);
    let node = g;
    if (opts.filter) {
      const f = ctx.createBiquadFilter();
      f.type = opts.filter; f.frequency.value = opts.cutoff || 800;
      g.connect(f); node = f;
    }
    node.connect(opts.bus === 'music' ? musicGain : sfxGain);
    o.start(t0); o.stop(t0 + (opts.dur || 0.2) + 0.05);
  }

  function noise(opts) {
    if (!enabled) return;
    ensure(); if (!ctx) return;
    const dur = opts.dur || 0.2;
    const t0 = ctx.currentTime;
    buildNoise();
    const src = ctx.createBufferSource(); src.buffer = noiseBuf;   // reuse the shared 2s buffer
    const offset = Math.random() * Math.max(0, 2 - dur);           // random slice for variation
    const g = ctx.createGain();
    const peak = opts.gain === undefined ? 0.3 : opts.gain;
    g.gain.setValueAtTime(peak, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    const f = ctx.createBiquadFilter();
    f.type = opts.filter || 'lowpass'; f.frequency.value = opts.cutoff || 1200;
    if (opts.cutoff1) f.frequency.exponentialRampToValueAtTime(Math.max(40, opts.cutoff1), t0 + dur);
    src.connect(f); f.connect(g); g.connect(sfxGain);
    src.start(t0, offset); src.stop(t0 + dur);
  }

  // ---- named SFX ----
  const SFX = {
    ui: () => tone({ type: 'square', f0: 520, f1: 480, dur: 0.06, gain: 0.12 }),
    uiBig: () => { tone({ type: 'triangle', f0: 440, f1: 660, dur: 0.12, gain: 0.18 }); },
    step: () => noise({ dur: 0.07, gain: 0.06, cutoff: 500 }),
    bite: () => { tone({ type: 'sawtooth', f0: 160, f1: 60, dur: 0.25, gain: 0.22, filter: 'lowpass', cutoff: 400 }); noise({ dur: 0.18, gain: 0.1, cutoff: 600, cutoff1: 200 }); },
    drain: () => tone({ type: 'sine', f0: 80, f1: 240, dur: 0.5, gain: 0.12, filter: 'lowpass', cutoff: 600 }),
    hit: () => { noise({ dur: 0.12, gain: 0.25, cutoff: 2000, cutoff1: 300 }); tone({ type: 'square', f0: 120, f1: 40, dur: 0.1, gain: 0.15 }); },
    hurt: () => tone({ type: 'sawtooth', f0: 300, f1: 90, dur: 0.2, gain: 0.2, filter: 'lowpass', cutoff: 900 }),
    gun: () => { noise({ dur: 0.12, gain: 0.4, cutoff: 4000, cutoff1: 400 }); tone({ type: 'square', f0: 220, f1: 60, dur: 0.08, gain: 0.2 }); },
    levelup: () => { [523, 659, 784, 1047].forEach((f, i) => setTimeout(() => tone({ type: 'triangle', f0: f, f1: f, dur: 0.20, gain: 0.18 }), i * 80)); tone({ type: 'sine', f0: 130, f1: 262, dur: 0.7, gain: 0.10, filter: 'lowpass', cutoff: 900 }); },
    gulp: () => { tone({ type: 'sine', f0: 180, f1: 70, dur: 0.22, gain: 0.16, filter: 'lowpass', cutoff: 500 }); tone({ type: 'triangle', f0: 90, f1: 55, dur: 0.18, gain: 0.10 }); noise({ dur: 0.10, gain: 0.05, cutoff: 1400, cutoff1: 300 }); },
    perfectGulp: () => { [784, 1175].forEach((f, i) => setTimeout(() => tone({ type: 'triangle', f0: f, dur: 0.16, gain: 0.16 }), i * 55)); tone({ type: 'sine', f0: 120, f1: 60, dur: 0.18, gain: 0.12 }); },
    skill: () => { [392, 523, 659].forEach((f, i) => setTimeout(() => tone({ type: 'triangle', f0: f, dur: 0.14, gain: 0.16 }), i * 70)); },
    pickup: () => tone({ type: 'square', f0: 660, f1: 990, dur: 0.1, gain: 0.14 }),
    cash: () => { [880, 1175].forEach((f, i) => setTimeout(() => tone({ type: 'square', f0: f, dur: 0.08, gain: 0.12 }), i * 60)); },
    spell: () => { tone({ type: 'sawtooth', f0: 400, f1: 1200, dur: 0.3, gain: 0.18, filter: 'bandpass', cutoff: 900 }); },
    dark: () => tone({ type: 'sine', f0: 220, f1: 55, dur: 0.6, gain: 0.2, filter: 'lowpass', cutoff: 500 }),
    frenzy: () => { tone({ type: 'sawtooth', f0: 90, f1: 200, dur: 0.7, gain: 0.25, filter: 'lowpass', cutoff: 700 }); noise({ dur: 0.5, gain: 0.12, cutoff: 800 }); },
    siren: () => { tone({ type: 'sine', f0: 700, f1: 1100, dur: 0.4, gain: 0.08 }); },
    engine: () => tone({ type: 'sawtooth', f0: 70, f1: 90, dur: 0.2, gain: 0.05, filter: 'lowpass', cutoff: 300 }),
    crash: () => { noise({ dur: 0.3, gain: 0.35, cutoff: 3000, cutoff1: 200 }); },
    death: () => { [330, 247, 165, 110].forEach((f, i) => setTimeout(() => tone({ type: 'sawtooth', f0: f, dur: 0.3, gain: 0.2, filter: 'lowpass', cutoff: 600 }), i * 140)); },
    explode: () => { noise({ dur: 0.5, gain: 0.5, cutoff: 2000, cutoff1: 80 }); tone({ type: 'sine', f0: 120, f1: 30, dur: 0.4, gain: 0.3 }); },
    win: () => { [523, 659, 784, 1047, 1319].forEach((f, i) => setTimeout(() => tone({ type: 'triangle', f0: f, dur: 0.2, gain: 0.2 }), i * 110)); },
  };

  function play(name) { if (SFX[name]) SFX[name](); }

  // ---- ambient music: dark minor drone + sparse arpeggio (night-city dread) ----
  const SCALE = [0, 3, 5, 7, 10, 12, 15]; // minor pentatonic-ish
  const ROOT = 110; // A2
  let tension = 0; // 0 calm .. 1 combat
  function midiHz(semi) { return ROOT * Math.pow(2, semi / 12); }
  function musicTick() {
    if (!ctx) return;
    // ALWAYS reschedule (gate only note production on enabled) so muting then
    // un-muting can't permanently kill the self-looping music chain.
    if (started && enabled) {
      musicStep++;
      const st = radioActive ? STATIONS[radioIdx] : null;
      // radio Static station = silence music bus
      if (st && st.tenLock === null) { musicTimer = setTimeout(musicTick, 600); return; }
      const baseT = st ? st.tenLock : tension;
      const scale = st ? st.scale : SCALE;
      const nType = st ? st.noteType : (baseT > 0.5 ? 'sawtooth' : 'triangle');
      if (musicStep % 4 === 0) {
        tone({ type: 'sine', f0: ROOT / 2, dur: 1.6 + baseT, gain: 0.10 + baseT * 0.05, filter: 'lowpass', cutoff: 300, bus: 'music' });
      }
      if (scale.length && Math.random() < 0.35 + baseT * 0.4) {
        const semi = scale[Math.floor(Math.random() * scale.length)] + (Math.random() < 0.4 ? 12 : 0);
        tone({ type: nType, f0: midiHz(semi), dur: 0.5 + Math.random() * 0.6, gain: 0.05 + baseT * 0.04, filter: 'lowpass', cutoff: 800 + baseT * 1200, bus: 'music' });
      }
      if (baseT > 0.5 && musicStep % 2 === 0) {
        tone({ type: 'square', f0: ROOT, dur: 0.12, gain: 0.05, bus: 'music' });
      }
    }
    musicTimer = setTimeout(musicTick, 520 - tension * 180);
  }
  function startMusic() { if (musicTimer) return; musicTick(); }
  function setTension(t) { tension = Math.max(0, Math.min(1, t)); }

  // ---- night-city ambience bed (wind + traffic hum + rain), all looping shared noise ----
  function loopSrc(rate) { const s = ctx.createBufferSource(); s.buffer = noiseBuf; s.loop = true; if (rate) s.playbackRate.value = rate; return s; }
  function startAmbience() {
    if (!ctx || !noiseBuf) return;
    amb.wind = loopSrc();
    const wbp = ctx.createBiquadFilter(); wbp.type = 'bandpass'; wbp.frequency.value = 380; wbp.Q.value = 0.7;
    amb.lfo = ctx.createOscillator(); amb.lfo.type = 'sine'; amb.lfo.frequency.value = 0.07;
    const lfoG = ctx.createGain(); lfoG.gain.value = 120; amb.lfo.connect(lfoG); lfoG.connect(wbp.frequency);
    amb.windG = ctx.createGain(); amb.windG.gain.value = 0.05;
    amb.wind.connect(wbp); wbp.connect(amb.windG); amb.windG.connect(ambGain);
    amb.traffic = loopSrc();
    const tlp = ctx.createBiquadFilter(); tlp.type = 'lowpass'; tlp.frequency.value = 220;
    amb.trafficG = ctx.createGain(); amb.trafficG.gain.value = 0.05;
    amb.traffic.connect(tlp); tlp.connect(amb.trafficG); amb.trafficG.connect(ambGain);
    amb.rain = loopSrc(1.3);
    const rhp = ctx.createBiquadFilter(); rhp.type = 'highpass'; rhp.frequency.value = 1200;
    amb.rainG = ctx.createGain(); amb.rainG.gain.value = 0;
    amb.rain.connect(rhp); rhp.connect(amb.rainG); amb.rainG.connect(ambGain);
    try { amb.wind.start(); amb.traffic.start(); amb.rain.start(); amb.lfo.start(); } catch (e) {}
  }
  function setAmbience(profile) {
    if (!ctx || !ambStarted) return;
    const now = ctx.currentTime;
    if (amb.windG) amb.windG.gain.setTargetAtTime((profile.indoor ? 0.02 : 0.05) + (profile.wind || 0) * 0.04, now, 1.0);
    if (amb.trafficG) amb.trafficG.gain.setTargetAtTime(profile.indoor ? 0.01 : (profile.night ? 0.04 : 0.07), now, 1.0);
    if (amb.rainG) amb.rainG.gain.setTargetAtTime(profile.rain ? 0.10 : 0, now, 1.5);
  }
  function footstep(sprint, rain) {
    if (!enabled || !ctx || !noiseBuf) return;
    const t0 = ctx.currentTime;
    const s = ctx.createBufferSource(); s.buffer = noiseBuf;
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = sprint ? 900 : 520;
    const g = ctx.createGain(); const pk = sprint ? 0.06 : 0.045;
    g.gain.setValueAtTime(pk, t0); g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.09);
    const pan = ctx.createStereoPanner ? ctx.createStereoPanner() : null; if (pan) pan.pan.value = (Math.random() * 2 - 1) * 0.3;
    s.connect(f); f.connect(g); if (pan) { g.connect(pan); pan.connect(sfxGain); } else g.connect(sfxGain);
    s.start(t0); s.stop(t0 + 0.1);
  }
  function sirenWail() {
    if (!enabled || !ctx) return;
    const t0 = ctx.currentTime, o = ctx.createOscillator(); o.type = 'sine';
    o.frequency.setValueAtTime(620, t0);
    try { o.frequency.setValueCurveAtTime(new Float32Array([620, 840, 620, 840, 620]), t0, 2.4); } catch (e) {}
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1500;
    const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t0); g.gain.linearRampToValueAtTime(0.03, t0 + 0.3); g.gain.linearRampToValueAtTime(0.0001, t0 + 2.4);
    const pan = ctx.createStereoPanner ? ctx.createStereoPanner() : null; if (pan) pan.pan.value = (Math.random() * 2 - 1) * 0.6;
    o.connect(lp); lp.connect(g); if (pan) { g.connect(pan); pan.connect(ambGain); } else g.connect(ambGain);
    o.start(t0); o.stop(t0 + 2.5);
  }
  // per-frame pump: heartbeat, ambience targets, ducking, footsteps
  function update(dt, game) {
    if (!enabled || !ctx || !game || !game.player || !game.player.derived) return;
    const p = game.player;
    const hpR = p.hp / Math.max(1, p.derived.maxHP), hung = (p.bloodState.hunger || 0) / 5;
    const danger = Math.max(hpR < 0.5 ? (0.5 - hpR) * 2 : 0, hung > 0.6 ? (hung - 0.6) * 2.5 : 0, p.bloodState.frenzied ? 1 : 0);
    hb.intensity += (danger - hb.intensity) * Math.min(1, dt * 3);
    if (hb.intensity > 0.04) { hb.bpm = 50 + hb.intensity * 90; hb.acc += dt * (hb.bpm / 60); if (hb.acc >= 1) { hb.acc -= 1; pulseHeart(hb.intensity); } } else hb.acc = 0;
    setAmbience({ rain: (game.weather && game.weather.kind === 'rain') ? 1 : 0, indoor: game.inHaven, night: game.timeOfDay && game.timeOfDay.night, wind: (game.weather && game.weather.kind === 'fog') ? 0.5 : 0 });
    const dgTarget = Math.min(0.9, tension * 0.35 + (p.feeding ? 0.55 : 0));
    const now = ctx.currentTime;
    if (duckGain) duckGain.gain.setTargetAtTime(1 - dgTarget, now, p.feeding ? 0.1 : 0.3);
    if (duckLP) duckLP.frequency.setTargetAtTime(p.feeding ? 700 : 20000, now, 0.2);
    amb.sirenT -= dt;
    if (amb.sirenT <= 0) { amb.sirenT = (25 + Math.random() * 35) - (game.masquerade ? game.masquerade.stars * 4 : 0); if (!game.inHaven) sirenWail(); }
    if (p.moving && !p.inVehicle && !p.feeding && !p.finisher && !p.pounce) {
      const idx = Math.floor((p.walkPhase || 0) / Math.PI);
      if (idx !== fs.lastIdx) { fs.lastIdx = idx; footstep(p.sprinting, game.weather && game.weather.kind === 'rain'); }
    } else fs.lastIdx = -999;
  }

  // immediately restore the duck bus + feed muffle (the pump stops while mode==='dead')
  function unduck() {
    if (!ctx) return; const now = ctx.currentTime;
    if (duckGain) duckGain.gain.setTargetAtTime(1, now, 0.2);
    if (duckLP) duckLP.frequency.setTargetAtTime(20000, now, 0.2);
  }

  function setVolume(kind, v) {
    volume[kind] = v;
    if (!ctx) return;
    if (kind === 'master' && master) master.gain.value = v;
    if (kind === 'music' && musicGain) musicGain.gain.value = v;
    if (kind === 'sfx' && sfxGain) sfxGain.gain.value = v;
    if (kind === 'amb' && ambGain) ambGain.gain.value = v;
  }
  function toggle() {
    enabled = !enabled;
    if (master) master.gain.value = enabled ? volume.master : 0;
    return enabled;
  }
  function isEnabled() { return enabled; }

  function nextStation() {
    radioIdx = (radioIdx + 1) % STATIONS.length;
    const st = STATIONS[radioIdx];
    return st;  // caller shows the station name
  }
  function setRadioActive(on) { radioActive = on; }

  VAMP.Audio = { resume, play, setTension, setVolume, toggle, isEnabled, tone, noise, update, setAmbience, unduck, nextStation, setRadioActive, STATIONS, get radioIdx() { return radioIdx; } };
})();
