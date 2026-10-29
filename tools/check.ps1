# Syntax-checks every .lua file in the mod with the game's own Lua compiler.
# Needs a JDK (javac) to build the checker once, and the game's bundled Java to run it.

$ErrorActionPreference = "Stop"

$game = "H:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$javac = "C:\Program Files\Java\jdk-13.0.2\bin\javac.exe"
$build = Join-Path $PSScriptRoot "build"
$luaRoot = Join-Path $PSScriptRoot "..\mod\SurvivorComforts\Contents\mods\SurvivorComforts"

New-Item -ItemType Directory -Force $build | Out-Null
& $javac --release 13 -d $build (Join-Path $PSScriptRoot "LuaSyntaxCheck.java")
if ($LASTEXITCODE -ne 0) { throw "javac failed" }

& "$game\jre64\bin\java.exe" -cp "$game\projectzomboid.jar;$build" LuaSyntaxCheck $luaRoot
exit $LASTEXITCODE
