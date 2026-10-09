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
