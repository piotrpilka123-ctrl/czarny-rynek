# Czarny Rynek

Gra testowa Piotra Piłki — symulator osiedlowego dilera w klimacie polskiego blokowiska (Godot 4, widok z pierwszej osoby).
Wszystkie postacie, miejsca i wydarzenia są fikcyjne. Gra nie zachęca do łamania prawa ani zażywania narkotyków.

▶ **Zwiastun:** [zwiastun/czarny-rynek-zwiastun-720p.mp4](zwiastun/czarny-rynek-zwiastun-720p.mp4)

| | |
|---|---|
| ![Osiedle wiosną](screenshots/01-osiedle-wiosna.jpg) | ![Spocik pod blokiem](screenshots/02-spocik-pod-blokiem.jpg) |
| ![Laboratorium w Starej Hucie](screenshots/06-laboratorium.jpg) | ![Wybuch huty](screenshots/08-wybuch-huty.jpg) |
| ![Klub Neon](screenshots/05-klub-neon.jpg) | ![Ucieczka nocą](screenshots/07-ucieczka-noca.jpg) |
| ![Kawalerka](screenshots/04-kawalerka.jpg) | ![Ekwipunek i ubrania](screenshots/09-ekwipunek.jpg) |
| ![Giełda w telefonie](screenshots/10-gielda.jpg) | ![Sąsiad przy grillu](screenshots/03-sasiad-przy-grillu.jpg) |

## Jak uruchomić

**macOS:** kliknij dwukrotnie **`Uruchom Czarny Rynek.command`**. Potrzebny jest [Godot 4](https://godotengine.org/download)
(projekt powstał w wersji 4.7) w `/Applications/Godot.app`.

**Windows / Linux:** otwórz w Godocie plik `godot/project.godot` i naciśnij F5.

Pierwsze uruchomienie po pobraniu trwa dłużej — Godot musi zaimportować modele i tekstury (ok. 300 MB zasobów).

Gra startuje na pełnym ekranie (F11 przełącza okno). Jakość grafiki zmienisz w telefonie → Ustawienia.
Obraz 3D skaluje się automatycznie, żeby utrzymać ok. 60 kl./s na MacBooku z M2; interfejs zawsze jest ostry.

## O co chodzi

Brata zabrała policja. Zostawił Ci kawalerkę oraz 25 000 zł długu u Wiktora. Wiktor daje towar na zeszyt i pierwszego klienta.
Resztę budujesz sam: klienci z polecenia, własna kryjówka, uprawa, kolejne towary (marihuana → amfetamina → metamfetamina → kokaina).
Raty rosną co cztery dni — trzy wpadki i koniec gry. Spłata całości zajmuje ok. 45 dni gry (1 godzina gry = 60 s).

Nowa gra zaczyna się krótkim wstępem (zatrzymanie brata, „trzy tygodnie później”), a samouczek najpierw oprowadza
po kawalerce: zapis gry, skrytka, waga — dopiero potem Wiktor wysyła po pierwszą paczkę.

- **Towar**: piszesz do Wiktora — telefon obraca się na bok i pokazuje jego „sklep”: kafle z towarem, rozmiar paczki, koszyk.
  Towar jest zawsze czysty i idzie na zeszyt. Paczka czeka w skrytce oznaczonej małym znakiem sprejem (z czasem skrytki
  są coraz dalej). Porcjujesz na wadze, możesz rozrobić — cena zostaje ta sama, ale klient może kręcić nosem albo odmówić.
- **Spłata**: gotówkę wrzucasz do skrzynki Wiktora za pawilonem (zawsze w tym samym miejscu). Idzie najpierw na to,
  czego termin jest bliżej: zeszyt za towar albo rata długu brata.
- **Klienci**: każdy odzywa się mniej więcej raz dziennie. Odpowiadasz kaflami: Zgoda / Negocjuj / Zmień godzinę / Anuluj.
  Po potwierdzeniu spotkanie jest za ok. godzinę (chyba że ustalisz inną porę); klient wychodzi z domu i idzie na miejsce.
  Na spotkaniu nie ma gadania: wybierasz woreczek, ewentualnie cenę (od −10% do +15%) i przytrzymujesz „Podaj towar”.
  Świat się wtedy nie zatrzymuje — pasek pokazuje, ilu ludzi patrzy i czy widzi Was patrol.
  „Zaraz wracam” zostawia klienta na miejscu, „Rezygnuję” odwołuje transakcję.
- **Ekwipunek** (I): rzeczy mają rozmiar i wagę, układają się w stosy. Przeciągasz je między plecakiem a skrytką,
  a ilość wybierasz suwakiem albo wpisujesz. Sztuki są całe, gramy liczone w połówkach.
- **Zapis gry**: tylko przy laptopie w kryjówce (w kawalerce stoi na stole; do garażu i piwnicy kupisz stolik z laptopem).
  Nie ma zapisów automatycznych — niezapisany postęp przepada.
- **Interakcje** (E): trzeba nacelować na drzwi, mebel albo osobę z bliska; celownik zmienia się wtedy w zielony pierścień.
- **Policja**: na początku prawie jej nie ma, z każdym tygodniem patroli przybywa; piesze patrole i radiowóz, gorąco w dzielnicach, śledztwo. Policjant widzi przed siebie i trochę na boki,
  nie za plecy (stożki widać na mapie). W pościgu przytrzymaj X, żeby wyrzucić towar.
- **Miasto**: GPS prowadzi ulicami i ścieżkami, ale w płotach są dziury — kto zna teren, pójdzie na skróty.
- **Kryjówki**: garaż i piwnica do kupienia; meblujesz je sam (B) — stół z wagą, regały, namiot uprawowy.

## Sterowanie

| Klawisz | Działanie |
|---|---|
| WASD, mysz | ruch i rozglądanie |
| Shift | sprint |
| E | interakcja z tym, na co celujesz (przytrzymaj przy skrytce w mieście) |
| Tab | telefon |
| I | ekwipunek |
| N / Q | trasa do celu / następny cel |
| B / R | meblowanie kryjówki / obrót mebla |
| F | latarka |
| X (przytrzymaj) | wyrzuć towar |
| M | dźwięk |
| F11 | pełny ekran |
| Esc | pauza |

## Muzyka w klubie

Klub Neon gra wbudowany, oryginalny bit. Żeby leciała Twoja muzyka, wrzuć własne pliki MP3 do `godot/muzyka/`.

## Co jest w repozytorium

- `godot/` — **główna gra** (Godot 4; skrypty w `scripts/`, zasoby w `assets/`).
- `game/` — starsza wersja przeglądarkowa (Three.js), od której projekt się zaczął. Uruchomienie: `game/Uruchom.command`
  albo `python3 game/serve.py`. Ma własny opis w `game/README.md`.
- `zwiastun/` — zwiastun gry (720p).
- `screenshots/` — zrzuty ekranu.
- `LICENCJE.md` — autorzy i licencje użytych zasobów.

## Dla ciekawych: narzędzia

Wszystko uruchamia się z folderu `godot/`:

- `./tools/runtest.sh 90` — automatyczny test rozgrywki (bez okna i dźwięku).
- `./tools/runtest.sh 240 --sim=48 --runs=3 --lazy=0.35` — symulacja ekonomii: bot gra 48 dni i wypisuje bilans.
- `./shot.sh nazwa --autostart --loc=out --hour=18` — zrzut ekranu z gry (trafia do folderu tymczasowego).
- `./tools/plan.sh plan.png` — plan miasta z góry (nawierzchnie, budynki, kolizje), bez otwierania okna.
- `./tools/widok.sh widok.png "x,z" kąt` — widok z oczu gracza bez okna: gra eksportuje wycinek świata, Blender go renderuje
  (`LUDZIE=1` dołącza postacie; `./tools/widok_pokoj.sh` robi to samo dla wnętrz).
- `./tools/uiaudit.sh` — przegląd układu wszystkich okien interfejsu (ucięty tekst, elementy poza ekranem), też bez okna.
- `Godot --headless --path . -- --autostart --test --przeglad` — lista rekwizytów, które wiszą, toną albo stoją w budynku.
- `./tools/trailer.sh <folder>` — nagranie klatek zwiastuna; potem `python3 tools/soundtrack.py` i `swift tools/encode.swift`.
