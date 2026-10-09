# Ekonomia produkcji i dealerów

Punkt startowy balansu: większe partie zachowują dawny koszt surowców na gram.
Koszt poniżej nie obejmuje prądu, sprzętu, strat, czasu ani prowizji.

| Partia | Sloty | Koszt wsadu | Wydajność bazowa | Koszt/g | Czas bazowy |
|---|---:|---:|---:|---:|---:|
| Amfetamina | 1 | 1600 zł | 72 g | 22,22 zł | 8 h gry |
| Metamfetamina | 2 | 4800 zł | 60 g | 80 zł | 14 h gry |
| Kokaina | 3 | 10800 zł | 90 g | 120 zł | 22 h gry |

Wszystkie nowe pakiety są abstrakcyjnymi zasobami gry. Nie przedstawiają rzeczywistych receptur.

Mati: poziom 4, rozpoczęcie współpracy 250 zł, zapas 40 g, do 4 g/h, prowizja 35%.
Darek: poziom 8, rozpoczęcie 900 zł, zapas 80 g, do 1 g/h, prowizja 40%.
Wymagane wcześniejsze 6 transakcji i 30 sprzedanych gramów. Sprzedają w godzinach 8–23,
bez zapasu nie zarabiają, przy śledztwie 65+ przeczekują. Jakość wpływa na przychód.
Przekazanie paczek i odbiór rozliczenia wymagają spotkania w świecie.

Maksymalne tempo nie jest gwarancją dobowego dochodu: trzeba dokładać zapas, poczekać
na godziny pracy i ponieść koszty produkcji oraz ryzyko przewożenia towaru. Bez dealerów
bezpośrednia sprzedaż nadal ma lepszą marżę. Dealer daje czas, nie darmowy towar.

Do kontroli po pierwszym bloku: symulacja kampanii i oddzielna kontrola sieci przy
regularnym zaopatrywaniu. Nie ogłaszać ostatecznego balansu po samym sprawdzeniu wzorów.


Audyt jednej partii przez istniejący system dealerów (7 dni, regularny dowóz):

| Produkt | Sprzedana partia | Koniec sprzedaży | Wynik po wsadzie, woreczkach i rekrutacji |
|---|---:|---:|---:|
| Amfetamina | 72 g | dzień 2 | +784 zł |
| Metamfetamina | 60 g | dzień 5 | +864 zł |
| Kokaina | 90 g | dzień 7 | +5520 zł |

To wariant bez prądu, sprzętu, podróży i wpadek; nie jest gwarantowanym zyskiem gracza.
Narzędzie: `godot/tools/dealer_balance.gd` uruchamiane headless z Dummy audio.
Symulacja dotychczasowej kampanii przy dwóch botach dała wspólnika w dniach 19 i 23,
ale bez produkcji i sieci dealerów — mierzy więc tylko ścieżkę bezpośrednich dostaw.


Lokalna reputacja (9a): rabat prowizji maksymalnie 3 punkty procentowe, po
80 pkt w terenie dealera. Mati: udział gracza 65→68% (+4,62% dochodu);
Darek: 60→63% (+5%). Ceny, zapas i tempo nie wzrastają. Wynik za rzeczywiste
dostawy, limit 12/dobę i raz na klienta, bez punktów za ponowne przekładanie
zapasu dealerów. Nie jest to nowa emisja pieniędzy, tylko mniejsza prowizja.


Roman (9b), po symulacji: 450 zł rekrutacji, 60 zł za obchód z potrzebnym podlewaniem,
limit czterech wizyt / 240 zł na dobę. Do dwóch istniejących roślin na godzinę;
bez gotówki nie pracuje, nie tworzy długu. Nie podnosi tempa, jakości ani
plonu. Oszczędza czynności gracza i zapobiega zaniedbaniu, zużywając pieniądze.
Zbiory pozostają ręczne. Rozszerzenie pomocy na laboratorium wymaga osobnego balansu.


## Symulacja wynagrodzenia Romana — 7 dób, 18 wariantów

Narzędzie godot/tools/worker_balance.gd używa rzeczywistego wzrostu, wody,
zdrowia, prognozy plonu/czystości i sprzedaży Matiego. 2/6/10 doniczek,
tryby lamp 18/6 i 24/0, pielęgnacja ręczna lub pracownik przy 12/60 zł za wizytę.
Sprzedaż przez Matiego: prowizja 35%, zapas 40 g, tempo 4 g/h w godzinach 8–23.
Suszenie 8 h, pojedyncza suszarka do 90 g, paczki po 5 g. Koszty nasion,
woreczków, energii i płac; cena marihuany 50 zł/g przy popycie 1.

| Doniczki, 18/6 | Płace 12 zł / tydzień | Płace 60 zł / tydzień | Wynik przy 12 zł | Wynik przy 60 zł |
|---|---:|---:|---:|---:|
| 2 | 96 zł | 480 zł | 2722,60 zł | 2338,60 zł |
| 6 | 252 zł | 1260 zł | 7426,40 zł | 6418,40 zł |
| 10 | 324 zł | 1620 zł | 7018,00 zł | 5722,00 zł |

Wynik to zrealizowany przepływ pieniędzy po kosztach operacyjnych. Nie wycenia
niesprzedanego zapasu, plonów w suszeniu ani roślin w trakcie wzrostu. Nie obejmuje
zakupu garażu/sprzętu, rekrutacji (dodatkowo 450 zł za Romana i 250 zł za Matiego),
podróży, nalotów ani zmiennego popytu. Zakłada regularny ręczny zbiór/sadzenie,
suszenie/pakowanie i dowóz do dealera. To kontrolowany test, nie gwarancja zysku.

Wniosek: 12 zł daje marginalny koszt delegowania. 60 zł zabiera ok. 17–22%
wyniku pracownika przed płacami w tych scenariuszach, pozostawiając dodatnią marżę.
Wdrażamy 60 zł za potrzebną wizytę, maks. 4 / 240 zł dziennie. Brak pracy = brak
opłaty. Migracja starych umów zachowuje wykorzystane wizyty i nie nalicza dopłat
wstecz. Większa uprawa wymaga dodatkowego doglądania: przy 10 roślinach w 18/6
przy pielęgnacji samym pomocnikiem uzyskano 424 g zamiast 600 g przy pełnej pielęgnacji,
a dealer sprzedał tylko 268 g — nie traktować całego plonu jako gotówki.
Pełne wyniki: SYMULACJA-PRACOWNIKA.csv.


## Igor — asystent laboratorium (9d)

1800 zł rekrutacji, 120 zł za przejęty etap, maks. 2 czynności / 240 zł na dobę.
Dyżur 24 h, sprawdzanie co godzinę, etap czeka minimum 8 minut; pomocnik nie
przyspiesza pracy względem gracza. Start, wsad i odbiór należą do właściciela.
Brak pracy/gotówki, pauza lub pościg = brak opłaty i obsługi. Limit wymusza
własną obsługę większej liczby stanowisk; nie jest pełną automatyzacją linii.

Symulacja 6 wariantów, jedna rzeczywista partia + sprzedaż przez Matiego/Darka.
Tryb produkcji normalny, zdrowie 100%, surowce faktycznie zużywane, plon/czystość
liczone przez Prod, sprzedaż ograniczona tempem, zapasem i prowizją dealerów.

| Partia | Ręcznie | Z Igorem | Płace | Czas ręcznie / Igor |
|---|---:|---:|---:|---:|
| Amfetamina 72 g, 80% | 1070 zł | 950 zł | 120 zł | 8,17 / 8,33 h |
| Metamfetamina 60 g, 80% | 1824 zł | 1584 zł | 240 zł | 14,33 / 15,33 h |
| Kokaina 90 g, 85% | 6600 zł | 6360 zł | 240 zł | 22,50 / 23,33 h |

Wynik po wsadzie, woreczkach i płacach; bez prądu, sprzętu, rekrutacji, podróży,
nalotów i zmiany popytu. To nie ta sama symulacja co wcześniejszy audyt gotowych
partii: tutaj produkcja wylicza rzeczywistą czystość. Igor nie zwiększa plonu,
powoduje opóźnienie do godzinnej kontroli i koszt. CSV: SYMULACJA-ASYSTENTA-LAB.csv;
narzędzie tools/lab_staff_balance.gd. Zmniejszenie liczby ręcznych etapów to
korzyść, nie emisja darmowych pieniędzy ani gwarancja końcowego balansu.
