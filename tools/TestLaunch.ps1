# Shared by test_server.ps1 and test_debug.ps1: start the game without Steam,
# with its own data folder (-cachedir) and the mod copied into it.
# Dot-source it after setting $GameDir, $Root, $ModId and $modSource.

# The java command line from the game's own .bat, so it follows game updates.
function Get-JavaLine($bat) {
    $lines = Get-Content (Join-Path $GameDir $bat)
    $classpath = ($lines | Where-Object { $_ -match '^\s*SET PZ_CLASSPATH=(.*)$' } | Select-Object -First 1) -replace '^\s*SET PZ_CLASSPATH=', ''
    $java = $lines | Where-Object { $_ -match '^\s*"\.\\jre64\\bin\\java\.exe"' } | Select-Object -First 1
    if (-not $java -or -not $classpath) { throw "Could not read the java command line from $bat." }
    return ($java.Trim() -replace '%PZ_CLASSPATH%', $classpath -replace '\s*%\d', '')
}

function Copy-Mod($dataDir) {
    $dest = Join-Path $dataDir "mods\$ModId"
    robocopy $modSource $dest /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Copying the mod to $dest failed (robocopy $LASTEXITCODE)." }
}

# Sets key=value in an ini file, adding the line if it is missing.
function Set-IniValue($file, $key, $value) {
    $lines = @()
    if (Test-Path $file) { $lines = @(Get-Content $file) }
    $found = $false
    $lines = @($lines | ForEach-Object {
        if ($_ -match "^$([regex]::Escape($key))=") { $found = $true; "$key=$value" } else { $_ }
    })
    if (-not $found) { $lines += "$key=$value" }
    New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null
    # No BOM: the game would read it as part of the first key.
    [IO.File]::WriteAllLines($file, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
}

# Your options in a 1280x720 window, the first time only.
function Initialize-ClientOptions($dataDir) {
    $options = Join-Path $dataDir "options.ini"
    if (Test-Path $options) { return }
    $mine = Join-Path $env:USERPROFILE "Zomboid\options.ini"
    if (Test-Path $mine) { Copy-Item $mine $options }
    Set-IniValue $options "fullScreen" "false"
    Set-IniValue $options "width" "1280"
    Set-IniValue $options "height" "720"
}

function Write-Launcher($name, $title, $javaLine, $arguments) {
    $file = Join-Path $Root "$name.cmd"
    Set-Content -Path $file -Encoding Default -Value @(
        "@echo off",
        "title $title",
        "cd /d `"$GameDir`"",
        "set _JAVA_OPTIONS=",
        "$javaLine $arguments",
        "pause"
    )
    return $file
}
