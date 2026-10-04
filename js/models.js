'use strict';
/* ============================================================
   MODELE: postacie (szkielet ze stawami), samochody, drzewa, rekwizyty
   ============================================================ */

const Models = { cache: {}, faceMats: {}, lightMats: {} };

const SKIN = ['#f1c9a5', '#e6b890', '#d09a6e', '#a8734b', '#7d5236', '#f6d8bf'];
const HAIRC = ['#17130f', '#33241a', '#5e4126', '#9a7040', '#c8ae82', '#7d7d7d', '#8a3324', '#222831'];
const TOPC = ['#2f4a6d', '#6d2f2f', '#2f6d45', '#3d3d42', '#a8a39a', '#7a5c2e', '#4b3a6d', '#8a2d52', '#1f6f78', '#c7b08a', '#20242b', '#b0492c', '#d8d8d8'];
const BOTC = ['#232a36', '#2e3a52', '#3b3630', '#1b1b1e', '#4a4f57', '#5b4a3a', '#283b2e'];
const SHOEC = ['#151515', '#3a2a1e', '#e8e8e8', '#5a1f1f', '#22324a'];

/* ---------- twarz (naklejka) ---------- */
Models.faceMat = function (kind) {
  if (Models.faceMats[kind]) return Models.faceMats[kind];
  const c = GFX.canvas(128, 64, (g) => {
    g.clearRect(0, 0, 128, 64);
    const eye = (x) => {
      g.fillStyle = 'rgba(250,250,250,.95)'; g.beginPath(); g.ellipse(x, 26, 10, kind === 'stern' ? 4.5 : 6, 0, 0, 7); g.fill();
      g.fillStyle = '#2a1a10'; g.beginPath(); g.arc(x, 26, 4.2, 0, 7); g.fill();
      g.fillStyle = '#000'; g.beginPath(); g.arc(x, 26, 2, 0, 7); g.fill();
      g.strokeStyle = 'rgba(30,18,10,.85)'; g.lineWidth = 2; g.beginPath(); g.ellipse(x, 26, 10, kind === 'stern' ? 4.5 : 6, 0, Math.PI, 0); g.stroke();
    };
    eye(40); eye(88);
    g.strokeStyle = 'rgba(40,25,15,.9)'; g.lineWidth = 3.5; g.lineCap = 'round';
    if (kind === 'stern') { g.beginPath(); g.moveTo(27, 13); g.lineTo(52, 18); g.stroke(); g.beginPath(); g.moveTo(101, 13); g.lineTo(76, 18); g.stroke(); }
    else { g.beginPath(); g.moveTo(28, 15); g.quadraticCurveTo(40, 10, 52, 15); g.stroke(); g.beginPath(); g.moveTo(76, 15); g.quadraticCurveTo(88, 10, 100, 15); g.stroke(); }
    g.strokeStyle = 'rgba(110,40,40,.85)'; g.lineWidth = 3;
    g.beginPath();
    if (kind === 'smile') { g.moveTo(50, 52); g.quadraticCurveTo(64, 61, 78, 52); }
    else if (kind === 'stern') { g.moveTo(52, 56); g.quadraticCurveTo(64, 52, 76, 56); }
    else { g.moveTo(52, 55); g.lineTo(76, 55); }
    g.stroke();
  });
  const t = GFX.tex(c, { aniso: 4 });
  const m = new THREE.MeshStandardMaterial({ map: t, transparent: true, depthWrite: false, roughness: 0.9, polygonOffset: true, polygonOffsetFactor: -4 });
  m.userData.envBase = 0.3; m.envMapIntensity = 0.3 * GFX.envIntensity; GFX.matList.push(m);
  return (Models.faceMats[kind] = m);
};

/* ---------- POSTAĆ ----------
   o: { skin, hair, hairColor, top:{type,color,color2}, bottom:{type,color}, shoes, female, height, build,
        hat, beard, glasses, face, role }                                                    */
Models.person = function (o) {
  o = Object.assign({}, o || {});
  const female = o.female != null ? o.female : Math.random() < 0.45;
  const skin = o.skin || pick(SKIN), hc = o.hairColor || pick(HAIRC);
  const top = Object.assign({ type: pick(['tshirt', 'hoodie', 'jacket', 'shirt', 'tshirt', 'jacket']), color: pick(TOPC), color2: pick(['#e8e8e8', '#222', '#d9c9a8', '#8a8f98']) }, o.top || {});
  const bottom = Object.assign({ type: female && Math.random() < 0.25 ? 'skirt' : pick(['jeans', 'pants', 'jeans', 'shorts']), color: pick(BOTC) }, o.bottom || {});
  const shoes = o.shoes || pick(SHOEC);
  const hair = o.hair || (female ? pick(['long', 'long', 'ponytail', 'bob', 'short']) : pick(['short', 'short', 'buzz', 'bald', 'short', 'long']));
  const build = o.build || rr(0.92, 1.12), height = o.height || (female ? rr(1.6, 1.74) : rr(1.7, 1.88));
  const vcMat = GFX.mat('#ffffff', { vc: true, rough: 0.86, key: 'person', env: 0.35 });
  const mk = (gb, parent, x, y, z) => { const m = new THREE.Mesh(gb.build(), vcMat); m.castShadow = true; m.receiveShadow = false; if (x != null) m.position.set(x, y, z); parent.add(m); return m; };
  const grp = (parent, x, y, z) => { const g = new THREE.Group(); g.position.set(x, y, z); parent.add(g); return g; };

  const root = new THREE.Group();
  const body = new THREE.Group(); root.add(body);
  const s = height / 1.86; body.scale.set(s * build * 1.2, s, s * build * 1.24);
  const pelvis = grp(body, 0, 0.96, 0);
  const longSleeve = top.type !== 'tshirt' && top.type !== 'tank' && top.type !== 'dress';
  const sleeveC = top.type === 'tank' ? skin : top.color;
  const legSkin = bottom.type === 'shorts' || bottom.type === 'skirt' || top.type === 'dress';

  // --- miednica ---
  let gb = new GB();
  gb.cyl(0.16, 0.155, 0.2, top.type === 'dress' ? top.color : bottom.color, { y: -0.03, sz: 0.68, seg: 12 });
  if (bottom.type === 'skirt' || top.type === 'dress') gb.cyl(0.165, 0.25, top.type === 'dress' ? 0.5 : 0.36, top.type === 'dress' ? top.color : bottom.color, { y: top.type === 'dress' ? -0.24 : -0.18, sz: 0.8, seg: 14 });
  if (top.type === 'coat') gb.cyl(0.175, 0.2, 0.46, top.color, { y: -0.2, sz: 0.72, seg: 12 });
  mk(gb, pelvis);

  // --- nogi ---
  const legs = [];
  for (const sd of [-1, 1]) {
    const hip = grp(pelvis, sd * 0.085, -0.04, 0);
    gb = new GB();
    gb.cyl(0.09, 0.07, 0.43, bottom.type === 'shorts' ? bottom.color : (legSkin ? skin : bottom.color), { y: -0.215, seg: 10 });
    if (bottom.type === 'shorts') gb.cyl(0.066, 0.06, 0.16, skin, { y: -0.36, seg: 10 });
    mk(gb, hip);
    const knee = grp(hip, 0, -0.43, 0);
    gb = new GB();
    gb.cyl(0.064, 0.048, 0.42, legSkin ? skin : bottom.color, { y: -0.21, seg: 10 });
    gb.box(0.095, 0.075, 0.25, shoes, { y: -0.452, z: 0.045 });
    gb.box(0.1, 0.022, 0.26, '#101010', { y: -0.484, z: 0.045 });
    gb.sph(0.05, shoes, { y: -0.452, z: 0.16, sy: 0.75, ws: 8, hs: 6 });
    mk(gb, knee);
    legs.push({ hip, knee });
  }

  // --- tułów ---
  const spine = grp(pelvis, 0, 0.06, 0);
  gb = new GB();
  const tc = top.color;
  gb.cyl(female ? 0.175 : 0.195, 0.158, 0.5, tc, { y: 0.27, sz: 0.62, seg: 14 });
  gb.sph(0.074, sleeveC === skin ? tc : sleeveC, { x: -0.2, y: 0.47, ws: 10, hs: 8 });
  gb.sph(0.074, sleeveC === skin ? tc : sleeveC, { x: 0.2, y: 0.47, ws: 10, hs: 8 });
  gb.cyl(0.048, 0.052, 0.09, skin, { y: 0.555, seg: 10 });
  if (female) { gb.sph(0.068, tc, { x: -0.07, y: 0.37, z: 0.075, ws: 8, hs: 6 }); gb.sph(0.068, tc, { x: 0.07, y: 0.37, z: 0.075, ws: 8, hs: 6 }); }
  gb.cyl(0.159, 0.159, 0.035, '#18181a', { y: 0.035, sz: 0.64, seg: 12 });
  if (top.type === 'jacket' || top.type === 'suit' || top.type === 'coat') {
    gb.box(0.085, 0.4, 0.012, top.color2, { y: 0.29, z: 0.117 });
    gb.box(0.05, 0.3, 0.014, tc, { x: -0.065, y: 0.34, z: 0.121, rz: 0.12 }); gb.box(0.05, 0.3, 0.014, tc, { x: 0.065, y: 0.34, z: 0.121, rz: -0.12 });
    if (top.type === 'suit') gb.box(0.032, 0.26, 0.014, o.tie || '#7a1f1f', { y: 0.33, z: 0.125 });
  }
  if (top.type === 'hoodie') { gb.sph(0.105, tc, { y: 0.5, z: -0.085, sy: 0.75, ws: 10, hs: 8 }); gb.box(0.2, 0.09, 0.012, tc, { y: 0.14, z: 0.112 }); gb.cyl(0.006, 0.006, 0.12, '#ddd', { x: -0.03, y: 0.44, z: 0.118, seg: 5 }); gb.cyl(0.006, 0.006, 0.12, '#ddd', { x: 0.03, y: 0.44, z: 0.118, seg: 5 }); }
  if (top.type === 'shirt') { gb.box(0.012, 0.42, 0.01, '#d8d8d8', { y: 0.29, z: 0.118 }); gb.box(0.1, 0.035, 0.03, tc, { y: 0.52, z: 0.085 }); }
  if (top.type === 'uniform') {
    gb.cyl(0.203, 0.168, 0.36, '#16243f', { y: 0.3, sz: 0.66, seg: 14 });
    gb.box(0.3, 0.05, 0.012, '#d7dde6', { y: 0.34, z: 0.128 }); gb.box(0.3, 0.05, 0.012, '#d7dde6', { y: 0.34, z: -0.128 });
    gb.box(0.05, 0.05, 0.014, '#f2c21a', { x: -0.1, y: 0.42, z: 0.13 });
    gb.box(0.06, 0.09, 0.04, '#0b0b0d', { x: 0.14, y: 0.45, z: 0.1 });
    gb.box(0.08, 0.1, 0.05, '#0b0b0d', { x: 0.17, y: 0.0, z: 0.0 });
  }
  if (o.chain) gb.cyl(0.07, 0.07, 0.012, '#e3b93a', { y: 0.47, z: 0.07, rx: 0.9, seg: 12, sz: 1 });
  if (o.bag) { gb.box(0.26, 0.3, 0.12, o.bag, { y: 0.3, z: -0.17 }); gb.box(0.03, 0.4, 0.02, o.bag, { x: -0.12, y: 0.34, z: 0.1 }); gb.box(0.03, 0.4, 0.02, o.bag, { x: 0.12, y: 0.34, z: 0.1 }); }
  mk(gb, spine);

  // --- ręce ---
  const arms = [];
  for (const sd of [-1, 1]) {
    const sh = grp(spine, sd * 0.225, 0.47, 0); sh.rotation.z = sd * 0.05;
    gb = new GB();
    gb.cyl(0.056, 0.047, 0.29, sleeveC, { y: -0.145, seg: 9 });
    mk(gb, sh);
    const el = grp(sh, 0, -0.29, 0);
    gb = new GB();
    gb.cyl(0.045, 0.038, 0.26, longSleeve ? tc : skin, { y: -0.13, seg: 9 });
    gb.sph(0.046, skin, { y: -0.29, sy: 1.3, sx: 0.8, ws: 8, hs: 6 });
    if (o.watch && sd === -1) gb.cyl(0.037, 0.037, 0.02, '#c9a227', { y: -0.24, seg: 8 });
    mk(gb, el);
    arms.push({ sh, el, side: sd });
  }

  // --- głowa ---
  const head = grp(spine, 0, 0.6, 0);
  gb = new GB();
  gb.sph(0.112, skin, { y: 0.11, sy: 1.18, sz: 1.05, ws: 16, hs: 12 });
  gb.sph(0.026, skin, { x: -0.108, y: 0.105, sy: 1.3, sx: 0.5, ws: 6, hs: 5 }); gb.sph(0.026, skin, { x: 0.108, y: 0.105, sy: 1.3, sx: 0.5, ws: 6, hs: 5 });
  gb.sph(0.02, skin, { y: 0.095, z: 0.118, sy: 1.2, ws: 6, hs: 5 });
  const hy = 0.118;
  if (hair === 'short') gb.sph(0.119, hc, { y: hy, z: -0.014, sx: 1.03, sy: 1.2, sz: 1.08, tl: Math.PI * 0.5, ws: 14, hs: 8, rx: -0.4 });
  if (hair === 'buzz') gb.sph(0.115, hc, { y: hy - 0.004, z: -0.008, sx: 1.01, sy: 1.19, sz: 1.06, tl: Math.PI * 0.46, ws: 14, hs: 8, rx: -0.4 });
  if (hair === 'long' || hair === 'bob' || hair === 'ponytail') {
    gb.sph(0.121, hc, { y: hy, z: -0.014, sx: 1.04, sy: 1.2, sz: 1.09, tl: Math.PI * 0.5, ws: 14, hs: 8, rx: -0.4 });
    if (hair !== 'ponytail') gb.add(new THREE.SphereGeometry(0.125, 12, 8, Math.PI * 0.95, Math.PI * 1.1, Math.PI * 0.3, Math.PI * (hair === 'long' ? 0.62 : 0.42)), hc, { y: hy - 0.01, z: -0.01, sx: 1.04, sy: hair === 'long' ? 1.75 : 1.3, sz: 1.05 });
    else { gb.sph(0.045, hc, { y: 0.16, z: -0.135, ws: 8, hs: 6 }); gb.cyl(0.03, 0.012, 0.2, hc, { y: 0.07, z: -0.15, rx: -0.25, seg: 7 }); }
  }
  if (o.beard) gb.add(new THREE.SphereGeometry(0.114, 12, 8, 0, Math.PI * 2, Math.PI * 0.66, Math.PI * 0.34), o.beard === true ? hc : o.beard, { y: 0.108, z: 0.008, sx: 0.97, sy: 1.17, sz: 1.04 });
  if (o.glasses) { gb.box(0.07, 0.04, 0.008, '#15151a', { x: -0.045, y: 0.118, z: 0.114 }); gb.box(0.07, 0.04, 0.008, '#15151a', { x: 0.045, y: 0.118, z: 0.114 }); gb.box(0.03, 0.008, 0.008, '#15151a', { y: 0.125, z: 0.114 }); }
  if (o.hat === 'cap') { gb.cyl(0.118, 0.122, 0.07, o.hatColor || '#20242b', { y: 0.2, seg: 14 }); gb.box(0.17, 0.014, 0.13, o.hatColor || '#20242b', { y: 0.175, z: 0.14 }); }
  if (o.hat === 'beanie') gb.sph(0.124, o.hatColor || '#7a1f1f', { y: 0.135, sy: 1.25, sx: 1.03, sz: 1.06, tl: Math.PI * 0.48, ws: 14, hs: 8, rx: -0.3 });
  if (o.hat === 'hood') gb.add(new THREE.SphereGeometry(0.14, 14, 10, Math.PI * 0.72, Math.PI * 1.56, 0, Math.PI * 0.75), top.color, { y: 0.11, z: -0.012, sy: 1.22, sz: 1.1 });
  if (o.hat === 'police') {
    gb.cyl(0.126, 0.118, 0.06, '#101a33', { y: 0.2, seg: 16 }); gb.cyl(0.15, 0.135, 0.03, '#101a33', { y: 0.24, seg: 16 });
    gb.box(0.18, 0.012, 0.11, '#0a0a0c', { y: 0.178, z: 0.135, rx: 0.15 }); gb.box(0.04, 0.035, 0.012, '#e9c21a', { y: 0.215, z: 0.123 });
    gb.cyl(0.128, 0.128, 0.018, '#c8ced6', { y: 0.176, seg: 16 });
  }
  if (o.earpiece) { gb.sph(0.016, '#e8e8e8', { x: 0.118, y: 0.1, ws: 6, hs: 5 }); gb.cyl(0.004, 0.004, 0.09, '#e8e8e8', { x: 0.116, y: 0.05, z: -0.02, seg: 4 }); }
  mk(gb, head);
  const face = new THREE.Mesh(new THREE.PlaneGeometry(0.185, 0.0925), Models.faceMat(o.face || 'neutral'));
  face.position.set(0, 0.11, 0.1195); head.add(face);

  const p = { group: root, body, pelvis, spine, head, legs, arms, face, phase: Math.random() * 6.28, baseY: 0.96, scale: s, height, idleT: Math.random() * 10, pose: o.pose || null, blend: 0 };
  root.userData.person = p;
  return p;
};

/* animacja postaci. st: {speed, pose, dt, t, look (kąt głowy)} */
Models.animate = function (p, dt, speed, pose, t) {
  p.idleT += dt;
  const L = p.legs, A = p.arms;
  const moving = speed > 0.05;
  if (moving) p.phase += dt * (2.2 + speed * 1.55);
  const amp = moving ? Math.min(0.85, 0.22 + speed * 0.115) : 0;
  p.blend += ((moving ? 1 : 0) - p.blend) * Math.min(1, dt * 8);
  const b = p.blend, sn = Math.sin(p.phase), cs = Math.cos(p.phase);
  p.spine.rotation.z = 0;
  const run = speed > 4.6 ? 1 : 0;
  // nogi
  L[0].hip.rotation.x = -sn * amp * b; L[1].hip.rotation.x = sn * amp * b;
  L[0].knee.rotation.x = Math.max(0, -cs) * amp * 1.5 * b + 0.04; L[1].knee.rotation.x = Math.max(0, cs) * amp * 1.5 * b + 0.04;
  // tułów
  p.pelvis.position.y = p.baseY + Math.abs(cs) * 0.035 * amp * b - 0.012 * b;
  p.spine.rotation.y = sn * 0.1 * amp * b;
  p.spine.rotation.x = run * 0.14 * b + Math.sin(p.idleT * 1.4) * 0.008;
  p.head.rotation.y = -sn * 0.07 * amp * b;
  // ręce (domyślnie)
  let aL = sn * amp * 0.8 * b, aR = -sn * amp * 0.8 * b, eL = -(0.12 + run * 1.1 + Math.max(0, sn) * amp * 0.5) * b - 0.06, eR = -(0.12 + run * 1.1 + Math.max(0, -sn) * amp * 0.5) * b - 0.06;
  let zL = -0.07, zR = 0.07;
  if (pose === 'phone') { aR = -0.95; eR = -1.95; p.head.rotation.x = 0.28; }
  else if (pose === 'talk') { aR = -0.55 + Math.sin(p.idleT * 3.1) * 0.2; eR = -1.25 + Math.sin(p.idleT * 4.3) * 0.25; p.head.rotation.x = Math.sin(p.idleT * 2) * 0.04; }
  else if (pose === 'handsup') { aL = -2.9; aR = -2.9; eL = -0.25; eR = -0.25; }
  else if (pose === 'dance') {
    const d = (t || p.idleT) * 6.8 + p.phase;
    aL = -2.2 + Math.sin(d) * 0.55; aR = -2.2 - Math.sin(d) * 0.55; eL = -0.6 + Math.cos(d) * 0.3; eR = -0.6 - Math.cos(d) * 0.3;
    p.pelvis.position.y = p.baseY + Math.abs(Math.sin(d * 0.5)) * 0.07 - 0.03;
    p.spine.rotation.y = Math.sin(d * 0.5) * 0.25; p.spine.rotation.z = Math.sin(d * 0.5 + 1) * 0.07;
    L[0].knee.rotation.x = 0.15 + Math.abs(Math.sin(d * 0.5)) * 0.3; L[1].knee.rotation.x = 0.15 + Math.abs(Math.cos(d * 0.5)) * 0.3;
    L[0].hip.rotation.x = -0.1 - Math.abs(Math.sin(d * 0.5)) * 0.15; L[1].hip.rotation.x = -0.1 - Math.abs(Math.cos(d * 0.5)) * 0.15;
    p.head.rotation.x = Math.sin(d) * 0.08;
  }
  else if (pose === 'arms') { aL = -0.32; aR = -0.32; eL = -0.75; eR = -0.75; zL = 0.3; zR = -0.3; }
  else if (pose === 'lean') { aL = 0.1; aR = 0.1; eL = -0.3; eR = -0.3; p.spine.rotation.x = -0.08; }
  else if (pose === 'sit') {
    L[0].hip.rotation.x = -1.5; L[1].hip.rotation.x = -1.5; L[0].knee.rotation.x = 1.5; L[1].knee.rotation.x = 1.5;
    p.pelvis.position.y = 0.56; aL = -0.5; aR = -0.5; eL = -0.9; eR = -0.9;
  }
  else if (pose === 'smoke') { aR = -0.7 + Math.max(0, Math.sin(p.idleT * 0.7)) * -0.5; eR = -1.6 - Math.max(0, Math.sin(p.idleT * 0.7)) * 0.5; }
  else { p.head.rotation.x += (0 - p.head.rotation.x) * Math.min(1, dt * 5); }
  A[0].sh.rotation.x = aL; A[1].sh.rotation.x = aR; A[0].el.rotation.x = eL; A[1].el.rotation.x = eR;
  A[0].sh.rotation.z = zL; A[1].sh.rotation.z = zR;
};

/* ---------- SAMOCHODY ---------- */
const CAR_TYPES = {
  sedan: { L: 4.5, W: 1.82, wb: 2.7, wr: 0.33, belt: 0.92, roof: 1.42, body: [[-2.25, 0.3], [-2.25, 0.7], [-2.15, 0.9], [-1.3, 0.94], [1.0, 0.94], [2.0, 0.86], [2.23, 0.7], [2.25, 0.3]], cab: [[-1.4, 0.92], [-0.78, 1.4], [0.32, 1.42], [1.08, 0.92]], pillar: -0.18 },
  hatch: { L: 4.0, W: 1.76, wb: 2.5, wr: 0.32, belt: 0.94, roof: 1.48, body: [[-2.0, 0.3], [-2.0, 0.8], [-1.9, 0.96], [0.85, 0.96], [1.75, 0.88], [1.98, 0.7], [2.0, 0.3]], cab: [[-1.92, 0.94], [-1.62, 1.46], [0.2, 1.48], [0.95, 0.94]], pillar: -0.45 },
  suv:   { L: 4.7, W: 1.92, wb: 2.8, wr: 0.38, belt: 1.08, roof: 1.74, body: [[-2.35, 0.38], [-2.35, 0.95], [-2.28, 1.1], [1.1, 1.1], [2.1, 1.02], [2.33, 0.82], [2.35, 0.38]], cab: [[-2.25, 1.08], [-2.0, 1.72], [0.4, 1.74], [1.2, 1.08]], pillar: -0.5 },
  van:   { L: 5.1, W: 1.98, wb: 3.1, wr: 0.36, belt: 1.12, roof: 2.05, body: [[-2.55, 0.36], [-2.55, 1.05], [-2.5, 1.14], [1.75, 1.14], [2.35, 1.0], [2.53, 0.8], [2.55, 0.36]], cab: [[-2.5, 1.12], [-2.46, 2.03], [1.2, 2.05], [1.95, 1.12]], pillar: 0.55, panel: true },
};
function roundedShape(pts, r) {
  const sh = new THREE.Shape(), n = pts.length;
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n];
    const v1 = [p0[0] - p1[0], p0[1] - p1[1]], v2 = [p2[0] - p1[0], p2[1] - p1[1]];
    const l1 = Math.hypot(v1[0], v1[1]), l2 = Math.hypot(v2[0], v2[1]), rr2 = Math.min(r, l1 * 0.45, l2 * 0.45);
    const a = [p1[0] + v1[0] / l1 * rr2, p1[1] + v1[1] / l1 * rr2], b = [p1[0] + v2[0] / l2 * rr2, p1[1] + v2[1] / l2 * rr2];
    if (i === 0) sh.moveTo(a[0], a[1]); else sh.lineTo(a[0], a[1]);
    sh.quadraticCurveTo(p1[0], p1[1], b[0], b[1]);
  }
  sh.closePath(); return sh;
}
Models.carGeo = function (type) {
  if (Models.cache['car_' + type]) return Models.cache['car_' + type];
  const T = CAR_TYPES[type], W = T.W;
  const ext = (pts, depth, r, bev) => {
    const g = new THREE.ExtrudeGeometry(roundedShape(pts, r), { depth: depth - bev * 2, bevelEnabled: true, bevelThickness: bev, bevelSize: bev, bevelSegments: 2, curveSegments: 6 });
    g.translate(0, 0, -(depth - bev * 2) / 2); return g;
  };
  // karoseria (dół + kabina)
  const bodyGB = new GB();
  bodyGB.add(ext(T.body, W, 0.12, 0.07), '#ffffff');
  const cabW = W - 0.22;
  bodyGB.add(ext(T.cab, cabW, 0.1, 0.05), '#ffffff');
  const body = bodyGB.build(); body.rotateY(-Math.PI / 2);
  // szyby
  const glass = new GB(), c = T.cab, zc = cabW / 2 + 0.006;
  const inset = (pts, k) => { const cx = pts.reduce((a, p) => a + p[0], 0) / pts.length, cy = pts.reduce((a, p) => a + p[1], 0) / pts.length; return pts.map(p => [cx + (p[0] - cx) * k, cy + (p[1] - cy) * k + 0.02]); };
  if (!T.panel) {
    const rear = inset([[c[0][0] + 0.12, c[0][1] + 0.06], [c[1][0] + 0.06, c[1][1] - 0.05], [T.pillar - 0.05, c[1][1] - 0.05 + (c[2][1] - c[1][1]) * 0.5], [T.pillar - 0.05, c[0][1] + 0.06]], 0.94);
    for (const sd of [-1, 1]) glass.add(new THREE.ShapeGeometry(roundedShape(rear, 0.04)), '#ffffff', { z: sd * zc });
  }
  const front = inset([[T.pillar + 0.05, c[3][1] + 0.06], [T.pillar + 0.05, c[2][1] - 0.05], [c[2][0] - 0.02, c[2][1] - 0.05], [c[3][0] - 0.16, c[3][1] + 0.06]], 0.94);
  for (const sd of [-1, 1]) glass.add(new THREE.ShapeGeometry(roundedShape(front, 0.04)), '#ffffff', { z: sd * zc });
  const slope = (a, b2, w) => {
    const dx = b2[0] - a[0], dy = b2[1] - a[1], len = Math.hypot(dx, dy), ang = Math.atan2(dy, dx);
    const nx = -dy / len, ny = dx / len, sgn = (nx * (a[0] > 0 ? 1 : -1)) > 0 ? 1 : -1;
    const g = new THREE.PlaneGeometry(len * 0.82, w); g.rotateX(-Math.PI / 2);
    glass.add(g, '#ffffff', { x: (a[0] + b2[0]) / 2 + nx * sgn * 0.078, y: (a[1] + b2[1]) / 2 + Math.abs(ny) * 0.078, rz: ang });
  };
  slope(c[3], c[2], cabW - 0.2);                // przednia
  if (!T.panel) slope(c[0], c[1], cabW - 0.24); // tylna
  const glassG = glass.build(); glassG.rotateY(-Math.PI / 2);
  // detale
  const d = new GB(), hw = W / 2;
  for (const wx of [-T.wb / 2, T.wb / 2]) for (const sd of [-1, 1]) {
    d.cyl(T.wr + 0.07, T.wr + 0.07, 0.03, '#0a0a0a', { x: wx, y: T.wr + 0.02, z: sd * (hw - 0.012), rx: Math.PI / 2, seg: 16 });
    d.cyl(T.wr, T.wr, 0.24, '#141414', { x: wx, y: T.wr, z: sd * (hw - 0.09), rx: Math.PI / 2, seg: 18 });
    d.cyl(T.wr * 0.62, T.wr * 0.62, 0.25, '#a9afb6', { x: wx, y: T.wr, z: sd * (hw - 0.088), rx: Math.PI / 2, seg: 12 });
    d.cyl(T.wr * 0.2, T.wr * 0.2, 0.26, '#2a2c30', { x: wx, y: T.wr, z: sd * (hw - 0.086), rx: Math.PI / 2, seg: 8 });
  }
  const fx = T.L / 2, bl = T.body, fy = bl[bl.length - 2][1], ry = bl[1][1];
  d.box(0.1, 0.16, W - 0.1, '#1b1c1f', { x: fx - 0.02, y: 0.38 }); d.box(0.1, 0.16, W - 0.1, '#1b1c1f', { x: -fx + 0.02, y: 0.38 });
  d.box(0.04, 0.12, W * 0.42, '#0d0d0f', { x: fx + 0.005, y: fy - 0.08 });
  d.box(0.02, 0.11, 0.48, '#f2f2f2', { x: fx + 0.03, y: 0.42 }); d.box(0.02, 0.11, 0.48, '#f2f2f2', { x: -fx - 0.03, y: 0.46 });
  for (const sd of [-1, 1]) {
    d.box(0.12, 0.09, 0.2, '#16171a', { x: c[3][0] - 0.05, y: T.belt + 0.07, z: sd * (hw + 0.07) });
    d.box(0.012, T.belt - 0.42, 0.012, '#0a0a0a', { x: T.pillar, y: (T.belt + 0.42) / 2, z: sd * (hw + 0.004) });
    d.box(0.012, T.belt - 0.42, 0.012, '#0a0a0a', { x: c[3][0] - 0.2, y: (T.belt + 0.42) / 2, z: sd * (hw + 0.004) });
    if (!T.panel) d.box(0.012, T.belt - 0.42, 0.012, '#0a0a0a', { x: c[0][0] + 0.5, y: (T.belt + 0.42) / 2, z: sd * (hw + 0.004) });
    d.box(0.14, 0.025, 0.02, '#c9ced4', { x: T.pillar - 0.3, y: T.belt - 0.1, z: sd * (hw + 0.008) });
    d.box(0.14, 0.025, 0.02, '#c9ced4', { x: T.pillar + 0.55, y: T.belt - 0.1, z: sd * (hw + 0.008) });
  }
  d.cyl(0.03, 0.03, 0.2, '#555', { x: -fx - 0.02, y: 0.3, z: -hw + 0.4, rz: Math.PI / 2, seg: 8 });
  const det = d.build(); det.rotateY(-Math.PI / 2);
  // światła
  const l = new GB();
  for (const sd of [-1, 1]) {
    l.box(0.1, 0.15, 0.4, '#fff6dc', { x: fx + 0.01, y: fy - 0.06, z: sd * (hw - 0.32) });
    l.box(0.1, 0.14, 0.38, '#ff1a10', { x: -fx - 0.01, y: ry + 0.02, z: sd * (hw - 0.3) });
  }
  const lg = l.build(); lg.rotateY(-Math.PI / 2);
  return (Models.cache['car_' + type] = { body, glass: glassG, det, lights: lg, T });
};
Models.carLightMat = function () {
  if (!Models.lightMats.car) Models.lightMats.car = new THREE.MeshBasicMaterial({ vertexColors: true, color: new THREE.Color(0.6, 0.6, 0.6) });
  return Models.lightMats.car;
};
Models.car = function (type, color, o) {
  o = o || {};
  const G0 = Models.carGeo(type), g = new THREE.Group();
  const body = new THREE.Mesh(G0.body, GFX.mat(color, { rough: 0.32, metal: 0.55, env: 1.3 })); body.castShadow = true; body.receiveShadow = true; g.add(body);
  const glass = new THREE.Mesh(G0.glass, GFX.mat('#0c1218', { rough: 0.08, metal: 0.9, env: 1.6, side: THREE.DoubleSide, key: 'carglass' })); g.add(glass);
  const det = new THREE.Mesh(G0.det, GFX.mat('#ffffff', { vc: true, rough: 0.6, metal: 0.2, key: 'cardet' })); det.castShadow = true; g.add(det);
  const li = new THREE.Mesh(G0.lights, Models.carLightMat()); g.add(li);
  g.userData.car = { type, T: G0.T };
  if (o.police) {
    const T = G0.T, gb = new GB();
    for (const sd of [-1, 1]) gb.box(0.02, 0.2, T.L * 0.78, '#1d3fa8', { x: sd * (T.W / 2 + 0.012), y: 0.68 });
    gb.box(1.0, 0.05, 0.3, '#22252b', { y: T.roof + 0.03, z: -0.15 });
    const m = GFX.meshFromGB(gb, { rough: 0.5 }); g.add(m);
    const mkL = (x, col) => { const b = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.11, 0.24), new THREE.MeshBasicMaterial({ color: col })); b.position.set(x, T.roof + 0.11, -0.15); g.add(b); return b; };
    g.userData.siren = [mkL(-0.26, new THREE.Color(4, 0.1, 0.1)), mkL(0.26, new THREE.Color(0.1, 0.3, 5))];
    const tx = Models.labelTex('POLICJA', '#ffffff', 'bold 90px sans-serif');
    for (const sd of [-1, 1]) { const pl = new THREE.Mesh(new THREE.PlaneGeometry(1.5, 0.3), new THREE.MeshBasicMaterial({ map: tx, transparent: true })); pl.position.set(sd * (T.W / 2 + 0.03), 0.68, 0.2); pl.rotation.y = sd * Math.PI / 2; g.add(pl); }
  }
  return g;
};
Models.labelTex = function (text, color, font) {
  const key = 'lt_' + text + color;
  if (Models.cache[key]) return Models.cache[key];
  const c = GFX.canvas(512, 96, (g, w, h) => { g.clearRect(0, 0, w, h); g.font = font || 'bold 64px sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = color; g.fillText(text, w / 2, h / 2 + 4); });
  return (Models.cache[key] = GFX.tex(c));
};

/* ---------- DRZEWA ---------- */
Models.treeGeo = function (kind, seed) {
  const key = 'tree_' + kind + seed;
  if (Models.cache[key]) return Models.cache[key];
  const r = mulberry(seed * 77 + 5), gb = new GB();
  const blob = (rad, x, y, z, c1, c2, sy) => {
    const g = new THREE.IcosahedronGeometry(rad, 2).toNonIndexed(), pa = g.attributes.position.array;
    const seen = {};
    for (let i = 0; i < pa.length; i += 3) {
      const k = Math.round(pa[i] * 50) + '_' + Math.round(pa[i + 1] * 50) + '_' + Math.round(pa[i + 2] * 50);
      if (seen[k] == null) seen[k] = 0.82 + r() * 0.36;
      pa[i] *= seen[k]; pa[i + 1] *= seen[k] * (sy || 0.9); pa[i + 2] *= seen[k];
    }
    g.computeVertexNormals();
    const col = lin(c1).lerp(lin(c2), r());
    const cc = new THREE.Color(); cc.copy(col); cc.convertLinearToSRGB();
    gb.add(g, cc, { x, y, z });
  };
  if (kind === 'pine') {
    gb.cyl(0.12, 0.2, 2.2, '#4a3524', { y: 1.1, seg: 7 });
    for (let k = 0; k < 5; k++) gb.cone(1.7 - k * 0.3, 1.5, k % 2 ? '#1f4a2c' : '#245533', { y: 2.0 + k * 0.9, seg: 9 });
  } else if (kind === 'birch') {
    gb.cyl(0.09, 0.14, 4.2, '#d9d6cc', { y: 2.1, seg: 7 });
    for (let k = 0; k < 5; k++) gb.box(0.2, 0.05, 0.02, '#2b2b2b', { y: 0.6 + k * 0.7, z: 0.12, ry: r() * 6 });
    for (let k = 0; k < 7; k++) blob(0.8 + r() * 0.5, (r() - 0.5) * 1.6, 3.6 + r() * 2.2, (r() - 0.5) * 1.6, '#6fa544', '#93bd58', 1.0);
  } else if (kind === 'bush') {
    for (let k = 0; k < 4; k++) blob(0.55 + r() * 0.3, (r() - 0.5) * 0.9, 0.45 + r() * 0.3, (r() - 0.5) * 0.9, '#2f6b33', '#4d8a3e', 0.8);
  } else {
    gb.cyl(0.2, 0.34, 2.6, '#4b3524', { y: 1.3, seg: 8 });
    gb.cyl(0.1, 0.17, 1.6, '#4b3524', { x: 0.45, y: 2.9, rz: -0.6, seg: 6 }); gb.cyl(0.09, 0.15, 1.5, '#4b3524', { x: -0.4, y: 2.8, z: 0.2, rz: 0.55, rx: 0.2, seg: 6 });
    const n = 8 + Math.floor(r() * 3);
    for (let k = 0; k < n; k++) { const a = r() * 6.28, d = r() * 1.5; blob(1.15 + r() * 0.7, Math.cos(a) * d, 3.6 + r() * 2.0, Math.sin(a) * d, '#2c6332', '#57913f', 0.85); }
  }
  return (Models.cache[key] = gb.build());
};
Models.tree = function (kind, s) {
  const m = new THREE.Mesh(Models.treeGeo(kind, (Math.random() * 3) | 0), GFX.mat('#ffffff', { vc: true, rough: 0.95, key: 'tree', env: 0.25 }));
  m.castShadow = true; m.receiveShadow = true; m.scale.setScalar(s || 1); m.rotation.y = Math.random() * 6.28;
  return m;
};

/* ---------- REKWIZYTY ---------- */
Models.prop = function (kind, o) {
  o = o || {};
  const key = 'prop_' + kind + (o.v || '');
  let geo = Models.cache[key], rough = 0.75, metal = 0.1;
  if (!geo) {
    const gb = new GB();
    if (kind === 'bench') {
      for (let k = 0; k < 4; k++) gb.box(2.0, 0.04, 0.1, '#7a5330', { y: 0.46, z: -0.18 + k * 0.12 });
      for (let k = 0; k < 3; k++) gb.box(2.0, 0.1, 0.035, '#7a5330', { y: 0.62 + k * 0.13, z: -0.27 - k * 0.03, rx: -0.2 });
      for (const x of [-0.85, 0.85]) { gb.box(0.06, 0.46, 0.06, '#1c1c1f', { x, y: 0.23, z: 0.14 }); gb.box(0.06, 0.95, 0.06, '#1c1c1f', { x, y: 0.47, z: -0.24, rx: -0.12 }); gb.box(0.06, 0.05, 0.5, '#1c1c1f', { x, y: 0.43, z: -0.05 }); }
    } else if (kind === 'bin') {
      gb.cyl(0.26, 0.22, 0.75, '#2f4f3a', { y: 0.43, seg: 14 }); gb.cyl(0.29, 0.29, 0.05, '#1e2f25', { y: 0.82, seg: 14 }); gb.cyl(0.05, 0.05, 0.9, '#222', { y: 0.45, z: -0.3, seg: 6 });
    } else if (kind === 'hydrant') {
      gb.cyl(0.1, 0.13, 0.55, '#b3261e', { y: 0.28, seg: 10 }); gb.sph(0.11, '#b3261e', { y: 0.58, ws: 8, hs: 6 }); gb.cyl(0.05, 0.05, 0.34, '#8f1d17', { y: 0.38, rz: Math.PI / 2, seg: 8 }); gb.cyl(0.16, 0.16, 0.04, '#8f1d17', { y: 0.04, seg: 10 });
    } else if (kind === 'bollard') {
      gb.cyl(0.07, 0.08, 0.8, '#3a3d42', { y: 0.4, seg: 8 }); gb.cyl(0.075, 0.075, 0.08, '#e3b93a', { y: 0.68, seg: 8 }); gb.sph(0.075, '#3a3d42', { y: 0.8, ws: 8, hs: 6 });
    } else if (kind === 'dumpster') {
      gb.box(2.0, 1.1, 1.1, '#2f5d3a', { y: 0.7 }); gb.box(2.06, 0.08, 1.16, '#1f3f27', { y: 1.28, rx: 0.08 }); for (const x of [-0.8, 0.8]) for (const z of [-0.45, 0.45]) gb.cyl(0.08, 0.08, 0.1, '#111', { x, y: 0.08, z, rz: Math.PI / 2, seg: 8 });
      gb.box(1.9, 0.04, 0.04, '#1f3f27', { y: 0.9, z: 0.57 });
    } else if (kind === 'barrel') {
      gb.cyl(0.32, 0.32, 0.95, '#6b2a22', { y: 0.48, seg: 14 }); for (const y of [0.2, 0.48, 0.76]) gb.cyl(0.335, 0.335, 0.04, '#4d1e18', { y, seg: 14 });
    } else if (kind === 'crate') {
      gb.box(1, 0.9, 1, '#8a6a3c', { y: 0.45 }); for (const s of [-1, 1]) { gb.box(1.04, 0.1, 0.06, '#6e5230', { y: 0.2, z: s * 0.5 }); gb.box(1.04, 0.1, 0.06, '#6e5230', { y: 0.7, z: s * 0.5 }); gb.box(0.06, 0.1, 1.04, '#6e5230', { y: 0.2, x: s * 0.5 }); gb.box(0.06, 0.1, 1.04, '#6e5230', { y: 0.7, x: s * 0.5 }); }
    } else if (kind === 'kiosk') {
      gb.box(2.6, 2.3, 2.0, '#2f6e5a', { y: 1.15 }); gb.box(2.9, 0.12, 2.4, '#1d473a', { y: 2.36 }); gb.box(2.0, 0.9, 0.05, '#10181c', { y: 1.5, z: 1.01 }); gb.box(2.2, 0.06, 0.4, '#c9ced4', { y: 1.02, z: 1.15 });
      for (let k = 0; k < 5; k++) gb.box(0.3, 0.4, 0.02, ['#c0392b', '#2980b9', '#f1c40f', '#27ae60', '#8e44ad'][k], { x: -0.8 + k * 0.4, y: 0.6, z: 1.02 });
    } else if (kind === 'trafficlight') {
      gb.cyl(0.07, 0.09, 3.4, '#2a2c30', { y: 1.7, seg: 8 }); gb.box(0.32, 0.9, 0.28, '#17181b', { y: 3.0, z: 0.05 }); gb.box(0.36, 0.06, 0.34, '#17181b', { y: 3.48, z: 0.07 });
    } else if (kind === 'planter') {
      gb.box(1.6, 0.5, 0.6, '#6b6e75', { y: 0.25 }); gb.box(1.44, 0.06, 0.44, '#3a2a1c', { y: 0.5 });
      const r = mulberry(7); for (let k = 0; k < 9; k++) gb.sph(0.14 + r() * 0.08, ['#3c8a3f', '#4c9a44', '#d6456b', '#e2b23a', '#3c8a3f'][k % 5], { x: -0.6 + k * 0.15, y: 0.6 + r() * 0.1, z: (r() - 0.5) * 0.25, ws: 6, hs: 5 });
    } else if (kind === 'sign') {
      gb.cyl(0.035, 0.035, 2.6, '#8a8f98', { y: 1.3, seg: 6 });
      if (o.v === 'stop') gb.cyl(0.32, 0.32, 0.03, '#c0392b', { y: 2.5, rx: Math.PI / 2, seg: 8 });
      else if (o.v === 'park') gb.box(0.5, 0.5, 0.03, '#1d4fa8', { y: 2.45 });
      else gb.add(new THREE.CylinderGeometry(0.36, 0.36, 0.03, 3), '#e3b93a', { y: 2.45, rx: Math.PI / 2, rz: Math.PI });
    } else if (kind === 'cone') {
      gb.cone(0.16, 0.55, '#e8641b', { y: 0.3, seg: 10 }); gb.box(0.38, 0.03, 0.38, '#e8641b', { y: 0.015 }); gb.cyl(0.105, 0.125, 0.1, '#f2f2f2', { y: 0.28, seg: 10 });
    } else if (kind === 'mailbox') {
      gb.box(0.45, 0.6, 0.35, '#c0392b', { y: 1.15 }); gb.cyl(0.05, 0.05, 0.9, '#2a2c30', { y: 0.45, seg: 6 }); gb.box(0.3, 0.03, 0.02, '#111', { y: 1.3, z: 0.18 });
    } else if (kind === 'acunit') {
      gb.box(1.2, 0.7, 0.8, '#b9bec4', { y: 0.35 }); gb.cyl(0.25, 0.25, 0.03, '#44484e', { y: 0.72, seg: 10 }); gb.box(1.22, 0.06, 0.82, '#8d9298', { y: 0.05 });
    } else if (kind === 'antenna') {
      gb.cyl(0.03, 0.03, 3.0, '#777', { y: 1.5, seg: 5 }); for (let k = 0; k < 4; k++) gb.box(0.9 - k * 0.15, 0.02, 0.02, '#888', { y: 1.8 + k * 0.3 });
    } else if (kind === 'dish') {
      gb.add(new THREE.SphereGeometry(0.45, 12, 6, 0, Math.PI * 2, 0, Math.PI * 0.32), '#d9dce0', { y: 0.5, z: -0.2, rx: -1.1 }); gb.cyl(0.03, 0.03, 0.5, '#666', { y: 0.25, seg: 5 });
    } else if (kind === 'watertank') {
      gb.cyl(0.9, 0.9, 1.5, '#7a5a3c', { y: 1.65, seg: 14 }); gb.cone(0.98, 0.5, '#4a4d52', { y: 2.65, seg: 14 }); for (const a of [0, 1.57, 3.14, 4.71]) gb.cyl(0.05, 0.05, 0.9, '#333', { x: Math.cos(a) * 0.65, y: 0.45, z: Math.sin(a) * 0.65, seg: 5 });
    } else if (kind === 'lamp') {
      gb.cyl(0.07, 0.11, 5.6, '#25272b', { y: 2.8, seg: 8 }); gb.cyl(0.14, 0.16, 0.5, '#1c1e21', { y: 0.25, seg: 8 });
      gb.cyl(0.045, 0.06, 1.5, '#25272b', { x: 0.6, y: 5.85, rz: -1.25, seg: 6 }); gb.box(0.7, 0.12, 0.3, '#1c1e21', { x: 1.35, y: 6.08 });
    }
    geo = Models.cache[key] = gb.build();
  }
  if (kind === 'hydrant' || kind === 'bollard' || kind === 'bin' || kind === 'dumpster' || kind === 'trafficlight' || kind === 'lamp' || kind === 'acunit') { rough = 0.5; metal = 0.45; }
  const m = new THREE.Mesh(geo, GFX.mat('#ffffff', { vc: true, rough, metal, key: 'prop' + rough }));
  m.castShadow = o.cast !== false; m.receiveShadow = true;
  return m;
};

/* etykieta nad głową */
Models.label = function (text, color, scale) {
  const c = GFX.canvas(512, 96, (g, w, h) => {
    g.font = 'bold 44px -apple-system, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.lineWidth = 8; g.strokeStyle = 'rgba(0,0,0,.85)'; g.strokeText(text, w / 2, h / 2);
    g.fillStyle = color || '#fff'; g.fillText(text, w / 2, h / 2);
  });
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: GFX.tex(c), transparent: true, depthTest: false, fog: false }));
  const k = scale || 1; s.scale.set(3.2 * k, 0.6 * k, 1); s.renderOrder = 10;
  return s;
};
