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
