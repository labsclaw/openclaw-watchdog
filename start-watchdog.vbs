' OpenClaw Watchdog VBS Launcher
' Runs the PowerShell watchdog script hidden (no console window)

Dim shell, scriptPath, logPath
Set shell = CreateObject("WScript.Shell")

' Resolve script directory
scriptPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
logPath = scriptPath & "\watchdog.log"

' Run PowerShell script hidden
shell.Run "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & "\openclaw-watchdog.ps1""", 0, False
