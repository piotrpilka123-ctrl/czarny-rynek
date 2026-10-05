'use strict';
/* ============================================================
   PĘTLA GŁÓWNA: start, sterowanie, kamera, nawigacja, dźwięk przestrzenny
   ============================================================ */

Object.assign(G, {
  /* ---------- start / menu ---------- */
  async startGame(fromSave) {
    Snd.init();
    $('title').classList.add('hidden');
    await UI.fade(true);
    NPC.clearOrders(); Nav.clear();
    for (const c of NPC.cops.slice()) if (c.post) NPC.removeCop(c);
    let S = fromSave ? G.load() : null;
    const fresh = !S; if (!S) S = G.newState();
    G.S = S;
    const P = G.player, R = W.rooms.safe;
    if (S.pos && !fresh) { P.loc = S.pos.loc; P.x = S.pos.x; P.z = S.pos.z; P.yaw = S.pos.yaw; }
    else { P.loc = 'safe'; P.x = R.cx - 3.6; P.z = 0.5; P.yaw = 0; }
    P.pitch = 0; P.stamina = G.maxStamina(); P.y = P.loc === 'out' ? W.groundY(P.x, P.z) : 0;
    W.setLocation(P.loc); W.rain = 0; W.rainTarget = 0; W.wet = 0;
    for (const o of S.orders) if (o.status === 'accepted' && !CUSTOMERS.find(c => c.id === o.cust).clubOnly) NPC.spawnCustomer(o);
    if (fresh) { G.onDay(); S.t = 8 * 60; S.msgs = []; S.unread = 0; S.weather = null; }
    if (S.weather) W.rainTarget = (S.t >= S.weather.start && S.t < S.weather.end) ? S.weather.power : 0;
    NPC.syncCrew(); G.updateStationViz(); G.syncStoryNpcs();
    G.running = true; G.busy = false; G.arresting = false; G.navDirty = true; G.zoneName = ''; G.zone = null;
    $('hud').classList.remove('hidden');
    await UI.fade(false);
    UI.mode = null;
    if (fresh) G.intro(); else { G.requestLock(); UI.toast('Witaj z powrotem. Dzień ' + G.day() + '.'); }
  },
  toMenu() {
    if (G.running) G.save(false);
    G.running = false; Snd.sirenOff(); Nav.clear();
    UI.closeAll(); $('hud').classList.add('hidden'); $('pause').classList.add('hidden'); $('ending').classList.add('hidden');
    UI.mode = 'title'; $('title').classList.remove('hidden'); $('btnContinue').disabled = !G.hasSave();
  },
  pause() {
    if (!G.running || UI.isOpen() || G.busy) return;
    UI.setMode('pause'); $('pause').classList.remove('hidden');
    $('btnMute').textContent = Snd.muted ? '🔇 Dźwięk: wył.' : '🔊 Dźwięk: wł.';
  },
  resume() { $('pause').classList.add('hidden'); UI.closeAll(); },
  requestLock() {
    if (!G.running || UI.isOpen() || G.noLock) return;
    const c = W.renderer.domElement;
    try { const p = c.requestPointerLock(); if (p && p.catch) p.catch(() => G.showClick()); } catch (e) { G.showClick(); }
    setTimeout(() => { if (G.running && !UI.isOpen() && !document.pointerLockElement) G.showClick(); }, 350);
  },
  showClick() { if (G.running && !UI.isOpen() && !G.noLock) $('clickToPlay').classList.remove('hidden'); },

  /* ---------- wejścia / wyjścia / sen ---------- */
  async enter(id) {
    if (G.busy) return; G.busy = true;
    const P = G.player;
    await UI.fade(true); Snd.door();
    P.loc = id; W.setLocation(id);
    const R = W.rooms[id];
    P.x = R.exit[0]; P.z = R.exit[1] - 1.7; P.yaw = 0; P.pitch = 0; P.y = 0;
    if (NPC.anyChase() || G.S.wanted) { NPC.endChase(); G.S.wanted = false; Snd.sirenOff(); G.S.stats.escapes++; G.addXp(20); G.addInvest(2); UI.toast('Zgubiłeś pościg, chowając się w budynku.', 'good'); }
    G.navDirty = true;
    await sleep(120); await UI.fade(false);
    G.busy = false;
  },
  async exit() {
    if (G.busy) return; G.busy = true;
    const P = G.player, id = P.loc, d = W.doors[id];
    await UI.fade(true); Snd.door();
    P.loc = 'out'; W.setLocation('out');
    P.x = d.x; P.z = d.z + (d.rotY === 0 ? 0.6 : -0.6); P.yaw = d.rotY === 0 ? Math.PI : 0; P.pitch = 0; P.y = W.groundY(P.x, P.z);
    if (id === 'safe') G.S.flags.leftHome = true;
    G.navDirty = true;
    await sleep(120); await UI.fade(false);
    G.busy = false;
  },
  async sleep() {
    if (G.busy) return; G.busy = true;
    await UI.fade(true);
    const delta = Math.max(60, ((7 * 60 - G.minute()) + 1440) % 1440);
    G.addMinutes(delta); G.addHeat(-20, false);
    G.player.stamina = G.maxStamina();
    G.save(true); G.updateStationViz();
    UI.toast('😴 Dobrze spałeś. Dzień ' + G.day() + ', ' + G.clock() + '.', 'good');
    await sleep(500); await UI.fade(false);
    G.busy = false;
  },

  /* ---------- cele i nawigacja ---------- */
  trackKey() { return G.S.track == null ? 'obj' : String(G.S.track); },
  setTrack(v) { G.S.track = v === 'obj' ? null : (/^\d+$/.test(v) ? +v : v); G.S.navOn = true; G.navDirty = true; },
  navTargets() {
    const S = G.S, out = [{ id: 'obj', label: '🎯 Cel fabularny' }];
    for (const o of S.orders) if (o.status === 'accepted') out.push({ id: o.id, label: '👤 ' + UI.orderLabel(o) + ' — ' + UI.spotName(o) });
    out.push({ id: 'safe', label: '🏠 Dom' }, { id: 'shop', label: '🛒 Hurtownia' });
    if (S.flags.ch2) out.push({ id: 'club', label: '🎵 Klub Neon' });
    if (S.flags.wiesioTip || S.flags.wiesio) out.push({ id: 'wash', label: '🚿 Myjnia' });
    return out;
  },
  cycleTrack() {
    const T = G.navTargets(), i = T.findIndex(t => String(t.id) === G.trackKey());
    const n = T[(i + 1) % T.length]; G.setTrack(String(n.id));
    UI.toast('🧭 Cel: ' + n.label);
  },
  rawTarget() {
    const S = G.S, tr = S.track;
    if (typeof tr === 'number') {
      const o = S.orders.find(x => x.id === tr);
      if (!o) { S.track = null; return G.rawTarget(); }
      if (o.spot === 'club') return { loc: 'club', x: NPC.madame.x - 1.2, z: NPC.madame.z + 1.6, label: 'Madame K', color: '#fbbf24' };
      if (o.story === 'FIN') return { loc: 'out', x: 96, z: -22, label: 'Księgowy — Parking', color: '#fbbf24' };
      const n = NPC.customers.find(c => c.order.id === o.id), sp = SPOTS.find(s => s.id === o.spot);
      return { loc: 'out', x: n ? n.x : sp.x, z: n ? n.z : sp.z, label: UI.orderLabel(o) + ' — ' + sp.name, color: '#fbbf24' };
    }
    if (typeof tr === 'string' && W.rooms[tr]) { const R = W.rooms[tr]; return { loc: tr, x: R.exit[0], z: R.exit[1] - 2.5, label: R.name, color: '#60a5fa' }; }
    const cur = STORY[S.step], m = cur && cur.marker ? cur.marker() : null;
    return m ? Object.assign({ label: 'Cel', color: '#4ade80' }, m) : null;
  },
  mapTarget(m) {
    if (!m) return null; const P = G.player;
    if (P.loc === m.loc) return { x: m.x, z: m.z, loc: P.loc, color: m.color, label: m.label };
    if (P.loc === 'out') { const d = W.doors[m.loc]; return d ? { x: d.x, z: d.z, loc: 'out', color: m.color, label: m.label } : null; }
    const R = W.rooms[P.loc]; return { x: R.exit[0], z: R.exit[1], loc: P.loc, color: m.color, label: m.label + ' (wyjdź)' };
  },
  targets() { const t = G.mapTarget(G.rawTarget()); return t ? [t] : []; },
  updateNav() {
    const S = G.S, P = G.player, t = G.mapTarget(G.rawTarget());
    if (!t) { Nav.clear(); G.navInfo = null; return; }
    const direct = Math.hypot(t.x - P.x, t.z - P.z);
    let path = null;
    if (S.navOn && direct > 3.5) path = P.loc === 'out' ? Nav.find(P.x, P.z, t.x, t.z) : [[P.x, P.z], [t.x, t.z]];
    if (path) Nav.set(path, t.color); else Nav.clear();
    G.navInfo = { label: t.label, dist: path ? Nav.length : direct, color: t.color };
  },
  updateBeacon() {
    const t = G.targets()[0];
    if (!G.beacon) {
      G.beacon = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 80, 12, 1, true), new THREE.MeshBasicMaterial({ color: 0x4ade80, transparent: true, opacity: 0.22, depthWrite: false, side: THREE.DoubleSide, fog: false, blending: THREE.AdditiveBlending }));
      G.diamond = new THREE.Mesh(new THREE.OctahedronGeometry(0.2), new THREE.MeshBasicMaterial({ color: 0x4ade80, depthTest: false, transparent: true, opacity: 0.9, fog: false }));
      G.diamond.renderOrder = 11; W.scene.add(G.beacon); W.scene.add(G.diamond);
    }
    G.beacon.visible = G.diamond.visible = false;
    if (!t || G.busy) return;
    const c = lin(t.color).multiplyScalar(1.8);
    if (G.player.loc === 'out') { G.beacon.visible = true; G.beacon.position.set(t.x, 40, t.z); G.beacon.material.color.copy(c); }
    else { G.diamond.visible = true; G.diamond.position.set(t.x, 2.5, t.z); G.diamond.material.color.copy(c); }
  },

  interactCandidate() {
    const P = G.player, fx = -Math.sin(P.yaw), fz = -Math.cos(P.yaw);
    let best = null, bd = 1e9;
    for (const it of W.inter) {
      if (it.loc !== P.loc || !it.enabled()) continue;
      const dx = it.x - P.x, dz = it.z - P.z, d = Math.hypot(dx, dz);
      if (d > it.range) continue;
      if (d > 1.4 && (dx * fx + dz * fz) / d < 0.15) continue;
      if (d < bd) { bd = d; best = { label: it.label(), act: it.act, d }; }
    }
    const n = NPC.nearestInteract(P.x, P.z, fx, fz, P.loc);
    if (n) { const d = Math.hypot(n.x - P.x, n.z - P.z); if (d < bd) best = { label: n.interact.label(), act: n.interact.act, d }; }
    return best;
  },

  helpHtml() {
    return `<div><b>WASD</b> ruch &nbsp; <b>Mysz</b> rozglądanie (lub strzałki) &nbsp; <b>Shift</b> sprint</div><div><b>E</b> interakcja &nbsp; <b>Tab</b> telefon (SMS-y, mapa, sklep, finanse)</div><div><b>N</b> trasa do celu wł./wył. &nbsp; <b>Q</b> następny cel</div><div><b>F</b> latarka &nbsp; <b>M</b> dźwięk &nbsp; <b>Esc</b> pauza</div>
      <div style="margin-top:8px;color:#94a3b8">Produkuj towar, odpowiadaj na SMS-y, targuj się, unikaj policji i prowokacji, pierz pieniądze i spłacaj dług w terminie.</div>`;
  },

  /* ---------- aktualizacja świata ---------- */
  update(dt) {
    const S = G.S, P = G.player;
    G.now += dt;
    G.addMinutes(dt * TIME_SCALE);
    if (!G.busy) {
      const k = G.keys;
      P.yaw += ((k.ArrowLeft ? 1 : 0) - (k.ArrowRight ? 1 : 0)) * 1.9 * dt;
      P.pitch = clamp(P.pitch + ((k.ArrowUp ? 1 : 0) - (k.ArrowDown ? 1 : 0)) * 1.4 * dt, -1.45, 1.45);
      const mx = (k.KeyD ? 1 : 0) - (k.KeyA ? 1 : 0), mz = (k.KeyS ? 1 : 0) - (k.KeyW ? 1 : 0), moving = mx || mz;
      const fx = -Math.sin(P.yaw), fz = -Math.cos(P.yaw), rx = Math.cos(P.yaw), rz = -Math.sin(P.yaw);
      let vx = rx * mx - fx * mz, vz = rz * mx - fz * mz; const len = Math.hypot(vx, vz) || 1; vx /= len; vz /= len;
      const ms = G.maxStamina();
      P.sprinting = (k.ShiftLeft || k.ShiftRight) && moving && P.stamina > 0.05 && !P.tired;
      if (P.stamina <= 0.05) P.tired = true; if (P.stamina > ms * 0.3) P.tired = false;
      if (P.sprinting) P.stamina = Math.max(0, P.stamina - dt); else P.stamina = Math.min(ms, P.stamina + dt * (moving ? 0.45 : 0.9) * (G.skill('kondycja', 4) ? 1.4 : 1));
      const sp = P.sprinting ? G.sprintSpeed() : 4.1;
      if (moving) {
        const r = W.resolve(P.x, P.z, 0.4, vx * sp * dt, vz * sp * dt); P.x = r[0]; P.z = r[1];
        P.stepT -= dt; if (P.stepT <= 0) { Snd.step(P.sprinting); P.stepT = P.sprinting ? 0.28 : 0.45; }
        P.bob += dt * (P.sprinting ? 12.5 : 8.2);
      }
      P.moving = !!moving;
      if (P.loc === 'out') { P.x = clamp(P.x, -121, 121); P.z = clamp(P.z, -121, 121); P.y += (W.groundY(P.x, P.z) - P.y) * Math.min(1, dt * 12); }
      else { const R = W.rooms[P.loc]; P.x = clamp(P.x, R.cx - R.w / 2 + 0.4, R.cx + R.w / 2 - 0.4); P.z = clamp(P.z, R.cz - R.d / 2 + 0.4, R.cz + R.d / 2 - 0.4); P.y += (0 - P.y) * Math.min(1, dt * 12); }
    }
    W.updateLighting(G.hour(), P.x, P.z, dt);
    NPC.suspMult = G.computeSusp();
    NPC.update(dt, P);
    Nav.update(dt);

    // uwaga policji
    if (!S.wanted) S.heat = Math.max(0, S.heat - dt * 0.07);
    if (S.wanted && !NPC.anyChase()) {
      G.wantedGrace += dt;
      if (G.wantedGrace > 1.5) { S.wanted = false; Snd.sirenOff(); S.stats.escapes++; G.addXp(25); G.addInvest(3); UI.toast('😮‍💨 Zgubiłeś policję. (+25 PD)', 'good'); G.addHeat(-12, false); }
    }
    G.copT = (G.copT || 0) - dt;
    if (G.copT <= 0) {
      G.copT = 9;
      const patrol = NPC.cops.filter(c => !c.post), target = 3 + (S.heat >= 45 ? 1 : 0) + (S.heat >= 75 ? 1 : 0) + (S.flags.wronaRefused ? 1 : 0) + (W.nightF > 0.6 ? 1 : 0) - (S.flags.wronaPaid ? 1 : 0);
      if (patrol.length < target) NPC.spawnCop(true);
      else if (patrol.length > target + 1) { const far = patrol.find(c => c.state === 'patrol' && Math.hypot(c.x - P.x, c.z - P.z) > 70); if (far) NPC.removeCop(far); }
    }
    // dzielnica
    let zn = null; if (P.loc === 'out') for (const z of W.zones) if (P.x > z.x0 && P.x < z.x1 && P.z > z.z0 && P.z < z.z1) zn = z;
    if (zn !== G.zone) {
      G.zone = zn; G.zoneName = zn ? zn.name : '';
      if (zn && zn.gang && !S.flags.wilkiGone) { const zb = $('zoneBanner'); zb.textContent = zn.name; zb.classList.remove('hidden'); setTimeout(() => zb.classList.add('hidden'), 2600); }
    }
    G.muggingCheck(dt);

    G.sec += dt;
    if (G.sec >= 1) {
      G.sec = 0;
      const st = STORY[S.step]; if (st && st.done()) G.completeStep();
      G.updateStationViz(); G.syncStoryNpcs();
      if (S.weather) W.rainTarget = (S.t >= S.weather.start && S.t < S.weather.end) ? S.weather.power : 0;
    }
    G.navT -= dt;
    if (G.navT <= 0 || G.navDirty) { G.navT = 0.45; G.navDirty = false; G.updateNav(); G.updateBeacon(); }
  },

  frame(ts) {
    requestAnimationFrame(G.frame);
    const dt = Math.min(0.05, (ts - (G.lastTs || ts)) / 1000); G.lastTs = ts;
    const P = G.player, cam = W.camera;
    if (G.running) {
      const open = UI.isOpen();
      if (!open && !G.busy) G.update(dt);
      else W.updateLighting(G.hour(), P.x, P.z, dt * 0.25);
      // kamera
      const bobY = P.moving ? Math.sin(P.bob) * (P.sprinting ? 0.07 : 0.04) : 0, bobX = P.moving ? Math.cos(P.bob * 0.5) * 0.02 : 0;
      G.shake = Math.max(0, G.shake - dt * 1.6);
      const beat = P.loc === 'club' ? Snd.beat() : 0;
      cam.position.set(P.x + Math.cos(P.yaw) * bobX, P.y + 1.64 + bobY, P.z - Math.sin(P.yaw) * bobX);
      cam.rotation.set(P.pitch + (Math.random() - 0.5) * G.shake * 0.03, P.yaw + (Math.random() - 0.5) * G.shake * 0.03, 0);
      const fov = 70 + (P.sprinting ? 5 : 0) + beat * 0.8;
      if (Math.abs(cam.fov - fov) > 0.05) { cam.fov += (fov - cam.fov) * Math.min(1, dt * 8); cam.updateProjectionMatrix(); }
      if (GFX.grade) GFX.grade.uniforms.shake.value = G.shake + (NPC.anyChase() ? 0.25 : 0);
      if (G.debugCam) { cam.position.set(G.debugCam[0], G.debugCam[1], G.debugCam[2]); cam.lookAt(G.debugCam[3], G.debugCam[4], G.debugCam[5]); }
      // podpowiedź interakcji
      const cand = (!open && !G.busy) ? G.interactCandidate() : null; G.cand = cand;
      const pr = $('prompt');
      if (cand) { const html = `<b>E</b>${esc(cand.label)}`; if (pr._h !== html) { pr.innerHTML = html; pr._h = html; } pr.classList.remove('hidden'); } else pr.classList.add('hidden');
      G.hudT -= dt;
      if (G.hudT <= 0) { G.hudT = 0.12; UI.updateHud(); UI.drawMap($('mini'), P.x, P.z, 130, false); }
      if (G.diamond && G.diamond.visible) { G.diamond.rotation.y += dt * 2; G.diamond.position.y = 2.5 + Math.sin(performance.now() * 0.003) * 0.1; }
      W.flash.intensity = (G.flashOn && P.loc === 'out') ? 2.2 : 0;
      // muzyka klubu: głośność zależna od odległości od drzwi
      let cv = 0; const d = W.doors.club;
      if (P.loc === 'club') cv = 1; else if (P.loc === 'out' && d) cv = Math.pow(clamp(1 - Math.hypot(P.x - d.x, P.z - (d.z + 2)) / 62, 0, 1), 1.6) * 0.75;
      Snd.update(dt, { clubVol: open && UI.mode === 'pause' ? 0 : cv, inside: P.loc === 'club', rain: W.rain, indoor: P.loc !== 'out' });
    } else {
      G.menuT += dt * 0.05;
      const R = 92, a = G.menuT;
      if (W.loc !== 'out') W.setLocation('out');
      cam.position.set(Math.cos(a) * R, 34 + Math.sin(a * 0.7) * 5, Math.sin(a) * R); cam.lookAt(0, 9, 0);
      W.updateLighting(18.9, 0, 0, dt);
      if (G.beacon) G.beacon.visible = G.diamond.visible = false;
      Snd.update(dt, { clubVol: 0 });
    }
    if (UI.mode !== 'skill') GFX.render(dt);
  },
});

/* ---------- uruchomienie ---------- */
window.addEventListener('DOMContentLoaded', () => {
  initWorld($('game'));
  Nav.init();
  G.S = G.newState();
  NPC.init();
  UI.init();
  UI.mode = 'title';
  $('btnContinue').disabled = !G.hasSave();
  $('btnNew').onclick = () => { if (G.hasSave() && !confirm('Rozpocząć nową grę? Dotychczasowy zapis zostanie nadpisany.')) return; G.startGame(false); };
  $('btnContinue').onclick = () => G.startGame(true);
  $('btnHelp').onclick = () => $('titleHelp').classList.toggle('show');
  $('btnResume').onclick = () => G.resume();
  $('btnPhonePause').onclick = () => { $('pause').classList.add('hidden'); UI.openPhone(); };
  $('btnSavePause').onclick = () => G.save(true);
  $('btnMute').onclick = () => { Snd.setMuted(!Snd.muted); $('btnMute').textContent = Snd.muted ? '🔇 Dźwięk: wył.' : '🔊 Dźwięk: wł.'; };
  $('btnQuit').onclick = () => G.toMenu();
  $('btnEndMenu').onclick = () => { $('ending').classList.add('hidden'); G.toMenu(); };
  $('helpText').innerHTML = G.helpHtml(); $('helpText').classList.add('show'); $('titleHelp').innerHTML = G.helpHtml();
  $('clickToPlay').onclick = () => { $('clickToPlay').classList.add('hidden'); G.requestLock(); };

  const canvas = W.renderer.domElement;
  canvas.addEventListener('click', () => { if (G.running && !UI.isOpen() && !document.pointerLockElement) G.requestLock(); });
  document.addEventListener('pointerlockchange', () => {
    G.locked = document.pointerLockElement === canvas;
    if (G.noLock) return;
    if (G.locked && UI.isOpen()) { document.exitPointerLock(); return; }
    if (G.locked) $('clickToPlay').classList.add('hidden');
    else if (G.running && !UI.isOpen() && !G.busy && $('clickToPlay').classList.contains('hidden')) G.pause();
  });
  document.addEventListener('mousemove', (e) => {
    if (!G.locked || !G.running || UI.isOpen()) return;
    G.player.yaw -= e.movementX * 0.0022;
    G.player.pitch = clamp(G.player.pitch - e.movementY * 0.0022, -1.45, 1.45);
  });
  document.addEventListener('keydown', (e) => {
    if (e.code === 'Tab' || e.code.startsWith('Arrow') || (e.code === 'Space' && UI.mode)) e.preventDefault();
    const m = UI.mode;
    if (m === 'skill') { if (e.code === 'Space' && !e.repeat) UI.skillPress(e.timeStamp); return; }
    if (e.repeat && ['Tab', 'KeyE', 'KeyF', 'KeyN', 'KeyQ', 'Space', 'Enter', 'KeyM'].includes(e.code)) return;
    G.keys[e.code] = true;
    if (m === 'dialog') { if (e.code === 'Space' || e.code === 'Enter') UI.advance(); else if (/^Digit[1-9]$/.test(e.code)) UI.pickChoice(+e.code.slice(5) - 1); return; }
    if (m === 'phone') { if (e.code === 'Tab' || e.code === 'Escape') UI.closeAll(); return; }
    if (m === 'modal') { if (e.code === 'Escape') { UI.deal ? UI.dealLeave() : UI.closeAll(); } return; }
    if (m === 'pause') { if (e.code === 'Escape') G.resume(); return; }
    if (!G.running || m || G.busy) return;
    if (e.code === 'KeyE' && G.cand) G.cand.act();
    else if (e.code === 'Tab') UI.openPhone(G.S.orders.some(o => o.status === 'new') ? 'sms' : null);
    else if (e.code === 'KeyF') G.flashOn = !G.flashOn;
    else if (e.code === 'KeyN') { G.S.navOn = !G.S.navOn; G.navDirty = true; UI.toast(G.S.navOn ? '🧭 Trasa włączona' : '🧭 Trasa wyłączona'); }
    else if (e.code === 'KeyQ') G.cycleTrack();
    else if (e.code === 'KeyM') { Snd.setMuted(!Snd.muted); UI.toast(Snd.muted ? '🔇 Dźwięk wył.' : '🔊 Dźwięk wł.'); }
  });
  document.addEventListener('keyup', (e) => { G.keys[e.code] = false; if (e.code === 'Space' && UI.mode) e.preventDefault(); });
  window.addEventListener('blur', () => { G.keys = {}; });
  window.addEventListener('beforeunload', () => { if (G.running && G.S && !G.arresting) G.save(false); });
  requestAnimationFrame(G.frame);
  // tryb testowy: ?autostart pomija menu i wstęp
  if (/autostart/.test(location.search)) {
    try { localStorage.removeItem(SAVE_KEY); } catch (e) {}
    G.startGame(false).then(() => {
      for (let i = 0; i < 14 && UI.dlg && !UI.dlg.choices; i++) { clearInterval(UI.typing); UI.dlg.typingDone = true; UI.advance(); }
      G.S.flags.leftHome = true; G.player.loc = 'out'; W.setLocation('out'); G.player.x = 30; G.player.z = -9; G.player.yaw = Math.PI; G.S.t = 12 * 60;
      window.__ready = true;
    });
  }
});
