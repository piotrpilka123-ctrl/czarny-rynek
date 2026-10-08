# Czarny Rynek — porównanie i kierunek rozbudowy

Wniosek z przeglądu projektu: potrzebna jest wyraźna droga od samodzielnych dostaw
do zarządzania własnym interesem. Rozszerzona mapa ma dawać nowe możliwości i ryzyko,
a rozwój ma uwalniać gracza od powtarzalnej pracy.

## Co wynika z materiałów twórców

[Schedule I — opis twórców](https://store.steampowered.com/app/3164500/Schedule_I/):
rozbudowa lokali i zatrudnianie pracowników oraz sprzedawców pozwalają skalować produkcję
i dystrybucję; miasto, wyposażenie i konkurencja dają dalsze cele.

[Drug Dealer Simulator — opis twórców](https://store.steampowered.com/app/682990/Drug_Dealer_Simulator/):
rozwój od małej kryjówki do kontroli terenu, współpraca z gangami, pracownicy laboratoriów
oraz inwestowanie w wyposażenie i nieruchomości tworzą długą pętlę postępu.

To porównanie mechanik, nie kopia map, modeli, dialogów ani konkretnych receptur tych gier.
Poniższe oceny są moim przeglądem kodu Czarnego Rynku i propozycjami dla tego projektu.

## Co już działa i czego brakuje

| Obszar | Aktualna gra | Rozbudowa |
|---|---|---|
| Początek | Prolog, pierwsze zamówienie, pakowanie, awanse | Krótkie wskazówki uczące planowania wyprawy i ryzyka |
| Dostawy | Osobne SMS-y, spotkania, trasy | Jedna lista pokazująca zapas, braki i konieczność przepakowania |
| Skala interesu | Własna produkcja i skup u Wiktora | Własni sprzedawcy, ich zapas, prowizje i fizyczny odbiór pieniędzy |
| Teren | Dzielnice i lokalna uwaga policji | Reputacja dzielnicy, kontrolowane wejścia, interesy z gangiem |
| Wydawanie zarobku | Kryjówki, ubrania, sprzęt | Cele na większy interes: pracownicy, transport, kolejne lokale |
| Świat | Cykl dnia, pogoda, chodzący mieszkańcy | Rozpoznawalne miejsca i sytuacje zależne od rozwoju gracza |
| Sterowanie | Duże pola interakcji | Mniejsze cele, sprawdzanie przeszkód, czytelne wejścia do kryjówek |

## Kolejność wdrażania

1. Dokładniejsze interakcje i uczciwe chowanie: poprawić fundament sterowania.
2. „Dostawy” w telefonie: całe paczki rezerwowane według terminu; brak podwójnego
   liczenia tej samej paczki; nie oznaczać zbyt słabego towaru jako gotowego.
3. Nowy teren za garażami, jezioro z brzegiami oraz osobne osiedle gangu.
   Osiedle: zauważalne ostrzeżenie i kontrolowane wejście na początku; dostęp zależny
   od postępów i kontaktów. Bez niewidocznych ścian udających niebezpieczeństwo.
4. Śmietniki i ich kraty: wspólny styl modeli, sensowne wejście, wnętrze i wyjście;
   redukcja nadmiarowych dziur w płotach. Budynki rozpoznawalne po bryle i parterze.
5. Sieć sprzedawców i reputacja: przekazujesz faktyczny zapas, sprzedaż zajmuje czas,
   pieniądze odbierasz osobiście. Rozwój ma koszt i ograniczenia, nie darmowy dochód.
6. Pomocnicy produkcji i dalsze cele: dopiero po własnym laboratorium; koszty,
   dostęp do sprzętu i zapasu. Następnie transport i późniejsze umowy z gangiem.

## Reguły wdrożenia

Nie kasować istniejących zapisów ani nie zmieniać indeksów fabuły bez migracji.
Zmiany ekonomii sprawdzać symulacją. Weryfikować wygląd w rendererze, a nie wyłącznie
headless. Nie dodawać realistycznych instrukcji chemicznych — to mechaniki fikcyjnej gry.
