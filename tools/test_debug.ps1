# Starts the game in debug mode (-debug) for trying the mod in single player,
# for example to get items from the debug menu or reload Lua in game.
#
# Like test_server.ps1 it runs without Steam and with its own data folder, so
# your normal %USERPROFILE%\Zomboid (saves, options) is not touched:
#   <Root>\debug   the saves, options and log (console.txt)
# The mod is copied into <Root>\debug\mods\ and turned on every time, so run
# this again after changing the mod, with the game closed.
#
#   powershell -File tools\test_debug.ps1              copy the mod and start the game
#   powershell -File tools\test_debug.ps1 -SetupOnly   only copy the mod and write the launch file
#
# Start a new game (Solo) from the main menu; the mod is already on. A save
# keeps the mod list it was started with, so a save made without the mod
# stays without it.
# The launch file is also written to <Root>\debug.cmd, to start it again by hand.

param(
    [string]$Root = $(if ($env:PZ_TEST_DIR) { $env:PZ_TEST_DIR } else { Join-Path $env:USERPROFILE "PZTest" }),
    [string]$GameDir = $env:PZ_GAME_DIR,
    [switch]$SetupOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "GameDir.ps1")
$GameDir = Resolve-GameDir $GameDir

$ModId = "SurvivorComforts"
$modSource = Join-Path $PSScriptRoot "..\mod\SurvivorComforts\Contents\mods\SurvivorComforts"
. (Join-Path $PSScriptRoot "TestLaunch.ps1")

New-Item -ItemType Directory -Force $Root | Out-Null

$dataDir = Join-Path $Root "debug"
Copy-Mod $dataDir
Initialize-ClientOptions $dataDir

# Turn the mod on in the main menu's mod list (new games start with it).
# On its first start the game empties the list unless this marker file exists.
$utf8 = New-Object Text.UTF8Encoding $false
$resetMarker = Join-Path $dataDir "mods\reset-mods-42_00.txt"
if (-not (Test-Path $resetMarker)) {
    [IO.File]::WriteAllText($resetMarker, "If this file does not exist, default.txt will be reset to empty (no mods active).", $utf8)
}
$modList = Join-Path $dataDir "mods\default.txt"
[IO.File]::WriteAllLines($modList, [string[]]@(
    "VERSION = 1,", "", "mods", "{", "    mod = $ModId,", "}", "", "maps", "{", "}"
), $utf8)

$cmd = Write-Launcher "debug" "$ModId debug" (Get-JavaLine "ProjectZomboid64.bat") "-nosteam -debug -cachedir=`"$dataDir`""

Write-Host "Test folder: $dataDir"
if ($SetupOnly) {
    Write-Host "Mod copied. Start with $cmd."
    exit 0
}

Start-Process -FilePath $cmd -WorkingDirectory $GameDir
Write-Host "Started the game in debug mode. Start a new Solo game; the mod is already on."
