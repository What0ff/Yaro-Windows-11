<p align="center"><img src="assets/yaro-banner.png" alt="Yaro — Windows 11, distilled" width="100%"></p>

# Yaro — lean Windows 11 from the official ISO

**English** | [Русский](README.ru.md)

Yaro turns a clean install of the **official** Windows 11 into a lean, quiet and fast system:
no ads and pre-installed junk apps, minimal telemetry, fewer background services, tuned for
games and development (Python, WSL2, Docker).

This repository contains **no Windows files**. You download Windows from Microsoft; Yaro is just
an answer file (`autounattend.xml`) and two PowerShell scripts that apply the changes during setup.

> [!WARNING]
> By default Yaro **turns off Microsoft Defender, SmartScreen, UAC prompts, automatic updates,
> printing, Bluetooth headset microphone and the built-in VPN**. Read
> [What Yaro turns off](#what-yaro-turns-off) and [Options](#options) before installing.
> Try it in a virtual machine first. Use at your own risk.

## Files

| File | What it is |
|---|---|
| `autounattend.xml` | Answer file for a clean install. The scripts are embedded inside it. |
| `Yaro-Apply.cmd` | Applies Yaro to an already installed Windows 11. |
| `scripts/Specialize.ps1` | System-wide changes: apps, components, services, registry. |
| `scripts/FirstLogon.ps1` | Settings of the user, power plan, MSI mode for GPU/NVMe/network. |
| `assets/` | Banner, logo, GitHub social preview and 1920×1080 notebook-paper wallpapers: white, cream, yellow, grid and a realistic textured paper. |

## Clean install (recommended)

1. **Download Windows 11** from [microsoft.com/software-download/windows11](https://www.microsoft.com/software-download/windows11):
   *Download Windows 11 Disk Image (ISO) for x64 devices*, language **English (United States)**.
   For another language, replace `en-US` with its code (for example `ru-RU`) in the
   `UILanguage`, `SystemLocale` and `UserLocale` lines of `autounattend.xml`.
2. **Optional:** open `autounattend.xml` in Notepad and change
   - `<TimeZone>UTC</TimeZone>` — your time zone, e.g. `FLE Standard Time` (Kyiv, Sofia),
     `Russian Standard Time` (Moscow), `Central European Standard Time` (Warsaw);
   - `<Name>User</Name>` — the name of the local account;
   - the [Options](#options) (search for `Yaro options`).
3. **Make a USB stick** (8 GB or more) with [Rufus](https://rufus.ie): partition scheme **GPT**,
   target system **UEFI**. When Rufus shows the *Windows User Experience* window, **untick
   everything**. Then copy `autounattend.xml` to the **root** of the USB stick.
4. **Boot from the USB stick.** The only question is which disk/partition to install to —
   choose carefully, the formatted partition is erased. Everything else is automatic,
   the PC restarts several times.
5. **After the first sign-in**
   - install drivers (chipset, graphics, Wi-Fi) from the manufacturer's site — Yaro turns off
     driver downloads through Windows Update, so keep the Wi-Fi/LAN driver on the USB stick;
   - check the logs in `C:\Windows\Setup\Scripts\Yaro\` — lines with `FAIL` show what did not apply;
   - after installing Intel drivers you can run `Yaro-Apply.cmd` once more: it removes the
     Intel telemetry that Intel software installs.
6. **Activate Windows with your own key:** Settings › System › Activation › Change product key.
   The key in `autounattend.xml` is Microsoft's generic *install* key: it only selects the
   **Pro** edition and does not activate. For a Home license, replace it with the generic
   Home key `YTMG3-N6DKC-DKB77-7M9GH-8HVX7`.

## Apply to an installed Windows

1. *Code › Download ZIP*, unpack the archive.
2. If you want Defender off, first turn off **Tamper Protection**
   (Windows Security › Virus & threat protection › Manage settings).
3. Run `Yaro-Apply.cmd` (it asks for administrator rights itself). It creates a restore point
   if System Protection is on, applies everything and writes logs to `C:\Windows\Setup\Scripts\Yaro\`.
4. Restart Windows.

## Options

At the top of `Specialize.ps1` (inside `autounattend.xml` for a clean install,
`scripts/Specialize.ps1` for `Yaro-Apply.cmd`). `$true` is the Yaro default,
`$false` keeps the normal Windows behaviour.

| Option | What `$true` does |
|---|---|
| `$DisableDefender` | Turns off Microsoft Defender antivirus and hides its tray icon |
| `$DisableSmartScreen` | Turns off SmartScreen for downloaded files and apps |
| `$SilentUAC` | Programs get administrator rights without a confirmation window |
| `$PauseUpdates` | No automatic updates, updates paused until 2077 |
| `$DisablePrinting` | Turns off the print spooler |
| `$DisableBtHandsFree` | Turns off the Bluetooth hands-free profile: headphones stay in stereo in games, their microphone is not used |
| `$DisableVPN` | Turns off RasMan/RasAuto (the built-in Windows VPN and dial-up) |

## What Yaro changes

### What Yaro turns off
- Microsoft Defender, SmartScreen, Smart App Control, UAC prompts *(options)*.
- Memory integrity / VBS (core isolation), automatic BitLocker device encryption.
- Automatic Windows Update and driver downloads through Windows Update.
- Printing, Bluetooth hands-free, built-in VPN *(options)*, incoming Remote Desktop.
- Location, telemetry, activity history, advertising and suggested apps, Copilot, widgets,
  Bing in Start search, OneDrive sync, Game Bar and game recording, PowerShell and .NET CLI telemetry.

### Removed apps
Xbox app and Game Bar, Copilot, Bing Search, Widgets, Maps, Sticky Notes, Family, Movies & TV,
Camera, Alarms & Clock, Tips, Phone Link, Teams, Clipchamp, Power Automate, Dev Home,
Feedback Hub, Solitaire, News, Weather, Cross Device, Edge Game Assist, Cortana, Office hub,
new Outlook, To Do, People, Get Help, Sound Recorder, Quick Assist, old Intel Graphics panel.
**Kept:** Microsoft Store, App Installer (winget), Terminal, Notepad, Paint, Calculator,
Snipping Tool, Photos, Media Player, Edge, media codecs. Anything removed can be installed again
from the Store.

### Removed components
Windows Hello face, Internet Explorer mode, Steps Recorder, Math Recognizer, legacy Windows Media
Player, handwriting and speech recognition, Fax and Scan, extra wallpapers. Turned off: SMB1,
PowerShell 2.0, XPS printing, Work Folders, Remote Differential Compression, legacy media
playback. **Added:** .NET Framework 3.5 (from the USB stick, if it is still connected).

### Services
Disabled: DiagTrack, dmwappushservice, MapsBroker, RetailDemo, CDPSvc, CDPUserSvc, TermService,
WSAIFabricSvc, PcaSvc, InventorySvc, TrkWks (+ Spooler, PrintNotify, BTAGService, RasMan, RasAuto,
Defender services when the options are on). Manual: WerSvc, Xbox services, RmSvc.
Automatic: SysMain, DPS. Background compatibility, CEIP, disk diagnostic and WinSAT
scheduled tasks are disabled.

### Performance
- Service host grouping (fewer `svchost.exe` processes), memory compression on.
- Kernel kept in RAM, no background power throttling, reserved storage off.
- NTFS last-access time and 8.3 short names off, long paths (> 260 characters) allowed.
- Hardware-accelerated GPU scheduling, optimizations for windowed games, variable refresh rate.
- MSI mode for GPU, NVMe and network adapters.
- Power: *Ultimate Performance* plan with minimum CPU state 5 %, *Best performance* power mode.
  On a laptop this costs battery life.
- No network throttling for multimedia, Edge does not preload in the background.
- Installers and drivers do not hang for 2 minutes on certificate checks
  (short certificate download timeouts).

### Interface
Dark theme, Windows 10 context menu, *Open in Notepad* for every file, *End task* on the taskbar,
no Search/Task view/Chat/Copilot buttons, instant menus, folders open in a separate process,
English interface with English and Russian keyboards, developer mode on.

### Setup
Hardware checks (TPM, Secure Boot, CPU, RAM, storage) are skipped. No EULA, network, Microsoft
account and privacy screens; one local administrator `User` without a password; random computer name.

## How to undo common changes

Run in **Command Prompt as administrator**, then restart Windows.

| What | Command |
|---|---|
| Printing | `sc config Spooler start= auto` and `sc config PrintNotify start= demand` |
| Bluetooth headset microphone | `sc config BTAGService start= demand` |
| Built-in VPN | `sc config RasMan start= demand` and `sc config RasAuto start= demand` |
| UAC prompts | `reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 5 /f` |
| Automatic updates | `reg delete HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /v NoAutoUpdate /f`, then Settings › Windows Update › *Resume updates* |
| Windows 11 context menu | `reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f` |
| Removed apps | Install them from Microsoft Store |

Defender and SmartScreen are best kept by setting `$DisableDefender = $false` /
`$DisableSmartScreen = $false` **before** installing.

## Troubleshooting

- **"Windows could not parse or process the unattend answer file"** — the file was damaged while
  editing. Download it again and repeat only the changes you need.
- **Setup stops with a language error** — the ISO language does not match `en-US` in the file
  (see step 1).
- **No internet after install** — install the network driver from the manufacturer's site.
- **Something was not applied** — look for `FAIL` in `C:\Windows\Setup\Scripts\Yaro\Specialize.log`
  and `FirstLogon.log`.

## Notes

- Yaro grew out of the author's own Windows 11 build used daily on a laptop with Intel Core
  i7-9750H and GeForce RTX 2060. The answer-file version for the official ISO is new —
  test it in a virtual machine (Hyper-V, VirtualBox) before your main PC.
- Not affiliated with Microsoft. Windows is a trademark of Microsoft Corporation.
  This repository contains no Microsoft software and no activation tools.
- License: [MIT](LICENSE).
