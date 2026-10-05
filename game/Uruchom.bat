@echo off
cd /d "%~dp0"
echo Uruchamiam Czarny Rynek...
where py >nul 2>nul
if %errorlevel%==0 (
  py serve.py 8765
) else (
  python serve.py 8765
)
echo.
echo Jesli gra sie nie uruchomila, zainstaluj Pythona z python.org albo otworz plik index.html w przegladarce.
pause
