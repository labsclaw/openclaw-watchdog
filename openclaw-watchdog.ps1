<#
.SYNOPSIS
    OpenClaw Watchdog - Auto-recovery for Gateway + Paperclip.
.DESCRIPTION
    Checks every 60s if services are alive. If down, restarts immediately.
#>

param(
    [int]$CheckInterval = 60
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogPath   = Join-Path $ScriptDir "watchdog.log"
$Gateway   = "http://127.0.0.1:18789/"
$Paperclip = "http://127.0.0.1:3100/"

function Log     { param($s) $t = Get-Date -Format "HH:mm:ss"; "$t $s" | Tee-Object -FilePath $LogPath -Append }
function Is-Alive{ param($u) try { (Invoke-WebRequest -Uri $u -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop).StatusCode -eq 200 } catch { $false } }

Log "=== Watchdog started ==="
Log "Gateway   : $Gateway"
Log "Paperclip : $Paperclip"
Log "Interval  : ${CheckInterval}s"

while ($true) {
    Start-Sleep -Seconds $CheckInterval

    if (-not (Is-Alive $Gateway)) {
        Log "Gateway DOWN. Restarting..."
        Start-Process "cmd.exe" -ArgumentList "/c openclaw gateway restart" -WindowStyle Hidden
        Start-Sleep 5
        if (Is-Alive $Gateway) { Log "Gateway OK" } else { Log "Gateway restart FAILED" }
    }

    if (-not (Is-Alive $Paperclip)) {
        Log "Paperclip DOWN. Restarting..."
        Start-Process "cmd.exe" -ArgumentList "/c pm2 restart paperclip" -WindowStyle Hidden
        Start-Sleep 5
        if (Is-Alive $Paperclip) { Log "Paperclip OK" } else { Log "Paperclip restart FAILED" }
    }
}
