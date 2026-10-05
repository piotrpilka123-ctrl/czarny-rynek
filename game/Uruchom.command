#!/bin/bash
# Dwuklik uruchamia grę: startuje lokalny serwer i otwiera przeglądarkę.
cd "$(dirname "$0")"
echo "Uruchamiam Czarny Rynek..."
exec python3 serve.py 8765
