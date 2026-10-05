'use strict';
/* ============================================================
   FABUŁA: cele, rozmowy z NPC, prowokacje, zakończenia
   ============================================================ */

/* specjalny „klient” fabularny – Księgowy (ostatnia robota) */
const KSIEGOWY_DEF = { id: 'ksiegowy', name: 'Księgowy', wealth: 0.75, pref: { dym: 1, szron: 1, neon: 1, pyl: 1 }, patience: 3, tough: 1.5, minQ: 2, nerv: 0, bio: 'Bolek „Księgowy” Zawada. Liczy każdy grosz — zwłaszcza Twój.' };

Object.assign(G, {
  /* ---------- zagadywanie przechodniów ---------- */
  approachCitizen(n, inClub) {
    const S = G.S;
    if (NPC.anyChase()) return UI.toast('Nie teraz!', 'bad');
    if (n.lastDeal && S.t - n.lastDeal < 240) return UI.dialog({ name: n.name, lines: ['Już coś od Ciebie brałem. Daj mi chwilę, dobra?'], onEnd: () => G.requestLock() });
    if (!n.user) {
      const snitch = !n.refused && Math.random() < (G.isNight() ? 0.08 : 0.16) * (1 - 0.3 * G.skill('dyskrecja', 2));
      n.state = 'talk'; n.talkT = 3; n.refused = true;
      return UI.dialog({
        name: n.name, lines: [pick(['Odczep się, nie interesuje mnie to.', 'Co?! Nie, dziękuję.', 'Przepraszam, śpieszę się.', 'Nie wiem, o czym mówisz.', 'Zostaw mnie w spokoju.'])],
        onEnd: () => { if (snitch) { G.addHeat(10); G.addInvest(3); NPC.dispatchTo(G.player.x, G.player.z, 2); UI.toast('📞 Ktoś zgłosił podejrzanego typa!', 'bad'); } G.requestLock(); },
      });
    }
    if (!n.stingRolled) { n.stingRolled = true; n.sting = !inClub && Math.random() < G.stingChance(); }
    const want = pick(G.availableProducts());
    const who = { name: n.name, bio: inClub ? 'Bywalec klubu. Lubi się bawić.' : 'Przechodzień. Czasem coś kupuje.', wealth: n.wealth, pref: { [want]: 1.0 }, patience: 3 + ((Math.random() * 2) | 0), tough: 1, minQ: 0, nerv: 0.2, st: { loy: n.loyalty || 0, tol: {} } };
    n.state = 'talk'; n.talkT = 600;
    const ctx = { who, product: want, qty: 1 + ((Math.random() * 3) | 0), street: !inClub, club: !!inClub, npc: n, sting: n.sting, onDone: (r) => { n.state = 'walk'; n.talkT = 0; if (r && r.sold && n.sting) G.stingBust(n); } };
    const line = n.sting ? pick(['Hej, stary! Masz coś mocnego? Biorę wszystko, cena nie gra roli, płacę od ręki!', 'Słuchaj, potrzebuję towaru. Dużo. Kasa nie jest problemem. Masz przy sobie?']) : pick(['Hej… Szukam czegoś na wieczór. Masz coś?', 'Podobno masz towar. Pokaż, co masz.', 'Cześć. Cicho, ale… masz coś dla mnie?', 'Ej, ty jesteś od Stasia? Potrzebuję czegoś.']);
    if (n.sting && G.skill('dyskrecja', 3)) UI.toast('⚠️ Coś tu nie gra — za bardzo mu zależy… (słuchawka w uchu?)', 'warn');
    UI.dialog({ name: n.name, lines: [line], onEnd: () => { if (!UI.openDeal(ctx)) { n.state = 'walk'; n.talkT = 0; G.requestLock(); } } });
  },

  dealWithCustomer(n) {
    const S = G.S, o = n.order, def = n.def, st = S.cust[def.id];
    if (NPC.anyChase()) return UI.toast('Nie teraz!', 'bad');
    const who = Object.assign({}, def, { st, minQ: Math.max(def.minQ, o.minQ || 0) });
    const ctx = { who, product: o.product, qty: o.qty, order: o, street: true, npc: n, agreed: o.agreed };
    const line = o.agreed ? `No jesteś. Umawialiśmy się na ${o.agreed} zł za sztukę. Masz towar?` : pick(['No jesteś! Co masz?', 'Cześć. Mam nadzieję, że to ten towar, o który prosiłem.', 'Dobrze, że jesteś. Pokaż, co masz.']);
    UI.dialog({ name: def.name, lines: [line], onEnd: () => { if (!UI.openDeal(ctx)) G.requestLock(); } });
  },

  /* ---------- Wujek Staś ---------- */
  talkStasiu() {
    const S = G.S, cur = STORY[S.step];
    if (!S.flags.metStasiu) {
      return UI.dialog({
        name: 'Wujek Staś', lines: [
          'No proszę, siostrzeniec! Słyszałem o Twoim kłopocie z Księgowym. Siedemdziesiąt tysięcy… Z nim się nie żartuje, chłopcze.',
          'Mam dla Ciebie interes. W Twoim mieszkaniu stoi stół z doniczkami — kiedyś hodowałem tam pomidory. Teraz posadzisz coś bardziej dochodowego: Zielony Dym.',
          'Masz tu startowy zestaw: trzy porcje nasion i trzy nawozu. Na mój rachunek.',
          'Zasady są proste: sadzisz, czekasz, odbierasz. Potem szukasz klientów. Zagaduj ludzi na ulicy — ci zainteresowani zerkają na Ciebie (ikona 👀). Nie każdy jest chętny, a policja ma oczy dookoła.',
          'Stali klienci będą pisać SMS-y. Odpisz im w telefonie (Tab) — wtedy pojawią się na mapie i trasa Cię do nich poprowadzi (klawisz N).',
          'Targuj się mądrze: im bliżej maksimum klienta, tym większy zysk, ale przesadzisz i odejdzie. I pamiętaj: kto bierze każdą cenę bez mrugnięcia okiem, ten może nosić odznakę.',
        ],
        onEnd: () => { S.flags.metStasiu = true; S.inv.ing.nasiona = (S.inv.ing.nasiona || 0) + 3; S.inv.ing.nawoz = (S.inv.ing.nawoz || 0) + 3; UI.toast('🎁 Otrzymano: 3× Nasiona Dymu, 3× Nawóz', 'good'); G.requestLock(); },
      });
    }
    if (cur && cur.id === 'stasiu2' && !S.flags.stasiu2) {
      return UI.dialog({
        name: 'Wujek Staś', lines: [
          'Chłopcze, robisz wrażenie. Księgowy pytał o Ciebie — dobry znak, ale też zły.',
          'Jest ktoś, kogo musisz poznać: Madame K, właścicielka klubu Neon. Płaci krocie, ale testuje każdego nowego dostawcę.',
          'Sprowadziłem Ci też nowy sprzęt: stół reakcyjny i prasę do tabletek (telefon → Sklep). Dojdą nowe składniki i Stabilizator — chroni partię przed zepsuciem.',
          'Ostrzegam: im większy interes, tym większe zainteresowanie policji. Zaczną Cię sprawdzać, podsyłać prowokatorów. Inspektor Wrona ma nos jak pies gończy.',
        ],
        onEnd: () => { S.flags.stasiu2 = true; S.flags.ch2 = true; UI.toast('🔓 Odblokowano: Madame K, nowe składniki i sprzęt', 'good'); G.requestLock(); },
      });
    }
    if (cur && cur.id === 'hier' && !S.flags.hierTip) {
      return UI.dialog({
        name: 'Wujek Staś', lines: [
          'Chcesz wejść na wyższy poziom? Jest taki człowiek — Pan Hieronim. Chemik z dawnych czasów. Ma składniki, o których ja mogę tylko pomarzyć.',
          'Stoi nocą na Podwórku, po 22:00. Weź gotówkę — on bierze „wpisowe”. I nie targuj się z nim. On tego nie lubi.',
        ],
        onEnd: () => { S.flags.hierTip = true; G.syncStoryNpcs(); G.requestLock(); },
      });
    }
    UI.dialog({
      name: 'Wujek Staś', lines: [pick(['Czego potrzebujesz, chłopcze?', 'Słucham. Czas to pieniądz.', 'No? Kupujesz, sprzedajesz, czy tylko stoisz?'])],
      choices: [
        { label: 'Kup składniki', act: () => UI.openShop('buy') },
        { label: 'Sprzedaj towar Stasiowi (szybko, ale za połowę ceny)', act: () => UI.openShop('sell') },
        { label: 'Pogadajmy o interesach', act: () => G.stasiuChat() },
        { label: 'Wychodzę.', act: () => G.requestLock() },
      ],
    });
  },
  stasiuChat() {
    const S = G.S;
    const tips = [
      'Rynek się zmienia co dzień. Gdy coś jest na topie, klienci płacą więcej. Sprawdzaj telefon.',
      'Wszystko, czego nie potrzebujesz, zostawiaj w skrytce. Jak Cię złapią, stracisz tylko to, co masz przy sobie.',
      'Policjanci widzą tylko to, co jest przed nimi. Za rogiem jesteś bezpieczny. A w budynku — jeszcze bardziej.',
      'Nie sprzedawaj wciąż w tym samym miejscu. Gdzie handlujesz często, tam robi się gorąco i patroli przybywa.',
      'Klient, któremu wciskasz w kółko to samo, płaci coraz mniej. Zmieniaj towar albo podnoś jakość.',
      'Jakość to wszystko. Premium daje prawie trzy razy tyle co Słaby. Ćwicz celność przy produkcji.',
      'W SMS-ach ludzie zaniżają budżet. Marek i Bartek kłamią jak z nut, Heniek mówi prawdę.',
      'Brudna forsa w skrytce kusi skarbówkę i włamywaczy. Kiedyś będziesz musiał ją wyprać.',
    ];
    UI.dialog({ name: 'Wujek Staś', lines: [pick(tips), S.news ? 'Dziś w mieście: ' + S.news.replace(/[🔥❄️]/g, '') : ''].filter(Boolean), onEnd: () => G.talkStasiu() });
  },

  /* ---------- Madame K ---------- */
  talkMadame() {
    const S = G.S, def = CUSTOMERS.find(c => c.id === 'madame'), st = S.cust.madame, cur = STORY[S.step];
    const o = S.orders.find(x => x.cust === 'madame' && x.story !== 'FIN');
    if (!S.flags.metMadame) {
      return UI.dialog({
        name: 'Madame K', lines: [
          'Więc to Ty jesteś nowym ulubieńcem Stasia. Słodkie.',
          'Prowadzę ten klub od dwunastu lat. Wiem, co się dzieje na tych ulicach, zanim się wydarzy.',
          'Testuję nowych dostawców. Potrzebuję 10 sztuk Zielonego Dymu — jakość minimum Zwykły. Dostarczaj partiami, ile masz. Zapłacę uczciwie… jeśli się dogadamy.',
          'Aha — moi goście też chętnie kupują. W klubie płacą więcej, a policja tu nie wchodzi.',
        ],
        onEnd: () => {
          S.flags.metMadame = true; st.unlocked = true;
          S.orders.push({ id: S.nextOrderId++, cust: 'madame', product: 'dym', qty: 10, minQ: 1, spot: 'club', deadline: S.t + 7 * 1440, respondBy: S.t + 7 * 1440, status: 'accepted', story: 'K1', stated: 55, noise: 1, text: 'Czekam na 10× Zielony Dym (min. Zwykły). Dostarczaj partiami.' });
          G.msg('Madame K', 'Czekam na 10× Zielony Dym (min. Zwykły). Dostarczaj partiami.'); G.requestLock();
        },
      });
    }
    if (cur && cur.id === 'wiesioMeet' && !S.flags.wiesioTip) {
      return UI.dialog({
        name: 'Madame K', lines: [
          'Skarbie, zarabiasz już tyle, że zaczynasz świecić jak neon nad moimi drzwiami. A świecących szybko gaszą.',
          'Potrzebujesz przykrywki. Mój znajomy, Pan Wiesio, prowadzi Myjnię Kryształ na wschodzie miasta. Od lat „myje” nie tylko samochody.',
          'Powiedz, że przysyłam Cię ja. I przygotuj gotówkę — interesy z Wiesiem nie są tanie.',
        ],
        onEnd: () => { S.flags.wiesioTip = true; G.requestLock(); },
      });
    }
    if (!o) return UI.dialog({ name: 'Madame K', lines: [pick(['Na razie niczego nie potrzebuję, kochanie. Zadzwonię.', 'Zabawa trwa, ale magazyn mam pełny. Wpadnij później.'])], onEnd: () => G.requestLock() });
    const who = Object.assign({}, def, { st, minQ: Math.max(def.minQ, o.minQ || 0) });
    const ctx = { who, product: o.product, qty: o.qty, order: o, club: true, agreed: o.agreed };
    UI.dialog({ name: 'Madame K', lines: [o.story ? 'Pokaż, co przyniosłeś. Cierpliwość nie jest moją cnotą.' : `Dobrze, że jesteś. Potrzebuję ${o.qty}× ${PRODUCTS[o.product].name}.`], onEnd: () => { if (!UI.openDeal(ctx)) G.requestLock(); } });
  },

  /* ---------- Inspektor Wrona ---------- */
  talkWrona() {
    const S = G.S;
    if (S.flags.wronaMet) return UI.dialog({ name: 'Insp. Wrona', lines: ['Wszystko ustalone. Nie zawiedź mnie.'], onEnd: () => G.requestLock() });
    UI.dialog({
      name: 'Insp. Wrona', lines: [
        'Punktualnie. Lubię to.',
        'Wiem, kim jesteś i czym handlujesz. Mógłbym Cię zamknąć choćby dziś. Ale papierologia jest taka… męcząca.',
        'Proponuję układ. 2 500 złotych „składki” i moi ludzie będą patrzeć w drugą stronę. Odmówisz — i zacznę patrzeć wyjątkowo uważnie.',
      ],
      choices: [
        { label: 'Płacę 2 500 zł', disabled: G.funds() < 2500, act: () => { G.pay(2500); S.flags.wronaMet = true; S.flags.wronaPaid = true; S.flags.ch3 = true; G.addInvest(-25); UI.toast('🤝 Wrona „po Twojej stronie”: patrole mniej czujne, łapówki skuteczniejsze', 'good'); UI.dialog({ name: 'Insp. Wrona', lines: ['Mądry wybór. Pamiętaj: ja nic nie widziałem. A gdybyś kiedyś chciał się pozbyć konkurencji… wiesz, gdzie mnie szukać.'], onEnd: () => G.requestLock() }); } },
        { label: 'Nie dam się szantażować.', cls: 'bad', act: () => { S.flags.wronaMet = true; S.flags.wronaRefused = true; S.flags.ch3 = true; G.addHeat(20); G.addInvest(15); NPC.spawnCop(true); UI.toast('⚠️ Wrona zwiększa liczbę patroli i wszczyna śledztwo', 'bad'); UI.dialog({ name: 'Insp. Wrona', lines: ['Jak chcesz. Do zobaczenia… na ulicy.'], onEnd: () => G.requestLock() }); } },
        { label: 'Muszę to przemyśleć (wrócę później).', act: () => G.requestLock() },
      ],
    });
  },

  /* ---------- Kruk (Wilki) ---------- */
  talkKruk() {
    const S = G.S, cur = STORY[S.step];
    if (cur && cur.id === 'war' && !S.flags.warDone) return G.krukWar();
    if (S.flags.krukMet) return UI.dialog({ name: 'Kruk', lines: [S.flags.krukPaid ? 'Wilki Cię szanują. Trzymaj się z daleka od kłopotów.' : 'Nasze ulice. Nasze zasady. Pamiętaj.'], onEnd: () => G.requestLock() });
    const has = S.inv.prod.dym.reduce((a, c, q) => a + (q >= 1 ? c : 0), 0);
    UI.dialog({
      name: 'Kruk', lines: [
        'Więc to Ty handlujesz bez pozwolenia na naszej ziemi.',
        'Wilki trzymają ten rejon od dziesięciu lat. Każdy, kto sprzedaje na ulicach, odpala nam działkę. 4 000 złotych i masz spokój. Albo… zawsze możemy dogadać się inaczej.',
      ],
      choices: [
        { label: 'Płacę 4 000 zł', disabled: G.funds() < 4000, act: () => { G.pay(4000); S.flags.krukMet = true; S.flags.krukPaid = true; UI.toast('🐺 Wilki przestają się Tobą interesować', 'good'); UI.dialog({ name: 'Kruk', lines: ['Rozsądnie. Miło mieć z Tobą do czynienia.'], onEnd: () => G.requestLock() }); } },
        {
          label: 'Zaproponuj układ: sprzedam wam towar (8× Dym, min. Zwykły).', disabled: has < 1, act: () => {
            const who = { name: 'Kruk', bio: 'Szef Wilków. Nie lubi być oszukiwany.', wealth: 1.0, pref: { dym: 1.0 }, patience: 3, tough: 1.5, minQ: 1, nerv: 0.3, st: { loy: 0, tol: {} } };
            S.flags.krukMet = true;
            UI.dialog({ name: 'Kruk', lines: ['Towar zamiast gotówki? Interesujące. Pokaż, co masz. Ale pamiętaj: oszukasz mnie — pożałujesz.'], onEnd: () => { if (!UI.openDeal({ who, product: 'dym', qty: 8, story: 'kruk', street: false, onDone: (r) => { if (!r.sold) { S.flags.krukRefused = true; UI.toast('🐺 Wilki są niezadowolone…', 'bad'); } } })) { S.flags.krukRefused = true; G.requestLock(); } } });
          },
        },
        { label: 'Spadaj, nic Wam nie płacę.', cls: 'bad', act: () => { S.flags.krukMet = true; S.flags.krukRefused = true; UI.toast('⚠️ Wilki będą Cię napadać w swoim rejonie nocą', 'bad'); UI.dialog({ name: 'Kruk', lines: ['Zobaczymy, jak będziesz tak mówił po zmroku, kolego.'], onEnd: () => G.requestLock() }); } },
        { label: 'Wrócę później.', act: () => G.requestLock() },
      ],
    });
  },
  krukWar() {
    const S = G.S;
    UI.dialog({
      name: 'Kruk', lines: [
        'Urosłeś. Za bardzo. Twoi dilerzy stoją na rogach, o których kiedyś decydowałem ja.',
        'Mam dla Ciebie trzy drogi. Sojusz: 8 000 i moi ludzie pracują dla Ciebie. Wojna: spróbuj sił. Albo… idź do swoich przyjaciół w mundurach, jeśli ich masz.',
      ],
      choices: [
        { label: 'Sojusz: płacę 8 000 zł (dostajesz dodatkowego dilera)', disabled: G.funds() < 8000, cls: 'go', act: () => { G.pay(8000); S.flags.warDone = true; S.flags.wilkiAlly = true; S.flags.krukPaid = true; S.crew.push({ name: 'Wilk „Zęby”', spot: null, product: 'dym', jail: 0, sold: 0 }); S.up.dealer = Math.max(G.lvl('dealer'), 1); UI.toast('🐺 Wilki są Twoimi sojusznikami. Nowy diler w ekipie.', 'good'); UI.dialog({ name: 'Kruk', lines: ['Jedna wataha. Nie zawiedź nas.'], onEnd: () => G.requestLock() }); } },
        { label: 'Wydaj Wilki Wronie (wymaga układu z Wroną)', disabled: !S.flags.wronaPaid, act: () => { S.flags.warDone = true; S.flags.wilkiGone = true; S.flags.krukPaid = true; G.addHeat(30, false); G.addInvest(-20); G.syncStoryNpcs(); UI.toast('🚔 Policja zrobiła nalot na Zaułek. Wilki zniknęły z miasta.', 'good'); UI.dialog({ name: 'Insp. Wrona (telefon)', lines: ['Ładna robota. Zaułek jest czysty. Ale pamiętaj — teraz wisisz mi przysługę.'], onEnd: () => G.requestLock() }); } },
        { label: 'Wojna. Niczego Wam nie oddam.', cls: 'bad', act: () => { S.flags.warDone = true; S.flags.wilkiWar = true; S.flags.krukRefused = true; S.flags.krukPaid = false; UI.toast('⚔️ Wilki polują na Ciebie nocą w całej południowo-zachodniej części miasta', 'bad'); UI.dialog({ name: 'Kruk', lines: ['Odważnie. Głupio, ale odważnie.'], onEnd: () => G.requestLock() }); } },
        { label: 'Daj mi czas.', act: () => G.requestLock() },
      ],
    });
  },

  /* ---------- Pan Hieronim (dostawca) ---------- */
  talkHieronim() {
    const S = G.S;
    if (!S.flags.hier) {
      return UI.dialog({
        name: 'Pan Hieronim', lines: [
          'Staś mówił, że przyjdziesz. Trzydzieści lat pracowałem w zakładach chemicznych. Wiem o reakcjach więcej niż cała ta policja razem wzięta.',
          'Mam Rzadki ekstrakt, Katalizator i Wzmacniacz. Z nich powstaje Złoty Pył — towar dla ludzi z portfelami grubszymi niż Twój dług.',
          'Wpisowe: 3 000 złotych. Potem handlujemy. I nigdy, przenigdy nie przyprowadzaj tu nikogo.',
        ],
        choices: [
          { label: 'Płacę 3 000 zł', disabled: G.funds() < 3000, act: () => { G.pay(3000); S.flags.hier = true; UI.toast('🔓 Hieronim sprzedaje rzadkie składniki. W Sklepie dostępne Laboratorium.', 'good'); UI.dialog({ name: 'Pan Hieronim', lines: ['Dobrze. Jestem tu każdej nocy między 22 a 4. Laboratorium kupisz sam — tylko za czyste pieniądze, żadnej gotówki z ulicy.'], onEnd: () => UI.openShop('hier') }); } },
          { label: 'Wrócę z pieniędzmi.', act: () => G.requestLock() },
        ],
      });
    }
    UI.dialog({ name: 'Pan Hieronim', lines: [pick(['Szybko. Nie lubię tu stać.', 'Co dziś?', 'Towar ten sam, cena ta sama. Bierzesz?'])], onEnd: () => UI.openShop('hier') });
  },

  /* ---------- Pan Wiesio (myjnia) ---------- */
  talkWiesio() {
    const S = G.S;
    if (!S.flags.wiesio) {
      return UI.dialog({
        name: 'Pan Wiesio', lines: [
          'Dzień dobry, dzień dobry! Mycie, woskowanie, odkurzanie? …A, od Madame K. To zmienia postać rzeczy.',
          'Widzi Pan, myjnia to piękny interes. Gotówka wpływa, nikt nie liczy, ile aut naprawdę umyto. Pan przynosi „utarg”, ja go księguję, a na konto wpływają czyste pieniądze.',
          'Mogę Panu odsprzedać udziały. 18 000 złotych i pierzemy do 2 500 dziennie. Z konta kupi Pan to, czego za gotówkę z ulicy nikt nie sprzeda.',
        ],
        onEnd: () => { S.flags.wiesio = true; UI.openWash(); },
      });
    }
    UI.dialog({ name: 'Pan Wiesio', lines: [pick(['Co dziś pierzemy, szefie?', 'Utarg, utarg, jak ja kocham utarg.', 'Księgi czyste jak łza.'])], onEnd: () => UI.openWash() });
  },

  /* ---------- Księgowy (ostatnia robota) ---------- */
  talkKsiegowy() {
    const S = G.S, o = S.orders.find(x => x.story === 'FIN');
    if (!o) return UI.dialog({ name: 'Księgowy', lines: ['Rozmowy o pieniądzach — wyłącznie przez telefon.'], onEnd: () => G.requestLock() });
    const who = Object.assign({}, KSIEGOWY_DEF, { st: { loy: 0, tol: {} } });
    UI.dialog({ name: 'Księgowy', lines: [`Proszę, proszę. Punktualny. Zostało jeszcze ${o.qty} sztuk. Jakość minimum Dobry. Proszę pokazać.`], onEnd: () => { if (!UI.openDeal({ who, product: null, qty: o.qty, order: o, street: true, any: true })) G.requestLock(); } });
  },

  /* ---------- widoczność postaci fabularnych ---------- */
  syncStoryNpcs() {
    const S = G.S, cur = STORY[S.step], h = G.hour(), night = h >= 21 || h < 4, late = h >= 22 || h < 4;
    NPC.hide(NPC.wrona, !(cur && cur.id === 'wrona' && !S.flags.wronaMet && night));
    NPC.hide(NPC.hier, !((S.flags.hierTip || S.flags.hier) && late));
    NPC.hide(NPC.ksiegowy, !(cur && cur.id === 'lastjob' && !S.flags.lastJob && late));
    for (const n of NPC.all) if (n.thug || n === NPC.kruk) NPC.hide(n, !!S.flags.wilkiGone);
    if (cur && cur.id === 'lastjob' && late && !G.mod('oblawa') && !S.flags.lastJob) {
      G.setMod('oblawa', 6); UI.toast('🚨 Policja węszy wokół Parkingu. Uważaj na posterunki!', 'bad');
      for (const [x, z] of [[68, -8], [52, -52], [68, -52]]) { const c = NPC.spawnCop(); c.post = true; c.state = 'post'; c.x = x; c.z = z; }
    }
  },

  /* ---------- napady Wilków ---------- */
  muggingCheck(dt) {
    const S = G.S, P = G.player;
    if (P.loc !== 'out' || S.flags.krukPaid || S.flags.wilkiGone || W.nightF < 0.3) return;
    const inZone = G.zone && G.zone.gang, war = S.flags.wilkiWar && P.x < 0 && P.z > 0;
    if (!(S.flags.krukRefused && (inZone || war))) return;
    if (Math.random() < dt * (inZone ? 0.045 : 0.012)) {
      let lost = 0; for (const p in S.inv.prod) for (let q = 0; q < 4; q++) { const l = Math.ceil(S.inv.prod[p][q] * 0.4); S.inv.prod[p][q] -= l; lost += l; }
      const cash = Math.round(S.cash * 0.25); S.cash -= cash;
      UI.hurt(); G.shake = 1; UI.toast(`🐺 Wilki Cię napadły! Straciłeś ${lost} szt. towaru i ${money(cash)}.`, 'bad');
    }
  },

  /* ---------- intro / finał / zakończenia ---------- */
  intro() {
    UI.dialog({
      name: 'Narrator', lines: [
        { t: 'Dzień 1, godzina 8:00. Trzy miesiące po zwolnieniu z pracy. Lodówka pusta, konto na minusie, a czynsz sam się nie zapłaci.' },
        { t: 'I wtedy pojawił się on — Bolek „Księgowy” Zawada. Uprzejmy, w garniturze, z uśmiechem człowieka, który zna cenę wszystkiego. Pożyczył Ci pieniądze „na start nowego życia”. Z odsetkami zrobiło się z tego 70 000 zł.' },
        { n: 'Księgowy (telefon)', t: 'Panie kolego, mamy 56 dni. Pierwsza rata — 1 500 zł — za tydzień. Co tydzień doliczam 2% odsetek. Nie lubię, kiedy ktoś się spóźnia. Naprawdę nie lubię.' },
        { n: 'Narrator', t: 'Jedyne światełko w tunelu to Wujek Staś. Mówił, że ma „sposób na szybki zarobek”. Jego Hurtownia jest na zachód stąd, za ulicą — zielone drzwi.' },
        { n: 'Narrator', t: 'Telefon (Tab) pokaże Ci cele, SMS-y i mapę. Zielona trasa na ziemi prowadzi do celu (N — wł./wył., Q — zmiana celu). Wyjdź przez drzwi na południowej ścianie mieszkania.' },
      ],
      onEnd: () => { G.msg('Księgowy', 'Termin pierwszej raty: dzień 7. Łącznie 1 500 zł. Nie zapomnij.'); G.requestLock(); },
    });
  },
  finale() {
    const S = G.S;
    UI.dialog({
      name: 'Księgowy (telefon)', lines: [
        'Spłacone. Co do grosza. Muszę przyznać, że… zaimponował mi Pan.',
        'Zwykle ludzie kończą w rzece albo w celi. Pan, panie kolego, kończy z uśmiechem. A ja zawsze doceniam dobrych inwestorów.',
        'Mam propozycję: zostaje Pan. Duże miasto, duże możliwości. Albo… wychodzi Pan z interesu, póki jest co zabrać do domu.',
      ],
      choices: [
        { label: 'Dziękuję, kończę z tym. Zaczynam od nowa.', act: () => G.ending('wolnosc') },
        { label: 'Zostaję. To miasto będzie moje.', cls: 'go', act: () => { S.flags.empire = true; S.step = STORY.length - 1; UI.toast('👑 Nowy cel: zgromadź 250 000 zł', 'good'); G.requestLock(); } },
        { label: 'Zeznaję przeciwko Księgowemu (wymaga układu z Wroną)', disabled: !S.flags.wronaPaid, act: () => G.ending('swiadek') },
      ],
    });
  },
  ending(kind) {
    const S = G.S;
    const E = {
      wolnosc: ['WOLNOŚĆ', 'Spłaciłeś dług i zamknąłeś ten rozdział. Wracasz do zwykłego życia — z nową pracą, nowym mieszkaniem i historią, o której nikomu nie opowiesz. Czasami, gdy mijasz zielone drzwi, czujesz dreszcz. Ale idziesz dalej.'],
      imperium: ['KRÓL MIASTA', 'Ćwierć miliona. Wilki skłaniają głowy, Wrona odbiera kopertę bez słowa, a Księgowy dzwoni z gratulacjami. Miasto jest Twoje. Pytanie tylko, jak długo — i czy to naprawdę jest to, czego chciałeś, gdy zaczynałeś z długiem i jedną doniczką.'],
      swiadek: ['ŚWIADEK KORONNY', 'Wrona dotrzymał słowa. Księgowy trafił za kratki na piętnaście lat, a Ty — z nowym nazwiskiem — do małego miasta nad morzem. Nikt Cię tu nie zna. Czasem tylko, gdy dzwoni nieznany numer, serce bije odrobinę szybciej.'],
      dlug: ['PŁYWASZ W WIŚLE', 'Trzy zaległe raty. Księgowy zawsze dotrzymuje słowa — ostatnie, co usłyszałeś, to cichy plusk. Gdybyś tylko spłacał na czas…'],
      wyrok: ['WYROK', 'Po raz piąty trafiłeś w ręce policji. Tym razem nie pomoże ani prawnik, ani koperta. Sąd nie ma litości dla recydywistów. Kilka lat za kratami na przemyślenia.'],
    }[kind];
    G.running = false; Snd.sirenOff();
    UI.closeAll(); UI.mode = 'end';
    $('endTitle').textContent = E[0]; $('endText').textContent = E[1];
    $('endStats').innerHTML = `Dni: <b>${G.day()}</b> • Zarobione: <b>${money(S.stats.earned)}</b> • Sprzedane jednostki: <b>${S.stats.sold}</b><br>Partie: <b>${S.stats.batchesCollected}</b> • Zatrzymania: <b>${S.arrests}</b> • Reputacja: <b>${Math.floor(S.rep)}</b> • Poziom: <b>${S.lvl}</b>`;
    $('ending').classList.remove('hidden'); $('hud').classList.add('hidden');
    try { localStorage.removeItem(SAVE_KEY); } catch (e) {}
  },

  /* ---------- cele ---------- */
  chapterOf(i) { for (let k = Math.min(i, STORY.length - 1); k >= 0; k--) if (STORY[k].ch) return STORY[k].ch; return ''; },
  completeStep() {
    const S = G.S, st = STORY[S.step];
    UI.toast('✔ Cel ukończony: ' + st.text().split('.')[0].split('(')[0], 'good'); G.addXp(40);
    if (st.onDone) st.onDone();
    S.step++;
    const nx = STORY[S.step];
    if (nx) { if (nx.ch) setTimeout(() => UI.toast('📖 ' + nx.ch, 'warn'), 1300); if (nx.onStart) nx.onStart(); }
    G.syncStoryNpcs(); G.navDirty = true;
  },
  /* najbliższy chętny przechodzień (do samouczka sprzedaży) */
  nearestBuyer() {
    const P = G.player; let best = null, bd = 1e9;
    for (const c of NPC.customers) { const d = Math.hypot(c.x - P.x, c.z - P.z); if (d < bd) { bd = d; best = c; } }
    if (best) return best;
    for (const c of NPC.citizens) { if (!c.user || c.refused || c.lastDeal) continue; const d = Math.hypot(c.x - P.x, c.z - P.z); if (d < bd) { bd = d; best = c; } }
    return best;
  },
});

const STORY = [
  { ch: 'Rozdział 1: Dług', id: 'leave', text: () => 'Wyjdź z mieszkania na ulicę (drzwi na południowej ścianie).', done: () => G.S.flags.leftHome, marker: () => ({ loc: 'safe', x: W.rooms.safe.exit[0], z: W.rooms.safe.exit[1] }) },
  { id: 'shop', text: () => 'Odwiedź Hurtownię Wujka Stasia (zielone drzwi po zachodniej stronie ulicy).', done: () => G.S.flags.metStasiu, marker: () => ({ loc: 'shop', x: NPC.stasiu.x, z: NPC.stasiu.z + 2.4 }) },
  { id: 'brew', text: () => 'Wróć do mieszkania i zasadź Zielony Dym w doniczkach (stół przy północnej ścianie).', done: () => G.S.stats.batchesStarted >= 1, marker: () => ({ loc: 'safe', x: W.rooms.safe.cx - 3.6, z: -5.5 }) },
  {
    id: 'collect', text: () => 'Poczekaj, aż partia dojrzeje (ok. 6 h gry), i odbierz ją. Możesz przespać się w łóżku.', done: () => G.S.stats.batchesCollected >= 1, marker: () => ({ loc: 'safe', x: W.rooms.safe.cx - 3.6, z: -5.5 }),
    onDone: () => { G.S.flags.ordersOn = true; G.unlockCustomer('dominik', 'Hej, tu Dominik, kumpel Stasia. Podobno masz Dym?'); G.makeOrder(CUSTOMERS[0]); },
  },
  {
    id: 'sell', text: () => `Sprzedaj 3 jednostki towaru: odpisz na SMS (Tab → Wiadomości) albo zagadaj przechodnia z ikoną 👀. (${Math.min(3, G.S.stats.sold)}/3)`, done: () => G.S.stats.sold >= 3,
    marker: () => { const b = G.nearestBuyer(); return b ? { loc: 'out', x: b.x, z: b.z } : null; },
  },
  { id: 'earn1', text: () => `Zarób łącznie 1 500 zł ze sprzedaży. (${money(G.S.stats.earned)})`, done: () => G.S.stats.earned >= 1500, onDone: () => G.msg('Wujek Staś', 'Chłopcze, wpadnij do hurtowni. Mam wieści.') },

  { ch: 'Rozdział 2: Znajomości', id: 'stasiu2', text: () => 'Wujek Staś ma dla Ciebie wieści. Wpadnij do Hurtowni.', done: () => G.S.flags.stasiu2, marker: () => ({ loc: 'shop', x: NPC.stasiu.x, z: NPC.stasiu.z + 2.4 }) },
  { id: 'madame', text: () => 'Spotkaj Madame K w klubie Neon (loża VIP w rogu sali).', done: () => G.S.flags.metMadame, marker: () => ({ loc: 'club', x: NPC.madame.x - 1.2, z: NPC.madame.z + 1.6 }) },
  { id: 'bulk', text: () => { const o = G.S.orders.find(x => x.story === 'K1'); return `Dostarcz Madame K 10× Zielony Dym (min. jakość Zwykły) — zostało ${o ? o.qty : 0}.`; }, done: () => G.S.flags.kDone, marker: () => ({ loc: 'club', x: NPC.madame.x - 1.2, z: NPC.madame.z + 1.6 }) },
  { id: 'reaktor', text: () => 'Kup stół reakcyjny (telefon → Sklep) i wyprodukuj partię Niebieskiego Szronu.', done: () => (G.S.stats.made_szron || 0) >= 1 },
  { id: 'earn2', text: () => `Zarób łącznie 7 000 zł. (${money(G.S.stats.earned)})`, done: () => G.S.stats.earned >= 7000 },

  {
    ch: 'Rozdział 3: Czarna Wrona', id: 'wrona', text: () => 'Inspektor Wrona czeka na Parkingu po 21:00. Idź sam.', done: () => G.S.flags.wronaMet, marker: () => ({ loc: 'out', x: 82, z: -40 }),
    onStart: () => G.msg('Numer zastrzeżony', 'Wiem, czym handlujesz. Parking, po 21:00. Przyjdź sam. — W.'),
  },
  { id: 'crew', text: () => 'Zatrudnij dilera (telefon → Sklep) i przydziel mu punkt oraz towar (telefon → Ekipa).', done: () => G.S.crew.some(c => c.spot) },
  { id: 'earn3', text: () => `Zarób łącznie 15 000 zł. (${money(G.S.stats.earned)})`, done: () => G.S.stats.earned >= 15000 },

  {
    ch: 'Rozdział 4: Wilki', id: 'kruk', text: () => 'Kruk z Wilków chce z Tobą porozmawiać. Zaułek w południowo-zachodnim rogu miasta.', done: () => G.S.flags.krukMet, marker: () => ({ loc: 'out', x: -93, z: 90 }),
    onStart: () => G.msg('Kruk', 'Handlujesz na naszej ziemi bez pozwolenia. Zaułek. Przyjdź.'),
  },
  { id: 'earn4', text: () => `Zarób łącznie 26 000 zł. (${money(G.S.stats.earned)})`, done: () => G.S.stats.earned >= 26000 },

  {
    ch: 'Rozdział 5: Przykrywka', id: 'wiesioMeet', text: () => G.S.flags.wiesioTip ? 'Odwiedź Pana Wiesia w Myjni Kryształ (wschodnia część miasta).' : 'Madame K chce z Tobą pomówić o „świeceniu”. Klub Neon.', done: () => G.S.flags.wiesio,
    marker: () => G.S.flags.wiesioTip ? { loc: 'wash', x: NPC.wiesio.x, z: NPC.wiesio.z + 2.5 } : { loc: 'club', x: NPC.madame.x - 1.2, z: NPC.madame.z + 1.6 },
    onStart: () => G.msg('Madame K', 'Skarbie, wpadnij do klubu. Musimy porozmawiać o tym, jak bardzo rzucasz się w oczy.'),
  },
  { id: 'buyWash', text: () => 'Kup udziały w myjni u Pana Wiesia (18 000 zł).', done: () => G.lvl('myjnia') >= 1, marker: () => ({ loc: 'wash', x: NPC.wiesio.x, z: NPC.wiesio.z + 2.5 }) },
  { id: 'launder', text: () => `Wypierz łącznie 5 000 zł w myjni (pranie odbywa się codziennie o 6:00). (${money(G.S.stats.laundered)})`, done: () => G.S.stats.laundered >= 5000, marker: () => ({ loc: 'wash', x: NPC.wiesio.x, z: NPC.wiesio.z + 2.5 }) },

  {
    ch: 'Rozdział 6: Alchemik', id: 'hier', text: () => G.S.flags.hierTip ? 'Spotkaj Pana Hieronima na Podwórku po 22:00 (weź 3 000 zł).' : 'Wujek Staś zna kogoś, kto ma „lepsze składniki”. Zapytaj go w Hurtowni.', done: () => G.S.flags.hier,
    marker: () => G.S.flags.hierTip ? { loc: 'out', x: -84, z: -93 } : { loc: 'shop', x: NPC.stasiu.x, z: NPC.stasiu.z + 2.4 },
    onStart: () => G.msg('Wujek Staś', 'Chłopcze, czas na wyższą ligę. Wpadnij, opowiem Ci o pewnym chemiku.'),
  },
  { id: 'lab', text: () => 'Kup Laboratorium (18 000 zł z konta — czyste pieniądze) i wyprodukuj Złoty Pył.', done: () => (G.S.stats.made_pyl || 0) >= 1 },
  { id: 'sellPyl', text: () => `Sprzedaj 6 szt. Złotego Pyłu. (${G.S.stats.byProd.pyl || 0}/6)`, done: () => (G.S.stats.byProd.pyl || 0) >= 6 },

  {
    ch: 'Rozdział 7: Wojna o ulice', id: 'war', text: () => G.S.flags.wilkiGone ? 'Wilki zniknęły z miasta.' : 'Kruk żąda rozmowy. Zaułek Wilków — zdecyduj: sojusz, wojna albo donos.', done: () => G.S.flags.warDone, marker: () => ({ loc: 'out', x: -93, z: 90 }),
    onStart: () => G.msg('Kruk', 'Za dużo Cię na naszych rogach. Zaułek. Dziś. Zdecydujemy, co dalej.'),
  },
  { id: 'earn5', text: () => `Zarób łącznie 60 000 zł. (${money(G.S.stats.earned)})`, done: () => G.S.stats.earned >= 60000 },

  {
    ch: 'Rozdział 8: Rozliczenie', id: 'lastjob', text: () => { const o = G.S.orders.find(x => x.story === 'FIN'); return `Ostatnia robota: dostarcz Księgowemu 20 szt. towaru (min. Dobry) na Parking między 22:00 a 4:00 — zostało ${o ? o.qty : 0}. Uwaga na posterunki.`; },
    done: () => G.S.flags.lastJob, marker: () => ({ loc: 'out', x: 96, z: -22 }),
    onStart: () => {
      const S = G.S;
      S.orders.push({ id: S.nextOrderId++, cust: 'madame', product: 'dym', any: true, qty: 20, minQ: 2, spot: 'parking', deadline: S.t + 30 * 1440, respondBy: S.t + 30 * 1440, status: 'accepted', story: 'FIN', stated: 0, noise: 1, text: 'Księgowy: 20 szt. dowolnego towaru (min. Dobry). Parking, nocą 22:00–4:00.' });
      G.msg('Księgowy', 'Panie kolego, ostatnia robota. 20 sztuk, jakość minimum Dobry. Parking, nocą między 22 a 4. Potem rozmawiamy o resztce długu.');
    },
  },
  { id: 'pay', text: () => `Spłać resztę długu: telefon (Tab) → Finanse. Pozostało ${money(G.S.debt)}.`, done: () => false },
  { ch: 'Epilog: Imperium', id: 'empire', text: () => `Zgromadź 250 000 zł majątku, by zostać królem miasta. (${money(G.netWorth())})`, done: () => G.netWorth() >= 250000, onDone: () => setTimeout(() => G.ending('imperium'), 600) },
];
