# Logs minutes of human activity (keyboard/mouse input) on this PC, for apportioning the
# work/personal use of a KVM shared with a work laptop.
#
# Default: runs hidden until the configured end, mirroring the log and a summary to the output
# folder every 15 minutes, then removes its startup shortcut.
# -Summary: print the numbers so far without touching the running tracker.
param([switch]$Summary)

$ErrorActionPreference = 'Stop'
$stateDir     = Join-Path $env:LOCALAPPDATA 'UsageTracker'
$cfg          = Get-Content (Join-Path $stateDir 'config.json') -Raw | ConvertFrom-Json
$start        = [datetime]$cfg.Start
$end          = [datetime]$cfg.End
$periodKey    = $start.ToString('yyyy-MM-dd_HHmm')
$logPath      = Join-Path $stateDir "active-minutes_$periodKey.log"
$versionsPath = Join-Path $stateDir "versions_$periodKey.log"
$period       = '{0} to {1}' -f $start.ToString('yyyy-MM-dd'), $end.ToString('yyyy-MM-dd')
$shareSummary = Join-Path $cfg.OutputDir "$period PC usage summary.txt"
$shareLog     = Join-Path $cfg.OutputDir "$period PC active minutes.log"
$shortcut     = Join-Path ([Environment]::GetFolderPath('Startup')) 'UsageTracker.lnk'
$syncEvery    = [timespan]::FromMinutes(15)

function Get-CodeVersion {
    $ErrorActionPreference = 'Continue'
    try {
        $commit = git -C $PSScriptRoot rev-parse --short HEAD 2>$null
        if (-not $commit) { return "$PSScriptRoot (not a git checkout)" }
        $url   = git -C $PSScriptRoot remote get-url origin 2>$null
        $dirty = git -C $PSScriptRoot status --porcelain --untracked-files=no 2>$null
        return "$url @ $commit" + $(if ($dirty) { ' + uncommitted changes' } else { '' })
    } catch {
        return "$PSScriptRoot (git unavailable)"
    }
}

function Get-Report {
    $minutes = @()
    if (Test-Path $logPath) { $minutes = @(Get-Content $logPath | Where-Object { $_ } | Sort-Object -Unique) }
    $personal = $minutes.Count / 60
    $work     = [double]$cfg.WorkHoursPerWeek
    $lines = @(
        'Personal PC active-use log (for KVM work/personal apportionment)'
        "Period:  $($start.ToString('ddd yyyy-MM-dd HH:mm')) to $($end.ToString('ddd yyyy-MM-dd HH:mm'))"
        "Method:  checked every minute; a minute counts as active if there was keyboard/mouse input on this PC in the previous $($cfg.IdleThresholdSeconds / 60) minutes."
        '         While the KVM is switched to the work laptop this PC receives no input, so active time here = personal use of the KVM setup.'
        'Code:    tracker runs this period (started at / source @ commit):'
    )
    if (Test-Path $versionsPath) { $lines += Get-Content $versionsPath | ForEach-Object { "         $_" } }
    $lines += ''
    $lines += 'Active hours per day:'
    for ($d = $start.Date; $d -le $end.Date; $d = $d.AddDays(1)) {
        $key = $d.ToString('yyyy-MM-dd')
        $n = @($minutes | Where-Object { $_.StartsWith($key) }).Count
        $lines += '  {0}  {1,6:N2} h' -f $d.ToString('ddd yyyy-MM-dd'), ($n / 60)
    }
    $lines += ''
    $lines += 'Personal use (this PC):        {0,6:N2} h' -f $personal
    $lines += 'Work from home:                {0,6:N2} h' -f $work
    if ($personal + $work -gt 0) {
        $lines += 'KVM work-use percentage:       {0,6:N1} %  = work / (work + personal)' -f (100 * $work / ($work + $personal))
    }
    if ((Get-Date) -lt $end) { $lines += ''; $lines += "PERIOD IN PROGRESS (as of $((Get-Date).ToString('ddd yyyy-MM-dd HH:mm')))" }
    $lines
}

function Sync-ToShare {
    Get-Report | Set-Content -Path $shareSummary -Encoding UTF8
    Copy-Item $logPath $shareLog -Force
}

if ($Summary) { Get-Report; exit }

# Single instance: startup shortcut + manual launch must not double-log.
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\UsageTracker', [ref]$created)
if (-not $created) { exit }

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class IdleTime {
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
    public static uint Seconds() {
        var info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(info);
        if (!GetLastInputInfo(ref info)) return uint.MaxValue;
        return unchecked((uint)Environment.TickCount - info.dwTime) / 1000;
    }
}
'@

if (-not (Test-Path $logPath)) { New-Item -ItemType File -Path $logPath | Out-Null }
Add-Content -Path $versionsPath -Value ('{0}  {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm'), (Get-CodeVersion))

# The local log is authoritative; the share copy is refreshed whenever the share is reachable.
$lastLogged = ''
$lastSync = [datetime]::MinValue
while ((Get-Date) -lt $end) {
    $now = Get-Date
    if ($now -ge $start -and [IdleTime]::Seconds() -lt $cfg.IdleThresholdSeconds) {
        $minute = $now.ToString('yyyy-MM-dd HH:mm')
        if ($minute -ne $lastLogged) {
            Add-Content -Path $logPath -Value $minute
            $lastLogged = $minute
        }
    }
    if ($now - $lastSync -ge $syncEvery) {
        try { Sync-ToShare; $lastSync = $now } catch { }
    }
    Start-Sleep -Seconds 60
}

while ($true) {
    try { Sync-ToShare; break } catch { Start-Sleep -Seconds 600 }
}
Remove-Item $shortcut -ErrorAction SilentlyContinue
