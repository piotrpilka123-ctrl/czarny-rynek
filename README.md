# Czarny Rynek

Aktualna wersja gry Piotra Piłki w Godocie 4: symulator z widokiem pierwszoosobowym, osadzony w fikcyjnym polskim mieście.

## Uruchomienie

- **macOS:** zainstaluj Godot 4.7 i otwórz `Uruchom Czarny Rynek.command`. Skrypt oczekuje Godota w `/Applications/Godot.app`.
- **Windows:** rozpakuj całe archiwum gry. Zainstaluj lub rozpakuj Godot 4.7.2 do folderu `Godot` obok projektu (paczka Windows zawiera go już w tym folderze). Kliknij `Uruchom Czarny Rynek.bat`. Domyślnie używa trybu zgodności OpenGL, sprawdzonego na Intel Iris Xe. Skrypt wyszukuje tez Godota w Pobranych i w PATH. Ten sam tryb uruchamia `Uruchom zgodnosc Windows.bat`. Logi: `import-windows.log` i `gra-windows.log`. Mozesz tez zaimportowac `godot/project.godot` w edytorze Godot 4.7 i nacisnac **F5**.
- **Linux:** zaimportuj `godot/project.godot` w Godocie 4.7 i nacisnij **F5**.

Pierwsze uruchomienie wymaga importu modeli i tekstur, dlatego trwa dłużej. To projekt gry; Godot jest potrzebny do jego uruchomienia.

## Sterowanie

WASD — ruch, mysz — rozglądanie, E — interakcja. Gra pokazuje pozostałe klawisze podczas samouczka. F11 przełącza pełny ekran.

## Towary

Sześć towarów w grze (wszystko fikcyjne): marihuana, amfetamina, metamfetamina, kokaina oraz dwa własnej produkcji.

- **Grzybki** (ok. 110 zł/g, od poziomu 4): szafa grzybowa kupiona w hurtowni i grzybnia ze sklepu Stasia. Kupują artyści z ogródków działkowych „Hutnik” (Tosia, Pan Zdzisław).
- **Ecstasy** (ok. 140 zł/g, od poziomu 6): stół laboratoryjny i dwa zestawy chemikaliów. Kupują ludzie z Neonu i afterów na zapleczu Repair Yard (Kaja, Bogdan z bramki).

Nowe miejsca spotkań i skrytek: ogródki działkowe oraz zaplecze Repair Yard. Każdy nowy klient ma też swoją rozmowę telefoniczną, która dopisuje kolejny kawałek historii o tym, kto sprzedał ekipę Wiktora.

## Pliki

`godot/` zawiera kod, scenę, modele, tekstury, animacje, muzykę i dźwięki aktualnej gry. Zapis gry jest przechowywany w danych użytkownika Godota, poza repozytorium.

Własną muzykę można umieścić w `godot/muzyka/` zgodnie z tamtejszą instrukcją. Nie jest przesyłana na GitHuba.

Autorzy i licencje zasobów: [LICENCJE.md](LICENCJE.md).
