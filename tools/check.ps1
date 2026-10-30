# Syntax-checks every .lua file in the mod with the game's own Lua compiler.
# Needs a JDK (javac, 13 or newer) to build the checker, and the game's bundled
# Java to run it.
#
# The game and javac are found automatically:
#   game : Steam's library folders (from the registry), steamapps\common\ProjectZomboid
#   javac: JAVA_HOME, then javac on PATH, then the newest C:\Program Files\Java\jdk*
# To use other locations, pass them or set environment variables:
#   powershell -File tools\check.ps1 -GameDir "E:\Games\ProjectZomboid" -Javac "C:\jdk\bin\javac.exe"
#   (or set PZ_GAME_DIR / JAVAC)

param(
    [string]$GameDir = $env:PZ_GAME_DIR,
    [string]$Javac = $env:JAVAC
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "GameDir.ps1")

function Find-Javac {
    if ($env:JAVA_HOME) {
        $candidate = Join-Path $env:JAVA_HOME "bin\javac.exe"
        if (Test-Path $candidate) { return $candidate }
    }
    $onPath = Get-Command javac -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $jdk = Get-ChildItem "C:\Program Files\Java" -Directory -Filter "jdk*" -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "bin\javac.exe") } |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($jdk) { return Join-Path $jdk.FullName "bin\javac.exe" }
    return $null
}

$GameDir = Resolve-GameDir $GameDir
if (-not $Javac) { $Javac = Find-Javac }
if (-not $Javac -or -not (Test-Path $Javac)) {
    throw "javac not found. Install a JDK (13 or newer), or pass -Javac / set JAVAC to javac.exe."
}

$build = Join-Path $PSScriptRoot "build"
$luaRoot = Join-Path $PSScriptRoot "..\mod\SurvivorComforts\Contents\mods\SurvivorComforts"

New-Item -ItemType Directory -Force $build | Out-Null
& $Javac --release 13 -d $build (Join-Path $PSScriptRoot "LuaSyntaxCheck.java")
if ($LASTEXITCODE -ne 0) { throw "javac failed" }

& "$GameDir\jre64\bin\java.exe" -cp "$GameDir\projectzomboid.jar;$build" LuaSyntaxCheck $luaRoot
exit $LASTEXITCODE
