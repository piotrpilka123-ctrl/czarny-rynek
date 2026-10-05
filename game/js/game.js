'use strict';
/* ============================================================
   LOGIKA GRY (rdzeń): stan, czas, ekwipunek, zamówienia, sprzedaż,
   produkcja, policja, finanse, ekipa, zdarzenia, zapis
   ============================================================ */

const SAVE_KEY = 'czarnyrynek_save_v2';
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const pad2 = (n) => String(n).padStart(2, '0');
const money = (n) => Math.round(n).toLocaleString('pl-PL') + ' zł';

const G = {
  S: null, now: 0, running: false, busy: false, locked: false,
  player: { x: 0, z: 0, y: 0.14, yaw: 0, pitch: 0, loc: 'safe', stamina: 5, sprinting: false, bob: 0, stepT: 0, moving: false },
  keys: {}, zoneName: '', zone: null, arresting: false, wantedGrace: 0, sec: 0, hudT: 0, flashOn: false, menuT: 0, navIdx: 0, navT: 0, shake: 0,
  noLock: /nolock/.test(location.search),

  /* ---------- stan ---------- */
  newState() {
    const prod = () => { const o = {}; for (const p in PRODUCTS) o[p] = [0, 0, 0, 0]; return o; };
    const cust = {}; CUSTOMERS.forEach(c => cust[c.id] = { unlocked: false, loy: 0, deals: 0, sat: 60, tol: {}, declines: 0 });
    const jobs = {}; for (const id in STATIONS) jobs[id] = new Array(STATIONS[id].max).fill(null);
    const demand = {}; for (const p in PRODUCTS) demand[p] = 1;
    return {
      v: 2, t: 8 * 60, cash: 180, bank: 0, debt: START_DEBT, paid: 0, rep: 0, heat: 0, invest: 0, strikes: 0, arrests: 0,
      step: 0, flags: {}, inv: { ing: {}, prod: prod() }, stash: { ing: {}, prod: prod(), cash: 0 }, jobs, up: {}, skills: {}, xp: 0, lvl: 1, sp: 0,
      cust, orders: [], nextOrderId: 1, msgs: [], unread: 0, track: null, navOn: true, wanted: false,
      demand, ingMult: 1, news: '', zheat: {}, crew: [], mods: {}, weather: null, washQ: 0, washDone: 0,
      stats: { earned: 0, sold: 0, batchesStarted: 0, batchesCollected: 0, deals: 0, walked: 0, bribes: 0, escapes: 0, laundered: 0, spoiled: 0, byProd: {} },
      pos: null,
    };
  },

  /* ---------- czas ---------- */
  day() { return Math.floor(G.S.t / 1440) + 1; },
  minute() { return G.S.t % 1440; },
  hour() { return G.minute() / 60; },
  clock(t) { const m = Math.floor((t == null ? G.S.t : t) % 1440); return pad2(Math.floor(m / 60)) + ':' + pad2(m % 60); },
  isNight() { const h = G.hour(); return h >= 21 || h < 5; },
  addMinutes(m) {
    let left = m;
    while (left > 0) {
      const step = Math.min(left, 10); left -= step;
      const prev = G.S.t; G.S.t += step;
      if (Math.floor(prev / 60) !== Math.floor(G.S.t / 60)) G.onHour();
      if (Math.floor(prev / 1440) !== Math.floor(G.S.t / 1440)) G.onDay();
    }
  },

  /* ---------- podstawy ---------- */
  lvl(id) { return G.S.up[id] || 0; },
  sk(id) { return G.S.skills[id] || 0; },
  skill(id, n) { return (G.S.skills[id] || 0) >= n ? 1 : 0; },
  slots(id) { return Math.min(STATIONS[id].max, STATIONS[id].slots + G.lvl('sloty')); },
  cap() { return [20, 36, 56][G.lvl('plecak')]; },
  carryCount() { let n = 0; for (const p in G.S.inv.prod) for (const c of G.S.inv.prod[p]) n += c; return n; },
  carryValue() { let v = 0; for (const p in G.S.inv.prod) G.S.inv.prod[p].forEach((c, q) => v += c * PRODUCTS[p].base * QMULT[q]); return v; },
  stashCount(p) { return G.S.stash.prod[p].reduce((a, b) => a + b, 0); },
  addProduct(p, q, n) {
    const room = G.cap() - G.carryCount(), put = Math.max(0, Math.min(room, n)), rest = n - put;
    G.S.inv.prod[p][q] += put;
    if (rest > 0) { G.S.stash.prod[p][q] += rest; UI.toast(`Plecak pełny — ${rest} szt. trafiło do skrytki.`, 'warn'); }
  },
  removeProduct(p, q, n) { G.S.inv.prod[p][q] = Math.max(0, G.S.inv.prod[p][q] - n); },
  ingPrice(k) { const d = [0, 0.05, 0.05, 0.05, 0.05, 0.15][G.sk('biznes')]; return Math.max(1, Math.round(INGREDIENTS[k].price * G.S.ingMult * (1 - d) * (G.mod('supply') ? 1.3 : 1))); },
  repTitle() { const r = G.S.rep; return r < 12 ? 'Pionek' : r < 35 ? 'Diler' : r < 70 ? 'Handlarz' : r < 120 ? 'Szef ulicy' : 'Król miasta'; },
  netWorth() { return G.S.cash + G.S.stash.cash + G.S.bank; },
  funds(clean) { return clean ? G.S.bank : G.S.cash + G.S.bank; },
  pay(cost, clean) {
    const S = G.S; if (G.funds(clean) < cost) return false;
    if (clean) S.bank -= cost; else { const c = Math.min(S.cash, cost); S.cash -= c; S.bank -= (cost - c); }
    return true;
  },
  mod(id) { return G.S.mods[id] && G.S.mods[id] > G.S.t; },
  setMod(id, hours) { G.S.mods[id] = G.S.t + hours * 60; },

  msg(from, text, quiet) {
    G.S.msgs.unshift({ from, text, day: G.day(), time: G.clock() });
    if (G.S.msgs.length > 60) G.S.msgs.length = 60;
    G.S.unread = (G.S.unread || 0) + 1;
    if (!quiet) { UI.toast('💬 ' + from + ': ' + (text.length > 74 ? text.slice(0, 72) + '…' : text)); Snd.sms(); }
  },

  /* ---------- doświadczenie i umiejętności ---------- */
  xpNeed(l) { return 90 + l * 70; },
  addXp(n) {
    const S = G.S; S.xp += n;
    while (S.xp >= G.xpNeed(S.lvl)) { S.xp -= G.xpNeed(S.lvl); S.lvl++; S.sp++; UI.toast(`⬆️ Poziom ${S.lvl}! Punkt umiejętności do rozdania (telefon → Umiejętności).`, 'good'); Snd.level(); }
  },
  learn(id) {
    const S = G.S; if (S.sp <= 0 || G.sk(id) >= 5) return;
    S.sp--; S.skills[id] = G.sk(id) + 1; Snd.good();
    UI.toast(`🧠 ${SKILLS.find(s => s.id === id).name} ${S.skills[id]}: ${SKILLS.find(s => s.id === id).desc[S.skills[id] - 1]}`, 'good');
  },
  maxStamina() { return 4 + [0, 1.2, 1.2, 2.4, 2.4, 3.6][G.sk('kondycja')]; },
  sprintSpeed() { return 6.7 * (1 + [0, 0, 0.05, 0.05, 0.05, 0.1][G.sk('kondycja')]); },

  /* ---------- uwaga policji: globalna + lokalna (dzielnice) + śledztwo ---------- */
  blockOf(x, z) {
    const idx = (v) => { let b = 0, bd = 1e9; for (let i = 0; i < 4; i++) { const c = (BLK[i][0] + BLK[i][1]) / 2, d = (v >= BLK[i][0] && v <= BLK[i][1]) ? 0 : Math.abs(v - c); if (d < bd) { bd = d; b = i; } } return b; };
    return 'z' + idx(x) + idx(z);
  },
  zoneHeatAt(x, z) { return (G.S && G.S.zheat[G.blockOf(x, z)]) || 0; },
  addHeat(n, local) {
    const S = G.S, k = n > 0 ? (G.skill('dyskrecja', 4) ? 0.8 : 1) : 1;
    S.heat = clamp(S.heat + n * k, 0, 100);
    if (local !== false && G.player.loc === 'out') { const key = G.blockOf(G.player.x, G.player.z); S.zheat[key] = clamp((S.zheat[key] || 0) + n * k * 1.6, 0, 100); }
  },
  addInvest(n) { const S = G.S; S.invest = clamp(S.invest + n * (n > 0 ? [1, 1, 0.7][G.lvl('prawnik')] : 1), 0, 100); },
  effHeat() { return clamp(G.S.heat + G.zoneHeatAt(G.player.x, G.player.z) * 0.6, 0, 100); },
  copRange() { const f = G.S.flags; return f.wronaPaid ? 0.78 : (f.wronaRefused ? 1.15 : 1); },
  loseTime() { return 7.5 - (G.skill('dyskrecja', 5) ? 2.2 : 0); },
  computeSusp() {
    const S = G.S, P = G.player, carry = G.carryCount() > 0, eh = G.effHeat();
    let m = 0;
    if (S.wanted) m = 3;
    else {
      if (carry && eh >= 50) m = 0.9;
      if (carry && P.sprinting) m = Math.max(m, 0.55);
      if (eh >= 80) m = Math.max(m, 1.3);
      if (S.invest >= 85) m = Math.max(m, 0.7);
      if (carry && W.nightF > 0.6 && eh >= 28) m = Math.max(m, 0.45);
      if (carry && G.mod('oblawa')) m = Math.max(m, 1.0);
    }
    return m * (1 - 0.14 * Math.min(1, G.sk('dyskrecja'))) * (S.flags.wronaPaid ? 0.6 : 1) * (S.flags.wronaRefused ? 1.2 : 1);
  },
  onChaseStart(c) {
    const S = G.S;
    if (!S.wanted) { S.wanted = true; UI.toast('🚨 Policja Cię ściga! Uciekaj albo schowaj się w budynku!', 'bad'); Snd.alert(); Snd.sirenOn(); G.shake = 1; }
    G.addHeat(12); if (S.heat < 45) S.heat = 45; G.wantedGrace = 0; G.chaseStart = G.now;
  },
  arrest(cop) {
    if (G.arresting || G.busy) return;
    G.arresting = true;
    const S = G.S, carry = G.carryCount();
    if (carry === 0 && S.invest < 85) {
      return UI.dialog({
        name: 'Policjant', lines: ['Stój! Policja! Ręce na maskę!', '…Hmm. Nic przy Tobie nie ma. Tym razem Cię puszczam, ale mam Cię na oku.'],
        onEnd: () => { NPC.endChase(); S.wanted = false; Snd.sirenOff(); G.addHeat(-10); G.addInvest(4); G.arresting = false; },
      });
    }
    UI.dialog({
      name: 'Policjant', lines: ['Stój! Policja! Ręce na maskę!', carry ? `Mamy podstawy, żeby Cię przeszukać. Co tam masz w plecaku? (${carry} szt. towaru)` : 'Mamy na Ciebie nakaz. Jedziesz z nami.'],
      choices: [
        { label: 'Poddaję się.', act: () => G.surrender() },
        ...[800, 2000, 4500].map(a => ({ label: `Zaproponuj „prezent” za ${money(a)} (szansa ~${Math.round(G.bribeChance(a) * 100)}%)`, disabled: S.cash < a, cls: 'warn', act: () => G.bribe(a) })),
      ],
    });
  },
  bribeChance(a) { const S = G.S; return clamp(0.08 + a / 5500 + (S.flags.wronaPaid ? 0.25 : 0) - S.invest / 400 - (G.carryValue() > 3000 ? 0.1 : 0), 0.04, 0.9); },
  bribe(a) {
    const S = G.S;
    S.cash -= a;
    if (Math.random() < G.bribeChance(a)) {
      S.stats.bribes++;
      UI.dialog({ name: 'Policjant', lines: ['*rozgląda się, chowa kopertę do kieszeni*', 'Nic nie widziałem. Idź już.'], onEnd: () => { NPC.endChase(); S.wanted = false; Snd.sirenOff(); G.addHeat(-20); G.arresting = false; } });
    } else UI.dialog({ name: 'Policjant', lines: ['Próba przekupstwa funkcjonariusza? Zakuć go!'], onEnd: () => { G.addInvest(8); G.surrender(); } });
  },
  async surrender() {
    const S = G.S, P = G.player;
    G.busy = true;
    await UI.fade(true);
    const fine = Math.min(S.cash, Math.round((S.cash * 0.3 + 300) * [1, 0.65, 0.4][G.lvl('prawnik')]));
    S.cash -= fine;
    let lost = 0; for (const p in S.inv.prod) for (let q = 0; q < 4; q++) { lost += S.inv.prod[p][q]; S.inv.prod[p][q] = 0; }
    S.arrests++; S.heat = 25; S.wanted = false; Snd.sirenOff(); NPC.endChase(); G.addInvest(10);
    G.addMinutes(360);
    P.loc = 'out'; W.setLocation('out'); P.x = -30; P.z = -76; P.yaw = Math.PI; P.pitch = 0;
    UI.toast(`🚔 Zatrzymany (${S.arrests}/${MAX_ARRESTS})! Konfiskata: ${lost} szt., grzywna ${money(fine)}.`, 'bad');
    G.msg('Księgowy', 'Słyszałem, że byłeś u policji. Bardzo nieostrożnie. Raty nadal obowiązują.', true);
    await sleep(700); await UI.fade(false);
    G.busy = false; G.arresting = false;
    if (S.arrests >= MAX_ARRESTS) G.ending('wyrok');
  },
  stingChance() { const S = G.S; return S.stats.deals < 6 ? 0 : clamp(0.025 + S.invest / 350 + (S.flags.wronaRefused ? 0.02 : 0), 0, 0.3); },

  /* ---------- zdarzenia czasowe ---------- */
  onHour() {
    const S = G.S, h = Math.floor(G.hour());
    // zamówienia: wygasanie
    for (const o of S.orders.slice()) {
      const def = CUSTOMERS.find(c => c.id === o.cust), st = S.cust[o.cust];
      if (o.status === 'new' && !o.story && S.t > o.respondBy) { G.dropOrder(o); st.sat = Math.max(0, st.sat - 2); G.msg(def.name, 'Nie odpisujesz, więc szukam gdzie indziej.', true); }
      else if (S.t > o.deadline) {
        G.dropOrder(o);
        if (o.story) G.msg(def.name, 'Czas minął. Jeszcze chcesz ze mną robić interesy?');
        else if (o.status === 'accepted') { st.sat = Math.max(0, st.sat - 14); st.loy = Math.max(0, st.loy - 1); G.msg(def.name, 'Umówiliśmy się, a Ciebie nie było. Słabo.'); }
      }
    }
    // nowe zamówienia
    const open = S.orders.filter(o => !o.story).length;
    if (open < 4 && S.flags.ordersOn) {
      for (const c of CUSTOMERS) {
        const st = S.cust[c.id];
        if (!st.unlocked || S.orders.some(o => o.cust === c.id)) continue;
        if (c.id === 'madame' && !S.flags.kDone) continue;
        const prob = ((h >= 9 && h <= 23) ? 0.11 : 0.035) * (W.rain > 0.3 ? 0.7 : 1) + Math.min(0.08, st.loy * 0.008) + (st.sat - 60) * 0.0008;
        if (Math.random() < prob) { G.makeOrder(c); if (S.orders.filter(o => !o.story).length >= 4) break; }
      }
    }
    if (S.up.pracownik) G.employeeTick();
    if (h === 6) G.washTick();
    if (h === 8) G.dailyCosts();
    if (h === 10) G.dailyEvent();
    if (h === 21) G.crewSell();
    // pogoda
    if (S.weather) W.rainTarget = (S.t >= S.weather.start && S.t < S.weather.end) ? S.weather.power : 0;
    // koniec obławy
    for (const c of NPC.cops.slice()) if (c.post && !G.mod('oblawa')) NPC.removeCop(c);
    G.syncStoryNpcs();
  },

  onDay() {
    const S = G.S, d = G.day();
    // rynek
    const keys = Object.keys(PRODUCTS), hot = pick(keys); let cold = pick(keys); if (cold === hot) cold = keys[(keys.indexOf(hot) + 1) % keys.length];
    for (const k of keys) S.demand[k] = +(0.96 + Math.random() * 0.1).toFixed(2);
    S.demand[hot] = +(1.12 + Math.random() * 0.16).toFixed(2); S.demand[cold] = +(0.8 + Math.random() * 0.1).toFixed(2);
    S.ingMult = +(0.9 + Math.random() * 0.28).toFixed(2);
    S.news = `🔥 ${PRODUCTS[hot].name} na topie (+${Math.round((S.demand[hot] - 1) * 100)}%). ❄️ ${PRODUCTS[cold].name} słabo schodzi (${Math.round((S.demand[cold] - 1) * 100)}%).`;
    UI.toast('📰 ' + S.news);
    if (d > 1 && d % 2 === 0) setTimeout(() => UI.toast('💡 ' + pick(HINTS)), 2000);
    // pogoda
    S.weather = null; W.rainTarget = 0;
    if (Math.random() < 0.3) { const st = S.t + rr(2, 14) * 60; S.weather = { start: st, end: st + rr(2, 7) * 60, power: rr(0.5, 1) }; }
    // dług: odsetki tygodniowe i raty
    if (S.debt > 0 && d > 1 && (d - 1) % 7 === 0) {
      const add = Math.round(S.debt * DEBT_INTEREST); S.debt += add;
      G.msg('Księgowy', `Tygodniowe odsetki: ${money(add)}. Pozostało ${money(S.debt)}.`);
    }
    for (const r of DEBT_SCHEDULE) {
      if (S.debt <= 0) break;
      if (d === r.day) UI.toast(`⏰ Dziś mija termin raty: łącznie ${money(r.due)} spłaconych (masz ${money(S.paid)}).`, 'warn');
      if (d === r.day + 1) { if (S.paid >= r.due) G.msg('Księgowy', 'Rata zaliczona. Miło mieć z panem do czynienia.'); else G.missedPayment(r); }
    }
    // klienci: tolerancja i nastroje
    for (const id in S.cust) { const st = S.cust[id]; for (const p in st.tol) st.tol[p] = Math.max(0, st.tol[p] - 0.12); st.sat = clamp(st.sat + (st.sat < 60 ? 1.5 : -0.5), 0, 100); }
    // uwaga policji
    for (const k in S.zheat) S.zheat[k] = Math.max(0, S.zheat[k] - 14);
    G.addInvest(S.heat < 25 ? -4 : -1);
    // nalot
    const raidP = (S.invest >= 60 ? 0.3 : S.heat > 75 ? 0.25 : 0) * [1, 0.7, 0.5][G.lvl('prawnik')];
    if (raidP && Math.random() < raidP) {
      let lost = 0; const frac = G.lvl('alarm') ? 0.3 : 0.6;
      for (const p in S.stash.prod) for (let q = 0; q < 4; q++) { const l = Math.ceil(S.stash.prod[p][q] * frac); S.stash.prod[p][q] -= l; lost += l; }
      const cl = Math.round(S.stash.cash * frac * 0.5); S.stash.cash -= cl;
      S.heat = Math.max(0, S.heat - 30); G.addInvest(-15);
      if (lost || cl) { UI.hurt(); UI.toast(`🚨 Nalot na mieszkanie! Skonfiskowano ${lost} szt. towaru i ${money(cl)} ze skrytki.`, 'bad'); G.msg('Wujek Staś', 'Słyszałem o nalocie… Trzymaj niższy profil i pierz pieniądze, chłopcze.'); }
    }
    S.heat = Math.max(0, S.heat - 6);
    // dilerzy w areszcie
    for (const c of S.crew) if (c.jail > 0) { c.jail--; if (c.jail === 0) G.msg(c.name, 'Wyszedłem. Wracam do roboty, szefie.', true); }
    NPC.syncCrew();
    G.checkLost(); G.checkUnlocks();
    G.save(false);
  },

  missedPayment(r) {
    const S = G.S; S.strikes++;
    const penalty = Math.round((r.due - S.paid) * 0.15); S.debt += penalty;
    const l1 = Math.round(S.cash * 0.4), l2 = Math.round(S.stash.cash * 0.15); S.cash -= l1; S.stash.cash -= l2;
    G.msg('Księgowy', `Rata nie wpłynęła. Doliczam ${money(penalty)} kary. Moi koledzy odwiedzą Cię osobiście. (${S.strikes}/${MAX_STRIKES})`);
    UI.hurt(); UI.toast(`👊 Oprychy Księgowego zabrali ${money(l1 + l2)}!`, 'bad');
    if (S.strikes >= MAX_STRIKES) setTimeout(() => G.ending('dlug'), 900);
  },
  checkLost() {
    const S = G.S;
    for (const c of CUSTOMERS) { const st = S.cust[c.id]; if (st.unlocked && !c.clubOnly && c.id !== 'dominik' && st.sat < 18) { st.unlocked = false; st.sat = 45; st.lostUntil = S.t + 4 * 1440; G.msg(c.name, 'Wiesz co? Znalazłem lepszego dostawcę. Nie pisz do mnie.'); UI.toast(`💔 Straciłeś klienta: ${c.name}`, 'bad'); } }
  },

  dailyCosts() {
    const S = G.S; let cost = RENT; const parts = [`czynsz ${money(RENT)}`];
    if (S.up.pracownik) { cost += 120; parts.push('Zdzisiek 120 zł'); }
    let c = Math.min(S.cash, cost); S.cash -= c; let left = cost - c;
    c = Math.min(S.bank, left); S.bank -= c; left -= c; c = Math.min(S.stash.cash, left); S.stash.cash -= c; left -= c;
    if (left > 0) { S.debt += Math.round(left * 1.5); G.msg('Administracja', `Zaległy czynsz i opłaty: ${money(left)}. Księgowy „pomógł” — dopisał ${money(Math.round(left * 1.5))} do długu.`); }
    else UI.toast(`🧾 Koszty dnia: ${parts.join(', ')}`);
  },

  /* ---------- ZAMÓWIENIA (SMS) ---------- */
  availableProducts() { const a = ['dym']; if (G.S.up.reaktor) a.push('szron'); if (G.S.up.prasa) a.push('neon'); if (G.S.up.lab) a.push('pyl'); return a; },
  /* maksymalna cena, jaką klient zapłaci za sztukę */
  maxPrice(def, st, p, q, qty, o) {
    o = o || {};
    const pref = def.pref[p] != null ? def.pref[p] : 0.7;
    let m = PRODUCTS[p].base * QMULT[q] * G.S.demand[p] * (G.mod('rival_' + p) ? 0.85 : 1) * pref * def.wealth * 0.92;
    m *= 1 + Math.min(10, st.loy || 0) * 0.03;
    m *= 1 - 0.22 * ((st.tol && st.tol[p]) || 0);
    if (q < (o.minQ != null ? o.minQ : def.minQ)) m *= 0.55;
    if (o.club) m *= 1.1;
    m *= 1 - Math.min(0.2, (qty - 1) * 0.02);
    return m * (o.noise || 1) * (o.boost || 1);
  },
  makeOrder(c) {
    const S = G.S, st = S.cust[c.id], avail = G.availableProducts().filter(p => c.pref[p]);
    if (!avail.length) return null;
    // tolerancja zniechęca do tego samego towaru
    avail.sort((a, b) => ((st.tol[a] || 0) - c.pref[a] * 0.3) - ((st.tol[b] || 0) - c.pref[b] * 0.3));
    const product = Math.random() < 0.7 ? avail[0] : pick(avail);
    const qty = Math.round(rr(c.qty[0], c.qty[1] + 0.49)) + (st.loy >= 8 ? 1 : 0);
    const spot = c.clubOnly ? 'club' : pick(SPOTS).id, noise = rr(0.94, 1.06);
    const max = G.maxPrice(c, st, product, Math.max(1, c.minQ), qty, { noise, club: c.clubOnly });
    const o = { id: S.nextOrderId++, cust: c.id, product, qty, minQ: c.minQ, spot, deadline: S.t + rr(5, 10) * 60, respondBy: S.t + 150, status: c.clubOnly ? 'accepted' : 'new', stated: Math.max(5, Math.round(max * c.honesty * rr(0.9, 0.98))), noise, agreed: null, counter: null };
    S.orders.push(o);
    const sp = spot === 'club' ? 'w klubie Neon' : SPOTS.find(s => s.id === spot).name;
    const q = c.minQ > 0 ? ` (min. ${QNAMES[c.minQ]})` : '';
    o.text = pick([
      `Potrzebuję ${qty}× ${PRODUCTS[product].name}${q}. Dam ${o.stated} zł za sztukę. ${sp}, do ${G.clock(o.deadline)}.`,
      `Hej, masz ${qty}× ${PRODUCTS[product].name}${q}? Mogę dać ${o.stated} zł/szt. Będę: ${sp}, najpóźniej ${G.clock(o.deadline)}.`,
      `${qty}× ${PRODUCTS[product].name}${q}, ${o.stated} zł/szt. ${sp}. Dasz radę do ${G.clock(o.deadline)}?`,
    ]);
    G.msg(c.name, o.text);
    return o;
  },
  dropOrder(o) {
    const S = G.S, i = S.orders.indexOf(o); if (i >= 0) S.orders.splice(i, 1);
    NPC.removeCustomer(o.id); if (S.track === o.id) S.track = null;
    G.navDirty = true;
  },
  /* odpowiedź na SMS: kind = accept | price | counterok | decline */
  replyOrder(id, kind, price) {
    const S = G.S, o = S.orders.find(x => x.id === id); if (!o) return;
    const def = CUSTOMERS.find(c => c.id === o.cust), st = S.cust[o.cust];
    const accept = (agreed, line) => {
      o.status = 'accepted'; o.agreed = agreed; o.counter = null; st.declines = 0;
      if (!def.clubOnly) NPC.spawnCustomer(o);
      S.track = o.id; S.navOn = true;
      G.msg(def.name, line, true); Snd.sms();
      UI.toast(`📍 ${def.name} czeka: ${o.spot === 'club' ? 'Klub Neon' : SPOTS.find(s => s.id === o.spot).name}. Trasa zaznaczona na mapie.`, 'good');
      G.navDirty = true;
    };
    if (kind === 'accept') accept(null, pick(['Dobra, czekam. Cenę ustalimy na miejscu.', 'Ok, będę tam. Pogadamy o cenie.']));
    else if (kind === 'counterok') accept(o.counter, `Stoi, ${o.counter} zł za sztukę. Czekam.`);
    else if (kind === 'price') {
      const max = G.maxPrice(def, st, o.product, Math.max(1, o.minQ), o.qty, { noise: o.noise, club: def.clubOnly });
      if (price <= max * 0.98) accept(price, pick([`Ok, ${price} zł za sztukę. Czekam.`, `Niech będzie ${price}. Do zobaczenia.`]));
      else if (price <= max * 1.18 && !o.countered) { o.counter = Math.round(max * rr(0.9 + G.sk('negocjacje') * 0.012, 0.97)); o.countered = true; G.msg(def.name, `${price}? Za drogo. Mogę dać ${o.counter} zł za sztukę, nie więcej.`, true); Snd.sms(); }
      else { G.dropOrder(o); st.sat = Math.max(0, st.sat - 6); G.msg(def.name, pick(['Chyba żartujesz. Szukam gdzie indziej.', 'Za takie pieniądze? Nie, dzięki.']), true); Snd.bad(); }
    } else if (kind === 'decline') {
      G.dropOrder(o); st.declines = (st.declines || 0) + 1; st.sat = Math.max(0, st.sat - 2);
      if (st.declines >= 3) { st.loy = Math.max(0, st.loy - 1); st.declines = 0; }
      G.msg(def.name, pick(['Szkoda. Następnym razem.', 'Ok, rozumiem.']), true);
    }
  },
  checkUnlocks() {
    const S = G.S;
    for (const c of CUSTOMERS) {
      const st = S.cust[c.id];
      if (st.unlocked || c.clubOnly || c.id === 'dominik') continue;
      if (st.lostUntil && S.t < st.lostUntil) continue;
      if (S.rep >= c.unlockRep) { st.unlocked = true; G.msg(c.name, 'Hej, dostałem Twój numer od znajomego. Masz coś dla mnie?'); UI.toast(`👥 Nowy klient: ${c.name}`, 'good'); G.addXp(15); }
    }
  },
  unlockCustomer(id, text) { const st = G.S.cust[id]; if (st.unlocked) return; st.unlocked = true; G.msg(CUSTOMERS.find(x => x.id === id).name, text || 'Cześć, słyszałem o Tobie.'); },

  /* ---------- SPRZEDAŻ ---------- */
  completeSale(ctx, p, q, qty, price, max) {
    const S = G.S, total = Math.round(price * qty);
    G.removeProduct(p, q, qty);
    S.cash += total; S.stats.earned += total; S.stats.sold += qty; S.stats.deals++; S.stats.byProd[p] = (S.stats.byProd[p] || 0) + qty;
    const repGain = (0.7 + qty * 0.3 + (price >= max * 0.85 ? 0.5 : 0)) * (ctx.order && ctx.order.cust === 'rysiek' ? 1.6 : 1);
    S.rep += repGain; G.addXp(4 + qty * 2 + (q >= 2 ? 3 : 0));
    Snd.cash(); UI.toast(`💰 +${money(total)}  (${qty}× ${PRODUCTS[p].name})`, 'good');
    const st = ctx.who && ctx.who.st;
    if (st) { st.tol = st.tol || {}; st.tol[p] = clamp((st.tol[p] || 0) + 0.07 * qty, 0, 1); }
    if (ctx.order) {
      const o = ctx.order, cs = S.cust[o.cust]; o.qty -= qty; cs.loy++; cs.deals++;
      cs.sat = clamp(cs.sat + (q - o.minQ) * 4 + (price < max * 0.8 ? 3 : price > max * 0.96 ? -2 : 1), 0, 100);
      if (o.qty <= 0) {
        G.dropOrder(o); G.addXp(10);
        if (o.story === 'K1') { S.flags.kDone = true; G.msg('Madame K', 'Zostajemy w kontakcie, skarbie. Będę miała dla Ciebie stałe zamówienia.'); }
        if (o.story === 'FIN') { S.flags.lastJob = true; G.msg('Księgowy', 'Towar odebrany. Jesteśmy prawie kwita. Proszę uregulować resztę długu.'); }
      }
    }
    if (ctx.npc && ctx.npc.kind !== 'customer') { ctx.npc.loyalty = (ctx.npc.loyalty || 0) + 1; ctx.npc.lastDeal = S.t; }
    if (ctx.story === 'kruk') S.flags.krukPaid = true;
    G.addMinutes(4);
    if (ctx.street && G.player.loc === 'out') G.afterDealRisk(ctx, qty);
    G.checkUnlocks();
    return { sold: qty, revenue: total, price };
  },
  afterDealRisk(ctx, qty) {
    const P = G.player;
    G.addHeat(2.5 + qty * 0.5);
    const w = NPC.citizensNear(P.x, P.z, 13, true) - (ctx.npc && ctx.npc.kind === 'citizen' ? 1 : 0);
    if (w > 0) {
      const chance = w * (G.isNight() ? 0.06 : 0.12) * (1 - 0.3 * G.skill('dyskrecja', 2)) * (ctx.who && ctx.who.nerv > 0.3 ? 1.3 : 1);
      if (Math.random() < chance) { UI.toast('📞 Ktoś z przechodniów mógł zadzwonić na policję…', 'warn'); G.addHeat(9); G.addInvest(3); NPC.dispatchTo(P.x, P.z, 2); }
    }
  },
  /* prowokacja policyjna */
  stingBust(n) {
    G.addInvest(12); G.addHeat(25);
    UI.dialog({
      name: n.name, lines: ['…Policja! To była kontrolowana transakcja. Nie ruszaj się!'],
      onEnd: () => { const c = NPC.spawnCop(); c.x = n.x; c.z = n.z; n.x = W.lat[n.a]; n.z = W.lat[n.b] + 300; n.reroll = 0; NPC.rollIdentity(n); c.susp = 1; NPC.startChase(c); UI.toast('🚨 PROWOKACJA! Uciekaj!', 'bad'); G.requestLock(); },
    });
  },

  /* ---------- PRODUKCJA ---------- */
  beginBatch(slot) {
    const id = UI.station, st = STATIONS[id], rec = RECIPES[st.product], S = G.S;
    if (!Object.keys(rec.inputs).every(k => (S.inv.ing[k] || 0) >= rec.inputs[k])) return UI.toast('Brakuje składników.', 'warn');
    const dil = !!UI.opt.dilute, stab = !!UI.opt.stab && (S.inv.ing.stabilizator || 0) > 0, boost = !!UI.opt.boost && (S.inv.ing.wzmacniacz || 0) > 0;
    const widen = 1 + (G.skill('chemia', 1) + G.skill('chemia', 4)) * 0.1 + (stab ? 0.3 : 0);
    UI.skillCheck(`${rec.verb}: ${PRODUCTS[st.product].name}`, 'Naciśnij SPACJĘ, gdy wskaźnik jest w zielonej strefie. Każde trafienie = lepsza jakość.', widen, (hits) => {
      for (const k in rec.inputs) S.inv.ing[k] -= rec.inputs[k];
      if (stab) S.inv.ing.stabilizator--; if (boost) S.inv.ing.wzmacniacz--;
      const spoilP = hits === 0 ? (stab ? 0 : 0.55 - 0.2 * G.skill('chemia', 2)) : 0;
      if (Math.random() < spoilP) {
        S.stats.spoiled++; UI.toast('💥 Partia zepsuta — składniki przepadły. Stabilizator chroni przed zepsuciem.', 'bad');
        UI.station = id; UI.refreshStation(); return;
      }
      let q = Math.min(3, hits); if (dil) q = Math.max(0, q - 1); if (boost) q = Math.min(3, q + 1);
      if (G.skill('chemia', 5) && Math.random() < 0.25) q = Math.min(3, q + 1);
      const n = rec.yield + G.lvl('partie') + G.skill('chemia', 3) + (dil ? 2 : 0);
      const hours = rec.hours * [1, 0.85, 0.7, 0.58][G.lvl('sprzet')];
      S.jobs[id][slot] = { p: st.product, q, n, start: S.t, end: S.t + hours * 60 };
      S.stats.batchesStarted++; G.addXp(5);
      UI.toast(`🧪 Partia rozpoczęta — jakość: ${QNAMES[q]} (${hits}/3 trafień)`, hits >= 2 ? 'good' : 'warn');
      UI.station = id; UI.refreshStation();
    });
  },
  collectBatch(slot) {
    const id = UI.station, job = G.S.jobs[id][slot];
    if (!job || G.S.t < job.end) return;
    G.addProduct(job.p, job.q, job.n);
    G.S.jobs[id][slot] = null; G.S.stats.batchesCollected++; G.S.stats['made_' + job.p] = (G.S.stats['made_' + job.p] || 0) + 1; G.addXp(8);
    UI.toast(`✅ Odebrano ${job.n}× ${PRODUCTS[job.p].name} (${QNAMES[job.q]})`, 'good');
  },
  employeeTick() {
    const S = G.S; let started = 0, got = 0;
    for (const id in STATIONS) {
      const st = STATIONS[id]; if (st.unlock && !S.up[st.unlock]) continue;
      const rec = RECIPES[st.product];
      for (let i = 0; i < G.slots(id); i++) {
        const j = S.jobs[id][i];
        if (j && S.t >= j.end) { S.stash.prod[j.p][j.q] += j.n; S.jobs[id][i] = null; S.stats.batchesCollected++; S.stats['made_' + j.p] = (S.stats['made_' + j.p] || 0) + 1; got += j.n; }
        if (!S.jobs[id][i] && Object.keys(rec.inputs).every(k => (S.stash.ing[k] || 0) >= rec.inputs[k])) {
          for (const k in rec.inputs) S.stash.ing[k] -= rec.inputs[k];
          const hours = rec.hours * [1, 0.85, 0.7, 0.58][G.lvl('sprzet')];
          S.jobs[id][i] = { p: st.product, q: 1, n: rec.yield + G.lvl('partie'), start: S.t, end: S.t + hours * 60 }; started++;
        }
      }
    }
    if (got) UI.toast(`🧑‍🔧 Zdzisiek odłożył do skrytki ${got} szt.${started ? ' i zaczął nowe partie' : ''}.`);
  },
  updateStationViz() {
    const S = G.S, V = W.stationViz;
    V.doniczki.forEach((d, i) => {
      d.group.visible = i < G.slots('doniczki');
      const j = S.jobs.doniczki[i], k = j ? Math.min(1, 0.12 + 0.88 * (S.t - j.start) / (j.end - j.start)) : 0.01;
      d.plant.scale.setScalar(Math.max(0.01, k)); d.plant.visible = !!j;
    });
    V.reaktor.liquids.forEach((l, i) => { const on = i < G.slots('reaktor'); l.fl.visible = l.nk.visible = on; l.liq.visible = on && !!S.jobs.reaktor[i]; });
    V.reaktor.cover.visible = !S.up.reaktor; V.prasa.cover.visible = !S.up.prasa; V.lab.cover.visible = !S.up.lab;
    const busy = S.jobs.prasa.some(j => j && S.t < j.end);
    V.prasa.light.material.color.setRGB(busy ? 0.2 : 0.1, busy ? 4 : 0.1, busy ? 0.6 : 0.1);
    V.lab.cols.forEach((c, i) => { c.visible = !!S.jobs.lab[i]; });
  },

  /* ---------- skrytka / sklep / ulepszenia ---------- */
  moveItem(v) {
    const [mode, type, key, qs, amt] = v.split('|'), q = +qs, S = G.S;
    const from = mode === 'out' ? S.inv : S.stash, to = mode === 'out' ? S.stash : S.inv;
    if (type === 'p') {
      let n = amt === 'all' ? from.prod[key][q] : Math.min(+amt, from.prod[key][q]);
      if (mode === 'in') n = Math.min(n, G.cap() - G.carryCount());
      if (n <= 0) return UI.toast('Plecak jest pełny.', 'warn');
      from.prod[key][q] -= n; to.prod[key][q] += n;
    } else { const n = amt === 'all' ? (from.ing[key] || 0) : Math.min(+amt, from.ing[key] || 0); from.ing[key] = (from.ing[key] || 0) - n; to.ing[key] = (to.ing[key] || 0) + n; }
  },
  moveCash(v) {
    const [m, a] = v.split('|'), S = G.S;
    if (m === 'dep') { const n = a === 'all' ? S.cash : Math.min(+a, S.cash); S.cash -= n; S.stash.cash += n; }
    else { const n = a === 'all' ? S.stash.cash : Math.min(+a, S.stash.cash); S.stash.cash -= n; S.cash += n; }
  },
  buyIngredient(k, n) {
    const S = G.S, cost = G.ingPrice(k) * n;
    if (!G.pay(cost)) return UI.toast('Za mało pieniędzy.', 'warn');
    S.inv.ing[k] = (S.inv.ing[k] || 0) + n; Snd.cash();
  },
  fenceSell(p, q, n) {
    const S = G.S, have = S.inv.prod[p][q], cnt = n === 'all' ? have : Math.min(+n, have); if (cnt <= 0) return;
    const pr = Math.round(PRODUCTS[p].base * QMULT[q] * S.demand[p] * 0.5) * cnt;
    G.removeProduct(p, q, cnt); S.cash += pr; S.stats.earned += pr; S.stats.sold += cnt; Snd.cash();
    UI.toast(`💰 +${money(pr)} (skup Stasia)`, 'good');
  },
  buyUpgrade(id) {
    const u = UPGRADES.find(x => x.id === id), S = G.S, l = G.lvl(id), L = u.levels[l];
    if (!L) return;
    if (!G.pay(L.cost, L.clean)) return UI.toast(L.clean ? 'Za mało czystych pieniędzy na koncie (wypierz gotówkę w myjni).' : 'Za mało pieniędzy.', 'warn');
    S.up[id] = l + 1; Snd.good(); G.addXp(12);
    UI.toast(`🛠️ Kupiono: ${u.name}${u.levels.length > 1 ? ' (poziom ' + (l + 1) + ')' : ''}`, 'good');
    if (id === 'dealer') { while (S.crew.length < S.up.dealer) S.crew.push({ name: DEALER_NAMES[S.crew.length % DEALER_NAMES.length], spot: null, product: 'dym', jail: 0, sold: 0 }); }
    G.updateStationViz();
  },
  payDebt(amt) {
    const S = G.S, n = Math.min(amt, S.cash + S.bank, S.debt); if (n <= 0) return;
    G.pay(n); S.debt -= n; S.paid += n; Snd.cash();
    UI.toast(`💸 Spłacono ${money(n)}. Zostało: ${money(S.debt)}`, 'good');
    if (S.debt <= 0) { UI.closeAll(); setTimeout(() => G.finale(), 400); }
  },

  /* ---------- pranie pieniędzy ---------- */
  washCap() { return [0, 2500, 6000][G.lvl('myjnia')]; },
  washFee() { return [0, 0.12, 0.10][G.lvl('myjnia')] - (G.skill('biznes', 3) ? 0.03 : 0); },
  washDeposit(a) {
    const S = G.S, n = a === 'all' ? S.cash : Math.min(+a, S.cash); if (n <= 0) return;
    S.cash -= n; S.washQ += n; Snd.cash(); UI.toast(`🚿 ${money(n)} trafiło do „utargu myjni”. Pranie: do ${money(G.washCap())} dziennie o 6:00.`);
  },
  washTick() {
    const S = G.S; if (!G.lvl('myjnia') || S.washQ <= 0) return;
    const n = Math.min(S.washQ, G.washCap()), clean = Math.round(n * (1 - G.washFee()));
    S.washQ -= n; S.bank += clean; S.stats.laundered += clean;
    G.msg('Pan Wiesio', `Wczorajszy „utarg” zaksięgowany: ${money(clean)} na koncie. W kolejce jeszcze ${money(S.washQ)}.`, true); UI.toast(`🏦 Wyprano ${money(clean)} (na koncie: ${money(S.bank)})`, 'good');
  },

  /* ---------- dilerzy ---------- */
  crewSell() {
    const S = G.S; if (!S.crew.length) return;
    let total = 0, units = 0; const lines = [];
    S.crew.forEach((d, i) => {
      if (!d.spot || d.jail > 0) return;
      const sp = SPOTS.find(s => s.id === d.spot), key = G.blockOf(sp.x, sp.z), zh = S.zheat[key] || 0;
      let cap = 6 + i + (G.skill('biznes', 4) ? 3 : 0), sold = 0, rev = 0;
      for (let q = 0; q < 4 && cap > 0; q++) { const n = Math.min(cap, S.stash.prod[d.product][q]); if (n > 0) { S.stash.prod[d.product][q] -= n; cap -= n; sold += n; rev += n * PRODUCTS[d.product].base * QMULT[q] * S.demand[d.product] * 0.78; } }
      if (!sold) { lines.push(`${d.name}: brak towaru (${PRODUCTS[d.product].name}) w skrytce.`); return; }
      const pArr = 0.04 + zh / 350 + S.invest / 600;
      if (Math.random() < pArr) { d.jail = 3; G.addInvest(5); S.zheat[key] = clamp(zh + 12, 0, 100); lines.push(`${d.name}: ZATRZYMANY z ${sold} szt. Wróci za 3 dni (albo wpłać kaucję w telefonie).`); return; }
      const net = Math.round(rev * 0.75); S.stash.cash += net; total += net; units += sold; d.sold = (d.sold || 0) + sold;
      S.stats.sold += sold; S.stats.earned += net; S.zheat[key] = clamp(zh + sold * 0.7, 0, 100);
      lines.push(`${d.name}: sprzedał ${sold} szt., do skrytki ${money(net)}.`);
    });
    if (lines.length) { G.msg('Ekipa', lines.join(' '), true); if (total) UI.toast(`🕴️ Dilerzy: +${money(total)} do skrytki (${units} szt.)`, 'good'); }
    NPC.syncCrew();
  },
  bail(i) { const S = G.S, d = S.crew[i]; if (!d || !d.jail) return; if (!G.pay(1500)) return UI.toast('Za mało pieniędzy na kaucję (1 500 zł).', 'warn'); d.jail = 0; UI.toast(`${d.name} wychodzi za kaucją.`, 'good'); NPC.syncCrew(); },
  setCrew(i, field, val) { const d = G.S.crew[i]; if (!d) return; d[field] = val || null; NPC.syncCrew(); },
  talkDealer(i) {
    const d = G.S.crew[i];
    UI.dialog({ name: d.name, lines: [pick(['Spokojnie, szefie. Wszystko pod kontrolą.', 'Towar schodzi. Tylko dowoź do skrytki.', 'Gliny się kręcą, ale daję radę.']), `Sprzedane łącznie: ${d.sold || 0} szt. (${PRODUCTS[d.product].name}). Zmienisz ustawienia w telefonie → Ekipa.`], onEnd: () => G.requestLock() });
  },

  /* ---------- zdarzenia losowe ---------- */
  dailyEvent() {
    const S = G.S; if (G.day() < 3 || Math.random() > 0.42 || UI.isOpen() || G.busy) return;
    const ev = [];
    ev.push(() => { G.setMod('supply', 48); G.msg('Wujek Staś', 'Kontrola na granicy. Przez dwa dni wszystko u mnie o 30% drożej, chłopcze.'); });
    const p = pick(G.availableProducts());
    ev.push(() => { G.setMod('rival_' + p, 72); G.msg('Wujek Staś', `Ktoś zalał miasto tanim towarem. ${PRODUCTS[p].name} przez trzy dni schodzi o 15% taniej.`); });
    ev.push(() => {
      G.setMod('oblawa', 6); UI.toast('🚨 Obława! Przez 6 godzin na skrzyżowaniach stoją posterunki.', 'bad'); G.msg('Dominik „Student”', 'Uważaj, psy stoją dziś na rogach i przeszukują ludzi!', true);
      for (const [x, z] of [[8, 8], [-8, -52], [52, 8]]) { const c = NPC.spawnCop(); c.post = true; c.state = 'post'; c.x = x; c.z = z; c.mesh.rotation.y = Math.random() * 6; }
    });
    if (S.stash.cash > 3000 && !G.lvl('alarm')) ev.push(() => { const l = Math.round(S.stash.cash * 0.2); S.stash.cash -= l; UI.hurt(); UI.toast(`🔓 Włamanie do mieszkania! Zniknęło ${money(l)} ze skrytki. (Alarm by temu zapobiegł.)`, 'bad'); });
    if (S.cash + S.stash.cash > 14000 + G.washCap() * 3 && S.flags.ch2) ev.push(() => G.audit());
    if (S.flags.ch2) ev.push(() => UI.dialog({
      name: 'Nieznany numer', lines: ['Mam nadwyżkę: 6 porcji Prekursora Z i 3 Rozpuszczalnika. Za wszystko 380 zł, bez pytań. Bierzesz?'],
      choices: [
        { label: 'Biorę (380 zł)', disabled: G.funds() < 380, act: () => { G.pay(380); if (Math.random() < 0.75) { S.stash.ing.prekursor = (S.stash.ing.prekursor || 0) + 6; S.stash.ing.rozpuszczalnik = (S.stash.ing.rozpuszczalnik || 0) + 3; UI.toast('📦 Towar czeka w skrytce.', 'good'); } else { UI.toast('🤡 Oszust! Zapłaciłeś za worek mąki.', 'bad'); } G.requestLock(); } },
        { label: 'Nie, dzięki.', act: () => G.requestLock() },
      ],
    }));
    if (S.heat > 40) ev.push(() => UI.dialog({
      name: 'Sąsiad z dołu', lines: ['Panie, ja wszystko widzę. Ci ludzie, ten zapach… 600 złotych i nic nie widziałem. Inaczej dzwonię, gdzie trzeba.'],
      choices: [
        { label: 'Płacę 600 zł', disabled: G.funds() < 600, act: () => { G.pay(600); UI.toast('🤐 Sąsiad milczy.', 'good'); G.requestLock(); } },
        { label: 'Nie dam się szantażować.', cls: 'bad', act: () => { G.addInvest(14); G.addHeat(10, false); UI.toast('📞 Sąsiad złożył donos. Śledztwo nabiera tempa.', 'bad'); G.requestLock(); } },
      ],
    }));
    pick(ev)();
  },
  audit() {
    const S = G.S, dirty = S.cash + S.stash.cash, tax = Math.round(dirty * 0.22);
    UI.dialog({
      name: 'Inspektor Lis (skarbówka)', lines: ['Dzień dobry. Urząd Skarbowy. Zauważyliśmy rozbieżność między Pana deklarowanymi dochodami a stylem życia.', `Mamy podstawy do domiaru podatkowego: ${money(tax)}. Chyba że ma Pan lepsze wyjaśnienie.`],
      choices: [
        { label: `Zapłać domiar ${money(tax)}`, act: () => { let t = tax; const c = Math.min(S.cash, t); S.cash -= c; t -= c; S.stash.cash = Math.max(0, S.stash.cash - t); UI.toast('🧾 Domiar zapłacony.', 'warn'); G.requestLock(); } },
        { label: 'Koperta dla pani inspektor (3 000 zł, szansa 55%)', disabled: G.funds() < 3000, cls: 'warn', act: () => { G.pay(3000); if (Math.random() < 0.55) UI.toast('🤝 Sprawa „zaginęła” w archiwum.', 'good'); else { const t = Math.round(tax * 1.4); S.stash.cash = Math.max(0, S.stash.cash - t); G.addInvest(10); UI.toast(`😡 Obrażona! Domiar wzrósł do ${money(t)}, a sprawa trafiła na policję.`, 'bad'); } G.requestLock(); } },
        { label: 'Niech rozmawia z moim prawnikiem (wymaga Prawnika II)', disabled: G.lvl('prawnik') < 2, act: () => { UI.toast('⚖️ Prawnik rozniósł kontrolę w pył.', 'good'); G.requestLock(); } },
      ],
    });
  },

  /* ---------- zapis ---------- */
  save(manual) {
    try { G.S.pos = { loc: G.player.loc, x: G.player.x, z: G.player.z, yaw: G.player.yaw }; localStorage.setItem(SAVE_KEY, JSON.stringify(G.S)); if (manual) UI.toast('💾 Gra zapisana.', 'good'); }
    catch (e) { if (manual) UI.toast('Nie udało się zapisać.', 'bad'); }
  },
  hasSave() { try { return !!localStorage.getItem(SAVE_KEY); } catch (e) { return false; } },
  load() {
    try {
      const raw = JSON.parse(localStorage.getItem(SAVE_KEY)), base = G.newState(), S = Object.assign({}, base, raw);
      for (const k of ['inv', 'stash', 'stats', 'jobs', 'demand']) S[k] = Object.assign({}, base[k], raw[k]);
      S.inv.prod = Object.assign({}, base.inv.prod, raw.inv.prod); S.stash.prod = Object.assign({}, base.stash.prod, raw.stash.prod);
      S.cust = base.cust; for (const id in raw.cust) if (S.cust[id]) Object.assign(S.cust[id], raw.cust[id]);
      S.wanted = false;
      return S;
    } catch (e) { return null; }
  },
};
