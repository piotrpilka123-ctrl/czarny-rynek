# Czarny Rynek — lista pracy do „stop”

Lista obejmuje polecenia Piotra z tego czatu. Praca trwa przez kolejne bloki i wznowienia
co 30 minut, także przez noc. Na „stop”/„stoo” wyłączyć automatyzację. Po ukończeniu
listy dopracowywać grę własnymi pomysłami. Nie pushować bez polecenia.

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
2. [ ] Produkcja: amfetamina 1 slot składnika, meta 2, kokaina 3. Większe partie
       odpowiednie dla dealerów, realny koszt w grze, czas i ryzyko. Fikcyjne pakiety
       procesowe, bez rzeczywistych instrukcji chemicznych. Symulacja marży i tempa.
3. [ ] Rozszerzyć teren za garażami z sensownym dojściem i funkcją w rozgrywce.
4. [ ] Jezioro/brzeg, otoczenie, ścieżki; granice terenu i nawigacja muszą pasować.
5. [ ] Osiedle gangu: odrębne budynki, kontrolowane wejście, ostrzeżenie i ryzyko
       na początku; późniejszy dostęp zależny od postępu/kontaktów.
6. [ ] Budynki: różnice brył, parterów, dachów, wejść i detali, spójna skala tekstur.
7. [ ] Płoty/przejścia: przegląd całej mapy, usunąć nadmiarowe i bezsensowne otwory;
       sensowne furtki i przełazy, bez psucia prologu i tras NPC.
8. [ ] Śmietniki i kraty: własne spójne modele, wejście, widok ze środka, bezpieczne
       wychodzenie i czytelne celowanie. Kontrola chowania przy obserwującym patrolu.
9. [ ] Lokalna reputacja i kontakty, kolejne cele, pomocnicy produkcji; ograniczenia
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


Doprecyzowanie produkcji przez Piotra: także laboratorium ma mieć dobre interakcyjne
systemy jak uprawa (widoczne składniki, czynności i animacje). Poprawić jakość roślin,
sadzenie i cały system uprawy; to część punktów 2 i 10, nie usuwać z kolejki.


Blok 319d3d2: dealerzy i podstawowe 1–3 sloty wsadu, 664 testy OK.
Panel Dealerzy i sloty obejrzane w rendererze; audyt układu 0 uwag.
Punkt 2 pozostaje otwarty do czynności i animacji w świecie oraz poprawy roślin.
Osobny audyt jednej partii dealerów i opis ograniczeń w EKONOMIA-SIECI.md.


Podpunkt 2a [x]: menu laboratorium w świecie + animacje i jednokrotne skutki czynności
(2692af9, aa8e909; 674 testy). Podpunkt 2b [ ]: lepsze rośliny, sadzenie i uprawa.
Końcowe dopracowanie światła laboratorium i podgląd zakończone: f2a57be, 673 testy OK. Nie odhaczać całego punktu 2
przed poprawą roślin oraz sprawdzeniem wyniku.
