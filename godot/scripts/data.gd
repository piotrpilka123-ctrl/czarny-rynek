extends Node
## Dane gry. Wszystkie substancje, nazwy, osoby i miejsca są FIKCYJNE.

const TIME_SCALE := 1.0          # minut gry na sekundę: 1 godzina gry = 60 sekund (doba = 24 minuty)
## Skala planu miasta (współrzędne w tabelach poniżej są w jednostkach projektu)
const SC := 0.56


func _ready() -> void:
	for s in SPOTS:
		s.x = float(s.x) * SC
		s.z = float(s.z) * SC
	var mark_i := 0
	for s in DROPS:
		s.x = float(s.x) * SC
		s.z = float(s.z) * SC
		if not s.get("locker", false):
			s["mark"] = mark_i % DROP_MARKS.size()
			mark_i += 1
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
	"dym": {"name": "Marihuana", "base": 46, "cost": 18, "color": "6fbf4a", "lvl": 1, "form": "susz", "desc": "Suszone kwiaty konopi. Najpopularniejszy towar na osiedlu — bierze student i emeryt."},
	"szron": {"name": "Amfetamina", "base": 112, "cost": 58, "color": "e8dfb8", "lvl": 4, "form": "proszek", "desc": "Biało-żółty proszek dla tych, co nie śpią. Klub Neon bierze go najwięcej."},
	"krysztal": {"name": "Metamfetamina", "base": 195, "cost": 108, "color": "9ad0ff", "lvl": 7, "form": "kryształ", "desc": "Niebieskawe kryształki dla nocnej zmiany. Mocny towar, mocne ryzyko."},
	"snieg": {"name": "Kokaina", "base": 330, "cost": 190, "color": "f3f6fb", "lvl": 9, "form": "proszek", "desc": "Najdroższy towar w mieście. Tylko dla klientów z grubym portfelem."},
}
## dopełniacz do zdań typu „5 g marihuany”
const PRODUCT_GEN := {"dym": "marihuany", "szron": "amfetaminy", "krysztal": "metamfetaminy", "snieg": "kokainy"}

## hurt u Wiktora: ilości i rabaty
const WHOLESALE_SIZES := [5, 10, 20, 50, 100, 250]
const WHOLESALE_DISC := {5: 0.0, 10: 0.0, 20: 0.04, 50: 0.08, 100: 0.12, 250: 0.16}
## maks. jednorazowe zamówienie (g) na danym poziomie
const WHOLESALE_MAX := [10, 10, 20, 20, 50, 50, 100, 100, 250, 250, 250, 250, 250, 250, 250, 250]
const PURITY_STD := 75
const PURITY_HIGH := 90

## sklep Wujka Stasia
const SHOP := [
	{"id": "woreczki", "name": "Woreczki strunowe (20 szt.)", "price": 12, "n": 20, "lvl": 1, "desc": "Bez nich nie zaporcjujesz towaru. 1 woreczek = 1 g."},
	{"id": "majeranek", "name": "Majeranek (20 g)", "price": 6, "n": 20, "lvl": 1, "desc": "Przyprawa z półki. Domieszany do marihuany podbija wagę, ale obniża czystość — powstaje mieszanka."},
	{"id": "cukier", "name": "Cukier puder (20 g)", "price": 5, "n": 20, "lvl": 4, "desc": "Do rozrabiania proszków. Więcej gramów, gorszy towar."},
	{"id": "doniczka", "name": "Doniczka z ziemią", "price": 40, "n": 1, "lvl": 4, "desc": "Stawiasz ją w kryjówce [B] i sadzisz w niej jeden krzak. Każdy krzak doglądasz osobno."},
	{"id": "nasiona", "name": "Nasiona konopi (3 szt.)", "price": 45, "n": 3, "lvl": 4, "desc": "Jedno nasiono = jeden krzak w doniczce."},
	{"id": "nawoz", "name": "Nawóz (3 dawki)", "price": 45, "n": 3, "lvl": 4, "desc": "Dawka na krzak: plon większy o 25%, ale roślina pije więcej wody. Tylko dopóki rośnie."},
	{"id": "chemia", "name": "„Zestaw do udrażniania rur”", "price": 800, "n": 1, "lvl": 5, "desc": "Staś nie pyta, po co Ci tyle chemii. Jeden zestaw = jedna synteza przy stole laboratoryjnym."},
	{"id": "burner", "name": "Telefon na kartę", "price": 420, "n": 1, "lvl": 2, "use": true, "desc": "Nowy numer: śledztwo policji spada o 25."},
	{"id": "kastet", "name": "Kastet (spod lady)", "price": 350, "n": 1, "lvl": 3, "desc": "Dłużnicy „na zeszyt” oddają o wiele chętniej. Nielegalny: nie wejdziesz z nim do klubu, a policja doliczy zarzut."},
]
const UPGRADES := [
	{"id": "plecak1", "name": "Plecak szkolny (40 miejsc)", "price": 380, "lvl": 2, "cap": 40, "desc": "Zamiast upychać towar po kieszeniach."},
	{"id": "plecak2", "name": "Plecak turystyczny (90 miejsc)", "price": 1500, "lvl": 5, "cap": 90, "req": "plecak1", "desc": "Na poważniejsze kursy."},
	{"id": "waga", "name": "Waga jubilerska", "price": 650, "lvl": 2, "desc": "Dużo mniej strat przy porcjowaniu, a spokojna robota jest całkiem bezstratna."},
	{"id": "szafka", "name": "Skrytka w podłodze", "price": 900, "lvl": 3, "desc": "Skrytka w mieszkaniu mieści 150 miejsc zamiast 60."},
]
## GIEŁDA: dostawcy. Każdy ma swój charakter — cenę, czystość, czas dostawy, zasady płatności i ryzyko.
## price = mnożnik ceny hurtowej, pur = widełki czystości, eta = minuty do dostawy skrytką,
## blind = czystość poznajesz dopiero po otwarciu paczki, mix = szansa, że towar jest już rozrobiony,
## risk = szansa, że dostawa jest „spalona” (przy skrytce czeka tajniak), prepay = płatne z góry.
const VENDORS := [
	{"id": "wiktor", "name": "Wiktor", "tag": "Pewniak", "lvl": 1, "price": 1.0, "pur": [70, 80], "eta": [40.0, 90.0], "credit": true, "min": 5, "max": 250, "risk": 0.0,
		"desc": "Solidny towar i zeszyt. Drożej niż u innych, ale nigdy nie zawodzi.", "color": "c9a86a"},
	{"id": "zbyszek", "name": "Tani Zbyszek", "tag": "Kot w worku", "lvl": 2, "price": 0.74, "pur": [45, 78], "eta": [20.0, 45.0], "min": 5, "max": 50, "risk": 0.1, "blind": true, "mix": 0.3,
		"desc": "Ćwierć taniej i szybko. Czystość poznasz dopiero po otwarciu paczki — bywa, że towar jest już rozrobiony. Co dziesiąta dostawa jest spalona.", "color": "8a9a3a"},
	{"id": "chemik", "name": "Chemik z Zagłębia", "tag": "Czysty towar", "lvl": 4, "price": 1.3, "pur": [86, 95], "eta": [150.0, 260.0], "min": 10, "max": 100, "risk": 0.0, "prepay": true,
		"desc": "Najczystszy towar w okolicy. Płatne z góry, dostawa trwa kilka godzin, minimum 10 g.", "color": "6aa8e8"},
	{"id": "port", "name": "Port", "tag": "Cegły z kontenera", "lvl": 6, "price": 0.8, "pur": [72, 82], "eta": [240.0, 420.0], "min": 50, "max": 250, "risk": 0.04, "prepay": true, "buys": true,
		"desc": "Całe cegły prosto z kontenera: od 50 g, jedna piąta taniej. Płatne z góry, długa dostawa. Skupuje też nadwyżki.", "color": "c86a4a"},
]
## sposoby dostawy: fee = dopłata do ceny, eta = mnożnik czasu, hold = ile godzin paczka czeka
const DELIVERY := {
	"drop": {"name": "Skrytka", "icon": "map_pin", "fee": 0.0, "eta": 1.0, "hold": 16.0, "desc": "Paczka czeka 16 godzin w umówionym miejscu na mieście."},
	"locker": {"name": "Skrytkomat", "icon": "lock", "fee": 0.08, "eta": 1.5, "hold": 36.0, "desc": "+8% i wolniej, ale paczka leży półtorej doby pod kodem i nikt przy niej nie węszy."},
	"courier": {"name": "Kurier", "icon": "footprints", "fee": 0.15, "eta": 0.5, "hold": 0.6, "desc": "+15%, za to dwa razy szybciej. Kurier czeka w umówionym miejscu tylko 35 minut."},
}
## skup nadwyżek: ułamek ceny ulicznej za towar luzem i dzienny limit gramów na poziom
const BULK_SELL := 0.44
const BULK_SELL_MIN := 20
const BULK_SELL_DAY := 40

## PRODUKCJA. Każdy przepis to dane: stanowisko, wsad, czas, etapy, plon. Nowy towar = nowy wpis (i ewentualnie stanowisko).
## hours = czas całego cyklu w zwykłym trybie, yield = gramy (dla upraw: na doniczkę), pur = czystość bazowa,
## smell = zapach w szczycie, power = zł za dobę, hold = etap kończy się czynnością gracza.
const RECIPES := {
	"konopie": {"name": "Konopie", "station": "pot", "product": "dym", "lvl": 4, "input": {"nasiona": 1}, "hours": 30.0, "yield": 12.0, "pur": 56,
		"smell": 4.0, "power": 4.0, "wet": true, "water": 4.2,
		"stages": [{"name": "Sadzonki", "to": 0.2}, {"name": "Wzrost", "to": 0.6}, {"name": "Kwitnienie", "to": 1.0}],
		"modes": [{"name": "Lampy 18/6", "speed": 1.0, "smell": 1.0, "power": 1.0, "water": 1.0, "pur": 0, "desc": "Zwykły cykl światła."},
			{"name": "Lampy 24/0", "speed": 1.35, "smell": 1.3, "power": 2.0, "water": 1.4, "pur": -4, "desc": "Rośnie o 1/3 szybciej, ale żre prąd i wodę, mocniej pachnie i wychodzi trochę słabsza."}]},
	"amfetamina": {"name": "Amfetamina", "station": "lab", "product": "szron", "lvl": 5, "input": {"chemia": 1}, "hours": 5.0, "yield": 28.0, "pur": 72,
		"smell": 34.0, "power": 8.0,
		"stages": [{"name": "Reakcja", "to": 0.45, "hold": "Przelej i schłodź"}, {"name": "Krystalizacja", "to": 0.85}, {"name": "Suszenie", "to": 1.0}],
		"modes": [{"name": "Niska temp.", "speed": 0.7, "smell": 0.7, "power": 1.0, "pur": 8, "desc": "Wolno i czysto: najlepszy towar, najmniej smrodu."},
			{"name": "Średnia temp.", "speed": 1.0, "smell": 1.0, "power": 1.0, "pur": 0, "desc": "Podręcznikowo."},
			{"name": "Wysoka temp.", "speed": 1.5, "smell": 1.6, "power": 1.3, "pur": -10, "burn": 0.18, "desc": "Szybko, ale śmierdzi na całą okolicę, towar słabszy i co szósta partia się przypala."}]},
	"metamfetamina": {"name": "Metamfetamina", "station": "lab", "product": "krysztal", "lvl": 8, "input": {"chemia": 2}, "hours": 8.0, "yield": 20.0, "pur": 74,
		"smell": 46.0, "power": 10.0,
		"stages": [{"name": "Redukcja", "to": 0.4, "hold": "Odfiltruj osad"}, {"name": "Krystalizacja", "to": 0.9, "hold": "Zbierz kryształy"}, {"name": "Suszenie", "to": 1.0}],
		"modes": [{"name": "Niska temp.", "speed": 0.7, "smell": 0.7, "power": 1.0, "pur": 8, "desc": "Wolno i czysto."},
			{"name": "Średnia temp.", "speed": 1.0, "smell": 1.0, "power": 1.0, "pur": 0, "desc": "Podręcznikowo."},
			{"name": "Wysoka temp.", "speed": 1.5, "smell": 1.6, "power": 1.3, "pur": -10, "burn": 0.22, "desc": "Szybko, śmierdząco i z ryzykiem przypalenia."}]},
}
const DRY_HOURS := 8.0
## uprawa w doniczkach: ile doniczek mieści kryjówka, tempo bez lampy, kara do jakości za brak światła
const POT_MAX := {"garage": 10, "basement": 18}
const POT_UNLIT_SPEED := 0.4
const POT_UNLIT_PUR := -12.0
## STROJE (sklep „Tania Odzież”). Każdy strój to inna sylwetka i inne zalety:
## speed = prędkość chodu i biegu, stamina = zapas kondycji, vis = jak bardzo rzucasz się w oczy patrolom (dzień i noc),
## vis_night = dodatkowy mnożnik po zmroku, noise = słyszalność kroków, attention = jak szybko patrol nabiera podejrzeń,
## gdy już Cię widzi, witness = ile z tego, co widzą świadkowie, trafia do śledztwa, charm = ile klienci gotowi są zapłacić,
## cap = dodatkowe (albo brakujące) miejsce w kieszeniach, masked = zamaskowany: patrol reaguje nawet, gdy nic nie niesiesz.
const OUTFITS := {
	"dres": {"name": "Stary dres", "model": "m10", "price": 0, "lvl": 1, "desc": "To, w czym uciekłeś z huty. Nic nie daje, nic nie zabiera."},
	"biegacz": {"name": "Strój biegacza", "model": "ms4", "price": 320, "lvl": 2, "speed": 1.1, "stamina": 1.3, "noise": 0.8, "vis": 1.12, "cap": -5,
		"desc": "Lekko i szybko. Jasny, z gołymi rękami — widać Cię z daleka, a kieszeni prawie brak."},
	"szary": {"name": "Szary człowiek", "model": "m05", "price": 450, "lvl": 2, "attention": 0.75, "vis": 0.92,
		"desc": "Beżowa kurtka, w której giniesz w tłumie. Patrol dłużej się zastanawia, zanim uzna Cię za podejrzanego."},
	"robotnik": {"name": "Kombinezon roboczy", "model": "mc2", "price": 600, "lvl": 3, "attention": 0.6, "vis": 1.2, "cap": 10, "speed": 0.96,
		"desc": "Robotnika w kasku nikt nie zaczepia, a w kombinezonie zmieści się więcej. Za to widać Cię z daleka i biega się ciężej."},
	"czarny": {"name": "Czarna kurtka", "model": "m20", "price": 700, "lvl": 3, "vis_night": 0.7, "attention": 1.12,
		"desc": "Po zmroku prawie Cię nie widać. W dzień wyglądasz, jakbyś coś kombinował."},
	"kominiarka": {"name": "Kominiarka i rękawiczki", "model": "m20", "mask": true, "masked": true, "price": 1200, "lvl": 5, "vis": 0.92, "vis_night": 0.6, "witness": 0.3, "attention": 2.0, "charm": 0.95,
		"desc": "Nikt Cię nie rozpozna: świadkowie i śledztwo prawie nic na Ciebie nie mają. Ale zamaskowany człowiek to dla patrolu sygnał alarmowy — reaguje od razu, nawet gdy nic nie niesiesz."},
	"ochrona": {"name": "Mundur ochroniarza", "model": "sm1", "price": 1800, "lvl": 6, "attention": 0.5, "speed": 0.95, "charm": 0.95,
		"desc": "Patrole biorą Cię za swojego. Klienci robią się nerwowi i płacą mniej, a w służbowych butach daleko nie pobiegniesz."},
	"garnitur": {"name": "Garnitur", "model": "mb4", "price": 2800, "lvl": 7, "attention": 0.7, "charm": 1.06, "speed": 0.94,
		"desc": "Klienci płacą więcej, policja rzadziej zaczepia eleganckiego pana. W lakierkach się nie ucieka."},
}
## czym rozrabia się dany towar
const FILLER := {"dym": "majeranek", "szron": "cukier", "krysztal": "cukier", "snieg": "cukier"}
const FILLER_NAMES := {"majeranek": "Majeranek", "cukier": "Cukier puder"}
## przedmioty: ile miejsca zajmuje jedna sztuka / gram i ile waży (w gramach)
const ITEMS := {
	"woreczki": {"name": "Woreczki strunowe", "icon": "woreczki", "size": 0.05, "w": 0.6, "unit": "szt.", "desc": "Puste woreczki do porcjowania. 1 woreczek = 1 porcja."},
	"majeranek": {"name": "Majeranek", "icon": "majeranek", "size": 0.25, "w": 1.0, "unit": "g", "desc": "Przyprawa. Domieszana do marihuany podbija wagę i psuje jakość."},
	"cukier": {"name": "Cukier puder", "icon": "cukier", "size": 0.2, "w": 1.0, "unit": "g", "desc": "Wypełniacz do proszków. Więcej gramów, gorszy towar."},
	"doniczka": {"name": "Doniczka z ziemią", "icon": "doniczka", "size": 3.0, "w": 2200.0, "unit": "szt.", "desc": "Postaw w kryjówce [B], a potem posadź w niej nasiono."},
	"nasiona": {"name": "Nasiona konopi", "icon": "nasiona", "size": 0.1, "w": 1.0, "unit": "szt.", "illegal": true, "desc": "Jedno nasiono = jeden krzak. Sadzisz je, celując w pustą doniczkę."},
	"nawoz": {"name": "Nawóz", "icon": "nawoz", "size": 0.4, "w": 90.0, "unit": "dawek", "desc": "Dawka na jeden krzak: plon większy o 25%, ale roślina pije więcej wody."},
	"chemia": {"name": "Zestaw chemikaliów", "icon": "chemia", "size": 4.0, "w": 1800.0, "unit": "szt.", "illegal": true, "desc": "Prekursory i rozpuszczalniki na jedną syntezę przy stole laboratoryjnym."},
	"burner": {"name": "Telefon na kartę", "icon": "burner", "size": 2.0, "w": 120.0, "unit": "szt.", "desc": "Nowy numer zbija śledztwo policji. Użyj z telefonu → Plecak."},
	# --- ZNALEZISKA: rzeczy z ziemi i ze śmietników. Do niczego nie służą — lombard przy Hutniczej płaci za nie gotówką (pawn = cena skupu).
	"butelki": {"name": "Butelki zwrotne", "icon": "beer", "size": 0.5, "w": 350.0, "unit": "szt.", "junk": true, "pawn": 3, "desc": "Kaucja to kaucja. Lombard bierze je hurtem."},
	"zapalniczka": {"name": "Zapalniczka benzynowa", "icon": "flame", "size": 0.1, "w": 60.0, "unit": "szt.", "junk": true, "pawn": 20, "desc": "Ktoś zgubił. Działa."},
	"miedz": {"name": "Zwój miedzianego kabla", "icon": "route", "size": 2.0, "w": 1600.0, "unit": "szt.", "junk": true, "pawn": 38, "desc": "Ciężki, ale skup metali i lombard zawsze wezmą."},
	"telefon_stary": {"name": "Stary telefon", "icon": "phone", "size": 0.5, "w": 140.0, "unit": "szt.", "junk": true, "pawn": 55, "desc": "Pęknięty ekran, bateria trzyma kwadrans. Części są coś warte."},
	"kartridz": {"name": "Gra na starą konsolę", "icon": "dices", "size": 0.3, "w": 90.0, "unit": "szt.", "junk": true, "pawn": 45, "desc": "Kolekcjonerzy płacą za takie rzeczy więcej, niż myślisz."},
	"magnetofon": {"name": "Magnetofon kasetowy", "icon": "music", "size": 3.0, "w": 2200.0, "unit": "szt.", "junk": true, "pawn": 70, "desc": "Kaseciak z urwaną klapką. Jeszcze gra."},
	"radio_sam": {"name": "Radio samochodowe", "icon": "radar", "size": 2.0, "w": 1300.0, "unit": "szt.", "junk": true, "pawn": 85, "desc": "Wyrwane z kablami. Lepiej nie pytać, skąd się wzięło w kontenerze."},
	"zegarek": {"name": "Zegarek na bransolecie", "icon": "clock", "size": 0.1, "w": 110.0, "unit": "szt.", "junk": true, "pawn": 110, "desc": "Nie chodzi, ale koperta jest ze stali."},
	"wiertarka": {"name": "Wiertarka udarowa", "icon": "hammer", "size": 3.0, "w": 2600.0, "unit": "szt.", "junk": true, "pawn": 120, "desc": "Spalone szczotki. W lombardzie naprawią i sprzedadzą jak nową."},
	"aparat": {"name": "Aparat fotograficzny", "icon": "camera", "size": 1.0, "w": 480.0, "unit": "szt.", "junk": true, "pawn": 140, "desc": "Lustrzanka z porysowanym obiektywem."},
	"obraczka": {"name": "Złota obrączka", "icon": "award", "size": 0.1, "w": 6.0, "unit": "szt.", "junk": true, "pawn": 260, "desc": "Ktoś ją wyrzucił razem ze wspomnieniami. Złoto to złoto."},
	"kastet": {"name": "Kastet", "icon": "kastet", "size": 0.5, "w": 180.0, "unit": "szt.", "illegal": true, "weapon": true,
		"desc": "Mosiądz na cztery palce. Dłużnicy oddają chętniej, gdy go widzą. Ochroniarz znajdzie go zawsze, a przy zatrzymaniu to osobny zarzut."},
	# --- UBRANIA: lekkie przedmioty z polem `slot`. Założone (przeciągnięte na postać) nic nie ważą i nie zajmują miejsca.
	# Cechy są celowo niewielkie — strój pomaga, ale nie robi gry za gracza.
	"czapka_daszek": {"name": "Czapka z daszkiem", "icon": "ub_czapka_daszek", "size": 0.5, "w": 80.0, "unit": "szt.", "look": {"hat": "cap", "color": "2c4a7a", "bone": "Bip01 Head"}, "slot": "glowa", "price": 90, "lvl": 1,
		"stats": {"witness": 0.94, "attention": 0.97}, "desc": "Daszek zasłania twarz przed kamerami i ciekawskimi."},
	"czapka_zimowa": {"name": "Czarna czapka", "icon": "ub_czapka_zimowa", "size": 0.5, "w": 70.0, "unit": "szt.", "look": {"hat": "beanie", "color": "1c1d22", "bone": "Bip01 Head"}, "slot": "glowa", "price": 70, "lvl": 1,
		"stats": {"vis_night": 0.96}, "desc": "Naciągnięta na czoło. Po zmroku odrobinę trudniej Cię wypatrzyć."},
	"kominiarka": {"name": "Kominiarka", "icon": "ub_kominiarka", "size": 0.5, "w": 60.0, "unit": "szt.", "look": {"mask": true}, "slot": "glowa", "price": 320, "lvl": 4,
		"stats": {"witness": 0.9, "attention": 1.12}, "desc": "Nikt Cię nie opisze — ale zamaskowany człowiek na ulicy od razu zwraca uwagę patrolu, a do klubu w niej nie wejdziesz."},
	"okulary": {"name": "Ciemne okulary", "icon": "ub_okulary", "size": 0.5, "w": 30.0, "unit": "szt.", "look": {"acc": "glasses", "bone": "Bip01 Head"}, "slot": "szyja", "price": 120, "lvl": 2,
		"stats": {"witness": 0.93, "charm": 0.98}, "desc": "Trudniej Cię opisać. Klient woli jednak widzieć oczy tego, od kogo kupuje."},
	"komin": {"name": "Komin na szyję", "icon": "ub_komin", "size": 0.5, "w": 60.0, "unit": "szt.", "look": {"acc": "gaiter", "color": "3a3f48"}, "slot": "szyja", "price": 180, "lvl": 3,
		"stats": {"witness": 0.9, "attention": 1.04}, "desc": "Podciągnięty na nos chroni przed rozpoznaniem, ale patrol patrzy na Ciebie odrobinę uważniej."},
	"lancuch": {"name": "Łańcuch z tombaku", "icon": "ub_lancuch", "size": 0.5, "w": 90.0, "unit": "szt.", "look": {"acc": "chain", "bone": "Bip01 Spine2"}, "slot": "szyja", "price": 650, "lvl": 5,
		"stats": {"charm": 1.03, "attention": 1.03}, "desc": "Wygląda na złoto. Klienci traktują Cię poważniej — policja też."},
	"bluza_kaptur": {"name": "Bluza z kapturem", "icon": "ub_bluza", "size": 1.0, "w": 320.0, "unit": "szt.", "look": {"color": "5b6f8c", "hood": true}, "slot": "gora", "price": 240, "lvl": 2,
		"stats": {"vis_night": 0.94, "cap": 2}, "desc": "Kaptur na głowę, ręce w kieszeni-kangurce. Dwa dodatkowe miejsca na towar."},
	"kurtka_kieszenie": {"name": "Kurtka z kieszeniami", "icon": "ub_kurtka", "size": 1.0, "w": 380.0, "unit": "szt.", "look": {"color": "5a6b4a", "collar": true}, "slot": "gora", "price": 480, "lvl": 4,
		"stats": {"cap": 4, "speed": 0.99, "conceal": 0.9}, "desc": "Cztery wewnętrzne kieszenie — ochroniarzowi trudniej coś w nich wymacać. Trochę krępuje ruchy."},
	"koszula": {"name": "Koszula w kratę", "icon": "ub_koszula", "size": 1.0, "w": 200.0, "unit": "szt.", "look": {"color": "a8433a", "plaid": true}, "slot": "gora", "price": 320, "lvl": 3,
		"stats": {"attention": 0.96, "charm": 1.02}, "desc": "Wyglądasz jak ktoś, kto idzie do pracy. Patrole zerkają rzadziej."},
	"rekawiczki": {"name": "Rękawiczki robocze", "icon": "ub_rekawiczki", "size": 0.5, "w": 60.0, "unit": "szt.", "look": {"color": "b0915a"}, "slot": "dlonie", "price": 50, "lvl": 1,
		"stats": {"witness": 0.95}, "desc": "Żadnych odcisków na woreczkach i klamkach."},
	"rekawiczki_skora": {"name": "Skórzane rękawiczki", "icon": "ub_rekawiczki_skora", "size": 0.5, "w": 80.0, "unit": "szt.", "look": {"color": "1e1611"}, "slot": "dlonie", "price": 280, "lvl": 4,
		"stats": {"witness": 0.92, "charm": 1.01}, "desc": "Bez odcisków i z klasą."},
	"dresy": {"name": "Spodnie dresowe", "icon": "ub_dresy", "size": 1.0, "w": 240.0, "unit": "szt.", "look": {"color": "4a4e58"}, "slot": "spodnie", "price": 120, "lvl": 1,
		"stats": {"speed": 1.02, "stamina": 1.04}, "desc": "Nic nie krępuje nóg, kiedy trzeba biec."},
	"jeansy": {"name": "Jeansy", "icon": "ub_jeansy", "size": 1.0, "w": 340.0, "unit": "szt.", "look": {"color": "40608f"}, "slot": "spodnie", "price": 190, "lvl": 2,
		"stats": {"attention": 0.97}, "desc": "Zwyczajne spodnie zwyczajnego człowieka."},
	"bojowki": {"name": "Bojówki", "icon": "ub_bojowki", "size": 1.0, "w": 360.0, "unit": "szt.", "look": {"color": "777a52", "cargo": true}, "slot": "spodnie", "price": 300, "lvl": 3,
		"stats": {"cap": 3, "conceal": 0.92}, "desc": "Kieszenie na udach: trzy dodatkowe miejsca, a przy kontroli mało kto tam zagląda."},
	"trampki": {"name": "Trampki", "icon": "ub_trampki", "size": 1.0, "w": 300.0, "unit": "szt.", "look": {"color": "c9c5b9"}, "slot": "buty", "price": 150, "lvl": 1,
		"stats": {"noise": 0.92}, "desc": "Miękka podeszwa. Kroki słychać z mniejszej odległości."},
	"buty_bieg": {"name": "Buty do biegania", "icon": "ub_buty_bieg", "size": 1.0, "w": 280.0, "unit": "szt.", "look": {"color": "c8482a"}, "slot": "buty", "price": 340, "lvl": 3,
		"stats": {"speed": 1.03, "stamina": 1.06}, "desc": "Lekkie i sprężyste. Dalej dobiegniesz, zanim zabraknie tchu."},
	"buty_robocze": {"name": "Buty robocze", "icon": "ub_buty_robocze", "size": 1.0, "w": 400.0, "unit": "szt.", "look": {"color": "6b4a2b"}, "slot": "buty", "price": 220, "lvl": 2,
		"stats": {"attention": 0.98, "speed": 0.99}, "desc": "W takich chodzi pół osiedla. Ciężkie, ale nikt na nie nie patrzy."},
}
## pola ubioru wokół postaci w ekwipunku: [id, nazwa, strona (-1 lewa, 1 prawa), wysokość na sylwetce 0..1 od góry]
const GEAR_SLOTS := [["glowa", "Czapka", 1, 0.06], ["szyja", "Dodatek", -1, 0.17], ["gora", "Góra", 1, 0.33], ["dlonie", "Rękawiczki", 1, 0.52], ["spodnie", "Spodnie", -1, 0.66], ["buty", "Buty", -1, 0.9]]
const SIZE_PACK := 1.0
const SIZE_BULK := 1.0
const W_PACK := 1.4
const W_BULK := 1.0
const PRODUCT_ICONS := {"dym": "pack_dym", "szron": "pack_szron", "krysztal": "pack_krysztal", "snieg": "pack_snieg"}
## Postacie to gotowe modele ludzi (assets/people, Microsoft Rocketbox, MIT). Klienci i bohaterowie fabuły
## mają własne twarze; przechodnie losują z puli, żeby nikt nie chodził po osiedlu „w dwóch egzemplarzach”.
const PEOPLE_M := ["m01", "m02", "m06", "m07", "m08", "m09", "m11", "m12", "m16", "mc2", "ms4"]
const PEOPLE_F := ["f01", "f02", "f05", "f07", "f08", "f12", "f13", "f14", "f17", "fb2", "fs2"]
const PEOPLE_COP := ["pm3", "pm6", "pm4", "pm3"]
## wspólnik z laboratorium (prolog)
const SIWY_LOOK := {"model": "m18", "kind": "hoodie", "seed": 51, "tall": 1.02, "walk": "Walk_Stiff"}

const PLAYER_LOOK := {"model": "m10", "kind": "dres", "top": "14161a", "top2": "e8e6e0", "bottom": "14161a", "stripes": true, "shoes": "e4e4e0", "hair": "hair_buzzed", "seed": 77, "skin": 0.25}
const CAP_BASE := 15
const STASH_BASE := 60

# ---------------------------------------------------------------- klienci
## type: charakter (wpływa na taktyki), like/hate: styl powitania
const CLIENTS := [
	{"id": "dominik", "name": "Dominik", "nick": "Student", "lvl": 1, "via": "start", "type": "luzak", "like": "luz", "hate": "twardo",
		"wealth": 1.0, "patience": 5, "minpur": 50, "grams": [4, 6], "every": [14.0, 22.0], "home": "blok5", "prod": "dym", "nerv": 0.1, "honesty": 0.95, "reliable": 0.9,
		"spots": ["klatka5", "trzepak", "pawilon"], "bio": "Student zaoczny z bloku obok. Brał od Twoich ludzi, zanim wszystko poszło z dymem. Spłukany, ale lojalny.",
		"look": {"model": "m20", "kind": "hoodie", "top": "2f4a6d", "bottom": "232a36", "hair": "hair_simpleparted", "hair_color": "3d2a1c", "seed": 11, "walk": "Walk_Stiff"}},
	{"id": "seba", "name": "Seba", "nick": "Dres", "lvl": 2, "via": "ref:dominik:1", "type": "twardziel", "like": "twardo", "hate": "luz",
		"wealth": 1.0, "patience": 4, "minpur": 55, "grams": [5, 8], "every": [16.0, 26.0], "home": "blok9", "prod": "dym", "nerv": 0.05, "honesty": 0.8, "reliable": 0.6,
		"spots": ["trzepak", "klatka5", "garaze"], "bio": "Stoi pod klatką od zawsze. Szanuje tylko tych, którzy się nie cackają.",
		"look": {"model": "m17", "kind": "dres", "top": "101114", "top2": "e8e6e0", "bottom": "101114", "stripes": true, "hair": "hair_buzzed", "seed": 12, "build": 1.08, "walk": "Walk_Swagger"}},
	{"id": "zenon", "name": "Pan Zenon", "nick": "Emeryt", "lvl": 3, "via": "ref:dominik:3", "type": "gadula", "like": "luz", "hate": "twardo",
		"wealth": 0.9, "patience": 6, "minpur": 45, "grams": [4, 6], "every": [18.0, 28.0], "home": "kam1", "prod": "dym", "nerv": 0.05, "honesty": 0.85, "reliable": 0.95,
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
	{"id": "przystanek", "name": "Przystanek", "x": 66.0, "z": 12.4},
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
## znaki sprejem przy skrytkach (tekstury gen_znak_N.png): mały biały szablon u stóp ściany
const DROP_MARKS := ["liść", "woreczek", "czaszka", "krzyżyk", "kryształ", "śnieżynka"]
## skrytki, w których dostawcy zostawiają towar — każda ma swój znak sprejem (mark, nadawany przy starcie).
## turf: miejsce spotkań, które musi należeć do Twojego terenu (ma tam klienta), żeby skrytka weszła do gry;
## "dom" = okolica mieszkania, dostępna od początku. Im większy teren, tym dalej wypadają dostawy.
var DROPS := [
	{"id": "smietnik", "name": "Za altanką śmietnikową", "x": 47.0, "z": -111.5, "turf": "dom"},
	{"id": "trzepak", "name": "Pod trzepakiem", "x": -33.0, "z": -110.4, "turf": "dom"},
	{"id": "zaulek", "name": "Zaułek za kamienicą", "x": -84.0, "z": -13.5, "turf": "klatka5"},
	{"id": "pawilon", "name": "Za pawilonem", "x": 84.0, "z": -59.0, "turf": "dom"},
	{"id": "piaskownica", "name": "Przy placu zabaw", "x": -1.0, "z": -113.0, "turf": "plac"},
	{"id": "wiata", "name": "Za wiatą przystanku", "x": 69.0, "z": 9.4, "turf": "przystanek"},
	{"id": "podworze", "name": "Trzepak za kamienicą", "x": -66.0, "z": 56.0, "turf": "brama"},
	{"id": "opony", "name": "Stos opon za garażami", "x": 108.5, "z": 110.0, "turf": "garaze"},
	{"id": "trafo", "name": "Za trafostacją", "x": 110.5, "z": -142.0, "turf": "garaze"},
	{"id": "plot", "name": "Pod blaszanym płotem", "x": 60.0, "z": 125.2, "turf": "garaze"},
	{"id": "dziupla", "name": "Stary dąb w parku", "x": -160.0, "z": 122.0, "turf": "park"},
	{"id": "krzaki", "name": "Krzaki w głębi parku", "x": -122.0, "z": 86.0, "turf": "park"},
	{"id": "nasyp", "name": "Krzaki pod nasypem", "x": 127.0, "z": -66.0, "turf": "tunel"},
	{"id": "przepust", "name": "Przy wylocie tunelu", "x": 121.0, "z": 31.0, "turf": "tunel"},
	{"id": "bramka", "name": "Za bramką na boisku", "x": -88.0, "z": 128.0, "turf": "boisko"},
	{"id": "zaklub", "name": "Za klubem Neon", "x": -26.0, "z": 142.6, "turf": "klub"},
	{"id": "zbiornik", "name": "Zbiornik w Starej Hucie", "x": 192.0, "z": 58.0, "turf": "huta"},
	{"id": "portiernia", "name": "Za portiernią huty", "x": 187.0, "z": -18.2, "turf": "huta"},
	{"id": "kontenery", "name": "Między kontenerami w hucie", "x": 180.6, "z": 65.2, "turf": "huta"},
	# skrytkomaty (dostawa „pod kod”); pozycje ustala świat przy budowie
	{"id": "locker_a", "name": "Skrytkomat przy pawilonie", "x": 98.0, "z": -40.0, "lvl": 99, "locker": true},
	{"id": "locker_b", "name": "Skrytkomat na osiedlu", "x": -24.0, "z": -98.0, "lvl": 99, "locker": true},
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
	"lab": {"cx": 1400.0, "w": 14.0, "d": 11.0, "h": 3.6, "name": "Laboratorium w Starej Hucie"},
	"ciuchy": {"cx": 1500.0, "w": 8.0, "d": 6.4, "h": 2.9, "name": "Tania Odzież"},
	"club": {"cx": 1600.0, "w": 15.0, "d": 12.0, "h": 4.2, "name": "Klub Neon"},
	"szpital": {"cx": 1700.0, "w": 7.6, "d": 6.2, "h": 2.8, "name": "Szpital miejski"},
	"komisariat": {"cx": 1800.0, "w": 8.4, "d": 6.0, "h": 2.8, "name": "Komisariat III"},
}
## drzwi zewnętrzne: punkt przed drzwiami i kierunek „na zewnątrz” (dz)
var DOORS := {
	"safe": {"x": 8.0, "z": -76.6, "dz": 1.0, "title": "BLOCK 7 — ENTRANCE B", "color": "c9a86a"},
	"shop": {"x": -6.0, "z": 11.4, "dz": 1.0, "title": "STAŚ'S GROCERY", "color": "3ddc6e"},
	"garage": {"x": 65.0, "z": 94.6, "dz": -1.0, "title": "GARAGE 14", "color": "9aa3ab", "prop": "garaz"},
	"basement": {"x": -75.0, "z": -11.4, "dz": -1.0, "title": "BASEMENT", "color": "8a7a66", "prop": "piwnica"},
	"ciuchy": {"x": 42.0, "z": 11.4, "dz": 1.0, "title": "THRIFT CLOTHES", "color": "e85ab8"},
	# tylne drzwi laboratorium w Starej Hucie: otwarte tylko w prologu, potem zaplombowane
	"lab": {"x": 182.0, "z": -113.4, "dz": -1.0, "title": "", "color": "8a7a66", "sealed": true},
	# klub: wejście w ścianie wschodniej, pilnowane przez ochroniarzy (własny model drzwi i własna interakcja)
	"club": {"x": -5.6, "z": 128.0, "dz": 1.0, "title": "", "color": "ff3bd0", "custom": true, "yaw_out": -90.0},
	# szpital i komenda: wychodzi się stąd po wypadku albo zatrzymaniu, z ulicy nie ma po co wchodzić
	"szpital": {"x": -181.0, "z": 31.6, "dz": -1.0, "title": "EMERGENCY", "color": "e85a5a", "locked": "Izba przyjęć. Na szczęście nic Ci nie dolega — nie masz tu czego szukać."},
	"komisariat": {"x": -181.0, "z": 9.4, "dz": 1.0, "title": "POLICE", "color": "9ab4ff", "locked": "Sam z siebie na komendę? Lepiej nie kusić losu."},
}

# ---------------------------------------------------------------- znaleziska, śmietniki, lombard
## co można znaleźć: [id albo "cash" albo "", ile od, ile do, waga losowania]
const LOOT := {
	"ground": [["butelki", 1, 3, 30], ["cash", 5, 20, 20], ["zapalniczka", 1, 1, 12], ["kartridz", 1, 1, 5], ["telefon_stary", 1, 1, 5], ["zegarek", 1, 1, 2]],
	"bin": [["", 0, 0, 45], ["butelki", 1, 4, 25], ["cash", 2, 15, 9], ["zapalniczka", 1, 1, 6], ["miedz", 1, 1, 5], ["telefon_stary", 1, 1, 4], ["kartridz", 1, 1, 4], ["zegarek", 1, 1, 2]],
	"dumpster": [["", 0, 0, 30], ["butelki", 2, 6, 22], ["miedz", 1, 2, 10], ["radio_sam", 1, 1, 6], ["telefon_stary", 1, 1, 6], ["magnetofon", 1, 1, 5], ["kartridz", 1, 1, 5],
		["cash", 5, 30, 5], ["wiertarka", 1, 1, 4], ["aparat", 1, 1, 3], ["zegarek", 1, 1, 3], ["obraczka", 1, 1, 1]],
}
## kontener na używaną odzież: zwykle szmaty, czasem coś, co da się nosić
const LOOT_CLOTHES := [["", 0, 0, 60], ["czapka_zimowa", 1, 1, 10], ["rekawiczki", 1, 1, 10], ["dresy", 1, 1, 8], ["trampki", 1, 1, 6], ["butelki", 1, 2, 6]]
## ile minut zajmuje przeszukanie i ile losowań daje kosz uliczny, a ile kontener w altance
const BIN_MINUTES := 12.0
const BIN_ROLLS := {"bin": 1, "dumpster": 3}
## ile znalezisk leży co rano na mieście
const LOOT_DAILY := [5, 8]
## lombard: godziny otwarcia i dzienne wahanie cen skupu
const PAWN_OPEN := [9.0, 19.0]
const PAWN_SWING := 0.12

# ---------------------------------------------------------------- rozmowy telefoniczne
## Telefony od ludzi z życia Kuby. Każdy dzwoni raz, gdy spełnią się warunki (dzień, poziom, zdarzenie),
## w ciągu dnia, w oknie telefonu z boku ekranu — świat się nie zatrzymuje. Wpisy {"n": "Ty", "t": …} to kwestie gracza.
const CALLS := [
	{"id": "mama", "who": "Mama", "day": 2, "hour": [10.0, 21.0], "lines": [
		"Kubuś? No nareszcie odbierasz. Trzeci dzień dzwonię, a tam tylko poczta.",
		"Sąsiadka mówi, że pod hutą było pełno policji. Powiedz mi, że ciebie tam nie było. Skłam nawet, byle ładnie.",
		{"n": "Ty", "t": "Nie było mnie tam, mamo. Mam nową robotę, wynająłem kawalerkę. Wszystko gra."},
		"Robotę. Ty zawsze masz robotę, tylko nigdy nie wiem jaką. Zjedz coś ciepłego i zadzwoń w niedzielę. I Kuba — ojciec też zawsze mówił, że wszystko gra."]},
	{"id": "stas", "who": "Wujek Staś", "day": 3, "hour": [8.0, 12.0], "lines": [
		"Kuba, tu Staś. Nie przez telefon, wiem, ale posłuchaj starego, bo drugi raz nie powtórzę.",
		"Chodzisz po osiedlu z kasą w kieszeni jak z wypłatą. Jak cię zgarną z grubszą gotówką, to nie skończy się na mandacie — zaczną ci grzebać po mieszkaniu.",
		"Trzymaj przy sobie tyle, ile trzeba na dzień. Reszta do szafy. A towar, którego akurat nie sprzedajesz — też.",
		{"n": "Ty", "t": "Od kiedy sklepowy zna się na takich rzeczach?"},
		"Od czterdziestu lat mam sklep naprzeciwko komisariatu, synek. Ja się znam na wszystkim."]},
	{"id": "siwy", "who": "Areszt śledczy", "day": 5, "hour": [16.0, 21.0], "lines": [
		"To ja, Siwy. Mam trzy minuty na automat, więc nie przerywaj.",
		"Nic im nie powiedziałem i nie powiem. Ale słuchaj: oni weszli od tyłu, od rampy. O rampie wiedziały cztery osoby. Ty, ja, Wiktor i ten, kto woził nam beczki.",
		"A ten, co cię zdjął za garażami, nie szukał cię na ślepo. Stał dokładnie tam, gdzie miałeś przejść.",
		{"n": "Ty", "t": "Myślisz, że ktoś nas sprzedał."},
		"Myślę, że ktoś ma teraz pół kilo twojego śniegu i święty spokój. Rozejrzyj się, kto na osiedlu nagle ma za dużo pieniędzy. Kończę, strażnik idzie."]},
	{"id": "ola", "who": "Ola z Neonu", "lvl": 3, "hour": [14.0, 22.0], "lines": [
		"Cześć, tu Ola, stoję za barem w Neonie. Numer mam od Seby, nie pytaj.",
		"Ludzie u nas pytają o towar co weekend, a ci, którzy coś mają, biorą potrójnie i sypią mąkę. Przydałby się ktoś normalny.",
		"Tylko jedno: Bogdan na bramce maca kieszenie każdemu. Jak coś znajdzie, wylatujesz. Trzy razy jednej nocy i wyjeżdżasz karetką — widziałam to nie raz.",
		{"n": "Ty", "t": "To jak mam cokolwiek wnieść?"},
		"Mało na raz i w porządnej kurtce. W środku płacą lepiej niż na ulicy, więc i tak wyjdziesz na swoje. Otwieramy o dwudziestej."]},
	{"id": "adwokat", "who": "Mecenas Lipko", "arrests": 1, "hour": [9.0, 18.0], "lines": [
		"Dzień dobry, mecenas Lipko, z urzędu. Dostałem pańskie akta, więc powiem krótko, bo za długie rozmowy mi nie płacą.",
		"Jedno zatrzymanie to incydent. Pięć to akt oskarżenia, którego nie wybroni nikt. Proszę liczyć.",
		"Druga sprawa: gotówka. Jeśli znajdą przy panu kwotę, której nie da się wytłumaczyć zasiłkiem, prokurator wystąpi o przeszukania. Mieszkanie, garaż, wszystko.",
		"I niech pan nie ucieka przed patrolem na ich oczach. Najpierw krzyczą, potem strzelają w powietrze, a potem już nie w powietrze. Do widzenia."]},
	{"id": "szpital", "who": "Wiktor", "hospital": 1, "hour": [9.0, 22.0], "lines": [
		"Słyszałem, że leżałeś na Emergency. Kwiatów nie wysłałem, nie obrażaj się.",
		"Leżący człowiek nie zarabia, a odsetki chodzą dalej, czy stoisz, czy leżysz. To nie złośliwość, to matematyka.",
		{"n": "Ty", "t": "Ktoś mi wyczyścił kieszenie, zanim trafiłem na salę."},
		"Bo nosisz przy sobie za dużo. Na mieście masz mieć tyle, żeby nie było żal. Wracaj do pracy, Kuba."]},
	{"id": "polowa", "who": "Wiktor", "paid": 12500.0, "hour": [9.0, 22.0], "lines": [
		"Połowa. Przyznam, że stawiałem, że znikniesz po pierwszym tygodniu — przegrałem flaszkę.",
		"Teraz będzie trudniej, bo zaczynają cię znać. Policja, konkurencja, ci, którzy pamiętają, kim byłeś przed wybuchem.",
		"Rób swoje i nie wychylaj się bardziej, niż musisz. Jak spłacisz resztę, pogadamy o tym, kto ci tę hutę podpalił. Bo ja już chyba wiem."]},
	{"id": "nieznany", "who": "Nieznany numer", "lvl": 6, "hour": [20.0, 23.0], "lines": [
		"…",
		"Dobrze ci idzie, Kuba. Lepiej, niż myślałem, kiedy leżałeś za garażami z twarzą w żwirze.",
		{"n": "Ty", "t": "Kto mówi?"},
		"Ten, kto niesie twoją torbę. Ciężka była. Sprzedaję ją powoli, żeby starczyło na długo.",
		"Nie szukaj mnie. Jak przyjdzie pora, sam cię znajdę."]},
]

# ---------------------------------------------------------------- klub, szpital, komenda
## klub Neon wpuszcza od 20:00 do 5:00; trzecia wpadka przy kontroli jednej nocy kończy się w szpitalu
const CLUB_OPEN := 20.0
const CLUB_CLOSE := 5.0
const CLUB_TRIES := 3
## imprezowicze w środku płacą więcej niż ulica
const CLUB_PREMIUM := 1.35
## goście loży VIP rozmawiają dopiero z kimś, kto ma już nazwisko na mieście
const CLUB_VIP_LVL := 5
## szpital: tyle gotówki z kieszeni „znika”, zanim się ockniesz (od–do)
const HOSPITAL_LOSS := [0.2, 0.7]
## komenda: gotówka przy sobie powyżej tego progu (rośnie z poziomem) robi z Ciebie hurtownika
const CASH_SUSPECT := 3000.0
const CASH_SUSPECT_LVL := 1500.0
const CASH_SUSPECT_INVEST := 12.0
## przez tyle dni po takiej wpadce policja węszy po kryjówkach; dzienna szansa nalotu na każdą z nich
const WATCH_DAYS := 3.0
const WATCH_RAID := 0.22

# ---------------------------------------------------------------- nieruchomości i meble
const PROPERTIES := [
	{"id": "garaz", "name": "Garaż nr 14", "price": 2600, "lvl": 4, "room": "garage", "where": "Garaże przy Robotniczej",
		"desc": "Blaszak z prądem „na lewo”. Miejsce na stół, regały i pierwszy namiot uprawowy."},
	{"id": "piwnica", "name": "Piwnica w kamienicy", "price": 9000, "lvl": 6, "room": "basement", "where": "Zaułek za kamienicą, ul. Hutnicza",
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
	{"id": "lampa_led", "name": "Lampa LED do uprawy", "price": 650, "model": "", "h": 2.0, "size": [1.7, 1.0], "func": "growlight", "hang": true, "lvl": 4, "desc": "Fioletowy panel na łańcuchach pod sufitem. Krzaki pod nim rosną 2,5 raza szybciej i wychodzą mocniejsze. Mieści się pod nim 6 doniczek."},
	{"id": "suszarka", "name": "Suszarka siatkowa", "price": 260, "model": "", "h": 1.9, "size": [0.9, 0.9], "func": "dry", "cap": 90, "lvl": 4, "desc": "Świeży zbiór trzeba wysuszyć (8 godzin), zanim trafi na wagę. Mieści 90 g."},
	{"id": "zbiornik", "name": "Zbiornik z pompą", "price": 700, "model": "", "h": 1.15, "size": [0.75, 0.75], "func": "tank", "lvl": 6, "desc": "Sam podlewa wszystkie uprawy w tej kryjówce. Nie musisz pamiętać o wodzie."},
	{"id": "filtr", "name": "Filtr węglowy", "price": 700, "model": "", "h": 1.7, "size": [0.6, 0.6], "func": "filter", "lvl": 4, "desc": "Zapach z tej kryjówki spada o 60%. Mniej zapachu = mniejsze ryzyko nalotu."},
	{"id": "lab", "name": "Stół laboratoryjny", "price": 3600, "model": "", "h": 0.92, "size": [2.0, 0.9], "func": "lab", "lvl": 5, "desc": "Synteza z zestawu chemikaliów: amfetamina, później metamfetamina. Śmierdzi i wymaga doglądania."},
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
	4: "Nowy towar: amfetamina. Możesz kupić Garaż nr 14.",
	5: "Doniczki, nasiona i lampy LED — własna marihuana w kryjówce.",
	6: "Klienci z klubu Neon. Piwnica w kamienicy na sprzedaż.",
	7: "Nowy towar: metamfetamina. Zamówienia hurtowe po 100 g.",
	8: "Zamówienia hurtowe po 250 g.",
	9: "Nowy towar: kokaina — dla klientów z najgrubszym portfelem.",
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

	{"id": "reka", "name": "Pewna ręka", "branch": "Towar", "row": 0, "desc": "Przy porcjowaniu rozsypujesz o 40% mniej towaru."},
	{"id": "mieszanie", "name": "Dobra mieszanka", "branch": "Towar", "row": 1, "req": "reka", "desc": "Rozrabianie obniża czystość o 20% mniej."},
	{"id": "czysta", "name": "Niewidoczny dodatek", "branch": "Towar", "row": 2, "req": "mieszanie", "desc": "Doświadczeni klienci o 30% rzadziej rozpoznają rozrobiony towar."},
	{"id": "paczki", "name": "Szybkie palce", "branch": "Towar", "row": 3, "req": "czysta", "desc": "Porcjujesz dwa razy szybciej — każdy woreczek zabiera połowę czasu."},
	{"id": "ogrodnik", "name": "Ogrodnik", "branch": "Towar", "row": 4, "req": "paczki", "lvl": 5, "desc": "Namiot uprawowy daje o 35% większy plon."},

	{"id": "slowo", "name": "Dobre słowo", "branch": "Kontakty", "row": 0, "desc": "Zadowoleni klienci szybciej polecają Cię dalej."},
	{"id": "kredyt", "name": "Kredyt zaufania", "branch": "Kontakty", "row": 1, "req": "slowo", "desc": "Limit „zeszytu” u Wiktora wyższy o 600 zł."},
	{"id": "rabat", "name": "Rabat hurtowy", "branch": "Kontakty", "row": 2, "req": "kredyt", "desc": "Towar u Wiktora tańszy o 8%."},
	{"id": "siec", "name": "Siatka", "branch": "Kontakty", "row": 3, "req": "rabat", "desc": "+2 do limitu stałych klientów, zamówienia częściej."},
	{"id": "uklad", "name": "Układ", "branch": "Kontakty", "row": 4, "req": "siec", "desc": "Łapówki dla policji skuteczniejsze o 15 pkt proc."},
]
const BRANCHES := ["Handel", "Ulica", "Towar", "Kontakty"]

# ---------------------------------------------------------------- dług i ryzyko
const START_CASH := 200
const START_DEBT := 25000
const DEBT_SCHEDULE := [
	{"day": 5, "due": 100}, {"day": 9, "due": 250}, {"day": 13, "due": 600}, {"day": 17, "due": 1300}, {"day": 21, "due": 2500}, {"day": 25, "due": 4300},
	{"day": 29, "due": 6800}, {"day": 33, "due": 10000}, {"day": 37, "due": 14000}, {"day": 41, "due": 19000}, {"day": 46, "due": 25000},
]
const DEBT_INTEREST := 0.01
const LIVING_COST := 28
const MAX_ARRESTS := 5
const MAX_STRIKES := 3
const CREDIT_BASE := 400
const CREDIT_DAYS := 4

const HINTS := [
	"Im bliżej ukrytego maksimum klienta zaproponujesz cenę, tym większy zysk. Kontroferta zdradza, ile jest gotów dać.",
	"Każdy klient lubi inny styl rozmowy. Raz odkryty zapisuje się w aplikacji Kontakty.",
	"Nie handluj na oczach policji. Nocą jest mniej świadków, ale patrole są czujniejsze.",
	"Towar w skrytce jest bezpieczny podczas zatrzymania. Noś przy sobie tylko tyle, ile sprzedasz.",
	"Niedokładne porcjowanie marnuje towar. Trzy trafienia na wadze = zero strat.",
	"Majeranek podbija wagę marihuany, ale stali klienci, którzy biorą dużo, rozpoznają mieszankę i odmówią.",
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
