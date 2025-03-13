Add-Type -AssemblyName PresentationFramework

# Hide Console Window
$dllvar = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
add-type -name win -member $dllvar -namespace native
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)

if ((Get-WinSystemLocale).Name -eq 'ru-RU')
{
    $global:Lang = 'RUS'
}
else
{
    $global:Lang = 'ENG'
}

while ($true)
{
    Get-BitsTransfer | Remove-BitsTransfer

    if ($global:NeedReset -eq $false)
    {
        exit
    }

    $global:NeedReset = $false
    $global:Errors = @()

    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    # For talking across runspaces.
    $sync = [Hashtable]::Synchronized(@{ })

    # Script location path
    $sync.rootPath = split-path -parent $MyInvocation.MyCommand.Definition

    # Deck version (LCD or OLED)
    $sync.version = 'LCD'

    function Install-Wlan
    {
        $RootPath = $sync.rootPath

        if ($sync.version -eq "LCD")
        {
            Start-Process -FilePath ($sync.rootPath + "\wlan_driver\lcd\install.bat") -Wait
        }

        else
        {
            if ((Get-WmiObject Win32_OperatingSystem).Caption -Match "Windows 11")
            {
                Start-Process -FilePath "PNPUtil.exe" -ArgumentList "/add-driver `"$RootPath\wlan_driver\oled_11\qcwlan64.inf`" /install" -Wait
            }

            else
            {
                Start-Process -FilePath "PNPUtil.exe" -ArgumentList "/add-driver `"$RootPath\wlan_driver\oled_10\qcwlan64.inf`" /install" -Wait
            }
        }

        [System.Windows.Forms.MessageBox]::Show("WI-FI driver installed")
    }

    Function Set-Orientation
    {
        $pinvokeCode = @"
using System;
using System.Runtime.InteropServices;
namespace Resolution
{
    [StructLayout(LayoutKind.Sequential)]

    public struct DEVMODE
    {
       [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)]
       public string dmDeviceName;
       public short  dmSpecVersion;
       public short  dmDriverVersion;
       public short  dmSize;
       public short  dmDriverExtra;
       public int    dmFields;
       public int    dmPositionX;
       public int    dmPositionY;
       public int    dmDisplayOrientation;
       public int    dmDisplayFixedOutput;
       public short  dmColor;
       public short  dmDuplex;
       public short  dmYResolution;
       public short  dmTTOption;
       public short  dmCollate;
       [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
       public string dmFormName;
       public short  dmLogPixels;
       public short  dmBitsPerPel;
       public int    dmPelsWidth;
       public int    dmPelsHeight;
       public int    dmDisplayFlags;
       public int    dmDisplayFrequency;
       public int    dmICMMethod;
       public int    dmICMIntent;
       public int    dmMediaType;
       public int    dmDitherType;
       public int    dmReserved1;
       public int    dmReserved2;
       public int    dmPanningWidth;
       public int    dmPanningHeight;
    };
    class NativeMethods
    {
        [DllImport("user32.dll")]
        public static extern int EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
        [DllImport("user32.dll")]
        public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);
        public const int ENUM_CURRENT_SETTINGS = -1;
        public const int CDS_UPDATEREGISTRY = 0x01;
        public const int CDS_TEST = 0x02;
        public const int DISP_CHANGE_SUCCESSFUL = 0;
        public const int DISP_CHANGE_RESTART = 1;
        public const int DISP_CHANGE_FAILED = -1;
        public const int DMDO_DEFAULT = 0;
        public const int DMDO_90 = 1;
        public const int DMDO_180 = 2;
        public const int DMDO_270 = 3;
    }
    public class PrmaryScreenResolution
    {
        static public string ChangeResolution()
        {
            DEVMODE dm = GetDevMode();
            if (0 != NativeMethods.EnumDisplaySettings(null, NativeMethods.ENUM_CURRENT_SETTINGS, ref dm))
            {
                // swap width and height
                int temp = dm.dmPelsHeight;
                dm.dmPelsHeight = dm.dmPelsWidth;
                dm.dmPelsWidth = temp;
                // determine new orientation based on the current orientation

                dm.dmDisplayOrientation = NativeMethods.DMDO_270;

                int iRet = NativeMethods.ChangeDisplaySettings(ref dm, NativeMethods.CDS_TEST);
                if (iRet == NativeMethods.DISP_CHANGE_FAILED)
                {
                    return "Unable To Process Your Request. Sorry For This Inconvenience.";
                }
                else
                {
                    iRet = NativeMethods.ChangeDisplaySettings(ref dm, NativeMethods.CDS_UPDATEREGISTRY);
                    switch (iRet)
                    {
                        case NativeMethods.DISP_CHANGE_SUCCESSFUL:
                            {
                                return "Success";
                            }
                        case NativeMethods.DISP_CHANGE_RESTART:
                            {
                                return "You Need To Reboot For The Change To Happen.\n If You Feel Any Problem After Rebooting Your Machine\nThen Try To Change Resolution In Safe Mode.";
                            }
                        default:
                            {
                                return "Failed To Change The Resolution";
                            }
                    }
                }
            }
            else
            {
                return "Failed To Change The Resolution.";
            }
        }
        private static DEVMODE GetDevMode()
        {
            DEVMODE dm = new DEVMODE();
            dm.dmDeviceName = new String(new char[32]);
            dm.dmFormName = new String(new char[32]);
            dm.dmSize = (short)Marshal.SizeOf(dm);
            return dm;
        }
    }
}
"@
        Add-Type $pinvokeCode -ErrorAction SilentlyContinue
        [Resolution.PrmaryScreenResolution]::ChangeResolution()
    }

    # long running task.
    $counter = {

        $sync.Tabs.Enabled = $false
        $sync.BrowseButton.Enabled = $false
        $sync.OSKeyboardButton.Enabled = $false
        $sync.OrientationButton.Enabled = $false
        $sync.StartButton.Enabled = $false
        $sync.LangComboBox.Enabled = $false

        $count = [PowerShell]::Create().AddScript({

            #Scroll textbox text to bottom
            $sync.TextBox.Add_TextChanged({
                $sync.TextBox.SelectionStart = $sync.TextBox.TextLength
                $sync.TextBox.ScrollToCaret()
            })

            function Is-Download-Selected
            {
                foreach ($Node in ($sync.MustTree_Node_VideoDriver, $sync.MustTree_Node_AudioDriver,
                $sync.MustTree_Node_BluetoothDriver, $sync.MustTree_Node_CardReaderDriver, $sync.MustTree_Node_Vc,
                $sync.MustTree_Node_DirectX, $sync.MustTree_Node_DotNet, $sync.MustTree_Node_Rtss, $sync.MustTree_Node_Adrenalin,
                $sync.MustTree_Node_Cru, $sync.MustTree_Node_DeckTools, $sync.TweaksTree_Node_Osk, $sync.TweaksTree_Node_Equalizer,
                $sync.SoftTree_Node_Steam, $sync.SoftTree_Node_Chrome, $sync.SoftTree_Node_7zip, $sync.SoftTree_Node_ShareX))
                {

                    if ($Node.Checked -eq $true)
                    {
                        return $true
                    }
                }
                return $false
            }

            function Is-Configure-Selected
            {
                if ($sync.MustTree_Node_Rtss.Checked -or $sync.MustTree_Node_DeckTools.Checked)
                {
                    return $true
                }
                else
                {
                    return $false
                }
            }

            function Is-Tweak-Selected
            {

                foreach ($Node in ($sync.MustTree_Node_Hibernation, $sync.MustTree_Node_Utc, $sync.TweaksTree_Node_GameBar, $sync.TweaksTree_Node_LoginSleep, $sync.TweaksTree_Node_ShowKeyboard))
                {
                    if ($Node.Checked -eq $true)
                    {
                        return $true
                    }
                }
                return $false
            }

            Function Set-Scale
            {
                $source = @"
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfo(
                uint uiAction,
                uint uiParam,
                uint pvParam,
                uint fWinIni);
"@
                $apicall = Add-Type -MemberDefinition $source -Name WinAPICall -Namespace SystemParamInfo -PassThru
                $apicall::SystemParametersInfo(0x009F, 4294967295, $null, 1) | Out-Null
            }

            function Report-Error
            {
                param ([String]$Error,
                    [String]$Name)

                Out-File -FilePath ($sync.rootPath + "\windeckhelper_errors.log") -Append -InputObject ((Get-Date -Format "MM/dd/yyyy HH:mm - ") + $Name + " - " + $Error)

                $sync.Textbox.AppendText($sync.ErrorString)

                if ($global:Errors -notlike "*$Name*")
                {
                    $global:Errors += $Name + "`n"
                }
            }

            function Start-Process-With-Timeout
            {
                param (
                    [string]$FilePath,
                    [string]$Arguments
                )
                $proc = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru
                $proc | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timeouted

                if ($timeouted)
                {
                    # terminate the process
                    $proc | kill
                    throw "Timeout error!"
                }
            }

            function Get-GitHubReleaseAsset {
                param (
                    [string]$owner,          # Владелец репозитория .
                    [string]$repo,           # Имя репозитория
                    [string]$patternTemplate = ".*{version}.*", # Шаблон для поиска файла (с плейсхолдером {version})
                    [bool]$trimVersion = $true, # Удалять ли символ 'v' из версии
                    [ref]$result # Параметр для возврата ссылки на скачивание
                )

                # URL для получения последнего релиза
                $url = "https://api.github.com/repos/$owner/$repo/releases/latest"

                # Заголовки для запроса
                $headers = @{
                    "Accept" = "application/vnd.github.v3+json"
                    "User-Agent" = "WindeckHelper/1.0"
                }

                try {
                    # Выполняем запрос к GitHub API
                    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
                } catch {
                    # Обрабатываем ошибку HTTP-запроса
                    $result.Value = $null
                    return $false
                }

                # Получаем версию релиза (tag_name)
                $version = $response.tag_name

                # Убираем символ 'v' из версии, если trimVersion = $true
                if ($trimVersion) {
                    $version = $version -replace '^v', ''
                }

                # Заменяем плейсхолдер {version} в паттерне на фактическую версию
                $pattern = $patternTemplate -replace "{version}", [regex]::Escape($version)

                # Ищем asset, который соответствует паттерну
                $matchingAsset = $response.assets | Where-Object { $_.name -match $pattern }

                # Проверяем, найден ли подходящий asset
                if ($matchingAsset) {
                    $downloadUrl = $matchingAsset.browser_download_url
                    $result.Value = $downloadUrl # Возвращаем ссылку через параметр [ref]
                    return $true # Файл найден
                } else {
                    $result.Value = $null # Очищаем значение
                    return $false # Файл не найден
                }
            }

            $DownloadPath = $sync.DownloadPath

            function Download-File
            {
                param (
                    [string]$Name,
                    [String]$Url,
                    [String]$Output
                )

                $TextboxText = $sync.TextBox.Text

                $DownloadText = $TextboxText + "`r`n - " + $sync.DownloadingString + " $Name" + ": "

                $TransferJob = Start-BitsTransfer -Asynchronous $Url "$DownloadPath\$Output"

                $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                while (($Stopwatch.elapsed -lt (New-TimeSpan -Seconds 30)) -and ($TransferJob.JobState -ne "Transferring") -and ($TransferJob.JobState -ne "Transferred"))
                {
                    $sync.Textbox.Text = ($DownloadText)
                }

                if ($TransferJob.JobState -eq "Transferring")
                {
                    if ($TransferJob.BytesTotal/1MB -gt 1)
                    {
                        $unit = 1MB
                    }
                    else
                    {
                        $unit = 1KB
                    }
                    while ($TransferJob.JobState -eq "Transferring")
                    {
                        $progressInt = ((($TransferJob.BytesTransferred/$unit) / ($TransferJob.BytesTotal/$unit)) * 100)

                        [string]$progressBar = "|" + "|" * ($progressInt / 3)
                        $sync.Textbox.Text = ("$DownloadText $progressBar " + ($progressInt.Tostring("0")) + "%")
                    }
                }

                Switch ($TransferJob.JobState)
                {
                    "Transferred" {
                        Complete-BitsTransfer -BitsJob $TransferJob
                        $sync.Textbox.Text = ($DownloadText + $sync.DoneString)
                    }
                    Default {
                        $sync.Textbox.Text = ($DownloadText)
                        Report-Error -Error 'Download Error!' -Name $Name
                    }
                }
            }

            if ((Is-Download-Selected) -or (Is-Tweak-Selected))
            {
                $sync.Textbox.Text = ''
            }

            #Install Drivers certificate
            if ($sync.MustTree_Node_VideoDriver.Checked -or $sync.MustTree_Node_AudioDriver.Checked -or $sync.MustTree_Node_BluetoothDriver.Checked -or $sync.MustTree_Node_CardReaderDriver.Checked)
            {
                certutil -enterprise -f -v -AddStore "TrustedPublisher" ($sync.rootPath + "\drivers.cer")
            }

            if (Is-Download-Selected)
            {
                # MustHave Download
                $sync.Textbox.AppendText("`r`n" + $sync.DownloadingTitleString + "`r`n")

                if ($sync.MustTree_Node_VideoDriver.Checked)
                {
                    if ($sync.version -eq "LCD")
                    {
                        Download-File -Name $sync.VideoDriverString -Url "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/Aerith%20Windows%20Driver_2302270303.zip" -Output "APU_Drivers.zip"
                    }
                    else
                    {
                        Download-File -Name $sync.VideoDriverString -Url "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/GFX_Driver_48.0.8.40630.zip" -Output "APU_Drivers.zip"
                    }
                }
                if ($sync.MustTree_Node_AudioDriver.Checked)
                {
                    if ($sync.version -eq "LCD")
                    {
                        Download-File -Name ($sync.AudioDriverString + " 1/2 (cs35l41)") -Url "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/cs35l41-V1.2.1.0.zip" -Output "Audio_Drivers_1.zip"
                        Download-File -Name ($sync.AudioDriverString + " 2/2 (NAU88L21)") -Url "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/NAU88L21_x64_1.0.6.0_WHQL%20-%20DUA_BIQ_WHQL.zip" -Output "Audio_Drivers_2.zip"
                    }
                    else
                    {
                        Download-File -Name ($sync.AudioDriverString + " 1/3 (cs35l41)") -Url "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/Audio1_cs35l41-V1.2.1.0.zip" -Output "Audio_Drivers_1.zip"
                        Download-File -Name ($sync.AudioDriverString + " 2/3 (NAU88L21)") -Url "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/Audio2_NAU88L21_x64_1.0.9.1_WHQL.zip" -Output "Audio_Drivers_2.zip"
                        Download-File -Name ($sync.AudioDriverString + " 3/3 (amdi2scodec)") -Url "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/amdampdriver.zip" -Output "Audio_Drivers_3.zip"
                    }

                }

                if ($sync.MustTree_Node_BluetoothDriver.Checked)
                {
                    if ($sync.version -eq "LCD")
                    {
                        Download-File -Name $sync.BluetoothDriverString -Url "https://catalog.s.download.windowsupdate.com/d/msdownload/update/driver/drvs/2022/08/ad501382-9e48-4720-92c7-bcee5374671e_501f5f234304610bbbc221823de181e544c1bc09.cab" -Output "Bluetooth_Drivers.cab"
                    }

                    else
                    {
                        Download-File -Name $sync.BluetoothDriverString -Url "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/FC66E-B_WIN_Bluetooth_driver.zip" -Output "Bluetooth_Drivers.zip"
                    }
                }

                if ($sync.MustTree_Node_CardReaderDriver.Checked)
                {
                    Download-File -Name $sync.CardReaderDriverString -Url "https://catalog.s.download.windowsupdate.com/c/msdownload/update/driver/drvs/2022/10/4f20ec00-bee5-4df2-873c-3a49cf4d4f8b_0aaf931a756473e6f8be1ef890fb60c283e9e82e.cab" -Output "MicroSD_Drivers.cab"
                }

                if ($sync.MustTree_Node_Vc.Checked)
                {
                    Download-File -Name $sync.VcString -Url "https://github.com/abbodi1406/vcredist/releases/download/v0.83.0/VisualCppRedist_AIO_x86_x64_83.zip" -Output "VCpp.zip"
                }

                if ($sync.MustTree_Node_DirectX.Checked)
                {
                    Download-File -Name $sync.DirectXString -Url "https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe" -Output "DirectX.exe"
                }

                if ($sync.MustTree_Node_DotNet.Checked)
                {
                    Download-File -Name $sync.DotNetString -Url "https://download.visualstudio.microsoft.com/download/pr/61881ecd-a425-4053-a420-7f76586d2f60/6daf1af8c05df332eb1c53261fafc07f/dotnet-sdk-6.0.425-win-x64.exe" -Output "dotnet6.0_Setup.exe"
                }

                if ($sync.MustTree_Node_Rtss.Checked)
                {
                    Download-File -Name $sync.RtssString -Url "https://ftp.nluug.nl/pub/games/PC/guru3d/afterburner/[Guru3D.com]-RTSS.zip" -Output "RivaTuner.zip"
                }

                if ($sync.MustTree_Node_Adrenalin.Checked)
                {
                    if ($sync.version -eq "LCD")
                    {
                        Download-File -Name $sync.AdrenalinString -Url "https://dl.dropboxusercontent.com/s/kex95hyhnkjdqsp/ccc2_install.exe?dl=0" -Output "ccc2_install.exe"
                    }

                    else
                    {
                        Download-File -Name $sync.AdrenalinString -Url "https://dl.dropboxusercontent.com/scl/fi/l4t3ti6i250mfo7wx5czv/Adrenalin_24_10_2.exe?rlkey=rwyid4h9cqp8k8kaxq6kstzj1&st=c4umnpt9&dl=1" -Output "ccc2_install.exe"
                    }

                }

                if ($sync.MustTree_Node_Cru.Checked)
                {
                    Download-File -Name $sync.CruString -Url "https://www.monitortests.com/download/cru/cru-1.5.2.zip" -Output "cru-1.5.2.zip"
                    Download-File -Name $sync.CruConfigString -Url "https://dl.dropboxusercontent.com/s/w8mmt7uvzmcaemx/cru-steamdeck.bin?dl=0" -Output "cru-steamdeck.bin"
                }
                if ($sync.MustTree_Node_DeckTools.Checked)
                {
                    Download-File -Name $sync.VigemBusString -Url "https://github.com/ViGEm/ViGEmBus/releases/download/v1.21.442.0/ViGEmBus_1.21.442_x64_x86_arm64.exe" -Output "ViGEmBus_Setup.exe"
                    $steamDeckToolsLink = $null;
                    if (Get-GitHubReleaseAsset -owner "mops1k" -repo "steam-deck-tools" -patternTemplate "SteamDeckTools-{version}-portable\.zip" -trimVersion $true -result ([ref]$steamDeckToolsLink)) {
                        Download-File -Name $sync.DeckToolsString -Url "$steamDeckToolsLink" -Output "SteamDeckTools.zip"
                    }
                    elseif(Get-GitHubReleaseAsset -owner "ayufan" -repo "steam-deck-tools" -patternTemplate "SteamDeckTools-{version}-portable\.zip" -trimVersion $true -result ([ref]$steamDeckToolsLink)) {
                        Download-File -Name $sync.DeckToolsString -Url "$steamDeckToolsLink" -Output "SteamDeckTools.zip"
                    } else {
                        Download-File -Name $sync.DeckToolsString -Url "https://github.com/ayufan/steam-deck-tools/releases/download/0.7.3/SteamDeckTools-0.7.3-portable.zip" -Output "SteamDeckTools.zip"
                    }
                }

                #Tweaks Download

                if ($sync.TweaksTree_Node_Osk.Checked)
                {
                    Download-File -Name $sync.OskString -Url "https://dl.dropboxusercontent.com/s/hapygmbsfuko4ms/ReplaceOSK.bat?dl=0" -Output "ReplaceOSK.bat"

                }

                if ($sync.TweaksTree_Node_Equalizer.Checked)
                {
                    Download-File -Name $sync.EqualizerString -Url "https://netix.dl.sourceforge.net/project/equalizerapo/1.3/EqualizerAPO64-1.3.exe" -Output "EqualizerAPO_Setup.exe"

                }

                #Soft Download

                if ($sync.SoftTree_Node_Steam.Checked)
                {
                    Download-File -Name $sync.SteamString -Url "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe" -Output "SteamSetup.exe"

                }

                if ($sync.SoftTree_Node_Chrome.Checked)
                {
                    Download-File -Name $sync.ChromeString -Url "https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7B04F50E1E-55EF-FA8E-646E-26A38F938B79%7D%26lang%3Den%26browser%3D3%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Dempty/chrome/install/ChromeStandaloneSetup64.exe" -Output "ChromeStandaloneSetup64.exe"

                }

                if ($sync.SoftTree_Node_7zip.Checked)
                {
                    Download-File -Name $sync.SevenZipString -Url "https://7-zip.org/a/7z2201-x64.exe" -Output "7z2201-x64.exe"

                }

                if ($sync.SoftTree_Node_ShareX.Checked)
                {
                    Download-File -Name $sync.ShareXString -Url "https://github.com/ShareX/ShareX/releases/download/v15.0.0/ShareX-15.0.0-setup.exe" -Output "ShareX-15.0.0-setup.exe"

                }

                #Must-Have Install

                $sync.Textbox.AppendText("`r`n`r`n" + $sync.InstallingTitleString + "`r`n")

                if ($sync.MustTree_Node_VideoDriver.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.VideoDriverString + " : "
                        Expand-Archive "$DownloadPath\APU_Drivers.zip" -DestinationPath "$DownloadPath\APU_Drivers" -Force
                        if ($sync.version -eq "LCD")
                        {
                            Start-Process-With-Timeout -FilePath "$DownloadPath\APU_Drivers\GFX Driver_41.1.1.30310_230227a-388790E-2302270303\Setup.exe" -Arguments "-install"
                        }
                        else
                        {
                            Start-Process-With-Timeout -FilePath "$DownloadPath\APU_Drivers\GFX_DriverGFX Driver_48.0.8.40630\Setup.exe" -Arguments "-install"
                        }
                        Set-Scale | Out-Null
                        Set-Orientation | Out-Null
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.VideoDriverString
                    }
                }

                if ($sync.MustTree_Node_AudioDriver.Checked)
                {
                    if ($sync.version -eq "LCD")
                    {
                        try
                        {
                            $Name = ($sync.AudioDriverString + " 1/2 (cs35l41)")
                            $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $Name + " : "
                            Expand-Archive "$DownloadPath\Audio_Drivers_1.zip" "$DownloadPath\Audio_Drivers_1" -Force
                            Start-Process-With-Timeout -FilePath "PNPUtil.exe" -Arguments "/add-driver `"$DownloadPath\Audio_Drivers_1\cs35l41-V1.2.1.0\cs35l41.inf`" /install"
                            $sync.Textbox.AppendText($sync.DoneString)
                        }

                        catch
                        {
                            Report-Error -Error $_.Exception.Message -Name $Name
                        }

                        try
                        {
                            $Name = ($sync.AudioDriverString + " 2/2 (NAU88L21)")
                            $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $Name + " : "
                            Expand-Archive "$DownloadPath\Audio_Drivers_2.zip" "$DownloadPath\Audio_Drivers_2" -Force
                            Start-Process-With-Timeout -FilePath "PNPUtil.exe" -Arguments "/add-driver `"$DownloadPath\Audio_Drivers_2\NAU88L21_x64_1.0.6.0_WHQL - DUA_BIQ_WHQL\NAU88L21.inf`" /install"
                            $sync.Textbox.AppendText($sync.DoneString)
                        }

                        catch
                        {
                            Report-Error -Error $_.Exception.Message -Name $Name
                        }
                    }

                    else
                    {
                        try
                        {
                            $Name = ($sync.AudioDriverString + " 1/3 (cs35l41)")
                            $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $Name + " : "
                            Expand-Archive "$DownloadPath\Audio_Drivers_1.zip" "$DownloadPath\Audio_Drivers_1" -Force
                            Start-Process-With-Timeout -FilePath "PNPUtil.exe" -Arguments "/add-driver `"$DownloadPath\Audio_Drivers_1\cs35l41-V1.2.1.0\cs35l41.inf`" /install"
                            $sync.Textbox.AppendText($sync.DoneString)
                        }

                        catch
                        {
                            Report-Error -Error $_.Exception.Message -Name $Name
                        }

                        try
                        {
                            $Name = ($sync.AudioDriverString + " 2/3 (NAU88L21)")
                            $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $Name + " : "
                            Expand-Archive "$DownloadPath\Audio_Drivers_2.zip" "$DownloadPath\Audio_Drivers_2" -Force
                            Start-Process-With-Timeout -FilePath "PNPUtil.exe" -Arguments "/add-driver `"$DownloadPath\Audio_Drivers_2\NAU88L21_x64_1.0.9.1_WHQL\NAU88L21.inf`" /install"
                            $sync.Textbox.AppendText($sync.DoneString)
                        }

                        catch
                        {
                            Report-Error -Error $_.Exception.Message -Name $Name
                        }

                        try
                        {
                            $Name = ($sync.AudioDriverString + " 3/3 (amdi2scodec)")
                            $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $Name + " : "
                            Expand-Archive "$DownloadPath\Audio_Drivers_3.zip" "$DownloadPath\Audio_Drivers_3" -Force
                            Start-Process-With-Timeout -FilePath "PNPUtil.exe" -Arguments "/add-driver `"$DownloadPath\Audio_Drivers_3\amdampdriver\amdi2scodec.inf`" /install"
                            $sync.Textbox.AppendText($sync.DoneString)
                        }

                        catch
                        {
                            Report-Error -Error $_.Exception.Message -Name $Name
                        }
                    }
                }

                #                if ($sync.MustTree_Node_NetworkDriver.Checked)
                #                {
                #                    try
                #                    {
                #                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.NetworkDriverString + " : "
                #                        New-Item $DownloadPath\WLAN_Drivers -ItemType Directory -ErrorAction SilentlyContinue >> $null
                #                        Start-Process-With-Timeout -FilePath "expand.exe" -Arguments "-F:* $DownloadPath\WLAN_Drivers.cab $DownloadPath\\WLAN_Drivers"
                #                        Start-Process-With-Timeout -FilePath "PNPUtil.exe" -Arguments "/add-driver `"$DownloadPath\WLAN_Drivers\netrtwlane.inf`" /install"
                #                        $sync.Textbox.AppendText($sync.DoneString)
                #                    }
                #
                #                    catch
                #                    {
                #                        Report-Error -Error $_.Exception.Message -Name $sync.NetworkDriverString
                #                    }
                #                }

                if ($sync.MustTree_Node_BluetoothDriver.Checked)
                {


                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.BluetoothDriverString + " : "

                        if ($sync.version -eq "LCD")
                        {
                            New-Item $DownloadPath\Bluetooth_Drivers -ItemType Directory -ErrorAction SilentlyContinue >> $null
                            Start-Process-With-Timeout -FilePath "expand.exe" -Arguments "-F:* $DownloadPath\Bluetooth_Drivers.cab $DownloadPath\Bluetooth_Drivers"
                            Start-Process-With-Timeout -FilePath "PNPUtil.exe" -Arguments "/add-driver `"$DownloadPath\Bluetooth_Drivers\Rtkfilter.inf`" /install"
                        }

                        else
                        {
                            Expand-Archive "$DownloadPath\Bluetooth_Drivers.zip" "$DownloadPath\Bluetooth_Drivers" -Force
                            Start-Process-With-Timeout -FilePath "PNPUtil.exe" -Arguments "/add-driver `"$DownloadPath\Bluetooth_Drivers\FC66E-B_WIN_Bluetooth_driver\BT\x64\qcbtuart.inf`" /install"
                        }

                        $sync.Textbox.AppendText($sync.DoneString)

                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.BluetoothDriverString
                    }
                }




                if ($sync.MustTree_Node_CardReaderDriver.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.CardReaderDriverString + " : "
                        New-Item $DownloadPath\MicroSD_Drivers -ItemType Directory -ErrorAction SilentlyContinue >> $null
                        Start-Process-With-Timeout -FilePath "expand.exe" -Arguments "-F:* $DownloadPath\MicroSD_Drivers.cab $DownloadPath\MicroSD_Drivers"
                        Start-Process-With-Timeout -FilePath "PNPUtil.exe" -Arguments "/add-driver `"$DownloadPath\MicroSD_Drivers\bhtsddr.inf`" /install"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.CardReaderDriverString
                    }
                }

                if ($sync.MustTree_Node_Vc.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.VcString + " : "
                        Expand-Archive "$DownloadPath\VCpp.zip" -DestinationPath "$DownloadPath\Vcpp" -Force
                        Start-Process-With-Timeout -FilePath "$DownloadPath\Vcpp\VisualCppRedist_AIO_x86_x64.exe" -Arguments "/ai"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.VcString
                    }
                }

                if ($sync.MustTree_Node_DirectX.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.DirectXString + " : "
                        Start-Process-With-Timeout -FilePath "$DownloadPath\DirectX.exe" -Arguments "/Q"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.DirectXString
                    }
                }

                if ($sync.MustTree_Node_DotNet.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.DotNetString + " : "
                        Start-Process-With-Timeout -FilePath "$DownloadPath\dotnet6.0_Setup.exe" -Arguments "/quiet /norestart"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.DotNetString
                    }
                }

                if ($sync.MustTree_Node_Rtss.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.RtssString + " : "
                        Expand-Archive "$DownloadPath\RivaTuner.zip" -DestinationPath "$DownloadPath\RivaTuner" -Force
                        Start-Process-With-Timeout -FilePath "$DownloadPath\RivaTuner\RTSSSetup736.exe" -Arguments "/S"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.RtssString
                    }
                }


                if ($sync.MustTree_Node_Adrenalin.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.AdrenalinString + " : "
                        Start-Process-With-Timeout -FilePath "$DownloadPath\ccc2_install.exe" -Arguments "/S"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.AdrenalinString
                    }
                }

                if ($sync.MustTree_Node_Cru.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.CruString + " : "
                        $cruPath = "$Env:Programfiles\Custom Resolution Utility"
                        New-Item "$Env:Programfiles" -ItemType Directory -Name "Custom Resolution Utility" -ErrorAction SilentlyContinue >> $null
                        Expand-Archive "$DownloadPath\cru-1.5.2.zip" $cruPath -Force
                        Copy-Item "$DownloadPath\cru-steamdeck.bin" -Destination $cruPath -Force
                        Start-Process "$cruPath\CRU.exe"
                        Start-Process ($sync.rootPath + "\cruAhk.exe") -Wait
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.CruString
                    }
                }
                if ($sync.MustTree_Node_DeckTools.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.VigemBusString + " : "
                        Start-Process-With-Timeout -FilePath "$DownloadPath\ViGEmBus_Setup.exe" -Arguments "/qn /norestart"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.VigemBusString
                    }

                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.DeckToolsString + " : "
                        New-Item "$Env:Programfiles" -ItemType Directory -Name "SteamDeckTools" -ErrorAction SilentlyContinue >> $null
                        Expand-Archive "$DownloadPath\SteamDeckTools.zip" "$Env:Programfiles\SteamDeckTools" -Force
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.DeckToolsString
                    }
                }

                if ($sync.TweaksTree_Node_Osk.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.OskString + " : "
                        Start-Process -FilePath "$DownloadPath\ReplaceOSK.bat" -Wait
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.OskString
                    }
                }

                if ($sync.TweaksTree_Node_Equalizer.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.EqualizerString + " : "
                        Start-Process -FilePath "$DownloadPath\EqualizerAPO_Setup.exe" -ArgumentList "/S"
                        Start-Process ($sync.rootPath + "\apoAhk.exe") -Wait
                        Copy-Item "$DownloadPath\EqualizerAPO_Config.txt" -Destination "$Env:Programfiles\EqualizerAPO\config\config.txt" -Force
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.EqualizerString
                    }
                }

                #Soft Install

                if ($sync.SoftTree_Node_Steam.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.SteamString + " : "
                        Start-Process-With-Timeout -FilePath "$DownloadPath\SteamSetup.exe" -Arguments "/S"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.SteamString
                    }
                }

                if ($sync.SoftTree_Node_Chrome.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.ChromeString + " : "
                        Start-Process-With-Timeout -FilePath "$DownloadPath\ChromeStandaloneSetup64.exe" -Arguments "/silent /install"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.ChromeString
                    }
                }

                if ($sync.SoftTree_Node_7zip.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.SevenZipString + " : "
                        Start-Process-With-Timeout -FilePath "$DownloadPath\7z2201-x64.exe" -Arguments "/S"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.SevenZipString
                    }
                }


                if ($sync.SoftTree_Node_ShareX.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.InstallingString + $sync.ShareXString + " : "
                        Start-Process-With-Timeout -FilePath "$DownloadPath\ShareX-15.0.0-setup.exe" -Arguments "/VERYSILENT /NORESTART /NORUN"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.ShareXString
                    }
                }
            }


            if (Is-Configure-Selected)
            {
                $sync.Textbox.AppendText("`r`n`r`n" + $sync.ConfiguringTitleString + "`r`n")

                if ($sync.MustTree_Node_Rtss.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.ConfiguringString + $sync.RtssString + " : "
                        $trigger = New-ScheduledTaskTrigger -AtLogOn
                        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                        $action = New-ScheduledTaskAction -Execute "$Env:ProgramFiles (x86)\RivaTuner Statistics Server\RTSS.exe"
                        $description = "Start RivaTuner at Login"
                        Register-ScheduledTask -TaskName "RivaTuner" -Action $action -Trigger $trigger -RunLevel Highest -Description $description -Settings $settings >> $null
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.RtssString
                    }
                }


                if ($sync.MustTree_Node_DeckTools.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.ConfiguringString + $sync.DeckToolsString + " : "
                        # Setting FanControl to run on login
                        Start-Process -FilePath "$Env:Programfiles\SteamDeckTools\FanControl.exe" -ArgumentList "-run-on-startup"
                        # Setting PerformanceOverlay to run on login
                        Start-Process -FilePath "$Env:Programfiles\SteamDeckTools\PerformanceOverlay.exe" -ArgumentList "-run-on-startup"
                        # Setting PowerControl to run on login
                        Start-Process -FilePath "$Env:Programfiles\SteamDeckTools\PowerControl.exe" -ArgumentList "-run-on-startup"
                        # Setting SteamController to run on login
                        Start-Process -FilePath "$Env:Programfiles\SteamDeckTools\SteamController.exe" -ArgumentList "-run-on-startup"
                        # Creating Desktop Shortcuts for SteamDeckTools
                        $DesktopPath = [Environment]::GetFolderPath('Desktop')
                        $shell = New-Object -comObject WScript.Shell
                        $shortcut = $shell.CreateShortcut("$DesktopPath\Fan Control.lnk")
                        $shortcut.TargetPath = "$Env:Programfiles\SteamDeckTools\FanControl.exe"
                        $shortcut.Save()

                        $shell = New-Object -comObject WScript.Shell
                        $shortcut = $shell.CreateShortcut("$DesktopPath\Performance Overlay.lnk")
                        $shortcut.TargetPath = "$Env:Programfiles\SteamDeckTools\PerformanceOverlay.exe"
                        $shortcut.Save()

                        $shell = New-Object -comObject WScript.Shell
                        $shortcut = $shell.CreateShortcut("$DesktopPath\Power Control.lnk")
                        $shortcut.TargetPath = "$Env:Programfiles\SteamDeckTools\PowerControl.exe"
                        $shortcut.Save()

                        $shell = New-Object -comObject WScript.Shell
                        $shortcut = $shell.CreateShortcut("$DesktopPath\Steam Controller.lnk")
                        $shortcut.TargetPath = "$Env:Programfiles\SteamDeckTools\SteamController.exe"
                        $shortcut.Save()
                        $sync.Textbox.AppendText($sync.DoneString)
                    }

                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.DeckToolsString
                    }
                }
            }

            if (Is-Tweak-Selected)
            {
                $sync.Textbox.AppendText("`r`n`r`n" + $sync.TweakingTitleString + "`r`n")

                if ($sync.MustTree_Node_Hibernation.Checked)
                {
                    try
                    {

                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.HibernationString + " : "
                        Start-Process -FilePath "PowerCfg" -ArgumentList " /h off" -Wait
                        $sync.Textbox.AppendText($sync.DoneString)
                    }
                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.HibernationString
                    }
                }

                if ($sync.MustTree_Node_Utc.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.UtcString + " : "
                        Start-Process -FilePath "reg" -ArgumentList "add `"HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation`" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f" -Wait
                        $sync.Textbox.AppendText($sync.DoneString)
                    }
                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.UtcString
                    }

                }

                if ($sync.TweaksTree_Node_GameBar.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.GameBarString + " : "
                        reg add HKCR\ms-gamebar /f /ve /d URL:ms-gamebar 2>&1 > ''
                        reg add HKCR\ms-gamebar /f /v "URL Protocol" /d " " 2>&1 > ''
                        reg add HKCR\ms-gamebar /f /v "NoOpenWith" /d " " 2>&1 > ''
                        reg add HKCR\ms-gamebar\shell\open\command /f /ve /d "\`"$env:SystemRoot\System32\systray.exe\`"" 2>&1 > ''
                        reg add HKCR\ms-gamebarservices /f /ve /d URL:ms-gamebarservices 2>&1 > ''
                        reg add HKCR\ms-gamebarservices /f /v "URL Protocol" /d " " 2>&1 > ''
                        reg add HKCR\ms-gamebarservices /f /v "NoOpenWith" /d " " 2>&1 > ''
                        reg add HKCR\ms-gamebarservices\shell\open\command /f /ve /d "\`"$env:SystemRoot\System32\systray.exe\`"" 2>&1 > ''
                        $sync.Textbox.AppendText($sync.DoneString)
                    }
                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.GameBarString
                    }

                }

                if ($sync.TweaksTree_Node_LoginSleep.Checked)
                {
                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.LoginSleepString + " : "
                        Start-Process -FilePath "PowerCfg" -ArgumentList "/SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0"
                        Start-Process -FilePath "PowerCfg" -ArgumentList "/SETDCVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0"
                        $sync.Textbox.AppendText($sync.DoneString)
                    }
                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.LoginSleepString
                    }

                }

                if ($sync.TweaksTree_Node_ShowKeyboard.Checked)
                {

                    try
                    {
                        $sync.Textbox.Text = $sync.Textbox.Text + "`r`n - " + $sync.ShowKeyboardString + " : "
                        Start-Process -FilePath "reg" -ArgumentList "add `"HKEY_CURRENT_USER\SOFTWARE\Microsoft\TabletTip\1.7`" /t REG_DWORD /v EnableDesktopModeAutoInvoke /d 1 /f" -Wait
                        $sync.Textbox.AppendText($sync.DoneString)
                    }
                    catch
                    {
                        Report-Error -Error $_.Exception.Message -Name $sync.ShowKeyboardString
                    }
                }
            }

            if ((Is-Download-Selected) -or (Is-Tweak-Selected))
            {
                if ($global:Errors.Count -gt 0)
                {
                    if ([System.Windows.MessageBox]::Show($sync.FinishErrors1String + $global:Errors + $sync.FinishErrors2String + ($sync.rootPath + "\windeckhelper_errors.log"), 'WinDeckHelper', 'YesNo') -eq 'Yes')
                    {

                        foreach ($item in (Get-Content ($sync.rootPath + "\windeckhelper_errors.log") -Encoding UTF8))
                        {
                            $log = $log + "`n" + $item

                        }

                        [System.Windows.MessageBox]::Show($log, "WinDeckHelper")
                    }
                }

                else
                {
                    if ([System.Windows.MessageBox]::Show($sync.FinishSuccessString, 'WinDeckHelper', 'YesNo') -eq 'Yes')
                    {
                        Restart-Computer
                    }
                }

            }

            $sync.Tabs.Enabled = $true
            $sync.BrowseButton.Enabled = $true
            $sync.OSKeyboardButton.Enabled = $true
            $sync.OrientationButton.Enabled = $true
            $sync.StartButton.Enabled = $true
            $sync.LangComboBox.Enabled = $true

        })

        # Adding Set-Orientation function to the Runspace
        $initialSessionState = [InitialSessionState]::CreateDefault()
        $definition = Get-Content Function:\Set-Orientation -ErrorAction Stop
        $addMessageSessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList 'Set-Orientation', $definition
        $initialSessionState.Commands.Add($addMessageSessionStateFunction)

        $runspace = [RunspaceFactory]::CreateRunspace($initialSessionState)
        $runspace.ApartmentState = "STA"
        $runspace.ThreadOptions = "ReuseThread"
        $runspace.Open()
        $runspace.SessionStateProxy.SetVariable("sync", $sync)

        $count.Runspace = $runspace
        $count.BeginInvoke()
    }

    #Localization

    switch ($global:Lang)
    {
        "ENG"
        {
            $SelectAllString = 'Select all'
            #Controls
            $MustHavePageString = 'Must-Have'
            $TweaksPageString = 'Tweaks'
            $SoftPageString = 'Soft'
            $DownPathLabelString = 'Download files to:'
            $BrowseButtonString = 'Browse...'
            $StartButtonString = 'START'
            $CancelButtonString = 'CANCEL'
            $WlanButtonString = 'Install WI-FI Driver'
            $OSKeyboardButtonString = 'Open On-Screen Keyboard'
            $OrientationButtonString = 'Change Screen Orientation'
            #Must-Have
            $DriversString = 'Drivers'
            $sync.VideoDriverString = 'Video driver'
            $sync.AudioDriverString = 'Audio driver'
            $sync.NetworkDriverString = 'Wi-Fi driver'
            $sync.BluetoothDriverString = 'Bluetooth driver'
            $sync.CardReaderDriverString = 'SDcard reader driver'
            $sync.HibernationString = 'Disable hibernation'
            $sync.UtcString = 'Set internal clock to UTC'
            $sync.CruConfigString = 'Custom Resolution Utility profile'
            #Tweaks
            $sync.OskString = 'ReplaceOSK (Touch keyboard)'
            $sync.ShowKeyboardString = 'Show touch keyboard'
            $sync.EqualizerString = 'Equalizer APO'
            $sync.LoginSleepString = 'Disable login after sleep'
            $sync.GameBarString = 'Disable "ms-gamebar" error'
            $sync.EqualizerPopupString = "Select 'Speakers' and click 'OK' in EqualizerAPO configuration popup"
            #Soft
            $sync.SteamString = 'Steam client'
            $sync.ChromeString = 'Chrome browser'
            $sync.SevenZipString = '7-zip archivator'
            $sync.ShareXString = 'ShareX screenshot tool'
            #Progress Strings
            $sync.DownloadingTitleString = '# DOWNLOAD'
            $sync.DownloadingString = 'Downloading'
            $sync.InstallingTitleString = '# INSTALLATION'
            $sync.InstallingString = 'Installing '
            $sync.ConfiguringTitleString = '# CONFIGURATION'
            $sync.ConfiguringString = 'Configuration '
            $sync.TweakingTitleString = '# TWEAKS'
            $sync.DoneString = 'Done!'
            $sync.ErrorString = 'Error!'
            $sync.TimeoutErrorString = 'Timeout Error!'
            #Network error
            $sync.NetworkErrorString = 'Network Connection Error. Please check your internet connection'
            #Info
            $MustHaveInfoString = 'musthave_info_eng.txt'
            $TweaksInfoString = 'tweaks_info_eng.txt'
            $SoftInfoString = 'soft_info_eng.txt'
            #Finish
            $sync.FinishErrors1String = "Following components FAILED to install:`n `n"
            $sync.FinishErrors2String = "`nShow errors log file?`n`n"
            $sync.FinishSuccessString = "All components have been successfully installed! `n`nDo you want to restart the device?"
        }
        "RUS"
        {
            $SelectAllString = 'Выбрать все'
            #Controls
            $MustHavePageString = 'Маст-Хэв'
            $TweaksPageString = 'Улучшалки'
            $SoftPageString = 'Софт'
            $DownPathLabelString = 'Скачивать файлы в:'
            $BrowseButtonString = 'Выбрать...'
            $StartButtonString = 'СТАРТ'
            $CancelButtonString = 'ОТМЕНА'
            $WlanButtonString = 'Уст. WI-FI драйвер'
            $OSKeyboardButtonString = 'Откр. экран. клавиатуру'
            $OrientationButtonString = 'Изм. экран. ориентацию'
            #Must-Have
            $DriversString = 'Драйверы'
            $sync.VideoDriverString = 'Видео драйвер'
            $sync.AudioDriverString = 'Аудио драйвер'
            $sync.NetworkDriverString = 'Wi-Fi драйвер'
            $sync.BluetoothDriverString = 'Bluetooth драйвер'
            $sync.CardReaderDriverString = 'Драйвер считывателя SD-карты'
            $sync.HibernationString = 'Выкл. гибернацию'
            $sync.UtcString = 'Установка часов в UTC'
            $sync.CruConfigString = 'Custom Resolution Utility профиль'
            #Tweaks
            $sync.OskString = 'ReplaceOSK (Тач клавиатура)'
            $sync.ShowKeyboardString = 'Показ. тач клавиатуру'
            $sync.EqualizerString = 'Equalizer APO (Эквалайзер)'
            $sync.LoginSleepString = 'Выкл. логин после сна'
            $sync.GameBarString = 'Выкл. "ms-gamebar" ошибку'
            $sync.EqualizerPopupString = "Выберете 'Speakers' и нажмите 'OK' в окне конфигурации EqualizerAPO"
            #Soft
            $sync.SteamString = 'Steam клиент'
            $sync.ChromeString = 'Chrome браузер'
            $sync.SevenZipString = '7-zip архиватор'
            $sync.ShareXString = 'ShareX скриншот утилита'
            #Progress Strings
            $sync.DownloadingTitleString = '# СКАЧИВАНИЕ'
            $sync.DownloadingString = 'Скачивание'
            $sync.InstallingTitleString = '# УСТАНОВКА'
            $sync.InstallingString = 'Установка '
            $sync.ConfiguringTitleString = '# КОНФИГУРАЦИЯ'
            $sync.ConfiguringString = 'Конфигурация '
            $sync.TweakingTitleString = '# УЛУЧШАЛКИ'
            $sync.DoneString = 'Готово!'
            $sync.ErrorString = 'Ошибка!'
            $sync.TimeoutErrorString = 'Таймаут Ошибка!'
            #Network error
            $sync.NetworkErrorString = 'Ошибка соединения. Проверьте подключение к сети.'
            #Info
            $MustHaveInfoString = 'musthave_info_rus.txt'
            $TweaksInfoString = 'tweaks_info_rus.txt'
            $SoftInfoString = 'soft_info_rus.txt'
            #Finish
            $sync.FinishErrors1String = "Произошла ОШИБКА во время установки следующих компонентов:`n `n"
            $sync.FinishErrors2String = "`nПоказать лог файл с ошибками?`n`n"
            $sync.FinishSuccessString = "Все компоненты успешно установились! `n`nЖелаете перезагрузить устройство?"
        }

        { $_ -in "ENG", "RUS" } {
            $sync.VcString = 'Microsoft Visual C++'
            $sync.DirectXString = 'Microsoft DirectX'
            $sync.DotNetString = 'Dot NET 6.0'
            $sync.RtssString = 'Rivatuner Statistics Server'
            $sync.AdrenalinString = 'AMD Adrenalin'
            $sync.CruString = 'Custom Resolution Utility'
            $sync.DeckToolsString = 'Steam Deck Tools'
            $sync.VigemBusString = 'ViGEmBus'
        }
    }

    if ((Test-Connection -ComputerName www.google.com -Quiet -Count 2) -eq $false)
    {
        [System.Windows.MessageBox]::Show($sync.NetworkErrorString, "WinDeckHelper") | Out-Null
    }

    $DownPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

    $sync.DownloadPath = $DownPath

    Function Show-Info
    {
        $Textbox.Text = ' '

        switch ($Tabs.SelectedIndex)
        {
            0 {
                $Info = $MustHaveInfoString
            }
            1 {
                $Info = $TweaksInfoString
            }
            2 {
                $Info = $SoftInfoString
            }
        }

        foreach ($item in (Get-Content ".\$Info" -Encoding UTF8))
        {
            $Textbox.AppendText(' ' + $item + "`r`n")
            $Textbox.SelectionStart = 1
            $Textbox.ScrollToCaret()
        }
    }

    function Check-Selected-Nodes
    {
        param (
            $Tree
        )

        $Tree.SelectedNode = $null

        if ($_.Node.Checked)
        {
            $_.Node.Checked = $false
        }
        else
        {
            $_.Node.Checked = $true
        }
    }

    function Check-Nodes
    {
        param (
            $Tree
        )

        if ($_.Node.Name -eq 'SelectAll')
        {
            $i = 1
            while ($i -lt $Tree.Nodes.Count)
            {
                $Tree.Nodes[$i].Checked = $_.Node.Checked
                $i++
            }
        }
        if ($_.Node.Nodes.Count -gt 0)
        {
            $i = 0
            while ($i -lt $_.Node.Nodes.Count)
            {
                $_.Node.Nodes[$i].Checked = $_.Node.Checked
                $i++
            }
        }
    }

    #----------------------------------------------
    #region Generated Form Objects
    #----------------------------------------------
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $VersionComboBox = New-Object 'System.Windows.Forms.ComboBox'
    $LangComboBox = New-Object 'System.Windows.Forms.ComboBox'
    $MainForm = New-Object 'System.Windows.Forms.Form'
    $DownPathButton = New-Object 'System.Windows.Forms.Button'
    $DownPathLabel = New-Object 'System.Windows.Forms.Label'
    $Textbox = New-Object 'System.Windows.Forms.TextBox'
    $Tabs = New-Object 'System.Windows.Forms.TabControl'
    $MusthavePage = New-Object 'System.Windows.Forms.TabPage'
    $SoftPage = New-Object 'System.Windows.Forms.TabPage'
    $TweaksPage = New-Object 'System.Windows.Forms.TabPage'
    $MustTree = New-Object 'System.Windows.Forms.TreeView'
    $TweaksTree = New-Object 'System.Windows.Forms.TreeView'
    $SoftTree = New-Object 'System.Windows.Forms.TreeView'
    $OSKeyboardButton = New-Object 'System.Windows.Forms.Button'
    $OrientationButton = New-Object 'System.Windows.Forms.Button'
    $CancelButton = New-Object 'System.Windows.Forms.Button'
    $BrowseButton = New-Object 'System.Windows.Forms.Button'
    $StartButton = New-Object 'System.Windows.Forms.Button'
    $WlanButton = New-Object 'System.Windows.Forms.Button'
    $folderbrowserdialog = New-Object 'System.Windows.Forms.FolderBrowserDialog'
    $InitialFormWindowState = New-Object 'System.Windows.Forms.FormWindowState'

    #
    # formTest
    #
    $sync.Tabs = $Tabs
    $sync.Textbox = $Textbox
    $sync.StartButton = $StartButton
    $sync.BrowseButton = $BrowseButton
    $sync.OrientationButton = $OrientationButton
    $sync.OSKeyboardButton = $OSKeyboardButton
    $sync.buttonCANCEL = $CancelButton
    $sync.wlanButton = $WlanButton
    $sync.LangComboBox = $LangComboBox
    $sync.VersionComboBox = $VersionComboBox

    $MainForm.Controls.Add($sync.VersionComboBox)
    $MainForm.Controls.Add($sync.LangComboBox)
    $MainForm.Controls.Add($sync.Textbox)
    $MainForm.Controls.Add($sync.StartButton)
    $MainForm.Controls.Add($DownPathButton)
    $MainForm.Controls.Add($DownPathLabel)
    $MainForm.Controls.Add($sync.Tabs)
    $MainForm.Controls.Add($sync.OSKeyboardButton)
    $MainForm.Controls.Add($sync.OrientationButton)
    $MainForm.Controls.Add($sync.buttonCANCEL)
    $MainForm.Controls.Add($sync.BrowseButton)
    $MainForm.Controls.Add($sync.wlanButton)
    $MainForm.AutoScaleDimensions = New-Object System.Drawing.SizeF(6, 13)
    $MainForm.AutoScaleMode = 'Font'
    $MainForm.BackColor = [System.Drawing.SystemColors]::ButtonHighlight
    $MainForm.BackgroundImageLayout = 'None'
    $MainForm.ClientSize = New-Object System.Drawing.Size(600, 472)
    $MainForm.FormBorderStyle = 'Fixed3D'
    $MainForm.MaximizeBox = $False
    $MainForm.StartPosition = 'CenterScreen'
    $MainForm.Text = "WinDeckHelper"
    $MainForm.Icon = New-Object system.drawing.icon ($sync.rootPath + "\Windeckicon.ico")
    $sync.MainForm = $MainForm

    # VersionComboBox
    #
    $VersionComboBox.DropDownStyle = 'DropDownList'
    $VersionComboBox.FormattingEnabled = $True
    [void]$VersionComboBox.Items.Add('LCD VERSION')
    [void]$VersionComboBox.Items.Add('OLED VERSION')
    $VersionComboBox.Location = New-Object System.Drawing.Point(220, 8)
    $VersionComboBox.Name = 'VersionComboBox'
    $VersionComboBox.Size = New-Object System.Drawing.Size(135, 25)
    $VersionComboBox.TabIndex = 42
    $VersionComboBox.SelectedIndex = $VersionComboBox.FindString($global:Version)
    $VersionComboBox.Font = [System.Drawing.Font]::new('Microsoft Sans Serif', '10')
    $VersionComboBox.Add_SelectedIndexChanged({

        if ($VersionComboBox.SelectedItem -eq "LCD VERSION")
        {
            $sync.version = 'LCD'
            if ([string]$MustTree.Nodes -notmatch "Custom")
            {
                [void]$MustTree.Nodes.Insert(7, $sync.MustTree_Node_Cru)
            }
        }
        if ($VersionComboBox.SelectedItem -eq "OLED VERSION")
        {
            $sync.version = 'OLED'
            $sync.MustTree_Node_Cru.Checked = $false
            [void]$MustTree.Nodes.Remove($sync.MustTree_Node_Cru)
        }
    })



    #
    # LangComboBox
    #
    $LangComboBox.DropDownStyle = 'DropDownList'
    $LangComboBox.FormattingEnabled = $True
    [void]$LangComboBox.Items.Add('ENG')
    [void]$LangComboBox.Items.Add('RUS')
    $LangComboBox.Location = New-Object System.Drawing.Point(530, 8)
    $LangComboBox.Name = 'LangComboBox'
    $LangComboBox.Size = New-Object System.Drawing.Size(58, 25)
    $LangComboBox.TabIndex = 42
    $LangComboBox.SelectedIndex = $LangComboBox.FindString($global:Lang)
    $LangComboBox.Font = [System.Drawing.Font]::new('Microsoft Sans Serif', '10')
    $LangComboBox.Add_SelectedIndexChanged({

        if ($LangComboBox.SelectedItem -eq "RUS" -and $global:Lang -eq 'ENG')
        {
            $global:Lang = 'RUS'
            $global:NeedReset = $true
            $MainForm.Close()
        }
        if ($LangComboBox.SelectedItem -eq "ENG" -and $global:Lang -eq 'RUS')
        {
            $global:Lang = 'ENG'
            $global:NeedReset = $true
            $MainForm.Close()
        }
    })

    #
    # DownPathButton
    #
    $DownPathButton.Enabled = $False
    $DownPathButton.Location = New-Object System.Drawing.Point(12, 390)
    $DownPathButton.Name = 'DownPathButton'
    $DownPathButton.Size = New-Object System.Drawing.Size(486, 29)
    $DownPathButton.TabIndex = 41
    $DownPathButton.TextAlign = 'MiddleLeft'
    $DownPathButton.Text = $DownPath
    $DownPathButton.UseVisualStyleBackColor = $True
    #
    # DownPathLabel
    #
    $DownPathLabel.AutoSize = $True
    $DownPathLabel.Location = New-Object System.Drawing.Point(12, 374)
    $DownPathLabel.Name = 'DownPathLabel'
    $DownPathLabel.Text = $DownPathLabelString
    $DownPathLabel.Size = New-Object System.Drawing.Size(98, 13)
    $DownPathLabel.TabIndex = 40
    #
    # Textbox
    #
    $Textbox.BackColor = [System.Drawing.Color]::WhiteSmoke
    $Textbox.BorderStyle = 'None'
    $Textbox.Cursor = 'Default'
    $Textbox.Location = New-Object System.Drawing.Point(228, 39)
    $Textbox.Multiline = $True
    $Textbox.Name = 'Textbox'
    $Textbox.Size = New-Object System.Drawing.Size(359, 322)
    $Textbox.ScrollBars = 'Vertical'
    $Textbox.Font = [System.Drawing.Font]::new('Microsoft Sans Serif', '8.50')
    $Textbox.TabIndex = 38
    #
    # Tabs
    #
    $Tabs.Controls.Add($MusthavePage)
    $Tabs.Controls.Add($TweaksPage)
    $Tabs.Controls.Add($SoftPage)
    $Tabs.ItemSize = New-Object System.Drawing.Size(64, 25)
    $Tabs.Location = New-Object System.Drawing.Point(12, 12)
    $Tabs.Multiline = $True
    $Tabs.Name = 'Tabs'
    $Tabs.SelectedIndex = 0
    $Tabs.Size = New-Object System.Drawing.Size(214, 349)
    $Tabs.TabIndex = 6
    $Tabs.Add_SelectedIndexChanged({
        Show-Info
    })
    #
    # MustHavePage
    #
    $MustHavePage.Controls.Add($MustTree)
    $MustHavePage.BackColor = [System.Drawing.Color]::WhiteSmoke
    $MustHavePage.Location = New-Object System.Drawing.Point(4, 29)
    $MustHavePage.Padding = '3, 3, 3, 3'
    $MustHavePage.Size = New-Object System.Drawing.Size(207, 316)
    $MustHavePage.Text = $MustHavePageString
    #
    # MustTree
    #
    $MustTree.BackColor = [System.Drawing.Color]::WhiteSmoke
    $MustTree.BorderStyle = 'None'
    $MustTree.ItemHeight = 25
    $MustTree.Location = New-Object System.Drawing.Point(-4, 2)
    $MustTree.CheckBoxes = $true
    $MustTree.Name = 'MustTree'
    $MustTree_Node_SelectAll = New-Object 'System.Windows.Forms.TreeNode' ($SelectAllString)
    $MustTree_Node_SelectAll.Name = 'SelectAll'
    [void]$MustTree.Nodes.Add($MustTree_Node_SelectAll)
    $MustTree_Node_VideoDriver = New-Object 'System.Windows.Forms.TreeNode' ($sync.VideoDriverString)
    $sync.MustTree_Node_VideoDriver = $MustTree_Node_VideoDriver
    $MustTree_Node_AudioDriver = New-Object 'System.Windows.Forms.TreeNode' ($sync.AudioDriverString)
    $sync.MustTree_Node_AudioDriver = $MustTree_Node_AudioDriver
    #    $MustTree_Node_NetworkDriver = New-Object 'System.Windows.Forms.TreeNode' ($sync.NetworkDriverString)
    #    $sync.MustTree_Node_NetworkDriver = $MustTree_Node_NetworkDriver
    $MustTree_Node_BluetoothDriver = New-Object 'System.Windows.Forms.TreeNode' ($sync.BluetoothDriverString)
    $sync.MustTree_Node_BluetoothDriver = $MustTree_Node_BluetoothDriver
    $MustTree_Node_CardReaderDriver = New-Object 'System.Windows.Forms.TreeNode' ($sync.CardReaderDriverString)
    $sync.MustTree_Node_CardReaderDriver = $MustTree_Node_CardReaderDriver
    $MustTree_Node_Drivers = New-Object 'System.Windows.Forms.TreeNode' ($DriversString, [System.Windows.Forms.TreeNode[]]($sync.MustTree_Node_VideoDriver, $sync.MustTree_Node_AudioDriver, $sync.MustTree_Node_BluetoothDriver, $sync.MustTree_Node_CardReaderDriver))
    [void]$MustTree.Nodes.Add($MustTree_Node_Drivers)
    $MustTree_Node_Vc = New-Object 'System.Windows.Forms.TreeNode' ($sync.VcString)
    $sync.MustTree_Node_Vc = $MustTree_Node_Vc
    [void]$MustTree.Nodes.Add($sync.MustTree_Node_Vc)
    $MustTree_Node_DirectX = New-Object 'System.Windows.Forms.TreeNode' ($sync.DirectXString)
    $sync.MustTree_Node_DirectX = $MustTree_Node_DirectX
    [void]$MustTree.Nodes.Add($sync.MustTree_Node_DirectX)
    $MustTree_Node_DotNet = New-Object 'System.Windows.Forms.TreeNode' ($sync.DotNetString)
    $sync.MustTree_Node_DotNet = $MustTree_Node_DotNet
    [void]$MustTree.Nodes.Add($sync.MustTree_Node_DotNet)
    $MustTree_Node_Rtss = New-Object 'System.Windows.Forms.TreeNode' ($sync.RtssString)
    $sync.MustTree_Node_Rtss = $MustTree_Node_Rtss
    [void]$MustTree.Nodes.Add($sync.MustTree_Node_Rtss)
    $MustTree_Node_Adrenalin = New-Object 'System.Windows.Forms.TreeNode' ($sync.AdrenalinString)
    $sync.MustTree_Node_Adrenalin = $MustTree_Node_Adrenalin
    [void]$MustTree.Nodes.Add($sync.MustTree_Node_Adrenalin)
    $MustTree_Node_Cru = New-Object 'System.Windows.Forms.TreeNode' ($sync.CruString)
    $sync.MustTree_Node_Cru = $MustTree_Node_Cru
    [void]$MustTree.Nodes.Add($sync.MustTree_Node_Cru)
    $MustTree_Node_DeckTools = New-Object 'System.Windows.Forms.TreeNode' ($sync.DeckToolsString)
    $sync.MustTree_Node_DeckTools = $MustTree_Node_DeckTools
    [void]$MustTree.Nodes.Add($sync.MustTree_Node_DeckTools)
    $MustTree_Node_Hibernation = New-Object 'System.Windows.Forms.TreeNode' ($sync.HibernationString)
    $sync.MustTree_Node_Hibernation = $MustTree_Node_Hibernation
    [void]$MustTree.Nodes.Add($sync.MustTree_Node_Hibernation)
    $MustTree_Node_Utc = New-Object 'System.Windows.Forms.TreeNode' ($sync.UtcString)
    $sync.MustTree_Node_Utc = $MustTree_Node_Utc
    [void]$MustTree.Nodes.Add($sync.MustTree_Node_Utc)
    $MustTree.Size = New-Object System.Drawing.Size(215, 322)
    $MustTree.TabIndex = 42

    $MustTree.add_AfterSelect({
        Check-Selected-Nodes -Tree $MustTree
    })

    $MustTree.add_AfterCheck({
        Check-Nodes -Tree $MustTree
    })

    #
    # TweaksPage
    #
    $TweaksPage.Controls.Add($TweaksTree)
    $TweaksPage.Location = New-Object System.Drawing.Point(4, 29)
    $TweaksPage.Name = 'TweaksPage'
    $TweaksPage.Padding = '3, 3, 3, 3'
    $TweaksPage.Size = New-Object System.Drawing.Size(207, 316)
    $TweaksPage.TabIndex = 2
    $TweaksPage.UseVisualStyleBackColor = $True
    $TweaksPage.Text = $TweaksPageString
    #
    # TweaksTree
    #
    $TweaksTree.BackColor = [System.Drawing.Color]::WhiteSmoke
    $TweaksTree.BorderStyle = 'None'
    $TweaksTree.ItemHeight = 25
    $TweaksTree.Location = New-Object System.Drawing.Point(-4, 2)
    $TweaksTree.CheckBoxes = $true
    $TweaksTree.Name = 'TweaksTree'
    $TweaksTree_Node_SelectAll = New-Object 'System.Windows.Forms.TreeNode' ($SelectAllString)
    $TweaksTree_Node_SelectAll.Name = 'SelectAll'
    [void]$TweaksTree.Nodes.Add($TweaksTree_Node_SelectAll)
    $TweaksTree_Node_Osk = New-Object 'System.Windows.Forms.TreeNode' ($sync.OskString)
    $sync.TweaksTree_Node_Osk = $TweaksTree_Node_Osk
    [void]$TweaksTree.Nodes.Add($sync.TweaksTree_Node_Osk)
    $TweaksTree_Node_ShowKeyboard = New-Object 'System.Windows.Forms.TreeNode' ($sync.ShowKeyboardString)
    $sync.TweaksTree_Node_ShowKeyboard = $TweaksTree_Node_ShowKeyboard
    [void]$TweaksTree.Nodes.Add($sync.TweaksTree_Node_ShowKeyboard)
    $TweaksTree_Node_Equalizer = New-Object 'System.Windows.Forms.TreeNode' ($sync.EqualizerString)
    $sync.TweaksTree_Node_Equalizer = $TweaksTree_Node_Equalizer
    [void]$TweaksTree.Nodes.Add($sync.TweaksTree_Node_Equalizer)
    $TweaksTree_Node_LoginSleep = New-Object 'System.Windows.Forms.TreeNode' ($sync.LoginSleepString)
    $sync.TweaksTree_Node_LoginSleep = $TweaksTree_Node_LoginSleep
    [void]$TweaksTree.Nodes.Add($sync.TweaksTree_Node_LoginSleep)
    $TweaksTree_Node_GameBar = New-Object 'System.Windows.Forms.TreeNode' ($sync.GameBarString)
    $sync.TweaksTree_Node_GameBar = $TweaksTree_Node_GameBar
    [void]$TweaksTree.Nodes.Add($sync.TweaksTree_Node_GameBar)
    $TweaksTree.Size = New-Object System.Drawing.Size(215, 322)
    $TweaksTree.TabIndex = 42

    $TweaksTree.add_AfterSelect({
        Check-Selected-Nodes -Tree $TweaksTree
    })

    $TweaksTree.add_AfterCheck({
        Check-Nodes -Tree $TweaksTree
    })
    #
    # SoftPage
    #
    $SoftPage.Controls.Add($SoftTree)
    $SoftPage.Location = New-Object System.Drawing.Point(4, 29)
    $SoftPage.Name = 'SoftPage'
    $SoftPage.Padding = '3, 3, 3, 3'
    $SoftPage.Size = New-Object System.Drawing.Size(207, 316)
    $SoftPage.TabIndex = 2
    $SoftPage.UseVisualStyleBackColor = $True
    $SoftPage.Text = $SoftPageString
    #
    # SoftTree
    #
    $SoftTree.BackColor = [System.Drawing.Color]::WhiteSmoke
    $SoftTree.BorderStyle = 'None'
    $SoftTree.ItemHeight = 25
    $SoftTree.Location = New-Object System.Drawing.Point(-4, 2)
    $SoftTree.CheckBoxes = $true
    $SoftTree.Name = 'SoftTree'
    $SoftTree_Node_SelectAll = New-Object 'System.Windows.Forms.TreeNode' ($SelectAllString)
    $SoftTree_Node_SelectAll.Name = 'SelectAll'
    [void]$SoftTree.Nodes.Add($SoftTree_Node_SelectAll)
    $SoftTree_Node_Steam = New-Object 'System.Windows.Forms.TreeNode' ($sync.SteamString)
    $sync.SoftTree_Node_Steam = $SoftTree_Node_Steam
    [void]$SoftTree.Nodes.Add($sync.SoftTree_Node_Steam)
    $SoftTree_Node_Chrome = New-Object 'System.Windows.Forms.TreeNode' ($sync.ChromeString)
    $sync.SoftTree_Node_Chrome = $SoftTree_Node_Chrome
    [void]$SoftTree.Nodes.Add($sync.SoftTree_Node_Chrome)
    $SoftTree_Node_7zip = New-Object 'System.Windows.Forms.TreeNode' ($sync.SevenZipString)
    $sync.SoftTree_Node_7zip = $SoftTree_Node_7zip
    [void]$SoftTree.Nodes.Add($sync.SoftTree_Node_7zip)
    $SoftTree_Node_ShareX = New-Object 'System.Windows.Forms.TreeNode' ($sync.ShareXString)
    $sync.SoftTree_Node_ShareX = $SoftTree_Node_ShareX
    [void]$SoftTree.Nodes.Add($sync.SoftTree_Node_ShareX)
    $SoftTree.Size = New-Object System.Drawing.Size(287, 421)
    $SoftTree.TabIndex = 43

    $SoftTree.add_AfterSelect({
        Check-Selected-Nodes -Tree $SoftTree
    })

    $SoftTree.add_AfterCheck({
        Check-Nodes -Tree $SoftTree
    })

    #
    # OSKeyboardButton
    #
    $OSKeyboardButton.Location = New-Object System.Drawing.Point(278, 429)
    $OSKeyboardButton.Name = 'OSKeyboardButton'
    $OSKeyboardButton.Text = $OSKeyboardButtonString
    $OSKeyboardButton.Size = New-Object System.Drawing.Size(154, 35)
    $OSKeyboardButton.TabIndex = 5
    $OSKeyboardButton.UseVisualStyleBackColor = $True
    #	$OSKeyboardButton.Font = [System.Drawing.Font]::new('Microsoft Sans Serif', '7.50')
    $OSKeyboardButton.Add_Click({ osk })
    #
    # OrientationButton
    #
    $OrientationButton.Location = New-Object System.Drawing.Point(437, 429)
    $OrientationButton.Name = 'OrientationButton'
    $OrientationButton.Text = $OrientationButtonString
    $OrientationButton.Size = New-Object System.Drawing.Size(154, 35)
    $OrientationButton.TabIndex = 5
    $OrientationButton.UseVisualStyleBackColor = $True
    #	$OrientationButton.Font = [System.Drawing.Font]::new('Microsoft Sans Serif', '7.50')
    $OrientationButton.Add_Click({ Set-Orientation })
    #
    # CancelButton
    #
    $CancelButton.Location = New-Object System.Drawing.Point(101, 429)
    $CancelButton.Name = 'CancelButton'
    $CancelButton.Text = $CancelButtonString
    $CancelButton.Size = New-Object System.Drawing.Size(83, 35)
    $CancelButton.TabIndex = 5
    $CancelButton.UseVisualStyleBackColor = $True
    $CancelButton.Add_Click({
        $global:NeedReset = $true
        $MainForm.Close()
    })
    #
    # BrowseButton
    #
    $BrowseButton.Location = New-Object System.Drawing.Point(504, 390)
    $BrowseButton.Name = 'BrowseButton'
    $BrowseButton.Text = $BrowseButtonString
    $BrowseButton.Size = New-Object System.Drawing.Size(83, 29)
    $BrowseButton.TabIndex = 5
    $BrowseButton.UseVisualStyleBackColor = $True
    $BrowseButton.add_Click({
        if ($folderbrowserdialog.ShowDialog() -eq 'OK')
        {
            $DownPath = $folderbrowserdialog.SelectedPath.ToString()
            $DownPathButton.Text = $DownPath
            $sync.DownloadPath = $DownPath
        }
    })
    #
    # StartButton
    #
    $StartButton.Location = New-Object System.Drawing.Point(12, 429)
    $StartButton.Name = 'StartButton'
    $StartButton.Text = $StartButtonString
    $StartButton.Size = New-Object System.Drawing.Size(83, 35)
    $StartButton.TabIndex = 5
    $StartButton.UseVisualStyleBackColor = $True
    $StartButton.Add_Click($counter)
    #
    # WlanButton
    #
    $WlanButton.Location = New-Object System.Drawing.Point(375, 7)
    $WlanButton.Name = 'WlanButton'
    $WlanButton.Text = $WlanButtonString
    $WlanButton.Size = New-Object System.Drawing.Size(135, 26)
    $WlanButton.TabIndex = 5
    $WlanButton.UseVisualStyleBackColor = $True
    $WlanButton.Add_Click({ Install-Wlan })

    Show-Info

    # Activate the form
    $MainForm.Add_Shown({ $MainForm.Activate() })
    [void]$MainForm.ShowDialog()
}
