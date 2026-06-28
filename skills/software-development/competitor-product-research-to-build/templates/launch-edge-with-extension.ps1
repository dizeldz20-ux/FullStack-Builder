# launch-edge-with-extension.ps1
# Creates a desktop shortcut (and a .bat fallback) that launches Microsoft Edge
# with the --load-extension flag pre-baked. Use when Edge 134+ silently
# blocks ExtensionInstallForcelist file:// URLs, or as a single-user
# alternative to the Group Policy install path.
#
# Edit $extPath at the top if your extension lives elsewhere. Run as the
# Windows user who will use the extension (the script writes to that user's
# Desktop + Start Menu).

$ErrorActionPreference = "Stop"

# --- CONFIG ---
$extPath = "C:\Users\administrator\AppData\Local\HermesBridge\extension\scrappy-dood"
$edgeExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$shortcutName = "Scrappy-Dood Edge"
# ---------------

if (-not (Test-Path $extPath)) {
    throw "Extension path does not exist: $extPath"
}
if (-not (Test-Path $edgeExe)) {
    throw "Edge executable not found: $edgeExe. Is Edge installed?"
}

$arguments = "--load-extension=`"$extPath`" --no-first-run --no-default-browser-check"

# 1. Desktop .lnk shortcut
$shell = New-Object -ComObject WScript.Shell
$desktopShortcut = [Environment]::GetFolderPath("Desktop") + "\$shortcutName.lnk"
$sc = $shell.CreateShortcut($desktopShortcut)
$sc.TargetPath = $edgeExe
$sc.Arguments = $arguments
$sc.WorkingDirectory = Split-Path $edgeExe -Parent
$sc.WindowStyle = 1
$sc.IconLocation = "$edgeExe,0"
$sc.Description = "Edge with the Scrappy-Dood extension loaded"
$sc.Save()
Write-Host "Desktop shortcut: $desktopShortcut"

# 2. Start Menu .lnk
$startMenu = [Environment]::GetFolderPath("StartMenu")
$programsShortcut = Join-Path $startMenu "Programs\$shortcutName.lnk"
$sc2 = $shell.CreateShortcut($programsShortcut)
$sc2.TargetPath = $edgeExe
$sc2.Arguments = $arguments
$sc2.WorkingDirectory = Split-Path $edgeExe -Parent
$sc2.WindowStyle = 1
$sc2.IconLocation = "$edgeExe,0"
$sc2.Save()
Write-Host "Start Menu shortcut: $programsShortcut"

# 3. Desktop .bat fallback (for the case where .lnk arguments don't expand)
$batPath = [Environment]::GetFolderPath("Desktop") + "\$shortcutName.bat"
$batContent = @"
@echo off
set "EXT=$extPath"
start "" "$edgeExe" --load-extension="%EXT%" --no-first-run --no-default-browser-check %*
"@
[System.IO.File]::WriteAllText($batPath, $batContent, [System.Text.Encoding]::ASCII)
Write-Host "Desktop batch: $batPath"

# 4. PowerShell helper
$helperPath = Join-Path $env:LOCALAPPDATA "HermesBridge\Launch-ScrappyEdge.ps1"
$helperDir = Split-Path $helperPath -Parent
if (-not (Test-Path $helperDir)) { New-Item -ItemType Directory -Force -Path $helperDir | Out-Null }
@"
# Launches Microsoft Edge with the Scrappy-Dood extension pre-loaded.
# Usage: powershell -File Launch-ScrappyEdge.ps1 [optional URL]
`$url = `$args[0]
`$extPath = "$extPath"
`$edge = "$edgeExe"
`$a = @('--load-extension=' + "`"$extPath`"", '--no-first-run', '--no-default-browser-check')
if (`$url) { `$a += `$url }
& `$edge @a
"@ | Set-Content $helperPath -Encoding UTF8
Write-Host "PowerShell helper: $helperPath"

Write-Host ""
Write-Host "Done. Close ALL Edge windows first, then double-click the desktop shortcut."
Write-Host "If it still doesn't load the extension, run gpupdate /force and reopen Edge."
