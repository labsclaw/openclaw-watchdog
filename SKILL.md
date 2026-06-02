---
name: watchdog
description: "Auto-recovery monitor for OpenClaw Gateway + Paperclip services on Windows"
---

# OpenClaw Watchdog Skill

Monitor and auto-restart OpenClaw Gateway and Paperclip services on Windows.

## What it does

- Checks every 10s if Gateway (port 18789) and Paperclip (port 3100) are alive
- Auto-restarts any service that goes down (3s recheck delay)
- Logs all events with rotation (keeps last 1MB)
- Installs as Windows startup task
- Runs hidden in background via VBS launcher

## Architecture

```
watchdog/
├── SKILL.md              ← you are here
├── openclaw-watchdog.ps1 ← main monitor loop
├── install.ps1           ← install/uninstall
├── start-watchdog.vbs    ← silent VBS launcher
└── watchdog.log          ← auto-generated log
```

## Install

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

This will:
1. Copy files to `%LOCALAPPDATA%\openclaw-watchdog\`
2. Create startup entry
3. Launch the watchdog

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

## Monitoring logic

Each cycle (every 10s):
1. **Gateway check**: HTTP GET `http://127.0.0.1:18789/` → if fails, restart
2. **Paperclip check**: HTTP GET `http://127.0.0.1:3100/api/health` → if fails, restart via PM2
3. **Process fallback**: If HTTP check unreachable, verify by process name

## Restart strategy

- Gateway: `openclaw gateway restart` via CLI
- Paperclip: `pm2 restart paperclip` (or `npx paperclipai server` fallback)
- 3-second delay before restart to avoid rapid cycling
- Max 3 consecutive restart attempts before backing off 30s

## Dependencies

- Windows 10+ (tested on build 22621)
- PowerShell 5.0+
- OpenClaw CLI (global npm)
- PM2 (optional, for Paperclip)

## Files

### `openclaw-watchdog.ps1`
The core monitor. Runs an infinite loop with health checks.

### `install.ps1`
One-command setup. Parameters:
- `-Uninstall`: remove from startup and stop watchdog
- `-WatchdogPath`: custom install path (default: `%LOCALAPPDATA%\openclaw-watchdog`)

### `start-watchdog.vbs`
Launches the PowerShell script hidden (no console window).
