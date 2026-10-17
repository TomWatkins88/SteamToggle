# Steam Network Toggle
# Run it once to block Steam's internet access, run it again to restore it.
# Self-elevates to administrator because it manages Windows Firewall rules.

# --- Self-elevate to admin if not already ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    try {
        Start-Process powershell.exe -Verb RunAs -ErrorAction Stop `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } catch {
        Write-Host ""
        Write-Host "  Administrator permission is needed to change firewall rules." -ForegroundColor Yellow
        Write-Host "  Nothing was changed." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
    exit
}

# --- Keep window on top so it doesn't hide behind your game ---
try {
    Add-Type -ErrorAction Stop @"
using System;
using System.Runtime.InteropServices;
public static class SteamToggleWindow {
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    public static void TopMost() {
        // HWND_TOPMOST, with SWP_NOSIZE | SWP_NOMOVE | SWP_SHOWWINDOW
        SetWindowPos(GetForegroundWindow(), new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0040);
    }
}
"@
    [SteamToggleWindow]::TopMost()
} catch {}

# --- Window title and size ---
$host.UI.RawUI.WindowTitle = "Steam Toggle"
try {
    $host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(60, 14)
    $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(60, 14)
} catch {}

Clear-Host

function Write-Banner($text, $colour) {
    Write-Host ""
    Write-Host "  ======================================" -ForegroundColor $colour
    Write-Host "       $text" -ForegroundColor $colour
    Write-Host "  ======================================" -ForegroundColor $colour
    Write-Host ""
}

function Exit-AfterDelay([int]$seconds = 3) {
    Write-Host "   Closing in $seconds seconds..." -ForegroundColor DarkGray
    Start-Sleep -Seconds $seconds
    exit
}

# --- Config ---
$ruleGroup  = "SteamToggle"
$rulePrefix = "SteamToggle - Block"

# Earlier versions named rules "BlockSteam_1", "BlockSteam_2", ... with no group.
# Matched exactly so unrelated user rules are never touched.
function Get-ToggleRules {
    $grouped = Get-NetFirewallRule -Group $ruleGroup -ErrorAction SilentlyContinue
    $legacy  = Get-NetFirewallRule -DisplayName "BlockSteam_*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match '^BlockSteam_\d+$' }
    @($grouped) + @($legacy) | Where-Object { $_ }
}

function Get-SteamPath {
    $candidates = @(
        (Get-ItemProperty "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction SilentlyContinue).SteamPath,
        (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name InstallPath -ErrorAction SilentlyContinue).InstallPath,
        "${env:ProgramFiles(x86)}\Steam"
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path (Join-Path $path "steam.exe"))) {
            return [IO.Path]::GetFullPath($path)
        }
    }
    return $null
}

function Get-SteamPrograms($steamPath) {
    $programs = @(
        (Join-Path $steamPath "steam.exe"),
        (Join-Path $steamPath "bin\SteamService.exe"),
        "${env:ProgramFiles(x86)}\Common Files\Steam\steamservice.exe"
    )
    # steamwebhelper has moved between cef.win7x64 and cef.win64 folders over time
    $cefDir = Join-Path $steamPath "bin\cef"
    if (Test-Path $cefDir) {
        $programs += Get-ChildItem $cefDir -Recurse -Filter "steamwebhelper.exe" -ErrorAction SilentlyContinue |
            ForEach-Object FullName
    }
    $programs | Where-Object { Test-Path $_ } | Select-Object -Unique
}

# --- Toggle ---
$existing = Get-ToggleRules

if ($existing) {
    $existing | Remove-NetFirewallRule
    Write-Banner "STEAM UNBLOCKED" Green
    Write-Host "   Network access restored." -ForegroundColor White
    Write-Host "   Cloud saves will sync now." -ForegroundColor Gray
    Write-Host ""
    Exit-AfterDelay
}

$steamPath = Get-SteamPath
if (-not $steamPath) {
    Write-Banner "STEAM NOT FOUND" Yellow
    Write-Host "   Could not locate steam.exe. Nothing was changed." -ForegroundColor White
    Write-Host ""
    Exit-AfterDelay 6
}

try {
    foreach ($prog in Get-SteamPrograms $steamPath) {
        New-NetFirewallRule `
            -DisplayName "$rulePrefix ($([IO.Path]::GetFileName($prog)))" `
            -Group $ruleGroup `
            -Direction Outbound `
            -Program $prog `
            -Action Block `
            -Profile Any `
            -ErrorAction Stop | Out-Null
    }
} catch {
    # Roll back so Steam is never left half-blocked
    Get-ToggleRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    Write-Banner "BLOCK FAILED" Yellow
    Write-Host "   $($_.Exception.Message)" -ForegroundColor White
    Write-Host "   Nothing was changed." -ForegroundColor Gray
    Write-Host ""
    Exit-AfterDelay 8
}

Write-Banner "STEAM BLOCKED" Red
Write-Host "   Steam is offline. Tell your friend" -ForegroundColor White
Write-Host "   to launch the game now." -ForegroundColor White
Write-Host ""
Write-Host "   Run again to restore access." -ForegroundColor Gray
Write-Host ""
Exit-AfterDelay
