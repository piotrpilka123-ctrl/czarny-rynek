# Czarny Rynek — bieżąca kontynuacja Codex

Projekt: /Users/macbook/czarny-rynek/godot. Godot 4.7.2, Blender 4.5.14 LTS.

## Polecenia Piotra (8 października 2026)

Kontynuować po Claudzie, poprawiać błędy, tekstury mapy i początek gry/samouczek,
aby zachęcał do zabawy. Pracować dalej do słowa „stop” (także „stoo”).
Najnowsza konkretna prośba: ręka w samouczku przenoszenia kokainy/notesu ma pokazać
kliknięcie, przytrzymanie LPM, przeciągnięcie, puszczenie oraz wybór i potwierdzenie wszystkiego.

## Zrobione

- c9698e6: kod jebacmazur nie uruchamia E/C/M; przerwa 5 s przerywa sekwencję;
  pisanie w polach i przypisywanie klawiszy wyłączają rozpoznawanie.
- c9698e6: runtest zwraca rzeczywisty kod zakończenia i błąd po timeout;
  commit.sh wymaga pełnego podsumowania sukcesu. Usunięto fałszywe autorstwo Claude.
- 604ea18: po kodzie otwarty ekwipunek odświeża gotówkę. 632 testy OK.

## Zrobione po kontynuacji

- inventory.gd: demonstracja 6 etapów nad właściwym wierszem przedmiotu,
  wizualizacja przytrzymanego LPM; demonstracyjne potwierdzenie nie zmienia ekwipunku.
- Prawdziwe okno ilości dostało „Wszystko”; notes wymaga potwierdzenia.
- c8c93c6: 636 testów OK, układy stash/invask bez uwag. Obejrzano przeciąganie
  i pokaz potwierdzenia w prawdziwym rendererze. Dodatkowo ikona przedmiotu podąża za ręką.
- 4fe78cb: stonowana trawa, duże przebarwienia twardych nawierzchni, suche drogi bez
  sztucznych kałuż. Studzienki zlicowane z podłożem i dopasowane normalną do spadku.
  Obejrzano wynik w rendererze (nawierzchnia-final.png). 639 testów OK.
- 4fe78cb: cel pierwszej dostawy podaje godzinę spotkania przed przyjściem klienta,
  a po umówionej porze termin, do którego czeka. Pierwsze spotkanie objaśnia czas gry,
  minimapę, pełną mapę i składanie zamówionej wagi z paczek. Indeksy fabuły bez zmian.

## Ostatni ukończony blok

- 880eb61, npc.gd: kontekstowe kwestie pogody/pory dnia/pościgu, brak natychmiastowego
  powtarzania tej samej kwestii. Własne kwestie stałych mieszkańców wracają co drugą rozmowę.
- Przechodnie przy widocznym pościgu (LOS, do 14 m) przestają stać, przyspieszają
  na 5 sekund i na kolejnym skrzyżowaniu wybierają istniejącą ścieżkę oddalającą
  od gracza. Sprawdzanie LOS najwyżej raz na sekundę na pobliskiego przechodnia.
- Ostatnie polecenie Piotra: dodać własne pomysły, żeby gra i dzielnica bardziej żyły.
- 639 testów OK. Oddzielny przebieg ze sceną gry potwierdził brak powtórzeń kwestii,
  zmianę tematu nocą i reakcję prawdziwego przechodnia na pościg (LOS i wyzerowane stanie).
  Nie oglądano jeszcze zachowania przy pościgu w rendererze — to następna kontrola.
- Kontrole wizualne: samouczek-potwierdzenie.png, nawierzchnia-final.png w
  /Users/macbook/codex-podglad. Pokaz potwierdzenia ma widoczną rękę nad oknem.
- Stan Git po blokach czysty, nic nie wypchnięto na GitHub.

## Następne konkretne zadanie

Obejrzeć pościg z przechodniami w rendererze, potem pogłębić harmonogramy mieszkańców
lub dodać drobne sytuacje uliczne z gestami. Unikać kolejnych statycznych dekoracji
jako jedynego sposobu ożywienia mapy. Sprawdzić też pokaz przenoszenia kokainy
w prologu i jego potwierdzenie przy różnych proporcjach ekranu.

## Następne bloki

1. Kontynuować przegląd nawierzchni (pierwszy blok zakończony) i poprawiać powtarzalność/kolor/połysk
   asfaltu, chodników i trawy; zachować skalę, nie dodawać ciężkich modeli bez potrzeby.
2. Początek: wyjaśnić cel rozwoju i nagrodę za pierwszy awans; nauczyć obsługi spotkania,
   przenoszenia całego stosu, zapisu i konsekwencji kontroli w krótkich wskazówkach.
   Nie zmieniać indeksów kroków fabuły bez migracji zapisów.
3. Brak dźwięków miasta: stare notatki opisują 3 źródła CC0, ale pliki i licencje trzeba
   zweryfikować przed pobraniem; nie twierdzić, że odsłuchano dźwięk bez odsłuchu.

## Zasady

Testy z --audio-driver Dummy. Przed oknem tools/wolne.sh; nie przeszkadzać graczowi.
Nie pushować GitHuba bez polecenia. Przy każdej zmianie wizualnej oglądać wynik,
nie polegać na samym teście headless. tools/commit.sh uruchamia pełny test.
Otwarto automatyzację heartbeat „dopracowanie-czarnego-rynku”, co 30 minut w tym czacie.
Na „stop”/„stoo” wyłączyć ją i zaprzestać pracy.


## Nowe polecenia Piotra i aktualna kolejność

- 7ba6a2d: odgłosy imprezy w prologu zmienione na ciągłe stereo tłumu + pojedyncze
  krótkie wiwaty, bez nakładania obcego śpiewu i tych samych okrzyków. Muzyka/jej ustawienia
  bez zmian. Nowy plik CC0 pochodzi z istniejącego źródła, nie było pobierania.
- 7ba6a2d: patrole po stałych odcinkach też używają siatki omijającej kolizje;
  pozycje startowe i końce obchodów na wolnych komórkach. Skupione ruchy latarek.
  Ucieczka ma kolejne cele wzdłuż bezpiecznej trasy, zamiast jednej strzałki przez przeszkody.
  639 testów OK. Pierwszy screenshot był niepoprawnym wywołaniem bez --intro — NIE używać
  prolog-ucieczka.png jako dowodu kontroli; poprawne uruchomienie ma --autostart --intro --prostage=escape.
- Najnowsze zadania: zróżnicować budynki; poprawić płoty i usunąć bezsensowne/nadmierne
  przejścia; szczególnie poprawić tekstury pustaków. Nie gubić tych zadań w kolejnych blokach.
- 5f5b01f: nowy pustak z Blendera: dwie otwarte komory, porowaty beton, sfazowane
  krawędzie. Podgląd /Users/macbook/codex-podglad/pustak.png obejrzany; 639 testów OK.
- Pracować oszczędniej tokenowo: krótkie odczyty i raporty, celowe screenshoty,
  utrzymać pełne testy i faktyczny postęp. Kontynuacja do „stop” nadal obowiązuje.

- Dodatkowa symulacja prologu: 700 aktualizacji po 0,05 s, wszystkie patrole poza
  kolizjami (0 wejść w zablokowaną komórkę); nowe nagranie tłumu wczytuje się,
  strumień muzyki nadal PARTY_MUSIC. Log: /tmp/czarny-prolog-check.log.
- Poprawny podgląd ucieczki obejrzany: /Users/macbook/codex-podglad/prolog-patrole.png
  (--autostart --intro --prostage=escape). Widoczny etapowy cel i znak 7 m.
- Następny priorytet: płoty i nadmiar przejść przy hucie/torach, następnie wyraźniejsze
  różnice budynków. Dokończyć te żądania, nie wracać do już ukończonych testów bez powodu.


## Rozbudowa po porównaniu Schedule I / DDS — najnowsze polecenia

Piotr chce rozumienia pętli tych gier, porównania braków i wdrożenia ich we własnym projekcie.
Powstał PLAN-ROZGRYWKI.md z oficjalnymi źródłami i kolejnością. Nowe prośby o grafikę
są uzupełnieniem, nie kasują mechanik: powiększyć mapę o osiedle kontrolowane przez gang
(niebezpieczne na początku), jezioro i teren za garażami. Poprawić śmietniki, kraty,
system chowania, celowanie i interakcje, których pola wydają się za duże.

Aktualny blok: mniejsze promienie i zasięg interakcji, promień fizyczny blokowany przez
przeszkody, cel kryjówki na jej wejściu; wyjście nie usuwa wiedzy policjanta.
Nowa aplikacja Dostawy: rezerwuje faktyczne całe paczki w kopii kieszeni, uwzględnia
wymaganą jakość, ostrzega przed za dużymi woreczkami i nie podwaja zapasu.
752a31b: 647 testów OK. Audyt Dostaw: 0 uwag; podgląd w rendererze obejrzany
(/Users/macbook/codex-podglad/dostawy.png). Następnie realizować punkty
3–6 planu i wcześniej zgłoszone budynki/płoty. Aktualizować ten zapis po każdym bloku.


## Noc 8/9 października — dealerzy i wsad

User dopisał: dealerzy z zaopatrywaniem i prowizją; większe partie, amfa 1 slot,
meta 2, koks 3; interaktywne systemy laboratoryjne jak uprawa oraz lepsze rośliny/sadzenie.
Nowa kompletna kolejka NOCNA-LISTA-CODEX.md — korzystać z niej przy kolejnych blokach.
- 319d3d2: scripts/dealers.gd, Mati i Darek w świecie, rekrutacja z warunkami,
  fizyczne zaopatrzenie (paczek nie duplikuje), sprzedaż z prowizją i ograniczeniami,
  osobisty odbiór gotówki, zapis, telefon i nawigacja. 664 testy OK.
- Wsady 1/2/3: nowe fikcyjne pakiety u Stasia. Partie 72/60/90 g; koszty
  1600/4800/10800 zł, czasy 8/14/22 h. Sloty pokazują posiadane/wymagane ilości.
  Dealerzy/sloty: audyt 0 uwag i renderer obejrzany (dealerzy.png, lab-sloty.png).
- Naprawiono ujawniony przez zmianę losowego układu NPC błąd szukania: patrol
  wybiera osiągalne punkty, czyści starą trasę i odzyskuje pozycję na wolnej komórce.
- Osobny audyt dystrybucji 1 partii przez 7 dni: amfa +784 zł do dnia 2, meta +864
  do dnia 5, koks +5520 do dnia 7 po wsadzie, woreczkach i rekrutacji; bez prądu,
  sprzętu, podróży i wpadek. EKONOMIA-SIECI.md, tools/dealer_balance.gd.
- Kampania botów bez produkcji/sieci: wspólnik dzień 19/23 — nie traktować tego
  jako testu całej nowej gospodarki.
Następny punkt: fizyczne czynności/animacje laboratorium i poprawa roślin/sadzenia,
potem wznowić rozszerzenie mapy. W tej turze mapy jeszcze nie zmieniono.


## Interaktywne laboratorium — kolejny blok

2692af9 / aa8e909: laboratorium ma menu przy celowniku, jak doniczki. Puste stanowisko:
wybór dostępnej partii + Sprawdź. W trakcie: oczekująca czynność; po zakończeniu: odbiór.
LabCare animuje układanie 1–3 pakietów, przelewanie, filtrowanie, zgarnianie i odbiór.
Skutki wykonywane raz w środku animacji. Panel parametrów pozostaje pod Sprawdź.
9 nowych kontroli obejmuje braki wsadu, zakaz podwójnego startu, oczekiwanie, kontynuację,
odbiór i blokadę drugiej czynności; pełny test ostatnio 674 OK.

Pierwszy podgląd laboratorium-czynnosc.png był omyłkowo panelem, bo preset labwork
nie uruchamiał animacji. Poprawiono preset; laboratorium-wsad.png oraz
laboratorium-przelanie.png obejrzane w rendererze (log LAB_WORK_STARTED true).
Zauważona silna zielona poświata: trwa korekta na neutralną ciecz i lokalne ciepłe
światło palnika. Otwarta szyjka butelki i krople w animacji. Końcowy podgląd
laboratorium-swiatlo.png obejrzany: neutralne oświetlenie zamiast zielonej poświaty.
f2a57be zapisany po pełnym teście: 673 OK, 0 błędów.

Następny podpunkt listy: rzeczywista poprawa modeli roślin i sadzenia/uprawy,
nie ponowne przepisywanie już gotowego menu laboratorium. Po roślinach mapa.


## 57a3dcb — rośliny i sadzenie (676 testów OK)

tools/blender/make_rosliny.py → roslina_1/2/3.glb. Łodyga, gałązki i składane liście;
modele współdzielone przez wszystkie doniczki. Materiały normalne/więdnące cached,
subtelne doświetlenie, cienie. Stare karty pozostają tylko awaryjnym fallbackiem.
Nowa roślina przez pierwsze 3% cyklu jest widocznym nasionem, nie gotową sadzonką.
Woda/wzrost/zdrowie/plon i koszt zachowane. Seed FX to drobinki ziemi; opis kiełkowania.
Test sprawdza nasiono, pojawienie liści oraz wczytanie wszystkich 3 siatek z Blendera.

Obejrzane: /Users/macbook/codex-podglad/rosliny-etapy.png i rosliny-3d.png.
Materiały zweryfikowane: aktywny materiał oraz tekstura atlasu obecne, bez pustych
białych materiałów. W podglądzie garażu 59 FPS (med, 960×540) — pomiar poglądowy.
Punkt 2 listy odhaczony. Następne zadanie: rozszerzenie mapy za garażami (punkt 3),
jezioro (4), osiedle gangu (5). Nie rozpoczynać kolejnego przepisywania roślin zamiast mapy.


## 49a71c6 — rzeczywiste rozszerzenie zaplecza za garażami

World.NZ 229→281, MAP_H 684→840, południowy brzeg 169,2→247,2. Nowe warsztaty,
plac, nawierzchnie, jeden sensowny ciąg ścieżek, ławka, dwa kosze, Roman i otoczenie.
Przesunięto mur/kolizje, drzewa i południowy pierścień tła. Gracz nie jest cofany na
stary limit; telefon ma Backyards, nowe krawędzie grafu po grid_path omijają przeszkody.
Wykryto i poprawiono wcześniejszy błąd: cur_target ignorował dealer_* mimo przycisku
telefonu. Nowy test obejmuje faktyczny wybór celu dealera.

Pierwsze przebiegi wykryły lampę nad trawnikiem, starą kontrolę granicy i dwa brakujące
narożniki. Dodano chodnik, dopasowano kontrolę do nowej granicy, zamknięto narożniki.
Ostatecznie 683 testy OK, 0 błędów; 6 kontroli nowego terenu plus pełny obwód granicy.
Podglądy zaplecze-garazy.png / zaplecze-final.png obejrzane w rendererze.
NOCNA-LISTA punkt 3 odhaczony. Następny 4: jezioro; punkt 5: osiedle gangu.
Plan jeziora: rejon (90,217), promienie (31,19), z zachowaniem furtki (83,193),
nawierzchni i warsztatów; to propozycja miejsca, jeszcze nie gotowa woda.


## Jezioro — punkt 4

4fb65d5 / 4deb777: zagłębiony zbiornik za zapleczem (90,217), brzeg i pętla ścieżek,
ławka/kosz, Pan Józek w godzinach 6–20, cel Old Reservoir w telefonie, kolor w minimapie.
Głębokie komórki zablokowane w nawigacji; nowe krawędzie grafu scalają wspólne punkty,
żeby brzeg był połączony z zapleczem. Krótkie trasy także sprawdzają siatkę kolizji.
Gracz brodzi wolniej przy brzegu; nie schodzi do głębokiej wody. Pozycja starego zapisu
na nowym dnie przenoszona na brzeg. Kontrole brzegu, furtki, trasy minimapy i pozycji.
689 testów OK po poprawieniu typów w nowym teście.

Renderer obejrzany: jezioro.png, jezioro-brzeg.png, jezioro-final.png i jezioro-odbicia.png
w /Users/macbook/codex-podglad. Transparentny wariant dawał mleczną obwódkę; użyto
odcięcia według głębokości i stonowanych odbić. Ostatni shader zapisany w 3682ef4
po pełnym teście: 689 OK, 0 błędów. Punkt 4 odhaczony; następny 5: osiedle gangu.
Dalszy szlif naturalności brzegu/otoczenia zostaje częścią pełnego przeglądu grafiki.


## Black Court — punkt 5

Zamknięty teren (-110..-16, 183..240) na nowym zapleczu. Trzy bryły o innych
wysokościach i elewacjach; detale wejść, anteny, balkony, zieleń, ławka, kosz.
Jeden wjazd, czytelny napis, Borys przy bramie i strażnik na dziedzińcu.
Pierwsze podejście daje ostrzeżenie. Stary zapis wewnątrz lub przeskoczenie muru
przenosi początkującego przed bramę. Dostęp wymaga osobistej rozmowy: poziom 7,
ranga Dealer (wkład 3500 zł), brak pościgu. Przepustka w S.flags; podnoszona
brama jednocześnie zmienia kolizję, LOS i AStar, zachowując sąsiednie ściany.
Osobna strefa Black Court i cel telefonu prowadzący do strażnika przed murem.

Weryfikacja: nowe kontrole dostępu, pościgu, osobistej rozmowy, obwodu,
zamkniętej/otwartej nawigacji, strefy i celu telefonu; pełny test przed commitem.
Podglądy gang-brama-final.png i gang-dziedziniec-final.png w codex-podglad.
Wczesny przebieg wykrył typ numerów budynków, lampę nad trawą oraz lampę w osi
wjazdu; poprawione. Grafika wymaga dalszego szlifu w punktach 6 i 10.
Nie dodano darmowego dochodu ani kary pieniężnej za wejście. Kolejny punkt 6:
rozpoznawalna zabudowa całej mapy, potem płoty/przejścia i śmietniki.

65abb0e: pełny test 698 OK, 0 błędów. Osobna próba w rendererze potwierdza
wyłączenie rzeczywistej kolizji po przyznaniu przepustki. Naprawiono również
referencję bramy: czyszczenie kolizji zieleni zmienia indeksy blocks, dlatego
brama zachowuje własny słownik zamiast zapamiętanego indeksu.


## Budynki — podpunkt 6a: dachy i profile wejść

Kamienice nie mają już jednego dachu: deterministyczne warianty szarego dachu
z eternitu, rdzawej blachy i czterospadowego dachu w chłodnym kolorze. Kalenica
biegnie po dłuższej osi, wysokość zależy od rozpiętości w metrach gry. Niskie
warsztaty nie dostają wysokiego dachu jak czteropiętrowa kamienica. Dopasowano
wysokość kominów, dodano obrzeża płaskich dachów bloków w kolorze akcentu.
Wspólne materiały PBR mapowane w przestrzeni świata, bez rozciągania faktury
wraz z długością bryły. Wejścia dekoracyjne: betonowy daszek, pochylona blacha
na wspornikach albo szerszy ganek. Rzeczywiste drzwi i trasy zachowane.

Podglądy dachy-hutnicza.png, dachy-osiedle.png, wejscia-osiedle.png obejrzane
w /Users/macbook/codex-podglad. Pełna weryfikacja: 698 testów OK, 0 błędów.
Ujęcie lotnicze średnia jakość: 21 FPS przy 2128 draw calls; widok większości
miasta, nie porównanie wydajności ulicy. Dalszy audyt wydajności pozostaje
w punkcie 12. Punkt 6 nadal otwarty: indywidualne partery/bryły i kontrola
tekstur przy chodniku, potem punkt 7 (płoty i przejścia).


## Budynki — podpunkt 6b: partery i rozpoznawalne sylwetki

Kamienice mają trzy profile parteru wyznaczone osobno dla każdego domu: płytsze
boniowanie, malowanie z pasem nad oknami lub cokół z fugami. Podziały obliczane
w metrach świata, utrzymują rozmiar przy różnych długościach elewacji. Nie wszystkie
partery są już jednakowo przyciemniane o 26%. Zachowano widoczne zużycie i cegłę
spod tynku. Nadbudówki bloków różnią się wysokością i kolorem; klub dostał stopniowaną
attykę, komisariat poziomy gzyms. Nowe bryły mieszczą się w obrysie budynków,
nie zwężają chodników, nie blokują drzwi ani tras NPC.

Renderer: partery-hutnicza.png, bryla-klubu.png, bryla-klubu-front.png obejrzane.
Pełny test: 699 OK, 0 błędów (liczba zależy od warunkowej ścieżki dotychczasowych testów).
Punkt 6 zamknięty jako pierwszy przegląd budynków łącznie z 6a; nie oznacza perfekcji
każdego modelu. Kompletny przegląd nocy, deszczu, detali i wydajności pozostaje
w punktach 10/12. Następny konkretny blok: 7 — audyt płotów, otworów i przejść.


## Płoty i przejścia — punkt 7

Audyt wszystkich wywołań _fence_run: usunięto dodatkowe wyrwy obok istniejących
furtek w (-66,-31.6), (37,-31.6), (88,-31.6), (-48.5,123), (128.6,78),
(128.6,-40), (71,127). Pozostają 22 przejścia z 29. Zostawiono furtki,
przełazy i konieczny przełaz prologu (128.6,-90), samodzielną wyrwę od parku
oraz pojedynczą wyrwę w murze. Kolizje i geometria powstają z tych samych odcinków.
Odgięty płat siatki ma teraz rzeczywiste oczka jak płot, zamiast przezroczystej folii.

Nowe kontrole: zamknięte komórki siedmiu wyrw, dostępne furtki i pełne obejścia,
trasy telefonu. Pierwszy rozszerzony test ujawnił, że stary graf chodników potrafi
rysować odcinek przez ogrodzenie. Nav.find sprawdza teraz gotowe odcinki względem
siatki kolizji; w razie przeszkody wyznacza rzeczywiste obejście AStar.
Celowany test FENCE CHECK OK. Pełny test wymagany po ostatniej zmianie płata
siatki przed commitem. Prolog nadal przechodzi pełną dotychczasową weryfikację.

Podglądy plot-osiedle.png, plot-furtki.png, plot-garaze.png, plot-wyrwa-siatka.png
obejrzane w /Users/macbook/codex-podglad. Punkt 7 zamknięty; następny 8:
modele śmietników/krat i widok, wejście, wyjście oraz celowanie w kryjówkach.


5822ab5: 701 testów OK, 0 błędów po naprawie płotów/tras i modelu odgiętej
siatki. Dodatkowy podgląd pokazał krzak na dojściu do parkowej wyrwy. Poszerzono
czyszczenie zieleni o korytarze podejścia do istniejących przejść (z usunięciem
kolizji i kryjówek roślin jak przy budynkach). Drzewa poza korytarzem zachowane.
plot-wyrwa-dojscie.png obejrzany: ścieżka wolna, siatka ma rzeczywiste oczka.
Pełny ponowny test po korekcie zieleni zakończony pomyślnie; brak nowych błędów.
Następny blok 8 nadal aktualny.


## Śmietniki, kraty i chowanie — punkt 8

Props.trash_shed: nowy model w Godocie, pełny dach z blachy, niski beton,
stalowe słupy i prawdziwe pręty krat. Zachowano szczegółowe kontenery z Blendera,
ujednolicono kolory i osadzenie kółek na podeście według granic siatki. Wiata
nie ma już pełnego prostopadłościanu kolizji w środku: fizyka obejmuje ściany
oraz dach; siatka patrolu nadal traktuje schowek jako osobną kryjówkę.

Usunięte błędy chowania: kamera pozostawała na wysokości stojącego gracza
(gałąź hidden pomijała obniżanie), kierunek po wejściu prowadził na kontenery,
prompt pokazywał podwójne [E]. Teraz patrzysz ku wyjściu ze skulonej pozycji.
Wejście wymaga zewnętrznej lokacji i bliskości. Wyjście sprawdza rzeczywistą
fizykę kapsuły; przy przeszkodzie wybiera sąsiedni punkt. Jeśli wszystkie
punkty zastawione, gracz pozostaje schowany. Pamięć obserwującego patrolu zachowana.
Mniejsze pole przeszukiwania kontenerów (r 1.6→0.8, wysokość przy pokrywach).

Weryfikacja: dwa nowe testy pustego wnętrza i wysokości kamery; pełna seria
703 OK, 0 błędów przed końcową korektą kierunku/promptu. Wymagany pełny test
finalnego kodu przed commitem. Osobny test w rendererze SHELTER PHYSICS OK:
wejście, pozycja kamery, kapsuła, wyjście mimo przeszkody na zwykłym punkcie.
Obejrzane smietnik-przed.png / smietnik-po.png / smietnik-w-srodku.png.
Szczegółowy szlif tekstur modeli nadal w punkcie 10. Następny 9: reputacja,
kontakty i pomocnicy produkcji z kosztami oraz ograniczeniami.


8339714: pełny finalny test podstawowego bloku 8 — 703 OK, 0 błędów.
Dalsza kontrola rozdzieliła obrys nawigacji od osłony: ściany boczne/tylna
blokują LOS, pełny obrys wiąże tylko AStar (op=false). Otwarty front nie jest
już niewidzialną ścianą osłaniającą gracza, który po prostu wejdzie bez interakcji.
Nowy test otwartego frontu i osłoniętego boku przechodzi; pełny test po tej
korekcie zakończony pomyślnie. Grafika bez dalszych zmian od obejrzanego rendereru.


## Punkt 9a — lokalna reputacja i cele sieci

Reputation zapisuje wynik osobno dla dzielnic. Udana dostawa odpowiedniego towaru
(czystość co najmniej 55) daje 2–3 pkt; najwyżej 12 pkt na dobę w dzielnicy,
raz na klienta. Rozdzielanie paczki ani samo przekazanie zapasu dealerowi nie
podnosi wyniku. Hook complete_sale rejestruje reputację dopiero po rzeczywistym
zdjęciu pełnej liczby gramów z plecaka; lokacja z zamówienia lub sprzedaży ulicznej.

Progi 20/50/80: Kojarzony/Zaufany/Ustawiony; prowizja dealera w tej dzielnicy
spada o 1/2/3 punkty procentowe. Maksimum Mati 35→32%, Darek 40→37%:
przychód po prowizji rośnie najwyżej o ok. 4,6%/5%, tempo i ceny pozostają
niezmienione. Reputacja sama nie daje gotówki. Telefon Dealerzy pokazuje nazwę
terenu, reputację, skuteczną prowizję i liczbę punktów do następnego celu.
Ogłoszenia tylko przy przekroczeniu progu. Starsze zapisy zaczynają od pustego
stanu; zapis zachowuje dzienną pamięć klientów.

9 nowych kontroli: dostawa, powtórzenia, słaby/pusty towar, limit dnia, zapis,
nowy dzień, maksymalny rabat, oddzielne dzielnice i brak darmowej gotówki,
migracja. Pierwszy pełny test przeszedł; końcowy test po dopracowaniu telefonu
wymagany przed commitem. reputacja-dealerzy.png obejrzany w rendererze.
Punkt 9 pozostaje otwarty do pomocników produkcji i kontaktów. Następny blok 9b:
pomoc w garażu, własna rekrutacja i wynagrodzenie, ograniczenie do dostępnego
sprzętu oraz zasobów, jasny cel rozwoju. Nie przechodzić jeszcze do punktu 10.


d1ab651: końcowo 713 testów OK, 0 błędów; audyt telefonu Dealerzy 0 uwag
(82 kontrolki). Jeden przebieg ujawnił patrol stojący podczas przeszukiwania:
zbyt wcześnie pomijał bliski punkt zakrętu, próbował ścinać przez przeszkodę.
Teraz pomija punkt tylko przy wolnym odcinku do następnego. Pełny test po
korekcie przechodzi, w tym ruch/przeczesywanie i prolog. Następny nadal 9b:
pomocnicy; rozbudować widok reputacji także o pozostałe odwiedzone dzielnice.


## Pilna regresja: celowanie i laptop

Naprawiono wysokość kolizji we wnętrzach: add_col przenosił zapas z terenu
(h+4) na meble, stół 0,8 m był niewidzialną przeszkodą do 4 m. Wnętrza kończą
kolizję na wysokości obiektu, stół otrzymuje rzeczywistą wysokość modelu.
Interakcja ignoruje wyłącznie własny CollisionShape celu (szafa, łóżko,
meble kryjówek), nie cały wspólny StaticBody — ściany/inne meble nadal blokują.
Wybór uwzględnia trafienie środkiem celownika, zamiast wybierać pobliską wagę
podczas patrzenia na radio. Nie zwiększano promieni interakcji.

Test samouczka teraz faktycznie celuje w laptop z dwóch pozycji i naciska
interakcję, zamiast wywoływać lap.act bez celowania. Dodatkowe kontrole radia,
wagi, szafy, łóżka, własnej/innej kolizji. Osobna instancja projektu
CzarnyRynek-TestInterakcji potwierdziła LAPTOP TARGET AND DISK SAVE OK:
rzeczywisty plik JSON, pozycja i flaga zapisu poprawne. Zapis gracza nietknięty.
laptop-naprawiony.png obejrzany: prompt i potwierdzenie „Gra zapisana”.
Pełny test finalnego kodu wymagany przed commitem.
Następny priorytet użytkownika: rośliny mają być gęstsze i bardziej realistyczne,
przed kontynuacją pomocników. Wcześniejsze odhaczenie roślin oznaczało pierwszą
wersję, nie akceptację ich wyglądu przez Piotra.


## Poprawa roślin po uwagach Piotra — gęstość i oświetlenie

Trzy modele przebudowane w Blenderze. Więcej pięter i bocznych pędów,
wachlarze 5–7 szerszych, ząbkowanych listków o różnych nachyleniach; dodatkowe
liście wewnątrz korony. Mniejsze, ciemniejsze i mniej regularne kwiatostany
zamiast dużych jasnych stożków. Siatka i atlas nadal wspólne dla danego etapu.
Nie zmieniono czasu wzrostu, plonu, jakości ani kosztów produkcji.

Źródło zgłoszenia cieni: grow_lamp miała shadow_enabled=false. Zamiast
Omni dodano skierowane w dół SpotLight z cieniami (jedna mapa zamiast sześciu
na światło), lekko zmniejszony bias. Liście: per-pixel PBR, bez własnej emisji,
zachowane obustronne materiały. Mają reagować na rzeczywiste lampy, nie świecić
same. Renderer: rosliny-gestsze.png / rosliny-swiatlo.png obejrzane; porównanie
rosliny-uv-cienie.png, rosliny-uv-bez-cieni-test.png i rosliny-uv-wylaczone-test.png.
Kontrola obrazu na roślinach/podłożu: zmiana światła 0,01287, cieni 0,01651
(średnia bezwzględna różnica RGB 0..1). Podczas próby wyłączono odświeżanie
stanowisk, aby gra nie przywracała ustawień testowych co ułamek sekundy.

Pełny test finalnych zasobów i kodu: 721 OK, 0 błędów. Podgląd med 1280×720,
po 120 klatkach: 58 FPS, 104 draw calls; pomiar lokalny, nie całej gry.
Wygląd pozostaje otwarty na ocenę Piotra; nie deklarować realizmu/perfekcji
po samym headless. Priorytet naprawy interakcji i cieni wykonany.
Następny niewykonany blok: pomocnicy produkcji 9b.


## Pomocnicy 9b — Roman, płatne podlewanie

Nowy Workers + zapis workers w stanie gry. Roman z zaplecza ma menu współpracy.
Rekrutacja osobista: poziom 8, własny garaż i lampa, 20 lokalnej reputacji
Garage Row, 450 zł. Pracuje 8–20, najwyżej 2 rzeczywiste rośliny pod lampą
na godzinę; tylko potrzebujące wody, żywe i przed zbiorem. 12 zł za wizytę,
najwyżej 48 zł/dobę. Bez pracy bez opłaty. Bez gotówki nie podlewa, bez długu;
pościg/śledztwo 65+ i pauza wstrzymują pracę. Nie zmienia wzrostu, jakości,
plonu, nie sadzi/zbiera i nie tworzy towaru. Działa w kroku czasu przed uprawą,
bez reentrantnego dodawania minut. Wizyty, stan płac i umowa przechodzą zapis.

Telefon Pomocnicy: koszty/status/wizyty/liczba podlanych, wstrzymanie, trasa do
Romana i reputacja odwiedzonych dzielnic. NPC pozostaje kontaktem na zapleczu;
praca odbywa się w symulacji, nie dodano jeszcze animacji jego pracy w garażu.
13 kontroli zatrudnienia, odległości, faktycznej pielęgnacji i limitu, braku
emisji towaru, bezczynności, pauzy, pieniędzy, pościgu, płac, zapisu/migracji
oraz rozpoznania celu telefonu. Pierwszy pełny test przeszedł; końcowy test
po celu i podglądzie telefonu wymagany przed commitem.
Panel pomocnik-roman-panel.png obejrzany. Punkt 9 nadal otwarty: pomoc przy
innych rodzajach produkcji i prezentacja pracy w świecie; nie odhaczać całości.

7f2da87: końcowy pełny test 734 OK, 0 błędów. Audyt Pomocnicy: 0 uwag
(73 kontrolki). Panel zatrudnionego Romana obejrzany w rendererze.
Następny blok 9c: wsparcie pozostałej produkcji i widoczna praca pomocników.


## Płace pomocnika — uwaga Piotra i symulacja

18 wariantów po 7 dób: 2/6/10 doniczek, dwa tryby lamp, ręcznie / 12 zł / 60 zł.
Rzeczywista uprawa/zdrowie/plon, suszenie z limitem 90 g, paczki 5 g, silnik
Matiego z prowizją i przepustowością, nasiona/prąd/woreczki/płace. Bez nalotów,
zmiany popytu, zakupu wyposażenia i podróży; regularne ręczne zbiory/dowóz.
Przy 6 roślinach 18/6 stare płace 252 zł/tydzień i wynik 7426,40 zł; nowe
1260 zł/tydzień i wynik 6418,40 zł. Przy 2/10 roślinach nowy wynik 2338,60/5722 zł.
CSV w SYMULACJA-PRACOWNIKA.csv, szczegóły i ograniczenia w EKONOMIA-SIECI.md.

Roman teraz 60 zł za potrzebną wizytę, limit 240 zł/dobę i 4 wizyty, bez zmiany
rekrutacji 450 zł. Aktualizacja panelu, dialogu i SMS-a. Dzienny licznik wizyt
chroni stare umowy: wykorzystane wizyty rozpoznawane po starej stawce, bez dopłaty
za przeszłość, od nowej doby normalny limit. Testy płac dostosowane; nowy test
migracji mieszanej doby. Symulacja ujawniła ograniczenie wydajności przy większej
farmie: helper nie zastępuje całej obsługi, a niesprzedany plon nie jest gotówką.
Pełny test przed commitem; audyt panelu. Następne nadal 9c / pełny balans 12.


## 9c — widoczna praca Romana

Opłacona wizyta zapisuje czas i prawdziwy punkt pielęgnacji. WorkerVisual pokazuje
Romana w garażu przez 16 minut gry: ta sama postać co kontakt na zapleczu,
animmacja doglądania na kolanach, konewka obok. Wybiera wolny punkt przy roślinie
na podstawie rzeczywistej fizyki, z odstępem od gracza; przy braku miejsca nie
pokazuje modelu w ścianie. Kontakt na zapleczu w tym czasie znika — bez duplikacji.
Wizualizacja nie wywołuje pielęgnacji ani płac. Starsze umowy bez nowego zdarzenia
pozostają poprawne. Wspólne zasoby postaci, model tworzony dopiero, gdy potrzebny.

Pełny test: 735 OK, 0 błędów. Osobny tools/worker_visual_check.gd uruchamia
rzeczywistą płatną wizytę i sprawdza: koszt 60 zł raz, model widoczny, miejsce
mieści kapsułę, kolejne klatki nie naliczają opłat/wizyt, wygaśnięcie chowa model.
WORKER VISUAL CHECK OK. Pose Fixing_Kneeling; głowa w sprawdzonym momencie
na ok. 0,83 m zamiast pozycji stojącej. Na potrzeby eksportu zamrożono skinned
mesh z rzeczywistych macierzy kości (samo przestawienie rest deformowało postać).
Blender: roman-praca-blender.png obejrzany — klęczy i dogląda roślin, bez modelu
w bryle mebla. To podgląd geometrii/pozy, nie kontrola identycznego światła Godota.

Próba tools/wolne.sh wykazała działającą sesję gracza (PID 41329); nie otwierano
nowego okna ani nie przerywano gry. Natywny podgląd pozostaje do sprawdzenia przy
wolnej sesji; nie deklarować perfekcji na podstawie samego headless/Blendera.
Następny blok 9d: pomoc przy laboratorium i pozostałej produkcji, koszty i symulacja.
