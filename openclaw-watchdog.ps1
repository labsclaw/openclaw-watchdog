<#
.SYNOPSIS
    OpenClaw Watchdog - Auto-recovery for Gateway + Paperclip services.
.DESCRIPTION
    Monitors both services with separate intervals (Paperclip more frequent).
    Auto-restarting any service that goes down.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogPath = Join-Path $ScriptDir "watchdog.log"

# Periodicidades separadas - Paperclip verifica mais frequentemente
$GatewayCheckInterval = 120
$PaperclipCheckInterval = 30

$GatewayPort = 18789
$PaperclipPort = 3100
$GatewayUrl = "http://127.0.0.1:$GatewayPort/"
$PaperclipUrl = "http://127.0.0.1:$PaperclipPort/api/health"

function Log { param($s) $t = Get-Date -Format "HH:mm:ss"; "$t $s" | Tee-Object -FilePath $LogPath -Append }
function Is-Alive { param($u) try { (Invoke-WebRequest -Uri $u -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop).StatusCode -eq 200 } catch { $false } }

Log "=== Watchdog started ==="
Log "Gateway   : $GatewayUrl"
Log "Paperclip : $PaperclipUrl"
Log "Gateway interval   : ${GatewayCheckInterval}s"
Log "Paperclip interval : ${PaperclipCheckInterval}s"

$LastGatewayCheck = (Get-Date).AddSeconds(-$GatewayCheckInterval)
$LastPaperclipCheck = (Get-Date).AddSeconds(-$PaperclipCheckInterval)

while ($true) {
    $Now = Get-Date

    # Check Gateway a cada 120s (2min)
    if (($Now - $LastGatewayCheck).TotalSeconds -ge $GatewayCheckInterval) {
        $LastGatewayCheck = $Now
        if (-not (Is-Alive $GatewayUrl)) {
            Log "Gateway DOWN. Restarting..."
            Start-Process "cmd.exe" -ArgumentList "/c openclaw gateway restart" -WindowStyle Hidden
            Start-Sleep 5
            if (Is-Alive $GatewayUrl) { Log "Gateway OK" } else { Log "Gateway restart FAILED" }
        }
    }

    # Check Paperclip a cada 30s
    if (($Now - $LastPaperclipCheck).TotalSeconds -ge $PaperclipCheckInterval) {
        $LastPaperclipCheck = $Now
        if (-not (Is-Alive $PaperclipUrl)) {
            Log "Paperclip DOWN. Restarting..."
            Start-Process "cmd.exe" -ArgumentList "/c pm2 restart paperclip" -WindowStyle Hidden
            Start-Sleep 5
            if (Is-Alive $PaperclipUrl) { Log "Paperclip OK" } else { Log "Paperclip restart FAILED" }
        }
    }

    Start-Sleep 5
}