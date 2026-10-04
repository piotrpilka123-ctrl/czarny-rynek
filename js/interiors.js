'use strict';
/* ============================================================
   WNĘTRZA: mieszkanie, hurtownia, klub, biuro myjni
   ============================================================ */

function buildInteriors() { buildSafehouse(); buildShop(); buildClub(); buildWash(); }

function makeRoom(id, floor, wallCol, ceilCol, o) {
  o = o || {};
  const R = W.rooms[id], cx = R.cx, cz = R.cz, w = R.w, d = R.d, h = R.h;
  const g = new THREE.Group(); W.scene.add(g); R.group = g;
  const fg = new THREE.PlaneGeometry(w, d); scaleUV(fg, 0, 4, w / (o.floorTile || 2), d / (o.floorTile || 2));
  const fl = new THREE.Mesh(fg, mat('#ffffff', { map: floor.map, rough: o.floorRough != null ? o.floorRough : 0.6, metal: o.floorMetal || 0, key: 'floor' + id, env: 0.8 }));
  fl.rotation.x = -Math.PI / 2; fl.position.set(cx, 0.005, cz); fl.receiveShadow = true; g.add(fl);
  const ce = new THREE.Mesh(new THREE.PlaneGeometry(w, d), mat(ceilCol, { rough: 1 })); ce.rotation.x = Math.PI / 2; ce.position.set(cx, h, cz); g.add(ce);
  const wt = TX.wall(wallCol, id.length * 7 + 3), wm = mat('#ffffff', { map: wt.map, rough: 0.95, key: 'wall' + id, env: 0.2 });
  const t = 0.5;
  for (const [ww, dd, x, z] of [[w + t * 2, t, cx, cz - d / 2 - t / 2], [w + t * 2, t, cx, cz + d / 2 + t / 2], [t, d, cx - w / 2 - t / 2, cz], [t, d, cx + w / 2 + t / 2, cz]]) {
    const bg = new THREE.BoxGeometry(ww, h, dd); const len = Math.max(ww, dd);
    scaleUV(bg, 0, 24, len / 4, 1);
    const m = new THREE.Mesh(bg, wm); m.position.set(x, h / 2, z); m.receiveShadow = true; g.add(m);
    addCol(x - ww / 2, x + ww / 2, z - dd / 2, z + dd / 2, h);
  }
  // listwy + drzwi wyjściowe
  const gb = new GB(), bc = o.base || '#2a2420';
  gb.box(w, 0.12, 0.05, bc, { x: cx, y: 0.06, z: cz - d / 2 + 0.03 }); gb.box(w, 0.12, 0.05, bc, { x: cx, y: 0.06, z: cz + d / 2 - 0.03 });
  gb.box(0.05, 0.12, d, bc, { x: cx - w / 2 + 0.03, y: 0.06, z: cz }); gb.box(0.05, 0.12, d, bc, { x: cx + w / 2 - 0.03, y: 0.06, z: cz });
  const ex = R.exit[0], ez = cz + d / 2;
  gb.box(1.3, 2.35, 0.1, o.door || '#6b4526', { x: ex, y: 1.18, z: ez - 0.06 }); gb.box(1.5, 0.1, 0.16, '#241a12', { x: ex, y: 2.4, z: ez - 0.08 });
  gb.box(0.1, 2.4, 0.16, '#241a12', { x: ex - 0.7, y: 1.2, z: ez - 0.08 }); gb.box(0.1, 2.4, 0.16, '#241a12', { x: ex + 0.7, y: 1.2, z: ez - 0.08 });
  gb.box(0.05, 0.14, 0.1, '#c9ced4', { x: ex + 0.45, y: 1.1, z: ez - 0.14 });
  gb.box(1.1, 0.02, 0.7, '#3a3a3a', { x: ex, y: 0.02, z: ez - 0.5 });
  g.add(GFX.meshFromGB(gb, { rough: 0.7 }));
  const sg = signPlane('WYJŚCIE', 1.1, 0.26, '#06180a', '#4ade80', 'bold 84px sans-serif', true, 2.2);
  sg.position.set(ex, 2.68, ez - 0.03); sg.rotation.y = Math.PI; g.add(sg);
  W.inter.push({ loc: id, x: ex, z: R.exit[1], range: 2.6, label: () => 'Wyjdź na ulicę', enabled: () => true, act: () => G.exit() });
  return g;
}
/* lampa sufitowa (świecąca) */
function ceilLamp(g, x, y, z, r, col) {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(r || 0.28, r || 0.28, 0.05, 16), new THREE.MeshBasicMaterial({ color: col || new THREE.Color(3.2, 2.7, 2.0) }));
  m.position.set(x, y - 0.03, z); g.add(m); return m;
}

/* ---------------- MIESZKANIE ---------------- */
function buildSafehouse() {
  const R = W.rooms.safe, cx = R.cx, h = R.h;
  const g = makeRoom('safe', TX.wood(), '#b9b2a4', '#e6e3dc', { floorTile: 3, floorRough: 0.5 });
  R.lights = [[-7, -1, 1.15], [4, -3.5, 1.3], [5, 4.5, 1.0]];
  const X = (v) => cx + v;   // współrzędne lokalne -12..12
  const gb = new GB(), col = (x0, x1, z0, z1, hh) => addCol(X(x0), X(x1), z0, z1, hh);

  // łóżko (róg płn.-zach.)
  gb.box(2.3, 0.3, 1.75, '#4a3626', { x: X(-10.7), y: 0.24, z: -6.9 }); gb.box(2.15, 0.2, 1.62, '#ece8e0', { x: X(-10.7), y: 0.49, z: -6.9 });
  gb.box(1.45, 0.13, 1.68, '#3b5b7a', { x: X(-10.3), y: 0.66, z: -6.9 }); gb.box(0.45, 0.13, 0.65, '#f7f7f5', { x: X(-11.45), y: 0.66, z: -6.5 }); gb.box(0.45, 0.13, 0.65, '#f7f7f5', { x: X(-11.45), y: 0.66, z: -7.3 });
  gb.box(0.1, 1.0, 1.75, '#3a2a1c', { x: X(-11.88), y: 0.6, z: -6.9 });
  col(-11.95, -9.5, -7.8, -6.0, 0.8);
  gb.box(0.5, 0.5, 0.45, '#4a3626', { x: X(-11.7), y: 0.25, z: -5.6 }); gb.cyl(0.05, 0.08, 0.3, '#2b2b2b', { x: X(-11.7), y: 0.65, z: -5.6, seg: 8 });
  W.inter.push({ loc: 'safe', x: X(-9.0), z: -6.6, range: 2.4, label: () => 'Spać do rana (zapis gry)', enabled: () => true, act: () => G.sleep() });
  // szafa
  gb.box(0.7, 2.2, 2.2, '#5a4632', { x: X(-11.6), y: 1.1, z: -2.8 }); gb.box(0.02, 2.0, 0.02, '#2a1f15', { x: X(-11.24), y: 1.1, z: -2.8 }); gb.box(0.03, 0.2, 0.03, '#c9ced4', { x: X(-11.22), y: 1.1, z: -2.65 }); gb.box(0.03, 0.2, 0.03, '#c9ced4', { x: X(-11.22), y: 1.1, z: -2.95 });
  col(-11.95, -11.2, -3.95, -1.65, 2.2);
  // strefa wypoczynku: TV + kanapa + stolik + dywan
  gb.box(3.8, 0.02, 2.8, '#6d2b2b', { x: X(-9.2), y: 0.02, z: 3.4 }); gb.box(3.4, 0.022, 2.4, '#7d3a34', { x: X(-9.2), y: 0.022, z: 3.4 });
  gb.box(0.45, 0.5, 2.0, '#2b2b2e', { x: X(-11.7), y: 0.25, z: 3.4 }); gb.box(0.07, 0.8, 1.4, '#0a0a0b', { x: X(-11.62), y: 1.1, z: 3.4 }); gb.box(0.2, 0.1, 0.5, '#0a0a0b', { x: X(-11.65), y: 0.56, z: 3.4 });
  col(-11.95, -11.4, 2.3, 4.5, 1.5);
  gb.box(1.0, 0.4, 2.5, '#34495e', { x: X(-7.3), y: 0.25, z: 3.4 }); gb.box(0.28, 0.5, 2.5, '#2c3e50', { x: X(-6.9), y: 0.68, z: 3.4 }); gb.box(1.0, 0.3, 0.26, '#2c3e50', { x: X(-7.3), y: 0.58, z: 2.2 }); gb.box(1.0, 0.3, 0.26, '#2c3e50', { x: X(-7.3), y: 0.58, z: 4.6 });
  gb.box(0.6, 0.14, 0.7, '#44607a', { x: X(-7.45), y: 0.5, z: 2.85 }); gb.box(0.6, 0.14, 0.7, '#44607a', { x: X(-7.45), y: 0.5, z: 3.95 }); gb.box(0.35, 0.3, 0.12, '#c0762b', { x: X(-7.15), y: 0.72, z: 2.6, rx: 0.3 });
  col(-7.85, -6.75, 2.1, 4.7, 0.9);
  gb.box(0.7, 0.05, 1.2, '#3a2a1c', { x: X(-9.3), y: 0.42, z: 3.4 }); for (const a of [-0.28, 0.28]) for (const b of [-0.52, 0.52]) gb.box(0.05, 0.4, 0.05, '#222', { x: X(-9.3) + a, y: 0.2, z: 3.4 + b });
  gb.cyl(0.05, 0.05, 0.12, '#e8e8e8', { x: X(-9.2), y: 0.5, z: 3.1, seg: 8 }); gb.box(0.25, 0.02, 0.18, '#1a1a1a', { x: X(-9.35), y: 0.46, z: 3.7 });
  col(-9.65, -8.95, 2.8, 4.0, 0.5);
  // regał z książkami
  gb.box(0.35, 2.0, 1.6, '#4a3626', { x: X(-11.75), y: 1.0, z: 6.9 });
  const br = mulberry(5); for (let s = 0; s < 4; s++) for (let k = 0; k < 9; k++) gb.box(0.2, 0.26 + br() * 0.1, 0.12 + br() * 0.04, ['#8e3b2f', '#2f5f8e', '#3f7d4a', '#c9a44b', '#6a3f8e', '#d9d4c8'][(br() * 6) | 0], { x: X(-11.62), y: 0.3 + s * 0.48, z: 6.25 + k * 0.155 });
  col(-11.95, -11.5, 6.0, 7.8, 2);
  // kuchnia (płd.-wsch.)
  gb.box(5.0, 0.88, 0.7, '#d9d4c8', { x: X(8.0), y: 0.44, z: 7.6 }); gb.box(5.1, 0.05, 0.78, '#2f3033', { x: X(8.0), y: 0.905, z: 7.58 });
  gb.box(5.0, 0.7, 0.38, '#cfc9bb', { x: X(8.0), y: 2.15, z: 7.78 }); for (let k = 0; k < 5; k++) gb.box(0.02, 0.6, 0.02, '#8a8478', { x: X(5.6 + k * 1.0), y: 2.15, z: 7.58 });
  gb.box(0.8, 0.04, 0.5, '#15161a', { x: X(6.6), y: 0.94, z: 7.6 }); for (const a of [-0.2, 0.2]) for (const b of [-0.12, 0.12]) gb.cyl(0.08, 0.08, 0.02, '#3a3a3d', { x: X(6.6) + a, y: 0.965, z: 7.6 + b, seg: 10 });
  gb.box(0.7, 0.1, 0.45, '#9aa1a8', { x: X(8.6), y: 0.9, z: 7.6 }); gb.cyl(0.02, 0.02, 0.3, '#c9ced4', { x: X(8.6), y: 1.08, z: 7.82, seg: 6 });
  gb.box(0.3, 0.32, 0.25, '#b03a2e', { x: X(9.9), y: 1.09, z: 7.65 }); gb.cyl(0.07, 0.07, 0.22, '#e8e8e8', { x: X(5.9), y: 1.04, z: 7.7, seg: 8 });
  gb.box(0.8, 1.95, 0.75, '#e6e8ea', { x: X(11.5), y: 0.98, z: 5.3 }); gb.box(0.03, 0.5, 0.04, '#9aa1a8', { x: X(11.08), y: 1.3, z: 5.0 }); gb.box(0.82, 0.02, 0.77, '#b9bdc2', { x: X(11.5), y: 1.25, z: 5.3 });
  col(5.4, 10.6, 7.2, 8.0, 1); col(11.05, 12, 4.9, 5.7, 2);
  // stół + krzesła
  gb.box(1.3, 0.05, 0.85, '#6b4a2b', { x: X(6.4), y: 0.76, z: 3.6 }); for (const a of [-0.58, 0.58]) for (const b of [-0.36, 0.36]) gb.box(0.06, 0.74, 0.06, '#3a2a1c', { x: X(6.4) + a, y: 0.37, z: 3.6 + b });
  for (const s of [-1, 1]) { gb.box(0.42, 0.05, 0.42, '#3a2a1c', { x: X(6.4), y: 0.46, z: 3.6 + s * 0.75 }); gb.box(0.42, 0.5, 0.05, '#3a2a1c', { x: X(6.4), y: 0.72, z: 3.6 + s * 0.95 }); for (const a of [-0.18, 0.18]) for (const b of [-0.18, 0.18]) gb.box(0.04, 0.45, 0.04, '#2a1f15', { x: X(6.4) + a, y: 0.23, z: 3.6 + s * 0.75 + b }); }
  gb.box(0.3, 0.02, 0.22, '#c9ced4', { x: X(6.3), y: 0.795, z: 3.6 }); gb.box(0.3, 0.2, 0.02, '#1a1a1c', { x: X(6.3), y: 0.9, z: 3.48, rx: -0.25 });
  col(5.7, 7.1, 3.1, 4.1, 0.8);
  // skrytka (sejf)
  gb.box(0.75, 2.0, 1.4, '#48525c', { x: X(11.55), y: 1.0, z: 1.2 }); gb.box(0.02, 1.8, 1.2, '#39424a', { x: X(11.16), y: 1.0, z: 1.2 }); gb.cyl(0.09, 0.09, 0.05, '#c9ced4', { x: X(11.13), y: 1.1, z: 0.85, rz: Math.PI / 2, seg: 10 }); gb.box(0.03, 0.3, 0.05, '#c9ced4', { x: X(11.13), y: 1.1, z: 1.5 });
  col(11.15, 12, 0.5, 1.9, 2);
  W.inter.push({ loc: 'safe', x: X(10.1), z: 1.2, range: 2.4, label: () => 'Otwórz skrytkę', enabled: () => true, act: () => UI.openStash() });
  // rośliny doniczkowe + pudła
  for (const [px, pz] of [[-11.4, -0.6], [11.4, 7.3], [0.8, 7.3]]) { gb.cyl(0.2, 0.16, 0.35, '#8a5a3a', { x: X(px), y: 0.18, z: pz, seg: 10 }); for (let k = 0; k < 5; k++) gb.sph(0.2, k % 2 ? '#2f7a35' : '#3e9144', { x: X(px) + Math.cos(k * 1.3) * 0.15, y: 0.6 + k * 0.13, z: pz + Math.sin(k * 1.3) * 0.15, ws: 7, hs: 5 }); }
  gb.box(0.6, 0.45, 0.5, '#a07a4a', { x: X(2.2), y: 0.23, z: 7.4 }); gb.box(0.5, 0.4, 0.45, '#a07a4a', { x: X(2.3), y: 0.65, z: 7.45, ry: 0.3 }); gb.box(0.55, 0.4, 0.5, '#8f6c40', { x: X(3.0), y: 0.2, z: 7.35, ry: -0.2 });

  /* --- stanowiska produkcji (ściana północna) --- */
  // doniczki + namiot
  gb.box(6.6, 0.08, 1.3, '#5d5145', { x: X(-3.6), y: 0.82, z: -7.2 }); for (const a of [-3.2, 0, 3.2]) for (const b of [-0.55, 0.55]) gb.box(0.08, 0.8, 0.08, '#3a332b', { x: X(-3.6 + a), y: 0.4, z: -7.2 + b });
  for (const a of [-3.3, 3.3]) for (const b of [-0.62, 0.62]) gb.box(0.05, 2.5, 0.05, '#1c1c1e', { x: X(-3.6 + a), y: 1.25, z: -7.2 + b });
  gb.box(6.7, 0.05, 0.05, '#1c1c1e', { x: X(-3.6), y: 2.5, z: -6.58 }); gb.box(6.7, 0.05, 0.05, '#1c1c1e', { x: X(-3.6), y: 2.5, z: -7.82 });
  gb.box(6.6, 2.5, 0.03, '#c9ced4', { x: X(-3.6), y: 1.25, z: -7.9 });
  gb.box(0.5, 0.5, 0.25, '#2b2b2e', { x: X(-0.5), y: 1.9, z: -7.7 }); gb.cyl(0.2, 0.2, 0.05, '#555', { x: X(-0.5), y: 1.9, z: -7.56, rx: Math.PI / 2, seg: 12 });
  gb.box(0.5, 0.45, 0.35, '#3d6b3a', { x: X(-7.4), y: 0.23, z: -7.4 }); gb.box(0.5, 0.45, 0.35, '#8a6a3c', { x: X(-7.4), y: 0.68, z: -7.4 });
  col(-7.0, -0.2, -8, -6.5, 1.0);
  const led = new THREE.Mesh(new THREE.BoxGeometry(6.2, 0.06, 0.7), new THREE.MeshBasicMaterial({ color: new THREE.Color(3.4, 0.7, 3.8) })); led.position.set(X(-3.6), 2.42, -7.2); g.add(led);
  W.stationViz.doniczki = [];
  const leafG = (() => { const lb = new GB(); for (let k = 0; k < 7; k++) { const a = k * 0.9; lb.cone(0.07, 0.75, k % 2 ? '#2f8f3c' : '#3fa04a', { x: Math.cos(a) * 0.14, y: 0.4 + (k % 3) * 0.05, z: Math.sin(a) * 0.14, rz: Math.cos(a) * 0.5, rx: Math.sin(a) * 0.5, seg: 5 }); } lb.cyl(0.02, 0.03, 0.5, '#4a7a3a', { y: 0.25, seg: 5 }); lb.sph(0.09, '#7fb85a', { y: 0.75, ws: 6, hs: 5 }); return lb.build(); })();
  for (let i = 0; i < 5; i++) {
    const px = X(-6.2 + i * 1.3), pg = new THREE.Group(); pg.position.set(px, 0.86, -7.2); g.add(pg);
    const pot = new GB(); pot.cyl(0.26, 0.2, 0.36, '#8b4513', { y: 0.18, seg: 12 }); pot.cyl(0.24, 0.24, 0.03, '#2a1c12', { y: 0.35, seg: 12 });
    pg.add(GFX.meshFromGB(pot));
    const plant = new THREE.Mesh(leafG, mat('#ffffff', { vc: true, rough: 0.8, key: 'leaf' })); plant.position.y = 0.36; plant.scale.setScalar(0.01); plant.castShadow = true; pg.add(plant);
    W.stationViz.doniczki.push({ group: pg, plant });
  }
  W.inter.push({ loc: 'safe', x: X(-3.6), z: -5.5, range: 2.9, label: () => 'Doniczki — Zielony Dym', enabled: () => true, act: () => UI.openStation('doniczki') });

  // stół reakcyjny
  gb.box(3.6, 0.9, 1.2, '#8f959d', { x: X(2.6), y: 0.45, z: -7.3 }); gb.box(3.7, 0.04, 1.26, '#2f3338', { x: X(2.6), y: 0.92, z: -7.3 });
  gb.box(3.6, 0.1, 0.9, '#6b7178', { x: X(2.6), y: 2.3, z: -7.45 }); gb.box(0.08, 1.4, 0.9, '#6b7178', { x: X(0.84), y: 1.6, z: -7.45 }); gb.box(0.08, 1.4, 0.9, '#6b7178', { x: X(4.36), y: 1.6, z: -7.45 });
  gb.cyl(0.12, 0.12, 0.9, '#9aa1a8', { x: X(3.9), y: 2.8, z: -7.5, seg: 10 });
  gb.box(0.3, 0.12, 0.3, '#1f1f22', { x: X(1.4), y: 1.0, z: -7.2 }); gb.box(0.5, 0.3, 0.3, '#d9d4c8', { x: X(4.0), y: 1.09, z: -7.6 });
  col(0.7, 4.5, -8, -6.6, 1.0);
  W.stationViz.reaktor = { liquids: [], cover: null, flame: null };
  const glassM = mat('#cfe3ee', { rough: 0.05, metal: 0.1, transparent: true, opacity: 0.35, env: 2.0, key: 'labglass' });
  for (let i = 0; i < 4; i++) {
    const fx = X(1.5 + i * 0.75);
    const fl = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.24, 0.5, 14), glassM); fl.position.set(fx, 1.2, -7.3); g.add(fl);
    const nk = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.1, 0.25, 10), glassM); nk.position.set(fx, 1.56, -7.3); g.add(nk);
    const liq = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.21, 0.3, 14), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.25, 1.4, 3.2) })); liq.position.set(fx, 1.1, -7.3); liq.visible = false; g.add(liq);
    W.stationViz.reaktor.liquids.push({ liq, fl, nk });
  }
  W.stationViz.reaktor.cover = box(g, 3.9, 2.1, 1.4, '#4a5340', X(2.6), 0, -7.3, false, { rough: 1 });
  W.inter.push({ loc: 'safe', x: X(2.6), z: -5.5, range: 2.6, label: () => G.S.up.reaktor ? 'Stół reakcyjny — Niebieski Szron' : 'Zakryty stół (kup: telefon → Sklep)', enabled: () => true, act: () => G.S.up.reaktor ? UI.openStation('reaktor') : UI.toast('Ten stół jest jeszcze zakryty. Kup go w telefonie → Sklep.', 'warn') });

  // prasa
  gb.box(1.6, 1.0, 1.1, '#5a5e66', { x: X(6.7), y: 0.5, z: -7.35 }); gb.box(1.7, 0.06, 1.2, '#2f3338', { x: X(6.7), y: 1.03, z: -7.35 });
  gb.box(0.25, 1.3, 0.25, '#3d4046', { x: X(6.1), y: 1.7, z: -7.6 }); gb.box(0.25, 1.3, 0.25, '#3d4046', { x: X(7.3), y: 1.7, z: -7.6 }); gb.box(1.5, 0.25, 0.4, '#3d4046', { x: X(6.7), y: 2.35, z: -7.6 });
  gb.cyl(0.14, 0.14, 0.7, '#c9ced4', { x: X(6.7), y: 1.85, z: -7.6, seg: 12 }); gb.cone(0.3, 0.4, '#8a8f98', { x: X(7.2), y: 1.5, z: -7.1, rx: Math.PI, seg: 12 });
  gb.box(0.6, 0.04, 0.4, '#9aa1a8', { x: X(6.7), y: 1.08, z: -7.1 });
  col(5.8, 7.6, -8, -6.7, 1.1);
  W.stationViz.prasa = { cover: null };
  W.stationViz.prasa.light = new THREE.Mesh(new THREE.SphereGeometry(0.06, 8, 6), new THREE.MeshBasicMaterial({ color: 0x222222 })); W.stationViz.prasa.light.position.set(X(6.1), 1.2, -6.78); g.add(W.stationViz.prasa.light);
  W.stationViz.prasa.cover = box(g, 2.0, 2.6, 1.4, '#4a5340', X(6.7), 0, -7.3, false, { rough: 1 });
  W.inter.push({ loc: 'safe', x: X(6.7), z: -5.6, range: 2.5, label: () => G.S.up.prasa ? 'Prasa — Neon' : 'Zakryta maszyna (kup: telefon → Sklep)', enabled: () => true, act: () => G.S.up.prasa ? UI.openStation('prasa') : UI.toast('Ta maszyna jest jeszcze zakryta. Kup ją w telefonie → Sklep.', 'warn') });

  // laboratorium (ściana wschodnia)
  gb.box(1.1, 0.9, 3.4, '#e4e6e8', { x: X(11.35), y: 0.45, z: -4.6 }); gb.box(1.16, 0.04, 3.46, '#22262b', { x: X(11.35), y: 0.92, z: -4.6 });
  gb.box(0.3, 1.5, 3.4, '#cfd3d7', { x: X(11.8), y: 1.9, z: -4.6 }); for (let k = 0; k < 6; k++) gb.cyl(0.05, 0.05, 0.2, ['#c0392b', '#2980b9', '#f1c40f'][k % 3], { x: X(11.6), y: 1.5, z: -6.0 + k * 0.55, seg: 8 });
  col(10.75, 12, -6.35, -2.85, 1.0);
  W.stationViz.lab = { cols: [], cover: null };
  for (let i = 0; i < 3; i++) {
    const cg = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.11, 0.9, 12), glassM); cg.position.set(X(11.3), 1.4, -5.6 + i * 1.0); g.add(cg);
    const li = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.6, 12), new THREE.MeshBasicMaterial({ color: new THREE.Color(3.2, 2.2, 0.4) })); li.position.set(X(11.3), 1.28, -5.6 + i * 1.0); li.visible = false; g.add(li);
    W.stationViz.lab.cols.push(li);
  }
  W.stationViz.lab.cover = box(g, 1.3, 2.4, 3.6, '#4a5340', X(11.3), 0, -4.6, false, { rough: 1 });
  W.inter.push({ loc: 'safe', x: X(9.9), z: -4.6, range: 2.5, label: () => G.S.up.lab ? 'Laboratorium — Złoty Pył' : 'Zakryte laboratorium (kup: telefon → Sklep)', enabled: () => true, act: () => G.S.up.lab ? UI.openStation('lab') : UI.toast('Laboratorium jest jeszcze zakryte. Kup je w telefonie → Sklep.', 'warn') });

  g.add(GFX.meshFromGB(gb, { rough: 0.75 }));
  // okno + TV + lampy + plakaty
  const fr = new GB(); fr.box(2.6, 0.08, 0.12, '#f0efe9', { x: X(-4), y: 2.42, z: 7.95 }); fr.box(2.6, 0.08, 0.2, '#f0efe9', { x: X(-4), y: 0.98, z: 7.9 }); fr.box(0.08, 1.5, 0.12, '#f0efe9', { x: X(-5.3), y: 1.7, z: 7.95 }); fr.box(0.08, 1.5, 0.12, '#f0efe9', { x: X(-2.7), y: 1.7, z: 7.95 }); fr.box(0.05, 1.4, 0.1, '#f0efe9', { x: X(-4), y: 1.7, z: 7.95 });
  fr.box(0.5, 1.7, 0.06, '#7c8a9a', { x: X(-5.45), y: 1.7, z: 7.85 }); fr.box(0.5, 1.7, 0.06, '#7c8a9a', { x: X(-2.55), y: 1.7, z: 7.85 }); fr.box(3.6, 0.05, 0.05, '#2b2b2b', { x: X(-4), y: 2.58, z: 7.85 });
  g.add(GFX.meshFromGB(fr));
  const win = new THREE.Mesh(new THREE.PlaneGeometry(2.5, 1.4), new THREE.MeshBasicMaterial({ color: 0x7aa7d6 })); win.position.set(X(-4), 1.7, 7.985); win.rotation.y = Math.PI; g.add(win); W.stationViz.window = win;
  const tv = new THREE.Mesh(new THREE.PlaneGeometry(1.3, 0.7), new THREE.MeshBasicMaterial({ color: 0x224466 })); tv.position.set(X(-11.58), 1.1, 3.4); tv.rotation.y = Math.PI / 2; g.add(tv); W.stationViz.tv = tv;
  for (const p of R.lights) ceilLamp(g, cx + p[0], h, p[1], 0.3);
  const p1 = signPlane('NIGDY\nWIĘCEJ\nDŁUGÓW', 1.3, 1.5, '#16161a', '#e74c3c', 'bold 62px sans-serif', false, 0.9); p1.position.set(X(11.99), 1.9, 3.4); p1.rotation.y = -Math.PI / 2; g.add(p1);
  const p2 = signPlane('MIASTO\nNIE ŚPI', 1.2, 1.0, '#101820', '#f1c40f', 'bold 70px sans-serif', false, 0.9); p2.position.set(X(1.5), 1.9, 7.99); p2.rotation.y = Math.PI; g.add(p2);
}

/* ---------------- HURTOWNIA ---------------- */
function buildShop() {
  const R = W.rooms.shop, cx = R.cx, h = R.h;
  const g = makeRoom('shop', TX.tiles('#6b6e73', '#5c5f64'), '#8a7f6c', '#d9d5cb', { floorTile: 2.4, floorRough: 0.45 });
  R.lights = [[0, -2.5, 1.4], [-5, 2, 1.0], [5, 2, 1.0]];
  const gb = new GB(), rnd = mulberry(404), cols = ['#a16207', '#15803d', '#1d4ed8', '#be123c', '#7c3aed', '#0e7490', '#d9d4c8', '#c2410c'];
  // lada
  gb.box(11, 1.05, 1.2, '#6b4a2b', { x: cx, y: 0.53, z: -1.6 }); gb.box(11.3, 0.07, 1.4, '#26272a', { x: cx, y: 1.09, z: -1.6 }); gb.box(11, 0.9, 0.04, '#553a20', { x: cx, y: 0.5, z: -0.98 });
  for (let k = 0; k < 6; k++) gb.box(0.04, 0.9, 0.05, '#3a2714', { x: cx - 5 + k * 2, y: 0.5, z: -0.96 });
  gb.box(0.45, 0.3, 0.4, '#2b2b2e', { x: cx + 3.5, y: 1.28, z: -1.6 }); gb.box(0.4, 0.26, 0.03, '#0a0a0b', { x: cx + 3.5, y: 1.56, z: -1.45, rx: -0.3 });
  gb.cyl(0.2, 0.2, 0.05, '#9aa1a8', { x: cx - 3.5, y: 1.17, z: -1.6, seg: 14 }); gb.box(0.3, 0.3, 0.06, '#c9ced4', { x: cx - 3.5, y: 1.36, z: -1.85 });
  gb.box(0.5, 0.35, 0.4, '#a07a4a', { x: cx - 1.2, y: 1.3, z: -1.7 }); gb.box(0.25, 0.3, 0.2, '#3d6b3a', { x: cx + 1.0, y: 1.27, z: -1.6 });
  addCol(cx - 5.6, cx + 5.6, -2.25, -0.95, 1.1);
  // regały przy ścianie północnej
  gb.box(15, 2.7, 0.5, '#2a2a2e', { x: cx, y: 1.35, z: -5.7 });
  for (let s = 0; s < 4; s++) {
    gb.box(15, 0.06, 0.75, '#4b4b50', { x: cx, y: 0.3 + s * 0.65, z: -5.2 });
    for (let k = 0; k < 16; k++) { if (rnd() < 0.12) continue; const hh = 0.3 + rnd() * 0.22; gb.box(0.55 + rnd() * 0.2, hh, 0.45, cols[(rnd() * cols.length) | 0], { x: cx - 7 + k * 0.93, y: 0.33 + s * 0.65 + hh / 2, z: -5.2 }); }
  }
  addCol(cx - 7.6, cx + 7.6, -6, -4.8, 2.7);
  // regały boczne i palety
  for (const sx of [-1, 1]) {
    gb.box(0.5, 2.4, 5, '#2a2a2e', { x: cx + sx * 8.7, y: 1.2, z: 1.2 });
    for (let s = 0; s < 3; s++) { gb.box(0.8, 0.06, 5, '#4b4b50', { x: cx + sx * 8.4, y: 0.4 + s * 0.7, z: 1.2 }); for (let k = 0; k < 6; k++) { if (rnd() < 0.2) continue; gb.box(0.55, 0.4, 0.6, cols[(rnd() * cols.length) | 0], { x: cx + sx * 8.4, y: 0.63 + s * 0.7, z: -1.0 + k * 0.85 }); } }
    addCol(cx + sx * 8.95 - 0.6, cx + sx * 8.95 + 0.6, -1.4, 3.8, 2.4);
  }
  for (const [x, z] of [[-6, 3.6], [6.2, 4.2]]) {
    gb.box(1.3, 0.14, 1.1, '#8a6a3c', { x: cx + x, y: 0.07, z });
    for (let k = 0; k < 4; k++) gb.box(0.6, 0.5, 0.5, cols[(k + 2) % cols.length], { x: cx + x - 0.3 + (k % 2) * 0.62, y: 0.4 + Math.floor(k / 2) * 0.5, z: z + (k % 2 ? 0.1 : -0.1) });
    addCol(cx + x - 0.7, cx + x + 0.7, z - 0.6, z + 0.6, 1.2);
  }
  for (let k = 0; k < 3; k++) gb.cyl(0.3, 0.3, 0.9, '#31506b', { x: cx - 7.4 + k * 0.7, y: 0.45, z: 5.3, seg: 12 });
  g.add(GFX.meshFromGB(gb, { rough: 0.8 }));
  for (const p of R.lights) { ceilLamp(g, cx + p[0], h - 0.6, p[1], 0.35); box(g, 0.03, 0.6, 0.03, '#222', cx + p[0], h - 0.6, p[1], false, { noShadow: true }); }
  const neon = signPlane('HURT • DETAL', 4.2, 0.8, '#06140a', '#4ade80', 'bold 62px sans-serif', true, 2.4); neon.position.set(cx, 3.15, -5.43); g.add(neon);
  const tab = signPlane('KUPUJĘ • SPRZEDAJĘ • NIE PYTAM', 5, 0.42, '#141414', '#fbbf24', 'bold 30px sans-serif', false, 1.3); tab.position.set(cx, 1.5, -0.955 + 0.03); tab.position.y = 0.55; g.add(tab);
}

/* ---------------- KLUB ---------------- */
function buildClub() {
  const R = W.rooms.club, cx = R.cx, h = R.h;
  const g = makeRoom('club', TX.tiles('#17171c', '#101014'), '#191222', '#08060c', { floorTile: 2.4, floorRough: 0.2, floorMetal: 0.4, door: '#1a1a1e', base: '#0c0a10' });
  const gb = new GB();
  // parkiet
  for (let i = 0; i < 8; i++) for (let j = 0; j < 6; j++) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(1.22, 1.22), new THREE.MeshBasicMaterial({ color: 0x222233 }));
    m.rotation.x = -Math.PI / 2; m.position.set(cx - 4.4 + i * 1.26, 0.02, -5.2 + j * 1.26); g.add(m); W.clubTiles.push(m);
  }
  gb.box(10.4, 0.03, 0.12, '#c9ced4', { x: cx, y: 0.02, z: -5.9 }); gb.box(10.4, 0.03, 0.12, '#c9ced4', { x: cx, y: 0.02, z: 2.5 });
  // bar (zachód)
  gb.box(1.0, 1.15, 11, '#2a1b3d', { x: cx - 11.6, y: 0.58, z: -1 }); gb.box(1.3, 0.08, 11.3, '#0d0d10', { x: cx - 11.55, y: 1.19, z: -1 });
  gb.box(0.35, 2.6, 11, '#15101c', { x: cx - 13.75, y: 1.3, z: -1 });
  for (let s = 0; s < 3; s++) gb.box(0.4, 0.04, 10.6, '#2a2233', { x: cx - 13.5, y: 1.3 + s * 0.45, z: -1 });
  const br = mulberry(88);
  for (let s = 0; s < 3; s++) for (let k = 0; k < 24; k++) gb.cyl(0.045, 0.05, 0.26 + br() * 0.08, ['#2ecc71', '#f39c12', '#3498db', '#e74c3c', '#ecf0f1', '#9b59b6'][(br() * 6) | 0], { x: cx - 13.5, y: 1.47 + s * 0.45, z: -6 + k * 0.43, seg: 7 });
  for (let k = 0; k < 6; k++) { gb.cyl(0.19, 0.19, 0.06, '#7c1d3b', { x: cx - 10.6, y: 0.8, z: -5 + k * 1.6, seg: 12 }); gb.cyl(0.035, 0.035, 0.78, '#c9ced4', { x: cx - 10.6, y: 0.39, z: -5 + k * 1.6, seg: 6 }); gb.cyl(0.2, 0.2, 0.03, '#c9ced4', { x: cx - 10.6, y: 0.02, z: -5 + k * 1.6, seg: 10 }); }
  addCol(cx - 12.15, cx - 11.05, -6.5, 4.5, 1.2); addCol(cx - 14, cx - 13.5, -6.5, 4.5, 2.6);
  // DJ + głośniki
  gb.box(4.4, 1.1, 1.4, '#16161a', { x: cx, y: 0.75, z: -9.6 }); gb.box(5.4, 0.2, 2.4, '#0d0d10', { x: cx, y: 0.1, z: -9.5 });
  gb.cyl(0.32, 0.32, 0.05, '#2b2b2e', { x: cx - 1.1, y: 1.33, z: -9.6, seg: 16 }); gb.cyl(0.32, 0.32, 0.05, '#2b2b2e', { x: cx + 1.1, y: 1.33, z: -9.6, seg: 16 }); gb.box(0.7, 0.08, 0.6, '#3a3a40', { x: cx, y: 1.34, z: -9.6 });
  addCol(cx - 2.8, cx + 2.8, -10.8, -8.3, 1.4);
  W.speakers = [];
  for (const sx of [-1, 1]) {
    const sg = new GB(); sg.box(1.4, 2.6, 1.1, '#0c0c0e', { y: 1.3 }); sg.cyl(0.5, 0.5, 0.06, '#1f1f23', { y: 0.8, z: 0.56, rx: Math.PI / 2, seg: 18 }); sg.cyl(0.3, 0.3, 0.07, '#3a3a40', { y: 0.8, z: 0.57, rx: Math.PI / 2, seg: 14 }); sg.cyl(0.36, 0.36, 0.06, '#1f1f23', { y: 1.9, z: 0.56, rx: Math.PI / 2, seg: 16 }); sg.cyl(0.2, 0.2, 0.07, '#3a3a40', { y: 1.9, z: 0.57, rx: Math.PI / 2, seg: 12 });
    const sm = GFX.meshFromGB(sg, { rough: 0.5 }); sm.position.set(cx + sx * 4.4, 0, -9.7); g.add(sm); W.speakers.push(sm);
    addCol(cx + sx * 4.4 - 0.75, cx + sx * 4.4 + 0.75, -10.3, -9.1, 2.6);
  }
  // loża VIP (płn.-wsch.)
  gb.box(4.6, 0.45, 1.1, '#7c1d3b', { x: cx + 10, y: 0.23, z: -9.8 }); gb.box(4.6, 0.7, 0.3, '#651730', { x: cx + 10, y: 0.75, z: -10.25 });
  gb.box(1.1, 0.45, 3.2, '#7c1d3b', { x: cx + 12.9, y: 0.23, z: -8.1 }); gb.box(0.3, 0.7, 3.2, '#651730', { x: cx + 13.35, y: 0.75, z: -8.1 });
  gb.cyl(0.55, 0.55, 0.05, '#0d0d10', { x: cx + 10.2, y: 0.55, z: -8.1, seg: 18 }); gb.cyl(0.08, 0.3, 0.52, '#c9ced4', { x: cx + 10.2, y: 0.27, z: -8.1, seg: 10 });
  gb.cyl(0.04, 0.04, 0.16, '#f1c40f', { x: cx + 10.0, y: 0.66, z: -8.2, seg: 6 }); gb.cyl(0.05, 0.03, 0.12, '#ecf0f1', { x: cx + 10.4, y: 0.64, z: -7.95, seg: 6 });
  for (const x of [7.4, 9.2, 11.0]) gb.cyl(0.04, 0.05, 0.95, '#e3b93a', { x: cx + x, y: 0.48, z: -6.1, seg: 8 });
  gb.box(3.6, 0.05, 0.05, '#8a1c2c', { x: cx + 9.2, y: 0.85, z: -6.1 });
  addCol(cx + 7.7, cx + 12.3, -10.4, -9.25, 0.9); addCol(cx + 12.35, cx + 13.5, -9.7, -6.5, 0.9); addCol(cx + 9.6, cx + 10.8, -8.7, -7.5, 0.6); addCol(cx + 7.3, cx + 11.1, -6.2, -6.0, 1.0);
  // boksy przy ścianie wschodniej
  for (let k = 0; k < 3; k++) { const z = -2 + k * 3.6; gb.box(1.0, 0.45, 2.4, '#3a2a55', { x: cx + 13.3, y: 0.23, z }); gb.box(0.25, 0.7, 2.4, '#2e2145', { x: cx + 13.75, y: 0.75, z }); gb.cyl(0.4, 0.4, 0.05, '#0d0d10', { x: cx + 12.0, y: 0.7, z, seg: 14 }); gb.cyl(0.05, 0.22, 0.68, '#c9ced4', { x: cx + 12.0, y: 0.35, z, seg: 8 }); addCol(cx + 12.8, cx + 14, z - 1.25, z + 1.25, 0.9); addCol(cx + 11.6, cx + 12.4, z - 0.4, z + 0.4, 0.75); }
  // kratownica
  for (const z of [-6, 2]) gb.box(22, 0.18, 0.18, '#2b2b2e', { x: cx, y: h - 0.5, z });
  for (const x of [-9, 0, 9]) gb.box(0.18, 0.18, 8.2, '#2b2b2e', { x: cx + x, y: h - 0.5, z: -2 });
  g.add(GFX.meshFromGB(gb, { rough: 0.55, metal: 0.25 }));
  // ruchome głowy + stożki światła
  for (let k = 0; k < 4; k++) {
    const pv = new THREE.Group(); pv.position.set(cx - 6.6 + k * 4.4, h - 0.65, k % 2 ? -6 : 2); g.add(pv);
    const head = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.2, 0.34, 10), new THREE.MeshBasicMaterial({ color: 0xffffff })); pv.add(head);
    const cg = new THREE.ConeGeometry(1.5, 5.4, 18, 1, true); cg.translate(0, -2.7, 0);
    const cone = new THREE.Mesh(cg, new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.11, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false })); pv.add(cone);
    W.clubLights.push({ cone, head });
  }
  const ball = new THREE.Mesh(new THREE.IcosahedronGeometry(0.55, 1), new THREE.MeshStandardMaterial({ color: 0xffffff, metalness: 1, roughness: 0.12, flatShading: true, emissive: 0x222233 })); ball.position.set(cx, h - 1.0, -2); g.add(ball); W.discoBall = ball;
  box(g, 0.03, 0.5, 0.03, '#888', cx, h - 0.5, -2, false, { noShadow: true });
  const sign = signPlane('NEON', 6, 1.8, '#0f0518', '#ff3bd0', 'bold 150px sans-serif', true, 3.2); sign.position.set(cx, 3.3, -10.97); g.add(sign);
  const back = new THREE.Mesh(new THREE.PlaneGeometry(0.06, 10.6), new THREE.MeshBasicMaterial({ color: new THREE.Color(3.2, 0.5, 2.6) })); back.rotation.z = Math.PI / 2; back.rotation.y = Math.PI / 2; back.position.set(cx - 13.55, 1.22, -1); g.add(back);
  for (const [x, z, c] of [[cx - 13.97, -1, new THREE.Color(2.6, 0.3, 2.2)], [cx + 13.97, 0, new THREE.Color(0.3, 1.6, 2.8)]]) { const st = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.06, 18), new THREE.MeshBasicMaterial({ color: c })); st.position.set(x, h - 0.4, z); g.add(st); }
}

/* ---------------- BIURO MYJNI ---------------- */
function buildWash() {
  const R = W.rooms.wash, cx = R.cx, h = R.h;
  const g = makeRoom('wash', TX.tiles('#8a949d', '#78828b'), '#7f939f', '#c8ccd0', { floorTile: 2, floorRough: 0.3 });
  R.lights = [[0, -1, 0.9]];
  const gb = new GB();
  gb.box(2.4, 0.06, 1.1, '#d9d4c8', { x: cx, y: 0.76, z: -2.2 }); gb.box(0.08, 0.74, 1.0, '#8a8f98', { x: cx - 1.1, y: 0.37, z: -2.2 }); gb.box(0.08, 0.74, 1.0, '#8a8f98', { x: cx + 1.1, y: 0.37, z: -2.2 });
  gb.box(0.5, 0.34, 0.03, '#0a0a0b', { x: cx - 0.3, y: 1.05, z: -2.4, rx: -0.15 }); gb.box(0.12, 0.12, 0.12, '#222', { x: cx - 0.3, y: 0.82, z: -2.4 }); gb.box(0.4, 0.02, 0.15, '#1a1a1c', { x: cx - 0.3, y: 0.8, z: -2.0 });
  gb.box(0.3, 0.02, 0.4, '#f5f5f5', { x: cx + 0.6, y: 0.8, z: -2.1 }); gb.cyl(0.05, 0.04, 0.12, '#c0392b', { x: cx + 0.95, y: 0.85, z: -2.5, seg: 8 });
  addCol(cx - 1.25, cx + 1.25, -2.8, -1.6, 0.9);
  gb.box(0.9, 1.2, 0.8, '#3a444d', { x: cx + 5.4, y: 0.6, z: -4.4 }); gb.cyl(0.12, 0.12, 0.05, '#c9ced4', { x: cx + 5.4, y: 0.7, z: -3.98, rx: Math.PI / 2, seg: 12 });
  addCol(cx + 4.9, cx + 6, -4.9, -3.9, 1.2);
  gb.box(0.4, 2.0, 3.0, '#d0d4d8', { x: cx - 5.7, y: 1.0, z: -1 });
  const r = mulberry(31); for (let s = 0; s < 4; s++) for (let k = 0; k < 7; k++) gb.cyl(0.08, 0.08, 0.26, ['#3498db', '#e74c3c', '#f1c40f', '#2ecc71'][(r() * 4) | 0], { x: cx - 5.5, y: 0.3 + s * 0.48, z: -2.2 + k * 0.4, seg: 8 });
  addCol(cx - 6, cx - 5.4, -2.6, 0.6, 2);
  gb.cyl(0.2, 0.16, 0.35, '#8a5a3a', { x: cx + 5.4, y: 0.18, z: 3.6, seg: 10 }); for (let k = 0; k < 5; k++) gb.sph(0.22, k % 2 ? '#2f7a35' : '#3e9144', { x: cx + 5.4 + Math.cos(k * 1.3) * 0.15, y: 0.6 + k * 0.14, z: 3.6 + Math.sin(k * 1.3) * 0.15, ws: 7, hs: 5 });
  gb.box(0.5, 0.45, 0.5, '#2b2b2e', { x: cx, y: 0.46, z: -3.3 }); gb.box(0.5, 0.6, 0.08, '#2b2b2e', { x: cx, y: 0.95, z: -3.55 });
  g.add(GFX.meshFromGB(gb, { rough: 0.6, metal: 0.1 }));
  ceilLamp(g, cx, h, -1, 0.4, new THREE.Color(3.0, 3.1, 3.3));
  const win = new THREE.Mesh(new THREE.PlaneGeometry(4, 1.3), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.5, 1.2, 1.8) })); win.position.set(cx, 1.9, -4.985); g.add(win);
  const s1 = signPlane('MYJNIA KRYSZTAŁ', 3.6, 0.6, '#06202e', '#38bdf8', 'bold 48px sans-serif', true, 2.0); s1.position.set(cx, 2.85, -4.98); g.add(s1);
  const s2 = signPlane('UCZCIWY BIZNES\nOD 1998', 1.4, 0.9, '#f5f5f5', '#1f2a33', 'bold 46px sans-serif', false, 0.9); s2.position.set(cx - 5.99, 2.4, 2.5); s2.rotation.y = Math.PI / 2; g.add(s2);
}
