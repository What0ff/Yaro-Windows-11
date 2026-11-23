# =============================================================================
#  Yaro - system-wide settings (part 1 of 2)
#  Runs as SYSTEM during Windows Setup (specialize pass), or as Administrator
#  on an already installed Windows via Yaro-Apply.cmd.
#  Log: C:\Windows\Setup\Scripts\Yaro\Specialize.log
# =============================================================================
param([switch]$Live)

# ---------------------------- Yaro options -----------------------------------
# $true = Yaro default, $false = keep the stock Windows behaviour.
$DisableDefender    = $true   # Microsoft Defender antivirus OFF (no built-in malware protection!)
$DisableSmartScreen = $true   # SmartScreen OFF
$SilentUAC          = $true   # admin programs elevate WITHOUT a confirmation window
$PauseUpdates       = $true   # Windows Update: no automatic installs, paused until 2077
$DisablePrinting    = $true   # print spooler OFF (printers will not work)
$DisableBtHandsFree = $true   # Bluetooth headset mic OFF (headphones stay in stereo in games)
$DisableVPN         = $true   # RasMan/RasAuto OFF (built-in Windows VPN will not work)
# -----------------------------------------------------------------------------

$ErrorActionPreference = 'Continue'
function R([string]$Key, [string]$Name, [string]$Data, [string]$Type = 'REG_DWORD') {
  & reg.exe add $Key /v $Name /t $Type /d $Data /f *> $null
  if ($LASTEXITCODE -ne 0) { "  FAIL  $Key\$Name" }
}
function Svc([string]$Name, [int]$Start) {
  $k = "HKLM\SYSTEM\CurrentControlSet\Services\$Name"
  & reg.exe query $k *> $null
  if ($LASTEXITCODE -eq 0) { R $k 'Start' "$Start" }
}
$LogDir = 'C:\Windows\Setup\Scripts\Yaro'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Start-Transcript -Path (Join-Path $LogDir 'Specialize.log') -Append | Out-Null
"Yaro Specialize.ps1 started $(Get-Date)  Live=$Live"

# ---------- 1. Store apps (removed for all users) ----------
"== Apps"
$Apps = @(
  'Microsoft.GamingApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxSpeechToTextOverlay',
  'Microsoft.BingSearch', 'Microsoft.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider',
  'Microsoft.WidgetsPlatformRuntime', 'MicrosoftWindows.Client.WebExperience',
  'Microsoft.WindowsMaps', 'Microsoft.MicrosoftStickyNotes', 'MicrosoftCorporationII.MicrosoftFamily',
  'Microsoft.ZuneVideo', 'Microsoft.WindowsCamera', 'Microsoft.ApplicationCompatibilityEnhancements',
  'Microsoft.WindowsAlarms', 'Microsoft.Getstarted', 'Microsoft.YourPhone', 'MSTeams', 'MicrosoftTeams',
  'Clipchamp.Clipchamp', 'Microsoft.PowerAutomateDesktop', 'Microsoft.Windows.DevHome',
  'Microsoft.WindowsFeedbackHub', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.BingNews',
  'Microsoft.BingWeather', 'MicrosoftWindows.CrossDevice', 'Microsoft.Edge.GameAssist',
  'AppUp.IntelGraphicsControlPanel', 'Microsoft.549981C3F5F10', 'Microsoft.MicrosoftOfficeHub',
  'Microsoft.OutlookForWindows', 'Microsoft.Todos', 'Microsoft.People', 'Microsoft.GetHelp',
  'Microsoft.WindowsSoundRecorder', 'MicrosoftCorporationII.QuickAssist'
)
Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -in $Apps } | ForEach-Object {
  "  remove provisioned $($_.DisplayName)"
  Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
}
if ($Live) {
  foreach ($a in $Apps) {
    Get-AppxPackage -AllUsers -Name $a -ErrorAction SilentlyContinue | ForEach-Object {
      "  remove installed $($_.Name)"
      Remove-AppxPackage -AllUsers -Package $_.PackageFullName -ErrorAction SilentlyContinue
    }
  }
}

# ---------- 2. Windows capabilities (Features on Demand) ----------
"== Capabilities"
$Caps = 'Hello.Face*', 'Browser.InternetExplorer*', 'App.StepsRecorder*', 'MathRecognizer*',
        'Media.WindowsMediaPlayer*', 'Language.Handwriting*', 'Language.Speech*', 'Print.Fax.Scan*',
        'OneCoreUAP.OneSync*', '*Wallpaper*', 'App.Support.QuickAssist*'
Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object {
  $n = $_.Name; $_.State -eq 'Installed' -and @($Caps | Where-Object { $n -like $_ }).Count
} | ForEach-Object {
  "  remove $($_.Name)"
  Remove-WindowsCapability -Online -Name $_.Name -ErrorAction SilentlyContinue | Out-Null
}

# ---------- 3. Optional features ----------
"== Optional features"
foreach ($f in 'SMB1Protocol', 'MicrosoftWindowsPowerShellV2Root', 'MicrosoftWindowsPowerShellV2',
               'Printing-XPSServices-Features', 'WorkFolders-Client', 'MSRDC-Infrastructure', 'MediaPlayback') {
  $s = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
  if ($s -and $s.State -eq 'Enabled') {
    "  disable $f"
    Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue | Out-Null
  }
}
# .NET Framework 3.5 from the install media (only if the media is still connected)
$sxs = Get-PSDrive -PSProvider FileSystem | ForEach-Object { Join-Path $_.Root 'sources\sxs' } |
       Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($sxs) {
  "  enable NetFx3 from $sxs"
  & dism.exe /Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess "/Source:$sxs" /NoRestart *> $null
}

# ---------- 4. Services ----------
"== Services"
foreach ($s in 'DiagTrack', 'dmwappushservice', 'MapsBroker', 'RetailDemo', 'CDPSvc', 'CDPUserSvc',
               'TermService', 'WSAIFabricSvc', 'PcaSvc', 'InventorySvc', 'TrkWks') { Svc $s 4 }
foreach ($s in 'WerSvc', 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc', 'RmSvc') { Svc $s 3 }
foreach ($s in 'SysMain', 'DPS') { Svc $s 2 }
if ($DisablePrinting)    { Svc 'Spooler' 4; Svc 'PrintNotify' 4 }
if ($DisableBtHandsFree) { Svc 'BTAGService' 4 }
if ($DisableVPN)         { Svc 'RasMan' 4; Svc 'RasAuto' 4 }
R 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' '1'

# ---------- 5. Setup, updates, telemetry, privacy ----------
"== Registry: setup, updates, privacy"
R 'HKLM\SYSTEM\CurrentControlSet\Control\BitLocker' 'PreventDeviceEncryption' '1'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE' 'DisableOOBEUpdate' '1'
R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE' 'DisableOOBEUpdate' '1'
R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE' 'HideOOBEUpdate' '1'
if ($PauseUpdates) {
  $ux = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
  R $ux 'PauseUpdatesExpiryTime' '2077-01-01T00:00:00Z' 'REG_SZ'
  R $ux 'PauseFeatureUpdatesStartTime' '2026-01-01T00:00:00Z' 'REG_SZ'
  R $ux 'PauseFeatureUpdatesEndTime' '2077-01-01T00:00:00Z' 'REG_SZ'
  R $ux 'PauseQualityUpdatesStartTime' '2026-01-01T00:00:00Z' 'REG_SZ'
  R $ux 'PauseQualityUpdatesEndTime' '2077-01-01T00:00:00Z' 'REG_SZ'
  R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoUpdate' '1'
}
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' '1'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' '0'
R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableCdp' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' '1'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Connect' 'AllowProjectionToPC' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\LiveCaptions' 'AllowLiveCaptions' '0'
R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'REG_SZ'
R 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}' 'SensorPermissionState' '0'
R 'HKLM\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration' 'Status' '0'
R 'HKLM\SYSTEM\Maps' 'AutoUpdateEnabled' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' '1'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\StorageSense' 'AllowStorageSenseGlobal' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' '1'
R 'HKLM\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' 'AllowWindowsInkWorkspace' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\PassportForWork' 'Enabled' '0'
R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun' '255'
R 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' '0'

# ---------- 6. Search (no web results, no WebView2 in Search) ----------
"== Registry: search"
$fm = 'HKLM\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides\8\1694661260'
R $fm 'EnabledState' '1'; R $fm 'EnabledStateOptions' '0'; R $fm 'Variant' '0'
R $fm 'VariantPayload' '0'; R $fm 'VariantPayloadKind' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'EnableDynamicContentInWSB' '0'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' '1'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' '0'

# ---------- 7. Fast installers and drivers (no 2-minute CRL hangs) ----------
"== Registry: installers and drivers"
foreach ($k in 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing',
               'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing',
               'HKU\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing') {
  R $k 'State' '0x00023c00'
}
foreach ($k in 'HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CertDllCreateCertificateChainEngine\Config',
               'HKLM\SOFTWARE\WOW6432Node\Microsoft\Cryptography\OID\EncodingType 0\CertDllCreateCertificateChainEngine\Config',
               'HKLM\SOFTWARE\Policies\Microsoft\SystemCertificates\ChainEngine\Config',
               'HKLM\SOFTWARE\WOW6432Node\Policies\Microsoft\SystemCertificates\ChainEngine\Config') {
  R $k 'ChainUrlRetrievalTimeoutMilliseconds' '200'
  R $k 'ChainRevAccumulativeUrlRetrievalTimeoutMilliseconds' '500'
}
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer' 'LimitSystemRestoreCheckpointing' '1'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' 'DontSearchWindowsUpdate' '1'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' 'SearchOrderConfig' '0'
R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig' '0'
R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork' '1'
R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings' 'DisableSendGenericDriverNotFoundToWER' '1'
R 'HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy' 'VerifiedAndReputablePolicyState' '0'

# ---------- 8. Performance, memory, file system ----------
"== Registry: performance"
R 'HKLM\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' '0xffffffff'
R 'HKLM\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '5000' 'REG_SZ'
R 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager' 'DisableWpbtExecution' '1'
R 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'DisablePagingExecutive' '1'
R 'HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' '1'
R 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' '0'
R 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' '0'
R 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' '2'
R 'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' '1'
R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager' 'ShippedWithReserves' '0'
R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense' '1'
R 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' '0xffffffff'
R 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' '0'
R 'HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' 'ActiveOverlayAcPowerScheme' 'ded574b5-45a0-4f42-8737-46345c09c238' 'REG_SZ'
R 'HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' 'ActiveOverlayDcPowerScheme' 'ded574b5-45a0-4f42-8737-46345c09c238' 'REG_SZ'
& fsutil.exe behavior set disablelastaccess 1 *> $null
& fsutil.exe 8dot3name set 1 *> $null
& dism.exe /Online /Set-ReservedStorageState /State:Disabled *> $null
[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine')

# ---------- 9. Explorer: "Open in Notepad" for every file ----------
try {
  $k = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey('SOFTWARE\Classes\*\shell\YaroOpenInNotepad')
  $k.SetValue('', 'Open in Notepad'); $k.SetValue('Icon', 'notepad.exe')
  $c = $k.CreateSubKey('command'); $c.SetValue('', 'notepad.exe "%1"'); $c.Close(); $k.Close()
} catch { "  FAIL Open in Notepad: $($_.Exception.Message)" }

# ---------- 10. Security options ----------
"== Security options"
if ($SilentUAC) { R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin' '0' }
if ($DisableSmartScreen) {
  R 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' '0'
  R 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled' 'Off' 'REG_SZ'
}
if ($DisableDefender) {
  $d = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'
  R $d 'DisableAntiSpyware' '1'
  R "$d\Real-Time Protection" 'DisableRealtimeMonitoring' '1'
  R "$d\Real-Time Protection" 'DisableBehaviorMonitoring' '1'
  R "$d\Real-Time Protection" 'DisableOnAccessProtection' '1'
  R "$d\Spynet" 'SpynetReporting' '0'
  R "$d\Spynet" 'SubmitSamplesConsent' '2'
  R 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray' 'HideSystray' '1'
  R 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications' 'DisableNotifications' '1'
  foreach ($s in 'WinDefend', 'WdNisSvc', 'Sense', 'WdFilter', 'WdBoot', 'WdNisDrv') { Svc $s 4 }
  if ($Live) { "  NOTE: on a running Windows turn off Tamper Protection first, otherwise Defender keeps its settings" }
}

# ---------- 11. Background scheduled tasks ----------
"== Scheduled tasks"
foreach ($t in '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
               '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp',
               '\Microsoft\Windows\Application Experience\MareBackup',
               '\Microsoft\Windows\Application Experience\PcaPatchDbTask',
               '\Microsoft\Windows\Application Experience\StartupAppTask',
               '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
               '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
               '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
               '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver',
               '\Microsoft\Windows\Maintenance\WinSAT') {
  & schtasks.exe /Change /TN $t /Disable *> $null
}

# ---------- 12. Intel telemetry (only if Intel software installed it) ----------
"== Intel telemetry cleanup"
& msiexec.exe /x '{420234D0-4C97-4B9F-B997-EC2AFDC5C695}' /qn /norestart *> $null
foreach ($s in 'ESRV_SVC_QUEENCREEK', 'USER_ESRV_SVC_QUEENCREEK', 'SystemUsageReportSvc_QUEENCREEK', 'Intel(R) SUR QC SAM', 'semav6msr64') {
  & sc.exe stop $s *> $null; & sc.exe delete $s *> $null
}
& schtasks.exe /Delete /TN 'USER_ESRV_SVC_QUEENCREEK' /F *> $null
foreach ($s in 'IntelTelemetryAgent', 'IntelCollectorService') { Svc $s 4 }

# ---------- 13. Default user profile (applies to every new user) ----------
"== Default user profile"
& reg.exe load 'HKU\YaroDefault' 'C:\Users\Default\NTUSER.DAT' *> $null
if ($LASTEXITCODE -eq 0) {
  R "HKU\YaroDefault\Control Panel\Desktop" 'MenuShowDelay' '0' 'REG_SZ'
  R "HKU\YaroDefault\Control Panel\Desktop" 'AutoEndTasks' '0' 'REG_SZ'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" 'TaskbarEndTask' '1' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\DirectX\UserGpuPreferences" 'DirectXUserGlobalSettings' 'SwapEffectUpgradeEnable=1;VRROptimizeEnable=1;' 'REG_SZ'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" 'AppsUseLightTheme' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" 'SystemUsesLightTheme' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'SeparateProcess' '1' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'TaskbarMn' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'ShowTaskViewButton' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'ShowCopilotButton' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\Search" 'SearchboxTaskbarMode' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\Search" 'BingSearchEnabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Policies\Microsoft\Windows\Explorer" 'DisableSearchBoxSuggestions' '1' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' '1' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\WinTrust\Trust Providers\Software Publishing" 'State' '0x00023c00' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\GameBar" 'AutoGameModeEnabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\System\GameConfigStore" 'GameDVR_Enabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'ContentDeliveryAllowed' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'OemPreInstalledAppsEnabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'PreInstalledAppsEnabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'PreInstalledAppsEverEnabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SilentInstalledAppsEnabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SoftLandingEnabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SystemPaneSuggestionsEnabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-310093Enabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-338388Enabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-338389Enabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-338393Enabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-353694Enabled' '0' 'REG_DWORD'
  R "HKU\YaroDefault\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-353696Enabled' '0' 'REG_DWORD'
  [gc]::Collect()
  & reg.exe unload 'HKU\YaroDefault' *> $null
} else { "  FAIL could not load C:\Users\Default\NTUSER.DAT" }

"Yaro Specialize.ps1 finished $(Get-Date)"
Stop-Transcript | Out-Null
