'use strict';
/* ============================================================
   INTERFEJS: HUD, dialogi, telefon, produkcja, sklepy, negocjacje, mapa
   ============================================================ */

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

const UI = {
  mode: null,           // null = rozgrywka; 'dialog' | 'modal' | 'phone' | 'skill' | 'pause' | 'title' | 'end'
  phoneTabName: 'zadania', dlg: null, typing: null, handlers: {}, deal: null, station: null,
  opt: { dilute: false, stab: false, boost: false }, shopTab: 'buy',

  init() {
    document.addEventListener('click', (e) => {
      const el = e.target.closest('[data-a]');
      if (!el || el.disabled) return;
      const fn = UI.handlers[el.dataset.a];
      if (fn) { Snd.click(); fn(el.dataset.v, el); }
      if (document.activeElement && document.activeElement.blur && document.activeElement.tagName === 'BUTTON') document.activeElement.blur();
    });
    $('skillBtn').addEventListener('mousedown', (e) => { e.preventDefault(); UI.skillPress(performance.now()); });
    UI.mapStatic = document.createElement('canvas'); UI.mapStatic.width = UI.mapStatic.height = 500;
  },

  /* ---------- tryby ---------- */
  setMode(m) { UI.mode = m; if (m && document.pointerLockElement) document.exitPointerLock(); },
  isOpen() { return UI.mode !== null; },
  closeAll() {
    for (const id of ['dialog', 'modal', 'phone', 'skill', 'pause']) $(id).classList.add('hidden');
    UI.mode = null; UI.dlg = null; UI.deal = null; UI.station = null;
    clearInterval(UI.dealTimerId); clearInterval(UI.typing);
    G.requestLock();
  },
  toast(msg, type) {
    const d = document.createElement('div'); d.className = 'toast ' + (type || ''); d.textContent = msg;
    $('toasts').appendChild(d);
    while ($('toasts').children.length > 4) $('toasts').removeChild($('toasts').firstChild);
    setTimeout(() => d.remove(), 4600);
    if (type === 'good') Snd.good(); else if (type === 'bad') Snd.bad(); else if (type === 'warn') Snd.alert();
  },
  fade(on) { return new Promise(res => { $('fade').style.opacity = on ? 1 : 0; setTimeout(res, 470); }); },
  hurt() { const h = $('hurt'); h.style.opacity = 1; setTimeout(() => h.style.opacity = 0, 450); },

  /* ---------- dialog ---------- */
  dialog(d) {
    const lines = d.lines.map(l => typeof l === 'string' ? { n: d.name, t: l } : { n: l.n || d.name, t: l.t });
    UI.dlg = { lines, i: 0, choices: d.choices || null, onEnd: d.onEnd || null };
    UI.setMode('dialog');
    $('modal').classList.add('hidden'); $('phone').classList.add('hidden');
    $('dialog').classList.remove('hidden');
    Snd.open(); UI.showLine();
  },
  showLine() {
    const D = UI.dlg, l = D.lines[D.i];
    $('dlgName').textContent = l.n || ''; $('dlgChoices').innerHTML = ''; $('dlgHint').style.display = '';
    clearInterval(UI.typing);
    let k = 0; const full = l.t; $('dlgText').textContent = ''; D.typingDone = false;
    UI.typing = setInterval(() => {
      k += 3; $('dlgText').textContent = full.slice(0, k);
      if (k % 9 === 0) Snd.tick();
      if (k >= full.length) { clearInterval(UI.typing); UI.lineDone(); }
    }, 20);
  },
  lineDone() {
    const D = UI.dlg; if (!D) return;
    D.typingDone = true; $('dlgText').textContent = D.lines[D.i].t;
    if (D.i === D.lines.length - 1 && D.choices) {
      $('dlgHint').style.display = 'none';
      const box = $('dlgChoices'); box.innerHTML = '';
      D.choices.forEach((c, idx) => {
        const b = document.createElement('button'); b.className = 'btn' + (c.cls ? ' ' + c.cls : ''); b.tabIndex = -1;
        b.textContent = (idx + 1) + '. ' + c.label; b.disabled = !!c.disabled; b.onclick = () => UI.pickChoice(idx);
        box.appendChild(b);
      });
    }
  },
  advance() {
    const D = UI.dlg; if (!D) return;
    if (!D.typingDone) { clearInterval(UI.typing); UI.lineDone(); return; }
    if (D.i < D.lines.length - 1) { D.i++; UI.showLine(); return; }
    if (D.choices) return;
    const end = D.onEnd; UI.closeAll(); if (end) end();
  },
  pickChoice(idx) {
    const D = UI.dlg; if (!D || !D.typingDone || !D.choices) return;
    const c = D.choices[idx]; if (!c || c.disabled) return;
    Snd.click(); UI.closeAll(); if (c.act) c.act();
  },

  modal(html) {
    $('dialog').classList.add('hidden'); $('phone').classList.add('hidden');
    $('modalBox').innerHTML = html; $('modal').classList.remove('hidden');
    if (UI.mode !== 'modal') Snd.open();
    UI.setMode('modal');
  },

  /* ---------- mini-gra precyzji (pozycja liczona z czasu = brak opóźnień) ---------- */
  skillCheck(title, help, widen, cb) {
    UI.setMode('skill');
    $('modal').classList.add('hidden'); $('skill').classList.remove('hidden');
    $('skillTitle').textContent = title; $('skillHelp').textContent = help;
    const S = UI.sk = { round: 0, hits: 0, cb, results: [], on: true, zone: [0, 0], t0: performance.now(), speed: 0.8, widen: widen || 1, lock: 0 };
    UI.skillNewRound();
    const loop = () => {
      if (!S.on) return;
      $('skillCur').style.transform = `translateX(${UI.skillPos(performance.now()) * UI.skBarW}px)`;
      requestAnimationFrame(loop);
    };
    UI.skBarW = $('skillBar').clientWidth - 5;
    requestAnimationFrame(loop);
  },
  skillPos(now) { const S = UI.sk, u = ((now - S.t0) / 1000 * S.speed) % 2; return u < 1 ? u : 2 - u; },
  skillNewRound() {
    const S = UI.sk, w = Math.min(0.5, [0.2, 0.15, 0.11][S.round] * S.widen), start = 0.08 + Math.random() * (0.84 - w);
    S.zone = [start, start + w]; S.speed = 0.78 + S.round * 0.42; S.t0 = performance.now() - Math.random() * 600;
    const z = $('skillZone'); z.style.left = (start * 100) + '%'; z.style.width = (w * 100) + '%';
    $('skillPips').textContent = S.results.map(r => r ? '✅' : '❌').join(' ') || '· · ·';
  },
  skillPress(ts) {
    const S = UI.sk; if (!S || !S.on) return;
    const now = performance.now(); if (now < S.lock) return; S.lock = now + 120;
    const pos = UI.skillPos(ts && ts <= now && now - ts < 250 ? ts : now);
    const hit = pos >= S.zone[0] && pos <= S.zone[1];
    S.results.push(hit); if (hit) { S.hits++; Snd.hit(); } else Snd.miss();
    const bar = $('skillBar'); bar.classList.remove('flashG', 'flashR'); void bar.offsetWidth; bar.classList.add(hit ? 'flashG' : 'flashR');
    S.round++;
    if (S.round >= 3) {
      S.on = false; $('skillPips').textContent = S.results.map(r => r ? '✅' : '❌').join(' ');
      setTimeout(() => { $('skill').classList.add('hidden'); UI.mode = null; const f = S.cb; UI.sk = null; f(S.hits); }, 380);
    } else UI.skillNewRound();
  },

  /* ============================================================
     TELEFON
     ============================================================ */
  openPhone(tab) {
    if (tab) UI.phoneTabName = tab;
    $('dialog').classList.add('hidden'); $('modal').classList.add('hidden'); $('pause').classList.add('hidden');
    $('phone').classList.remove('hidden'); UI.setMode('phone');
    if (UI.phoneTabName === 'sms') G.S.unread = 0;
    UI.renderPhone(); Snd.open();
  },
  renderPhone() {
    const S = G.S, pend = S.orders.filter(o => o.status === 'new').length;
    const tabs = [['zadania', '📋 Zadania'], ['sms', '💬 Wiadomości'], ['plecak', '🎒 Plecak'], ['klienci', '👥 Klienci'], ['mapa', '🗺️ Mapa'], ['sklep', '🛒 Sklep'], ['skills', '🧠 Umiejętności'], ['finanse', '💸 Finanse'], ['ekipa', '🕴️ Ekipa'], ['opcje', '⚙️ Opcje']];
    $('phoneTabs').innerHTML = tabs.map(t => `<button tabindex="-1" data-a="ptab" data-v="${t[0]}" class="${UI.phoneTabName === t[0] ? 'on' : ''}">${t[1]}${t[0] === 'sms' && pend ? `<span class="badge">${pend}</span>` : ''}${t[0] === 'skills' && S.sp ? `<span class="badge">${S.sp}</span>` : ''}</button>`).join('') +
      '<div style="flex:1"></div><button tabindex="-1" data-a="pclose">✖ Zamknij</button>';
    if (UI.phoneTabName === 'sms') S.unread = 0;
    $('phoneContent').innerHTML = (UI.phoneRenderers[UI.phoneTabName] || UI.phoneRenderers.zadania)();
    if (UI.phoneTabName === 'mapa') UI.drawMap($('bigmap'), 0, 0, 262, true);
  },
  orderLabel(o) { return o.story === 'FIN' ? 'Księgowy' : CUSTOMERS.find(c => c.id === o.cust).name; },
  spotName(o) { return o.spot === 'club' ? 'Klub Neon' : SPOTS.find(s => s.id === o.spot).name; },

  phoneRenderers: {
    zadania() {
      const S = G.S, cur = STORY[S.step];
      let h = '<h3>📋 Zadania</h3>';
      if (cur) h += `<div class="muted" style="margin-bottom:8px">${esc(G.chapterOf(S.step))}</div><div class="task cur"><b>Aktualny cel</b><br>${esc(cur.text())}</div>`;
      h += '<h3 style="margin-top:18px">📰 Rynek dziś</h3><div class="card muted" style="line-height:1.8">' + G.availableProducts().map(p => `${PRODUCTS[p].icon} ${PRODUCTS[p].name}: bazowo ${PRODUCTS[p].base} zł × <b style="color:${S.demand[p] >= 1.05 ? 'var(--acc)' : S.demand[p] <= 0.92 ? 'var(--bad)' : 'var(--txt)'}">${Math.round(S.demand[p] * 100)}%</b>${G.mod('rival_' + p) ? ' <span class="badc">(konkurencja −15%)</span>' : ''}`).join('<br>') +
        `${G.mod('supply') ? '<br><span class="warnc">Składniki u Stasia +30%</span>' : ''}${G.mod('oblawa') ? '<br><span class="badc">🚨 Obława: posterunki na skrzyżowaniach</span>' : ''}${S.weather && S.t < S.weather.end ? `<br>🌧️ Deszcz: ${G.clock(S.weather.start)}–${G.clock(S.weather.end)}` : ''}</div>`;
      h += '<h3 style="margin-top:18px">Ukończone</h3>';
      for (let i = S.step - 1; i >= Math.max(0, S.step - 8); i--) h += `<div class="task done">${esc(STORY[i].text().split('(')[0])}</div>`;
      h += `<h3 style="margin-top:18px">Statystyki</h3><div class="card muted" style="line-height:1.8">Zarobione łącznie: <b class="good">${money(S.stats.earned)}</b> • Wyprane: <b>${money(S.stats.laundered)}</b><br>Sprzedane jednostki: <b>${S.stats.sold}</b> • Transakcje: <b>${S.stats.deals}</b> • Ucieczki: <b>${S.stats.escapes}</b><br>Partie: <b>${S.stats.batchesCollected}</b> (zepsute: ${S.stats.spoiled})<br>Zatrzymania: <b>${S.arrests}/${MAX_ARRESTS}</b> • Nieudane raty: <b>${S.strikes}/${MAX_STRIKES}</b></div>`;
      return h;
    },
    sms() {
      const S = G.S;
      let h = '<h3>💬 Wiadomości</h3>';
      const orders = S.orders.slice().sort((a, b) => (a.status === 'new' ? 0 : 1) - (b.status === 'new' ? 0 : 1));
      if (orders.length) h += '<h4 class="muted" style="margin:6px 0">Zamówienia</h4>';
      for (const o of orders) {
        const left = Math.max(0, o.deadline - S.t), P = PRODUCTS[o.product];
        h += `<div class="card order ${o.status}"><div class="itemRow"><div class="l"><b>${esc(UI.orderLabel(o))}</b><span class="tag">${o.any ? '📦 dowolny towar' : P.icon + ' ' + o.qty + '× ' + P.name}${o.any ? ' ×' + o.qty : ''}</span>${o.minQ > 0 ? `<span class="tag">min. ${QNAMES[o.minQ]}</span>` : ''}</div>
          <div class="r muted">📍 ${esc(UI.spotName(o))} • ${Math.floor(left / 60)}h ${Math.floor(left % 60)}m</div></div>
          <div class="bubble">${esc(o.text || '')}</div>`;
        if (o.status === 'new') {
          if (o.counter) h += `<div class="bubble">Kontroferta: <b>${o.counter} zł/szt.</b></div><div class="replies"><button tabindex="-1" class="btn small go" data-a="reply" data-v="${o.id}|counterok">✔ Zgoda na ${o.counter} zł</button><button tabindex="-1" class="btn small" data-a="reply" data-v="${o.id}|accept">Pogadamy na miejscu</button><button tabindex="-1" class="btn small bad" data-a="reply" data-v="${o.id}|decline">Odmów</button></div>`;
          else {
            const s = o.stated, a = Math.round(s * 1.15), b = Math.round(s * 1.3);
            h += `<div class="muted" style="font-size:12px;margin:4px 0">Odpowiedz (czeka jeszcze ${Math.max(0, Math.floor((o.respondBy - S.t) / 60))}h ${Math.max(0, Math.floor((o.respondBy - S.t) % 60))}m):</div><div class="replies">
              <button tabindex="-1" class="btn small go" data-a="reply" data-v="${o.id}|accept">✅ Będę. Cenę ustalimy na miejscu</button>
              <button tabindex="-1" class="btn small" data-a="reply" data-v="${o.id}|price|${s}">OK, ${s} zł/szt.</button>
              <button tabindex="-1" class="btn small" data-a="reply" data-v="${o.id}|price|${a}">Chcę ${a} zł/szt.</button>
              <button tabindex="-1" class="btn small" data-a="reply" data-v="${o.id}|price|${b}">Chcę ${b} zł/szt.</button>
              <button tabindex="-1" class="btn small bad" data-a="reply" data-v="${o.id}|decline">❌ Nie tym razem</button></div>`;
            if (G.skill('negocjacje', 5)) { const def = CUSTOMERS.find(c => c.id === o.cust), mx = G.maxPrice(def, S.cust[o.cust], o.product, Math.max(1, o.minQ), o.qty, { noise: o.noise }); h += `<div class="muted" style="font-size:12px">🧠 Szacowany budżet: ~${Math.round(mx * 0.93)}–${Math.round(mx * 1.05)} zł/szt.</div>`; }
          }
        } else {
          h += `<div class="replies"><span class="tag good">✅ Umówione: ${o.agreed ? o.agreed + ' zł/szt.' : 'cena na miejscu'}</span>
            <button tabindex="-1" class="btn small ${S.track === o.id ? 'go' : ''}" data-a="track" data-v="${o.id}">${S.track === o.id ? '🧭 Prowadzę' : '🧭 Prowadź'}</button>
            ${o.story ? '' : `<button tabindex="-1" class="btn small bad" data-a="reply" data-v="${o.id}|decline">Odwołaj</button>`}</div>`;
        }
        h += '</div>';
      }
      h += '<h4 class="muted" style="margin:14px 0 6px">Skrzynka</h4>';
      if (!S.msgs.length) h += '<div class="muted">Brak wiadomości.</div>';
      for (const m of S.msgs.slice(0, 30)) h += `<div class="msg"><div class="from">${esc(m.from)}</div>${esc(m.text)}<div class="when">Dzień ${m.day}, ${m.time}</div></div>`;
      return h;
    },
    plecak() {
      const S = G.S;
      let h = `<h3>🎒 Plecak <span class="muted" style="font-size:14px">(${G.carryCount()}/${G.cap()})</span></h3><div class="grid2"><div class="card"><h4>Towar</h4>`;
      let any = false;
      for (const p in PRODUCTS) for (let q = 3; q >= 0; q--) { const n = S.inv.prod[p][q]; if (!n) continue; any = true; h += `<div class="itemRow"><div class="l">${PRODUCTS[p].icon} ${PRODUCTS[p].name} <span class="tag" style="color:${QCOLOR[q]}">${QNAMES[q]}</span></div><div class="r"><b>${n}</b></div></div>`; }
      if (!any) h += '<div class="muted">Pusto.</div>';
      h += '</div><div class="card"><h4>Składniki</h4>'; any = false;
      for (const k in INGREDIENTS) { const n = S.inv.ing[k] || 0; if (!n) continue; any = true; h += `<div class="itemRow"><div class="l">${INGREDIENTS[k].icon} ${INGREDIENTS[k].name}</div><div class="r"><b>${n}</b></div></div>`; }
      if (!any) h += '<div class="muted">Pusto.</div>';
      h += `</div></div><div class="card" style="margin-top:14px"><div class="itemRow"><div class="l">💵 Gotówka przy sobie (brudna)</div><div class="r"><b class="good">${money(S.cash)}</b></div></div>
        <div class="itemRow"><div class="l">🗄️ Gotówka w skrytce (brudna)</div><div class="r"><b>${money(S.stash.cash)}</b></div></div>
        <div class="itemRow"><div class="l">🏦 Konto (czyste pieniądze)</div><div class="r"><b class="bluec">${money(S.bank)}</b></div></div></div>
        <p class="muted" style="font-size:13px">Przy zatrzymaniu tracisz towar z plecaka i część gotówki przy sobie. Skrytka jest bezpieczna, dopóki nie ma nalotu ani włamania. Konto jest bezpieczne zawsze.</p>`;
      return h;
    },
    klienci() {
      const S = G.S; let h = '<h3>👥 Klienci</h3>';
      for (const c of CUSTOMERS) {
        const st = S.cust[c.id];
        if (!st.unlocked) { h += `<div class="card locked">🔒 Nieznany kontakt <span class="muted">— ${c.clubOnly ? 'fabuła' : 'reputacja ' + c.unlockRep}</span></div>`; continue; }
        const tol = Object.keys(st.tol || {}).filter(p => st.tol[p] > 0.05).map(p => `${PRODUCTS[p].icon} ${Math.round(st.tol[p] * 100)}%`).join(' ');
        h += `<div class="card" style="margin-bottom:8px"><div class="itemRow"><div class="l"><b>${esc(c.name)}</b></div><div class="r"><span class="tag">Lojalność ${st.loy}</span><span class="tag">Transakcje ${st.deals}</span></div></div>
          <div class="muted" style="font-size:13px">${esc(c.bio)}</div>
          <div class="meter"><span>Zadowolenie</span><div class="bar"><div style="width:${st.sat}%;background:${st.sat > 55 ? 'var(--acc2)' : st.sat > 30 ? 'var(--warn)' : 'var(--bad)'}"></div></div></div>
          <div class="muted" style="font-size:12px;margin-top:4px">Lubi: ${Object.keys(c.pref).map(p => PRODUCTS[p].icon + ' ' + PRODUCTS[p].name).join(', ')} • Min. jakość: ${QNAMES[c.minQ]} • Cierpliwość: ${'●'.repeat(c.patience)}${tol ? ' • Znudzenie towarem: ' + tol : ''}</div></div>`;
      }
      return h;
    },
    mapa() {
      const S = G.S, T = G.navTargets();
      let h = '<h3>🗺️ Mapa</h3><div class="mapWrap"><canvas id="bigmap" width="560" height="560"></canvas><div class="navList"><h4 class="muted">Prowadź do</h4>';
      for (const t of T) h += `<button tabindex="-1" class="btn small ${G.trackKey() === String(t.id) ? 'go' : ''}" data-a="nav" data-v="${t.id}">${esc(t.label)}</button>`;
      h += `<button tabindex="-1" class="btn small" data-a="navtoggle">Trasa: ${S.navOn ? 'wł.' : 'wył.'} (N)</button>
        <div class="muted" style="font-size:12px;margin-top:8px;line-height:1.6">⬜ Ty • 🟩 umówieni klienci • 🟨 chętni przechodnie • 🟥 policja • 🟦 Twoi dilerzy<br>Czerwone tło = „gorąca” dzielnica (więcej patroli).</div></div></div>`;
      return h;
    },
    sklep() {
      const S = G.S;
      let h = `<h3>🛒 Sklep <span class="muted" style="font-size:14px">(gotówka ${money(S.cash)} • konto ${money(S.bank)})</span></h3>`;
      for (const u of UPGRADES) {
        const l = G.lvl(u.id), L = u.levels[l], locked = u.requires && !S.flags[u.requires];
        let right;
        if (!L) right = '<span class="tag good">Maks.</span>';
        else if (u.atWash) right = '<span class="tag">u Pana Wiesia</span>';
        else right = `<button tabindex="-1" class="btn small go" data-a="buyup" data-v="${u.id}" ${(G.funds(L.clean) < L.cost || locked) ? 'disabled' : ''}>${L.clean ? '💳 ' : ''}${money(L.cost)}</button>`;
        h += `<div class="card" style="margin-bottom:8px"><div class="itemRow"><div class="l"><span style="font-size:22px">${u.icon}</span><div><b>${u.name}</b>${u.levels.length > 1 ? ` <span class="tag">poz. ${l}/${u.levels.length}</span>` : (l ? ' <span class="tag good">Posiadasz</span>' : '')}
          <div class="muted" style="font-size:13px">${L ? L.desc : u.levels[u.levels.length - 1].desc}${L && L.clean ? ' <span class="bluec">(tylko z konta)</span>' : ''}${locked ? ' <span class="warnc">(odblokuje się w fabule)</span>' : ''}</div></div></div><div class="r">${right}</div></div></div>`;
      }
      return h;
    },
    skills() {
      const S = G.S;
      let h = `<h3>🧠 Umiejętności</h3><div class="card"><div class="itemRow"><div class="l">Poziom <b>${S.lvl}</b></div><div class="r">Punkty do rozdania: <b class="good">${S.sp}</b></div></div><div class="bar"><div style="width:${S.xp / G.xpNeed(S.lvl) * 100}%;background:var(--blue)"></div></div><div class="muted" style="font-size:12px">${Math.floor(S.xp)} / ${G.xpNeed(S.lvl)} PD — za sprzedaż, produkcję, ucieczki i cele fabularne.</div></div>`;
      for (const s of SKILLS) {
        const l = G.sk(s.id);
        h += `<div class="card" style="margin-top:8px"><div class="itemRow"><div class="l"><span style="font-size:22px">${s.icon}</span><div><b>${s.name}</b> <span class="pips">${[0, 1, 2, 3, 4].map(i => `<span class="${i < l ? 'on' : ''}"></span>`).join('')}</span>
          <div class="muted" style="font-size:13px">${l < 5 ? 'Następny poziom: ' + s.desc[l] : 'Mistrz.'}</div></div></div><div class="r"><button tabindex="-1" class="btn small go" data-a="learn" data-v="${s.id}" ${(S.sp <= 0 || l >= 5) ? 'disabled' : ''}>+1</button></div></div></div>`;
      }
      return h;
    },
    finanse() {
      const S = G.S, d = G.day();
      let h = `<h3>💸 Finanse</h3><div class="grid2"><div class="card"><div class="priceBig" style="color:var(--bad)">${money(S.debt)}</div><div class="muted" style="text-align:center">dług u Księgowego (spłacono ${money(S.paid)})<br>+2% odsetek co 7 dni</div></div>
        <div class="card" style="line-height:1.9">💵 Przy sobie: <b class="good">${money(S.cash)}</b><br>🗄️ Skrytka: <b>${money(S.stash.cash)}</b><br>🏦 Konto: <b class="bluec">${money(S.bank)}</b><br>🚿 W praniu: <b>${money(S.washQ)}</b>${G.lvl('myjnia') ? ` <span class="muted">(${money(G.washCap())}/dzień)</span>` : ''}</div></div>`;
      h += '<div class="btns" style="justify-content:flex-start;margin-top:12px">';
      for (const a of [500, 2000, 5000]) h += `<button tabindex="-1" class="btn" data-a="pay" data-v="${a}" ${(G.funds() < 1 || S.debt <= 0) ? 'disabled' : ''}>Spłać ${money(Math.min(a, G.funds()))}</button>`;
      h += `<button tabindex="-1" class="btn go" data-a="pay" data-v="all" ${(G.funds() < 1 || S.debt <= 0) ? 'disabled' : ''}>Spłać ile się da</button></div>`;
      h += '<h4 class="muted" style="margin:16px 0 8px">Harmonogram (łącznie spłacone do końca dnia)</h4><div class="sched">';
      for (const r of DEBT_SCHEDULE) { const ok = S.paid >= r.due, past = d > r.day; h += `<div class="task ${ok ? 'done' : ''} ${(!ok && !past) ? 'cur' : ''}">Dzień ${r.day}: <b>${money(r.due)}</b> ${ok ? '✅' : (past ? '❌' : '')}</div>`; }
      h += `</div><div class="muted" style="font-size:13px;margin:8px 0">Spóźnienie = kara 15% zaległości + oprychy zabierają gotówkę. ${MAX_STRIKES} spóźnienia = koniec gry (${S.strikes}/${MAX_STRIKES}).</div>
        <div class="card" style="line-height:1.8"><b>Koszty dzienne (8:00):</b> czynsz ${money(RENT)}${S.up.pracownik ? ', Zdzisiek 120 zł' : ''}<br><b>🔎 Śledztwo policji:</b> ${Math.round(S.invest)}% <span class="muted">— 60%: ryzyko nalotu, 85%: nakaz zatrzymania. Spada, gdy siedzisz cicho.</span><br><b>Brudna gotówka:</b> ${money(S.cash + S.stash.cash)} <span class="muted">— powyżej ok. ${money(14000 + G.washCap() * 3)} przyciąga skarbówkę.</span></div>`;
      return h;
    },
    ekipa() {
      const S = G.S;
      let h = '<h3>🕴️ Ekipa</h3>';
      h += `<div class="card"><b>🧑‍🔧 Zdzisiek (produkcja)</b><div class="muted" style="font-size:13px">${S.up.pracownik ? 'Pracuje. Co godzinę odbiera gotowe partie do skrytki i zakłada nowe ze składników w skrytce.' : 'Niezatrudniony (telefon → Sklep).'}</div></div>`;
      if (!S.crew.length) h += '<div class="card" style="margin-top:8px"><b>Dilerzy</b><div class="muted" style="font-size:13px">Brak. Zatrudnisz ich w Sklepie (po spotkaniu z Wroną). Diler co wieczór (21:00) sprzedaje towar ze skrytki w swoim punkcie i odkłada 75% utargu do skrytki.</div></div>';
      S.crew.forEach((d, i) => {
        h += `<div class="card" style="margin-top:8px"><div class="itemRow"><div class="l"><b>${esc(d.name)}</b> ${d.jail > 0 ? `<span class="tag badc">areszt: ${d.jail} dni</span>` : (d.spot ? '<span class="tag good">pracuje</span>' : '<span class="tag warnc">bez punktu</span>')}</div><div class="r muted">sprzedał: ${d.sold || 0} szt.${d.jail > 0 ? ` <button tabindex="-1" class="btn small warn" data-a="bail" data-v="${i}">Kaucja 1 500 zł</button>` : ''}</div></div>
          <div class="muted" style="font-size:12px;margin:6px 0 2px">Punkt:</div><div class="replies">${SPOTS.map(s => `<button tabindex="-1" class="btn small ${d.spot === s.id ? 'go' : ''}" data-a="crew" data-v="${i}|spot|${s.id}">${s.name} <span class="muted">${Math.round(S.zheat[G.blockOf(s.x, s.z)] || 0)}%🔥</span></button>`).join('')}<button tabindex="-1" class="btn small" data-a="crew" data-v="${i}|spot|">— wolne</button></div>
          <div class="muted" style="font-size:12px;margin:6px 0 2px">Towar (ze skrytki):</div><div class="replies">${G.availableProducts().map(p => `<button tabindex="-1" class="btn small ${d.product === p ? 'go' : ''}" data-a="crew" data-v="${i}|product|${p}">${PRODUCTS[p].icon} ${PRODUCTS[p].name} <span class="muted">(${G.stashCount(p)})</span></button>`).join('')}</div></div>`;
      });
      return h;
    },
    opcje() {
      return `<h3>⚙️ Opcje</h3><div class="btns" style="justify-content:flex-start"><button tabindex="-1" class="btn" data-a="save">💾 Zapisz grę</button>
        <button tabindex="-1" class="btn" data-a="mute">${Snd.muted ? '🔇 Dźwięk: wył.' : '🔊 Dźwięk: wł.'}</button>
        <button tabindex="-1" class="btn bad" data-a="quit">⏏ Menu główne</button></div>
        <h4 class="muted" style="margin:16px 0 8px">Jakość grafiki</h4><div class="btns" style="justify-content:flex-start">${[['high', 'Wysoka'], ['med', 'Średnia'], ['low', 'Niska (bez efektów)']].map(q => `<button tabindex="-1" class="btn ${GFX.quality === q[0] ? 'go' : ''}" data-a="quality" data-v="${q[0]}">${q[1]}</button>`).join('')}</div>
        <div class="muted" style="font-size:13px;margin-top:6px">Jeśli gra się przycina, wybierz niższą jakość.</div>
        <h4 class="muted" style="margin:16px 0 8px">Muzyka w klubie</h4><div class="muted" style="font-size:13px;line-height:1.6">Teraz gra: <b>${esc(Snd.trackName())}</b><br>Własne utwory: wrzuć pliki MP3 do folderu <b>muzyka</b> obok gry i uruchom ją przez <b>Uruchom.command</b>. Będą grane w klubie i słyszalne w jego pobliżu.</div>
        <div class="help show" style="margin-top:16px">${G.helpHtml()}</div>`;
    },
  },

  /* ============================================================
     STACJE PRODUKCJI
     ============================================================ */
  openStation(id) { UI.station = id; UI.refreshStation(); },
  refreshStation() {
    const id = UI.station, st = STATIONS[id], S = G.S, rec = RECIPES[st.product], P = PRODUCTS[st.product];
    const ing = Object.keys(rec.inputs).map(k => `${INGREDIENTS[k].icon} ${rec.inputs[k]}× ${INGREDIENTS[k].name} <span class="${(S.inv.ing[k] || 0) >= rec.inputs[k] ? 'muted' : 'badc'}">(masz ${S.inv.ing[k] || 0})</span>`).join(' &nbsp;+&nbsp; ');
    const hrs = rec.hours * [1, 0.85, 0.7, 0.58][G.lvl('sprzet')], yld = rec.yield + G.lvl('partie') + G.skill('chemia', 3);
    const chk = (key, label, have) => `<label class="chk ${have === 0 ? 'off' : ''}"><input type="checkbox" ${UI.opt[key] && have !== 0 ? 'checked' : ''} ${have === 0 ? 'disabled' : ''} onchange="UI.opt.${key}=this.checked"> ${label}</label>`;
    let h = `<button tabindex="-1" class="btn close" data-a="mclose">✖</button><h2>${st.icon} ${st.name} — ${P.icon} ${P.name}</h2>
      <div class="sub">Przepis: ${ing}<br>Czas: <b>${hrs.toFixed(1)} h</b> • Wydajność: <b>${yld}</b> szt. • Jakość zależy od precyzji. <span class="warnc">0 trafień = ryzyko zepsucia partii.</span></div>
      <div class="chks">${chk('dilute', 'Rozcieńcz: <b>+2 szt.</b>, jakość <b>−1</b>')}${chk('stab', `🧊 Stabilizator <span class="muted">(masz ${S.inv.ing.stabilizator || 0})</span>: bez zepsucia, szersze strefy`, S.inv.ing.stabilizator || 0)}${chk('boost', `⚡ Wzmacniacz <span class="muted">(masz ${S.inv.ing.wzmacniacz || 0})</span>: jakość <b>+1</b>`, S.inv.ing.wzmacniacz || 0)}</div>`;
    for (let i = 0; i < G.slots(id); i++) {
      const job = S.jobs[id][i];
      h += '<div class="card" style="margin-bottom:8px">';
      if (!job) {
        const can = Object.keys(rec.inputs).every(k => (S.inv.ing[k] || 0) >= rec.inputs[k]);
        h += `<div class="itemRow"><div class="l"><b>Miejsce ${i + 1}</b> <span class="muted">— wolne</span></div><div class="r"><button tabindex="-1" class="btn go" data-a="startbatch" data-v="${i}" ${can ? '' : 'disabled'}>${rec.verb}…</button></div></div>`;
      } else {
        const total = job.end - job.start, done = Math.min(1, (S.t - job.start) / total), left = Math.max(0, job.end - S.t);
        if (done >= 1) h += `<div class="itemRow"><div class="l"><b>Miejsce ${i + 1}</b> <span class="tag good">GOTOWE</span> ${job.n}× <span style="color:${QCOLOR[job.q]}">${QNAMES[job.q]}</span></div><div class="r"><button tabindex="-1" class="btn go" data-a="collect" data-v="${i}">Odbierz</button></div></div>`;
        else h += `<div class="itemRow"><div class="l"><b>Miejsce ${i + 1}</b> w toku • ${job.n}× <span style="color:${QCOLOR[job.q]}">${QNAMES[job.q]}</span></div><div class="r muted">${Math.floor(left / 60)}h ${Math.floor(left % 60)}m</div></div><div class="prog"><div style="width:${done * 100}%"></div></div>`;
      }
      h += '</div>';
    }
    if (G.slots(id) < st.max) h += `<div class="muted" style="font-size:13px">Więcej miejsc: telefon → Sklep → Dodatkowe stanowiska.</div>`;
    if (!Object.keys(rec.inputs).every(k => (S.inv.ing[k] || 0) >= rec.inputs[k])) h += `<div class="warnc" style="font-size:13px;margin-top:6px">Brakuje składników w plecaku — ${id === 'lab' ? 'kupisz je nocą u Pana Hieronima (Podwórko).' : 'kup je w Hurtowni Stasia (albo wyjmij ze skrytki).'}</div>`;
    UI.modal(h);
  },

  /* ---------- skrytka ---------- */
  openStash() { UI.refreshStash(); },
  refreshStash() {
    const S = G.S;
    const col = (src, title, mode) => {
      let h = `<div class="card"><h4>${title}</h4>`, any = false;
      for (const p in PRODUCTS) for (let q = 3; q >= 0; q--) { const n = src.prod[p][q]; if (!n) continue; any = true; h += `<div class="itemRow"><div class="l">${PRODUCTS[p].icon} ${PRODUCTS[p].name} <span class="tag" style="color:${QCOLOR[q]}">${QNAMES[q]}</span> ×<b>${n}</b></div><div class="r"><button tabindex="-1" class="btn small" data-a="mv" data-v="${mode}|p|${p}|${q}|1">1</button><button tabindex="-1" class="btn small" data-a="mv" data-v="${mode}|p|${p}|${q}|5">5</button><button tabindex="-1" class="btn small" data-a="mv" data-v="${mode}|p|${p}|${q}|all">wszystko</button></div></div>`; }
      for (const k in INGREDIENTS) { const n = src.ing[k] || 0; if (!n) continue; any = true; h += `<div class="itemRow"><div class="l">${INGREDIENTS[k].icon} ${INGREDIENTS[k].name} ×<b>${n}</b></div><div class="r"><button tabindex="-1" class="btn small" data-a="mv" data-v="${mode}|i|${k}|0|1">1</button><button tabindex="-1" class="btn small" data-a="mv" data-v="${mode}|i|${k}|0|all">wszystko</button></div></div>`; }
      return h + (any ? '' : '<div class="muted">Pusto.</div>') + '</div>';
    };
    UI.modal(`<button tabindex="-1" class="btn close" data-a="mclose">✖</button><h2>🗄️ Skrytka</h2><div class="sub">Bezpieczna podczas zatrzymania. Zdzisiek i dilerzy korzystają wyłącznie ze skrytki. Plecak: ${G.carryCount()}/${G.cap()}</div>
      <div class="grid2">${col(S.inv, '🎒 Plecak → skrytka', 'out')}${col(S.stash, '🗄️ Skrytka → plecak', 'in')}</div>
      <div class="card" style="margin-top:12px"><div class="itemRow"><div class="l">💵 Przy sobie: <b>${money(S.cash)}</b> &nbsp;|&nbsp; 🗄️ W skrytce: <b>${money(S.stash.cash)}</b></div>
      <div class="r"><button tabindex="-1" class="btn small" data-a="cash" data-v="dep|1000">wpłać 1000</button><button tabindex="-1" class="btn small" data-a="cash" data-v="dep|all">wpłać wszystko</button><button tabindex="-1" class="btn small" data-a="cash" data-v="wd|1000">wypłać 1000</button><button tabindex="-1" class="btn small" data-a="cash" data-v="wd|all">wypłać wszystko</button></div></div></div>`);
  },

  /* ---------- hurtownia / Hieronim ---------- */
  openShop(tab) {
    UI.shopTab = tab || UI.shopTab || 'buy';
    const S = G.S, hier = UI.shopTab === 'hier';
    let h = `<button tabindex="-1" class="btn close" data-a="mclose">✖</button><h2>${hier ? '🧪 Pan Hieronim' : '🛒 Hurtownia Wujka Stasia'}</h2><div class="sub">Gotówka: <b class="good">${money(S.cash)}</b> • Konto: <b class="bluec">${money(S.bank)}</b>${hier ? '' : ' • Ceny zmieniają się z dnia na dzień.'}${G.mod('supply') && !hier ? ' <span class="warnc">Kontrola na granicy: +30%.</span>' : ''}</div>`;
    if (!hier) h += `<div class="btns" style="justify-content:flex-start;margin-bottom:12px"><button tabindex="-1" class="btn ${UI.shopTab === 'buy' ? 'go' : ''}" data-a="stab" data-v="buy">Kup składniki</button><button tabindex="-1" class="btn ${UI.shopTab === 'sell' ? 'go' : ''}" data-a="stab" data-v="sell">Skup Stasia (połowa ceny rynkowej)</button></div>`;
    if (UI.shopTab !== 'sell') {
      for (const k in INGREDIENTS) {
        const I = INGREDIENTS[k];
        if (I.src !== (hier ? 'hier' : 'stas') || (I.req && !S.flags[I.req])) continue;
        const pr = G.ingPrice(k);
        h += `<div class="itemRow"><div class="l"><span style="font-size:22px">${I.icon}</span><div><b>${I.name}</b> <span class="muted">(masz ${S.inv.ing[k] || 0})</span>${I.desc ? `<div class="muted" style="font-size:12px">${I.desc}</div>` : ''}</div></div><div class="r"><b>${money(pr)}</b>
          <button tabindex="-1" class="btn small" data-a="buying" data-v="${k}|1" ${G.funds() < pr ? 'disabled' : ''}>+1</button><button tabindex="-1" class="btn small" data-a="buying" data-v="${k}|5" ${G.funds() < pr * 5 ? 'disabled' : ''}>+5</button></div></div>`;
      }
      if (!S.flags.ch2 && !hier) h += '<div class="muted" style="margin-top:10px;font-size:13px">Więcej towaru Staś sprowadzi, gdy zdobędziesz jego zaufanie.</div>';
    } else {
      let any = false;
      for (const p in PRODUCTS) for (let q = 3; q >= 0; q--) {
        const n = S.inv.prod[p][q]; if (!n) continue; any = true;
        const pr = Math.round(PRODUCTS[p].base * QMULT[q] * S.demand[p] * 0.5);
        h += `<div class="itemRow"><div class="l">${PRODUCTS[p].icon} ${PRODUCTS[p].name} <span class="tag" style="color:${QCOLOR[q]}">${QNAMES[q]}</span> ×<b>${n}</b></div><div class="r"><b>${money(pr)}</b> / szt.<button tabindex="-1" class="btn small" data-a="fence" data-v="${p}|${q}|1">sprzedaj 1</button><button tabindex="-1" class="btn small" data-a="fence" data-v="${p}|${q}|all">wszystko</button></div></div>`;
      }
      if (!any) h += '<div class="muted">Nie masz nic do sprzedania.</div>';
    }
    UI.modal(h);
  },

  /* ---------- myjnia ---------- */
  openWash() {
    const S = G.S, l = G.lvl('myjnia'), U = UPGRADES.find(u => u.id === 'myjnia'), L = U.levels[l];
    let h = `<button tabindex="-1" class="btn close" data-a="mclose">✖</button><h2>🚿 Myjnia Kryształ</h2><div class="sub">Brudna gotówka → „utarg myjni” → czyste pieniądze na koncie. Pranie odbywa się codziennie o 6:00.</div>
      <div class="grid2"><div class="card" style="line-height:1.9">💵 Gotówka przy sobie: <b class="good">${money(S.cash)}</b><br>🚿 W kolejce do prania: <b>${money(S.washQ)}</b><br>🏦 Konto: <b class="bluec">${money(S.bank)}</b></div>
      <div class="card" style="line-height:1.9">Udziały: <b>${l ? 'poziom ' + l : 'brak'}</b><br>Limit dzienny: <b>${money(G.washCap())}</b><br>Prowizja: <b>${Math.round(G.washFee() * 100)}%</b></div></div>`;
    if (L) h += `<div class="card" style="margin-top:12px"><div class="itemRow"><div class="l"><b>${l ? 'Rozbuduj myjnię' : 'Kup udziały w myjni'}</b> <span class="muted">— ${L.desc}</span></div><div class="r"><button tabindex="-1" class="btn go" data-a="buywash" ${G.funds() < L.cost ? 'disabled' : ''}>${money(L.cost)}</button></div></div></div>`;
    if (l) h += `<div class="btns" style="justify-content:flex-start;margin-top:12px">${[1000, 2500, 5000].map(a => `<button tabindex="-1" class="btn" data-a="wash" data-v="${a}" ${S.cash < 1 ? 'disabled' : ''}>Wpłać ${money(Math.min(a, S.cash))}</button>`).join('')}<button tabindex="-1" class="btn go" data-a="wash" data-v="all" ${S.cash < 1 ? 'disabled' : ''}>Wpłać całą gotówkę</button></div>`;
    UI.modal(h);
  },

  /* ============================================================
     NEGOCJACJE
     ============================================================ */
  openDeal(ctx) {
    const S = G.S, who = ctx.who;
    const stacks = [];
    for (const p in PRODUCTS) for (let q = 3; q >= 0; q--) if (S.inv.prod[p][q] > 0) stacks.push({ p, q });
    if (!stacks.length) { UI.toast('Nie masz nic do sprzedania. Weź towar ze skrytki.', 'warn'); return false; }
    if (NPC.anyChase()) { UI.toast('Nie teraz! Policja depcze Ci po piętach!', 'bad'); return false; }
    const D = UI.deal = {
      ctx, who, stacks, patience: who.patience + G.skill('negocjacje', 2) + G.skill('negocjacje', 4) + Math.min(1, Math.floor((who.st.loy || 0) / 6)),
      sel: null, qty: 1, price: 0, noise: (ctx.order && ctx.order.noise) || rr(0.93, 1.07), gave: false, bluffed: false, counter: null, speech: '', over: false, sold: false, boost: 1, copT: 0, copMax: 0, lastRatio: 0, haggle: !ctx.agreed,
    };
    D.maxPatience = D.patience;
    let best = null;
    for (const s of stacks) { if (ctx.product && s.p !== ctx.product) continue; if (!best || (s.q >= who.minQ && (best.q < who.minQ || s.q < best.q))) best = s; }
    D.sel = best || stacks[0];
    D.qty = Math.max(1, Math.min(ctx.qty || 1, S.inv.prod[D.sel.p][D.sel.q]));
    D.price = ctx.agreed || Math.round(UI.marketPrice(D.sel.p, D.sel.q));
    D.speech = ctx.sting ? '„Dawaj, co masz. Biorę wszystko!”' : pick(['„Cześć. Masz coś dla mnie?”', '„No, jesteś. Co masz?”', '„Słyszałem, że masz dobry towar.”', '„Szybko, bo nie lubię tu stać.”']);
    const P = G.player;
    const cop = P.loc === 'out' && NPC.cops.find(c => Math.hypot(c.x - P.x, c.z - P.z) < 22 && W.los(c.x, c.z, P.x, P.z));
    if (cop) { D.copT = D.copMax = 14; D.cop = cop; }
    UI.renderDeal();
    clearInterval(UI.dealTimerId); UI.dealTimerId = setInterval(() => UI.dealTick(), 100);
    return true;
  },
  marketPrice(p, q) { return PRODUCTS[p].base * QMULT[q] * G.S.demand[p]; },
  dealMax(D, p, q, qty) { return G.maxPrice(D.who, D.who.st, p, q, qty, { noise: D.noise, boost: D.boost, club: D.ctx.club, minQ: D.who.minQ }); },
  dealTick() {
    const D = UI.deal; if (!D) return;
    if (D.copT > 0 && !D.over) {
      D.copT -= 0.1;
      const el = $('copBar'); if (el) el.style.width = (D.copT / D.copMax * 100) + '%';
      if (D.copT <= 0) {
        const cop = D.cop, ctx = D.ctx; clearInterval(UI.dealTimerId);
        UI.closeAll(); UI.toast('👮 Policjant zauważył transakcję!', 'bad');
        if (ctx.onDone) ctx.onDone({ sold: 0, interrupted: true });
        G.addHeat(18); G.addInvest(4); cop.susp = 1; NPC.startChase(cop);
      }
    }
  },
  renderDeal() {
    const D = UI.deal, S = G.S, w = D.who;
    D.stacks = D.stacks.filter(s => S.inv.prod[s.p][s.q] > 0);
    if (!D.stacks.length && !D.over) {
      D.over = true; D.counter = null; D.speech = '„Nie masz już towaru? No to nie ma o czym gadać.”';
      if (D.ctx.onDone && !D.sold) { const f = D.ctx.onDone; D.ctx.onDone = null; f({ sold: 0 }); }
    } else if (D.stacks.length && S.inv.prod[D.sel.p][D.sel.q] <= 0) { D.sel = D.stacks[0]; D.price = Math.round(UI.marketPrice(D.sel.p, D.sel.q)); }
    const sel = D.sel, have = S.inv.prod[sel.p][sel.q], maxQ = Math.max(1, Math.min(have, D.ctx.qty || 99));
    D.qty = Math.max(1, Math.min(D.qty, maxQ));
    const mk = UI.marketPrice(sel.p, sel.q);
    const want = D.ctx.any ? `${D.ctx.qty}× dowolny towar` : (D.ctx.product ? `${D.ctx.qty}× ${PRODUCTS[D.ctx.product].name}` : `ok. ${D.ctx.qty} szt.`);
    let h = `<button tabindex="-1" class="btn close" data-a="dealleave">✖</button><h2>💬 ${esc(w.name)}</h2><div class="sub">${esc(w.bio || '')}</div>`;
    if (D.copMax && !D.over) h += `<div class="copWarn">👮 Policjant ma Was na oku! Szybko zakończ rozmowę!</div><div class="timerBar"><div id="copBar" style="width:${D.copT / D.copMax * 100}%"></div></div>`;
    h += `<div class="dealHead"><div><div class="muted" style="font-size:12px">SZUKA</div><b>${want}</b>${w.minQ > 0 ? ` <span class="tag">min. ${QNAMES[w.minQ]}</span>` : ''}${D.ctx.agreed ? ` <span class="tag good">umówione: ${D.ctx.agreed} zł/szt.</span>` : ''}</div>
      <div style="text-align:right"><div class="muted" style="font-size:12px">CIERPLIWOŚĆ</div><div class="pips">${Array.from({ length: Math.max(D.maxPatience, D.patience, 1) }, (_, i) => `<span class="${i < D.patience ? 'on' : ''}"></span>`).join('')}</div></div></div>
      <div class="speech">${D.speech}</div>`;
    if (D.over) { h += `<div class="btns"><button tabindex="-1" class="btn big go" data-a="dealclose">Zamknij</button></div>`; UI.modal(h); return; }
    h += '<div class="grid2"><div class="card"><h4>Twój towar</h4><div class="stackBtns">';
    for (const s of D.stacks) {
      const wrong = (D.ctx.product && s.p !== D.ctx.product) || s.q < w.minQ;
      h += `<div class="stackBtn ${s.p === sel.p && s.q === sel.q ? 'sel' : ''} ${wrong ? 'wrong' : ''}" data-a="dstack" data-v="${s.p}|${s.q}">${PRODUCTS[s.p].icon} ${PRODUCTS[s.p].name}<br><span style="color:${QCOLOR[s.q]}">${QNAMES[s.q]}</span> ×${S.inv.prod[s.p][s.q]}</div>`;
    }
    h += `</div><div class="muted" style="font-size:13px">Ilość: <b id="dQtyTxt">${D.qty}</b> / ${maxQ}</div><input type="range" id="dQty" min="1" max="${maxQ}" value="${D.qty}" tabindex="-1"></div>`;
    if (!D.haggle) {
      const ap = UI.agreedPrice(D);
      h += `<div class="card"><h4>Umówiona cena</h4><div class="priceBig">${ap ? money(ap) : '—'}</div><div class="muted" style="font-size:13px;text-align:center">${ap ? (sel.q > w.minQ ? 'Lepsza jakość niż zamawiał: premia.' : sel.q < w.minQ ? 'Słabsza jakość niż zamawiał: rabat.' : 'Zgodnie z umową.') : 'Tego towaru nie weźmie.'}<br>Razem: <b id="dTotal" class="good">${money((ap || 0) * D.qty)}</b></div></div></div>
        <div class="btns" style="margin-top:14px"><button tabindex="-1" class="btn big go" data-a="dealagreed" ${ap ? '' : 'disabled'}>Sprzedaj po umówionej cenie</button><button tabindex="-1" class="btn warn" data-a="dealhaggle">Podbij cenę (ryzykowne)</button><button tabindex="-1" class="btn bad" data-a="dealleave">Odejdź</button></div>`;
    } else {
      h += `<div class="card"><h4>Cena za sztukę</h4><div class="priceBig" id="dPrice">${money(D.price)}</div>
        <input type="range" id="dPriceR" min="${Math.max(1, Math.round(mk * 0.2))}" max="${Math.round(mk * 2.4)}" value="${D.price}" tabindex="-1">
        <div class="muted" style="font-size:13px;display:flex;justify-content:space-between"><span>Rynek: ~${money(mk)}</span><span>Razem: <b id="dTotal" class="good">${money(D.price * D.qty)}</b></span></div>
        ${G.skill('negocjacje', 5) ? `<div class="muted" style="font-size:12px">🧠 Budżet: ~${Math.round(UI.dealMax(D, sel.p, sel.q, D.qty) * 0.93)}–${Math.round(UI.dealMax(D, sel.p, sel.q, D.qty) * 1.05)} zł</div>` : ''}</div></div><div class="btns" style="margin-top:14px">`;
      if (D.counter) h += `<button tabindex="-1" class="btn go" data-a="dealaccept">✔ Przyjmij ${money(D.counter)} / szt.</button>`;
      h += `<button tabindex="-1" class="btn big go" data-a="dealoffer">Zaproponuj</button>
        <button tabindex="-1" class="btn" data-a="dealsample" ${D.gave ? 'disabled' : ''}>🎁 Darmowa próbka</button>
        <button tabindex="-1" class="btn" data-a="dealbluff" ${D.bluffed ? 'disabled' : ''}>🗣️ Zachwal towar</button>
        <button tabindex="-1" class="btn bad" data-a="dealleave">Odejdź</button></div>`;
    }
    UI.modal(h);
    const q = $('dQty'), p = $('dPriceR');
    if (q) q.oninput = () => { D.qty = +q.value; $('dQtyTxt').textContent = D.qty; $('dTotal').textContent = money((D.haggle ? D.price : (UI.agreedPrice(D) || 0)) * D.qty); };
    if (p) p.oninput = () => { D.price = +p.value; $('dPrice').textContent = money(D.price); $('dTotal').textContent = money(D.price * D.qty); };
  },
  /* cena umówiona skorygowana o jakość towaru */
  agreedPrice(D) {
    const s = D.sel, w = D.who, a = D.ctx.agreed;
    if (D.ctx.product && s.p !== D.ctx.product) return 0;
    if (s.q < w.minQ - 1) return 0;
    if (s.q < w.minQ) return Math.round(a * 0.7);
    return Math.round(a * (1 + 0.06 * (s.q - Math.max(1, w.minQ))));
  },
  dealOffer() {
    const D = UI.deal; if (!D || D.over) return;
    const sel = D.sel, P = D.price, max = UI.dealMax(D, sel.p, sel.q, D.qty), r = P / max, w = D.who;
    D.lastRatio = r; D.counter = null;
    if (D.ctx.sting) return UI.dealSell(P, '„Biorę! Trzymaj kasę.”');
    const cLo = 0.86 + G.sk('negocjacje') * 0.012;
    if (r <= 0.85) return UI.dealSell(P, '„Stoi! Dobra cena.”');
    if (r <= 1.0) {
      if (Math.random() < 1 - ((r - 0.85) / 0.15) * 0.7) return UI.dealSell(P, pick(['„No dobra, niech stracę.”', '„Okej, biorę.”', '„Niech Ci będzie.”']));
      D.patience--; D.counter = Math.round(max * rr(cLo, 0.95)); D.speech = `„Hmm… prawie. Dam ${money(D.counter)} za sztukę, nie więcej.”`;
    } else if (r <= 1.12) { D.patience--; D.counter = Math.round(max * rr(cLo, 0.95)); D.speech = pick([`„Trochę drogo. ${money(D.counter)} i po sprawie.”`, `„Mogę dać ${money(D.counter)} za sztukę.”`]); }
    else if (r <= 1.4) { D.patience -= (w.tough > 1.1 ? 2 : 1); D.counter = Math.round(max * rr(cLo - 0.06, 0.9)); D.speech = pick([`„Przesadzasz. Góra ${money(D.counter)}.”`, `„Za drogo! ${money(D.counter)}, bo pójdę gdzie indziej.”`]); }
    else { D.patience -= 2; D.speech = pick(['„Chyba żartujesz?!”', '„Ile?! Pogięło Cię?”', '„Za kogo Ty mnie masz?”']); D.counter = D.patience > 0 ? Math.round(max * rr(0.74, 0.84)) : null; }
    UI.checkWalk(); UI.renderDeal();
  },
  checkWalk() {
    const D = UI.deal; if (D.patience > 0) return;
    D.over = true; D.counter = null; G.S.stats.walked++;
    const w = D.who, st = w.st;
    if (st && st.sat != null) st.sat = Math.max(0, st.sat - 8);
    const snitch = Math.random() < (w.nerv || 0.1) * 0.5 + (D.lastRatio > 1.4 ? 0.15 : 0.04);
    if (snitch) { D.speech = '„Mam dość! Zadzwonię po policję!” — odchodzi, wściekły.'; G.addHeat(12); G.addInvest(3); NPC.dispatchTo(G.player.x, G.player.z, 2); UI.toast('📞 Klient wezwał policję!', 'bad'); }
    else D.speech = pick(['„Tracę czas. Cześć.” — klient odchodzi.', '„Nie dogadamy się.” — klient odwraca się plecami.']);
    if (D.ctx.order && !D.ctx.order.story) G.dropOrder(D.ctx.order);
    if (D.ctx.onDone) { const f = D.ctx.onDone; D.ctx.onDone = null; f({ sold: 0, walked: true }); }
  },
  dealSell(price, line) {
    const D = UI.deal, sel = D.sel, max = UI.dealMax(D, sel.p, sel.q, D.qty);
    const res = G.completeSale(D.ctx, sel.p, sel.q, D.qty, price, max);
    D.over = true; D.sold = true; D.counter = null;
    const diff = max - price; let fb = '';
    if (!D.ctx.sting) { if (diff > max * 0.25) fb = ` <span class="warnc">(Mogłeś zażądać więcej — klient był gotów dać do ~${money(max)}.)</span>`; else if (diff < max * 0.07) fb = ` <span class="good">(Świetny interes — blisko jego maksimum!)</span>`; }
    D.speech = `${line}<br><b class="good">+${money(price * D.qty)}</b> za ${D.qty}× ${PRODUCTS[sel.p].name}.${fb}`;
    clearInterval(UI.dealTimerId); UI.renderDeal();
    if (D.ctx.onDone) { const f = D.ctx.onDone; D.ctx.onDone = null; f(res); }
  },
  dealAgreed() { const D = UI.deal; if (!D) return; const ap = UI.agreedPrice(D); if (!ap) return; UI.dealSell(ap, pick(['„Tak jak się umawialiśmy. Dzięki.”', '„Słowo to słowo. Trzymaj.”'])); },
  dealHaggle() { const D = UI.deal; if (!D) return; D.haggle = true; D.patience = Math.max(1, D.patience - 1); D.price = Math.round(D.ctx.agreed * 1.1); if (D.who.st && D.who.st.sat != null) D.who.st.sat = Math.max(0, D.who.st.sat - 3); D.speech = '„Ej, umawialiśmy się inaczej… No dobra, mów.”'; UI.renderDeal(); },
  dealAccept() { const D = UI.deal; if (!D || !D.counter) return; UI.dealSell(D.counter, '„Dobra, tak wygląda uczciwa cena.”'); },
  dealSample() {
    const D = UI.deal; if (!D || D.gave) return;
    const s = D.sel; G.removeProduct(s.p, s.q, 1);
    D.gave = true; D.boost *= 1.05; D.patience++; D.maxPatience = Math.max(D.maxPatience, D.patience); D.who.st.loy = (D.who.st.loy || 0) + 1;
    D.speech = pick(['„O, nieźle… Zostaje na dłużej.”', '„Hmm! Dobre. Teraz pogadajmy o cenie.”']); UI.renderDeal();
  },
  dealBluff() {
    const D = UI.deal; if (!D || D.bluffed) return; D.bluffed = true;
    const p = 0.38 + G.skill('negocjacje', 3) * 0.2 + (D.who.tough > 1.2 ? -0.1 : 0);
    if (Math.random() < p) { D.boost *= 1.07; D.speech = pick(['„Gadasz jak z reklamy… ale dobra, zainteresowałeś mnie.”', '„Hmm, może i masz rację z tą jakością.”']); }
    else { D.patience--; D.speech = pick(['„Nie nabierzesz mnie na gadkę.”', '„Mniej gadania, więcej konkretów.”']); UI.checkWalk(); }
    UI.renderDeal();
  },
  dealLeave() { const D = UI.deal, ctx = D && D.ctx, f = ctx && ctx.onDone; if (ctx) ctx.onDone = null; UI.closeAll(); if (f) f({ sold: 0, left: true }); },

  /* ============================================================
     HUD + MAPA
     ============================================================ */
  updateHud() {
    const S = G.S, P = G.player, eh = G.effHeat();
    $('hCash').textContent = '💵 ' + money(S.cash);
    $('hTime').textContent = `${W.rain > 0.2 ? '🌧️' : (W.nightF > 0.5 ? '🌙' : '☀️')} Dzień ${G.day()} • ${G.clock()}`;
    $('hBank').textContent = '🏦 ' + money(S.bank);
    $('hDebt').textContent = '📉 ' + money(S.debt);
    $('hHeat').style.width = eh + '%'; $('hHeatTxt').textContent = Math.round(eh) + '%';
    $('hInv').textContent = '🔎 Śledztwo ' + Math.round(S.invest) + '%'; $('hInv').className = S.invest >= 60 ? 'badc' : '';
    $('hRep').textContent = `⭐ ${G.repTitle()} • poz. ${S.lvl}`;
    $('hCarry').textContent = `🎒 ${G.carryCount()}/${G.cap()}`;
    $('hLoc').textContent = P.loc === 'out' ? (G.zoneName || 'Ulica') : W.rooms[P.loc].name;
    $('hXp').style.width = (S.xp / G.xpNeed(S.lvl) * 100) + '%';
    const cur = STORY[S.step];
    $('objTitle').textContent = cur ? G.chapterOf(S.step) : 'Wolna gra';
    $('objText').textContent = cur ? cur.text() : 'Rozwijaj swoje imperium.';
    $('stam').style.width = (P.stamina / G.maxStamina() * 100) + '%';
    $('chaseBanner').classList.toggle('hidden', !NPC.anyChase());
    const nav = G.navInfo;
    $('navLine').innerHTML = nav ? `🧭 <b>${esc(nav.label)}</b> • ${Math.round(nav.dist)} m ${S.navOn ? '' : '<span class="muted">(trasa wył.)</span>'} <span class="muted">[N] trasa • [Q] zmień cel</span>` : '<span class="muted">[Q] wybierz cel • [N] trasa</span>';
    const pend = S.orders.filter(o => o.status === 'new').length;
    $('smsBadge').classList.toggle('hidden', !pend); $('smsBadge').textContent = `💬 ${pend} SMS czeka na odpowiedź — [Tab]`;
    const mt = $('musicTag'); if (Snd.club.vol > 0.05) { mt.classList.remove('hidden'); mt.textContent = '♪ ' + Snd.trackName(); } else mt.classList.add('hidden');
  },

  paintMapStatic() {
    const c = UI.mapStatic, g = c.getContext('2d'), SC = 2;
    const X = (x) => (x + 125) * SC, Z = (z) => (z + 125) * SC;
    g.fillStyle = '#0f1218'; g.fillRect(0, 0, c.width, c.height);
    g.fillStyle = '#2a2e38';
    for (const r of W.roadsZ) g.fillRect(0, Z(r - 6), c.width, 12 * SC);
    for (const r of W.roadsX) g.fillRect(X(r - 6), 0, 12 * SC, c.height);
    for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
      const b = blk(i, j);
      g.fillStyle = (i === 1 && j === 1) ? '#1f3d28' : (i === 3 && j === 1 ? '#23252b' : '#181c25');
      g.fillRect(X(b.x0), Z(b.z0), (b.x1 - b.x0) * SC, (b.z1 - b.z0) * SC);
    }
    g.fillStyle = '#3b4560';
    for (const k of W.colliders) if (k.h >= 5.5 && k.x1 - k.x0 > 6 && k.x1 - k.x0 < 80 && k.x0 > -124) g.fillRect(X(k.x0), Z(k.z0), (k.x1 - k.x0) * SC, (k.z1 - k.z0) * SC);
  },
  drawMap(cv, cx, cz, span, big) {
    if (!UI.mapPainted) { UI.paintMapStatic(); UI.mapPainted = true; }
    const g = cv.getContext('2d'), w = cv.width, k = w / span, S = G.S, P = G.player;
    const X = (x) => (x - cx) * k + w / 2, Z = (z) => (z - cz) * k + w / 2;
    g.fillStyle = '#07090d'; g.fillRect(0, 0, w, w);
    g.drawImage(UI.mapStatic, 0, 0, 500, 500, X(-125), Z(-125), 250 * k, 250 * k);
    // „gorące” dzielnice
    for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) { const hz = S.zheat['z' + i + j] || 0; if (hz < 8) continue; const b = blk(i, j); g.fillStyle = `rgba(239,68,68,${Math.min(0.5, hz / 160)})`; g.fillRect(X(b.x0), Z(b.z0), (b.x1 - b.x0) * k, (b.z1 - b.z0) * k); }
    if (P.loc !== 'out' && !big) { g.fillStyle = 'rgba(0,0,0,.6)'; g.fillRect(0, 0, w, w); g.fillStyle = '#e5e7eb'; g.font = 'bold 15px sans-serif'; g.textAlign = 'center'; g.fillText(W.rooms[P.loc].name.toUpperCase(), w / 2, w / 2 - 4); g.font = '11px sans-serif'; g.fillStyle = '#94a3b8'; g.fillText('wyjście: drzwi na południu', w / 2, w / 2 + 14); return; }
    const dot = (x, z, col, r) => { g.fillStyle = col; g.beginPath(); g.arc(X(x), Z(z), r, 0, 6.3); g.fill(); };
    const label = (x, z, t, col, dy) => { g.font = 'bold ' + (big ? 12 : 10) + 'px sans-serif'; g.textAlign = 'center'; g.lineWidth = 3; g.strokeStyle = 'rgba(0,0,0,.8)'; g.strokeText(t, X(x), Z(z) - (dy || 7)); g.fillStyle = col; g.fillText(t, X(x), Z(z) - (dy || 7)); };
    // trasa
    if (S.navOn && Nav.path && P.loc === 'out' && Nav.path.length > 1) {
      g.strokeStyle = (G.navInfo && G.navInfo.color) || '#4ade80'; g.lineWidth = big ? 4 : 3; g.lineJoin = 'round'; g.setLineDash([7, 5]); g.globalAlpha = 0.9;
      g.beginPath(); Nav.path.forEach((p, i) => { if (i) g.lineTo(X(p[0]), Z(p[1])); else g.moveTo(X(p[0]), Z(p[1])); }); g.stroke(); g.setLineDash([]); g.globalAlpha = 1;
    }
    for (const id in W.doors) { const d = W.doors[id]; dot(d.x, d.z, '#fbbf24', big ? 5 : 3.5); if (big || id === 'safe') label(d.x, d.z, { safe: 'Dom', shop: 'Hurtownia', club: 'Klub', wash: 'Myjnia' }[id], '#fde68a'); }
    if (big) { for (const s of SPOTS) { dot(s.x, s.z, '#64748b', 3); label(s.x, s.z, s.name, '#94a3b8'); } if (!S.flags.wilkiGone) label(-93, 93, 'Wilki', '#f87171'); label(-30, -86, 'Komisariat', '#60a5fa'); }
    if (P.loc === 'out') {
      for (const c of NPC.citizens) if (c.icon.visible || (big && c.user && G.carryCount() > 0 && Math.hypot(c.x - P.x, c.z - P.z) < 60 && !c.refused)) dot(c.x, c.z, '#facc15', 2.6);
      for (const c of NPC.crew) dot(c.x, c.z, '#38bdf8', 3.5);
      for (const c of NPC.cops) if (S.up.radio || c.state !== 'patrol' || (c.post && Math.hypot(c.x - P.x, c.z - P.z) < 40)) dot(c.x, c.z, c.state === 'chase' ? '#ef4444' : '#f59e0b', 4);
    }
    for (const c of NPC.customers) { dot(c.x, c.z, '#4ade80', big ? 6 : 5); label(c.x, c.z, c.def.name.split(' ')[0].replace(/[„”]/g, ''), '#bbf7d0', 9); }
    for (const t of G.targets()) if (t.loc === 'out' || big) { g.save(); g.translate(X(t.x), Z(t.z)); g.rotate(Math.PI / 4); g.fillStyle = t.color; g.fillRect(-4.5, -4.5, 9, 9); g.strokeStyle = '#000'; g.lineWidth = 1; g.strokeRect(-4.5, -4.5, 9, 9); g.restore(); }
    let px = P.x, pz = P.z; if (P.loc !== 'out') { const d = W.doors[P.loc]; px = d.x; pz = d.z; }
    g.save(); g.translate(clamp(X(px), 6, w - 6), clamp(Z(pz), 6, w - 6)); g.rotate(-P.yaw + Math.PI);
    g.fillStyle = '#fff'; g.strokeStyle = '#000'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(0, 8); g.lineTo(5.5, -6); g.lineTo(0, -2.5); g.lineTo(-5.5, -6); g.closePath(); g.fill(); g.stroke(); g.restore();
  },
};

/* ---------- handlery przycisków ---------- */
Object.assign(UI.handlers, {
  ptab: (v) => { UI.phoneTabName = v; UI.renderPhone(); },
  pclose: () => UI.closeAll(),
  mclose: () => UI.closeAll(),
  track: (v) => { G.S.track = (G.S.track === +v) ? null : +v; G.S.navOn = true; G.navDirty = true; UI.renderPhone(); },
  nav: (v) => { G.setTrack(v); UI.renderPhone(); },
  navtoggle: () => { G.S.navOn = !G.S.navOn; G.navDirty = true; UI.renderPhone(); },
  reply: (v) => { const [id, kind, price] = v.split('|'); G.replyOrder(+id, kind, +price); UI.renderPhone(); },
  buyup: (v) => { G.buyUpgrade(v); UI.renderPhone(); },
  learn: (v) => { G.learn(v); UI.renderPhone(); },
  pay: (v) => { G.payDebt(v === 'all' ? Infinity : +v); if (UI.mode === 'phone') UI.renderPhone(); },
  bail: (v) => { G.bail(+v); UI.renderPhone(); },
  crew: (v) => { const [i, f, val] = v.split('|'); G.setCrew(+i, f, val); UI.renderPhone(); },
  quality: (v) => { GFX.setQuality(v); UI.renderPhone(); },
  save: () => G.save(true),
  mute: () => { Snd.setMuted(!Snd.muted); UI.renderPhone(); },
  quit: () => G.toMenu(),
  startbatch: (v) => G.beginBatch(+v),
  collect: (v) => { G.collectBatch(+v); UI.refreshStation(); },
  mv: (v) => { G.moveItem(v); UI.refreshStash(); },
  cash: (v) => { G.moveCash(v); UI.refreshStash(); },
  stab: (v) => UI.openShop(v),
  buying: (v) => { const [k, n] = v.split('|'); G.buyIngredient(k, +n); UI.openShop(); },
  fence: (v) => { const [p, q, n] = v.split('|'); G.fenceSell(p, +q, n); UI.openShop(); },
  wash: (v) => { G.washDeposit(v); UI.openWash(); },
  buywash: () => { G.buyUpgrade('myjnia'); UI.openWash(); },
  dstack: (v) => { const [p, q] = v.split('|'), D = UI.deal; D.sel = { p, q: +q }; if (D.haggle && !D.ctx.agreed) D.price = Math.round(UI.marketPrice(p, +q)); D.counter = null; UI.renderDeal(); },
  dealoffer: () => UI.dealOffer(),
  dealaccept: () => UI.dealAccept(),
  dealagreed: () => UI.dealAgreed(),
  dealhaggle: () => UI.dealHaggle(),
  dealsample: () => UI.dealSample(),
  dealbluff: () => UI.dealBluff(),
  dealleave: () => UI.dealLeave(),
  dealclose: () => { const D = UI.deal, f = D && D.ctx.onDone; if (D) D.ctx.onDone = null; UI.closeAll(); if (f) f({ sold: 0 }); },
});
