<#
.SYNOPSIS
    Install/Uninstall OpenClaw Watchdog as Windows startup task.
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
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
        Write-Host "[+] Startup shortcut removed" -ForegroundColor Green
    }
    $watchdogProcs = Get-Process -Name "powershell" -ErrorAction SilentlyContinue
    $watchdogProcs | Where-Object { $_.CommandLine -like "*openclaw-watchdog*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Uninstall complete" -ForegroundColor Green
    return
}

# ── Install ─────────────────────────────────────────────────────────
Write-Host "[*] Installing OpenClaw Watchdog..." -ForegroundColor Cyan
if (-not (Test-Path $WatchdogPath)) { New-Item -ItemType Directory -Path $WatchdogPath -Force | Out-Null }
Write-Host "[+] Target: $WatchdogPath" -ForegroundColor Green

# Copy files
$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Copy-Item (Join-Path $SourceDir "openclaw-watchdog.ps1") (Join-Path $WatchdogPath "openclaw-watchdog.ps1") -Force
Copy-Item (Join-Path $SourceDir "start-watchdog.vbs") (Join-Path $WatchdogPath "start-watchdog.vbs") -Force
Write-Host "[+] Files copied" -ForegroundColor Green

# Create startup shortcut
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = Join-Path $WatchdogPath "start-watchdog.vbs"
$Shortcut.WorkingDirectory = $WatchdogPath
$Shortcut.Description = "OpenClaw Watchdog - Auto-restart Gateway + Paperclip"
$Shortcut.Save()
Write-Host "[+] Startup shortcut created" -ForegroundColor Green

# Launch watchdog
$vbsPath = Join-Path $WatchdogPath "start-watchdog.vbs"
Start-Process -FilePath "wscript.exe" -ArgumentList $vbsPath -WindowStyle Hidden
Write-Host "[+] Watchdog launched" -ForegroundColor Green

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Cyan
Write-Host "  Path: $WatchdogPath" -ForegroundColor White
Write-Host "  Startup: $ShortcutPath" -ForegroundColor White
Write-Host "  Monitor: Gateway (:18789) + Paperclip (:3100)" -ForegroundColor White
Write-Host ""
Write-Host "Uninstall: powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall" -ForegroundColor Yellow
