<#
.SYNOPSIS
    Install/Uninstall OpenClaw Watchdog as Windows startup task.
.DESCRIPTION
    -Install: Copies files to %LOCALAPPDATA%\openclaw-watchdog, creates startup entry, launches.
    -Uninstall: Removes startup entry and stops watchdog.
.PARAMETER Uninstall
    Remove watchdog from startup.
.PARAMETER WatchdogPath
    Custom install path. Default: %LOCALAPPDATA%\openclaw-watchdog
#>

param(
    [switch]$Uninstall,
    [string]$WatchdogPath = ""
)

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $WatchdogPath) { $WatchdogPath = "$env:LOCALAPPDATA\openclaw-watchdog" }

$WshShell = New-Object -ComObject WScript.Shell
$StartupFolder = [System.Environment]::GetFolderPath('Startup')
$ShortcutPath = Join-Path $StartupFolder "OpenClaw-Watchdog.lnk"

# ── Uninstall ──────────────────────────────────────────────────────
if ($Uninstall) {
    Write-Host "[*] Uninstalling OpenClaw Watchdog..." -ForegroundColor Yellow

    # Remove startup shortcut
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
        Write-Host "[✓] Startup shortcut removed" -ForegroundColor Green
    }

    # Kill running watchdog processes
    $watchdogProcs = Get-Process | Where-Object {
        $_.ProcessName -eq "powershell" -and $_.CommandLine -like "*openclaw-watchdog*"
    } -ErrorAction SilentlyContinue
    if ($watchdogProcs) {
        $watchdogProcs | Stop-Process -Force
        Write-Host "[✓] Running watchdog stopped" -ForegroundColor Green
    }

    Write-Host "[✓] Uninstall complete" -ForegroundColor Green
    return
}

# ── Install ─────────────────────────────────────────────────────────
Write-Host "[*] Installing OpenClaw Watchdog..." -ForegroundColor Cyan

# Create target directory
if (-not (Test-Path $WatchdogPath)) {
    New-Item -ItemType Directory -Path $WatchdogPath -Force | Out-Null
}
Write-Host "[✓] Target: $WatchdogPath" -ForegroundColor Green

# Copy files
$filesToCopy = @("openclaw-watchdog.ps1", "start-watchdog.vbs")
foreach ($file in $filesToCopy) {
    $src = Join-Path $ScriptDir $file
    $dst = Join-Path $WatchdogPath $file
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "[✓] Copied $file" -ForegroundColor Green
    } else {
        Write-Host "[!] Missing: $src" -ForegroundColor Yellow
    }
}

# Create startup shortcut
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = Join-Path $WatchdogPath "start-watchdog.vbs"
$Shortcut.WorkingDirectory = $WatchdogPath
$Shortcut.Description = "OpenClaw Watchdog - Auto-restart Gateway + Paperclip"
$Shortcut.Save()
Write-Host "[✓] Startup shortcut created" -ForegroundColor Green

# Launch watchdog
Start-Process -FilePath "wscript.exe" -ArgumentList "`"$(Join-Path $WatchdogPath 'start-watchdog.vbs')`"" -WindowStyle Hidden
Write-Host "[✓] Watchdog launched" -ForegroundColor Green

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Cyan
Write-Host "  Watchdog path: $WatchdogPath" -ForegroundColor White
Write-Host "  Startup entry: $ShortcutPath" -ForegroundColor White
Write-Host "  Monitor: Gateway (:18789) + Paperclip (:3100)" -ForegroundColor White
Write-Host ""
Write-Host "To uninstall: powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall" -ForegroundColor Yellow
