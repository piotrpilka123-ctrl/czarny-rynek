#!/bin/sh
# przegląd układu okien bez rysowania: ./tools/uiaudit.sh [nazwa…]  (nazwy jak w --ui=; bez nazw — wszystkie)
# RES=1280x800 liczy układ dla innych proporcji ekranu; LISTA=1 wypisuje wszystkie napisy okna z pozycjami, FRAMES=n czeka dłużej, N=n więcej wierszy
DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$*"
[ -z "$LIST" ] && LIST="home sms chat chat_nego chat_time chat_swap chat_ok sklep gielda2 kontakty mapa portfel rozwoj zadania lokale plecak ustawienia options options_audio options_keys controls pause bench station0 hideout stash inv gear invsel invask char wear org shop build skill property deal skrzynka wagi paczka ziemia hurtownia"
for n in $LIST; do
  /Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path "$DIR" -- --autostart --test --uiaudit="$n" ${LISTA:+--uitekst} ${FRAMES:+--frames=$FRAMES} ${RES:+--res=$RES} 2>&1 | grep -E "^UI|SCRIPT ERROR|Invalid|rror:" | grep -v "RID\|leaked\|still in use" | head -${N:-14}
done
