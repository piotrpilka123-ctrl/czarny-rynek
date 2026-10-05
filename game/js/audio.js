'use strict';
/* ============================================================
   DŹWIĘK: efekty (WebAudio), deszcz, muzyka klubowa
   Muzyka w klubie: jeśli w folderze „muzyka/” są pliki audio — grają one;
   w przeciwnym razie syntezowany bit klubowy (własna kompozycja).
   ============================================================ */
const Snd = {
  ctx: null, master: null, sfx: null, muted: /nolock|autostart|mute/.test(location.search), silent: /nolock|autostart|mute/.test(location.search), sirenOsc: null,
  club: { bus: null, filter: null, vol: 0, target: 0, muffle: 1, playing: false, step: 0, nextT: 0, lastKick: -9, bar: 0, track: 0, files: [], fileIdx: 0, el: null, analyser: null, an: null, useFiles: false },
  rainGain: null, noiseBuf: null,

  init() {
    if (this.silent) return;            // tryb testowy: żadnego dźwięku
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    try {
      const c = this.ctx = new (window.AudioContext || window.webkitAudioContext)();
      this.master = c.createGain(); this.master.gain.value = this.muted ? 0 : 0.6; this.master.connect(c.destination);
      this.sfx = c.createGain(); this.sfx.gain.value = 1; this.sfx.connect(this.master);
      // szum
      const n = c.sampleRate * 2, buf = c.createBuffer(1, n, c.sampleRate), d = buf.getChannelData(0);
      for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
      this.noiseBuf = buf;
      // klub
      const C = this.club;
      C.bus = c.createGain(); C.bus.gain.value = 0;
      C.filter = c.createBiquadFilter(); C.filter.type = 'lowpass'; C.filter.frequency.value = 500; C.filter.Q.value = 0.7;
      C.comp = c.createDynamicsCompressor(); C.comp.threshold.value = -14; C.comp.ratio.value = 4;
      C.bus.connect(C.filter); C.filter.connect(C.comp); C.comp.connect(this.master);
      C.analyser = c.createAnalyser(); C.analyser.fftSize = 64; C.an = new Uint8Array(32); C.bus.connect(C.analyser);
      // deszcz
      const rs = c.createBufferSource(); rs.buffer = buf; rs.loop = true;
      const rf = c.createBiquadFilter(); rf.type = 'bandpass'; rf.frequency.value = 2600; rf.Q.value = 0.4;
      this.rainGain = c.createGain(); this.rainGain.gain.value = 0;
      rs.connect(rf); rf.connect(this.rainGain); this.rainGain.connect(this.master); rs.start();
      this.loadPlaylist();
    } catch (e) { this.ctx = null; }
  },
  setMuted(m) { this.muted = m; if (this.master) this.master.gain.value = m ? 0 : 0.6; },

  /* ---------- proste efekty ---------- */
  tone(freq, dur, type, vol, delay, slideTo, dest) {
    if (!this.ctx || this.muted) return;
    const c = this.ctx, t = c.currentTime + (delay || 0);
    const o = c.createOscillator(), g = c.createGain();
    o.type = type || 'sine'; o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol || 0.15, t + 0.008); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(dest || this.sfx); o.start(t); o.stop(t + dur + 0.05);
  },
  noise(dur, vol, freq, type, when, dest) {
    if (!this.ctx || this.muted) return;
    const c = this.ctx, t = when || c.currentTime;
    const s = c.createBufferSource(); s.buffer = this.noiseBuf; s.loop = true;
    const f = c.createBiquadFilter(); f.type = type || 'lowpass'; f.frequency.value = freq || 800;
    const g = c.createGain(); g.gain.setValueAtTime(vol || 0.1, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(f); f.connect(g); g.connect(dest || this.sfx); s.start(t, Math.random()); s.stop(t + dur + 0.02);
  },
  click() { this.tone(720, 0.04, 'square', 0.04); },
  open()  { this.tone(440, 0.07, 'triangle', 0.07); this.tone(660, 0.09, 'triangle', 0.07, 0.06); },
  step(run) { this.noise(0.05, run ? 0.07 : 0.045, 420 + Math.random() * 300); },
  cash()  { this.tone(988, 0.08, 'square', 0.06); this.tone(1480, 0.18, 'square', 0.06, 0.08); },
  bad()   { this.tone(200, 0.3, 'sawtooth', 0.09, 0, 90); },
  good()  { this.tone(523, 0.1, 'triangle', 0.09); this.tone(659, 0.1, 'triangle', 0.09, 0.1); this.tone(784, 0.2, 'triangle', 0.09, 0.2); },
  alert() { this.tone(880, 0.12, 'square', 0.09); this.tone(660, 0.12, 'square', 0.09, 0.14); },
  sms()   { this.tone(1200, 0.06, 'sine', 0.1); this.tone(1600, 0.1, 'sine', 0.1, 0.07); },
  door()  { this.noise(0.18, 0.12, 300); this.tone(90, 0.12, 'sine', 0.12); },
  tick()  { this.tone(1000, 0.02, 'square', 0.025); },
  hit()   { this.tone(1320, 0.09, 'sine', 0.12); },
  miss()  { this.tone(170, 0.14, 'square', 0.07); },
  horn()  { this.tone(415, 0.35, 'sawtooth', 0.06); this.tone(520, 0.35, 'sawtooth', 0.06); },
  level() { [523, 659, 784, 1047].forEach((f, i) => this.tone(f, 0.16, 'triangle', 0.1, i * 0.09)); },

  sirenOn() {
    if (!this.ctx || this.sirenOsc || this.muted) return;
    const c = this.ctx, o = c.createOscillator(); o.type = 'sawtooth'; o.frequency.value = 700;
    const lfo = c.createOscillator(); lfo.frequency.value = 1.6; const lg = c.createGain(); lg.gain.value = 260;
    lfo.connect(lg); lg.connect(o.frequency); lfo.start();
    const g = c.createGain(); g.gain.value = 0.03; const f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1800;
    o.connect(f); f.connect(g); g.connect(this.sfx); o.start();
    this.sirenOsc = o; this.sirenLfo = lfo;
  },
  sirenOff() { if (!this.sirenOsc) return; try { this.sirenOsc.stop(); this.sirenLfo.stop(); } catch (e) {} this.sirenOsc = null; },

  /* ---------- playlista użytkownika (folder muzyka/) ---------- */
  loadPlaylist() {
    const C = this.club;
    try {
      fetch('api/music').then(r => r.ok ? r.json() : []).then(list => {
        if (Array.isArray(list) && list.length) { C.files = list.sort(() => Math.random() - 0.5); C.useFiles = true; }
      }).catch(() => {});
    } catch (e) {}
  },
  playFile() {
    const C = this.club; if (!C.files.length) return;
    if (!C.el) {
      C.el = new Audio(); C.el.crossOrigin = 'anonymous'; C.el.preload = 'auto';
      try { C.src = this.ctx.createMediaElementSource(C.el); C.src.connect(C.bus); } catch (e) { C.useFiles = false; return; }
      C.el.addEventListener('ended', () => { C.fileIdx = (C.fileIdx + 1) % C.files.length; C.el.src = C.files[C.fileIdx]; C.el.play().catch(() => {}); });
      C.el.addEventListener('error', () => { C.fileIdx = (C.fileIdx + 1) % C.files.length; if (C.files.length > 1) { C.el.src = C.files[C.fileIdx]; C.el.play().catch(() => {}); } else C.useFiles = false; });
      C.el.src = C.files[C.fileIdx];
    }
    C.el.play().catch(() => {});
  },
  trackName() { const C = this.club; return C.useFiles && C.files.length ? decodeURIComponent(C.files[C.fileIdx].split('/').pop()).replace(/\.[a-z0-9]+$/i, '') : ['Neon Nights (club mix)', 'Blok Po Zmroku (remix)', 'Kasa i Sen (bass edit)'][C.track % 3]; },

  /* ---------- syntezator klubowy ---------- */
  TRACKS: [
    { bpm: 126, root: 41, prog: [0, 0, 3, -2], lead: [12, 15, 17, 15, 12, 10, 12, 7, 12, 15, 19, 17, 15, 12, 10, 12], wave: 'sawtooth' },
    { bpm: 122, root: 43, prog: [0, -4, -2, -5], lead: [7, 12, 10, 7, 3, 7, 10, 12, 14, 12, 10, 7, 5, 7, 3, 0], wave: 'square' },
    { bpm: 130, root: 38, prog: [0, 5, 3, 7], lead: [0, 12, 0, 15, 0, 12, 10, 12, 0, 12, 0, 17, 15, 12, 10, 7], wave: 'sawtooth' },
  ],
  mtof(n) { return 440 * Math.pow(2, (n - 69) / 12); },
  schedule() {
    const C = this.club, c = this.ctx; if (!c || !C.playing || C.useFiles) return;
    const T = this.TRACKS[C.track % 3], s16 = 60 / T.bpm / 4;
    if (C.nextT < c.currentTime) C.nextT = c.currentTime + 0.05;
    while (C.nextT < c.currentTime + 0.14) {
      const st = C.step % 16, bar = Math.floor(C.step / 16), sec = Math.floor(bar / 8) % 4, t = C.nextT;
      const full = sec === 2 || sec === 3 && bar % 8 < 6, brk = sec === 3 && bar % 8 >= 6, intro = sec === 0;
      const root = T.root + T.prog[bar % 4];
      // stopa
      if (st % 4 === 0 && !brk) { this.kick(t); C.lastKick = t; }
      // clap
      if ((st === 4 || st === 12) && !intro && !brk) this.clap(t);
      // hi-hat
      if (st % 2 === 0 && !brk) this.noise(st % 4 === 2 ? 0.07 : 0.03, st % 4 === 2 ? 0.05 : 0.022, 8000, 'highpass', t, C.bus);
      if (full && st % 4 === 3) this.noise(0.025, 0.016, 9000, 'highpass', t, C.bus);
      // bas (offbeat)
      if (!intro && (st % 4 === 2 || (full && st === 15))) this.bass(root - 12 + (st === 15 ? 2 : 0), t, s16 * 1.6, brk ? 0.5 : 1);
      if (brk && st % 4 === 0) this.bass(root - 12, t, s16 * 3.4, 0.7);
      // lead / „wokal” cięty
      if ((full || brk) && st % 2 === 0) { const n = T.lead[(st / 2 + (bar % 2) * 8) % 16]; if (!(bar % 4 === 3 && st > 11)) this.lead(root + 12 + n, t, s16 * 1.7, T.wave, brk ? 0.5 : 1); }
      if (sec === 1 && (st === 0 || st === 6 || st === 10)) this.chop(root + 24 + [0, 3, 7][st % 3], t, s16 * 1.5);
      // pad
      if (st === 0 && (brk || sec === 1)) { for (const iv of [0, 3, 7, 10]) this.pad(root + 12 + iv, t, s16 * 16); }
      // narastanie przed dropem
      if (sec === 1 && bar % 8 === 7) this.noise(s16 * 0.9, 0.012 + st * 0.004, 2000 + st * 500, 'bandpass', t, C.bus);
      C.step++; C.nextT += s16;
      if (C.step % (16 * 32) === 0) { C.track++; }
    }
  },
  kick(t) {
    const c = this.ctx, o = c.createOscillator(), g = c.createGain();
    o.type = 'sine'; o.frequency.setValueAtTime(150, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.12);
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.95, t + 0.004); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.3);
    o.connect(g); g.connect(this.club.bus); o.start(t); o.stop(t + 0.32);
  },
  clap(t) { for (let i = 0; i < 3; i++) this.noise(0.09, 0.11, 1500, 'bandpass', t + i * 0.012, this.club.bus); },
  bass(n, t, dur, v) {
    const c = this.ctx, o = c.createOscillator(), f = c.createBiquadFilter(), g = c.createGain();
    o.type = 'sawtooth'; o.frequency.setValueAtTime(this.mtof(n), t);
    f.type = 'lowpass'; f.frequency.setValueAtTime(900, t); f.frequency.exponentialRampToValueAtTime(140, t + dur); f.Q.value = 6;
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.34 * v, t + 0.01); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(f); f.connect(g); g.connect(this.club.bus); o.start(t); o.stop(t + dur + 0.02);
  },
  lead(n, t, dur, wave, v) {
    const c = this.ctx, g = c.createGain(), f = c.createBiquadFilter();
    f.type = 'lowpass'; f.frequency.setValueAtTime(3200, t); f.frequency.exponentialRampToValueAtTime(700, t + dur);
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.085 * v, t + 0.012); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    for (const det of [-7, 7]) { const o = c.createOscillator(); o.type = wave; o.frequency.setValueAtTime(this.mtof(n), t); o.detune.value = det; o.connect(f); o.start(t); o.stop(t + dur + 0.02); }
    f.connect(g); g.connect(this.club.bus);
  },
  chop(n, t, dur) {
    const c = this.ctx, o = c.createOscillator(), f = c.createBiquadFilter(), g = c.createGain();
    o.type = 'sawtooth'; o.frequency.setValueAtTime(this.mtof(n) * 0.5, t); o.frequency.linearRampToValueAtTime(this.mtof(n) * 0.53, t + dur);
    f.type = 'bandpass'; f.frequency.setValueAtTime(900, t); f.frequency.linearRampToValueAtTime(1700, t + dur * 0.6); f.Q.value = 5;
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.16, t + 0.02); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(f); f.connect(g); g.connect(this.club.bus); o.start(t); o.stop(t + dur + 0.02);
  },
  pad(n, t, dur) {
    const c = this.ctx, o = c.createOscillator(), g = c.createGain();
    o.type = 'triangle'; o.frequency.setValueAtTime(this.mtof(n), t);
    g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.03, t + dur * 0.3); g.gain.linearRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(this.club.bus); o.start(t); o.stop(t + dur + 0.05);
  },
  /* 0..1 — siła uderzenia stopy (do efektów świetlnych) */
  beat() {
    const C = this.club; if (!this.ctx || !C.playing) return 0;
    if (C.useFiles) { C.analyser.getByteFrequencyData(C.an); return Math.pow((C.an[1] + C.an[2]) / 510, 2.2); }
    return Math.exp(-Math.max(0, this.ctx.currentTime - C.lastKick) * 7);
  },

  /* wywoływane co klatkę: vol 0..1 (odległość od klubu), inside = w środku */
  update(dt, o) {
    if (!this.ctx) return;
    const C = this.club;
    const want = this.muted ? 0 : (o.clubVol || 0);
    C.vol += (want - C.vol) * Math.min(1, dt * 3);
    const playing = C.vol > 0.012;
    if (playing && !C.playing) { C.playing = true; C.nextT = 0; if (C.useFiles) this.playFile(); }
    if (!playing && C.playing) { C.playing = false; if (C.el) C.el.pause(); }
    if (C.playing) {
      C.bus.gain.value = C.vol * (o.inside ? 0.6 : 0.5);
      const cut = o.inside ? 15000 : 260 + C.vol * 700;
      C.filter.frequency.value += (cut - C.filter.frequency.value) * Math.min(1, dt * 4);
      this.schedule();
    } else C.bus.gain.value = 0;
    if (this.rainGain) this.rainGain.gain.value += ((this.muted ? 0 : (o.rain || 0) * (o.indoor ? 0.03 : 0.11)) - this.rainGain.gain.value) * Math.min(1, dt * 2);
  },
};
