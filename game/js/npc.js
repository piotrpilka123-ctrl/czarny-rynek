'use strict';
/* ============================================================
   POSTACIE: przechodnie, klienci, policja, NPC fabularni, ruch uliczny
   ============================================================ */

function angDiff(a, b) { let d = a - b; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return d; }

const NPC = {
  all: [], cops: [], citizens: [], customers: [], cars: [], crew: [], suspMult: 0, group: null,

  init() {
    this.group = new THREE.Group(); W.scene.add(this.group);
    for (let i = 0; i < 16; i++) this.spawnCitizen();
    for (let i = 0; i < 3; i++) this.spawnCop();
    this.buildStatic();
    this.initTraffic();
  },

  node(a, b) { return { a, b, x: W.lat[a], z: W.lat[b] }; },
  randNode() { return this.node((Math.random() * 6) | 0, (Math.random() * 6) | 0); },

  /* ---------- przechodnie ---------- */
  rollIdentity(n) {
    n.female = n.p ? n.female : Math.random() < 0.45;
    n.name = pick(n.female ? FIRST_NAMES_F : FIRST_NAMES_M);
    n.user = Math.random() < 0.44; n.wealth = rr(0.7, 1.3); n.loyalty = 0; n.lastDeal = null; n.refused = false; n.sting = false; n.stingRolled = false;
  },
  spawnCitizen() {
    const nd = this.randNode(), female = Math.random() < 0.45;
    const p = Models.person({ female, bag: Math.random() < 0.18 ? pick(['#3a2a1e', '#22324a', '#5a1f1f']) : null, hat: Math.random() < 0.14 ? pick(['cap', 'beanie']) : null, glasses: Math.random() < 0.12, beard: !female && Math.random() < 0.2 });
    this.group.add(p.group);
    const n = { kind: 'citizen', loc: 'out', p, mesh: p.group, female, x: nd.x, z: nd.z, a: nd.a, b: nd.b, pa: -1, pb: -1, tx: nd.x, tz: nd.z, rot: 0, speed: rr(1.15, 1.7), idle: rr(0, 3), state: 'walk', talkT: 0, pose: null, idlePose: Math.random() < 0.3 ? 'phone' : (Math.random() < 0.15 ? 'smoke' : null), reroll: rr(60, 160) };
    this.rollIdentity(n);
    const ic = Models.label('👀', '#fde68a', 0.42); ic.position.set(0, p.height + 0.32, 0); ic.visible = false; p.group.add(ic); n.icon = ic;
    n.interact = { label: () => 'Zagadać: ' + n.name, range: 2.7, act: () => G.approachCitizen(n) };
    this.pickNext(n);
    this.citizens.push(n); this.all.push(n);
    return n;
  },
  pickNext(n, weighted) {
    const opts = [];
    for (const [da, db] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const a = n.a + da, b = n.b + db;
      if (a < 0 || a > 5 || b < 0 || b > 5) continue;
      if (a === n.pa && b === n.pb && Math.random() < 0.9) continue;
      opts.push([a, b]);
    }
    let o = opts.length ? pick(opts) : [n.pa, n.pb];
    if (weighted && opts.length > 1) {
      // policja chętniej patroluje „gorące” okolice
      let tot = 0; const ws = opts.map(op => { const w = 1 + G.zoneHeatAt(W.lat[op[0]], W.lat[op[1]]) / 18; tot += w; return w; });
      let r = Math.random() * tot; for (let i = 0; i < opts.length; i++) { r -= ws[i]; if (r <= 0) { o = opts[i]; break; } }
    }
    n.pa = n.a; n.pb = n.b; n.a = o[0]; n.b = o[1];
    n.tx = W.lat[n.a] + rr(-1.1, 1.1); n.tz = W.lat[n.b] + rr(-1.1, 1.1);
  },

  /* ---------- policja ---------- */
  spawnCop(atKomisariat) {
    const p = Models.person({ female: Math.random() < 0.25, top: { type: 'uniform', color: '#7fa3d1' }, bottom: { type: 'pants', color: '#101a33' }, shoes: '#0a0a0a', hat: 'police', face: 'stern', hair: 'short', height: rr(1.76, 1.9) });
    this.group.add(p.group);
    const nd = this.randNode();
    const c = { kind: 'cop', loc: 'out', p, mesh: p.group, x: nd.x, z: nd.z, a: nd.a, b: nd.b, pa: -1, pb: -1, tx: nd.x, tz: nd.z, rot: 0, speed: 1.4, state: 'patrol', side: 1, susp: 0, lookT: Math.random() * 0.2, sees: false, lastSeen: 0, idle: 0, inv: null, searchT: 0, pose: null };
    if (atKomisariat) { c.x = -30 + rr(-4, 4); c.z = -79; c.a = 1; c.b = 0; }
    const al = Models.label('!', '#ef4444', 0.8); al.position.set(0, p.height + 0.45, 0); al.visible = false; p.group.add(al); c.alert = al;
    this.pickNext(c);
    this.cops.push(c); this.all.push(c);
    return c;
  },
  removeCop(c) {
    const i = this.cops.indexOf(c); if (i >= 0) this.cops.splice(i, 1);
    const k = this.all.indexOf(c); if (k >= 0) this.all.splice(k, 1);
    this.group.remove(c.mesh);
  },

  /* ---------- NPC stali ---------- */
  addStatic(o, x, z, rot, loc, name, extra) {
    const p = Models.person(o);
    p.group.position.set(x, loc === 'out' ? W.groundY(x, z) : 0, z); p.group.rotation.y = rot || 0;
    this.group.add(p.group);
    const n = Object.assign({ kind: 'static', loc, p, mesh: p.group, x, z, rot: rot || 0, name, static: true, pose: null, by: p.group.position.y }, extra || {});
    if (name) { const l = Models.label(name, '#fde68a', 0.9); l.position.set(0, (n.pose === 'sit' ? 1.45 : p.height + 0.3), 0); p.group.add(l); n.label = l; }
    this.all.push(n); return n;
  },
  buildStatic() {
    const R = W.rooms;
    this.stasiu = this.addStatic({ female: false, top: { type: 'jacket', color: '#5b3a1e', color2: '#c9b89a' }, bottom: { type: 'pants', color: '#2b2622' }, hair: 'short', hairColor: '#9a9a9a', beard: '#9a9a9a', skin: '#e0b088', glasses: true, build: 1.12, height: 1.76 }, R.shop.cx, -3.3, 0, 'shop', 'Wujek Staś', { track: true });
    this.stasiu.interact = { label: () => 'Porozmawiaj: Wujek Staś', range: 3.4, act: () => G.talkStasiu() };
    this.madame = this.addStatic({ female: true, top: { type: 'dress', color: '#b01e3c' }, hair: 'long', hairColor: '#c9a13a', skin: '#f1c9a5', height: 1.7, face: 'smile', chain: true }, R.club.cx + 10.0, -9.75, 0, 'club', 'Madame K', { pose: 'sit', track: true });
    this.madame.interact = { label: () => 'Porozmawiaj: Madame K', range: 3.6, act: () => G.talkMadame() };
    this.addStatic({ female: false, top: { type: 'shirt', color: '#111111' }, bottom: { type: 'pants', color: '#111' }, hair: 'buzz' }, R.club.cx - 12.75, -1, Math.PI / 2, 'club', null, { pose: 'lean' });
    for (const x of [28.4, 31.6]) this.addStatic({ female: false, top: { type: 'suit', color: '#0b0b0d', color2: '#0b0b0d' }, bottom: { type: 'pants', color: '#0b0b0d' }, hair: 'bald', build: 1.3, height: 1.92, face: 'stern', earpiece: true }, x, 12.9, Math.PI, 'out', null, { pose: 'arms' });
    for (let i = 0; i < 9; i++) {
      const x = R.club.cx - 3.8 + (i % 4) * 2.4 + rr(-0.4, 0.4), z = -4.4 + Math.floor(i / 4) * 2.3 + rr(-0.3, 0.3), female = Math.random() < 0.55;
      const d = this.addStatic({ female, top: { type: pick(['tank', 'tshirt', 'dress', 'shirt']), color: pick(['#ec4899', '#22d3ee', '#facc15', '#a78bfa', '#34d399', '#f5f5f5', '#111111']) }, bottom: { type: female ? pick(['skirt', 'jeans', 'shorts']) : 'jeans', color: pick(BOTC) } }, x, z, rr(0, 6), 'club', null, { pose: 'dance', dancer: true, female, bx: x, bz: z });
      this.rollIdentity(d); d.user = Math.random() < 0.75; d.wealth = rr(1.0, 1.5);
      d.interact = { label: () => 'Zagadać: ' + d.name, range: 2.4, act: () => G.approachCitizen(d, true) };
    }
    for (const [x, z, pose] of [[-98, 86, 'smoke'], [-87, 99, 'arms'], [-103, 99, 'lean'], [-90, 82, 'phone']])
      this.addStatic({ female: false, top: { type: 'hoodie', color: '#1c1917' }, bottom: { type: 'pants', color: '#0c0a09' }, hat: 'hood', face: 'stern', hair: 'buzz' }, x, z, rr(0, 6), 'out', null, { thug: true, pose, track: true });
    this.kruk = this.addStatic({ female: false, top: { type: 'jacket', color: '#3a0d0d', color2: '#111' }, bottom: { type: 'pants', color: '#0c0a09' }, hair: 'buzz', beard: true, build: 1.2, height: 1.9, face: 'stern', chain: true }, -93, 93, 0, 'out', 'Kruk', { track: true });
    this.kruk.interact = { label: () => 'Porozmawiaj: Kruk (Wilki)', range: 3.2, act: () => G.talkKruk() };
    this.wrona = this.addStatic({ female: false, top: { type: 'coat', color: '#2b2622', color2: '#8a8f98' }, bottom: { type: 'pants', color: '#1c1917' }, hair: 'short', hairColor: '#666666', face: 'stern', height: 1.84 }, 82, -42, Math.PI, 'out', 'Insp. Wrona', { track: true, pose: 'smoke' });
    this.wrona.interact = { label: () => 'Porozmawiaj: Inspektor Wrona', range: 3.2, act: () => G.talkWrona() };
    this.hide(this.wrona, true);
    this.hier = this.addStatic({ female: false, top: { type: 'coat', color: '#3a3f2e', color2: '#222' }, bottom: { type: 'pants', color: '#222' }, hat: 'beanie', hatColor: '#222222', beard: true, glasses: true, bag: '#2a2a2a' }, -84, -96, 0.6, 'out', 'Pan Hieronim', { track: true });
    this.hier.interact = { label: () => 'Porozmawiaj: Pan Hieronim', range: 3.2, act: () => G.talkHieronim() };
    this.hide(this.hier, true);
    this.wiesio = this.addStatic({ female: false, top: { type: 'shirt', color: '#38bdf8' }, bottom: { type: 'pants', color: '#1f2a33' }, hair: 'bald', hairColor: '#888', beard: '#888888', build: 1.25, height: 1.72, face: 'smile' }, R.wash.cx, -3.4, 0, 'wash', 'Pan Wiesio', { track: true });
    this.wiesio.interact = { label: () => 'Porozmawiaj: Pan Wiesio', range: 3.6, act: () => G.talkWiesio() };
    this.ksiegowy = this.addStatic({ female: false, top: { type: 'suit', color: '#1a1f2b', color2: '#f5f5f5' }, bottom: { type: 'pants', color: '#0b0f19' }, hair: 'short', hairColor: '#17130f', glasses: true, height: 1.8, face: 'smile', watch: true }, 96, -22, Math.PI * 0.75, 'out', 'Księgowy', { track: true });
    this.ksiegowy.interact = { label: () => 'Porozmawiaj: Księgowy', range: 3.2, act: () => G.talkKsiegowy() };
    this.hide(this.ksiegowy, true);
  },
  hide(n, h) { n.hidden = h; n.mesh.visible = !h; },

  /* dilerzy gracza stojący w swoich punktach */
  syncCrew() {
    for (const c of this.crew) { this.group.remove(c.mesh); const k = this.all.indexOf(c); if (k >= 0) this.all.splice(k, 1); }
    this.crew.length = 0;
    (G.S.crew || []).forEach((d, i) => {
      if (!d.spot || d.jail) return;
      const sp = SPOTS.find(s => s.id === d.spot); if (!sp) return;
      const n = this.addStatic({ female: false, top: { type: 'hoodie', color: ['#1f6f78', '#6d2f2f', '#3d3d42'][i % 3] }, hat: 'cap' }, sp.x + 2.2 + i * 0.4, sp.z + 1.6, rr(0, 6), 'out', 'Diler: ' + d.name.split(' ')[0], { pose: 'phone', track: true, crewIdx: i });
      n.interact = { label: () => 'Pogadaj: ' + d.name, range: 2.8, act: () => G.talkDealer(i) };
      this.crew.push(n);
    });
  },

  /* ---------- klienci umówieni na spotkanie ---------- */
  spawnCustomer(order) {
    const def = CUSTOMERS.find(c => c.id === order.cust);
    if (def.clubOnly || this.customers.some(c => c.order.id === order.id)) return null;
    const spot = SPOTS.find(s => s.id === order.spot);
    const p = Models.person(Object.assign({}, def.look || {}));
    const x = spot.x + rr(-1.0, 1.0), z = spot.z + rr(-1.0, 1.0);
    p.group.position.set(x, W.groundY(x, z), z); this.group.add(p.group);
    const l = Models.label(def.name, '#fde68a', 0.9); l.position.set(0, p.height + 0.3, 0); p.group.add(l);
    const mk = new THREE.Mesh(new THREE.OctahedronGeometry(0.2), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.5, 2.6, 1.0), depthTest: false, transparent: true, fog: false }));
    mk.position.set(0, p.height + 0.85, 0); mk.renderOrder = 9; p.group.add(mk);
    const n = { kind: 'customer', loc: 'out', p, mesh: p.group, x, z, rot: rr(0, 6), order, def, marker: mk, name: def.name, idle: 0, pose: Math.random() < 0.5 ? 'phone' : null };
    n.interact = { label: () => 'Porozmawiaj: ' + def.name, range: 3.0, act: () => G.dealWithCustomer(n) };
    this.customers.push(n); this.all.push(n);
    return n;
  },
  removeCustomer(orderId) {
    const i = this.customers.findIndex(c => c.order.id === orderId); if (i < 0) return;
    const n = this.customers[i]; this.group.remove(n.mesh); this.customers.splice(i, 1);
    const k = this.all.indexOf(n); if (k >= 0) this.all.splice(k, 1);
  },
  clearOrders() {
    for (const n of this.customers.slice()) { this.group.remove(n.mesh); const k = this.all.indexOf(n); if (k >= 0) this.all.splice(k, 1); }
    this.customers.length = 0; this.endChase();
  },

  nearestInteract(px, pz, fx, fz, loc) {
    let best = null, bd = 1e9;
    for (const n of this.all) {
      if (!n.interact || n.loc !== loc || n.hidden) continue;
      const dx = n.x - px, dz = n.z - pz, d = Math.hypot(dx, dz);
      if (d > n.interact.range) continue;
      if (d > 0.9 && (dx * fx + dz * fz) / d < 0.25) continue;
      if (d < bd) { bd = d; best = n; }
    }
    return best;
  },

  /* ---------- policja: pościgi ---------- */
  dispatchTo(x, z, n) {
    const cs = this.cops.filter(c => c.state === 'patrol' || c.state === 'search').sort((a, b) => Math.hypot(a.x - x, a.z - z) - Math.hypot(b.x - x, b.z - z));
    for (let i = 0; i < Math.min(n || 2, cs.length); i++) { cs[i].state = 'investigate'; cs[i].inv = { x, z }; cs[i].alert.visible = true; }
  },
  startChase(c) {
    if (c.state === 'chase') return;
    c.state = 'chase'; c.alert.visible = true; c.lastSeen = G.now; c.inv = { x: G.player.x, z: G.player.z };
    G.onChaseStart(c);
    for (const o of this.cops) if (o !== c && o.state !== 'chase' && !o.post && Math.hypot(o.x - c.x, o.z - c.z) < 50) { o.state = 'chase'; o.lastSeen = G.now; o.alert.visible = true; o.inv = { x: G.player.x, z: G.player.z }; }
  },
  snapToNode(c) {
    let bi = 0, bj = 0, bd = 1e9;
    for (let a = 0; a < 6; a++) for (let b = 0; b < 6; b++) { const d = Math.hypot(W.lat[a] - c.x, W.lat[b] - c.z); if (d < bd) { bd = d; bi = a; bj = b; } }
    c.a = bi; c.b = bj; c.pa = -1; c.pb = -1; this.pickNext(c);
  },
  endChase() {
    for (const c of this.cops) if (c.state !== 'patrol' && c.state !== 'post') { c.state = c.post ? 'post' : 'patrol'; c.susp = 0; c.alert.visible = false; c.inv = null; if (!c.post) this.snapToNode(c); }
  },
  anyChase() { return this.cops.some(c => c.state === 'chase'); },
  citizensNear(x, z, r, needLos) {
    let n = 0;
    for (const c of this.citizens) if (c.state !== 'talk' && Math.hypot(c.x - x, c.z - z) < r && (!needLos || W.los(c.x, c.z, x, z))) n++;
    return n;
  },

  /* ---------- aktualizacja ---------- */
  update(dt, P) {
    const outside = P.loc === 'out', showIcons = outside && G.S.flags.metStasiu && G.carryCount() > 0 && !G.S.wanted;
    const iconR = 16 + G.skill('biznes', 2) * 14;
    for (const n of this.citizens) {
      n.mesh.visible = outside; if (!outside) continue;
      const dp = Math.hypot(P.x - n.x, P.z - n.z);
      n.reroll -= dt;
      if (n.reroll <= 0) { n.reroll = rr(70, 180); if (dp > 55 && n.state !== 'talk') this.rollIdentity(n); }
      n.icon.visible = showIcons && n.user && dp < iconR && !(n.lastDeal && G.S.t - n.lastDeal < 240) && !n.refused;
      let sp = 0, pose = null;
      if (n.state === 'talk') {
        n.talkT -= dt; if (n.talkT <= 0) n.state = 'walk';
        n.mesh.rotation.y += angDiff(Math.atan2(P.x - n.x, P.z - n.z), n.mesh.rotation.y) * Math.min(1, dt * 6); pose = 'talk';
      } else if (n.idle > 0) { n.idle -= dt; pose = n.idlePose; }
      else {
        const dx = n.tx - n.x, dz = n.tz - n.z, d = Math.hypot(dx, dz);
        if (d < 0.35) { if (Math.random() < 0.2) n.idle = rr(2, 7); this.pickNext(n); }
        else { sp = n.speed * (W.rain > 0.3 ? 1.35 : 1); n.x += dx / d * sp * dt; n.z += dz / d * sp * dt; n.rot = Math.atan2(dx, dz); }
        n.mesh.rotation.y += angDiff(n.rot, n.mesh.rotation.y) * Math.min(1, dt * 8);
      }
      n.mesh.position.set(n.x, W.groundY(n.x, n.z), n.z);
      if (dp < 75) Models.animate(n.p, dt, sp, pose);
    }
    for (const n of this.customers) {
      n.mesh.visible = outside; if (!outside) continue;
      const dp = Math.hypot(P.x - n.x, P.z - n.z);
      n.idle -= dt; if (n.idle <= 0) { n.idle = rr(2, 5); n.rot = dp < 14 ? Math.atan2(P.x - n.x, P.z - n.z) : n.rot + rr(-1.2, 1.2); }
      n.mesh.rotation.y += angDiff(n.rot, n.mesh.rotation.y) * Math.min(1, dt * 3);
      if (dp < 75) Models.animate(n.p, dt, 0, dp < 5 ? 'talk' : n.pose);
      n.marker.rotation.y += dt * 2; n.marker.position.y = n.p.height + 0.85 + Math.sin(G.now * 3) * 0.08;
    }
    for (const n of this.all) {
      if (n.kind !== 'static') continue;
      const vis = n.loc === P.loc && !n.hidden;
      n.mesh.visible = vis; if (!vis) continue;
      const dp = Math.hypot(P.x - n.x, P.z - n.z);
      if (n.track && dp < 10 && n.pose !== 'sit') n.mesh.rotation.y += angDiff(Math.atan2(P.x - n.x, P.z - n.z), n.mesh.rotation.y) * Math.min(1, dt * 3);
      if (n.dancer) { n.mesh.rotation.y += Math.sin(G.now * 0.7 + n.bx) * dt * 0.6; }
      if (dp < 60) Models.animate(n.p, dt, 0, (n.track && dp < 3.6 && n.pose !== 'sit' && n.interact) ? 'talk' : n.pose, G.now);
      if (n.pose === 'sit') n.mesh.position.y = n.by - 0.08;
    }
    this.updateCops(dt, P);
    this.updateTraffic(dt, P);
  },

  updateCops(dt, P) {
    const outside = P.loc === 'out', mult = this.suspMult;
    const range = (27 - W.nightF * 6 - W.rain * 5) * G.copRange();
    for (const c of this.cops) {
      c.mesh.visible = outside; if (!outside) continue;
      const dx = P.x - c.x, dz = P.z - c.z, dist = Math.hypot(dx, dz);
      c.lookT -= dt;
      if (c.lookT <= 0) {
        c.lookT = 0.2;
        const ang = Math.abs(angDiff(Math.atan2(dx, dz), c.mesh.rotation.y));
        const inCone = dist < 6 || ang < 1.05;
        c.sees = dist < range && inCone && W.los(c.x, c.z, P.x, P.z);
        if (c.state === 'chase' && dist < range * 1.4 && W.los(c.x, c.z, P.x, P.z)) c.sees = true;
      }
      let moveSpeed = 0, tgt = null, pose = null;
      if (c.state === 'patrol' || c.state === 'post') {
        if (c.sees && mult > 0) c.susp += mult * dt * (dist < 10 ? 1.6 : 0.8) * 0.65; else c.susp = Math.max(0, c.susp - dt * 0.3);
        c.alert.visible = c.susp > 0.25; if (c.alert.visible) c.alert.material.color.setRGB(2.4, 1.8, 0.3);
        if (c.susp >= 1) this.startChase(c);
        if (c.state === 'post') { c.mesh.rotation.y += Math.sin(G.now * 0.4 + c.x) * dt * 0.5; pose = 'arms'; }
        else if (c.idle > 0) { c.idle -= dt; }
        else {
          const ddx = c.tx - c.x, ddz = c.tz - c.z, d = Math.hypot(ddx, ddz);
          if (d < 0.4) { if (Math.random() < 0.15) c.idle = rr(2, 6); this.pickNext(c, true); }
          else { moveSpeed = c.speed; tgt = [c.tx, c.tz]; }
        }
      } else if (c.state === 'investigate') {
        if (c.sees && mult > 0) c.susp += mult * dt * 1.2; if (c.susp >= 1) this.startChase(c);
        const d = Math.hypot(c.inv.x - c.x, c.inv.z - c.z);
        if (d < 3) { c.state = 'search'; c.searchT = 14; } else { moveSpeed = 3.8; tgt = [c.inv.x, c.inv.z]; }
      } else if (c.state === 'search') {
        c.searchT -= dt; c.mesh.rotation.y += dt * 1.5;
        if (c.sees && mult > 0) { c.susp += mult * dt; if (c.susp >= 1) this.startChase(c); }
        if (c.searchT <= 0) { c.state = c.post ? 'post' : 'patrol'; c.susp = 0; c.alert.visible = false; if (!c.post) this.snapToNode(c); }
      } else if (c.state === 'chase') {
        c.alert.visible = true; c.alert.material.color.setRGB(3, 0.3, 0.3);
        if (c.sees) { c.lastSeen = G.now; c.inv = { x: P.x, z: P.z }; }
        if (G.now - c.lastSeen > G.loseTime()) { c.state = 'search'; c.searchT = 7; }
        else {
          if (!c.inv) c.inv = { x: P.x, z: P.z };
          const ex = (c.sees ? P.x : c.inv.x) - c.x, ez = (c.sees ? P.z : c.inv.z) - c.z;
          if (Math.hypot(ex, ez) > 0.5) { moveSpeed = 5.7 + Math.min(1, G.S.heat / 100) * 0.5; tgt = [c.x + ex, c.z + ez]; }
        }
        if (c.sees && dist < 1.5) G.arrest(c);
      }
      if (tgt) {
        const ddx = tgt[0] - c.x, ddz = tgt[1] - c.z, d = Math.hypot(ddx, ddz) || 1;
        let face = Math.atan2(ddx, ddz);
        if (c.state === 'chase' || c.state === 'investigate') {
          const step = moveSpeed * dt, base = Math.atan2(ddz, ddx);
          const offs = c.side > 0 ? [0, 0.5, 1.0, 1.6, 2.3, -0.5, -1.0, -1.6] : [0, -0.5, -1.0, -1.6, -2.3, 0.5, 1.0, 1.6];
          let moved = false;
          for (const off of offs) {
            const a = base + off, r = W.resolve(c.x, c.z, 0.35, Math.cos(a) * step, Math.sin(a) * step);
            if (Math.hypot(r[0] - c.x, r[1] - c.z) > step * 0.7) { c.x = r[0]; c.z = r[1]; face = Math.PI / 2 - a; if (off !== 0) c.side = off > 0 ? 1 : -1; moved = true; break; }
          }
          if (!moved) c.side = -(c.side || 1);
        } else { c.x += ddx / d * moveSpeed * dt; c.z += ddz / d * moveSpeed * dt; }
        c.mesh.rotation.y += angDiff(face, c.mesh.rotation.y) * Math.min(1, dt * 7);
      }
      c.mesh.position.set(c.x, W.groundY(c.x, c.z), c.z);
      if (dist < 90) Models.animate(c.p, dt, moveSpeed, pose);
    }
  },

  /* ---------- RUCH ULICZNY (siatka 3×3 skrzyżowań) ---------- */
  initTraffic() {
    this.headMat = new THREE.MeshBasicMaterial({ map: TX.glow(), transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false, fog: false });
    const hg = new THREE.PlaneGeometry(4.2, 9); hg.rotateX(-Math.PI / 2);
    for (let i = 0; i < 8; i++) {
      const g = Models.car(pick(['sedan', 'hatch', 'suv', 'sedan', 'van', 'hatch']), pick(CARCOLS));
      const hl = new THREE.Mesh(hg, this.headMat); hl.position.set(0, 0.06, 6.2); g.add(hl);
      this.group.add(g);
      const fi = (Math.random() * 3) | 0, fj = (Math.random() * 3) | 0;
      const car = { g, from: [fi, fj], to: null, s: 0, v: rr(6, 9), vmax: rr(7.5, 10.5), x: 0, z: 0, rot: 0, horn: 0 };
      this.nextSeg(car, true); car.s = rr(8, 40);
      const p = this.carPos(car); car.x = p[0]; car.z = p[1]; car.rot = p[2];
      this.cars.push(car);
    }
  },
  nextSeg(car, first) {
    const cur = first ? car.from : car.to, prev = first ? null : car.from, opts = [];
    for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const i = cur[0] + di, j = cur[1] + dj; if (i < 0 || i > 2 || j < 0 || j > 2) continue;
      if (prev && i === prev[0] && j === prev[1]) continue;
      opts.push([i, j]);
    }
    const nx = pick(opts);
    car.from = cur; car.to = nx; car.s = 0;
    car.len = 60; car.dx = nx[0] - cur[0]; car.dz = nx[1] - cur[1]; car.axis = car.dx !== 0 ? 'ew' : 'ns';
  },
  carPos(car) {
    const ax = W.roadsX[car.from[0]], az = W.roadsZ[car.from[1]];
    const x = ax + car.dx * car.s - car.dz * 2.8, z = az + car.dz * car.s + car.dx * 2.8;
    return [x, z, Math.atan2(car.dx, car.dz)];
  },
  updateTraffic(dt, P) {
    const outside = P.loc === 'out';
    this.headMat.opacity = W.nightF * 0.5;
    const light = W.tl;
    for (const car of this.cars) {
      car.g.visible = outside; if (!outside) continue;
      let target = car.vmax;
      // światła: stop przed pasami
      const stopS = car.len - 11.5;
      if (car.s < stopS && light[car.axis] !== 'g') { const d = stopS - car.s; if (d < 16) target = Math.min(target, Math.max(0, (d - 0.6) * 1.1)); }
      // inne auta przed nami
      for (const o of this.cars) {
        if (o === car) continue;
        const ddx = o.x - car.x, ddz = o.z - car.z, fwd = ddx * car.dx + ddz * car.dz, lat = Math.abs(-ddx * car.dz + ddz * car.dx);
        if (fwd > 0 && fwd < 9.5 && lat < 2.2) target = Math.min(target, Math.max(0, (fwd - 6) * 1.5));
      }
      // gracz na drodze
      if (outside) {
        const ddx = P.x - car.x, ddz = P.z - car.z, fwd = ddx * car.dx + ddz * car.dz, lat = Math.abs(-ddx * car.dz + ddz * car.dx);
        if (fwd > -1 && fwd < 10 && lat < 1.9) { target = Math.min(target, Math.max(0, (fwd - 4.2) * 1.6)); car.horn -= dt; if (fwd < 6 && car.horn <= 0) { Snd.horn(); car.horn = 4; } }
        const d = Math.hypot(ddx, ddz);
        if (d < 1.9 && car.v > 0.5) { P.x += ddx / (d || 1) * (1.9 - d); P.z += ddz / (d || 1) * (1.9 - d); }
      }
      car.v += clamp(target - car.v, -14 * dt, 4.5 * dt); car.v = Math.max(0, car.v);
      car.s += car.v * dt;
      if (car.s >= car.len) this.nextSeg(car);
      const p = this.carPos(car);
      const k = Math.min(1, dt * 5);
      car.x += (p[0] - car.x) * k; car.z += (p[1] - car.z) * k; car.rot += angDiff(p[2], car.rot) * Math.min(1, dt * 4);
      car.g.position.set(car.x, 0.02, car.z); car.g.rotation.y = car.rot;
    }
  },
};
