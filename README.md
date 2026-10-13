# pc-usage-tracker

Measures how much I use my personal PC, to apportion the work/personal use of a KVM switch
shared between that PC and my work laptop (ATO work-from-home deduction records).

## Method

- Every minute the tracker reads the time since the last keyboard/mouse input (`GetLastInputInfo`).
  A minute counts as active if there was input in the previous 5 minutes, so a PC left on but
  unattended doesn't count.
- When the KVM is switched to the work laptop, this PC receives no input. Active time on this PC
  is therefore personal use of the KVM setup.
- Work hours come from the configured work-from-home hours per week (Tue + Thu, 16 h).
- KVM work-use % = work / (work + personal).

Known biases:

- Watching video or gaming with a controller for more than 5 minutes without keyboard/mouse input
  isn't counted, which understates personal use.
- Each session gets up to 5 extra minutes after the last input, which overstates personal use.

## Usage

Start a 7-day period (writes config, adds a Startup-folder shortcut, launches hidden):

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -OutputDir '\\network-pi.tail67cc1f.ts.net\shared\tax-write-offs\2026-27\kvm-wfh-setup'
```

Options: `-WorkHoursPerWeek 16`, `-Days 7`, `-IdleThresholdSeconds 300`, `-Start <datetime>`.
To update the code mid-period, rerun with the original `-Start`. The period's log carries on.

Numbers so far:

```powershell
powershell -ExecutionPolicy Bypass -File track.ps1 -Summary
```

Stop early: `powershell -ExecutionPolicy Bypass -File uninstall.ps1`

## Data

- Local, authoritative: `%LOCALAPPDATA%\UsageTracker\`
  - `config.json`: the current period
  - `active-minutes_<start>.log`: one line per active minute
  - `versions_<start>.log`: each tracker launch, with the repo commit it ran
- Output folder (refreshed every 15 minutes while reachable, and at the end of the period):
  - `<start> to <end> PC usage summary.txt`
  - `<start> to <end> PC active minutes.log`

The summary lists the commits that produced the log. Logs are personal data and stay out of git.
At the end of the period the tracker removes its Startup shortcut.
