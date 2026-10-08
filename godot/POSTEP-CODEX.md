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

## Aktualny blok

- inventory.gd: demonstracja 6 etapów nad właściwym wierszem przedmiotu,
  wizualizacja przytrzymanego LPM; demonstracyjne potwierdzenie nie zmienia ekwipunku.
- Prawdziwe okno ilości dostało „Wszystko”; notes wymaga potwierdzenia.
- Do ukończenia: pełny test, audyt układu, wizualna kontrola etapów, lokalny commit.

## Następne bloki

1. Obejrzeć nawierzchnie w prawdziwym rendererze i poprawić powtarzalność/kolor/połysk
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
