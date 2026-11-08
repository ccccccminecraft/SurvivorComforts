# Starts the game with Steam, using the development data folder
# %USERPROFILE%\PZDev (or $env:PZ_DEV_DIR) instead of %USERPROFILE%\Zomboid,
# for trying the mod and uploading it to the Workshop.
#
# The mod is copied there first (deploy.ps1) and turned on in the main menu's
# mod list. Saves, options and the log (console.txt) are kept in that folder,
# so the everyday game, which uses the Steam Workshop copy of the mod, is not
# touched (docs\dev-guide.md, "開発用のフォルダ"). Steam must be running.
#
#   powershell -File tools\dev_game.ps1              copy the mod and start the game
#   powershell -File tools\dev_game.ps1 -Debug       start it in debug mode
#   powershell -File tools\dev_game.ps1 -SetupOnly   only copy the mod and write the launch file
#   powershell -File tools\dev_game.ps1 -Alpha       the alpha mod, Survivor Comforts (Alpha),
#                                                    instead of the stable one (deploy.ps1 -Alpha)
#
# The launch file is also written to <PZDev>\dev.cmd, to start it again by hand.

param(
    [string]$GameDir = $env:PZ_GAME_DIR,
    [switch]$Debug,
    [switch]$SetupOnly,
    [switch]$Alpha
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "GameDir.ps1")
$GameDir = Resolve-GameDir $GameDir

$ModId = if ($Alpha) { "SurvivorComfortsAlpha" } else { "SurvivorComforts" }
$Root = if ($env:PZ_DEV_DIR) { $env:PZ_DEV_DIR } else { Join-Path $env:USERPROFILE "PZDev" }
$modSource = Join-Path $PSScriptRoot "..\mod\SurvivorComforts\Contents\mods\SurvivorComforts"
. (Join-Path $PSScriptRoot "TestLaunch.ps1")

New-Item -ItemType Directory -Force $Root | Out-Null

& (Join-Path $PSScriptRoot "deploy.ps1") -Alpha:$Alpha
if ($LASTEXITCODE -ne 0) { throw "deploy.ps1 failed" }

Initialize-ClientOptions $Root

# Turn the mod on in the main menu's mod list (new games start with it).
# On its first start the game empties the list unless this marker file exists.
$utf8 = New-Object Text.UTF8Encoding $false
New-Item -ItemType Directory -Force (Join-Path $Root "mods") | Out-Null
$resetMarker = Join-Path $Root "mods\reset-mods-42_00.txt"
if (-not (Test-Path $resetMarker)) {
    [IO.File]::WriteAllText($resetMarker, "If this file does not exist, default.txt will be reset to empty (no mods active).", $utf8)
}
$modList = Join-Path $Root "mods\default.txt"
[IO.File]::WriteAllLines($modList, [string[]]@(
    "VERSION = 1,", "", "mods", "{", "    mod = $ModId,", "}", "", "maps", "{", "}"
), $utf8)

# With Steam (no -nosteam), so the Workshop upload works.
$arguments = "-cachedir=`"$Root`""
if ($Debug) { $arguments = "-debug $arguments" }
$cmd = Write-Launcher "dev" "$ModId dev" (Get-JavaLine "ProjectZomboid64.bat") $arguments

Write-Host "Dev folder: $Root"
if ($SetupOnly) {
    Write-Host "Mod copied. Start with $cmd."
    exit 0
}

Start-Process -FilePath $cmd -WorkingDirectory $GameDir
Write-Host "Started the game with the dev folder. The mod is on; Main menu > Workshop uploads from $Root\Workshop."
