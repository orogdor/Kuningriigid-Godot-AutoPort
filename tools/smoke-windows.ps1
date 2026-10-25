$ErrorActionPreference = "Stop"
$repo = "orogdor/Kuningriigid-Godot-AutoPort"
$root = Join-Path $env:RUNNER_TEMP "AutoPortWindowsSmoke"
$download = Join-Path $root "download"
$env:KUNINGRIIGID_HOME = Join-Path $root "Kuningriigid-Data"
$env:KUNINGRIIGID_VERIFY_ONLY = "1"
New-Item -ItemType Directory -Force $download | Out-Null

Write-Host "Downloading small Windows launcher from latest GitHub release..."
gh release download --repo $repo --pattern "Kuningriigid.exe" --dir $download --clobber
if ($LASTEXITCODE -ne 0) { throw "Could not fetch launcher release" }
$exe = Join-Path $download "Kuningriigid.exe"
$size = (Get-Item $exe).Length
if ($size -gt 15000000 -or $size -lt 500000) { throw "Expected small native EXE; size=$size" }

function Start-And-Wait-Launcher {
    param ([switch]$Offline)
    if ($Offline) {
        # A failed GitHub request must not prevent launching a verified cached game.
        $env:HTTPS_PROXY = "http://127.0.0.1:9"
        $env:HTTP_PROXY = "http://127.0.0.1:9"
        $env:ALL_PROXY = "http://127.0.0.1:9"
        $env:NO_PROXY = ""
    }
    try {
        $p = Start-Process -FilePath $exe -WorkingDirectory $download -PassThru
        if (-not $p.WaitForExit(240000)) {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            throw "Launcher timed out"
        }
        if ($p.ExitCode -ne 0) {
            $errfile = Join-Path $env:KUNINGRIIGID_HOME "last-error.txt"
            if (Test-Path $errfile) { throw "Launcher error: $(Get-Content $errfile -Raw)" }
            throw "Launcher exit code $($p.ExitCode)"
        }
    } finally {
        if ($Offline) {
            Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
            Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
            Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
            Remove-Item Env:NO_PROXY -ErrorAction SilentlyContinue
        }
    }
}
function Kill-Test-Engine {
    Get-Process "Godot" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Write-Host "FIRST LAUNCH: native downloader fetches separate Godot runtime and individual game files"
Start-And-Wait-Launcher
Start-Sleep -Seconds 3
Kill-Test-Engine

# Every first install must visibly advance the update percentage to 100%.
$progressLog = Join-Path $env:KUNINGRIIGID_HOME "last-update-progress.log"
if (-not (Test-Path $progressLog)) { throw "Missing UPDATE progress tracking log" }
$progressText = Get-Content $progressLog -Raw
if (-not ($progressText -match '0% UPDATE' -and $progressText -match '100% UPDATE')) {
    throw "Expected UPDATE progress from 0% to 100%; got $progressText"
}
Write-Host "UPDATE PROGRESS OK: percentage from 0 to 100"

$stateFile = Join-Path $env:KUNINGRIIGID_HOME "active.json"
if (-not (Test-Path $stateFile)) { throw "Missing installed version state" }
$state = Get-Content $stateFile -Raw | ConvertFrom-Json
$game = Join-Path $env:KUNINGRIIGID_HOME "versions\$($state.commit)\game"
$engine = Join-Path $env:KUNINGRIIGID_HOME "runtime\$($state.engine_sha256)\Godot.exe"

foreach ($path in @(
    $engine,
    (Join-Path $game "project.godot"),
    (Join-Path $game "main.tscn"),
    (Join-Path $game "content.tscn"),
    (Join-Path $game "scripts\logic_v02.gd"),
    (Join-Path $game "data\generated\manifest.json")
)) {
    if (-not (Test-Path $path)) { throw "Missing separated game file: $path" }
}

Write-Host "RUNNING INSTALLED GODOT PROJECT IN HEADLESS MODE"
$p = Start-Process -FilePath $engine -ArgumentList @("--headless", "--path", $game, "--editor", "--quit") -PassThru -Wait
if ($p.ExitCode -ne 0) { throw "Installed Godot project import failed with exit code $($p.ExitCode)" }
$p = Start-Process -FilePath $engine -ArgumentList @("--headless", "--path", $game, "--quit-after", "3") -PassThru -Wait
if ($p.ExitCode -ne 0) { throw "Installed Godot content failed with exit code $($p.ExitCode)" }

# Prevent an old cached 0.3 rules-inspector from being mistaken for 0.5.
$contentScript = Get-Content (Join-Path $game "scripts/content.gd") -Raw
if ($contentScript -notmatch 'GODOT 0\.5' -or $contentScript -notmatch 'Linnamajandus') {
    throw "Installed project is not the AutoPort 0.5 city economy scene"
}
Write-Host "GODOT 0.5 CONTENT VERIFIED: city economy scene"

$count = (Get-ChildItem -Path $game -Recurse -File | Measure-Object).Count
if ($count -lt 20) { throw "Expected game directory with many distinct files; found $count" }
Write-Host "EXTRACTED GAME OK: $count separate files"

Write-Host "OFFLINE RELAUNCH: updater must open cached installed version"
Start-And-Wait-Launcher -Offline
Start-Sleep -Seconds 2
Kill-Test-Engine
$offlineText = Get-Content $progressLog -Raw
if (-not ($offlineText -match '0% UPDATE' -and $offlineText -match '100% UPDATE')) {
    throw "Cached/offline startup did not complete update progress"
}
Write-Host "WINDOWS BOOTSTRAP TEST SUCCESS: 0.5 content, update progress, first install and offline startup"