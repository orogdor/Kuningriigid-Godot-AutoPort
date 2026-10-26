$ErrorActionPreference = "Stop"
$repo = "orogdor/Kuningriigid-Godot-AutoPort"
$root = Join-Path $env:RUNNER_TEMP "AutoPortWindowsSmoke"
$download = Join-Path $root "download"
$env:KUNINGRIIGID_HOME = Join-Path $root "Kuningriigid-Data"
$env:KUNINGRIIGID_VERIFY_ONLY = "1"
New-Item -ItemType Directory -Force $download | Out-Null

# A workflow_run may start its check-only sibling before a release exists.
# Test the *specific* successful build, not a stale --latest release.
$releaseTag = $env:KUNINGRIIGID_SMOKE_RELEASE_TAG
if ($env:GITHUB_EVENT_NAME -eq "workflow_run") {
    $event = Get-Content $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json
    $parentId = [int64]$event.workflow_run.id
    $parentNumber = [int]$event.workflow_run.run_number
    $runs = gh api "repos/$repo/actions/runs/$parentId/jobs" | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect triggering build $parentId" }
    $successfulBuilds = @($runs.jobs | Where-Object { $_.name -eq "build" -and $_.conclusion -eq "success" })
    if ($successfulBuilds.Count -eq 0) {
        Write-Host "SKIP: triggering workflow $parentId was check-only; no new APK/EXE was published"
        exit 0
    }
    $localConfig = Get-Content "game/project.godot" -Raw
    if ($localConfig -notmatch 'AutoPort 0\.(\d+)') {
        throw "Missing current version in game/project.godot"
    }
    $releaseTag = "v0.$($Matches[1]).$parentNumber"
}
if ($releaseTag) {
    Write-Host "Downloading exact Windows launcher release $releaseTag..."
    gh release download $releaseTag --repo $repo --pattern "Kuningriigid.exe" --dir $download --clobber
} else {
    Write-Host "Downloading small Windows launcher from latest GitHub release..."
    gh release download --repo $repo --pattern "Kuningriigid.exe" --dir $download --clobber
}
if ($LASTEXITCODE -ne 0) { throw "Could not fetch launcher release $releaseTag" }
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

# Do not pin the launcher smoke test to AutoPort 0.17: this used to
# falsely fail every modern release even after a successful installed boot.
$contentScript = Get-Content (Join-Path $game "scripts/content.gd") -Raw
$projectScript = Get-Content (Join-Path $game "project.godot") -Raw
if ($contentScript -notmatch 'GODOT 0\.(\d+)') {
    throw "Installed city version identifier is missing from scripts/content.gd"
}
$installedMinor = [int]$Matches[1]
if ($installedMinor -lt 33 -or $contentScript -notmatch 'Linnamajandus') {
    throw "Installed AutoPort release content is incomplete: found 0.$installedMinor, expected 0.33+"
}
if ($projectScript -notmatch "AutoPort 0\.$installedMinor") {
    throw "Installed project.godot version does not match scripts/content.gd (0.$installedMinor)"
}
if ($releaseTag -and -not $releaseTag.StartsWith("v0.$installedMinor.")) {
    throw "Installed 0.$installedMinor is not the requested test release $releaseTag"
}
foreach ($part in @("scripts/world_trade_routes_v17.gd", "scripts/two_city_trade_v15.gd", "scripts/freight_v14.gd", "scripts/construction_scheduler_v13.gd", "scripts/construction_v12.gd", "scripts/construction_v11.gd", "scripts/spatial_paths_v09.gd", "scripts/detail_terrain_v10.gd", "scripts/spatial_economy_v08.gd", "scripts/detail_view_v07.gd")) {
    if (-not (Test-Path (Join-Path $game $part))) {
        throw "Missing 0.13 deployed game source: $part"
    }
}
Write-Host "GODOT 0.$installedMinor CONTENT VERIFIED: current city and packaged project versions agree"

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
Write-Host "WINDOWS BOOTSTRAP TEST SUCCESS: current 0.$installedMinor content, update progress, first install and offline startup"