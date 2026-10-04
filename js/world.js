'use strict';
/* ============================================================
   ŚWIAT: scena, miasto, oświetlenie dzień/noc, pogoda, kolizje
   ============================================================ */

const W = {
  scene: null, camera: null, renderer: null, sun: null, hemi: null, amb: null, flash: null, roomLights: [],
  colliders: [], inter: [], loc: 'out',
  nightMats: [], stationViz: {}, clubTiles: [], clubLights: [], sirens: [], flickers: [],
  roadsZ: [-60, 0, 60], roadsX: [-60, 0, 60],
  lat: [-68, -52, -8, 8, 52, 68],
  rooms: {
    safe: { cx: 300, cz: 0, w: 24, d: 16, h: 3.3, exit: [300, 7.0], name: 'Mieszkanie' },
    shop: { cx: 400, cz: 0, w: 18, d: 12, h: 3.6, exit: [400, 5.0], name: 'Hurtownia' },
    club: { cx: 500, cz: 0, w: 28, d: 22, h: 5.0, exit: [500, 10.0], name: 'Klub Neon' },
    wash: { cx: 600, cz: 0, w: 12, d: 10, h: 3.2, exit: [600, 4.0], name: 'Myjnia Kryształ' },
  },
  doors: {}, zones: [], t: 0, nightF: 0, rain: 0, rainTarget: 0, wet: 0, tl: { phase: 0, ns: 'g', ew: 'r' },
};
const BLK = [[-120, -66], [-54, -6], [6, 54], [66, 120]];
function blk(i, j) { return { x0: BLK[i][0], x1: BLK[i][1], z0: BLK[j][0], z1: BLK[j][1], cx: (BLK[i][0] + BLK[i][1]) / 2, cz: (BLK[j][0] + BLK[j][1]) / 2 }; }
const RND = mulberry(20241004);
const mat = (c, o) => GFX.mat(c, o);
function addCol(x0, x1, z0, z1, h) { W.colliders.push({ x0, x1, z0, z1, h: h == null ? 4 : h }); }
function nearest(arr, v) { return arr.reduce((b, r) => Math.abs(r - v) < Math.abs(b - v) ? r : b, arr[0]); }

/* ---------- instancjonowanie powtarzalnych obiektów ---------- */
const Inst = {
  m: {},
  add(key, geo, material, x, y, z, ry, s, color, cast) {
    const e = this.m[key] || (this.m[key] = { geo, material, list: [], cast: cast !== false });
    e.list.push({ x, y, z, ry: ry || 0, s: s == null ? 1 : s, color });
  },
  addM(key, geo, material, matrix, color, cast) {
    const e = this.m[key] || (this.m[key] = { geo, material, list: [], cast: cast !== false });
    e.list.push({ matrix, color });
  },
  flush() {
    const d = new THREE.Object3D(), col = new THREE.Color();
    for (const key in this.m) {
      const e = this.m[key], im = new THREE.InstancedMesh(e.geo, e.material, e.list.length);
      e.list.forEach((it, i) => {
        if (it.matrix) im.setMatrixAt(i, it.matrix);
        else { d.position.set(it.x, it.y, it.z); d.rotation.set(0, it.ry, 0); if (typeof it.s === 'number') d.scale.setScalar(it.s); else d.scale.set(it.s[0], it.s[1], it.s[2]); d.updateMatrix(); im.setMatrixAt(i, d.matrix); }
        if (it.color) { im.setColorAt(i, col.copy(lin(it.color))); }
      });
      if (im.instanceColor) im.instanceColor.needsUpdate = true;
      im.castShadow = e.cast; im.receiveShadow = true; im.frustumCulled = false;
      W.scene.add(im); e.mesh = im;
    }
    this.m = {};
  },
};
function prop(kind, x, z, ry, o) {
  o = o || {};
  const p = Models.prop(kind, o);
  Inst.add('prop_' + kind + (o.v || ''), p.geometry, p.material, x, o.y != null ? o.y : W.groundY(x, z), z, ry || 0, o.s || 1, null, o.cast);
  if (o.col) addCol(x - o.col[0], x + o.col[0], z - o.col[1], z + o.col[1], o.col[2] || 1);
}
function tree(x, z, s, kind) {
  kind = kind || (RND() < 0.2 ? 'birch' : RND() < 0.25 ? 'pine' : 'oak');
  const v = (RND() * 3) | 0;
  Inst.add('tree_' + kind + v, Models.treeGeo(kind, v), mat('#ffffff', { vc: true, rough: 0.95, key: 'tree', env: 0.25 }), x, W.groundY(x, z), z, RND() * 6.28, s || 1);
  if (kind !== 'bush') addCol(x - 0.4, x + 0.4, z - 0.4, z + 0.4, 6);
}
const CARCOLS = ['#8a1c1c', '#1c3f8a', '#d9dcdf', '#15171a', '#b08a1e', '#1e6b3a', '#5a6068', '#5a2d8a', '#9aa3ab', '#6b1f2a', '#28424f'];
function carParked(x, z, ry, type, color, police) {
  type = type || pick(['sedan', 'sedan', 'hatch', 'hatch', 'suv', 'van']);
  const G0 = Models.carGeo(type), T = G0.T, y = 0.02;
  if (police) {
    const c = Models.car(type, '#e8ebee', { police: true }); c.position.set(x, y, z); c.rotation.y = ry; W.scene.add(c);
    if (c.userData.siren) W.sirens.push(c.userData.siren);
  } else {
    Inst.add('carbody_' + type, G0.body, mat('#ffffff', { rough: 0.32, metal: 0.55, env: 1.3, key: 'carbodyinst' }), x, y, z, ry, 1, color || pick(CARCOLS));
    Inst.add('carglass_' + type, G0.glass, mat('#0c1218', { rough: 0.08, metal: 0.9, env: 1.6, side: THREE.DoubleSide, key: 'carglass' }), x, y, z, ry, 1, null, false);
    Inst.add('cardet_' + type, G0.det, mat('#ffffff', { vc: true, rough: 0.6, metal: 0.2, key: 'cardet' }), x, y, z, ry, 1);
    Inst.add('carlight_' + type, G0.lights, W.parkedLightMat, x, y, z, ry, 1, null, false);
  }
  const along = Math.abs(Math.sin(ry)) > 0.5;          // forward = +Z obrócone o ry
  const hl = T.L / 2 + 0.1, hw = T.W / 2 + 0.1;
  addCol(x - (along ? hl : hw), x + (along ? hl : hw), z - (along ? hw : hl), z + (along ? hw : hl), 1.5);
}

/* box: y = dolna krawędź; używany do prostych brył (wnętrza, detale) */
function box(parent, w, h, d, color, x, y, z, col, o) {
  o = o || {};
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), o.material || mat(color, o));
  m.position.set(x, y + h / 2, z); m.castShadow = !o.noShadow; m.receiveShadow = true;
  if (o.ry) m.rotation.y = o.ry;
  (parent || W.scene).add(m);
  if (col) addCol(x - w / 2, x + w / 2, z - d / 2, z + d / 2, y + h);
  return m;
}
function scaleUV(geo, from, to, su, sv, ou, ov) {
  const uv = geo.attributes.uv;
  for (let i = from; i < to; i++) uv.setXY(i, uv.getX(i) * su + (ou || 0), uv.getY(i) * sv + (ov || 0));
}
function signPlane(text, w, h, bg, fg, font, glow, bright) {
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ map: TX.sign(text, bg, fg, font, glow), color: new THREE.Color(bright || 1.6, bright || 1.6, bright || 1.6) }));
  return m;
}

/* wysokość podłoża (krawężniki) */
W.groundY = function (x, z) {
  for (let i = 0; i < 4; i++) if (x >= BLK[i][0] && x <= BLK[i][1]) { for (let j = 0; j < 4; j++) if (z >= BLK[j][0] && z <= BLK[j][1]) return 0.14; return 0.02; }
  return 0.02;
};

/* ---------- inicjalizacja ---------- */
function initWorld(host) {
  GFX.init(host);
  W.renderer = GFX.renderer;
  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(0x8fb0d0, 40, 220);
  W.scene = scene;
  const cam = new THREE.PerspectiveCamera(70, window.innerWidth / window.innerHeight, 0.08, 900);
  cam.rotation.order = 'YXZ'; scene.add(cam); W.camera = cam;

  W.hemi = new THREE.HemisphereLight(0xbfd8ff, 0x4a4438, 0.6); scene.add(W.hemi);
  W.amb = new THREE.AmbientLight(0xffffff, 0.05); scene.add(W.amb);
  const sun = new THREE.DirectionalLight(0xfff1d6, 2.0);
  sun.castShadow = true;
  const sc = sun.shadow.camera; sc.left = -60; sc.right = 60; sc.top = 60; sc.bottom = -60; sc.near = 1; sc.far = 320;
  sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.04;
  scene.add(sun); scene.add(sun.target); W.sun = sun;
  for (let i = 0; i < 3; i++) { const l = new THREE.PointLight(0xffe0b0, 0, 30, 1.6); scene.add(l); W.roomLights.push(l); }
  const fl = new THREE.SpotLight(0xfff2d0, 0, 45, 0.5, 0.5, 1.3);
  cam.add(fl); fl.position.set(0.25, -0.15, 0); cam.add(fl.target); fl.target.position.set(0, 0, -5); W.flash = fl;

  GFX.attach(scene, cam, sun);

  // gwiazdy i księżyc
  const sp = [], rnd = mulberry(99);
  for (let i = 0; i < 900; i++) { const a = rnd() * Math.PI * 2, e = Math.acos(rnd()) * 0.98, R = 420; sp.push(Math.sin(e) * Math.cos(a) * R, Math.cos(e) * R, Math.sin(e) * Math.sin(a) * R); }
  const sg = new THREE.BufferGeometry(); sg.setAttribute('position', new THREE.Float32BufferAttribute(sp, 3));
  W.stars = new THREE.Points(sg, new THREE.PointsMaterial({ color: new THREE.Color(2, 2, 2.3), size: 1.5, sizeAttenuation: false, transparent: true, opacity: 0, fog: false, depthWrite: false }));
  W.stars.frustumCulled = false; scene.add(W.stars);
  W.moon = new THREE.Mesh(new THREE.SphereGeometry(13, 20, 14), new THREE.MeshBasicMaterial({ color: new THREE.Color(2.2, 2.3, 2.6), fog: false }));
  scene.add(W.moon);

  W.parkedLightMat = new THREE.MeshBasicMaterial({ vertexColors: true, color: new THREE.Color(0.35, 0.35, 0.35) });
  W.poolMat = new THREE.MeshBasicMaterial({ map: TX.glow(), transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false, fog: false });
  W.lampHeadMat = new THREE.MeshBasicMaterial({ color: 0x333333 });

  buildCity();
  buildInteriors();
  Inst.flush();
  buildRain();
  for (const id in W.rooms) W.rooms[id].group.visible = false;
}

/* ============================================================
   FASADY / BUDYNKI
   ============================================================ */
const FSTY = {
  blokA: { style: 'blok', pal: { wall: '#c9c4b6', accent: '#d98c4a', frame: '#e9ecef', trim: '#aeb1b5' }, seed: 1 },
  blokB: { style: 'blok', pal: { wall: '#b9c2c9', accent: '#5f93b8', frame: '#e9ecef', trim: '#a9adb2' }, seed: 2 },
  blokC: { style: 'blok', pal: { wall: '#d3cdb4', accent: '#7fae6b', frame: '#e9ecef', trim: '#b3b5b0' }, seed: 3 },
  blokD: { style: 'blok', pal: { wall: '#c7bfc6', accent: '#c96d7a', frame: '#e9ecef', trim: '#aeaab0' }, seed: 4 },
  kamA: { style: 'kamienica', pal: { wall: '#b89a6e', accent: '#b89a6e', frame: '#4a3524', trim: '#d9cbb0' }, seed: 5 },
  kamB: { style: 'kamienica', pal: { wall: '#8f9a8c', accent: '#8f9a8c', frame: '#2f2a25', trim: '#cfd3c6' }, seed: 6 },
  kamC: { style: 'kamienica', pal: { wall: '#a67c68', accent: '#a67c68', frame: '#3a2a22', trim: '#dccabd' }, seed: 7 },
  modern: { style: 'modern', pal: { wall: '#3d4852', accent: '#3d4852', frame: '#1a2026', trim: '#2a3138' }, seed: 8, rough: 0.2, metal: 0.55, env: 1.5 },
  brick: { style: 'brick', pal: { wall: '#8a4f3a', accent: '#8a4f3a', frame: '#2b2b2b', trim: '#b8a48a' }, seed: 9 },
  brickDark: { style: 'brick', pal: { wall: '#4d3c38', accent: '#4d3c38', frame: '#1b1b1b', trim: '#8a7f73' }, seed: 10 },
  club: { style: 'dark', pal: { wall: '#1b1526', accent: '#1b1526', frame: '#111111', trim: '#15101c' }, seed: 11, rough: 0.6 },
};
const facMats = {};
function facMat(key) {
  if (facMats[key]) return facMats[key];
  const S = FSTY[key], t = TX.facade(S.style, S.pal, S.seed);
  const m = mat('#ffffff', { map: t.map, emissive: '#ffffff', emissiveMap: t.emi, ei: 0, bump: t.bump, bumpScale: S.style === 'modern' ? 0.02 : 0.08, rough: S.rough != null ? S.rough : 0.9, metal: S.metal || 0, env: S.env || 0.6, key: 'fac' + key });
  W.nightMats.push({ m, k: S.style === 'dark' ? 3.0 : 1.7 });
  return (facMats[key] = m);
}
const SHOPS = [['SPOŻYWCZY', '#2e8b57'], ['KEBAB U ALIEGO', '#c0392b'], ['APTEKA', '#27ae60'], ['FRYZJER', '#8e44ad'], ['LOMBARD', '#d4a017'], ['MONOPOLOWY 24H', '#e67e22'], ['PIEKARNIA', '#b9770e'], ['KWIACIARNIA', '#e84393'], ['SERWIS GSM', '#2980b9'], ['PIZZERIA ROMA', '#c0392b'], ['SECOND HAND', '#16a085'], ['PRALNIA', '#3498db'], ['KANTOR', '#f1c40f'], ['BAR MLECZNY', '#d35400']];
const shopMats = {};
function shopMat(i) {
  if (shopMats[i]) return shopMats[i];
  const s = SHOPS[i], t = TX.shop(s[0], s[1], i + 1);
  const m = mat('#ffffff', { map: t.map, emissive: '#ffffff', emissiveMap: t.emi, ei: 0, rough: 0.35, metal: 0.2, env: 1.2, key: 'shop' + i });
  W.nightMats.push({ m, k: 2.6, day: 0.25 });
  return (shopMats[i] = m);
}
let balconyGeo = null;
function getBalconyGeo() {
  if (balconyGeo) return balconyGeo;
  const gb = new GB();
  gb.box(3.5, 0.12, 1.1, '#b9bcc0', { y: 0.06, z: 0.55 });
  gb.box(3.5, 0.95, 0.05, '#ffffff', { y: 0.6, z: 1.08 });
  gb.box(0.05, 0.95, 1.1, '#ffffff', { x: -1.73, y: 0.6, z: 0.55 }); gb.box(0.05, 0.95, 1.1, '#ffffff', { x: 1.73, y: 0.6, z: 0.55 });
  gb.box(3.56, 0.05, 0.08, '#55585d', { y: 1.09, z: 1.08 });
  return (balconyGeo = gb.build());
}

/* budynek: środek (x,z), wymiary w,d,h; styl; o: {shops:[faces], door:face, noBalcony, roofCol} */
function building(x, z, w, d, h, key, o) {
  o = o || {};
  const S = FSTY[key], y0 = 0.14;
  const geo = new THREE.BoxGeometry(w, h, d);
  const ko = Math.floor(RND() * 4), vo = Math.floor(RND() * 4);
  scaleUV(geo, 0, 8, d / 16, h / 12, ko * 0.25, vo * 0.25);
  scaleUV(geo, 16, 24, w / 16, h / 12, ko * 0.25, vo * 0.25);
  scaleUV(geo, 8, 16, w / 8, d / 8);
  const fm = facMat(key), roof = mat('#ffffff', { map: TX.roof().map, rough: 0.95, key: 'roof' });
  const m = new THREE.Mesh(geo, [fm, fm, roof, roof, fm, fm]);
  m.position.set(x, y0 + h / 2, z); m.castShadow = true; m.receiveShadow = true; W.scene.add(m);
  addCol(x - w / 2, x + w / 2, z - d / 2, z + d / 2, h);

  // detale scalone: cokół, attyka, gzyms
  const gb = new GB(), top = y0 + h, tc = S.pal.trim;
  gb.box(w + 0.16, 0.7, d + 0.16, shadeHex(S.pal.wall, 0.55), { x, y: y0 + 0.35, z });
  for (const s of [-1, 1]) {
    gb.box(w + 0.3, 0.7, 0.3, shadeHex(tc, 0.8), { x, y: top + 0.35, z: z + s * (d / 2 - 0.05) });
    gb.box(0.3, 0.7, d + 0.3, shadeHex(tc, 0.8), { x: x + s * (w / 2 - 0.05), y: top + 0.35, z });
  }
  if (S.style === 'kamienica') { gb.box(w + 0.7, 0.35, d + 0.7, tc, { x, y: top - 0.25, z }); gb.box(w + 0.4, 0.25, d + 0.4, tc, { x, y: y0 + 3.0, z }); }
  if (S.style === 'modern') gb.box(w + 0.1, 0.25, d + 0.1, '#1d2228', { x, y: y0 + 3.2, z });
  // klatka schodowa / maszynownia na dachu
  gb.box(3.2, 2.2, 3.2, shadeHex(S.pal.wall, 0.8), { x: x + (RND() - 0.5) * (w - 6), y: top + 1.1, z: z + (RND() - 0.5) * (d - 6) });
  const dm = GFX.meshFromGB(gb, { rough: 0.9 }); W.scene.add(dm);
  // rekwizyty na dachu
  const nprops = 2 + Math.floor(RND() * 3);
  for (let i = 0; i < nprops; i++) {
    const kind = pick(['acunit', 'acunit', 'antenna', 'dish', 'watertank']);
    if (kind === 'watertank' && (S.style !== 'kamienica' || RND() < 0.6)) continue;
    const p = Models.prop(kind);
    Inst.add('prop_' + kind, p.geometry, p.material, x + (RND() - 0.5) * (w - 4), top, z + (RND() - 0.5) * (d - 4), RND() * 6.28, 1);
  }
  // balkony 3D (bloki)
  if (S.style === 'blok' && !o.noBalcony) {
    const bg = getBalconyGeo(), bm = mat('#ffffff', { vc: true, rough: 0.85, key: 'balcony' });
    const M = new THREE.Matrix4(), q = new THREE.Quaternion(), sc = new THREE.Vector3(1, 1, 1), pos = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
    const faces = [['pz', w, 0], ['nz', w, Math.PI], ['px', d, Math.PI / 2], ['nx', d, -Math.PI / 2]];
    for (const [f, len, ry] of faces) {
      const n = Math.round(len / 4);
      for (let i = 0; i < n; i++) {
        if ((i + ko) % 2 !== 1) continue;
        const t = -len / 2 + (i + 0.5) * 4;
        for (let fl = 1; fl < Math.round(h / 3); fl++) {
          if (f === 'pz') pos.set(x + t, y0 + fl * 3 + 0.3, z + d / 2);
          else if (f === 'nz') pos.set(x - t, y0 + fl * 3 + 0.3, z - d / 2);
          else if (f === 'px') pos.set(x + w / 2, y0 + fl * 3 + 0.3, z - t);
          else pos.set(x - w / 2, y0 + fl * 3 + 0.3, z + t);
          q.setFromAxisAngle(up, ry); M.compose(pos, q, sc);
          Inst.addM('balcony', bg, bm, M.clone(), RND() < 0.5 ? shadeHex(S.pal.accent, 0.85) : '#9a9da2');
        }
      }
    }
  }
  // witryny
  if (o.shops) for (const f of o.shops) {
    const len = (f === 'n' || f === 's') ? w : d, n = Math.floor(len / 8);
    for (let i = 0; i < n; i++) {
      if (RND() < 0.25) continue;
      const t = -len / 2 + (len - n * 8) / 2 + i * 8 + 4;
      const pl = new THREE.Mesh(new THREE.PlaneGeometry(7.6, 3.0), shopMat(Math.floor(RND() * SHOPS.length)));
      if (f === 's') { pl.position.set(x + t, y0 + 1.5, z + d / 2 + 0.07); }
      else if (f === 'n') { pl.position.set(x - t, y0 + 1.5, z - d / 2 - 0.07); pl.rotation.y = Math.PI; }
      else if (f === 'e') { pl.position.set(x + w / 2 + 0.07, y0 + 1.5, z - t); pl.rotation.y = Math.PI / 2; }
      else { pl.position.set(x - w / 2 - 0.07, y0 + 1.5, z + t); pl.rotation.y = -Math.PI / 2; }
      pl.receiveShadow = true; W.scene.add(pl);
    }
  }
  return m;
}
function shadeHex(h, k) { const c = hex2rgb(h); return '#' + [0, 1, 2].map(i => Math.round(clamp(c[i] * k, 0, 255)).toString(16).padStart(2, '0')).join(''); }

/* drzwi budynku interaktywnego */
function door(id, x, z, title, color, signW, rotY) {
  const nz = rotY === 0 ? 1 : -1, y0 = 0.14;
  const gb = new GB();
  gb.box(3.4, 3.5, 0.5, '#15161a', { x, y: y0 + 1.75, z: z + nz * 0.12 });
  gb.box(4.4, 0.18, 1.8, '#2a2c31', { x, y: y0 + 3.65, z: z + nz * 0.9 });
  gb.box(3.8, 0.12, 1.2, '#6e7178', { x, y: 0.2, z: z + nz * 0.8 });
  gb.box(1.25, 2.9, 0.12, '#3a2c20', { x: x - 0.66, y: y0 + 1.5, z: z + nz * 0.4 }); gb.box(1.25, 2.9, 0.12, '#3a2c20', { x: x + 0.66, y: y0 + 1.5, z: z + nz * 0.4 });
  gb.box(0.06, 0.5, 0.1, '#c9ced4', { x: x - 0.1, y: y0 + 1.45, z: z + nz * 0.48 }); gb.box(0.06, 0.5, 0.1, '#c9ced4', { x: x + 0.1, y: y0 + 1.45, z: z + nz * 0.48 });
  W.scene.add(GFX.meshFromGB(gb, { rough: 0.6, metal: 0.2 }));
  const glow = new THREE.Mesh(new THREE.BoxGeometry(2.3, 0.5, 0.06), GFX.basic(color)); glow.material.color.multiplyScalar(2.2);
  glow.position.set(x, y0 + 3.2, z + nz * 0.42); W.scene.add(glow);
  const sg = signPlane(title, signW, signW * 0.19, '#0c0c12', color, 'bold 62px sans-serif', true, 2.0);
  sg.position.set(x, y0 + 4.75, z + nz * 0.08); sg.rotation.y = rotY; W.scene.add(sg);
  const strip = new THREE.Mesh(new THREE.BoxGeometry(4.2, 0.06, 0.06), GFX.basic(color)); strip.material.color.multiplyScalar(2.5);
  strip.position.set(x, y0 + 3.55, z + nz * 1.78); W.scene.add(strip);
  W.doors[id] = { x, z: z + nz * 1.9, rotY };
  W.inter.push({ loc: 'out', x, z: z + nz * 1.9, range: 3.2, door: id, label: () => 'Wejdź: ' + title, enabled: () => true, act: () => G.enter(id) });
}

/* ============================================================
   MIASTO
   ============================================================ */
function buildCity() {
  const sc = W.scene, A = TX.asphalt(), R = TX.road(), P = TX.paving(), GR = TX.grass();
  // podłoże poza miastem
  const gnd = new THREE.Mesh(new THREE.PlaneGeometry(900, 900), mat('#ffffff', { map: GR.map, rough: 1, key: 'outer', env: 0.2 }));
  scaleUV(gnd.geometry, 0, 4, 150, 150);
  gnd.rotation.x = -Math.PI / 2; gnd.position.y = -0.03; gnd.receiveShadow = true; sc.add(gnd);

  // drogi
  W.roadMat = mat('#ffffff', { map: R.map, bump: R.bump, bumpScale: 0.015, rough: 0.92, key: 'road', env: 0.5 });
  const mkRoad = (len, vertical, x, z, y) => {
    const g = new THREE.PlaneGeometry(len, 12); scaleUV(g, 0, 4, len / 16, 1);
    const m = new THREE.Mesh(g, W.roadMat); m.rotation.x = -Math.PI / 2; if (vertical) m.rotation.z = Math.PI / 2;
    m.position.set(x, y, z); m.receiveShadow = true; sc.add(m);
  };
  for (const z of W.roadsZ) mkRoad(250, false, 0, z, 0.02);
  for (const x of W.roadsX) mkRoad(250, true, x, 0, 0.025);
  W.asphMat = mat('#ffffff', { map: A.map, bump: A.bump, bumpScale: 0.015, rough: 0.92, key: 'asph', env: 0.5 });
  for (const x of W.roadsX) for (const z of W.roadsZ) {
    const g = new THREE.PlaneGeometry(12, 12); scaleUV(g, 0, 4, 1.5, 1.5);
    const m = new THREE.Mesh(g, W.asphMat); m.rotation.x = -Math.PI / 2; m.position.set(x, 0.032, z); m.receiveShadow = true; sc.add(m);
  }
  // pasy
  const zebra = mat('#d9d9d4', { rough: 0.85, key: 'zebra' }), zg = new THREE.BoxGeometry(1, 0.012, 1);
  for (const X of W.roadsX) for (const Z of W.roadsZ) for (let k = -5; k <= 5.01; k += 1.25) {
    Inst.add('zebra', zg, zebra, X + 8.2, 0.04, Z + k, 0, [3, 1, 0.6], null, false); Inst.add('zebra', zg, zebra, X - 8.2, 0.04, Z + k, 0, [3, 1, 0.6], null, false);
    Inst.add('zebra', zg, zebra, X + k, 0.04, Z + 8.2, 0, [0.6, 1, 3], null, false); Inst.add('zebra', zg, zebra, X + k, 0.04, Z - 8.2, 0, [0.6, 1, 3], null, false);
  }

  // płyty bloków
  const paveM = mat('#ffffff', { map: P.map, bump: P.bump, bumpScale: 0.02, rough: 0.88, key: 'pave', env: 0.4 });
  const curbM = mat('#7d8086', { rough: 0.9 });
  const grassM = mat('#ffffff', { map: GR.map, bump: GR.bump, bumpScale: 0.05, rough: 1.0, key: 'grass', env: 0.2 });
  const lotM = W.asphMat;
  for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
    const b = blk(i, j), bw = b.x1 - b.x0, bd = b.z1 - b.z0;
    const g = new THREE.BoxGeometry(bw, 0.14, bd); scaleUV(g, 8, 12, bw / 3, bd / 3);
    const topM = (i === 3 && j === 1) ? lotM : paveM;
    if (i === 3 && j === 1) scaleUV(g, 8, 12, 3 / 8, 3 / 8);
    const m = new THREE.Mesh(g, [curbM, curbM, topM, curbM, curbM, curbM]);
    m.position.set(b.cx, 0.07, b.cz); m.receiveShadow = true; sc.add(m);
  }
  // granice świata – żywopłot i mur
  const hedge = mat('#ffffff', { map: GR.map, rough: 1, key: 'hedge' });
  for (const [w, d, x, z] of [[252, 2.2, 0, -124], [252, 2.2, 0, 124], [2.2, 252, -124, 0], [2.2, 252, 124, 0]]) {
    const g = new THREE.BoxGeometry(w, 4.2, d); const m = new THREE.Mesh(g, hedge); m.material.color.copy(lin('#2c5a30'));
    m.position.set(x, 2.1, z); m.castShadow = true; sc.add(m); addCol(x - w / 2, x + w / 2, z - d / 2, z + d / 2, 5);
  }

  /* --- zabudowa generyczna --- */
  const special = new Set(['1,1', '2,1', '1,2', '2,2', '3,1', '0,0', '1,0', '0,3', '3,2']);
  const blokKeys = ['blokA', 'blokB', 'blokC', 'blokD'], kamKeys = ['kamA', 'kamB', 'kamC'];
  const kamBlocks = new Set(['2,0', '1,3', '2,3']);
  for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
    if (special.has(i + ',' + j)) continue;
    const b = blk(i, j), isKam = kamBlocks.has(i + ',' + j);
    const inx0 = b.x0 + 7, inx1 = b.x1 - 7, inz0 = b.z0 + 7, inz1 = b.z1 - 7;
    const cw = (inx1 - inx0 - 6) / 2, cd = (inz1 - inz0 - 6) / 2;
    for (let a = 0; a < 2; a++) for (let c = 0; c < 2; c++) {
      const w = Math.floor(cw / 4) * 4, d = Math.floor(cd / 4) * 4;
      const cx = (a === 0 ? inx0 + w / 2 : inx1 - w / 2), cz = (c === 0 ? inz0 + d / 2 : inz1 - d / 2);
      const h = isKam ? [12, 15, 18][Math.floor(RND() * 3)] : [15, 21, 27, 33, 36][Math.floor(RND() * 5)];
      const faces = [a === 0 ? 'w' : 'e', c === 0 ? 'n' : 's'];
      building(cx, cz, w, d, h, isKam ? pick(kamKeys) : pick(blokKeys), { shops: (isKam || RND() < 0.5) ? faces : [faces[Math.floor(RND() * 2)]] });
    }
    // podwórko wewnątrz kwartału
    const yardM = new THREE.Mesh(new THREE.PlaneGeometry(6, b.z1 - b.z0 - 14), grassM); yardM.rotation.x = -Math.PI / 2; yardM.position.set(b.cx, 0.15, b.cz); scaleUV(yardM.geometry, 0, 4, 1, 6); yardM.receiveShadow = true; sc.add(yardM);
    tree(b.cx, b.cz - 6, 0.9); tree(b.cx, b.cz + 7, 1.0); tree(b.cx + 0.5, b.cz - 14, 0.8, 'bush'); tree(b.cx - 0.5, b.cz + 14, 0.8, 'bush');
    prop('dumpster', b.cx - 9, b.cz + 0.5, Math.PI / 2, { col: [0.6, 1.05, 1.4] });
    prop('bench', b.cx + 1.5, b.cz, Math.PI / 2, { col: [0.3, 1.1, 0.9] });
  }

  /* --- PARK --- */
  {
    const b = blk(1, 1), bw = b.x1 - b.x0 - 8;
    const lawn = new THREE.Mesh(new THREE.PlaneGeometry(bw, bw), grassM); scaleUV(lawn.geometry, 0, 4, bw / 6, bw / 6);
    lawn.rotation.x = -Math.PI / 2; lawn.position.set(b.cx, 0.15, b.cz); lawn.receiveShadow = true; sc.add(lawn);
    const gm = mat('#ffffff', { map: TX.gravel().map, rough: 1, key: 'gravel' });
    for (const [w, d] of [[bw, 3.4], [3.4, bw]]) { const p = new THREE.Mesh(new THREE.PlaneGeometry(w, d), gm); scaleUV(p.geometry, 0, 4, w / 3, d / 3); p.rotation.x = -Math.PI / 2; p.position.set(b.cx, 0.16, b.cz); p.receiveShadow = true; sc.add(p); }
    const ring = new THREE.Mesh(new THREE.CircleGeometry(7.5, 28), gm); ring.rotation.x = -Math.PI / 2; ring.position.set(b.cx, 0.165, b.cz); ring.receiveShadow = true; sc.add(ring);
    // fontanna
    const fg = new GB();
    fg.cyl(4.4, 4.7, 0.6, '#9a9ca2', { x: b.cx, y: 0.44, z: b.cz, seg: 28 }); fg.cyl(4.0, 4.0, 0.62, '#6d7077', { x: b.cx, y: 0.44, z: b.cz, seg: 28 });
    fg.cyl(0.5, 0.7, 1.6, '#a7a9af', { x: b.cx, y: 0.95, z: b.cz, seg: 12 }); fg.cyl(1.5, 0.4, 0.25, '#a7a9af', { x: b.cx, y: 1.8, z: b.cz, seg: 16 }); fg.cyl(0.25, 0.35, 0.8, '#a7a9af', { x: b.cx, y: 2.2, z: b.cz, seg: 10 });
    sc.add(GFX.meshFromGB(fg, { rough: 0.7 }));
    const water = new THREE.Mesh(new THREE.CircleGeometry(3.95, 28), mat('#3f7fa6', { rough: 0.05, metal: 0.3, env: 2.0, transparent: true, opacity: 0.85, key: 'water' }));
    water.rotation.x = -Math.PI / 2; water.position.set(b.cx, 0.72, b.cz); sc.add(water);
    addCol(b.cx - 4.5, b.cx + 4.5, b.cz - 4.5, b.cz + 4.5, 1);
    for (const [x, z, r] of [[-22, -37.6, 0], [-38, -37.6, 0], [-22, -22.4, Math.PI], [-38, -22.4, Math.PI], [-37.6, -30 - 8, Math.PI / 2], [-22.4, -22, -Math.PI / 2]]) prop('bench', x, z, r, { col: r % Math.PI === 0 ? [1.1, 0.35, 0.9] : [0.35, 1.1, 0.9] });
    const tr = mulberry(777);
    for (let k = 0; k < 26; k++) {
      let x, z, tries = 0;
      do { x = b.x0 + 5 + tr() * (b.x1 - b.x0 - 10); z = b.z0 + 5 + tr() * (b.z1 - b.z0 - 10); tries++; }
      while (tries < 30 && (Math.abs(x - b.cx) < 3.2 || Math.abs(z - b.cz) < 3.2 || Math.hypot(x - b.cx, z - b.cz) < 9 || (Math.abs(x + 22) < 4 && Math.abs(z + 24) < 4)));
      if (tries < 30) tree(x, z, 0.85 + tr() * 0.5);
    }
    for (let k = 0; k < 10; k++) tree(b.x0 + 6 + tr() * (b.x1 - b.x0 - 12), b.z0 + 6 + tr() * (b.z1 - b.z0 - 12), 0.9, 'bush');
    for (const [x, z] of [[-33, -33], [-27, -27], [-33, -27], [-27, -33]]) prop('planter', x, z, Math.PI / 4, { col: [0.7, 0.7, 0.7] });
    prop('bin', -24.5, -26.2, 0, { col: [0.3, 0.3, 0.9] }); prop('bin', -35.5, -33.8, 0, { col: [0.3, 0.3, 0.9] });
    const sg = signPlane('PARK MIEJSKI', 4.5, 0.9, '#173b22', '#e8f5e9', 'bold 60px sans-serif', false, 1.0); sg.position.set(-30, 2.6, -8.9); sc.add(sg);
    box(null, 0.12, 2.2, 0.12, '#333', -32, 0.14, -8.9); box(null, 0.12, 2.2, 0.12, '#333', -28, 0.14, -8.9);
    W.zones.push({ id: 'park', name: 'Park Miejski', x0: b.x0, x1: b.x1, z0: b.z0, z1: b.z1, quiet: true });
  }

  /* --- PARKING --- */
  {
    const b = blk(3, 1);
    const lm = mat('#d9d9d4', { rough: 0.85, key: 'zebra' });
    for (let k = 0; k < 9; k++) for (const s of [-1, 1]) Inst.add('lotline', new THREE.BoxGeometry(1, 0.012, 1), lm, b.x0 + 7 + k * 5.4, 0.15, b.cz + s * 12, 0, [0.14, 1, 6.5], null, false);
    for (let k = 0; k < 8; k++) {
      if (RND() < 0.35) carParked(b.x0 + 9.7 + k * 5.4, b.cz - 12, 0);
      if (RND() < 0.5) carParked(b.x0 + 9.7 + k * 5.4, b.cz + 12, Math.PI);
    }
    const gb = new GB();
    gb.box(5, 2.8, 4, '#5a5d63', { x: b.x1 - 8, y: 1.54, z: b.z0 + 8 }); gb.box(5.4, 0.2, 4.4, '#33363b', { x: b.x1 - 8, y: 3.04, z: b.z0 + 8 });
    gb.box(2.4, 1.2, 0.06, '#1a2530', { x: b.x1 - 8, y: 1.9, z: b.z0 + 10.03 });
    gb.box(0.2, 1.1, 0.2, '#e8e8e8', { x: b.x0 + 4, y: 0.7, z: b.z1 - 5 }); gb.box(6.5, 0.12, 0.12, '#c0392b', { x: b.x0 + 7.2, y: 1.2, z: b.z1 - 5 });
    sc.add(GFX.meshFromGB(gb, { rough: 0.7 })); addCol(b.x1 - 10.5, b.x1 - 5.5, b.z0 + 6, b.z0 + 10, 3);
    const sg = signPlane('PARKING STRZEŻONY', 5, 0.8, '#143a8a', '#ffffff', 'bold 46px sans-serif', false, 1.2); sg.position.set(b.x1 - 8, 3.7, b.z0 + 10.06); sc.add(sg);
    for (const x of [b.x0 + 14, b.x0 + 40]) for (const z of [b.cz - 5, b.cz + 5]) prop('cone', x, z, 0);
    W.zones.push({ id: 'parking', name: 'Parking', x0: b.x0, x1: b.x1, z0: b.z0, z1: b.z1 });
  }

  /* --- KOMISARIAT --- */
  {
    const b = blk(1, 0);
    building(b.cx, b.cz, 32, 20, 18, 'modern', { noBalcony: true });
    const sg = signPlane('KOMISARIAT POLICJI', 14, 2.0, '#0b1f4a', '#cfe1ff', 'bold 50px sans-serif', true, 1.8); sg.position.set(b.cx, 13.5, b.cz + 10.2); sc.add(sg);
    const st = new THREE.Mesh(new THREE.BoxGeometry(32.3, 0.35, 0.3), GFX.basic('#2563eb')); st.material.color.multiplyScalar(2.0); st.position.set(b.cx, 9.5, b.cz + 10.1); sc.add(st);
    const gb = new GB(); gb.box(8, 0.3, 3, '#6e7178', { x: b.cx, y: 0.3, z: b.cz + 11.5 }); gb.box(4, 3.2, 0.3, '#10161f', { x: b.cx, y: 1.75, z: b.cz + 10.1 }); gb.box(6, 0.2, 2.6, '#2a2f37', { x: b.cx, y: 3.6, z: b.cz + 11.2 });
    sc.add(GFX.meshFromGB(gb, { rough: 0.5, metal: 0.3 }));
    carParked(b.cx - 9, b.cz + 16.5, Math.PI / 2, 'sedan', null, true); carParked(b.cx + 9, b.cz + 16.5, Math.PI / 2, 'suv', null, true);
    for (const x of [-14, -5, 5, 14]) prop('bollard', b.cx + x, b.cz + 22, 0, { col: [0.12, 0.12, 0.9] });
    W.zones.push({ id: 'komisariat', name: 'Okolice Komisariatu', x0: b.x0, x1: b.x1, z0: b.z0, z1: b.z1, police: true });
  }

  /* --- PODWÓRKO --- */
  {
    const b = blk(0, 0);
    building(-106, -108, 20, 16, 30, 'blokB'); building(-80, -108, 16, 16, 24, 'blokA'); building(-108, -80, 16, 20, 27, 'blokD');
    const lawn = new THREE.Mesh(new THREE.PlaneGeometry(22, 20), grassM); scaleUV(lawn.geometry, 0, 4, 4, 3.5); lawn.rotation.x = -Math.PI / 2; lawn.position.set(-88, 0.15, -88); lawn.receiveShadow = true; sc.add(lawn);
    const gb = new GB();
    gb.box(0.12, 2.3, 0.12, '#3a4a5a', { x: -94.4, y: 1.3, z: -93 }); gb.box(0.12, 2.3, 0.12, '#3a4a5a', { x: -91.6, y: 1.3, z: -93 }); gb.box(3.1, 0.12, 0.12, '#c0392b', { x: -93, y: 2.45, z: -93 });
    for (const sx of [-0.7, 0.7]) { gb.box(0.03, 1.6, 0.03, '#888', { x: -93 + sx, y: 1.6, z: -93 }); gb.box(0.5, 0.05, 0.25, '#2c3e50', { x: -93 + sx, y: 0.8, z: -93 }); }
    gb.box(3, 0.25, 3, '#c9a15a', { x: -85, y: 0.27, z: -92 }); gb.box(3.2, 0.3, 0.2, '#7a5330', { x: -85, y: 0.3, z: -90.4 }); gb.box(3.2, 0.3, 0.2, '#7a5330', { x: -85, y: 0.3, z: -93.6 }); gb.box(0.2, 0.3, 3.2, '#7a5330', { x: -83.4, y: 0.3, z: -92 }); gb.box(0.2, 0.3, 3.2, '#7a5330', { x: -86.6, y: 0.3, z: -92 });
    gb.box(1.0, 1.6, 0.1, '#2980b9', { x: -90, y: 0.95, z: -82, rx: -0.6 }); gb.box(0.1, 1.8, 0.1, '#555', { x: -90, y: 1.0, z: -81.2 });
    gb.box(0.1, 2.6, 0.1, '#444', { x: -97, y: 1.44, z: -84 }); gb.box(0.1, 2.6, 0.1, '#444', { x: -97, y: 1.44, z: -80 }); gb.box(0.05, 0.05, 4, '#ccc', { x: -97, y: 2.6, z: -82 });
    sc.add(GFX.meshFromGB(gb, { rough: 0.7 }));
    prop('bench', -88, -83, 0, { col: [1.1, 0.35, 0.9] }); prop('bench', -82, -86, -Math.PI / 2, { col: [0.35, 1.1, 0.9] });
    tree(-97, -90, 1.0); tree(-80, -80, 0.95); tree(-92, -98, 0.9, 'birch');
    prop('dumpster', -74.5, -96.5, 0, { col: [1.05, 0.6, 1.4] }); prop('dumpster', -74.5, -94, 0, { col: [1.05, 0.6, 1.4] });
    carParked(-73, -78, 0); carParked(-73, -84, 0);
    W.zones.push({ id: 'podworko', name: 'Podwórko', x0: b.x0, x1: b.x1, z0: b.z0, z1: b.z1, quiet: true });
  }

  /* --- ZAUŁEK WILKÓW --- */
  {
    const b = blk(0, 3);
    building(-106, 108, 20, 16, 15, 'brickDark', { noBalcony: true }); building(-80, 108, 16, 16, 24, 'brickDark'); building(-108, 80, 16, 12, 12, 'brick'); building(-76, 80, 8, 12, 18, 'brickDark');
    const wall = new GB(); wall.box(40, 3, 0.4, '#3a3432', { x: -96, y: 1.64, z: 71.4 });
    sc.add(GFX.meshFromGB(wall, { rough: 0.95 })); addCol(-116, -76, 71.2, 71.6, 3.2);
    for (let k = 0; k < 4; k++) { const gp = new THREE.Mesh(new THREE.PlaneGeometry(8, 3), new THREE.MeshStandardMaterial({ map: TX.graffiti(k + 1), transparent: true, roughness: 1, depthWrite: false })); gp.position.set(-110 + k * 9.5, 1.7, 71.62); W.scene.add(gp); const g2 = gp.clone(); g2.position.z = 71.18; g2.rotation.y = Math.PI; W.scene.add(g2); }
    for (let k = 0; k < 6; k++) {
      const x = -100 + (k % 3) * 6, z = 91 + Math.floor(k / 3) * 7;
      prop('barrel', x, z, 0, { col: [0.33, 0.33, 1.1] });
      if (k % 2 === 0) { const f = new THREE.Mesh(new THREE.ConeGeometry(0.3, 0.9, 7), new THREE.MeshBasicMaterial({ color: new THREE.Color(5, 1.6, 0.25) })); f.position.set(x, 1.5, z); sc.add(f); W.flickers.push(f); }
    }
    prop('dumpster', -112, 92, Math.PI / 2, { col: [0.6, 1.05, 1.4] }); prop('crate', -86, 86, 0.3, { col: [0.5, 0.5, 0.9] }); prop('crate', -85, 87.2, 0.9, { col: [0.5, 0.5, 0.9] });
    carParked(-112, 99, 0, 'van', '#2a2a2e');
    W.zones.push({ id: 'wilki', name: 'Terytorium Wilków', x0: b.x0, x1: b.x1, z0: b.z0, z1: b.z1, gang: true });
  }

  /* --- BUDYNKI INTERAKTYWNE --- */
  {
    building(30, -30, 32, 32, 21, 'kamA');
    door('safe', 30, -14, 'MIESZKANIE', '#f0a030', 5.5, 0);
    for (const x of [22, 38]) prop('planter', x, -12.6, 0, { col: [0.8, 0.3, 0.6] });
    prop('bench', 40, -9.5, Math.PI, { col: [1.1, 0.35, 0.9] }); prop('bin', 24.5, -9.2, 0, { col: [0.3, 0.3, 0.9] });
    W.zones.push({ id: 'dom', name: 'Kamienica', x0: 6, x1: 54, z0: -54, z1: -6 });
  }
  {
    building(-30, 26, 32, 20, 12, 'brick', { noBalcony: true });
    door('shop', -30, 16, 'HURTOWNIA STASIA', '#3ddc6e', 7.5, Math.PI);
    prop('crate', -40, 13.2, 0.1, { col: [0.55, 0.55, 0.9] }); prop('crate', -38.7, 13.4, 0.5, { col: [0.55, 0.55, 0.9] }); prop('crate', -39.4, 13.3, 0.2, { y: 1.04 });
    prop('barrel', -21, 13.4, 0, { col: [0.33, 0.33, 1.1] }); carParked(-17, 4.85, Math.PI / 2, 'van', '#d9dcdf');
    building(-42, 46, 12, 8, 9, 'brickDark', { noBalcony: true }); building(-20, 46, 16, 8, 12, 'kamB', { shops: ['s'] });
    W.zones.push({ id: 'hurt', name: 'Hurtownia', x0: -54, x1: -6, z0: 6, z1: 54 });
  }
  {
    building(30, 28, 32, 24, 15, 'club', { noBalcony: true });
    door('club', 30, 16, 'KLUB NEON', '#ff3bd0', 8.5, Math.PI);
    const big = signPlane('NEON', 12, 3.6, '#0d0714', '#ff3bd0', 'bold 150px sans-serif', true, 2.6); big.position.set(30, 10.5, 15.9); big.rotation.y = Math.PI; sc.add(big);
    for (const x of [-4.5, -2.6, 2.6, 4.5]) prop('bollard', 30 + x, 12.4, 0, { col: [0.12, 0.12, 0.9] });
    const rope = new GB(); rope.box(1.9, 0.05, 0.05, '#8a1c2c', { x: 26.45, y: 0.9, z: 12.4 }); rope.box(1.9, 0.05, 0.05, '#8a1c2c', { x: 33.55, y: 0.9, z: 12.4 }); sc.add(GFX.meshFromGB(rope));
    carParked(44, 4.85, Math.PI / 2, 'suv', '#15171a'); carParked(16, 4.85, -Math.PI / 2, 'sedan', '#6b1f2a');
    building(18, 47, 16, 8, 12, 'kamC', { shops: ['s'] }); building(42, 47, 16, 8, 15, 'kamA', { shops: ['s'] });
    W.zones.push({ id: 'klub', name: 'Okolice klubu', x0: 6, x1: 54, z0: 6, z1: 54 });
  }
  {
    // Myjnia Kryształ (przykrywka)
    building(96, 24, 28, 16, 6, 'modern', { noBalcony: true });
    door('wash', 86, 16, 'MYJNIA KRYSZTAŁ', '#38bdf8', 7.5, Math.PI);
    const gb = new GB();
    for (const x of [97, 104]) { gb.box(5.4, 4.2, 0.4, '#0b1016', { x, y: 2.24, z: 15.9 }); gb.box(5.8, 0.3, 0.6, '#38bdf8', { x, y: 4.5, z: 15.8 }); }
    sc.add(GFX.meshFromGB(gb, { rough: 0.4, metal: 0.4 }));
    carParked(97, 4.85, Math.PI / 2, 'hatch'); for (const x of [93.5, 100.5, 107.5]) prop('cone', x, 13, 0);
    building(78, 46, 16, 8, 12, 'blokC', { shops: ['s'] }); building(106, 46, 20, 8, 18, 'blokA', { shops: ['s'] });
    W.zones.push({ id: 'myjnia', name: 'Myjnia', x0: 66, x1: 120, z0: 6, z1: 54 });
  }

  /* --- przystanek --- */
  {
    const gb = new GB();
    gb.box(0.08, 2.5, 4.2, '#8fb4c9', { x: -9.75, y: 1.4, z: -30 }); gb.box(2.6, 0.12, 4.6, '#30343a', { x: -8.6, y: 2.72, z: -30 });
    gb.box(0.08, 2.5, 0.08, '#30343a', { x: -7.45, y: 1.4, z: -32.2 }); gb.box(0.08, 2.5, 0.08, '#30343a', { x: -7.45, y: 1.4, z: -27.8 });
    gb.box(0.5, 0.08, 3.4, '#7a5330', { x: -9.3, y: 0.62, z: -30 }); gb.box(0.08, 0.5, 0.08, '#30343a', { x: -9.3, y: 0.38, z: -31.4 }); gb.box(0.08, 0.5, 0.08, '#30343a', { x: -9.3, y: 0.38, z: -28.6 });
    gb.cyl(0.04, 0.04, 2.8, '#8a8f98', { x: -7.3, y: 1.54, z: -26.6, seg: 6 }); gb.box(0.5, 0.5, 0.04, '#1d4fa8', { x: -7.3, y: 2.75, z: -26.6, ry: Math.PI / 2 });
    sc.add(GFX.meshFromGB(gb, { rough: 0.4, metal: 0.3 })); addCol(-9.85, -9.65, -32.1, -27.9, 2.6);
    const sg = signPlane('PRZYSTANEK • PARK', 3.4, 0.5, '#143a8a', '#ffffff', 'bold 44px sans-serif', false, 1.2); sg.position.set(-9.68, 2.3, -30); sg.rotation.y = Math.PI / 2; sc.add(sg);
  }

  /* --- latarnie --- */
  const lampPts = [];
  for (const lx of W.lat) for (let k = -3; k <= 3; k++) {
    const z = k * 36 + 18 * (W.lat.indexOf(lx) % 2); if (Math.abs(z) > 112 || W.roadsZ.some(r => Math.abs(z - r) < 11)) continue;
    const rd = nearest(W.roadsX, lx); lampPts.push([lx + Math.sign(lx - rd) * 1.5, z, Math.sign(rd - lx) > 0 ? 0 : Math.PI]);
  }
  for (const lz of W.lat) for (let k = -3; k <= 3; k++) {
    const x = k * 36 + 18 * ((W.lat.indexOf(lz) + 1) % 2); if (Math.abs(x) > 112 || W.roadsX.some(r => Math.abs(x - r) < 11)) continue;
    const rd = nearest(W.roadsZ, lz); lampPts.push([x, lz + Math.sign(lz - rd) * 1.5, Math.sign(rd - lz) > 0 ? -Math.PI / 2 : Math.PI / 2]);
  }
  const free = (x, z, pad) => !W.colliders.some(c => x > c.x0 - (pad || 0.8) && x < c.x1 + (pad || 0.8) && z > c.z0 - (pad || 0.8) && z < c.z1 + (pad || 0.8));
  W.lampPts = lampPts.filter(p => free(p[0], p[1]));
  const lp = Models.prop('lamp'), hg = new THREE.BoxGeometry(0.5, 0.06, 0.22), pg = new THREE.PlaneGeometry(18, 18); pg.rotateX(-Math.PI / 2);
  for (const p of W.lampPts) {
    Inst.add('lamp', lp.geometry, lp.material, p[0], 0.14, p[1], p[2], 1);
    const hx = p[0] + Math.cos(p[2]) * 1.35, hz = p[1] - Math.sin(p[2]) * 1.35;
    Inst.add('lamphead', hg, W.lampHeadMat, hx, 6.14, hz, p[2], 1, null, false);
    Inst.add('lamppool', pg, W.poolMat, hx + Math.cos(p[2]) * 1.5, 0.2, hz - Math.sin(p[2]) * 1.5, 0, 1, null, false);
    addCol(p[0] - 0.15, p[0] + 0.15, p[1] - 0.15, p[1] + 0.15, 6);
  }

  /* --- sygnalizacja świetlna --- */
  W.tlMat = {};
  for (const k of ['nsr', 'nsy', 'nsg', 'ewr', 'ewy', 'ewg']) W.tlMat[k] = new THREE.MeshBasicMaterial({ color: 0x111111 });
  const lens = new THREE.SphereGeometry(0.09, 10, 8);
  for (const X of W.roadsX) for (const Z of W.roadsZ) {
    // 4 słupy; każdy obsługuje ruch nadjeżdżający z jednego kierunku
    const posts = [[X + 7.2, Z + 7.2, 0, 'ns'], [X - 7.2, Z - 7.2, Math.PI, 'ns'], [X - 7.2, Z + 7.2, -Math.PI / 2, 'ew'], [X + 7.2, Z - 7.2, Math.PI / 2, 'ew']];
    for (const [x, z, ry, ax] of posts) {
      prop('trafficlight', x, z, ry, { y: 0.14 });
      const fx = Math.sin(ry) * 0.2, fz = Math.cos(ry) * 0.2;
      ['r', 'y', 'g'].forEach((c, i) => Inst.add('tl' + ax + c, lens, W.tlMat[ax + c], x + fx, 3.42 - i * 0.28, z + fz, 0, 1, null, false));
      addCol(x - 0.12, x + 0.12, z - 0.12, z + 0.12, 3.5);
    }
  }

  /* --- zaparkowane auta przy krawężniku --- */
  let placed = 0, tries = 0;
  while (placed < 26 && tries++ < 400) {
    const horiz = RND() < 0.5, road = pick(horiz ? W.roadsZ : W.roadsX), side = RND() < 0.5 ? -1 : 1;
    const along = -112 + RND() * 224;
    if ((horiz ? W.roadsX : W.roadsZ).some(r => Math.abs(along - r) < 16)) continue;
    if (Math.abs(along) < 62 && false) continue;
    const x = horiz ? along : road + side * 4.85, z = horiz ? road + side * 4.85 : along;
    if (!free(x, z, 3.2)) continue;
    carParked(x, z, horiz ? (side > 0 ? -Math.PI / 2 : Math.PI / 2) : (side > 0 ? 0 : Math.PI)); placed++;
  }

  /* --- mała architektura wzdłuż chodników --- */
  for (let k = 0; k < 70; k++) {
    const lx = pick(W.lat), t = -112 + RND() * 224, vert = RND() < 0.5;
    const rdArr = vert ? W.roadsX : W.roadsZ, rd = nearest(rdArr, lx), off = Math.sign(lx - rd) * 1.55;
    const x = vert ? lx + off : t, z = vert ? t : lx + off;
    if ((vert ? W.roadsZ : W.roadsX).some(r => Math.abs(t - r) < 10) || !free(x, z, 1.2)) continue;
    const kind = pick(['bin', 'bin', 'hydrant', 'bollard', 'mailbox', 'sign', 'planter', 'tree', 'tree', 'tree']);
    if (kind === 'tree') tree(x, z, 0.7 + RND() * 0.25, RND() < 0.3 ? 'birch' : 'oak');
    else if (kind === 'sign') prop('sign', x, z, vert ? Math.PI / 2 : 0, { v: pick(['stop', 'park', 'warn']), col: [0.08, 0.08, 2.6] });
    else if (kind === 'planter') prop('planter', x, z, vert ? Math.PI / 2 : 0, { col: vert ? [0.32, 0.82, 0.6] : [0.82, 0.32, 0.6] });
    else prop(kind, x, z, RND() * 6.28, { col: [0.22, 0.22, 0.9] });
  }
  prop('kiosk', -50.5, -50.5, Math.PI / 4, { col: [1.6, 1.6, 2.4] }); prop('kiosk', 50.5, 50.5, -Math.PI * 0.75, { col: [1.6, 1.6, 2.4] }); prop('kiosk', 50.5, -9.5, Math.PI, { col: [1.4, 1.1, 2.4] });
}

/* ============================================================
   DESZCZ
   ============================================================ */
function buildRain() {
  const N = 1400, pos = new Float32Array(N * 6);
  W.rainData = { N, off: new Float32Array(N * 3) };
  for (let i = 0; i < N; i++) { W.rainData.off[i * 3] = (Math.random() - 0.5) * 50; W.rainData.off[i * 3 + 1] = Math.random() * 24; W.rainData.off[i * 3 + 2] = (Math.random() - 0.5) * 50; }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  W.rainMesh = new THREE.LineSegments(g, new THREE.LineBasicMaterial({ color: new THREE.Color(0.75, 0.8, 0.9), transparent: true, opacity: 0, depthWrite: false, fog: false }));
  W.rainMesh.frustumCulled = false; W.scene.add(W.rainMesh);
}
function updateRain(dt) {
  const R = W.rainData, a = W.rainMesh.geometry.attributes.position.array, cp = W.camera.position;
  const vis = W.rain > 0.02 && W.loc === 'out';
  W.rainMesh.visible = vis; if (!vis) return;
  W.rainMesh.material.opacity = 0.42 * W.rain;
  const n = Math.floor(R.N * Math.min(1, W.rain + 0.15));
  for (let i = 0; i < R.N; i++) {
    let y = R.off[i * 3 + 1] - dt * 26; if (y < 0) y += 24; R.off[i * 3 + 1] = y;
    const x = cp.x + R.off[i * 3], z = cp.z + R.off[i * 3 + 2], k = i * 6;
    if (i > n) { a[k] = a[k + 3] = 0; a[k + 1] = a[k + 4] = -50; a[k + 2] = a[k + 5] = 0; continue; }
    a[k] = x; a[k + 1] = y; a[k + 2] = z; a[k + 3] = x + 0.12; a[k + 4] = y + 0.75; a[k + 5] = z;
  }
  W.rainMesh.geometry.attributes.position.needsUpdate = true;
}

/* ============================================================
   KOLIZJE
   ============================================================ */
W.resolve = function (x, z, r, vx, vz) {
  let nx = x + vx, nz = z;
  for (const c of W.colliders) if (nx > c.x0 - r && nx < c.x1 + r && nz > c.z0 - r && nz < c.z1 + r) { if (vx > 0) nx = c.x0 - r; else if (vx < 0) nx = c.x1 + r; }
  nz = z + vz;
  for (const c of W.colliders) if (nx > c.x0 - r && nx < c.x1 + r && nz > c.z0 - r && nz < c.z1 + r) { if (vz > 0) nz = c.z0 - r; else if (vz < 0) nz = c.z1 + r; }
  return [nx, nz];
};
W.los = function (ax, az, bx, bz) {
  for (const c of W.colliders) { if (c.h < 3 || (c.x1 - c.x0 < 1 && c.z1 - c.z0 < 1)) continue; if (segBox(ax, az, bx, bz, c.x0, c.x1, c.z0, c.z1)) return false; }
  return true;
};
function segBox(ax, az, bx, bz, x0, x1, z0, z1) {
  let t0 = 0, t1 = 1; const dx = bx - ax, dz = bz - az;
  const p = [-dx, dx, -dz, dz], q = [ax - x0, x1 - ax, az - z0, z1 - az];
  for (let i = 0; i < 4; i++) {
    if (p[i] === 0) { if (q[i] < 0) return false; }
    else { const t = q[i] / p[i]; if (p[i] < 0) { if (t > t1) return false; if (t > t0) t0 = t; } else { if (t < t0) return false; if (t < t1) t1 = t; } }
  }
  return true;
}
W.setLocation = function (loc) {
  W.loc = loc;
  for (const id in W.rooms) if (W.rooms[id].group) W.rooms[id].group.visible = (id === loc);
};

/* ============================================================
   OŚWIETLENIE DZIEŃ / NOC
   ============================================================ */
const SKYK = [ // godzina, zenit, horyzont
  [0, '#02040c', '#0a1024'], [4.5, '#04071a', '#141a36'], [5.8, '#1b2a55', '#c96a4a'], [7, '#3d6fb0', '#f0b98a'], [9, '#2f6fc0', '#a9cdf0'], [16.5, '#2c69b8', '#a9cdf0'],
  [18.2, '#3a5a9a', '#f29a5a'], [19.6, '#1c2450', '#c0503a'], [20.8, '#060a1e', '#1c1a3a'], [24, '#02040c', '#0a1024'],
];
const _a = new THREE.Color(), _b = new THREE.Color(), _top = new THREE.Color(), _hor = new THREE.Color(), _v = new THREE.Vector3();
function skyAt(h) {
  for (let i = 0; i < SKYK.length - 1; i++) if (h >= SKYK[i][0] && h <= SKYK[i + 1][0]) {
    const t = (h - SKYK[i][0]) / (SKYK[i + 1][0] - SKYK[i][0]);
    _top.copy(lin(SKYK[i][1])).lerp(lin(SKYK[i + 1][1]), t); _hor.copy(lin(SKYK[i][2])).lerp(lin(SKYK[i + 1][2]), t); return;
  }
}
W.updateLighting = function (hour, px, pz, dt) {
  W.t += dt;
  const ang = ((hour - 6) / 12) * Math.PI, elev = Math.sin(ang);
  const night = clamp(0.32 - elev * 2.6, 0, 1);
  W.nightF = night;
  const inside = W.loc !== 'out';
  // pogoda
  W.rain += (W.rainTarget - W.rain) * Math.min(1, dt * 0.25);
  W.wet += ((W.rain > 0.15 ? 1 : 0) - W.wet) * Math.min(1, dt * (W.rain > 0.15 ? 0.12 : 0.03));
  const ov = W.rain;      // zachmurzenie
  skyAt(hour);
  _top.lerp(_a.setRGB(0.12, 0.13, 0.15).multiplyScalar(1 - night * 0.9), ov * 0.8); _hor.lerp(_a.setRGB(0.3, 0.32, 0.35).multiplyScalar(1 - night * 0.92), ov * 0.8);
  const U = GFX.skyMat.uniforms;
  U.uTop.value.copy(_top); U.uHorizon.value.copy(_hor); U.uNight.value = night; U.uTime.value = W.t; U.uCloud.value = 0.55 + ov * 0.45;
  const dayDir = _v.set(Math.cos(ang) * -0.85, Math.max(0.1, Math.abs(elev)), 0.5).normalize();
  U.uSunDir.value.copy(dayDir);
  if (elev > 0) U.uSunColor.value.setRGB(1.0, 0.75 + elev * 0.2, 0.45 + elev * 0.4).multiplyScalar(1 - ov * 0.9); else U.uSunColor.value.setRGB(0.5, 0.55, 0.75).multiplyScalar(0.5 * (1 - ov));

  const G1 = GFX.grade ? GFX.grade.uniforms : null;
  if (inside) {
    const R = W.rooms[W.loc], club = W.loc === 'club';
    W.scene.fog.color.setRGB(0.01, 0.01, 0.015); W.scene.fog.near = 25; W.scene.fog.far = 90;
    W.sun.intensity = 0; W.hemi.intensity = club ? 0.1 : 0.34; W.hemi.color.setRGB(1, 0.92, 0.82); W.hemi.groundColor.setRGB(0.25, 0.2, 0.16); W.amb.intensity = club ? 0.03 : 0.1;
    const L = W.roomLights;
    if (club) {
      const beat = (typeof Snd !== 'undefined' && Snd.beat) ? Snd.beat() : 0;
      L[0].position.set(R.cx, R.h - 0.8, -2); L[0].color.setHSL((W.t * 0.13) % 1, 1, 0.5); L[0].intensity = 2.4 + beat * 2.2; L[0].distance = 26;
      L[1].position.set(R.cx - 12, 2.4, -1); L[1].color.setRGB(1, 0.2, 0.8); L[1].intensity = 1.6; L[1].distance = 14;
      L[2].position.set(R.cx + 10, 2.2, -7.5); L[2].color.setRGB(1, 0.75, 0.4); L[2].intensity = 1.3; L[2].distance = 12;
      for (let i = 0; i < W.clubTiles.length; i++) {
        const hh = (W.t * 0.22 + (i % 8) * 0.07 + Math.floor(i / 8) * 0.05) % 1;
        W.clubTiles[i].material.color.setHSL(hh, 1, 0.5).multiplyScalar(0.25 + 1.4 * Math.pow(0.5 + 0.5 * Math.sin(W.t * 4 + i * 1.7), 2) + beat * 0.8);
      }
      W.clubLights.forEach((l, i) => { l.cone.rotation.z = Math.sin(W.t * 1.3 + i * 1.7) * 0.6; l.cone.rotation.x = Math.cos(W.t * 0.9 + i) * 0.5; l.cone.material.color.setHSL((W.t * 0.2 + i * 0.25) % 1, 1, 0.5).multiplyScalar(0.5 + beat); l.head.material.color.setHSL((W.t * 0.2 + i * 0.25) % 1, 1, 0.5).multiplyScalar(4); });
      if (W.discoBall) W.discoBall.rotation.y += dt * 0.8;
      if (W.speakers) W.speakers.forEach(s => s.scale.setScalar(1 + beat * 0.035));
    } else {
      const pts = R.lights || [[0, 0]];
      for (let i = 0; i < 3; i++) { const p = pts[i]; if (p) { L[i].position.set(R.cx + p[0], R.h - 0.5, R.cz + p[1]); L[i].color.setRGB(1, 0.86, 0.68); L[i].intensity = p[2] || 1.25; L[i].distance = 16; } else L[i].intensity = 0; }
    }
    if (G1) { G1.exposure.value = club ? 1.25 : 1.15; if (GFX.bloom) { GFX.bloom.strength = club ? 0.95 : 0.4; GFX.bloom.threshold = club ? 0.75 : 0.95; } }
    GFX.setEnvIntensity(club ? 0.15 : 0.35);
  } else {
    W.scene.fog.color.copy(_hor).lerp(_top, 0.45); { const fc = W.scene.fog.color, fl = (fc.r + fc.g + fc.b) / 3; fc.r += (fl - fc.r) * 0.45; fc.g += (fl - fc.g) * 0.45; fc.b += (fl - fc.b) * 0.45; }
    W.scene.fog.near = 40 - night * 15 - ov * 15; W.scene.fog.far = 260 - night * 90 - ov * 110;
    for (const l of W.roomLights) l.intensity = 0;
    W.sun.position.set(px + dayDir.x * 110, dayDir.y * 110, pz + dayDir.z * 110); W.sun.target.position.set(px, 0, pz);
    if (elev > 0.02) { W.sun.color.setRGB(1.0, 0.72 + clamp(elev, 0, 0.6) * 0.42, 0.45 + clamp(elev, 0, 0.6) * 0.8); W.sun.intensity = clamp(elev * 3.2, 0, 2.3) * (1 - ov * 0.85); }
    else { W.sun.color.setRGB(0.55, 0.65, 1.0); W.sun.intensity = 0.2 * night * (1 - ov * 0.7); }
    W.hemi.color.copy(_top).lerp(_hor, 0.6); W.hemi.groundColor.setRGB(0.2, 0.18, 0.15);
    const hk = Math.max(W.hemi.color.r, W.hemi.color.g, W.hemi.color.b, 0.001); W.hemi.color.multiplyScalar(1 / hk);
    W.hemi.intensity = 0.10 + (1 - night) * 0.62; W.amb.intensity = 0.03 + night * 0.035;
    if (G1) { G1.exposure.value = 1.0 + night * 0.35; if (GFX.bloom) { GFX.bloom.strength = 0.22 + night * 0.5 + W.wet * 0.1; GFX.bloom.threshold = 1.5 - night * 0.6; } }
    GFX.setEnvIntensity(0.25 + (1 - night) * 0.75);
    const hk2 = hour < 5 || hour > 21 ? 'n' : (hour > 8.5 && hour < 16.5 ? 'd' + Math.round(ov * 2) : 'h' + Math.round(hour * 2) + Math.round(ov * 2));
    GFX.updateEnv(hk2);
  }
  // mokra nawierzchnia
  const rough = 0.92 - W.wet * 0.62;
  W.roadMat.roughness = rough; W.asphMat.roughness = rough; W.roadMat.userData.envBase = W.asphMat.userData.envBase = 0.5 + W.wet * 1.4;
  W.roadMat.envMapIntensity = W.roadMat.userData.envBase * GFX.envIntensity; W.asphMat.envMapIntensity = W.roadMat.envMapIntensity;
  W.stars.material.opacity = inside ? 0 : night * (1 - ov);
  W.stars.position.copy(W.camera.position);
  W.moon.visible = !inside && night > 0.3 && ov < 0.5;
  W.moon.position.set(W.camera.position.x - 170, 240, W.camera.position.z - 130);
  const nm = inside ? 0 : night;
  for (const e of W.nightMats) e.m.emissiveIntensity = nm * e.k + (e.day || 0) * (1 - nm);
  W.poolMat.opacity = nm * 0.55;
  W.lampHeadMat.color.setRGB(0.2 + nm * 5.5, 0.2 + nm * 4.2, 0.2 + nm * 2.2);
  W.parkedLightMat.color.setScalar(0.35);
  if (Models.lightMats.car) Models.lightMats.car.color.setScalar(0.5 + nm * 2.6);
  // sygnalizacja
  const T = W.tl; T.phase = (W.t % 30);
  T.ns = T.phase < 12 ? 'g' : T.phase < 15 ? 'y' : 'r'; T.ew = T.phase < 15 ? 'r' : T.phase < 27 ? 'g' : 'y';
  const on = { r: [5, 0.3, 0.2], y: [5, 3, 0.2], g: [0.3, 5, 1.2] };
  for (const ax of ['ns', 'ew']) for (const c of ['r', 'y', 'g']) { const m = W.tlMat[ax + c]; if (T[ax] === c) m.color.setRGB(on[c][0], on[c][1], on[c][2]); else m.color.setRGB(0.06, 0.06, 0.06); }
  for (const s of W.sirens) { const o2 = Math.sin(W.t * 9) > 0; s[0].visible = o2; s[1].visible = !o2; }
  for (const f of W.flickers) { f.scale.y = 0.8 + Math.sin(W.t * 11 + f.position.x) * 0.25; f.scale.x = 0.9 + Math.sin(W.t * 17 + f.position.z) * 0.15; }
  if (W.stationViz.window) W.stationViz.window.material.color.copy(_hor).multiplyScalar(inside ? 1.6 : 1).lerp(_a.setRGB(0.02, 0.03, 0.06), night * 0.6);
  if (W.stationViz.tv) W.stationViz.tv.material.color.setHSL((W.t * 0.05) % 1, 0.5, 0.4).multiplyScalar(1.2 + Math.sin(W.t * 7) * 0.4);
  updateRain(dt);
};
