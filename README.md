# SteamToggle

A one-click switch that cuts Steam's internet access, then restores it on the next click.

It works by adding (or removing) Windows Firewall rules that block Steam's own processes from making outbound connections. Your games themselves are not blocked, and nothing about your Steam install is modified.

## Why?

The usual reason is **Steam Family Sharing**: while the library owner's Steam client is online and playing, a family member can't play a shared game at the same time. Taking the owner's Steam offline at the firewall lets both play.

It's also handy any time you want Steam to stop syncing, updating or showing you as online without fully closing it.

## Usage

1. Download `SteamToggle.bat` and `SteamToggle.ps1` and keep them **in the same folder**.
2. Double-click `SteamToggle.bat`.
3. Accept the Windows administrator prompt (needed to change firewall rules).

A small window appears on top of your game to show the result, then closes after a few seconds:

| State | Meaning |
| --- | --- |
| **STEAM BLOCKED** | Steam can no longer reach the internet. |
| **STEAM UNBLOCKED** | The rules have been removed; Steam reconnects and cloud saves sync. |

Run it again at any time to flip back.

> **Tip:** Remember to unblock when you're done. Cloud saves won't upload while Steam is blocked.

## What it blocks

The script finds your Steam install automatically (via the registry, falling back to the default location) and blocks outbound traffic for:

- `steam.exe`
- `steamwebhelper.exe` (the Steam UI/browser process)
- `SteamService.exe` / `steamservice.exe`

Only files that actually exist on your system get a rule.

## How it works

- All rules are created in a firewall rule group called **SteamToggle**, so the script only ever touches its own rules.
- If any rule fails to be created, everything is rolled back so Steam is never left half-blocked.
- You can inspect or remove the rules manually in **Windows Defender Firewall with Advanced Security → Outbound Rules**, or with PowerShell:

  ```powershell
  Get-NetFirewallRule -Group SteamToggle
  Remove-NetFirewallRule -Group SteamToggle   # run as administrator
  ```

## Requirements

- Windows 10 or 11
- Windows Defender Firewall enabled (third-party firewalls that replace it will ignore these rules)
- Administrator rights

## Notes

- Steam may take a minute to notice it has lost its connection and switch to offline behaviour. Starting Steam in offline mode first, or restarting it after blocking, gives the most reliable result.
- The `.bat` file only exists to launch the PowerShell script with the right execution policy; you can also right-click `SteamToggle.ps1` and choose **Run with PowerShell**.
- Using this tool is at your own risk. Check that what you're doing is in line with Steam's terms for your situation.

## Licence

[MIT](LICENSE)
