# Runs a local test server and game clients on this PC, to try the mod in
# multiplayer with several players (for example F09, the player list).
#
# Everything runs without Steam (-nosteam), so one PC can join with several
# clients under different user names. Each one gets its own data folder
# (-cachedir), so your normal %USERPROFILE%\Zomboid (saves, options) is not
# touched:
#   <Root>\server   the server's world, settings (Server\sctest.ini) and log (server-console.txt)
#   <Root>\client1  the first client, <Root>\client2 the second, ...
# The mod is copied into <Root>\<each>\mods\ every time (no Workshop without
# Steam), so run this again after changing the mod, with the server stopped.
#
#   powershell -File tools\test_server.ps1               copy the mod, start the server and 2 clients
#   powershell -File tools\test_server.ps1 -Clients 1    only 1 client
#   powershell -File tools\test_server.ps1 -SetupOnly    only copy the mod and write the launch files
#
# Then join from each client: Join > IP 127.0.0.1, port 16261, a different
# user name in each (a new name makes a new account). The server's admin
# password is "admin". Stop the server by typing "quit" in its window.
# The launch files are also written to <Root>\*.cmd, to start one again by hand.

param(
    [string]$Root = $(if ($env:PZ_TEST_DIR) { $env:PZ_TEST_DIR } else { Join-Path $env:USERPROFILE "PZTest" }),
    [string]$GameDir = $env:PZ_GAME_DIR,
    [int]$Clients = 2,
    [switch]$SetupOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "GameDir.ps1")
$GameDir = Resolve-GameDir $GameDir

$ModId = "SurvivorComforts"
$ServerName = "sctest"
$AdminPassword = "admin"
$modSource = Join-Path $PSScriptRoot "..\mod\SurvivorComforts\Contents\mods\SurvivorComforts"

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

New-Item -ItemType Directory -Force $Root | Out-Null

# Server: the mod from its mods folder, no Workshop items.
$serverDir = Join-Path $Root "server"
Copy-Mod $serverDir
$ini = Join-Path $serverDir "Server\$ServerName.ini"
Set-IniValue $ini "Mods" $ModId
Set-IniValue $ini "WorkshopItems" ""
Set-IniValue $ini "Open" "true"
Set-IniValue $ini "Public" "false"
$serverCmd = Write-Launcher "server" "$ModId test server" (Get-JavaLine "ProjectZomboidServer.bat") `
    "-nosteam -cachedir=`"$serverDir`" -servername $ServerName -adminpassword $AdminPassword"

# Clients: the same mod files (the server checks they match), and your options
# in a 1280x720 window the first time.
$clientJava = Get-JavaLine "ProjectZomboid64.bat"
$clientCmds = @()
for ($i = 1; $i -le $Clients; $i++) {
    $clientDir = Join-Path $Root "client$i"
    Copy-Mod $clientDir
    $options = Join-Path $clientDir "options.ini"
    if (-not (Test-Path $options)) {
        $mine = Join-Path $env:USERPROFILE "Zomboid\options.ini"
        if (Test-Path $mine) { Copy-Item $mine $options }
        Set-IniValue $options "fullScreen" "false"
        Set-IniValue $options "width" "1280"
        Set-IniValue $options "height" "720"
    }
    $clientCmds += Write-Launcher "client$i" "$ModId test client $i" $clientJava "-nosteam -cachedir=`"$clientDir`""
}

Write-Host "Test folder: $Root"
if ($SetupOnly) {
    Write-Host "Mod copied. Start with $serverCmd and client*.cmd."
    exit 0
}

Start-Process -FilePath $serverCmd -WorkingDirectory $GameDir
foreach ($cmd in $clientCmds) {
    Start-Process -FilePath $cmd -WorkingDirectory $GameDir
}
Write-Host "Started the server and $Clients client(s). Join 127.0.0.1 port 16261 with a different user name in each."
