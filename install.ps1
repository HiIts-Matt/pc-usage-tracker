# Starts (or restarts) a tracking period: writes the config, installs the startup shortcut and
# launches the tracker hidden. Re-running with the same -Start resumes that period's log.
param(
    [Parameter(Mandatory)][string]$OutputDir,
    [double]$WorkHoursPerWeek = 16,
    [int]$Days = 7,
    [datetime]$Start = (Get-Date -Second 0 -Millisecond 0),
    [int]$IdleThresholdSeconds = 300
)

$ErrorActionPreference = 'Stop'
$stateDir = Join-Path $env:LOCALAPPDATA 'UsageTracker'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

& (Join-Path $PSScriptRoot 'uninstall.ps1')

[ordered]@{
    Start                = $Start.ToString('s')
    End                  = $Start.AddDays($Days).ToString('s')
    IdleThresholdSeconds = $IdleThresholdSeconds
    WorkHoursPerWeek     = $WorkHoursPerWeek
    OutputDir            = $OutputDir
} | ConvertTo-Json | Set-Content (Join-Path $stateDir 'config.json') -Encoding UTF8

$launchArgs = '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $PSScriptRoot 'track.ps1')
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'UsageTracker.lnk'))
$lnk.TargetPath = Join-Path $env:WINDIR 'System32\conhost.exe'
$lnk.Arguments  = $launchArgs
$lnk.Save()

Start-Process (Join-Path $env:WINDIR 'System32\conhost.exe') -ArgumentList $launchArgs
Get-Content (Join-Path $stateDir 'config.json')
