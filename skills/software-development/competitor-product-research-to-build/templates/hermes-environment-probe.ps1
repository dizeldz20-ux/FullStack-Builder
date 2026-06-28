# Hermes Environment Probe for Windows + Tailscale
# ===============================================
# Drop this on the user's machine (via SSH heredoc, NOT scp — see pitfalls),
# then run it to capture a full snapshot of what's available for a
# Hermes-integrated personal build.
#
# Usage from Hermes host:
#   ssh -i ~/.ssh/hermes-laptop/id_ed25519 Administrator@<fqdn> \
#     "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& { $(Get-Content -Raw C:\path\to\probe.ps1) }\""
#
# Safer for multi-line (avoids escaping hell):
#   1. Write the script to the laptop first via heredoc:
#      ssh ... "powershell -Command \"Set-Content -Path C:\probe.ps1 -Value @'
#      ...script body...
#      '@\""
#   2. Then invoke it:
#      ssh ... "powershell -NoProfile -ExecutionPolicy Bypass -File C:\probe.ps1"
#
# Output: a compact text snapshot. Capture and parse back into the build plan.

$ErrorActionPreference = "Continue"

Write-Host "=== OS ==="
$os = Get-CimInstance Win32_OperatingSystem
"{0} | Build {1}" -f $os.Caption, $os.BuildNumber

Write-Host ""
Write-Host "=== USERS (admin-capable) ==="
Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Name

Write-Host ""
Write-Host "=== BROWSERS ==="
$browsers = @{
    "Chrome"  = "HKLM:\SOFTWARE\Google\Chrome\BLBeacon"
    "Edge"    = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge\BLBeacon"
    "EdgeAlt" = "HKLM:\SOFTWARE\Microsoft\Edge\BLBeacon"
    "Brave"   = "HKLM:\SOFTWARE\BraveSoftware\Brave-Browser\BLBeacon"
}
foreach ($k in $browsers.Keys) {
    $v = (Get-ItemProperty -Path $browsers[$k] -ErrorAction SilentlyContinue).version
    if ($v) { Write-Host "$k : $v" }
}
$edgeInstall = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" -ErrorAction SilentlyContinue
if ($edgeInstall) { "Edge path: $($edgeInstall.InstallLocation)" }

Write-Host ""
Write-Host "=== RUNTIMES ==="
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) { "Node: $($node.Version) at $($node.Source)" } else { "Node: NOT FOUND" }
$npm = Get-Command npm -ErrorAction SilentlyContinue
if ($npm) { "npm: $($npm.Version)" }
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) { "Python: $($py.Version)" } else { "Python: NOT FOUND" }
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwsh) { "PowerShell 7: $($pwsh.Version)" } else { "PowerShell 7: NOT FOUND (only classic 5.1)" }

Write-Host ""
Write-Host "=== CHROME PROFILES (for personal install path planning) ==="
$chromeUserData = "$env:LOCALAPPDATA\Google\Chrome\User Data"
if (Test-Path $chromeUserData) {
    Get-ChildItem -Path $chromeUserData -Directory |
        Where-Object { $_.Name -eq "Default" -or $_.Name -match "^Profile " } |
        Select-Object -ExpandProperty Name
} else { "Chrome user data dir not found" }

Write-Host ""
Write-Host "=== HERMES BRIDGE TARGET DIR ==="
$bridgeDir = "$env:LOCALAPPDATA\HermesBridge"
"Target: $bridgeDir"
"Exists: $(Test-Path $bridgeDir)"

Write-Host ""
Write-Host "=== TAILSCALE STATE ==="
$ts = Get-Process tailscaled -ErrorAction SilentlyContinue
if ($ts) { "Tailscale: running" } else { "Tailscale: NOT running" }
$tsIp = & tailscale ip -4 2>$null
if ($tsIp) { "Tailscale IP: $tsIp" }

Write-Host ""
Write-Host "=== POWERSHELL EXEC POLICY ==="
Get-ExecutionPolicy -Scope CurrentUser
Get-ExecutionPolicy -Scope LocalMachine

Write-Host ""
Write-Host "=== REGISTRY WRITE TEST (HKCU only) ==="
$testKey = "HKCU:\Software\HermesBridgeProbe"
try {
    Set-ItemProperty -Path $testKey -Name "Test" -Value "OK" -Force
    $v = (Get-ItemProperty -Path $testKey -Name "Test" -ErrorAction SilentlyContinue).Test
    "HKCU write: $v"
    Remove-Item -Path $testKey -Recurse -Force -ErrorAction SilentlyContinue
} catch { "HKCU write: FAILED ($_)" }
