# =============================================================================
#  Yaro - puts the Yaro wallpaper on the desktop of the signed-in user.
#  Runs from FirstLogon.ps1 and once for every new user (RunOnce).
#  The image: C:\Windows\Web\Wallpaper\Yaro\yaro-wallpaper.png
# =============================================================================
$p = 'C:\Windows\Web\Wallpaper\Yaro\yaro-wallpaper.png'
if (-not (Test-Path -LiteralPath $p)) { return }
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'   # Fill
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'
Add-Type -Namespace Yaro -Name Desktop -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);'
[void][Yaro.Desktop]::SystemParametersInfo(0x14, 0, $p, 3)   # SPI_SETDESKWALLPAPER, save + notify
