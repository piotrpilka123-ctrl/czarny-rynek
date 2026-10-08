#!/bin/bash
# Bezpiecznik przed zrzutami z oknem: zwraca 0 tylko wtedy, gdy NIE działa żadna gra uruchomiona z projektu
# (edytor i przebiegi --headless się nie liczą). Użycie: ./tools/wolne.sh && Godot --path . ...
# liczy się tylko proces, którego programem jest sam Godot — powłoka z poleceniem zawierającym jego ścieżkę to nie gra
out=$(ps -axo pid=,command= | /usr/bin/grep -E "^ *[0-9]+ [^ ]*Godot .*--path" | /usr/bin/grep -v -- "--headless" | /usr/bin/grep -v "grep")
if [ -n "$out" ]; then
	echo "GRA DZIAŁA — bez okien:"
	echo "$out" | cut -c1-160
	exit 1
fi
exit 0
