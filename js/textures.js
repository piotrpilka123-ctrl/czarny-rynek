'use strict';
/* ============================================================
   TEKSTURY PROCEDURALNE: nawierzchnie, fasady, witryny, wnętrza
   ============================================================ */

const TX = { c: {} };
TX.get = function (name, make) { return TX.c[name] || (TX.c[name] = make()); };
const hex2rgb = (h) => { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
const shade = (h, k) => { const c = hex2rgb(h); return `rgb(${Math.round(clamp(c[0] * k, 0, 255))},${Math.round(clamp(c[1] * k, 0, 255))},${Math.round(clamp(c[2] * k, 0, 255))})`; };

/* baza: kolor + szum */
TX.noisy = function (g, w, h, col, amp, scale, oct, seed) {
  const c = hex2rgb(col);
  GFX.fbmPaint(g, w, h, scale || 8, oct || 4, seed || 3, (v) => { const k = 1 + (v - 0.5) * 2 * amp; return [c[0] * k, c[1] * k, c[2] * k]; });
};
TX.speckle = function (g, w, h, n, dark, light, rnd) {
  for (let i = 0; i < n; i++) { g.fillStyle = rnd() < 0.5 ? dark : light; const s = 1 + rnd() * 2; g.fillRect(rnd() * w, rnd() * h, s, s); }
};
TX.cracks = function (g, w, h, n, col, rnd) {
  g.strokeStyle = col; g.lineCap = 'round';
  for (let i = 0; i < n; i++) {
    let x = rnd() * w, y = rnd() * h, a = rnd() * 6.28; g.lineWidth = 0.6 + rnd() * 1.4; g.beginPath(); g.moveTo(x, y);
    const steps = 6 + (rnd() * 14) | 0;
    for (let k = 0; k < steps; k++) { a += (rnd() - 0.5) * 1.2; x += Math.cos(a) * (6 + rnd() * 12); y += Math.sin(a) * (6 + rnd() * 12); g.lineTo(x, y); }
    g.stroke();
  }
};

/* ---------- nawierzchnie ---------- */
TX.asphalt = () => TX.get('asphalt', () => {
  const rnd = mulberry(11);
  const c = GFX.canvas(512, 512, (g, w, h) => {
    TX.noisy(g, w, h, '#3b3c40', 0.16, 6, 5, 11);
    TX.speckle(g, w, h, 5000, 'rgba(0,0,0,.25)', 'rgba(190,190,190,.16)', rnd);
    TX.cracks(g, w, h, 9, 'rgba(10,10,12,.55)', rnd);
    for (let i = 0; i < 6; i++) { g.fillStyle = `rgba(${rnd() < 0.5 ? '20,20,22' : '90,90,95'},.10)`; g.fillRect(rnd() * w, rnd() * h, 40 + rnd() * 120, 30 + rnd() * 90); }
  });
  const b = GFX.canvas(256, 256, (g, w, h) => { TX.noisy(g, w, h, '#808080', 0.5, 32, 3, 12); TX.cracks(g, w, h, 6, 'rgba(0,0,0,.8)', mulberry(11)); });
  return { map: GFX.tex(c, { repeat: true }), bump: GFX.tex(b, { repeat: true, linear: true }) };
});
/* droga: u wzdłuż (16 m), v w poprzek (12 m) */
TX.road = () => TX.get('road', () => {
  const rnd = mulberry(21);
  const c = GFX.canvas(1024, 512, (g, w, h) => {
    TX.noisy(g, w, h, '#37383c', 0.15, 8, 5, 21);
    TX.speckle(g, w, h, 9000, 'rgba(0,0,0,.25)', 'rgba(190,190,190,.15)', rnd);
    // ślady opon
    for (const v of [0.25, 0.75]) { const gr = g.createLinearGradient(0, h * (v - 0.12), 0, h * (v + 0.12)); gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(0.5, 'rgba(0,0,0,.22)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, h * (v - 0.12), w, h * 0.24); }
    TX.cracks(g, w, h, 12, 'rgba(8,8,10,.5)', rnd);
    // linie
    g.fillStyle = 'rgba(225,225,220,.82)';
    g.fillRect(0, h * 0.035, w, 6); g.fillRect(0, h * 0.965 - 6, w, 6);
    for (let k = 0; k < 2; k++) g.fillRect(w * (0.06 + k * 0.5), h / 2 - 3, w * 0.25, 6);
    // przetarcia linii
    g.globalCompositeOperation = 'destination-over';
    g.globalCompositeOperation = 'source-over';
    for (let i = 0; i < 260; i++) { g.fillStyle = 'rgba(55,56,60,.5)'; const y = rnd() < 0.5 ? h / 2 - 4 + rnd() * 8 : (rnd() < 0.5 ? h * 0.035 + rnd() * 6 : h * 0.965 - 6 + rnd() * 6); g.fillRect(rnd() * w, y, 2 + rnd() * 8, 1.5); }
    // łaty i studzienka
    g.fillStyle = 'rgba(25,25,28,.35)'; g.fillRect(w * 0.6, h * 0.58, 90, 60);
    g.fillStyle = '#2a2b2e'; g.beginPath(); g.arc(w * 0.3, h * 0.3, 15, 0, 7); g.fill(); g.strokeStyle = '#17181a'; g.lineWidth = 3; g.stroke();
    g.strokeStyle = 'rgba(80,80,84,.9)'; g.lineWidth = 1.5; for (let k = -2; k <= 2; k++) { g.beginPath(); g.moveTo(w * 0.3 - 11, h * 0.3 + k * 5); g.lineTo(w * 0.3 + 11, h * 0.3 + k * 5); g.stroke(); }
  });
  return { map: GFX.tex(c, { repeat: true, aniso: 16 }), bump: TX.asphalt().bump };
});
TX.paving = () => TX.get('paving', () => {
  const rnd = mulberry(31);
  const c = GFX.canvas(512, 512, (g, w, h) => {
    TX.noisy(g, w, h, '#8d9095', 0.12, 10, 4, 31);
    const n = 6, s = w / n;
    for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) { g.fillStyle = `rgba(${rnd() < 0.5 ? '0,0,0' : '255,255,255'},${rnd() * 0.09})`; g.fillRect(i * s, j * s, s, s); }
    g.strokeStyle = 'rgba(40,42,46,.75)'; g.lineWidth = 2.5;
    for (let i = 0; i <= n; i++) { g.beginPath(); g.moveTo(i * s, 0); g.lineTo(i * s, h); g.stroke(); g.beginPath(); g.moveTo(0, i * s); g.lineTo(w, i * s); g.stroke(); }
    TX.speckle(g, w, h, 2500, 'rgba(0,0,0,.2)', 'rgba(255,255,255,.12)', rnd);
    for (let i = 0; i < 26; i++) { g.fillStyle = 'rgba(20,20,22,.5)'; g.beginPath(); g.ellipse(rnd() * w, rnd() * h, 2 + rnd() * 3, 2 + rnd() * 2, rnd() * 3, 0, 7); g.fill(); }
    TX.cracks(g, w, h, 4, 'rgba(20,20,22,.4)', rnd);
  });
  const b = GFX.canvas(256, 256, (g, w, h) => {
    TX.noisy(g, w, h, '#909090', 0.25, 24, 3, 32);
    g.strokeStyle = '#202020'; g.lineWidth = 3; const s = w / 6;
    for (let i = 0; i <= 6; i++) { g.beginPath(); g.moveTo(i * s, 0); g.lineTo(i * s, h); g.stroke(); g.beginPath(); g.moveTo(0, i * s); g.lineTo(w, i * s); g.stroke(); }
  });
  return { map: GFX.tex(c, { repeat: true }), bump: GFX.tex(b, { repeat: true, linear: true }) };
});
TX.grass = () => TX.get('grass', () => {
  const rnd = mulberry(41);
  const c = GFX.canvas(512, 512, (g, w, h) => {
    GFX.fbmPaint(g, w, h, 6, 5, 41, (v) => [38 + v * 40, 78 + v * 62, 30 + v * 26]);
    for (let i = 0; i < 9000; i++) { const x = rnd() * w, y = rnd() * h; g.strokeStyle = `rgba(${40 + rnd() * 60},${110 + rnd() * 70},${30 + rnd() * 40},.5)`; g.lineWidth = 1; g.beginPath(); g.moveTo(x, y); g.lineTo(x + (rnd() - 0.5) * 3, y - 2 - rnd() * 4); g.stroke(); }
    for (let i = 0; i < 40; i++) { g.fillStyle = 'rgba(120,100,50,.18)'; g.beginPath(); g.ellipse(rnd() * w, rnd() * h, 8 + rnd() * 20, 6 + rnd() * 14, 0, 0, 7); g.fill(); }
  });
  const b = GFX.canvas(256, 256, (g, w, h) => TX.noisy(g, w, h, '#808080', 0.6, 40, 3, 42));
  return { map: GFX.tex(c, { repeat: true }), bump: GFX.tex(b, { repeat: true, linear: true }) };
});
TX.gravel = () => TX.get('gravel', () => {
  const rnd = mulberry(51);
  const c = GFX.canvas(256, 256, (g, w, h) => { TX.noisy(g, w, h, '#a08f72', 0.2, 12, 4, 51); TX.speckle(g, w, h, 4000, 'rgba(60,50,35,.5)', 'rgba(230,220,200,.4)', rnd); });
  return { map: GFX.tex(c, { repeat: true }) };
});
TX.roof = () => TX.get('roof', () => {
  const rnd = mulberry(61);
  const c = GFX.canvas(256, 256, (g, w, h) => {
    TX.noisy(g, w, h, '#3a3b3f', 0.2, 8, 4, 61); TX.speckle(g, w, h, 2500, 'rgba(0,0,0,.3)', 'rgba(170,170,170,.2)', rnd);
    g.strokeStyle = 'rgba(15,15,17,.6)'; g.lineWidth = 2; for (let i = 0; i < 4; i++) { g.beginPath(); g.moveTo(0, i * 64 + 10); g.lineTo(w, i * 64 + 10); g.stroke(); }
    for (let i = 0; i < 5; i++) { g.fillStyle = 'rgba(70,75,80,.25)'; g.beginPath(); g.ellipse(rnd() * w, rnd() * h, 20 + rnd() * 30, 10 + rnd() * 18, rnd() * 3, 0, 7); g.fill(); }
  });
  return { map: GFX.tex(c, { repeat: true }) };
});
TX.concrete = (col) => TX.get('conc' + col, () => {
  const rnd = mulberry(71);
  const c = GFX.canvas(256, 256, (g, w, h) => { TX.noisy(g, w, h, col, 0.1, 6, 4, 71); TX.speckle(g, w, h, 1200, 'rgba(0,0,0,.12)', 'rgba(255,255,255,.08)', rnd); });
  return { map: GFX.tex(c, { repeat: true }) };
});
TX.wood = () => TX.get('wood', () => {
  const rnd = mulberry(81);
  const c = GFX.canvas(512, 512, (g, w, h) => {
    const n = 8, pw = w / n;
    for (let i = 0; i < n; i++) {
      const k = 0.82 + rnd() * 0.32; g.fillStyle = shade('#7a5636', k); g.fillRect(i * pw, 0, pw, h);
      for (let l = 0; l < 40; l++) { g.strokeStyle = `rgba(40,25,12,${0.05 + rnd() * 0.12})`; g.lineWidth = 1; const x = i * pw + rnd() * pw; g.beginPath(); g.moveTo(x, 0); g.bezierCurveTo(x + (rnd() - 0.5) * 6, h * 0.3, x + (rnd() - 0.5) * 6, h * 0.6, x + (rnd() - 0.5) * 4, h); g.stroke(); }
      g.fillStyle = 'rgba(20,12,6,.7)'; g.fillRect(i * pw, 0, 1.5, h);
      const jy = rnd() * h; g.fillRect(i * pw, jy, pw, 1.5);
    }
  });
  return { map: GFX.tex(c, { repeat: true }) };
});
TX.tiles = (c1, c2) => TX.get('tiles' + c1 + c2, () => {
  const rnd = mulberry(91);
  const c = GFX.canvas(256, 256, (g, w, h) => {
    for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) { g.fillStyle = shade((i + j) % 2 ? c1 : c2, 0.92 + rnd() * 0.16); g.fillRect(i * 64, j * 64, 64, 64); }
    g.strokeStyle = 'rgba(15,15,18,.7)'; g.lineWidth = 2; for (let i = 0; i <= 4; i++) { g.beginPath(); g.moveTo(i * 64, 0); g.lineTo(i * 64, h); g.stroke(); g.beginPath(); g.moveTo(0, i * 64); g.lineTo(w, i * 64); g.stroke(); }
    TX.speckle(g, w, h, 500, 'rgba(0,0,0,.15)', 'rgba(255,255,255,.08)', rnd);
  });
  return { map: GFX.tex(c, { repeat: true }) };
});
TX.wall = (col, seed) => TX.get('wall' + col, () => {
  const rnd = mulberry(seed || 101);
  const c = GFX.canvas(256, 256, (g, w, h) => {
    TX.noisy(g, w, h, col, 0.07, 5, 4, seed || 101);
    const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, 'rgba(0,0,0,.10)'); gr.addColorStop(0.2, 'rgba(0,0,0,0)'); gr.addColorStop(0.85, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(0,0,0,.22)'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    TX.cracks(g, w, h, 2, 'rgba(0,0,0,.12)', rnd);
  });
  return { map: GFX.tex(c, { repeat: true }) };
});

/* ---------- FASADY (kafel 4 okna × 4 piętra = 16 m × 12 m) ---------- */
TX.facade = function (style, pal, seed) {
  return TX.get('fac_' + style + pal.wall + seed, () => {
    const S = 512, C = 128, rnd = mulberry(seed * 13 + 7);
    const cells = [];
    for (let r = 0; r < 4; r++) for (let c = 0; c < 4; c++) cells.push({ r, c, x: c * C, y: r * C, lit: rnd() < 0.52, tv: rnd() < 0.16, cur: rnd(), k: rnd() });
    let win;   // funkcja: prostokąt okna dla komórki
    if (style === 'blok') win = (q) => (q.c % 2 === 1) ? [16, 22, 96, 78] : [30, 30, 68, 62];
    else if (style === 'kamienica') win = (q) => [38, 18, 52, 86];
    else if (style === 'modern') win = (q) => [4, 22, 120, 100];
    else if (style === 'brick') win = (q) => (q.k < 0.55 ? [34, 34, 60, 50] : null);
    else win = () => null;

    const map = GFX.canvas(S, S, (g) => {
      TX.noisy(g, S, S, pal.wall, style === 'brick' ? 0.05 : 0.09, 7, 4, seed + 3);
      if (style === 'brick') {
        for (let y = 0; y < S; y += 16) for (let x = -32; x < S; x += 32) {
          const ox = (y / 16) % 2 ? 16 : 0; g.fillStyle = shade(pal.wall, 0.78 + rnd() * 0.4); g.fillRect(x + ox + 1, y + 1, 30, 14);
        }
        g.fillStyle = 'rgba(0,0,0,.18)'; for (let i = 0; i < 12; i++) g.fillRect(rnd() * S, rnd() * S, 30 + rnd() * 80, 40 + rnd() * 120);
      }
      if (style === 'blok') {
        // pasy „pastelozy”
        g.fillStyle = pal.accent; g.globalAlpha = 0.9; g.fillRect(C + 6, 0, C - 12, S); g.globalAlpha = 0.55; g.fillRect(3 * C + 6, 0, C - 12, S); g.globalAlpha = 1;
        g.strokeStyle = 'rgba(0,0,0,.35)'; g.lineWidth = 2;
        for (let i = 0; i <= 4; i++) { g.beginPath(); g.moveTo(i * C, 0); g.lineTo(i * C, S); g.stroke(); g.beginPath(); g.moveTo(0, i * C); g.lineTo(S, i * C); g.stroke(); }
        g.strokeStyle = 'rgba(255,255,255,.18)'; g.lineWidth = 1; for (let i = 0; i <= 4; i++) { g.beginPath(); g.moveTo(i * C + 2, 0); g.lineTo(i * C + 2, S); g.stroke(); }
      }
      if (style === 'kamienica') {
        for (let r = 0; r < 4; r++) { g.fillStyle = shade(pal.trim, 1.0); g.fillRect(0, r * C + C - 9, S, 7); g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(0, r * C + C - 2, S, 3); g.fillStyle = 'rgba(255,255,255,.2)'; g.fillRect(0, r * C + C - 10, S, 1.5); }
        TX.cracks(g, S, S, 5, 'rgba(0,0,0,.22)', rnd);
      }
      if (style === 'modern') {
        g.fillStyle = shade(pal.wall, 0.7); for (let r = 0; r < 4; r++) g.fillRect(0, r * C, S, 20);
      }
      if (style === 'dark') {
        g.strokeStyle = 'rgba(255,255,255,.05)'; g.lineWidth = 2; for (let i = 0; i <= 8; i++) { g.beginPath(); g.moveTo(i * 64, 0); g.lineTo(i * 64, S); g.stroke(); }
        for (let r = 0; r < 4; r++) { g.fillStyle = r % 2 ? '#ff2bd6' : '#2be4ff'; g.fillRect(0, r * C + 60, S, 4); }
      }
      for (const q of cells) {
        const wr = win(q); if (!wr) continue;
        const x = q.x + wr[0], y = q.y + wr[1], w = wr[2], h = wr[3];
        // wnęka i szyba
        g.fillStyle = 'rgba(0,0,0,.45)'; g.fillRect(x - 3, y - 3, w + 6, h + 6);
        const gr = g.createLinearGradient(0, y, 0, y + h);
        if (style === 'modern') { gr.addColorStop(0, '#7fa6bd'); gr.addColorStop(0.5, '#3d5d74'); gr.addColorStop(1, '#22384a'); }
        else { gr.addColorStop(0, '#6f8ea6'); gr.addColorStop(0.45, '#2c3e50'); gr.addColorStop(1, '#17212c'); }
        g.fillStyle = gr; g.fillRect(x, y, w, h);
        // odbicie
        g.fillStyle = 'rgba(255,255,255,.10)'; g.beginPath(); g.moveTo(x, y + h * 0.5); g.lineTo(x + w * 0.5, y); g.lineTo(x + w * 0.72, y); g.lineTo(x, y + h * 0.78); g.fill();
        if (style !== 'modern') {
          // firanka / roleta
          if (q.cur < 0.4) { g.fillStyle = 'rgba(235,232,222,.5)'; g.fillRect(x, y, w, h * (0.3 + q.k * 0.6)); }
          else if (q.cur < 0.6) { g.fillStyle = 'rgba(210,200,170,.55)'; g.fillRect(x, y, w * 0.3, h); g.fillRect(x + w * 0.7, y, w * 0.3, h); }
          // ramy
          g.strokeStyle = style === 'kamienica' ? pal.frame : '#e9ecef'; g.lineWidth = style === 'brick' ? 2 : 4; g.strokeRect(x, y, w, h);
          g.lineWidth = 3; g.beginPath(); g.moveTo(x + w / 2, y); g.lineTo(x + w / 2, y + h); g.stroke();
          if (style === 'kamienica' || style === 'brick') { g.lineWidth = 2; g.beginPath(); g.moveTo(x, y + h * 0.33); g.lineTo(x + w, y + h * 0.33); g.stroke(); }
          if (style === 'brick') { g.beginPath(); g.moveTo(x, y + h * 0.66); g.lineTo(x + w, y + h * 0.66); g.stroke(); }
          // parapet
          g.fillStyle = shade(pal.trim, 1.05); g.fillRect(x - 6, y + h + 3, w + 12, 5); g.fillStyle = 'rgba(0,0,0,.3)'; g.fillRect(x - 6, y + h + 8, w + 12, 3);
          // zaciek
          const st = g.createLinearGradient(0, y + h + 10, 0, y + h + 40); st.addColorStop(0, 'rgba(0,0,0,.16)'); st.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = st; g.fillRect(x + w * 0.2, y + h + 10, w * 0.15, 30); g.fillRect(x + w * 0.7, y + h + 10, w * 0.1, 24);
        } else {
          g.strokeStyle = '#1a2026'; g.lineWidth = 4; g.strokeRect(x, y, w, h); g.beginPath(); g.moveTo(x + w / 2, y); g.lineTo(x + w / 2, y + h); g.stroke();
        }
        if (style === 'kamienica') {
          g.fillStyle = shade(pal.trim, 1.08); g.beginPath(); g.moveTo(x - 8, y - 4); g.lineTo(x + w / 2, y - 16); g.lineTo(x + w + 8, y - 4); g.fill();
          if (q.k < 0.25) { g.strokeStyle = '#141414'; g.lineWidth = 2; g.strokeRect(x - 8, y + h - 26, w + 16, 30); for (let b = 0; b < 8; b++) { g.beginPath(); g.moveTo(x - 8 + b * (w + 16) / 7, y + h - 26); g.lineTo(x - 8 + b * (w + 16) / 7, y + h + 4); g.stroke(); } }
        }
        if (style === 'blok' && q.c % 2 === 1) {
          // balkon
          const by = q.y + C - 14;
          g.fillStyle = 'rgba(0,0,0,.4)'; g.fillRect(q.x + 6, by + 4, C - 12, 6);
          g.fillStyle = '#b9bcc0'; g.fillRect(q.x + 6, by, C - 12, 6);
          g.fillStyle = q.k < 0.5 ? shade(pal.accent, 0.82) : '#9a9da2'; g.fillRect(q.x + 8, by - 34, C - 16, 34);
          g.strokeStyle = 'rgba(0,0,0,.35)'; g.lineWidth = 1.5; g.strokeRect(q.x + 8, by - 34, C - 16, 34);
          for (let b = 1; b < 6; b++) { g.beginPath(); g.moveTo(q.x + 8 + b * (C - 16) / 6, by - 34); g.lineTo(q.x + 8 + b * (C - 16) / 6, by); g.stroke(); }
          if (q.cur < 0.3) { g.fillStyle = '#d7dadd'; g.beginPath(); g.ellipse(q.x + 98, by - 46, 11, 9, 0, 0, 7); g.fill(); g.strokeStyle = '#777'; g.stroke(); }
          else if (q.cur < 0.55) { for (let b = 0; b < 3; b++) { g.fillStyle = ['#c0392b', '#2e86c1', '#f4d03f', '#ecf0f1'][(q.r + b + q.c) % 4]; g.fillRect(q.x + 22 + b * 26, by - 52, 20, 16); } }
          else if (q.cur < 0.75) { g.fillStyle = '#2f7a35'; g.beginPath(); g.arc(q.x + 28, by - 40, 10, 0, 7); g.fill(); g.beginPath(); g.arc(q.x + 44, by - 37, 7, 0, 7); g.fill(); }
        }
        if (style === 'blok' && q.c % 2 === 0 && q.k > 0.9) { g.fillStyle = '#c3c7cc'; g.fillRect(q.x + 96, q.y + 92, 26, 18); g.strokeStyle = '#555'; g.lineWidth = 1.5; g.strokeRect(q.x + 96, q.y + 92, 26, 18); g.beginPath(); g.arc(q.x + 109, q.y + 101, 6, 0, 7); g.stroke(); }
      }
      // ogólne zabrudzenia
      const gr2 = g.createLinearGradient(0, 0, 0, S); gr2.addColorStop(0, 'rgba(0,0,0,.08)'); gr2.addColorStop(0.5, 'rgba(0,0,0,0)'); gr2.addColorStop(1, 'rgba(0,0,0,.10)'); g.fillStyle = gr2; g.fillRect(0, 0, S, S);
    });
    const emi = GFX.canvas(S, S, (g) => {
      g.fillStyle = '#000'; g.fillRect(0, 0, S, S);
      if (style === 'dark') { for (let r = 0; r < 4; r++) { g.fillStyle = r % 2 ? '#ff2bd6' : '#2be4ff'; g.fillRect(0, r * C + 60, S, 4); } return; }
      for (const q of cells) {
        const wr = win(q); if (!wr || !q.lit) continue;
        const x = q.x + wr[0], y = q.y + wr[1], w = wr[2], h = wr[3];
        const base = q.tv ? [120, 170, 255] : (style === 'modern' ? [215, 230, 255] : (q.k < 0.5 ? [255, 196, 120] : [255, 214, 150]));
        const a = 0.55 + q.k * 0.45;
        const gr = g.createLinearGradient(0, y, 0, y + h); gr.addColorStop(0, `rgba(${base[0]},${base[1]},${base[2]},${a})`); gr.addColorStop(1, `rgba(${base[0] * 0.7},${base[1] * 0.6},${base[2] * 0.5},${a * 0.8})`);
        g.fillStyle = gr; g.fillRect(x + 2, y + 2, w - 4, h - 4);
        g.fillStyle = 'rgba(0,0,0,.55)'; g.fillRect(x + w / 2 - 1.5, y, 3, h);
        if (q.cur < 0.4) { g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(x, y, w, h * (0.3 + q.k * 0.6)); }
        if (style !== 'modern' && q.k > 0.6) { g.fillStyle = 'rgba(0,0,0,.6)'; g.fillRect(x + w * 0.6, y + h * 0.5, w * 0.25, h * 0.5); }
      }
    });
    const bump = GFX.canvas(256, 256, (g) => {
      const k = 0.5; g.fillStyle = '#8a8a8a'; g.fillRect(0, 0, 256, 256);
      if (style === 'brick') { g.fillStyle = '#5a5a5a'; for (let y = 0; y < 256; y += 8) g.fillRect(0, y, 256, 1.5); for (let y = 0; y < 256; y += 8) for (let x = 0; x < 256; x += 16) g.fillRect(x + ((y / 8) % 2 ? 8 : 0), y, 1.5, 8); }
      if (style === 'blok') { g.fillStyle = '#404040'; for (let i = 0; i <= 4; i++) { g.fillRect(i * 64 - 1, 0, 2.5, 256); g.fillRect(0, i * 64 - 1, 256, 2.5); } }
      if (style === 'kamienica') { g.fillStyle = '#c8c8c8'; for (let r = 0; r < 4; r++) g.fillRect(0, r * 64 + 59, 256, 4); }
      for (const q of cells) {
        const wr = win(q); if (!wr) continue;
        g.fillStyle = '#303030'; g.fillRect((q.x + wr[0]) * k, (q.y + wr[1]) * k, wr[2] * k, wr[3] * k);
        g.fillStyle = '#d0d0d0'; g.fillRect((q.x + wr[0] - 6) * k, (q.y + wr[1] + wr[3] + 3) * k, (wr[2] + 12) * k, 3);
        if (style === 'blok' && q.c % 2 === 1) { g.fillStyle = '#e8e8e8'; g.fillRect((q.x + 8) * k, (q.y + C - 48) * k, (C - 16) * k, 20); }
      }
    });
    return { map: GFX.tex(map, { repeat: true }), emi: GFX.tex(emi, { repeat: true }), bump: GFX.tex(bump, { repeat: true, linear: true }) };
  });
};

/* ---------- WITRYNY (8 m × 3 m) ---------- */
TX.shop = function (name, col, seed) {
  return TX.get('shop_' + name, () => {
    const rnd = mulberry(seed * 5 + 2), W = 512, H = 192;
    const paint = (emi) => (g) => {
      g.fillStyle = emi ? '#000' : '#26282c'; g.fillRect(0, 0, W, H);
      // szyld
      g.fillStyle = emi ? col : shade(col, 0.55); g.fillRect(8, 6, W - 16, 44);
      g.fillStyle = emi ? '#fff' : '#f4f4f4'; g.font = 'bold 30px sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
      if (emi) { g.shadowColor = '#fff'; g.shadowBlur = 8; } g.fillText(name, W / 2, 29); g.shadowBlur = 0;
      // szyby
      const glass = (x, w) => {
        if (emi) { const gr = g.createLinearGradient(0, 58, 0, H - 14); gr.addColorStop(0, 'rgba(255,214,150,.75)'); gr.addColorStop(1, 'rgba(255,170,90,.35)'); g.fillStyle = gr; }
        else { const gr = g.createLinearGradient(0, 58, 0, H - 14); gr.addColorStop(0, '#59758a'); gr.addColorStop(1, '#1b2530'); g.fillStyle = gr; }
        g.fillRect(x, 58, w, H - 72);
        // półki / towary
        for (let s = 0; s < 3; s++) for (let k = 0; k < Math.floor(w / 22); k++) { g.fillStyle = emi ? `rgba(0,0,0,${0.25 + rnd() * 0.4})` : `rgba(${40 + rnd() * 160},${40 + rnd() * 140},${40 + rnd() * 140},.55)`; g.fillRect(x + 6 + k * 22, 78 + s * 32 + rnd() * 6, 14, 16); }
        if (!emi) { g.fillStyle = 'rgba(255,255,255,.10)'; g.beginPath(); g.moveTo(x, 58 + (H - 72) * 0.7); g.lineTo(x + w * 0.5, 58); g.lineTo(x + w * 0.75, 58); g.lineTo(x, H - 14); g.fill(); g.strokeStyle = '#111316'; g.lineWidth = 4; g.strokeRect(x, 58, w, H - 72); }
      };
      glass(14, 180); glass(318, 180);
      // drzwi
      g.fillStyle = emi ? 'rgba(255,200,130,.5)' : '#2e3f4c'; g.fillRect(212, 62, 88, H - 68);
      if (!emi) { g.strokeStyle = '#0d0f11'; g.lineWidth = 5; g.strokeRect(212, 62, 88, H - 68); g.fillStyle = '#c9ced4'; g.fillRect(286, 120, 5, 26); g.fillStyle = '#17181b'; g.fillRect(0, H - 12, W, 12); }
      else { g.fillStyle = '#fff'; g.font = 'bold 13px sans-serif'; g.fillText('OTWARTE', 256, 80); }
    };
    return { map: GFX.tex(GFX.canvas(W, H, paint(false))), emi: GFX.tex(GFX.canvas(W, H, paint(true))) };
  });
};

/* szyld / neon: tekst na ciemnym tle */
TX.sign = function (text, bg, fg, font, glow) {
  return TX.get('sign_' + text + bg + fg, () => {
    const lines = String(text).split('\n');
    const c = GFX.canvas(512, 128 * Math.max(1, lines.length * 0.75), (g, w, h) => {
      g.fillStyle = bg; g.fillRect(0, 0, w, h);
      g.strokeStyle = fg; g.lineWidth = 6; g.strokeRect(6, 6, w - 12, h - 12);
      g.fillStyle = fg; g.font = font || 'bold 80px sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
      if (glow) { g.shadowColor = fg; g.shadowBlur = 22; }
      lines.forEach((l, i) => g.fillText(l, w / 2, h * (i + 0.5) / lines.length + 4));
    });
    return GFX.tex(c);
  });
};
TX.glow = () => TX.get('glow', () => GFX.tex(GFX.canvas(128, 128, (g, w, h) => {
  const gr = g.createRadialGradient(w / 2, h / 2, 2, w / 2, h / 2, w / 2); gr.addColorStop(0, 'rgba(255,214,150,1)'); gr.addColorStop(0.4, 'rgba(255,200,130,.45)'); gr.addColorStop(1, 'rgba(255,200,130,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
})));
TX.graffiti = (seed) => TX.get('graf' + seed, () => {
  const rnd = mulberry(seed * 9 + 1), words = ['WILKI', 'JP', 'ZAUŁEK', 'W1LK', 'KRUK', '★', 'RAJD'];
  return GFX.tex(GFX.canvas(512, 256, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    for (let i = 0; i < 4; i++) {
      g.save(); g.translate(60 + rnd() * 380, 50 + rnd() * 160); g.rotate((rnd() - 0.5) * 0.4);
      g.font = `bold ${50 + rnd() * 50}px sans-serif`; g.lineWidth = 8; g.strokeStyle = 'rgba(10,10,10,.9)'; g.fillStyle = ['#e74c3c', '#f1c40f', '#2ecc71', '#3498db', '#e84393', '#ecf0f1'][(rnd() * 6) | 0];
      const t = words[(rnd() * words.length) | 0]; g.strokeText(t, 0, 0); g.fillText(t, 0, 0); g.restore();
    }
  }));
});
