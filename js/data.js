/* ============================================================
   CZARNY RYNEK — dane gry
   Wszystkie substancje, nazwy, receptury i postacie są w pełni FIKCYJNE.
   ============================================================ */
'use strict';

const TIME_SCALE = 2.0;            // minut gry na sekundę (doba = 12 min)
const QNAMES = ['Słaby', 'Zwykły', 'Dobry', 'Premium'];
const QMULT = [0.65, 1.0, 1.35, 1.8];
const QCOLOR = ['#9ca3af', '#e5e7eb', '#60a5fa', '#fbbf24'];

const PRODUCTS = {
  dym:   { id: 'dym',   name: 'Zielony Dym',     icon: '🌿', base: 42,  color: '#4ade80' },
  szron: { id: 'szron', name: 'Niebieski Szron', icon: '💎', base: 110, color: '#60a5fa' },
  neon:  { id: 'neon',  name: 'Neon',            icon: '💊', base: 74,  color: '#f472b6' },
  pyl:   { id: 'pyl',   name: 'Złoty Pył',       icon: '✨', base: 230, color: '#fbbf24' },
};

const INGREDIENTS = {
  nasiona:        { name: 'Nasiona Dymu',   icon: '🌱', price: 24,  src: 'stas' },
  nawoz:          { name: 'Nawóz',          icon: '🧪', price: 18,  src: 'stas' },
  prekursor:      { name: 'Prekursor Z',    icon: '⚗️', price: 75,  src: 'stas', req: 'ch2' },
  rozpuszczalnik: { name: 'Rozpuszczalnik', icon: '🫙', price: 42,  src: 'stas', req: 'ch2' },
  proszek:        { name: 'Proszek bazowy', icon: '🥣', price: 38,  src: 'stas', req: 'ch2' },
  spoiwo:         { name: 'Spoiwo',         icon: '🧂', price: 24,  src: 'stas', req: 'ch2' },
  stabilizator:   { name: 'Stabilizator',   icon: '🧊', price: 45,  src: 'stas', req: 'ch2', extra: true, desc: 'Dodatek: chroni partię przed zepsuciem i poszerza zielone strefy.' },
  ekstrakt:       { name: 'Rzadki ekstrakt', icon: '🍯', price: 160, src: 'hier' },
  katalizator:    { name: 'Katalizator',    icon: '🔩', price: 120, src: 'hier' },
  wzmacniacz:     { name: 'Wzmacniacz',     icon: '⚡', price: 95,  src: 'hier', extra: true, desc: 'Dodatek: +1 poziom jakości partii.' },
};

const STATIONS = {
  doniczki: { name: 'Doniczki',          slots: 3, max: 5, product: 'dym',   unlock: null,      icon: '🪴' },
  reaktor:  { name: 'Stół reakcyjny',    slots: 2, max: 4, product: 'szron', unlock: 'reaktor', icon: '⚗️' },
  prasa:    { name: 'Prasa do tabletek', slots: 2, max: 4, product: 'neon',  unlock: 'prasa',   icon: '⚙️' },
  lab:      { name: 'Laboratorium',      slots: 2, max: 3, product: 'pyl',   unlock: 'lab',     icon: '🔬' },
};

const RECIPES = {
  dym:   { station: 'doniczki', inputs: { nasiona: 1, nawoz: 1 },                       hours: 6,  yield: 4, verb: 'Sadzenie' },
  szron: { station: 'reaktor',  inputs: { prekursor: 2, rozpuszczalnik: 1 },            hours: 8,  yield: 3, verb: 'Reakcja' },
  neon:  { station: 'prasa',    inputs: { proszek: 2, spoiwo: 1 },                      hours: 9,  yield: 5, verb: 'Prasowanie' },
  pyl:   { station: 'lab',      inputs: { ekstrakt: 1, katalizator: 1, prekursor: 1 },  hours: 14, yield: 2, verb: 'Destylacja' },
};

/* ulepszenia: levels[] = kolejne poziomy; clean = tylko czyste pieniądze z konta */
const UPGRADES = [
  { id: 'plecak',    name: 'Plecak',               icon: '🎒', levels: [{ cost: 1500, desc: 'Udźwig 20 → 36 szt.' }, { cost: 5000, desc: 'Udźwig 36 → 56 szt.' }] },
  { id: 'sprzet',    name: 'Lepszy sprzęt',        icon: '⏱️', levels: [{ cost: 3200, desc: 'Produkcja o 15% szybsza.' }, { cost: 9000, desc: 'Produkcja o 30% szybsza.' }, { cost: 18000, desc: 'Produkcja o 42% szybsza.', clean: true }] },
  { id: 'partie',    name: 'Większe partie',       icon: '📦', levels: [{ cost: 3000, desc: '+1 szt. z każdej partii.' }, { cost: 8500, desc: '+2 szt. z każdej partii.' }, { cost: 17000, desc: '+3 szt. z każdej partii.', clean: true }] },
  { id: 'sloty',     name: 'Dodatkowe stanowiska', icon: '➕', levels: [{ cost: 4200, desc: '+1 miejsce na każdym stanowisku.' }, { cost: 12000, desc: '+2 miejsca na każdym stanowisku.', clean: true }] },
  { id: 'reaktor',   name: 'Stół reakcyjny',       icon: '⚗️', levels: [{ cost: 4500, desc: 'Odblokowuje Niebieski Szron.' }], requires: 'ch2' },
  { id: 'prasa',     name: 'Prasa do tabletek',    icon: '⚙️', levels: [{ cost: 9500, desc: 'Odblokowuje Neon.' }], requires: 'ch2' },
  { id: 'lab',       name: 'Laboratorium',         icon: '🔬', levels: [{ cost: 18000, desc: 'Odblokowuje Złoty Pył.', clean: true }], requires: 'hier' },
  { id: 'pracownik', name: 'Pracownik: Zdzisiek',  icon: '🧑‍🔧', levels: [{ cost: 7500, desc: 'Odbiera gotowe partie do skrytki i zakłada nowe ze składników ze skrytki (jakość Zwykły). Pensja 120 zł/dzień.' }], requires: 'ch2' },
  { id: 'dealer',    name: 'Dilerzy uliczni',      icon: '🕴️', levels: [{ cost: 3500, desc: '1 diler sprzedaje towar ze skrytki (prowizja 25%).' }, { cost: 12000, desc: '2 dilerów.' }, { cost: 24000, desc: '3 dilerów.', clean: true }], requires: 'ch3' },
  { id: 'prawnik',   name: 'Prawnik',              icon: '⚖️', levels: [{ cost: 4500, desc: 'Grzywny −35%, mniejsze ryzyko nalotu.' }, { cost: 13000, desc: 'Grzywny −60%, wolniejsze śledztwo.' }] },
  { id: 'radio',     name: 'Skaner policyjny',     icon: '📻', levels: [{ cost: 6000, desc: 'Patrole widoczne na minimapie.' }] },
  { id: 'alarm',     name: 'Alarm i sejf',         icon: '🔐', levels: [{ cost: 5000, desc: 'Chroni skrytkę przed włamaniem; nalot zabiera o połowę mniej.' }] },
  { id: 'myjnia',    name: 'Myjnia (przykrywka)',  icon: '🚿', levels: [{ cost: 18000, desc: 'Pierze do 2 500 zł dziennie (prowizja 12%).' }, { cost: 30000, desc: 'Pierze do 6 000 zł dziennie (prowizja 10%).' }], requires: 'wiesio', atWash: true },
];

const SKILLS = [
  { id: 'negocjacje', name: 'Negocjacje', icon: '🗣️', desc: ['Lepsze kontroferty', '+1 cierpliwości klientów', 'Skuteczniejsze zachwalanie', '+1 cierpliwości klientów', 'Widzisz przybliżony budżet klienta'] },
  { id: 'dyskrecja',  name: 'Dyskrecja',  icon: '🕶️', desc: ['Policja wolniej nabiera podejrzeń', 'Mniej donosów od świadków', 'Rozpoznajesz prowokacje', 'Uwaga policji rośnie wolniej', 'Krótszy pościg (szybciej Cię gubią)'] },
  { id: 'chemia',     name: 'Chemia',     icon: '🧬', desc: ['Szersze zielone strefy', 'Mniejsze ryzyko zepsucia partii', '+1 szt. z partii', 'Szersze zielone strefy', 'Szansa na jakość o poziom wyższą'] },
  { id: 'kondycja',   name: 'Kondycja',   icon: '🏃', desc: ['Dłuższy sprint', 'Szybszy sprint', 'Dłuższy sprint', 'Szybsza regeneracja', 'Dłuższy i szybszy sprint'] },
  { id: 'biznes',     name: 'Biznes',     icon: '📈', desc: ['Tańsze składniki (−5%)', 'Chętni klienci widoczni z dalszej odległości', 'Tańsze pranie pieniędzy', 'Dilerzy sprzedają więcej', 'Tańsze składniki (−15%)'] },
];

/* Klienci stali (fikcyjni). honesty = jak blisko prawdy podają budżet w SMS-ie */
const CUSTOMERS = [
  { id: 'dominik', name: 'Dominik „Student”', color: '#3b82f6', wealth: 0.8,  pref: { dym: 1.1 },                        patience: 5, tough: 0.9,  minQ: 0, qty: [1, 3],  nerv: 0.1,  unlockRep: 0,    honesty: 0.95, bio: 'Student zaoczny. Zawsze spłukany, ale lojalny i szczery.', look: { top: { type: 'hoodie', color: '#3b82f6' }, hair: 'short' } },
  { id: 'zenon',   name: 'Pan Zenon',         color: '#92400e', wealth: 0.75, pref: { dym: 1.2 },                        patience: 6, tough: 0.7,  minQ: 0, qty: [1, 2],  nerv: 0.05, unlockRep: 5,    honesty: 0.8,  bio: 'Emeryt. Targuje się z przyzwyczajenia, nie ze skąpstwa.', look: { top: { type: 'coat', color: '#6b5a45', color2: '#c9b89a' }, hair: 'bald', hairColor: '#aaaaaa', female: false, glasses: true } },
  { id: 'kasia',   name: 'Kasia z Biura',     color: '#a855f7', wealth: 1.1,  pref: { dym: 1.0, neon: 1.1 },             patience: 3, tough: 1.0,  minQ: 1, qty: [1, 3],  nerv: 0.4,  unlockRep: 10,   honesty: 0.9,  bio: 'Korpo-stres. Płaci dobrze, ale panikuje przy każdym radiowozie.', look: { female: true, top: { type: 'suit', color: '#4b3a6d', color2: '#f0f0f0' }, hair: 'bob' } },
  { id: 'marek',   name: 'Marek Mechanik',    color: '#65a30d', wealth: 0.95, pref: { szron: 1.2, dym: 0.9 },            patience: 4, tough: 1.3,  minQ: 1, qty: [1, 3],  nerv: 0.1,  unlockRep: 16,   honesty: 0.65, bio: 'Twardy negocjator i blefiarz. W SMS-ach zawsze zaniża budżet.', look: { female: false, top: { type: 'jacket', color: '#3d4a2a', color2: '#888' }, beard: true, hat: 'cap' } },
  { id: 'heniek',  name: 'Gruby Heniek',      color: '#dc2626', wealth: 1.25, pref: { neon: 1.25, dym: 0.9 },            patience: 2, tough: 0.8,  minQ: 0, qty: [2, 5],  nerv: 0.15, unlockRep: 24,   honesty: 1.0,  bio: 'Impulsywny. Kupuje szybko i dużo, ale nie znosi gadania.', look: { female: false, build: 1.3, top: { type: 'tshirt', color: '#dc2626' }, hair: 'buzz' } },
  { id: 'ola',     name: 'Ola Tatuażystka',   color: '#0d9488', wealth: 1.05, pref: { dym: 1.15, szron: 1.0 },           patience: 4, tough: 1.05, minQ: 1, qty: [2, 4],  nerv: 0.08, unlockRep: 30,   honesty: 0.85, bio: 'Prowadzi studio. Ceni stałą jakość, szybko się nudzi tym samym towarem.', look: { female: true, top: { type: 'tank', color: '#111111' }, hair: 'ponytail', hairColor: '#8a3324' } },
  { id: 'natalia', name: 'DJ Natalia',        color: '#ec4899', wealth: 1.35, pref: { neon: 1.35, szron: 1.0 },          patience: 4, tough: 1.0,  minQ: 2, qty: [2, 4],  nerv: 0.1,  unlockRep: 38,   honesty: 0.9,  bio: 'Gra w klubach. Chce tylko dobry towar i płaci za jakość.', look: { female: true, top: { type: 'jacket', color: '#ec4899', color2: '#111' }, hair: 'long', hairColor: '#222831' } },
  { id: 'zbyszek', name: 'Prof. Zbyszek',     color: '#0ea5e9', wealth: 1.2,  pref: { szron: 1.4, pyl: 1.1 },            patience: 5, tough: 1.1,  minQ: 3, qty: [1, 2],  nerv: 0.2,  unlockRep: 48,   honesty: 0.85, bio: 'Wykładowca chemii (!). Kupuje wyłącznie Premium i zna się na rzeczy.', look: { female: false, top: { type: 'suit', color: '#5b4a3a', color2: '#e8e8e8' }, glasses: true, hair: 'short', hairColor: '#7d7d7d', beard: '#7d7d7d' } },
  { id: 'bartek',  name: 'Bartek Handlarz',   color: '#14b8a6', wealth: 1.6,  pref: { dym: 1.0, szron: 1.1, neon: 1.1 }, patience: 3, tough: 1.45, minQ: 2, qty: [5, 9],  nerv: 0.1,  unlockRep: 62,   honesty: 0.6,  bio: 'Hurtownik z innego miasta. Duże ilości, brutalne targi.', look: { female: false, top: { type: 'jacket', color: '#1c1c1e', color2: '#14b8a6' }, hair: 'buzz', chain: true } },
  { id: 'iga',     name: 'Mecenas Iga',       color: '#b45309', wealth: 1.7,  pref: { pyl: 1.3, szron: 1.1 },            patience: 3, tough: 1.2,  minQ: 2, qty: [1, 3],  nerv: 0.3,  unlockRep: 78,   honesty: 0.9,  bio: 'Adwokat z dobrej kancelarii. Dyskrecja ponad wszystko.', look: { female: true, top: { type: 'suit', color: '#1f2937', color2: '#f5f5f5' }, hair: 'bob', hairColor: '#c8ae82' } },
  { id: 'rysiek',  name: 'Rysiek Taksówkarz', color: '#ca8a04', wealth: 0.9,  pref: { neon: 1.2, dym: 1.0 },             patience: 5, tough: 0.9,  minQ: 0, qty: [2, 4],  nerv: 0.05, unlockRep: 90,   honesty: 0.9,  bio: 'Zna całe miasto. Poleca Cię innym — z nim reputacja rośnie szybciej.', look: { female: false, top: { type: 'shirt', color: '#ca8a04' }, hat: 'cap', hatColor: '#3a3a3a', beard: true } },
  { id: 'wiktor',  name: 'Wiktor z Giełdy',   color: '#4f46e5', wealth: 2.0,  pref: { pyl: 1.4 },                        patience: 2, tough: 1.3,  minQ: 3, qty: [2, 4],  nerv: 0.25, unlockRep: 105,  honesty: 0.75, bio: 'Makler. Płaci fortunę za Złoty Pył Premium, ale nie ma czasu na targi.', look: { female: false, top: { type: 'suit', color: '#1e1b4b', color2: '#ffffff' }, hair: 'short', watch: true } },
  { id: 'paula',   name: 'Paula Influencerka', color: '#f43f5e', wealth: 1.5, pref: { neon: 1.3, pyl: 1.15 },            patience: 3, tough: 1.0,  minQ: 2, qty: [3, 6],  nerv: 0.45, unlockRep: 120,  honesty: 0.7,  bio: 'Pół miasta ją obserwuje. Świetna klientka — i chodzące ryzyko.', look: { female: true, top: { type: 'dress', color: '#f43f5e' }, hair: 'long', hairColor: '#c8ae82' } },
  { id: 'madame',  name: 'Madame K',          color: '#f59e0b', wealth: 1.8,  pref: { dym: 1.0, szron: 1.2, neon: 1.2, pyl: 1.2 }, patience: 4, tough: 1.15, minQ: 1, qty: [6, 12], nerv: 0, unlockRep: 99999, honesty: 0.85, bio: 'Właścicielka klubu Neon. Zamawia partiami i zawsze w klubie.', clubOnly: true },
];

const SPOTS = [
  { id: 'park',       name: 'Park Miejski', x: -22,  z: -25 },
  { id: 'przystanek', name: 'Przystanek',   x: -8.2, z: -30 },
  { id: 'parking',    name: 'Parking',      x: 88,   z: -30 },
  { id: 'podworko',   name: 'Podwórko',     x: -88,  z: -86 },
  { id: 'kiosk',      name: 'Kiosk przy rondzie', x: 50.5, z: -12 },
  { id: 'zaulek_n',   name: 'Brama przy Hurtowni', x: -12, z: 40 },
];

const FIRST_NAMES_M = ['Adam', 'Bartek', 'Czarek', 'Darek', 'Filip', 'Hubert', 'Jacek', 'Kuba', 'Michał', 'Oskar', 'Paweł', 'Rafał', 'Tomek', 'Wojtek', 'Igor', 'Kamil'];
const FIRST_NAMES_F = ['Ewa', 'Gosia', 'Iza', 'Lena', 'Nina', 'Sylwia', 'Ula', 'Zosia', 'Magda', 'Ania', 'Julia', 'Wera'];
const DEALER_NAMES = ['Maciek „Szybki”', 'Krystian', 'Dawid „Młody”', 'Seba', 'Patryk', 'Olek'];

const START_DEBT = 70000;
const DEBT_SCHEDULE = [
  { day: 7, due: 1500 }, { day: 14, due: 4500 }, { day: 21, due: 9500 }, { day: 28, due: 17000 },
  { day: 35, due: 27000 }, { day: 42, due: 39000 }, { day: 49, due: 53000 }, { day: 56, due: 70000 },
];
const DEBT_INTEREST = 0.02;      // tygodniowo od pozostałej kwoty
const RENT = 90;                 // czynsz dzienny
const MAX_ARRESTS = 5, MAX_STRIKES = 3;

const HINTS = [
  'Im bliżej ukrytego maksimum klienta zaproponujesz cenę, tym większy zysk.',
  'Kontroferta klienta zdradza, ile maksymalnie jest gotów zapłacić.',
  'Nie handluj na oczach policji. Nocą jest mniej świadków, ale więcej patroli.',
  'Skrytka w mieszkaniu jest bezpieczna podczas zatrzymania — ale nie podczas nalotu.',
  'Odpowiadaj na SMS-y: po przyjęciu zamówienia klient pojawi się na minimapie.',
  'Klawisz N włącza trasę do celu, Q przełącza kolejne cele.',
  'Klient, który bierze każdą cenę bez mrugnięcia, może być policyjną prowokacją.',
  'Sprzedawaj w różnych dzielnicach. Tam, gdzie handlujesz często, patroli jest więcej.',
  'Ten sam towar sprzedawany w kółko jednemu klientowi traci na wartości (tolerancja).',
  'Brudną gotówkę można wyprać w myjni. Czyste pieniądze są bezpieczne i potrzebne do dużych zakupów.',
  'Dług rośnie o 2% tygodniowo. Wcześniejsza spłata to oszczędność.',
  'Stabilizator chroni partię przed zepsuciem, Wzmacniacz podnosi jakość o poziom.',
];
