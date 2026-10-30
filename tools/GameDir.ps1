# Finds the Project Zomboid folder (the one with projectzomboid.jar).
# Dot-sourced by check.ps1, test_server.ps1 and make_english_names.ps1.
#   $GameDir = Resolve-GameDir $GameDir

function Find-GameDir {
    $steam = Get-ItemProperty "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction SilentlyContinue
    if (-not $steam) { return $null }
    $libraries = @($steam.SteamPath)
    $vdf = Join-Path $steam.SteamPath "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        foreach ($m in Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"') {
            $libraries += $m.Matches[0].Groups[1].Value -replace '\\\\', '\'
        }
    }
    foreach ($lib in $libraries) {
        $dir = Join-Path $lib "steamapps\common\ProjectZomboid"
        if (Test-Path (Join-Path $dir "projectzomboid.jar")) { return $dir }
    }
    return $null
}

# Returns the given folder, or the one found in Steam's libraries; throws if neither has the game.
function Resolve-GameDir($given) {
    $dir = if ($given) { $given } else { Find-GameDir }
    if (-not $dir -or -not (Test-Path (Join-Path $dir "projectzomboid.jar"))) {
        throw "Project Zomboid not found. Pass -GameDir or set PZ_GAME_DIR to the game folder (the one with projectzomboid.jar)."
    }
    return $dir
}
