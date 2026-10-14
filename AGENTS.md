# Wspólne zasady pracy — Codex i Claude

Nad grą pracują na zmianę Codex i Claude. Obaj czytają ten plik (Codex: AGENTS.md, Claude: CLAUDE.md → tutaj).

## Jedna wersja gry

- Jedyna kopia robocza: `/Users/macbook/czarny-rynek`, gałąź `main`. Gra: `godot/`.
- Nie twórz worktree, klonów, kopii folderu, gałęzi „archiwum/kopia/aktualna-gra-…” ani zapasowych plików `*.bak`. Historię trzyma git — to jest kopia zapasowa.
- Zrzuty, logi i podglądy tylko w katalogu tymczasowym (`$TMPDIR` / scratchpad), nie w `/Users/macbook/…` obok projektu.
- `godot/tools/` jest w `.gitignore` (nie trafia na GitHuba), ale jest potrzebne do pracy — dlatego worktree i klony nie działają poprawnie.

## Kto teraz pracuje

- Przed pierwszą edycją: `./tools/zajmij.sh "Codex: krótko co robię"` (albo „Claude: …”), z katalogu `godot/`. Jeśli skrypt odmawia, bo drugi agent ma zajęte — nie edytuj plików, poczekaj albo zajmij się czymś tylko do odczytu.
- Po commicie i zakończeniu bloku pracy: `./tools/zwolnij.sh`. Blokada starsza niż 2 godziny jest uznawana za porzuconą.
- `tools/commit.sh` robi `git add -A` — dlatego dwa agenty nie mogą edytować jednocześnie.

## Porządek

- Na początku: `git status` (ma być czysto) i `git log --oneline -5` — zobacz, co zrobił drugi agent.
- Małe commity przez `./tools/commit.sh "Komunikat po polsku w trybie rozkazującym"` (testy przechodzą albo nie ma commitu). Autor commitów: noreply GitHuba, nigdy prywatny e-mail.
- Postęp i listy zadań: `NOCNA-LISTA-CODEX.md` (wspólna lista — odhaczaj tam, nie zakładaj nowych list).
- `git push` tylko na wyraźne polecenie Piotra. Przed pushem `git fetch` i scalenie `origin/main` do `main` (bez force).

## Zasady Piotra (skrót)

- Po polsku. Dźwięk w testach wyciszony (`--audio-driver Dummy`).
- Okno gry tylko gdy `./tools/wolne.sh` zwraca 0 (Piotr nie gra). Nie zamykaj jego edytora Godota.
- Tylko zasoby CC0/własne; pobieranie czegokolwiek wymaga jego zgody. Czerń w modelach nigdy idealnie czarna.
- UI: małe, płaskie, monochromatyczne, mało tekstu. Napis „A test game by Piotr Piłka” zostaje.
