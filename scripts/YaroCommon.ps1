# Shared settings and registry helpers for both Yaro stages.
# ---------------------------- Yaro options -----------------------------------
# $true applies the Yaro setting; $false skips it on this run.
$DisableDefender    = $true   # Microsoft Defender antivirus OFF (no built-in malware protection!)
$DisableSmartScreen = $true   # SmartScreen OFF
$SilentUAC          = $true   # admin programs elevate WITHOUT a confirmation window
$PauseUpdates       = $true   # Windows Update: no automatic installs, paused until 2077
$DisablePrinting    = $true   # print spooler OFF (printers will not work)
$DisableBtHandsFree = $true   # Bluetooth headset mic OFF (headphones stay in stereo in games)
$DisableVPN         = $true   # RasMan/RasAuto OFF (built-in Windows VPN will not work)
$SetWallpaper       = $true   # Yaro notebook wallpaper on the desktop of every user
# -----------------------------------------------------------------------------

$YaroLogDir = Join-Path $env:SystemRoot 'Setup\Scripts\Yaro'
$YaroWallpaperPath = Join-Path $env:SystemRoot 'Web\Wallpaper\Yaro\yaro-wallpaper.png'
$script:YaroFailures = 0

function Write-YaroFailure([string]$Message) {
  $script:YaroFailures++
  "  FAIL $Message"
}

function Get-YaroRegistryPath([string]$Key) {
  $hive, $subkey = $Key -split '\\', 2
  switch ($hive) {
    'HKLM' { "HKEY_LOCAL_MACHINE\$subkey" }
    'HKCU' { "HKEY_CURRENT_USER\$subkey" }
    'HKU' { "HKEY_USERS\$subkey" }
    default { throw "Unsupported registry path: $Key" }
  }
}

function Set-YaroRegistryValue([string]$Key, [string]$Name, [string]$Data, [ValidateSet('REG_DWORD', 'REG_SZ')][string]$Type = 'REG_DWORD') {
  try {
    $value = $Data
    $kind = [Microsoft.Win32.RegistryValueKind]::String
    if ($Type -eq 'REG_DWORD') {
      $kind = [Microsoft.Win32.RegistryValueKind]::DWord
      if ($Data.StartsWith('0x', [StringComparison]::OrdinalIgnoreCase)) {
        $value = [Convert]::ToInt32($Data.Substring(2), 16)
      } else {
        $value = [Convert]::ToInt32($Data, 10)
      }
    }
    [Microsoft.Win32.Registry]::SetValue((Get-YaroRegistryPath $Key), $Name, $value, $kind)
  } catch {
    Write-YaroFailure "$Key\$Name - $($_.Exception.Message)"
  }
}

function Merge-YaroGraphicsDefaults([string]$Settings) {
  foreach ($name in 'SwapEffectUpgradeEnable', 'VRROptimizeEnable') {
    if ($Settings -match "(?:^|;)\s*$name\s*=") { continue }
    if ($Settings -and -not $Settings.EndsWith(';')) { $Settings += ';' }
    $Settings += "$name=1;"
  }
  $Settings
}

function Set-YaroGraphicsDefaults([string]$UserHive) {
  $key = "$UserHive\Software\Microsoft\DirectX\UserGpuPreferences"
  $name = 'DirectXUserGlobalSettings'
  try {
    $current = [Microsoft.Win32.Registry]::GetValue((Get-YaroRegistryPath $key), $name, '')
    if ($null -ne $current -and $current -isnot [string]) {
      "  WARN unexpected registry value type for $name"
      return
    }
    $updated = Merge-YaroGraphicsDefaults $current
    if ($updated -cne $current) { Set-YaroRegistryValue $key $name $updated 'REG_SZ' }
  } catch {
    Write-YaroFailure "graphics preferences: $($_.Exception.Message)"
  }
}

function Set-YaroMachinePerformance {
  "== Power plan: Ultimate Performance, minimum CPU state 5%"
  $scheme = 'e9a42b02-d5df-448d-aa00-03f14749eb62'
  & powercfg.exe /query $scheme SUB_PROCESSOR *> $null
  $schemeAvailable = $LASTEXITCODE -eq 0
  if (-not $schemeAvailable) {
    & powercfg.exe /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $scheme *> $null
    $schemeAvailable = $LASTEXITCODE -eq 0
  }
  if ($schemeAvailable) {
    $configured = $true
    foreach ($command in '/setacvalueindex', '/setdcvalueindex') {
      & powercfg.exe $command $scheme SUB_PROCESSOR PROCTHROTTLEMIN 5 *> $null
      if ($LASTEXITCODE -ne 0) {
        $configured = $false
        Write-YaroFailure "powercfg $command (exit $LASTEXITCODE)"
      }
    }
    if ($configured) {
      & powercfg.exe /setactive $scheme *> $null
      if ($LASTEXITCODE -ne 0) { Write-YaroFailure "power plan activation (exit $LASTEXITCODE)" }
    }
  } else {
    Write-YaroFailure 'Ultimate Performance plan unavailable'
  }

  "== Memory compression"
  try { Enable-MMAgent -MemoryCompression -ErrorAction Stop }
  catch { Write-YaroFailure "memory compression: $($_.Exception.Message)" }
}

function Test-YaroOneDriveInactive {
  $sync = [Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\OneDrive', 'DisableFileSyncNGSC', $null)
  $reports = [Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\OneDrive', 'EnableSyncAdminReports', $null)
  return ($sync -eq 1 -and $reports -ne 1)
}

function Remove-YaroOneDriveStartup([string]$UserHive) {
  try {
    if (-not (Test-YaroOneDriveInactive)) { return }
    $policy = Get-YaroRegistryPath "$UserHive\Software\Policies\Microsoft\OneDrive"
    if ([Microsoft.Win32.Registry]::GetValue($policy, 'EnableAutoStart', $null) -eq 1) { return }

    $run = Get-YaroRegistryPath "$UserHive\Software\Microsoft\Windows\CurrentVersion\Run"
    $entries = @{ OneDriveSetup = @("$env:SystemRoot\System32\OneDriveSetup.exe") }
    if ($UserHive -eq 'HKCU') {
      $entries['OneDrive'] = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDrive.exe')
        foreach ($dir in $env:ProgramFiles, [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) {
          if ($dir) { Join-Path $dir 'Microsoft OneDrive\OneDrive.exe' }
        }
      )
    }
    foreach ($name in $entries.Keys) {
      $command = [Microsoft.Win32.Registry]::GetValue($run, $name, $null)
      if ($command -isnot [string]) { continue }
      $command = [Environment]::ExpandEnvironmentVariables($command).Trim()
      $argument = if ($name -eq 'OneDriveSetup') { '/thfirstsetup' } else { '/background' }
      foreach ($exe in $entries[$name]) {
        if ($command -in "$exe $argument", ('"{0}" {1}' -f $exe, $argument)) {
          Remove-ItemProperty -LiteralPath "Registry::$run" -Name $name -ErrorAction Stop
          "  removed $name startup (OneDrive sync is blocked)"
          break
        }
      }
    }
  } catch { Write-YaroFailure "OneDrive startup ($UserHive): $($_.Exception.Message)" }
}

function Set-YaroUserPolicies([string]$UserHive) {
  Set-YaroRegistryValue "$UserHive\Software\Policies\Microsoft\Windows\Explorer" 'DisableSearchBoxSuggestions' '1' 'REG_DWORD'
  Set-YaroRegistryValue "$UserHive\Software\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' '1' 'REG_DWORD'
}
