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

## Aktualny blok

- npc.gd: kontekstowe kwestie pogody/pory dnia/pościgu, brak natychmiastowego
  powtarzania tej samej kwestii. Własne kwestie stałych mieszkańców wracają co drugą rozmowę.
- Przechodnie przy widocznym pościgu (LOS, do 14 m) przestają stać, przyspieszają
  na 5 sekund i na kolejnym skrzyżowaniu wybierają istniejącą ścieżkę oddalającą
  od gracza. Sprawdzanie LOS najwyżej raz na sekundę na pobliskiego przechodnia.
- Ostatnie polecenie Piotra: dodać własne pomysły, żeby gra i dzielnica bardziej żyły.
- Do ukończenia: pełny test i commit tego bloku. Potem sprawdzić reakcje w rendererze,
  następnie pogłębiać harmonogramy mieszkańców i drobne sytuacje uliczne.

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
