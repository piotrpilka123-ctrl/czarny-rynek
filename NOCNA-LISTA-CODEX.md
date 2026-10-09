# Czarny Rynek — lista pracy do „stop”

Lista obejmuje polecenia Piotra z tego czatu. Praca trwa przez kolejne bloki i wznowienia
co 30 minut, także przez noc. Na „stop”/„stoo” wyłączyć automatyzację. Po ukończeniu
listy dopracowywać grę własnymi pomysłami. Nie pushować bez polecenia.

## Pilne poprawki zgłoszone przez Piotra

Najnowsze polecenia — przed dalszym ogólnym audytem:
- [x] Poprawić toalety: model ceramiczny z wnętrzem misy, deską, pokrywą i zbiornikiem; obejrzany w Godocie.
- [x] Poprawić wiszące narzędzia garażu: przestrzenne klucze, piła, młotek, śrubokręty i kombinerki z Blendera.
- [x] Cienie w pokoju początkowym, w tym krzesła: lampka rzuca cienie, skorygowana odległość cienia od powierzchni; porównanie renderów ON/OFF.
- [x] Sprawdzić brakujące kolizje płotków/doniczek wskazanych jako „potki”.
- [x] Poprawić tekstury schodów.
- [x] Bardziej imprezowa muzyka w budynkach; klub słyszany przez ściany ma być stłumiony i trochę cichszy.
- [x] Rozbudować klub: neonowy korytarz, osobne łazienki, górny balkon i trzy loże z działającymi schodami oraz balustradami. Domyślna muzyka klubowa gotowa. 769 testów i natywne podglądy; dalsze strojenie po graniu pozostaje w audycie.
- [ ] Rozbudować lokale do kupienia o więcej pomieszczeń; zachować wyposażenie i zapis gracza.
- [ ] Dealerami stają się duzi klienci, którzy sami proponują współpracę; początkowo nie ma dealerów na ulicy. Zachować istniejące kontrakty/zapas/pieniądze.
- [ ] Dodać złomowisko na mapie (interpretacja „do mamy” z kontekstu mapy).
- [ ] Rozszerzyć miejsca spotkań klientów, aby nie wracali stale w te same punkty.


- [x] Naprawić rzeczywiste celowanie w laptop i pozostałe przedmioty; zapis z celownika.
- [x] Rośliny: ponowna poprawa, gęstsze liście i realistyczniejsza sylwetka — dotychczasowy wygląd nie został zaakceptowany.

## Wykonane

- [x] Odczyt rozmowy Claude, projektu i dawnych list; dostęp do Godota i Blendera.
- [x] Cheat +1000 zł bez uruchamiania skrótów, aktualizacja widocznej gotówki.
- [x] Pokaz kliknięcia, trzymania LPM, przeciągnięcia, puszczenia i potwierdzenia „Wszystko”.
- [x] Pierwsze spotkanie: godzina, miejsce, oczekiwanie, objaśnienie czasu gry.
- [x] Pierwszy blok nawierzchni: trawa, suche/mokre podłoże, zlicowane studzienki.
- [x] Reakcje mieszkańców na pogodę, noc i widoczny pościg.
- [x] Odgłosy imprezy w prologu (muzyka zachowana), patrole omijające przeszkody,
      etapowe znaczniki ucieczki. 639 testów + sprawdzenie patroli.
- [x] Pustaki: model z porowatego betonu i otwartymi komorami z Blendera.
- [x] Mniejsze pola interakcji, blokowanie przeszkodami, pamięć policji po opuszczeniu kryjówki.
- [x] Porównanie Schedule I i DDS; PLAN-ROZGRYWKI.md; aplikacja Dostawy. 647 testów.

## Do wykonania po kolei

1. [x] Dealerzy: rekrutacja, przekazanie rzeczywistych paczek, powolna sprzedaż,
       prowizja, zapas i fizyczny odbiór gotówki; zapis stanu, samouczek, panel telefonu.
2. [x] Produkcja: amfetamina 1 slot składnika, meta 2, kokaina 3. Większe partie
       odpowiednie dla dealerów, realny koszt w grze, czas i ryzyko. Fikcyjne pakiety
       procesowe, bez rzeczywistych instrukcji chemicznych. Symulacja marży i tempa.
3. [x] Rozszerzyć teren za garażami z sensownym dojściem i funkcją w rozgrywce.
4. [x] Jezioro/brzeg, otoczenie, ścieżki; granice terenu i nawigacja muszą pasować.
5. [x] Osiedle gangu: odrębne budynki, kontrolowane wejście, ostrzeżenie i ryzyko
       na początku; późniejszy dostęp zależny od postępu/kontaktów.
6. [x] Budynki: różnice brył, parterów, dachów, wejść i detali, spójna skala tekstur.
7. [x] Płoty/przejścia: przegląd całej mapy, usunąć nadmiarowe i bezsensowne otwory;
       sensowne furtki i przełazy, bez psucia prologu i tras NPC.
8. [x] Śmietniki i kraty: własne spójne modele, wejście, widok ze środka, bezpieczne
       wychodzenie i czytelne celowanie. Kontrola chowania przy obserwującym patrolu.
9. [x] Lokalna reputacja i kontakty, kolejne cele, pomocnicy produkcji; ograniczenia
       i wydatki zamiast darmowego dochodu.
10. [ ] Pełny przegląd grafiki: wszystkie modele/tekstury, dzień/noc/deszcz, wnętrza,
        telefon i interfejs; usuwać przenikanie, powtórzenia, nadmierną czerń i rozciągnięcia.
11. [ ] Pełny przegląd początku i samouczka z nowymi mechanikami; zachęta do rozwoju,
        krótkie wskazówki, bez zatrzymywania świata przez telefon.
12. [ ] Balans całości, symulacja ekonomii, kontrola wydajności i ponowna kontrola zapisów.

## Zasada ukończenia bloku

Rzeczywista zmiana → odpowiednia weryfikacja → pełny pomyślny test → lokalny commit
→ aktualizacja POSTEP-CODEX.md i tej listy. Grafika wymaga obejrzenia renderu.
Testy bez dźwięku. Przed oknem tools/wolne.sh. Krótkie odczyty i raporty oszczędzają
tokeny; nie zastępują testów ani pracy. „Idealnie” traktować jako kierunek iteracji,
nie deklarować perfekcji po samym teście headless.

Preferencja Piotra: używać Graphify do odnajdywania zależności i powiązanych testów,
aby ograniczać odczyty kodu. 2026-10-09: lokalny manifest wtyczki obecny, lecz brak
aktywnych narzędzi Graphify w sesji; indeks projektu niepotwierdzony. Po połączeniu
sprawdzić indeks i jego aktualność, pobierać krótkie wyniki, potwierdzać je w kodzie.
Do tego czasu: celowe rg, krótkie fragmenty plików i aktualne notatki postępu.


Doprecyzowanie produkcji przez Piotra: także laboratorium ma mieć dobre interakcyjne
systemy jak uprawa (widoczne składniki, czynności i animacje). Poprawić jakość roślin,
sadzenie i cały system uprawy; to część punktów 2 i 10, nie usuwać z kolejki.


Blok 319d3d2: dealerzy i podstawowe 1–3 sloty wsadu, 664 testy OK.
Panel Dealerzy i sloty obejrzane w rendererze; audyt układu 0 uwag.
Punkt 2 pozostaje otwarty do czynności i animacji w świecie oraz poprawy roślin.
Osobny audyt jednej partii dealerów i opis ograniczeń w EKONOMIA-SIECI.md.


Podpunkt 2a [x]: menu laboratorium w świecie + animacje i jednokrotne skutki czynności
(2692af9, aa8e909; 674 testy). Podpunkt 2b [x]: lepsze rośliny, sadzenie i uprawa (57a3dcb).
Końcowe dopracowanie światła laboratorium i podgląd zakończone: f2a57be, 673 testy OK. Nie odhaczać całego punktu 2
przed poprawą roślin oraz sprawdzeniem wyniku.


57a3dcb: trzy modele roślin z Blendera (wspólne siatki/tekstury, gałązki, liście,
kwiatostany, cienie); po sadzeniu widoczne nasiono, liście dopiero po wykiełkowaniu.
Drobne cząstki ziemi zamiast dużych płaskich fragmentów. Prognoza informuje o kiełkowaniu.
676 testów OK. Podgląd etapów w Blenderze i uprawy w rendererze obejrzane;
960×540, jakość średnia: ok. 59 FPS w krótkim podglądzie, nie gwarancja całej rozgrywki.
Teraz punkt 3: rzeczywiste rozszerzenie mapy za garażami, następnie jezioro i osiedle gangu.


49a71c6: południowy teren poszerzony o 78 jednostek planu (43,68 m w grze).
Zaplecze z warsztatami, placem, przejściem, ławką, koszami, detalami i Romanem.
Przesunięto południową granicę, tło i kolizje; zsynchronizowano limit ruchu, mapę
oraz nawigację. Nowe połączenia tras są obliczane po kolizjach.
683 testy OK, w tym ruch poza starą granicą, dojście, połączenia i szczelność granicy.
Renderer zaplecza obejrzany. Naprawiono również wybór celu dealer_* w cur_target.
Następny punkt: 4 — jezioro z brzegiem. Miejsce na południowym zapleczu,
orientacyjnie centrum (90,217), promienie ok. (31,19) w jednostkach planu;
nie zalewać istniejącej furtki (83,193), zabudowy ani połączeń drogi.


Punkt 4: 4fb65d5, 4deb777, 3682ef4 — jezioro, brzeg, ścieżki, cel telefonu,
Józek, brodzenie i ochrona starej pozycji zapisu. Nawigacja omija głęboką wodę.
689 testów OK, ostateczny podgląd jezioro-odbicia.png obejrzany w rendererze.
Naturalność otoczenia można dalej szlifować w punkcie 10. Następny punkt 5: osiedle gangu.

Punkt 5: Black Court na południowym zapleczu; dwie odrębne kamienice/bloki,
zabudowanie gospodarcze, mur z jedną bramą, Borys i strażnik. Dostęp: poziom 7
i ranga Dealer u Wiktora; podczas pościgu odmowa. Fizyczna brama, kolizja,
LOS i nawigacja synchronizowane z zapisywaną przepustką. Podglądy bramy
i dziedzińca obejrzane. Następny punkt 6: odrębność zabudowy całej mapy.

Podpunkt 6a [x]: trzy warianty dachów kamienic (różny profil, kolor i kierunek
kalenicy), wysokość połaci dopasowana do szerokości; obramowania dachów bloków
w kolorze elewacji, trzy profile daszków wejściowych. 698 testów OK, renderer
Hutniczej, osiedla i wejścia obejrzany. Punkt 6 pozostaje otwarty: partery,
kształty wyróżniających się budynków i kontrola skali tekstur z poziomu ulicy.

Podpunkt 6b [x]: różne partery kamienic (boniowanie, malowanie, kamienny cokół),
zróżnicowane nadbudówki bloków i sylwetki klubu/komisariatu. Skala podziałów
w metrach świata, ulica Hutnicza i klub obejrzane w rendererze. 699 testów OK.
Blok 6 zamknięty w zakresie pierwszego przeglądu; dalsza kontrola każdego miejsca,
nocy/deszczu i przenikania pozostaje w punkcie 10. Następny punkt 7: płoty/przejścia.

Punkt 7: siedem zbędnych wyrw zamkniętych (pod wiaduktem, przy klubie,
nasypie i garażach). Pozostają 22 przejścia z 29; furtki i przełazy prologu
zachowane. Odgięta siatka ma oczka zamiast prostokąta przypominającego folię.
Nawigacja telefonu sprawdza gotową trasę i omija kolizje przez siatkę AStar.
Nowe testy zamknięć, dojść przez furtki i tras telefonu; pełny test przed commitem.
Następny punkt 8: śmietniki, kraty i chowanie.

Punkt 8: nowa spójna wiata z pełnym dachem, prawdziwymi kratami i pustym
wnętrzem w fizyce. Kontenery ustawione kółkami na podeście, mniejsze pole
przeszukiwania. Kamera przy chowaniu rzeczywiście kuca i patrzy na wyjście,
bez podwójnego [E]. Wejście tylko z bliska na zewnątrz, wyjście wybiera wolny
punkt albo czeka na zwolnienie przejścia. Pamięć policji zachowana. Dalszy szlif
samych kontenerów/tekstur w pełnym audycie grafiki (10). Następny punkt 9.

Podpunkt 9a [x]: lokalna reputacja za rzeczywiste dostawy; dzienny limit,
pamięć klientów i zapis. Progi 20/50/80 dają lokalnej sieci rabat prowizji
1/2/3 punkty procentowe. Telefon pokazuje dzielnicę, stan i następny cel.
Punkt 9 nadal otwarty: pomocnicy produkcji, ich kontakty, koszty i kolejne cele.

Pilne poprawki: fd64cbd naprawa celowania/zapisu, 721 testów OK i zapis
na dysk w izolowanej instancji. Kolejna wersja roślin: gęstsze korony, boczne
pędy, szersze liście, mniejsze kwiatostany; lampy uprawowe z rzeczywistymi
cieniami, materiały liści reagują na światło. Renderer porównany światło/cienie
włączone i wyłączone; nie jest to deklaracja perfekcji ani akceptacja przez Piotra.
Po nowych uwagach użytkownika wrócić do tych modeli. Następne: pomocnicy 9b.

Podpunkt 9b [x]: Roman — pierwszy płatny pomocnik uprawy w garażu. Rekrutacja
osobiście przy zapleczu: poziom 8, własny garaż, lampa, reputacja Garage Row 20,
450 zł. Podlewa do 2 potrzebujących roślin/godz., 8–20; 60 zł za wizytę,
limit 240 zł/dobę. Brak pracy = brak opłaty; bez gotówki/pościg/wstrzymanie
nie pracuje. Telefon Pomocnicy: stan, koszty, pauza, trasa, reputacja innych dzielnic.
Punkt 9 nadal otwarty: pomoc przy pozostałej produkcji i prezentacja pracy w świecie.

Uwagi Piotra do płac: przeprowadzono 18 wariantów / 7 dób na silniku gry;
stawka Romana 12→60 zł, limit 48→240 zł/dobę, nadal maks. 4 wizyty.
CSV i metodologia w EKONOMIA-SIECI.md; ochrona starych umów przed dopłatą wstecz.

Podpunkt 9c [x]: Roman widoczny podczas opłaconej wizyty przy roślinach w garażu,
poza wizytą wraca do kontaktu na zapleczu; animacja klęczącego doglądania i konewka.
Bez dodatkowego podlewania/opłat z animacji. Wybiera wolne miejsce, nie pojawia się
w kolizji. Weryfikacja silnika i render Blender bez okna, bo sesja gracza działała.
Pozostaje kontrola w natywnym rendererze przy wolnej sesji; następny 9d — pomoc
przy innych rodzajach produkcji, z kosztami i symulacją.

Podpunkt 9d [x]: Igor w Black Court, odpłatne doglądanie zatrzymanych etapów
laboratorium w garażu. Rekrutacja 1800 zł, poziom 10, przepustka, 50 reputacji
Garage Row i stanowisko. 120 zł za rzeczywiście wykonany etap, maks. 2/dobę;
bez wsadu/startowania/odbioru partii, bez darmowego podnoszenia jakości.
6 wariantów symulacji: po płacach nadal dodatnia marża, nie zwiększa plonu i tempa.
745 testów OK, audyt Pomocnicy 0 uwag. Pierwsza wersja punktu 9 zamknięta;
przegląd wizualny kontaktów i pracy w natywnym rendererze pozostaje w punkcie 10.

Graphify: bezpośredni MCP graphify działa po logowaniu CLI. Indeks GitHuba
9676160 wskazuje starszy game/js/interiors.js (buildClub), nie aktualny Godot.
Nie powtarzać zapytań do nieaktualnego grafu przy każdym bloku; użyć go ponownie
po potwierdzonej aktualizacji indeksu lub wdrożeniu właściwego lokalnego indeksu.
Nie pushować tylko w celu odświeżenia Graphify. Oszczędności tokenów nie zmierzono.
