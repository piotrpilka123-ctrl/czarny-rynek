extends Node
## Dane gry. Wszystkie substancje, nazwy, osoby i miejsca są FIKCYJNE.

const TIME_SCALE := 1.0          # minut gry na sekundę: 1 godzina gry = 60 sekund (doba = 24 minuty)
## Skala planu miasta (współrzędne w tabelach poniżej są w jednostkach projektu)
const SC := 0.56


func _ready() -> void:
	for s in SPOTS:
		s.x = float(s.x) * SC
		s.z = float(s.z) * SC
	for s in DROPS:
		s.x = float(s.x) * SC
		s.z = float(s.z) * SC
	for z in ZONES:
		for k in ["x0", "x1", "z0", "z1"]:
			z[k] = float(z[k]) * SC
	for k in HOMES:
		HOMES[k].x = float(HOMES[k].x) * SC
		HOMES[k].z = float(HOMES[k].z) * SC
	for k in DOORS:
		DOORS[k].x = float(DOORS[k].x) * SC
		DOORS[k].z = float(DOORS[k].z) * SC


# ---------------------------------------------------------------- towar
const TIER_NAMES := ["Słaby", "Zwykły", "Dobry", "Premium"]
const TIER_COLOR := ["9ca3af", "e5e7eb", "60a5fa", "fbbf24"]
const TIER_MIN := [0, 50, 68, 84]

const PRODUCTS := {
	"dym": {"name": "Green", "base": 46, "cost": 21, "color": "4ade80", "lvl": 1, "desc": "Susz. Najpopularniejszy towar na osiedlu."},
	"szron": {"name": "Speed", "base": 112, "cost": 58, "color": "e8dfb8", "lvl": 4, "desc": "Proszek dla tych, co nie śpią. Klub Neon bierze go najwięcej."},
	"krysztal": {"name": "Blue", "base": 195, "cost": 108, "color": "60a5fa", "lvl": 7, "desc": "Niebieskie kryształki dla nocnej zmiany. Mocny towar, mocne ryzyko."},
	"snieg": {"name": "Snow", "base": 330, "cost": 190, "color": "f3f6fb", "lvl": 9, "desc": "Najdroższy towar w mieście. Tylko dla klientów z grubym portfelem."},
}

## hurt u Wiktora: ilości i rabaty
const WHOLESALE_SIZES := [5, 10, 20, 50, 100, 250]
const WHOLESALE_DISC := {5: 0.0, 10: 0.0, 20: 0.04, 50: 0.08, 100: 0.12, 250: 0.16}
## maks. jednorazowe zamówienie (g) na danym poziomie
const WHOLESALE_MAX := [5, 10, 20, 20, 50, 50, 100, 100, 250, 250, 250, 250, 250, 250, 250, 250]
const PURITY_STD := 75
const PURITY_HIGH := 90

## sklep Wujka Stasia
const SHOP := [
	{"id": "woreczki", "name": "Woreczki strunowe (20 szt.)", "price": 12, "n": 20, "lvl": 1, "desc": "Bez nich nie zaporcjujesz towaru. 1 woreczek = 1 g."},
	{"id": "majeranek", "name": "Majeranek (20 g)", "price": 6, "n": 20, "lvl": 1, "desc": "Przyprawa z półki. Domieszany do Greena podbija wagę, ale obniża czystość — powstaje mieszanka."},
	{"id": "cukier", "name": "Cukier puder (20 g)", "price": 5, "n": 20, "lvl": 4, "desc": "Do rozrabiania proszków. Więcej gramów, gorszy towar."},
	{"id": "nasiona", "name": "Nasiona Green (1 paczka)", "price": 70, "n": 1, "lvl": 5, "desc": "Do namiotu uprawowego w kryjówce."},
	{"id": "burner", "name": "Telefon na kartę", "price": 420, "n": 1, "lvl": 2, "use": true, "desc": "Nowy numer: śledztwo policji spada o 25."},
]
const UPGRADES := [
	{"id": "plecak1", "name": "Plecak szkolny (40 miejsc)", "price": 380, "lvl": 2, "cap": 40, "desc": "Zamiast upychać towar po kieszeniach."},
	{"id": "plecak2", "name": "Plecak turystyczny (90 miejsc)", "price": 1500, "lvl": 5, "cap": 90, "req": "plecak1", "desc": "Na poważniejsze kursy."},
	{"id": "waga", "name": "Waga jubilerska", "price": 650, "lvl": 2, "desc": "Dokładniejsza: szersze zielone strefy przy porcjowaniu."},
	{"id": "szafka", "name": "Skrytka w podłodze", "price": 900, "lvl": 3, "desc": "Skrytka w mieszkaniu mieści 150 miejsc zamiast 60."},
]
## czym rozrabia się dany towar
const FILLER := {"dym": "majeranek", "szron": "cukier", "krysztal": "cukier", "snieg": "cukier"}
const FILLER_NAMES := {"majeranek": "Majeranek", "cukier": "Cukier puder"}
## przedmioty: ile miejsca zajmuje jedna sztuka / gram i ile waży (w gramach)
const ITEMS := {
	"woreczki": {"name": "Woreczki strunowe", "icon": "package", "size": 0.05, "w": 0.6, "unit": "szt.", "desc": "Puste woreczki do porcjowania. 1 woreczek = 1 porcja."},
	"majeranek": {"name": "Majeranek", "icon": "leaf", "size": 0.25, "w": 1.0, "unit": "g", "desc": "Przyprawa. Domieszana do Greena podbija wagę i psuje jakość."},
	"cukier": {"name": "Cukier puder", "icon": "beaker", "size": 0.2, "w": 1.0, "unit": "g", "desc": "Wypełniacz do proszków. Więcej gramów, gorszy towar."},
	"nasiona": {"name": "Nasiona Green", "icon": "sprout", "size": 0.5, "w": 4.0, "unit": "pacz.", "desc": "Paczka nasion do namiotu uprawowego."},
	"burner": {"name": "Telefon na kartę", "icon": "phone", "size": 2.0, "w": 120.0, "unit": "szt.", "desc": "Nowy numer zbija śledztwo policji. Użyj z telefonu → Plecak."},
}
const SIZE_PACK := 1.0
const SIZE_BULK := 1.0
const W_PACK := 1.4
const W_BULK := 1.0
const PRODUCT_ICONS := {"dym": "leaf", "szron": "zap", "krysztal": "flask_conical", "snieg": "droplets"}
## Postacie to gotowe modele ludzi (assets/people, Microsoft Rocketbox, MIT). Klienci i bohaterowie fabuły
## mają własne twarze; przechodnie losują z puli, żeby nikt nie chodził po osiedlu „w dwóch egzemplarzach”.
const PEOPLE_M := ["m01", "m02", "m06", "m07", "m08", "m09", "m11", "m12", "m16", "mc2", "ms4"]
const PEOPLE_F := ["f01", "f02", "f05", "f07", "f08", "f12", "f13", "f14", "f17", "fb2", "fs2"]
const PEOPLE_COP := ["pm3", "pm6", "pm4", "pm3"]
const BROTHER_LOOK := {"model": "m18", "kind": "hoodie", "seed": 51, "tall": 1.02, "walk": "Walk_Stiff"}

const PLAYER_LOOK := {"model": "m10", "kind": "dres", "top": "14161a", "top2": "e8e6e0", "bottom": "14161a", "stripes": true, "shoes": "e4e4e0", "hair": "hair_buzzed", "seed": 77, "skin": 0.25}
const CAP_BASE := 15
const STASH_BASE := 60

# ---------------------------------------------------------------- klienci
## type: charakter (wpływa na taktyki), like/hate: styl powitania
const CLIENTS := [
	{"id": "dominik", "name": "Dominik", "nick": "Student", "lvl": 1, "via": "start", "type": "luzak", "like": "luz", "hate": "twardo",
		"wealth": 0.9, "patience": 5, "minpur": 50, "grams": [4, 6], "every": [14.0, 22.0], "home": "blok5", "prod": "dym", "nerv": 0.1, "honesty": 0.95, "reliable": 0.9,
		"spots": ["klatka5", "trzepak", "pawilon"], "bio": "Student zaoczny z bloku obok. Brał od Twojego brata. Spłukany, ale lojalny.",
		"look": {"model": "m20", "kind": "hoodie", "top": "2f4a6d", "bottom": "232a36", "hair": "hair_simpleparted", "hair_color": "3d2a1c", "seed": 11, "walk": "Walk_Stiff"}},
	{"id": "seba", "name": "Seba", "nick": "Dres", "lvl": 2, "via": "ref:dominik:1", "type": "twardziel", "like": "twardo", "hate": "luz",
		"wealth": 0.95, "patience": 4, "minpur": 55, "grams": [5, 8], "every": [16.0, 26.0], "home": "blok9", "prod": "dym", "nerv": 0.05, "honesty": 0.8, "reliable": 0.6,
		"spots": ["trzepak", "klatka5", "garaze"], "bio": "Stoi pod klatką od zawsze. Szanuje tylko tych, którzy się nie cackają.",
		"look": {"model": "m17", "kind": "dres", "top": "101114", "top2": "e8e6e0", "bottom": "101114", "stripes": true, "hair": "hair_buzzed", "seed": 12, "build": 1.08, "walk": "Walk_Swagger"}},
	{"id": "zenon", "name": "Pan Zenon", "nick": "Emeryt", "lvl": 3, "via": "ref:dominik:3", "type": "gadula", "like": "luz", "hate": "twardo",
		"wealth": 0.8, "patience": 6, "minpur": 45, "grams": [4, 6], "every": [18.0, 28.0], "home": "kam1", "prod": "dym", "nerv": 0.05, "honesty": 0.85, "reliable": 0.95,
		"spots": ["park", "przystanek", "plac"], "bio": "„Na kolana, panie, na kolana”. Targuje się z przyzwyczajenia i lubi pogadać.",
		"look": {"model": "m13", "kind": "jacket", "top": "6b5a45", "bottom": "3b3630", "hair": "hair_buzzed", "hair_color": "d8d2c4", "hat": "cap", "hat_color": "45423c", "seed": 13, "build": 1.1, "height": 1.7, "walk": "Walk_Hunched"}},
	{"id": "kasia", "name": "Kasia", "nick": "Korpo", "lvl": 3, "via": "ref:dominik:5", "type": "konkret", "like": "konkret", "hate": "luz",
		"wealth": 1.25, "patience": 3, "minpur": 68, "grams": [6, 9], "every": [18.0, 28.0], "home": "blok11", "prod": "dym", "nerv": 0.4, "honesty": 0.9, "reliable": 0.95,
		"spots": ["przystanek", "brama", "pawilon"], "bio": "Open space, deadline'y, bezsenność. Płaci dobrze, ale panikuje na widok munduru.",
		"look": {"model": "f15", "female": true, "kind": "jacket", "top": "3a3f4a", "bottom": "101114", "hair": "hair_long", "hair_color": "6b4a2e", "seed": 14, "walk": "Walk_Phone"}},
	{"id": "marek", "name": "Marek", "nick": "Mechanik", "lvl": 4, "via": "talk", "type": "cwaniak", "like": "twardo", "hate": "luz",
		"wealth": 1.0, "patience": 4, "minpur": 60, "grams": [6, 9], "every": [16.0, 26.0], "home": "garaze", "prod": "dym", "nerv": 0.1, "honesty": 0.6, "reliable": 0.5,
		"spots": ["garaze", "tunel"], "bio": "Dłubie przy autach w garażach. Blefiarz — w SMS-ach zawsze zaniża, ile da.",
		"look": {"model": "mw1", "kind": "tshirt", "top": "3d3326", "bottom": "2e3440", "hair": "hair_buzzed", "beard": true, "hat": "cap", "seed": 15, "walk": "Walk"}},
	{"id": "kowal", "name": "Kowal", "nick": "Stróż z huty", "lvl": 5, "via": "talk", "type": "twardziel", "like": "konkret", "hate": "luz",
		"wealth": 0.95, "patience": 4, "minpur": 55, "grams": [7, 10], "every": [18.0, 28.0], "home": "huta", "prod": "dym", "nerv": 0.05, "honesty": 0.9, "reliable": 0.8,
		"spots": ["huta", "tunel"], "bio": "Pilnuje ruin Starej Huty. Długie nocne zmiany, niska pensja.",
		"look": {"model": "md1", "kind": "jacket", "top": "23402e", "bottom": "45423c", "hat": "beanie", "beard": true, "seed": 16, "build": 1.15, "walk": "Walk_Swagger"}},
	{"id": "heniek", "name": "Gruby Heniek", "nick": "Hurtownik warzyw", "lvl": 5, "via": "ref:seba:4", "type": "impulsywny", "like": "konkret", "hate": "luz",
		"wealth": 1.3, "patience": 2, "minpur": 50, "grams": [8, 12], "every": [18.0, 28.0], "home": "kam4", "prod": "dym", "nerv": 0.15, "honesty": 1.0, "reliable": 0.85,
		"spots": ["boisko", "garaze", "brama"], "bio": "Kupuje szybko i dużo, ale nie znosi gadania.",
		"look": {"model": "m14", "kind": "tshirt", "top": "8a2a22", "bottom": "283b2e", "bald": true, "seed": 17, "build": 1.3, "walk": "Walk_Swagger"}},
	{"id": "ola", "name": "Ola", "nick": "Barmanka", "lvl": 6, "via": "talk", "type": "konkret", "like": "konkret", "hate": "twardo",
		"wealth": 1.3, "patience": 3, "minpur": 70, "grams": [5, 8], "every": [16.0, 26.0], "home": "klub", "prod": "szron", "nerv": 0.2, "honesty": 0.9, "reliable": 0.9,
		"spots": ["klub"], "bio": "Barmanka z Neonu. Zna wszystkich, którzy mają pieniądze.",
		"look": {"model": "f04", "female": true, "kind": "tank", "top": "101114", "bottom": "101114", "hair": "hair_buns", "hair_color": "8a3a22", "seed": 18, "walk": "Walk_Loose"}},
	{"id": "mrok", "name": "DJ Mrok", "nick": "Rezydent Neonu", "lvl": 7, "via": "ref:ola:3", "type": "impulsywny", "like": "luz", "hate": "twardo",
		"wealth": 1.5, "patience": 3, "minpur": 72, "grams": [7, 11], "every": [18.0, 28.0], "home": "klub", "prod": "szron", "nerv": 0.25, "honesty": 0.8, "reliable": 0.7,
		"spots": ["klub", "boisko"], "bio": "Gra do rana, śpi do wieczora. Bierze dla siebie i „dla ekipy”.",
		"look": {"model": "m04", "kind": "hoodie", "top": "101114", "bottom": "101114", "hat": "cap", "hat_color": "5a2f52", "seed": 19, "walk": "Walk_Phone"}},
	{"id": "rysiek", "name": "Rysiek", "nick": "Tirowiec", "lvl": 7, "via": "ref:kowal:3", "type": "twardziel", "like": "twardo", "hate": "luz",
		"wealth": 1.2, "patience": 4, "minpur": 68, "grams": [5, 8], "every": [18.0, 28.0], "home": "huta", "prod": "krysztal", "nerv": 0.1, "honesty": 0.85, "reliable": 0.8,
		"spots": ["tunel", "huta", "garaze"], "bio": "Jeździ na trasie Zagłębie–Hamburg. Kolega Kowala. Musi nie spać trzy doby z rzędu.",
		"look": {"model": "m05", "kind": "jacket", "top": "4a4f58", "bottom": "1b2538", "hat": "cap", "hat_color": "8a1c1c", "beard": true, "seed": 21, "build": 1.2, "walk": "Walk_Folded"}},
	{"id": "wolski", "name": "Mecenas Wolski", "nick": "Adwokat", "lvl": 9, "via": "ref:kasia:5", "type": "cwaniak", "like": "konkret", "hate": "twardo",
		"wealth": 1.6, "patience": 3, "minpur": 82, "grams": [4, 6], "every": [20.0, 30.0], "home": "kam6", "prod": "snieg", "nerv": 0.5, "honesty": 0.7, "reliable": 1.0,
		"spots": ["brama", "park"], "bio": "Broni takich jak Ty. Płaci krocie, ale tylko za najczystszy towar.",
		"look": {"model": "mb4", "kind": "shirt", "top": "d8d8d8", "bottom": "1b1b1e", "shoes": "151517", "hair": "hair_simpleparted", "hair_color": "7a7a7a", "seed": 20, "walk": "Walk_Formal"}},
]
const MAX_CLIENTS := [1, 1, 2, 4, 5, 6, 8, 9, 10, 11, 11, 11, 11, 11, 11, 11]
const TYPE_NAMES := {"luzak": "Luzak", "twardziel": "Twardziel", "gadula": "Gaduła", "konkret": "Konkretny", "cwaniak": "Cwaniak", "impulsywny": "Impulsywny"}
const STYLE_NAMES := {"luz": "na luzie", "konkret": "konkretnie", "twardo": "twardo"}
## szansa powodzenia taktyki „ostatnie sztuki” wg charakteru
const SCARCITY := {"luzak": 0.55, "twardziel": 0.35, "gadula": 0.5, "konkret": 0.4, "cwaniak": 0.2, "impulsywny": 0.8}

const NAMES_M := ["Adam", "Bartek", "Czarek", "Darek", "Filip", "Hubert", "Jacek", "Kuba", "Michał", "Oskar", "Paweł", "Rafał", "Tomek", "Wojtek", "Igor", "Kamil", "Mati", "Łysy", "Młody"]
const NAMES_F := ["Ewa", "Gosia", "Iza", "Lena", "Nina", "Sylwia", "Ula", "Zosia", "Magda", "Ania", "Julia", "Wera"]

# ---------------------------------------------------------------- miejsca
## miejsca spotkań z klientami
var SPOTS := [
	{"id": "klatka5", "name": "Klatka bloku 5", "x": -60.0, "z": -75.5},
	{"id": "trzepak", "name": "Trzepak", "x": -28.0, "z": -104.0},
	{"id": "plac", "name": "Plac zabaw", "x": -6.0, "z": -108.0},
	{"id": "pawilon", "name": "Pawilon", "x": 72.0, "z": -43.5},
	{"id": "przystanek", "name": "Przystanek", "x": 62.0, "z": 12.2},
	{"id": "brama", "name": "Brama kamienicy", "x": -58.0, "z": 12.4},
	{"id": "garaze", "name": "Garaże", "x": 58.0, "z": 84.0},
	{"id": "park", "name": "Ławka w parku", "x": -88.0, "z": 66.0},
	{"id": "boisko", "name": "Boisko", "x": -70.0, "z": 128.0},
	{"id": "klub", "name": "Pod klubem Neon", "x": 5.4, "z": 124.0},
	{"id": "tunel", "name": "Tunel pod nasypem", "x": 126.0, "z": 13.4},
	{"id": "huta", "name": "Brama Starej Huty", "x": 172.0, "z": 30.0},
]
## skąd klienci wychodzą na spotkanie
var HOMES := {
	"blok5": {"x": -60.0, "z": -76.4}, "blok7": {"x": 30.0, "z": -76.4}, "blok9": {"x": -50.0, "z": -145.0}, "blok11": {"x": 40.0, "z": -145.0},
	"kam1": {"x": -58.0, "z": 11.6}, "kam4": {"x": 13.0, "z": 11.6}, "kam6": {"x": -27.0, "z": 28.4}, "garaze": {"x": 66.0, "z": 84.0},
	"huta": {"x": 172.0, "z": 31.0}, "klub": {"x": -6.0, "z": 126.0},
}
## skrytki, w których Wiktor zostawia towar
var DROPS := [
	{"id": "smietnik", "name": "Za altanką śmietnikową", "x": 47.0, "z": -111.5, "lvl": 1},
	{"id": "zaulek", "name": "Zaułek za kamienicą", "x": -84.0, "z": -13.5, "lvl": 1},
	{"id": "opony", "name": "Stos opon za garażami", "x": 108.5, "z": 110.0, "lvl": 2},
	{"id": "dziupla", "name": "Stary dąb w parku", "x": -160.0, "z": 122.0, "lvl": 2},
	{"id": "nasyp", "name": "Krzaki pod nasypem", "x": 127.0, "z": -66.0, "lvl": 3},
	{"id": "zbiornik", "name": "Zbiornik w Starej Hucie", "x": 192.0, "z": 58.0, "lvl": 4},
]

## strefy (nazwy na HUD-zie i lokalna uwaga policji)
var ZONES := [
	{"id": "huta", "name": "Dead Mill", "x0": 160.0, "x1": 210.0, "z0": -170.0, "z1": 170.0},
	{"id": "nasyp", "name": "The Tracks", "x0": 128.0, "x1": 160.0, "z0": -170.0, "z1": 170.0},
	{"id": "komisariat", "name": "Cop Corner", "x0": -210.0, "x1": -150.0, "z0": -18.0, "z1": 45.0},
	{"id": "osiedle", "name": "Steel Blocks", "x0": -210.0, "x1": 128.0, "z0": -170.0, "z1": -30.0},
	{"id": "skarpa", "name": "The Ridge", "x0": -210.0, "x1": 128.0, "z0": -30.0, "z1": -18.0},
	{"id": "garaze", "name": "Garage Row", "x0": 38.0, "x1": 128.0, "z0": 55.0, "z1": 125.0},
	{"id": "park", "name": "Smelter Park", "x0": -210.0, "x1": -48.0, "z0": 45.0, "z1": 170.0},
	{"id": "klub", "name": "Neon Strip", "x0": -48.0, "x1": 38.0, "z0": 55.0, "z1": 170.0},
	{"id": "dolne", "name": "Old Town", "x0": -150.0, "x1": 128.0, "z0": -18.0, "z1": 55.0},
	{"id": "poludnie", "name": "The Dumps", "x0": 38.0, "x1": 128.0, "z0": 125.0, "z1": 170.0},
]

## wnętrza (daleko poza mapą, wejście przez drzwi z przejściem)
const ROOMS := {
	"safe": {"cx": 1000.0, "w": 7.2, "d": 5.6, "h": 2.6, "name": "Kawalerka"},
	"shop": {"cx": 1100.0, "w": 9.0, "d": 7.0, "h": 3.0, "name": "Sklep u Stasia"},
	"garage": {"cx": 1200.0, "w": 6.0, "d": 9.0, "h": 2.7, "name": "Garaż nr 14"},
	"basement": {"cx": 1300.0, "w": 9.0, "d": 10.0, "h": 2.4, "name": "Piwnica"},
}
## drzwi zewnętrzne: punkt przed drzwiami i kierunek „na zewnątrz” (dz)
var DOORS := {
	"safe": {"x": 8.0, "z": -76.6, "dz": 1.0, "title": "BLOK 7 — KLATKA B", "color": "c9a86a"},
	"shop": {"x": -6.0, "z": 11.4, "dz": 1.0, "title": "SKLEP U STASIA", "color": "3ddc6e"},
	"garage": {"x": 65.0, "z": 94.6, "dz": -1.0, "title": "GARAŻ 14", "color": "9aa3ab", "prop": "garaz"},
	"basement": {"x": -75.0, "z": -11.4, "dz": -1.0, "title": "PIWNICA", "color": "8a7a66", "prop": "piwnica"},
}

# ---------------------------------------------------------------- nieruchomości i meble
const PROPERTIES := [
	{"id": "garaz", "name": "Garaż nr 14", "price": 4500, "lvl": 4, "room": "garage", "where": "Garaże przy Robotniczej",
		"desc": "Blaszak z prądem „na lewo”. Miejsce na stół, regały i pierwszy namiot uprawowy."},
	{"id": "piwnica", "name": "Piwnica w kamienicy", "price": 12000, "lvl": 6, "room": "basement", "where": "Zaułek za kamienicą, ul. Hutnicza",
		"desc": "Sucha, bez okien, sąsiedzi głusi. Dużo miejsca na magazyn i uprawę."},
	{"id": "kebab", "name": "Lokal „Kebab u Mirka”", "price": 38000, "lvl": 8, "room": "", "where": "Pawilon na osiedlu",
		"desc": "Przykrywka: legalny interes, przez który przepuścisz gotówkę. (W przygotowaniu)"},
	{"id": "hala", "name": "Hala w Starej Hucie", "price": 65000, "lvl": 10, "room": "", "where": "Stara Huta",
		"desc": "Tysiąc metrów pod produkcję na dużą skalę. (W przygotowaniu)"},
	{"id": "neon", "name": "Udziały w klubie Neon", "price": 140000, "lvl": 13, "room": "", "where": "ul. Robotnicza",
		"desc": "Własny klub = własny rynek zbytu. (W przygotowaniu)"},
]
## meble do kryjówek. size: [szer., głęb.] w metrach; func: pack | stash | grow | bed | light | decor
const FURNITURE := [
	{"id": "stol", "name": "Stół roboczy z wagą", "price": 480, "model": "painted_wooden_table", "h": 0.86, "size": [1.9, 0.9], "func": "pack", "lvl": 1, "desc": "Porcjowanie i mieszanie towaru na miejscu."},
	{"id": "regal", "name": "Regał magazynowy", "price": 340, "model": "steel_frame_shelves_01", "h": 1.95, "size": [1.05, 0.5], "func": "stash", "cap": 150, "lvl": 1, "desc": "+150 miejsc w skrytce w tej kryjówce."},
	{"id": "skrzynia", "name": "Skrzynia", "price": 120, "model": "wooden_crate_02", "h": 0.5, "size": [0.6, 1.2], "func": "stash", "cap": 50, "lvl": 1, "desc": "+50 miejsc w skrytce."},
	{"id": "namiot", "name": "Namiot uprawowy", "price": 1900, "model": "", "h": 2.0, "size": [1.3, 1.3], "func": "grow", "lvl": 5, "desc": "Uprawa Greena z nasion: ok. 18 g po 36 godzinach."},
	{"id": "lozko", "name": "Stare łóżko", "price": 260, "model": "old_bed_frame", "h": 1.0, "size": [1.0, 2.05], "func": "bed", "lvl": 1, "desc": "Sen przewija czas i studzi gorąco na mieście."},
	{"id": "laptop", "name": "Stolik z laptopem", "price": 420, "model": "", "h": 0.8, "size": [0.7, 0.6], "func": "save", "lvl": 1, "desc": "Zapis gry w tej kryjówce — bez wracania do kawalerki."},
	{"id": "lampa", "name": "Świetlówka warsztatowa", "price": 110, "model": "", "h": 2.1, "size": [0.4, 0.4], "func": "light", "lvl": 1, "desc": "Porządne światło do pracy."},
	{"id": "kanapa", "name": "Kanapa z odzysku", "price": 190, "model": "sofa_02", "h": 0.75, "size": [1.9, 0.9], "func": "decor", "lvl": 1, "desc": "Wygoda. Nic nie daje, ale kryjówka od razu jest „Twoja”."},
	{"id": "fotel", "name": "Fotel", "price": 140, "model": "armchair_01", "h": 1.0, "size": [0.9, 0.85], "func": "decor", "lvl": 1, "desc": "Do siedzenia i liczenia pieniędzy."},
	{"id": "tv", "name": "Telewizor na szafce", "price": 320, "model": "television_01", "h": 0.5, "size": [0.7, 0.55], "func": "decor", "lvl": 1, "desc": "Leci w tle, kiedy pakujesz."},
	{"id": "krzeslo", "name": "Plastikowe krzesło", "price": 35, "model": "plastic_monobloc_chair_01", "h": 0.86, "size": [0.6, 0.6], "func": "decor", "lvl": 1, "desc": "Klasyk każdego garażu."},
	{"id": "szafka", "name": "Szafka narzędziowa", "price": 210, "model": "drawer_cabinet", "h": 1.5, "size": [0.95, 0.45], "func": "stash", "cap": 80, "lvl": 1, "desc": "+80 miejsc w skrytce."},
	{"id": "boombox", "name": "Boombox", "price": 260, "model": "boombox", "h": 0.32, "size": [0.5, 0.2], "func": "decor", "lvl": 1, "desc": "Bo cisza w garażu jest podejrzana."},
	{"id": "beczka", "name": "Beczka", "price": 60, "model": "barrel_01", "h": 0.9, "size": [0.6, 0.6], "func": "decor", "lvl": 1, "desc": "Stolik, popielniczka, siedzisko."},
]

# ---------------------------------------------------------------- rozwój
const XP_LEVELS := [0, 60, 220, 520, 1100, 1900, 2900, 4100, 5600, 7400, 9500, 12000, 15000, 18500, 22500, 27000]
const LEVEL_TITLES := ["Nikt", "Goniec", "Osiedlowy", "Diler", "Kombinator", "Gracz", "Hurtownik", "Szef klatki", "Szef osiedla", "Boss dzielnicy", "Baron", "Wspólnik", "Król Zagłębia", "Legenda", "Legenda", "Legenda"]
const LEVEL_UNLOCKS := {
	2: "Nowi klienci z polecenia, większe zamówienia u Wiktora (10 g), plecak u Stasia.",
	3: "Zaczepianie przechodniów, do 4 stałych klientów.",
	4: "Nowy towar: Speed. Możesz kupić Garaż nr 14.",
	5: "Namiot uprawowy i nasiona — własny Green w kryjówce.",
	6: "Klienci z klubu Neon. Piwnica w kamienicy na sprzedaż.",
	7: "Nowy towar: Blue. Zamówienia hurtowe po 100 g.",
	8: "Zamówienia hurtowe po 250 g.",
	9: "Nowy towar: Snow — dla klientów z najgrubszym portfelem.",
}
## drzewko umiejętności: 4 gałęzie, wymagania w „req”
const SKILLS := [
	{"id": "gadka", "name": "Gadka", "branch": "Handel", "row": 0, "desc": "Klienci mają +1 cierpliwości w negocjacjach."},
	{"id": "oko1", "name": "Czytanie ludzi I", "branch": "Handel", "row": 1, "req": "gadka", "desc": "Widzisz orientacyjną maksymalną cenę klienta (±15%)."},
	{"id": "twarda", "name": "Twarda ręka", "branch": "Handel", "row": 2, "req": "oko1", "desc": "Klienci płacą do 6% więcej."},
	{"id": "oko2", "name": "Czytanie ludzi II", "branch": "Handel", "row": 3, "req": "twarda", "desc": "Dokładniejsza wycena (±6%) i widoczny „głód” klienta."},
	{"id": "rekin", "name": "Rekin", "branch": "Handel", "row": 4, "req": "oko2", "desc": "Kontroferty klientów są bliżej ich maksimum."},

	{"id": "kondycja1", "name": "Kondycja I", "branch": "Ulica", "row": 0, "desc": "+30% wytrzymałości podczas sprintu."},
	{"id": "cichy", "name": "Szary człowiek", "branch": "Ulica", "row": 1, "req": "kondycja1", "desc": "Policja o 20% wolniej nabiera podejrzeń."},
	{"id": "teren", "name": "Znajomość terenu", "branch": "Ulica", "row": 2, "req": "cichy", "desc": "Minimapa pokazuje wszystkie patrole w promieniu 60 m."},
	{"id": "kondycja2", "name": "Kondycja II", "branch": "Ulica", "row": 3, "req": "teren", "desc": "Sprint szybszy o 8%."},
	{"id": "duch", "name": "Duch", "branch": "Ulica", "row": 4, "req": "kondycja2", "desc": "Nocą policja nabiera podejrzeń o 35% wolniej."},

	{"id": "reka", "name": "Pewna ręka", "branch": "Towar", "row": 0, "desc": "Porcjowanie: szersze zielone strefy na wadze."},
	{"id": "mieszanie", "name": "Dobra mieszanka", "branch": "Towar", "row": 1, "req": "reka", "desc": "Rozrabianie obniża czystość o 20% mniej."},
	{"id": "czysta", "name": "Niewidoczny dodatek", "branch": "Towar", "row": 2, "req": "mieszanie", "desc": "Doświadczeni klienci o 30% rzadziej rozpoznają rozrobiony towar."},
	{"id": "paczki", "name": "Szybkie palce", "branch": "Towar", "row": 3, "req": "czysta", "desc": "Porcjujesz dwa razy więcej gramów w jednej sesji."},
	{"id": "ogrodnik", "name": "Ogrodnik", "branch": "Towar", "row": 4, "req": "paczki", "lvl": 5, "desc": "Namiot uprawowy daje o 35% większy plon."},

	{"id": "slowo", "name": "Dobre słowo", "branch": "Kontakty", "row": 0, "desc": "Zadowoleni klienci szybciej polecają Cię dalej."},
	{"id": "kredyt", "name": "Kredyt zaufania", "branch": "Kontakty", "row": 1, "req": "slowo", "desc": "Limit „zeszytu” u Wiktora wyższy o 600 zł."},
	{"id": "rabat", "name": "Rabat hurtowy", "branch": "Kontakty", "row": 2, "req": "kredyt", "desc": "Towar u Wiktora tańszy o 8%."},
	{"id": "siec", "name": "Siatka", "branch": "Kontakty", "row": 3, "req": "rabat", "desc": "+2 do limitu stałych klientów, zamówienia częściej."},
	{"id": "uklad", "name": "Układ", "branch": "Kontakty", "row": 4, "req": "siec", "desc": "Łapówki dla policji skuteczniejsze o 15 pkt proc."},
]
const BRANCHES := ["Handel", "Ulica", "Towar", "Kontakty"]

# ---------------------------------------------------------------- dług i ryzyko
const START_CASH := 60
const START_DEBT := 25000
const DEBT_SCHEDULE := [
	{"day": 5, "due": 100}, {"day": 9, "due": 220}, {"day": 13, "due": 600}, {"day": 17, "due": 1500}, {"day": 21, "due": 3000}, {"day": 25, "due": 5200},
	{"day": 29, "due": 8000}, {"day": 33, "due": 11500}, {"day": 37, "due": 15500}, {"day": 41, "due": 20000}, {"day": 45, "due": 25000},
]
const DEBT_INTEREST := 0.01
const LIVING_COST := 28
const MAX_ARRESTS := 5
const MAX_STRIKES := 3
const CREDIT_BASE := 300
const CREDIT_DAYS := 3

const HINTS := [
	"Im bliżej ukrytego maksimum klienta zaproponujesz cenę, tym większy zysk. Kontroferta zdradza, ile jest gotów dać.",
	"Każdy klient lubi inny styl rozmowy. Raz odkryty zapisuje się w aplikacji Kontakty.",
	"Nie handluj na oczach policji. Nocą jest mniej świadków, ale patrole są czujniejsze.",
	"Towar w skrytce jest bezpieczny podczas zatrzymania. Noś przy sobie tylko tyle, ile sprzedasz.",
	"Niedokładne porcjowanie marnuje towar. Trzy trafienia na wadze = zero strat.",
	"Majeranek podbija wagę Greena, ale stali klienci, którzy biorą dużo, rozpoznają mieszankę i odmówią.",
	"Umawiaj spotkania tak, żeby zdążyć dojść. Klient wychodzi z domu tuż przed godziną i czeka tylko godzinę.",
	"Odbieraj paczki ze skrytek szybko — po 16 godzinach przepadają.",
	"Sprzedawaj w różnych miejscach. Tam, gdzie handlujesz często, patroli jest więcej.",
	"Klawisz N włącza trasę do celu, Q przełącza kolejne cele.",
]
const MOM := [
	"Kubuś, jadłeś coś dzisiaj? Zadzwoń czasem do matki.",
	"Pani Halinka mówiła, że widziała Cię pod blokiem z jakimś łysym. Uważaj na siebie.",
	"W niedzielę rosół. Przyjdziesz?",
	"Znalazłeś już jakąś pracę? Wujek Staś mówił, że szuka kogoś do sklepu.",
	"Ubieraj się ciepło, idzie zima.",
]
