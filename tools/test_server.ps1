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
#   powershell -File tools\test_server.ps1 -Debug        start the clients in debug mode
#   powershell -File tools\test_server.ps1 -SetupOnly    only copy the mod and write the launch files
#
# Then join from each client: Join > IP 127.0.0.1, port 16261, a different
# user name in each (a new name makes a new account). The server's admin
# password is "admin". Stop the server by typing "quit" in its window.
# The launch files are also written to <Root>\*.cmd, to start one again by hand.
# For single player in debug mode, use test_debug.ps1.

param(
    [string]$Root = $(if ($env:PZ_TEST_DIR) { $env:PZ_TEST_DIR } else { Join-Path $env:USERPROFILE "PZTest" }),
    [string]$GameDir = $env:PZ_GAME_DIR,
    [int]$Clients = 2,
    [switch]$Debug,
    [switch]$SetupOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "GameDir.ps1")
$GameDir = Resolve-GameDir $GameDir

$ModId = "SurvivorComforts"
$ServerName = "sctest"
$AdminPassword = "admin"
$modSource = Join-Path $PSScriptRoot "..\mod\SurvivorComforts\Contents\mods\SurvivorComforts"
. (Join-Path $PSScriptRoot "TestLaunch.ps1")

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

# Clients: the same mod files (the server checks they match).
$clientJava = Get-JavaLine "ProjectZomboid64.bat"
$clientArgs = "-nosteam"
if ($Debug) { $clientArgs += " -debug" }
$clientCmds = @()
for ($i = 1; $i -le $Clients; $i++) {
    $clientDir = Join-Path $Root "client$i"
    Copy-Mod $clientDir
    Initialize-ClientOptions $clientDir
    $clientCmds += Write-Launcher "client$i" "$ModId test client $i" $clientJava "$clientArgs -cachedir=`"$clientDir`""
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
