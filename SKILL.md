---
name: watchdog
description: "Auto-recovery monitor for OpenClaw Gateway + Paperclip services on Windows"
---

# OpenClaw Watchdog

Monitor and auto-restart OpenClaw Gateway and Paperclip on Windows.

## Behavior

- **Check**: Every 60s via HTTP health check
- **Restart**: Immediate on failure (no delay)
- **Scope**: Gateway (18789) + Paperclip (3100)

## Files

```
watchdog/
├── SKILL.md
├── openclaw-watchdog.ps1   ← main loop
├── start-watchdog.vbs       ← hidden VBS launcher
├── install.ps1              ← setup
└── watchdog.log             ← auto-generated
```

## Install

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```
