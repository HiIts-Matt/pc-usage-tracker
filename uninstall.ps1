# Stops the running tracker and removes its startup shortcut. Logs are left in place.
Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'UsageTracker.lnk') -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
    Where-Object { $_.CommandLine -like '*track.ps1*' -and $_.CommandLine -notlike '*-Summary*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Wait-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
