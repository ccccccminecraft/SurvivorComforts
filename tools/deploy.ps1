# Copies the mod into the development data folder,
# %USERPROFILE%\PZDev\Workshop\SurvivorComforts (or $env:PZ_DEV_DIR\Workshop\...),
# so a game started with that folder (dev_game.ps1) can load it for testing
# and upload it from Main menu > Workshop.
#
#   powershell -File tools\deploy.ps1          the stable mod (upload from main)
#   powershell -File tools\deploy.ps1 -Alpha   the alpha mod, Survivor Comforts (Alpha),
#                                              from the files as they are (dev)
#
# Not into %USERPROFILE%\Zomboid\Workshop: the game takes a mod from its
# Workshop folder before the Steam Workshop copy, so the everyday game would
# use this copy instead of the one the other players have
# (docs\dev-guide.md, "開発用のフォルダ").
#
# The repository's LICENSE is copied into the mod as LICENSE.txt.
#
# The alpha mod (docs\dev-guide.md, "アルファ版") is the same files in
# Workshop\SurvivorComfortsAlpha\Contents\mods\SurvivorComfortsAlpha; only its
# mod.info is changed: the mod id, the name, the version (with -alpha and the
# dev commit) and incompatible= the stable mod.
#
# workshop.txt in the destination is kept: the game writes the Workshop item
# id into it after the first upload. If there is none yet, the stable one is
# copied from the old place (%USERPROFILE%\Zomboid\Workshop\SurvivorComforts),
# and the alpha one is made from docs\workshop-alpha.md.

param(
    [switch]$Alpha
)

$ErrorActionPreference = "Stop"

$StableId = "SurvivorComforts"
$AlphaId = "SurvivorComfortsAlpha"
$ModId = if ($Alpha) { $AlphaId } else { $StableId }

$DevRoot = if ($env:PZ_DEV_DIR) { $env:PZ_DEV_DIR } else { Join-Path $env:USERPROFILE "PZDev" }
$repo = Join-Path $PSScriptRoot ".."
$source = Join-Path $repo "mod\SurvivorComforts"
$dest = Join-Path $DevRoot "Workshop\$ModId"
$modDest = Join-Path $dest "Contents\mods\$ModId"
$utf8 = New-Object Text.UTF8Encoding $false

function Invoke-Robocopy($from, $to, [string[]]$extra) {
    robocopy $from $to /MIR /NFL /NDL /NJH /NP @extra | Out-Host
    # robocopy: 0-7 = success (8 or more = failure)
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
}

if ($Alpha) {
    # The mod folder under its own id, and the preview image.
    Invoke-Robocopy (Join-Path $source "Contents\mods\$StableId") $modDest @()
    Copy-Item (Join-Path $source "preview.png") (Join-Path $dest "preview.png") -Force
} else {
    Invoke-Robocopy $source $dest @("/XF", "workshop.txt")
}

# The license goes into the mod itself, so the Workshop copy carries it (the
# MIT License asks for its text in every copy; F02 and F15 are based on
# itsu07's MIT code). The repository's LICENSE is the only source.
Copy-Item (Join-Path $repo "LICENSE") (Join-Path $modDest "LICENSE.txt") -Force

if ($Alpha) {
    $commit = (git -C $repo rev-parse --short HEAD 2>$null)
    if (-not $commit) { $commit = "unknown" }
    $dirty = git -C $repo status --porcelain 2>$null
    if ($dirty) { $commit = "$commit.modified" }
    foreach ($info in Get-ChildItem $modDest -Recurse -Filter mod.info) {
        $lines = [IO.File]::ReadAllLines($info.FullName, $utf8) | Where-Object { $_ -notmatch '^incompatible=' } | ForEach-Object {
            if ($_ -match '^id=') { "id=$AlphaId" }
            elseif ($_ -match '^name=') { "name=Survivor Comforts (Alpha)" }
            elseif ($_ -match '^modversion=(.*)$') { "modversion=$($Matches[1])-alpha.$commit" }
            elseif ($_ -match '^description=(.*)$') { "description=(Alpha: features still in development) $($Matches[1])" }
            else { $_ }
        }
        $lines += "incompatible=\$StableId"
        [IO.File]::WriteAllLines($info.FullName, [string[]]$lines, $utf8)
    }
    Write-Host "Alpha version: $commit"
}

$itemFile = Join-Path $dest "workshop.txt"
if ($Alpha) {
    if (-not (Test-Path $itemFile)) {
        # The description is the first code block under the "## 説明" (description)
        # heading of workshop-alpha.md; written with \u codes, as Windows
        # PowerShell reads this file in the system code page.
        $page = [IO.File]::ReadAllLines((Join-Path $repo "docs\workshop-alpha.md"), $utf8)
        $section = $false; $inBlock = $false; $description = @()
        foreach ($line in $page) {
            if ($line -match '^## ') { $section = ($line -match '^## \u8AAC\u660E'); continue }
            if (-not $section) { continue }
            if ($line -match '^```') {
                if ($inBlock) { break }
                $inBlock = $true
                continue
            }
            if ($inBlock) { $description += $line }
        }
        if ($description.Count -eq 0) { throw "No description found in docs\workshop-alpha.md" }
        $out = @("version=1", "title=Survivor Comforts (Alpha)")
        $out += $description | ForEach-Object { "description=$_" }
        $out += @("tags=Build 42;Interface;QoL", "visibility=unlisted")
        [IO.File]::WriteAllLines($itemFile, [string[]]$out, $utf8)
        Write-Host "Made $itemFile from docs\workshop-alpha.md (no Workshop id yet: the first upload makes a new item)"
    }
} else {
    $oldItemFile = Join-Path $env:USERPROFILE "Zomboid\Workshop\SurvivorComforts\workshop.txt"
    if (-not (Test-Path $itemFile) -and (Test-Path $oldItemFile)) {
        Copy-Item $oldItemFile $itemFile
        Write-Host "Copied workshop.txt (the Workshop item id) from $oldItemFile"
    }

    $old = Join-Path $env:USERPROFILE "Zomboid\Workshop\SurvivorComforts"
    if (Test-Path $old) {
        Write-Host "Note: $old still exists. The everyday game uses it instead of the Steam Workshop copy; remove it once workshop.txt is in $dest."
    }
}

Write-Host "Deployed to $dest"
exit 0
