# install-edge-extension-policy.ps1
# Register a personal Chrome/Edge extension via Group Policy so it loads
# automatically on next browser launch. Bypasses the Developer Mode UI
# (which is hidden in Edge 134+ and Chrome matching versions) and the
# "private key required" gate that the unpacked-extension dialog now enforces.
#
# Run as Administrator on the target laptop. The session is the SSH session
# from Hermes, which lands on the Administrator account by default — so no
# elevation step is needed.
#
# Usage (after editing the two variables at the top):
#   powershell -NoProfile -ExecutionPolicy Bypass -File install-edge-extension-policy.ps1
#
# Or, remotely:
#   scp install-edge-extension-policy.ps1 Administrator@laptop.tail<id>.ts.net:staging.ps1
#   ssh Administrator@laptop.tail<id>.ts.net "powershell -NoProfile -ExecutionPolicy Bypass -File staging.ps1"

$ErrorActionPreference = "Stop"

# --- Edit these two lines ---
$extId = "mphahnfobooebdfijheknmidjieihaic"   # from pack-crx.js output or extIdFromPubKey()
$crxPath = "C:\Users\administrator\AppData\Local\HermesBridge\scrappy-dood.crx"

# --- Sanity check the CRX exists ---
if (-not (Test-Path $crxPath)) {
    throw "CRX not found at $crxPath — run pack-crx.js + scp first."
}

# --- HKLM is required for Edge policies; HKCU is silently ignored ---
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (-not (Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
    Write-Host "Created Edge policy key: $policyPath"
}

# Build the file:// URL Edge expects
$crxUrl = "file:///" + ($crxPath -replace '\\','/')

# 1. ExtensionInstallForcelist — force-install this extension
$forceListPath = "$policyPath\ExtensionInstallForcelist"
if (-not (Test-Path $forceListPath)) { New-Item -Path $forceListPath -Force | Out-Null }
# Value format: "extension_id;update_url" — for a local CRX, update_url is file://
$value = "$extId;$crxUrl"
New-ItemProperty -Path $forceListPath -Name "1" -Value $value -PropertyType String -Force | Out-Null
Write-Host "Set ExtensionInstallForcelist[1] = $value"

# 2. ExtensionSettings — per-extension allow + force_install
$extSettingsPath = "$policyPath\ExtensionSettings"
if (-not (Test-Path $extSettingsPath)) { New-Item -Path $extSettingsPath -Force | Out-Null }
$config = @{
    "*" = @{
        installation_mode = "allowed"
        runtime_blocked_hosts = @()
        blocked_permissions = @()
    }
    $extId = @{
        installation_mode = "force_installed"
        update_url = $crxUrl
    }
} | ConvertTo-Json -Depth 6 -Compress
New-ItemProperty -Path $extSettingsPath -Name $extId -Value $config -PropertyType String -Force | Out-Null
Write-Host "Set ExtensionSettings[$extId]"

# 3. ExtensionInstallAllowlist — defense in depth (allows the ID even
#    if some other policy tries to blocklist it)
$allowlistPath = "$policyPath\ExtensionInstallAllowlist"
if (-not (Test-Path $allowlistPath)) { New-Item -Path $allowlistPath -Force | Out-Null }
New-ItemProperty -Path $allowlistPath -Name $extId -Value 1 -PropertyType DWord -Force | Out-Null
Write-Host "Set ExtensionInstallAllowlist[$extId] = 1"

# 4. DeveloperToolsAvailability — make sure DevTools stay on (1 = always allowed)
New-ItemProperty -Path $policyPath -Name "DeveloperToolsAvailability" -Value 1 -PropertyType DWord -Force | Out-Null
Write-Host "Set DeveloperToolsAvailability = 1"

Write-Host ""
Write-Host "=== Final policy state under HKLM\SOFTWARE\Policies\Microsoft\Edge ==="
foreach ($sub in @("ExtensionInstallForcelist", "ExtensionSettings", "ExtensionInstallAllowlist")) {
    $p = "$policyPath\$sub"
    if (Test-Path $p) {
        Write-Host "--- $sub ---"
        $props = Get-Item $p
        $props.GetEnumerator() | ForEach-Object {
            if ($_.Name -notmatch '^PS') {
                $val = $_.Value
                if ($val.Length -gt 200) { $val = $val.Substring(0, 200) + "..." }
                Write-Host "  $($_.Name) = $val"
            }
        }
    }
}

Write-Host ""
Write-Host "Done. The user should fully close Edge (no windows open) and relaunch."
Write-Host "On first launch, Edge may pop an 'External extension loaded' prompt"
Write-Host "which the user clicks through. After that, the extension appears in"
Write-Host "edge://extensions with ID = $extId"
