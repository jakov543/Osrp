# OSRP server setup (Windows) - downloads the official FXServer and puts OSRP in it.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root      = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo      = Split-Path -Parent $root
$base      = Join-Path $root 'OSRP-Server'
$artifacts = Join-Path $base 'artifacts'
$data      = Join-Path $base 'server-data'
$res       = Join-Path $data 'resources'

function Step($t) { Write-Host "`n>> $t" -ForegroundColor Cyan }

Write-Host '=========================================' -ForegroundColor Green
Write-Host '   OSRP | Osijek Roleplay - server setup' -ForegroundColor Green
Write-Host '=========================================' -ForegroundColor Green

New-Item -ItemType Directory -Force -Path $artifacts, $res | Out-Null

# 1. FXServer (official Cfx.re server, recommended build)
if (-not (Test-Path (Join-Path $artifacts 'FXServer.exe'))) {
    Step 'Preuzimam FXServer (sluzbeni server)...'
    $zip = Join-Path $base 'server.7z'
    $url = $null
    try {
        $info = Invoke-RestMethod 'https://changelogs-live.fivem.net/api/changelog/versions/win32/server'
        $url = $info.recommended_download
        if (-not $url) { $url = $info.latest_download }
    } catch { }
    if (-not $url) {
        Write-Host 'Nisam mogao automatski naci verziju.' -ForegroundColor Yellow
        Write-Host 'Otvaram stranicu: skini "LATEST RECOMMENDED" server.7z u mapu:' -ForegroundColor Yellow
        Write-Host "  $base" -ForegroundColor Yellow
        Start-Process 'https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/'
        Read-Host 'Kad je server.7z u toj mapi, pritisni Enter'
    } else {
        Invoke-WebRequest $url -OutFile $zip
    }
    if (-not (Test-Path $zip)) { throw 'server.7z nije pronaden.' }

    Step 'Raspakiravam...'
    $sevenZip = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($sevenZip) { & $sevenZip x $zip "-o$artifacts" -y | Out-Null }
    else { tar -xf $zip -C $artifacts }
    if (-not (Test-Path (Join-Path $artifacts 'FXServer.exe'))) {
        throw 'Raspakiravanje nije uspjelo. Instaliraj 7-Zip (7-zip.org, besplatno) i pokreni setup ponovno.'
    }
    Remove-Item $zip -Force
} else { Step 'FXServer vec postoji - preskacem.' }

# 2. Base resources (chat, sessionmanager, hardcap) from the official cfx-server-data
if (-not (Test-Path -LiteralPath (Join-Path $res '[system]'))) {
    Step 'Preuzimam osnovne resurse (chat, sessionmanager)...'
    $tmp = Join-Path $base 'cfx-server-data.zip'
    Invoke-WebRequest 'https://github.com/citizenfx/cfx-server-data/archive/refs/heads/master.zip' -OutFile $tmp
    $ex = Join-Path $base 'cfx-tmp'
    Expand-Archive $tmp -DestinationPath $ex -Force
    Copy-Item (Join-Path $ex 'cfx-server-data-master\resources\*') $res -Recurse -Force
    Remove-Item $tmp, $ex -Recurse -Force
}

# 3. OSRP resources (always refreshed from this repo)
Step 'Kopiram OSRP resurse...'
$osrp = Join-Path $res '[osrp]'
[IO.Directory]::CreateDirectory($osrp) | Out-Null
Copy-Item -Path (Join-Path $repo 'fivem-resources\*') -Destination $osrp -Recurse -Force

# 4. server.cfg + license key
$cfg = Join-Path $data 'server.cfg'
if (-not (Test-Path $cfg)) {
    Step 'Postavljam server.cfg'
    Write-Host 'Treba ti BESPLATNI server kljuc:' -ForegroundColor Yellow
    Write-Host '  1. Otvori https://portal.cfx.re  (prijava s FiveM/Cfx racunom)'
    Write-Host '  2. Server Keys -> Generate -> IP: tvoj IP (ili 127.0.0.1 za test)'
    Write-Host '  3. Kopiraj kljuc (pocinje s cfxk_)'
    Start-Process 'https://portal.cfx.re/servers/registration-keys'
    $key = ''
    while ($key -notmatch '^cfxk_') { $key = (Read-Host 'Zalijepi kljuc ovdje').Trim() }
    $text = [IO.File]::ReadAllText((Join-Path $root 'server.cfg.template')).Replace('__LICENSE_KEY__', $key)
    [IO.File]::WriteAllText($cfg, $text, (New-Object System.Text.UTF8Encoding($false)))
} else { Step 'server.cfg vec postoji - ostavljam tvoj.' }

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host '  GOTOVO! Pokreni start-server.bat' -ForegroundColor Green
Write-Host '  Zatim u launcheru: Postavke -> Server = 127.0.0.1:30120' -ForegroundColor Green
Write-Host '=========================================' -ForegroundColor Green
