# Copies the mod into %USERPROFILE%\Zomboid\Workshop\SurvivorComforts so the game
# can load it for testing and upload it from Main menu > Workshop.
#
# workshop.txt in the destination is kept: the game writes the Workshop item
# id into it after the first upload.

$ErrorActionPreference = "Stop"

$source = Join-Path $PSScriptRoot "..\mod\SurvivorComforts"
$dest = Join-Path $env:USERPROFILE "Zomboid\Workshop\SurvivorComforts"

robocopy $source $dest /MIR /XF workshop.txt /NFL /NDL /NJH /NP | Out-Host
# robocopy: 0-7 = success (8 or more = failure)
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }

Write-Host "Deployed to $dest"
exit 0
