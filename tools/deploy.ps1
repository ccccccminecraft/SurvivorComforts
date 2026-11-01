# Copies the mod into the development data folder,
# %USERPROFILE%\PZDev\Workshop\SurvivorComforts (or $env:PZ_DEV_DIR\Workshop\...),
# so a game started with that folder (dev_game.ps1) can load it for testing
# and upload it from Main menu > Workshop.
#
# Not into %USERPROFILE%\Zomboid\Workshop: the game takes a mod from its
# Workshop folder before the Steam Workshop copy, so the everyday game would
# use this copy instead of the one the other players have
# (docs\dev-guide.md, "開発用のフォルダ").
#
# workshop.txt in the destination is kept: the game writes the Workshop item
# id into it after the first upload. If there is none yet, the one from the
# old place (%USERPROFILE%\Zomboid\Workshop\SurvivorComforts) is copied over.

$ErrorActionPreference = "Stop"

$DevRoot = if ($env:PZ_DEV_DIR) { $env:PZ_DEV_DIR } else { Join-Path $env:USERPROFILE "PZDev" }
$source = Join-Path $PSScriptRoot "..\mod\SurvivorComforts"
$dest = Join-Path $DevRoot "Workshop\SurvivorComforts"

robocopy $source $dest /MIR /XF workshop.txt /NFL /NDL /NJH /NP | Out-Host
# robocopy: 0-7 = success (8 or more = failure)
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }

$itemFile = Join-Path $dest "workshop.txt"
$oldItemFile = Join-Path $env:USERPROFILE "Zomboid\Workshop\SurvivorComforts\workshop.txt"
if (-not (Test-Path $itemFile) -and (Test-Path $oldItemFile)) {
    Copy-Item $oldItemFile $itemFile
    Write-Host "Copied workshop.txt (the Workshop item id) from $oldItemFile"
}

$old = Join-Path $env:USERPROFILE "Zomboid\Workshop\SurvivorComforts"
if (Test-Path $old) {
    Write-Host "Note: $old still exists. The everyday game uses it instead of the Steam Workshop copy; remove it once workshop.txt is in $dest."
}

Write-Host "Deployed to $dest"
exit 0
