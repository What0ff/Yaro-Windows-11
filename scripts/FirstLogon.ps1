# =============================================================================
#  Yaro - settings of the signed-in user, power plan, interrupts (part 2 of 2)
#  Runs at the first sign-in after Windows Setup, or via Yaro-Apply.cmd.
#  Log: C:\Windows\Setup\Scripts\Yaro\FirstLogon.log
# =============================================================================
$ErrorActionPreference = 'Continue'
function R([string]$Key, [string]$Name, [string]$Data, [string]$Type = 'REG_DWORD') {
  & reg.exe add $Key /v $Name /t $Type /d $Data /f *> $null
  if ($LASTEXITCODE -ne 0) { "  FAIL  $Key\$Name" }
}
$LogDir = 'C:\Windows\Setup\Scripts\Yaro'
New-Item -ItemType Directory -Force -Path $LogDir -ErrorAction SilentlyContinue | Out-Null
Start-Transcript -Path (Join-Path $LogDir 'FirstLogon.log') -Append -ErrorAction SilentlyContinue | Out-Null
"Yaro FirstLogon.ps1 started $(Get-Date) as $env:USERNAME"

"== Current user settings"
R "HKCU\Control Panel\Desktop" 'MenuShowDelay' '0' 'REG_SZ'
R "HKCU\Control Panel\Desktop" 'AutoEndTasks' '0' 'REG_SZ'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" 'TaskbarEndTask' '1' 'REG_DWORD'
R "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" 'DirectXUserGlobalSettings' 'SwapEffectUpgradeEnable=1;VRROptimizeEnable=1;' 'REG_SZ'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" 'AppsUseLightTheme' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" 'SystemUsesLightTheme' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'SeparateProcess' '1' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'TaskbarMn' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'ShowTaskViewButton' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'ShowCopilotButton' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" 'SearchboxTaskbarMode' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" 'BingSearchEnabled' '0' 'REG_DWORD'
R "HKCU\Software\Policies\Microsoft\Windows\Explorer" 'DisableSearchBoxSuggestions' '1' 'REG_DWORD'
R "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' '1' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing" 'State' '0x00023c00' 'REG_DWORD'
R "HKCU\Software\Microsoft\GameBar" 'AutoGameModeEnabled' '0' 'REG_DWORD'
R "HKCU\System\GameConfigStore" 'GameDVR_Enabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'ContentDeliveryAllowed' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'OemPreInstalledAppsEnabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'PreInstalledAppsEnabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'PreInstalledAppsEverEnabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SilentInstalledAppsEnabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SoftLandingEnabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SystemPaneSuggestionsEnabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-310093Enabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-338388Enabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-338389Enabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-338393Enabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-353694Enabled' '0' 'REG_DWORD'
R "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-353696Enabled' '0' 'REG_DWORD'
# Windows 10 style context menu
try {
  $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32')
  $k.SetValue('', ''); $k.Close()
} catch { "  FAIL classic context menu: $($_.Exception.Message)" }
# Folders: do not guess folder type (faster Explorer)
R 'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell' 'FolderType' 'NotSpecified' 'REG_SZ'

"== Power plan: Ultimate Performance, minimum CPU state 5%"
& powercfg.exe -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 e9a42b02-d5df-448d-aa00-03f14749eb62 *> $null
& powercfg.exe /setacvalueindex e9a42b02-d5df-448d-aa00-03f14749eb62 SUB_PROCESSOR PROCTHROTTLEMIN 5 *> $null
& powercfg.exe /setdcvalueindex e9a42b02-d5df-448d-aa00-03f14749eb62 SUB_PROCESSOR PROCTHROTTLEMIN 5 *> $null
& powercfg.exe -setactive e9a42b02-d5df-448d-aa00-03f14749eb62 *> $null

"== Memory compression"
Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue

"== MSI mode for GPU, NVMe and network adapters"
Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
  Where-Object { $_.Class -in 'Display', 'SCSIAdapter', 'Net' -and $_.InstanceId -like 'PCI\*' } |
  ForEach-Object {
    $k = 'HKLM:\SYSTEM\CurrentControlSet\Enum\' + $_.InstanceId + '\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
    if (Test-Path -LiteralPath $k) { Set-ItemProperty -LiteralPath $k -Name MSISupported -Value 1 -Type DWord; "  MSI on: $($_.FriendlyName)" }
  }

"== Leftover apps of the current user"
foreach ($a in 'Microsoft.Windows.DevHome', 'MicrosoftWindows.CrossDevice', 'Microsoft.Edge.GameAssist', 'AppUp.IntelGraphicsControlPanel',
               'Microsoft.Copilot', 'Microsoft.BingSearch', 'MicrosoftWindows.Client.WebExperience', 'Microsoft.OutlookForWindows') {
  Get-AppxPackage -Name $a -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
}

"== Wallpaper"
$Sw = Join-Path $LogDir 'SetWallpaper.ps1'
if ((Test-Path $Sw) -and (Test-Path 'C:\Windows\Web\Wallpaper\Yaro\yaro-wallpaper.png')) { & $Sw; "  set" } else { "  skipped (Yaro wallpaper is off)" }

"Yaro FirstLogon.ps1 finished $(Get-Date)"
Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
