# CZARNY RYNEK

Gra 3D z widokiem z pierwszej osoby w stylu *Schedule I*: produkujesz fikcyjny towar, odpowiadasz na SMS-y klientów,
targujesz się, unikasz policji, pierzesz pieniądze i spłacasz dług u Księgowego.
Wszystkie substancje, receptury i postacie są **całkowicie zmyślone**.

## Pobieranie

Pobierz paczkę ZIP (zielony przycisk **Code → Download ZIP** na GitHubie), rozpakuj ją i uruchom grę jak niżej.
Nie trzeba niczego instalować poza Pythonem 3 (na Macu zwykle już jest).

## Jak uruchomić

**Mac:** dwuklik na `Uruchom.command` — startuje lokalny serwer i otwiera grę w przeglądarce.
Jeśli macOS zablokuje plik: prawy przycisk → Otwórz, albo w Terminalu w folderze gry: `python3 serve.py`.

**Windows:** dwuklik na `Uruchom.bat` (wymaga Pythona 3 z python.org).

**Bez Pythona:** można spróbować otworzyć `index.html` bezpośrednio w przeglądarce
(wtedy nie działa tylko własna muzyka z folderu `muzyka/`).

Adres gry po uruchomieniu serwera: `http://localhost:8765/`. Najlepiej Chrome, Opera lub Edge, na pełnym ekranie.

## Sterowanie

| Klawisz | Akcja |
|---|---|
| WASD | ruch |
| Mysz / trackpad | rozglądanie (kliknij okno gry); alternatywnie strzałki |
| Shift | sprint |
| E | interakcja: rozmowa, drzwi, stanowiska, łóżko, skrytka |
| Tab | telefon: zadania, **SMS-y z odpowiedziami**, plecak, klienci, mapa, sklep, umiejętności, finanse, ekipa, opcje |
| N | trasa do celu wł./wył. (zielona wstęga na ziemi i linia na minimapie) |
| Q | następny cel trasy (cel fabularny, umówieni klienci, dom, hurtownia…) |
| F | latarka |
| Spacja / Enter | dalej w dialogu, STOP w mini-grze produkcji |
| 1–5 | wybór odpowiedzi w dialogu |
| M / Esc | dźwięk / pauza |

## Najważniejsze zasady

- **Dług:** 70 000 zł w 56 dni, raty co tydzień, +2% odsetek tygodniowo. Trzy spóźnienia = koniec gry.
- **Produkcja:** cztery stanowiska (doniczki, stół reakcyjny, prasa, laboratorium). Jakość zależy od mini-gry;
  0 trafień grozi zepsuciem partii. Dodatki: Stabilizator (bez zepsucia), Wzmacniacz (+1 jakość), rozcieńczanie (+2 szt., −1 jakość).
- **Klienci:** piszą SMS-y z ofertą. Odpowiedz w telefonie: przyjmij, zaproponuj wyższą cenę albo odmów.
  Po przyjęciu klient pojawia się na mapie, a trasa prowadzi prosto do niego. Na ulicy chętni przechodnie mają ikonę 👀.
  Klienci mają zadowolenie, lojalność i „znudzenie” tym samym towarem.
- **Policja:** uwaga policji jest lokalna (dzielnice) i globalna; do tego rośnie śledztwo. Zdarzają się obławy,
  naloty i prowokacje — klient, który bierze każdą cenę, może być policjantem.
- **Pieniądze:** gotówka z ulicy jest „brudna”. Myjnia pierze ją na konto; z konta kupisz najdroższy sprzęt.
- **Rozwój:** ulepszenia wielopoziomowe, umiejętności za doświadczenie, pracownik produkcji i dilerzy uliczni.
- **Fabuła:** 8 rozdziałów i 5 zakończeń.

## Muzyka w klubie

W pobliżu klubu Neon słychać muzykę (na ulicy przytłumioną, w środku pełną).
Domyślnie gra wbudowany, syntezowany bit klubowy. Żeby grały **Twoje utwory**, wrzuć pliki MP3/M4A/OGG/WAV
do folderu `muzyka/` i uruchom grę przez `Uruchom.command`.

## Jakość grafiki

Telefon → Opcje → Jakość grafiki (Wysoka / Średnia / Niska). Jeśli gra się przycina, wybierz niższą.

## Zapis

Automatycznie co dzień, przy zamknięciu karty i przy spaniu w łóżku. „Kontynuuj” w menu wczytuje zapis.

## Biblioteki

Gra korzysta z [three.js](https://threejs.org/) r128 (licencja MIT) — pliki `three.min.js` oraz `lib/`.
