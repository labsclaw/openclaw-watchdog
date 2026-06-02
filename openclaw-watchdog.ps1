<#
.SYNOPSIS
    OpenClaw Watchdog - Auto-recovery for Gateway + Paperclip services.
.DESCRIPTION
    Monitors both services via HTTP health checks and process detection,
    auto-restarting any service that goes down. Runs as infinite loop.
.PARAMETER LogPath
    Path to log file. Default: $PSScriptRoot\watchdog.log
.PARAMETER CheckInterval
    Seconds between health checks. Default: 10
.PARAMETER RestartDelay
    Seconds to wait before restart. Default: 3
#>

param(
    [string]$LogPath = "",
    [int]$CheckInterval = 10,
    [int]$RestartDelay = 3
)

# ── Config ──────────────────────────────────────────────────────────
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $LogPath) { $LogPath = Join-Path $ScriptDir "watchdog.log" }

$GatewayPort    = 18789
$PaperclipPort  = 3100
$GatewayUrl     = "http://127.0.0.1:$GatewayPort/"
$PaperclipUrl   = "http://127.0.0.1:$PaperclipPort/api/health"
$MaxRetries     = 3
$BackoffSeconds = 30

# Track restart attempts to detect rapid cycling
$restartAttempts = @{ Gateway = 0; Paperclip = 0 }

# ── Logging ─────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    try {
        Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue
        # Keep log under 1MB
        if ((Get-Item $LogPath -ErrorAction SilentlyContinue).Length -gt 1MB) {
            $oldLog = $LogPath -replace '\.log$', '.old.log'
            Move-Item -Path $LogPath -Destination $oldLog -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

# ── Health Checks ───────────────────────────────────────────────────
function Test-ServiceAlive {
    param([string]$Url, [string]$Name)
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302 -or $response.StatusCode -eq 301) {
            return $true
        }
        return $false
    } catch {
        # Fallback: check process
        return (Test-ProcessAlive -Name $Name)
    }
}

function Test-ProcessAlive {
    param([string]$Name)
    switch ($Name) {
        "Gateway" {
            $procs = Get-WmiObject Win32_Process -Filter "name = 'node.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -like "*openclaw*gateway*" }
            return ($procs.Count -gt 0)
        }
        "Paperclip" {
            # Check PM2 first
            $pm2 = Get-WmiObject Win32_Process -Filter "name = 'node.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -like "*pm2*paperclip*" -or $_.CommandLine -like "*paperclip*server*" }
            if ($pm2.Count -gt 0) { return $true }
            # Direct paperclip process
            $pcp = Get-WmiObject Win32_Process -Filter "name = 'node.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -like "*paperclipai*" -or $_.CommandLine -like "*paperclip*" }
            return ($pcp.Count -gt 0)
        }
    }
    return $false
}

# ── Restart Functions ───────────────────────────────────────────────
function Restart-Gateway {
    Write-Log "WARN" "Gateway is DOWN. Waiting ${RestartDelay}s before restart..."
    Start-Sleep -Seconds $RestartDelay

    # Double-check before restarting
    if (Test-ServiceAlive -Url $GatewayUrl -Name "Gateway") {
        Write-Log "INFO" "Gateway recovered on its own, skipping restart"
        $restartAttempts["Gateway"] = 0
        return
    }

    $restartAttempts["Gateway"]++
    if ($restartAttempts["Gateway"] -gt $MaxRetries) {
        Write-Log "ERROR" "Gateway: $MaxRetries restart attempts failed. Backing off ${BackoffSeconds}s."
        Start-Sleep -Seconds $BackoffSeconds
        $restartAttempts["Gateway"] = 0
        return
    }

    Write-Log "INFO" "Restarting Gateway (attempt $($restartAttempts['Gateway'])/$MaxRetries)..."
    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "openclaw gateway restart" -WindowStyle Hidden -NoNewWindow
        Start-Sleep -Seconds 5
        if (Test-ServiceAlive -Url $GatewayUrl -Name "Gateway") {
            Write-Log "OK" "Gateway restarted successfully"
            $restartAttempts["Gateway"] = 0
        } else {
            Write-Log "WARN" "Gateway restart issued but not yet responsive (may need more time)"
        }
    } catch {
        Write-Log "ERROR" "Failed to restart Gateway: $_"
    }
}

function Restart-Paperclip {
    Write-Log "WARN" "Paperclip is DOWN. Waiting ${RestartDelay}s before restart..."
    Start-Sleep -Seconds $RestartDelay

    if (Test-ServiceAlive -Url $PaperclipUrl -Name "Paperclip") {
        Write-Log "INFO" "Paperclip recovered on its own, skipping restart"
        $restartAttempts["Paperclip"] = 0
        return
    }

    $restartAttempts["Paperclip"]++
    if ($restartAttempts["Paperclip"] -gt $MaxRetries) {
        Write-Log "ERROR" "Paperclip: $MaxRetries restart attempts failed. Backing off ${BackoffSeconds}s."
        Start-Sleep -Seconds $BackoffSeconds
        $restartAttempts["Paperclip"] = 0
        return
    }

    Write-Log "INFO" "Restarting Paperclip (attempt $($restartAttempts['Paperclip'])/$MaxRetries)..."
    try {
        # Try PM2 first
        $pm2Result = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "pm2 restart paperclip" -WindowStyle Hidden -NoNewWindow -PassThru -Wait
        Start-Sleep -Seconds 3
        if (Test-ServiceAlive -Url $PaperclipUrl -Name "Paperclip") {
            Write-Log "OK" "Paperclip restarted via PM2 successfully"
            $restartAttempts["Paperclip"] = 0
            return
        }
    } catch {
        Write-Log "WARN" "PM2 restart failed, trying direct start"
    }

    # Fallback: direct paperclip start
    try {
        $pcpPath = "$env:USERPROFILE\AppData\Roaming\npm\node_modules\paperclipai\dist\index.js"
        Start-Process -FilePath "node" -ArgumentList $pcpPath -WindowStyle Hidden -NoNewWindow
        Start-Sleep -Seconds 5
        if (Test-ServiceAlive -Url $PaperclipUrl -Name "Paperclip") {
            Write-Log "OK" "Paperclip started directly"
            $restartAttempts["Paperclip"] = 0
        }
    } catch {
        Write-Log "ERROR" "Failed to start Paperclip: $_"
    }
}

# ── Main Loop ───────────────────────────────────────────────────────
Write-Log "INFO" "══════════════════════════════════════════════"
Write-Log "INFO" "OpenClaw Watchdog started"
Write-Log "INFO" "Gateway:  http://127.0.0.1:$GatewayPort"
Write-Log "INFO" "Paperclip: http://127.0.0.1:$PaperclipPort"
Write-Log "INFO" "Check interval: ${CheckInterval}s | Restart delay: ${RestartDelay}s"
Write-Log "INFO" "Log: $LogPath"
Write-Log "INFO" "══════════════════════════════════════════════"

while ($true) {
    try {
        # ── Check Gateway ──
        $gwAlive = Test-ServiceAlive -Url $GatewayUrl -Name "Gateway"
        if (-not $gwAlive) {
            Restart-Gateway
        } else {
            if ($restartAttempts["Gateway"] -gt 0) { $restartAttempts["Gateway"] = 0 }
        }

        # ── Check Paperclip ──
        $pcAlive = Test-ServiceAlive -Url $PaperclipUrl -Name "Paperclip"
        if (-not $pcAlive) {
            Restart-Paperclip
        } else {
            if ($restartAttempts["Paperclip"] -gt 0) { $restartAttempts["Paperclip"] = 0 }
        }

    } catch {
        Write-Log "ERROR" "Watchdog loop error: $_"
    }

    Start-Sleep -Seconds $CheckInterval
}
