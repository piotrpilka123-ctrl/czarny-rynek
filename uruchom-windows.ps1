param([string]$GodotPath, [switch]$Compatibility)
$ErrorActionPreference = 'Stop'
try {
    $project = Join-Path $PSScriptRoot 'godot'
    if (-not $GodotPath) { $GodotPath = $env:GODOT_EXE }
    if (-not $GodotPath) {
        $command = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $GodotPath = $command.Source }
    }
    if (-not $GodotPath) {
        $folders = @($PSScriptRoot, (Join-Path $PSScriptRoot 'Godot'), (Join-Path $env:USERPROFILE 'Downloads'))
        $candidates = foreach ($folder in $folders) {
            if (Test-Path -LiteralPath $folder) {
                Get-ChildItem -LiteralPath $folder -Filter 'Godot_v4*.exe' -File
                Get-ChildItem -LiteralPath $folder -Directory -Filter 'Godot_v4*' | ForEach-Object {
                    Get-ChildItem -LiteralPath $_.FullName -Filter 'Godot_v4*.exe' -File
                }
            }
        }
        $selected = $candidates | Sort-Object @{Expression={$_.Name -match '_console'};Descending=$true}, @{Expression={$_.Name};Descending=$true} | Select-Object -First 1
        if ($selected) { $GodotPath = $selected.FullName }
    }
    if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        throw 'Nie znaleziono Godota. Rozpakuj Godot 4.7.2 do folderu Godot obok tego skryptu lub podaj -GodotPath "C:\sciezka\Godot.exe".'
    }
    $version = & $GodotPath --version
    if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '^4\.(7|[89]|[1-9][0-9])\.') {
        throw "Projekt wymaga Godota 4.7 lub nowszego z serii 4. Znaleziona wersja: $version"
    }
    Write-Host 'Importowanie zasobow. Pierwsze uruchomienie moze potrwac kilka minut.'
    $importLog = Join-Path $PSScriptRoot 'import-windows.log'
    & $GodotPath --headless --rendering-method gl_compatibility --path $project --import *> $importLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR:|ERROR: (Failed to import|Error importing|Failed loading resource)' -Quiet)) {
        throw "Import nie powiodl sie. Szczegoly: $importLog"
    }
    $gameArgs = @('--path', $project, '--log-file', (Join-Path $PSScriptRoot 'gra-windows.log'))
    if ($Compatibility) { $gameArgs += @('--rendering-method', 'gl_compatibility') }
    & $GodotPath @gameArgs
    if ($LASTEXITCODE -ne 0) { throw 'Gra zakonczyla sie bledem. Sprawdz gra-windows.log. Przy problemach ze sterownikiem uzyj trybu zgodnosci.' }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
