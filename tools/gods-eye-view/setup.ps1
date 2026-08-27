<#
.SYNOPSIS
    Richtet God's Eye View (https://github.com/bilawalsidhu/gods-eye-view) auf
    einem Windows-PC ein und startet den lokalen Dev-Server.

.DESCRIPTION
    Prueft Git und die Node-Version, klont bzw. aktualisiert das Repository,
    legt die .env aus .env.example an, fragt den (einzigen) Pflicht-Key
    GOOGLE_MAPS_API_KEY ab, installiert die Abhaengigkeiten und startet
    "npm run dev". Der Dev-Server bindet bewusst nur an localhost.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1 -InstallDir D:\apps\gev -Port 5173
#>
[CmdletBinding()]
param(
    # Zielordner fuer den Klon. Default: %USERPROFILE%\gods-eye-view
    [string]$InstallDir = "",
    # Port des Dev-Servers.
    [int]$Port = 4173,
    # Nur einrichten, nicht starten.
    [switch]$SetupOnly,
    # node_modules loeschen und neu installieren.
    [switch]$Reinstall,
    # Node-Versionspruefung ueberspringen (auf eigenes Risiko).
    [switch]$SkipNodeCheck,
    # Browser nicht automatisch oeffnen.
    [switch]$NoBrowser,
    # Keine Rueckfragen stellen (fuer automatisierte Laeufe).
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
# PowerShell 7.4+ laesst native Kommandos bei ErrorActionPreference='Stop' werfen.
# Dieses Skript wertet $LASTEXITCODE selbst aus, also abschalten wenn vorhanden.
if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$RepoUrl = 'https://github.com/bilawalsidhu/gods-eye-view.git'
$KeyPlaceholder = 'your_google_maps_api_key_here'

function Write-Step  { param([string]$Message) Write-Host "[SETUP] $Message" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Message) Write-Host "[OK]    $Message" -ForegroundColor Green }
function Write-Warn2 { param([string]$Message) Write-Host "[HINW]  $Message" -ForegroundColor Yellow }
function Write-Err2  { param([string]$Message) Write-Host "[FEHLER] $Message" -ForegroundColor Red }

function Stop-Setup {
    param([string]$Message)
    Write-Err2 $Message
    exit 1
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# --- Banner ------------------------------------------------------------------
Write-Host ""
Write-Host "===================================================" -ForegroundColor DarkCyan
Write-Host "   God's Eye View - lokales Setup" -ForegroundColor DarkCyan
Write-Host "===================================================" -ForegroundColor DarkCyan
Write-Host ""

# --- Zielordner --------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = Join-Path $env:USERPROFILE 'gods-eye-view'
}
Write-Step "Zielordner: $InstallDir"

# --- Git ---------------------------------------------------------------------
if (-not (Test-Command 'git')) {
    Write-Err2 "Git wurde nicht gefunden."
    Write-Host "  Installieren mit:  winget install --id Git.Git -e" -ForegroundColor Gray
    Write-Host "  Oder herunterladen: https://git-scm.com/download/win" -ForegroundColor Gray
    Write-Host "  Danach ein NEUES Terminal oeffnen (PATH wird sonst nicht uebernommen)." -ForegroundColor Gray
    exit 1
}
Write-Ok "Git gefunden: $((git --version) 2>&1)"

# --- Node --------------------------------------------------------------------
if (-not (Test-Command 'node')) {
    Write-Err2 "Node.js wurde nicht gefunden."
    Write-Host "  Installieren mit:  winget install --id OpenJS.NodeJS.LTS -e" -ForegroundColor Gray
    Write-Host "  Oder herunterladen: https://nodejs.org/ (LTS 24.x)" -ForegroundColor Gray
    Write-Host "  Danach ein NEUES Terminal oeffnen." -ForegroundColor Gray
    exit 1
}

$nodeRaw = (& node --version) 2>&1
$nodeOk = $false
if ($nodeRaw -match '^v(\d+)\.(\d+)\.(\d+)') {
    $nodeMajor = [int]$Matches[1]
    $nodeMinor = [int]$Matches[2]
    # package.json des Projekts verlangt: >=24.14.0 <25 || >=26 <27
    if ($nodeMajor -eq 24 -and $nodeMinor -ge 14) { $nodeOk = $true }
    if ($nodeMajor -eq 26) { $nodeOk = $true }
}

if ($nodeOk) {
    Write-Ok "Node-Version passt: $nodeRaw"
} elseif ($SkipNodeCheck) {
    Write-Warn2 "Node $nodeRaw entspricht nicht der geforderten Version (24.14+ oder 26.x)."
    Write-Warn2 "Weiter wegen -SkipNodeCheck. Unerwartete Fehler sind moeglich."
} else {
    Write-Err2 "Node $nodeRaw wird vom Projekt nicht unterstuetzt."
    Write-Host "  Gefordert (package.json): >=24.14.0 <25 || >=26 <27" -ForegroundColor Gray
    Write-Host "  Empfohlen: Node 24 LTS" -ForegroundColor Gray
    Write-Host "  winget install --id OpenJS.NodeJS.LTS -e" -ForegroundColor Gray
    Write-Host "  Mehrere Versionen parallel: https://github.com/coreybutler/nvm-windows" -ForegroundColor Gray
    Write-Host "    nvm install 24" -ForegroundColor Gray
    Write-Host "    nvm use 24" -ForegroundColor Gray
    Write-Host "  Trotzdem versuchen: setup.ps1 -SkipNodeCheck" -ForegroundColor Gray
    exit 1
}

if (-not (Test-Command 'npm')) {
    Write-Err2 "npm wurde nicht gefunden, obwohl Node vorhanden ist."
    Write-Host "  Node.js neu installieren, npm gehoert zum Lieferumfang." -ForegroundColor Gray
    Write-Host "  Bei nvm-windows hilft meist: nvm use 24" -ForegroundColor Gray
    exit 1
}

# --- Repository klonen / aktualisieren ---------------------------------------
if (Test-Path (Join-Path $InstallDir '.git')) {
    Write-Step "Repository gefunden, hole Updates ..."
    $pullFailed = $false
    try {
        & git -C $InstallDir pull --ff-only
        if ($LASTEXITCODE -ne 0) { $pullFailed = $true }
    } catch {
        $pullFailed = $true
    }
    if ($pullFailed) {
        Write-Warn2 "git pull fehlgeschlagen (lokale Aenderungen?). Bestehender Stand wird verwendet."
    } else {
        Write-Ok "Repository aktuell."
    }
} elseif ((Test-Path $InstallDir) -and (Get-ChildItem -Force $InstallDir | Select-Object -First 1)) {
    Stop-Setup "Ordner '$InstallDir' existiert, ist aber kein Git-Repository und nicht leer. Anderen -InstallDir waehlen."
} else {
    Write-Step "Klone $RepoUrl ..."
    & git clone $RepoUrl $InstallDir
    if ($LASTEXITCODE -ne 0) { Stop-Setup "git clone fehlgeschlagen." }
    Write-Ok "Repository geklont."
}

Set-Location $InstallDir

# --- .env --------------------------------------------------------------------
$envPath = Join-Path $InstallDir '.env'
$envExamplePath = Join-Path $InstallDir '.env.example'

if (-not (Test-Path $envPath)) {
    if (-not (Test-Path $envExamplePath)) { Stop-Setup ".env.example fehlt im Repository." }
    Copy-Item $envExamplePath $envPath
    Write-Ok ".env aus .env.example angelegt."
}

# .env ohne BOM schreiben - ein BOM wuerde den ersten Variablennamen zerstoeren.
function Save-EnvLines {
    param([string]$Path, [string[]]$Lines)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $utf8NoBom)
}

function Get-EnvValue {
    param([string[]]$Lines, [string]$Name)
    foreach ($line in $Lines) {
        if ($line -match "^\s*$([regex]::Escape($Name))\s*=\s*(.*)$") {
            return $Matches[1].Trim()
        }
    }
    return ""
}

function Set-EnvValue {
    param([string[]]$Lines, [string]$Name, [string]$Value)
    $found = $false
    $out = @()
    foreach ($line in $Lines) {
        if ($line -match "^\s*$([regex]::Escape($Name))\s*=") {
            $out += "$Name=$Value"
            $found = $true
        } else {
            $out += $line
        }
    }
    if (-not $found) { $out += "$Name=$Value" }
    return $out
}

$envLines = @(Get-Content -LiteralPath $envPath -Encoding UTF8)
$googleKey = Get-EnvValue -Lines $envLines -Name 'GOOGLE_MAPS_API_KEY'

if ([string]::IsNullOrWhiteSpace($googleKey) -or $googleKey -eq $KeyPlaceholder) {
    Write-Host ""
    Write-Warn2 "GOOGLE_MAPS_API_KEY fehlt - er liefert den fotorealistischen 3D-Globus."
    Write-Host "  Key holen: https://console.cloud.google.com/  (Map Tiles API aktivieren)" -ForegroundColor Gray
    Write-Host "  Kostenpflichtig/metered: Key einschraenken und ein Budget-Limit setzen." -ForegroundColor Gray
    if (-not $NonInteractive) {
        $entered = Read-Host "  Key jetzt einfuegen (Enter = spaeter nachtragen)"
        if (-not [string]::IsNullOrWhiteSpace($entered)) {
            $envLines = Set-EnvValue -Lines $envLines -Name 'GOOGLE_MAPS_API_KEY' -Value $entered.Trim()
            Save-EnvLines -Path $envPath -Lines $envLines
            Write-Ok "Key in .env gespeichert."
        } else {
            Write-Warn2 "Ohne Key startet die App, der 3D-Globus bleibt aber leer."
            Write-Warn2 "Nachtragen in: $envPath"
        }
    }
} else {
    Write-Ok "GOOGLE_MAPS_API_KEY ist gesetzt."
}

# OpenSky ohne Zugangsdaten: anonymer Modus haelt die Flug-Ebene am Leben.
$envLines = @(Get-Content -LiteralPath $envPath -Encoding UTF8)
$openSkyId = Get-EnvValue -Lines $envLines -Name 'OPENSKY_CLIENT_ID'
$openSkyMode = Get-EnvValue -Lines $envLines -Name 'OPENSKY_AUTH_MODE'
if ([string]::IsNullOrWhiteSpace($openSkyId) -and $openSkyMode -eq 'oauth') {
    $envLines = Set-EnvValue -Lines $envLines -Name 'OPENSKY_AUTH_MODE' -Value 'anon'
    Save-EnvLines -Path $envPath -Lines $envLines
    Write-Ok "OPENSKY_AUTH_MODE=anon gesetzt (keine OpenSky-Zugangsdaten hinterlegt)."
}

# --- Abhaengigkeiten ---------------------------------------------------------
$nodeModules = Join-Path $InstallDir 'node_modules'
if ($Reinstall -and (Test-Path $nodeModules)) {
    Write-Step "Entferne node_modules ..."
    Remove-Item -Recurse -Force $nodeModules
}

if (-not (Test-Path $nodeModules)) {
    Write-Step "Installiere Abhaengigkeiten (dauert beim ersten Mal einige Minuten) ..."
    & npm.cmd install
    if ($LASTEXITCODE -ne 0) { Stop-Setup "npm install fehlgeschlagen." }
    Write-Ok "Abhaengigkeiten installiert."
} else {
    Write-Ok "node_modules vorhanden (Neuinstallation mit -Reinstall)."
}

if ($SetupOnly) {
    Write-Host ""
    Write-Ok "Setup abgeschlossen. Start mit: npm run dev -- --host localhost --port $Port"
    exit 0
}

# --- Start -------------------------------------------------------------------
$url = "http://localhost:$Port/"
Write-Host ""
Write-Step "Starte Dev-Server auf $url"
Write-Host "  Beenden mit Strg+C." -ForegroundColor Gray
Write-Host "  Der Server ist nur von diesem PC erreichbar (localhost)." -ForegroundColor Gray
Write-Host ""

if (-not $NoBrowser) {
    $null = Start-Job -ScriptBlock {
        param($target)
        $deadline = (Get-Date).AddSeconds(180)
        while ((Get-Date) -lt $deadline) {
            try {
                $response = Invoke-WebRequest -Uri $target -UseBasicParsing -TimeoutSec 3
                if ($response.StatusCode -eq 200) {
                    Start-Process $target
                    return
                }
            } catch {
                Start-Sleep -Seconds 1
            }
        }
    } -ArgumentList $url
}

& npm.cmd run dev -- --host localhost --port $Port
