#!/bin/sh
# Uruchamia grę „Czarny Rynek” (wymaga programu Godot 4 w folderze Programy).
DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
if [ ! -x "$GODOT" ]; then
  echo "Nie znalazłem Godota w /Applications/Godot.app — pobierz go z https://godotengine.org/download/macos/"
  read -r _
  exit 1
fi
# po świeżym pobraniu z GitHuba Godot musi raz zaimportować modele i tekstury
if [ ! -d "$DIR/godot/.godot/imported" ]; then
  echo "Pierwsze uruchomienie: importuję zasoby gry (to potrwa 1–3 minuty)…"
  # Import bez urządzenia GPU: backend zgodności działa również na świeżej kopii.
  if ! "$GODOT" --headless --rendering-method gl_compatibility --path "$DIR/godot" --import > /dev/null 2>&1; then
    echo "Import zasobów nie powiódł się. Otwórz godot/project.godot w edytorze Godota."
    read -r _
    exit 1
  fi
fi
exec "$GODOT" --path "$DIR/godot" "$@"
