
Add-Type -AssemblyName PresentationCore, PresentationFramework

Function setScale
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


Function setOrientation
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

function run_form
{
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    [bool]$global:allChecked = $false

    $DownloadPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

    Write-Host
    Write-Host " WinDeckHelper - Utilities installer and tweaker for your Windows Steam Deck " -NoNewline -BackgroundColor Yellow -ForegroundColor Black
    Write-Host
    Write-Host

    IF ((Test-Connection -ComputerName www.google.com -Quiet) -eq $false) {
        [System.Windows.MessageBox]::Show("Network Connection Error. Please check your internet connection.","WinDeckHelper") | Out-Null
    }

    # Form
    $Form = New-Object System.Windows.Forms.Form
    $Form.width = 520
    $Form.height = 470
    $Form.Text = "WinDeckHelper"
    $Form.StartPosition = "CenterScreen"
    $Form.MaximizeBox = $false
    $Form.FormBorderStyle = 'Fixed3D'

    # Form Font
    $Font = New-Object System.Drawing.Font("Times New Roman", 12)
    $Form.Font = $Font

    # Form icon
    $Form.Icon = New-Object system.drawing.icon ("./Windeckicon.ico")

    ### Form Checkboxes

    # Select All
    $SelectAll= new-object System.Windows.Forms.checkbox
    $SelectAll.Location = new-object System.Drawing.Size(30, 20)
    $SelectAll.Size = new-object System.Drawing.Size(200, 20)
    $SelectAll.Text = "Select All"
    $SelectAll.Font = [System.Drawing.Font]::new("Times New Roman", 12, [System.Drawing.FontStyle]::Bold)
    $SelectAll.Add_Click({selectAll})
    $Form.Controls.Add($SelectAll)

    # Drivers
    $Drivers = new-object System.Windows.Forms.checkbox
    $Drivers.Location = new-object System.Drawing.Size(30, 50)
    $Drivers.Size = new-object System.Drawing.Size(240, 20)
    $Drivers.Text = "Drivers"
    $Form.Controls.Add($Drivers)

    # AMD Adrenalin
    $Adrenalin = new-object System.Windows.Forms.checkbox
    $Adrenalin.Location = new-object System.Drawing.Size(30, 80)
    $Adrenalin.Size = new-object System.Drawing.Size(240, 20)
    $Adrenalin.Text = "AMD Adrenalin"
    $Form.Controls.Add($Adrenalin)

    # VC
    $Vc = new-object System.Windows.Forms.checkbox
    $Vc.Location = new-object System.Drawing.Size(30, 110)
    $Vc.Size = new-object System.Drawing.Size(240, 20)
    $Vc.Text = "VC++"
    $Form.Controls.Add($Vc)

    # DirectX
    $Directx = new-object System.Windows.Forms.checkbox
    $Directx.Location = new-object System.Drawing.Size(30, 140)
    $Directx.Size = new-object System.Drawing.Size(240, 20)
    $Directx.Text = "DirectX"
    $Form.Controls.Add($Directx)

    # DotNet
    $DotNet = new-object System.Windows.Forms.checkbox
    $DotNet.Location = new-object System.Drawing.Size(30, 170)
    $DotNet.Size = new-object System.Drawing.Size(240, 20)
    $DotNet.Text = "Dot NET 6.0"
    $Form.Controls.Add($DotNet)

    # Rivatuner
    $Rivatuner = new-object System.Windows.Forms.checkbox
    $Rivatuner.Location = new-object System.Drawing.Size(30, 200)
    $Rivatuner.Size = new-object System.Drawing.Size(240, 20)
    $Rivatuner.Text = "RTSS Rivatuner"
    $Form.Controls.Add($Rivatuner)

    # SteamDeckTools
    $SteamDeckTools = new-object System.Windows.Forms.checkbox
    $SteamDeckTools.Location = new-object System.Drawing.Size(30, 230)
    $SteamDeckTools.Size = new-object System.Drawing.Size(240, 20)
    $SteamDeckTools.Text = "Steam Deck Tools"
    $Form.Controls.Add($SteamDeckTools)

    # Custom Resolution Utility
    $Cru = new-object System.Windows.Forms.checkbox
    $Cru.Location = new-object System.Drawing.Size(30, 260)
    $Cru.Size = new-object System.Drawing.Size(240, 20)
    $Cru.Text = "Custom Resolution Utility"
    $Form.Controls.Add($Cru)

    # EqualizerApo
    $EqualizerApo = new-object System.Windows.Forms.checkbox
    $EqualizerApo.Location = new-object System.Drawing.Size(30, 290)
    $EqualizerApo.Size = new-object System.Drawing.Size(240, 20)
    $EqualizerApo.Text = "Equalizer APO"
    $Form.Controls.Add($EqualizerApo)

    # ReplaceOSK keyboard
    $ReplaceOSK = new-object System.Windows.Forms.checkbox
    $ReplaceOSK.Location = new-object System.Drawing.Size(30, 320)
    $ReplaceOSK.Size = new-object System.Drawing.Size(240, 20)
    $ReplaceOSK.Text = "ReplaceOSK(Touch Keyboard)"
    $Form.Controls.Add($ReplaceOSK)

    # Disable Hibernation
    $Hibernation = new-object System.Windows.Forms.checkbox
    $Hibernation.Location = new-object System.Drawing.Size(270, 50)
    $Hibernation.Size = new-object System.Drawing.Size(240, 20)
    $Hibernation.Text = "Disable Hibernation"
    $Form.Controls.Add($Hibernation)

    # Disable login after sleep
    $Sleeplogin = new-object System.Windows.Forms.checkbox
    $Sleeplogin.Location = new-object System.Drawing.Size(270, 80)
    $Sleeplogin.Size = new-object System.Drawing.Size(240, 20)
    $Sleeplogin.Text = "Disable Login After Sleep"
    $Form.Controls.Add($Sleeplogin)

    # Internal clock to UTC
    $Utcfix = new-object System.Windows.Forms.checkbox
    $Utcfix.Location = new-object System.Drawing.Size(270, 110)
    $Utcfix.Size = new-object System.Drawing.Size(240, 20)
    $Utcfix.Text = "Set UTC Internal Clock"
    $Form.Controls.Add($Utcfix)

    # Disable xbox gamebar
    $Gamebar = new-object System.Windows.Forms.checkbox
    $Gamebar.Location = new-object System.Drawing.Size(270, 140)
    $Gamebar.Size = new-object System.Drawing.Size(240, 20)
    $Gamebar.Text = "Disable 'ms-gamebar' Error"
    $Form.Controls.Add($Gamebar)

    # Auto Show Touch Keyboard
    $AutoKeyboard = new-object System.Windows.Forms.checkbox
    $AutoKeyboard.Location = new-object System.Drawing.Size(270, 170)
    $AutoKeyboard.Size = new-object System.Drawing.Size(240, 20)
    $AutoKeyboard.Text = "Show Touch Keyboard "
    $Form.Controls.Add($AutoKeyboard)

    ### Form Buttons

    # Start button
    $STARTButton = new-object System.Windows.Forms.Button
    $STARTButton.Location = new-object System.Drawing.Size(30, 360)
    $STARTButton.Size = new-object System.Drawing.Size(100, 40)
    $STARTButton.Text = "START"

    # Change Orientation
    $Orientation = new-object System.Windows.Forms.Button
    $Orientation.Location = new-object System.Drawing.Size(150, 360)
    $Orientation.Size = new-object System.Drawing.Size(100, 40)
    $Orientation.Text = "Change Orientation"

    # Open Onscreen Keyboard
    $Osk = new-object System.Windows.Forms.Button
    $Osk.Location = new-object System.Drawing.Size(270, 360)
    $Osk.Size = new-object System.Drawing.Size(100, 40)
    $Osk.Text = "Open OSKeyboard"

    function download
    {
        Write-Host
        Write-Host ">>> DOWNLOADING STUFF      " -BackgroundColor Green -ForegroundColor Black
        Write-Host
        if ($Drivers.Checked)
        {
            $name = "- Downloading APU Chipset Drivers from Valve: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/Aerith%20Windows%20Driver_2209130944.zip" "$DownloadPath\APU_Drivers.zip" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"

            $name = "- Downloading Audio Drivers 1/2 from Valve (cs35l41): "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/cs35l41-V1.2.1.0.zip" "$DownloadPath\Audio_Drivers_1.zip" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"

            $name = "- Downloading Audio Drivers 2/2 from Valve (NAU88L21): "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://steamdeck-packages.steamos.cloud/misc/windows/drivers/NAU88L21_x64_1.0.6.0_WHQL%20-%20DUA_BIQ_WHQL.zip" "$DownloadPath\Audio_Drivers_2.zip" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"

            $name = "- Downloading Wireless LAN Drivers from Windows Update: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://catalog.s.download.windowsupdate.com/d/msdownload/update/driver/drvs/2022/11/05b73312-01e0-4e40-a991-93d11309b736_8cd43d4695c27a3f174b6e9c33034c100995e095.cab" "$DownloadPath\WLAN_Drivers.cab" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"

            $name = "- Downloading Bluetooth Drivers from Windows Update: "
            Write-Host -NoNewline  $name
            Start-BitsTransfer "https://catalog.s.download.windowsupdate.com/d/msdownload/update/driver/drvs/2022/08/ad501382-9e48-4720-92c7-bcee5374671e_501f5f234304610bbbc221823de181e544c1bc09.cab" "$DownloadPath\Bluetooth_Drivers.cab" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"

            $name = "- Downloading MicroSD Card Reader Drivers from Windows Update: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://catalog.s.download.windowsupdate.com/c/msdownload/update/driver/drvs/2022/10/4f20ec00-bee5-4df2-873c-3a49cf4d4f8b_0aaf931a756473e6f8be1ef890fb60c283e9e82e.cab" "$DownloadPath\MicroSD_Drivers.cab" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"
        }

        if ($Adrenalin.Checked)
        {
            $name = "- Downloading AMD Adrenalin: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://dl.dropboxusercontent.com/s/kr6k6o2lg3y0yu8/ccc2_install.exe?dl=0"  "$DownloadPath\ccc2_install.exe" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"
        }

        if ($Vc.Checked)
        {
            $name = "- Downloading VC++ All in One Redistributable: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://github.com/abbodi1406/vcredist/releases/download/v0.64.0/VisualCppRedist_AIO_x86_x64_64.zip" "$DownloadPath\VCpp.zip" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"

        }
        if ($Directx.Checked)
        {
            $name = "- Downloading DirectX Web Setup: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe" "$DownloadPath\DirectX.exe" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"
        }
        if ($DotNet.Checked)
        {
            $name = "- Downloading .NET 6.0 Setup: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://download.visualstudio.microsoft.com/download/pr/08ada4db-1e64-4829-b36d-5beb71f67bff/b77050cf7e0c71d3b95418651db1a9b8/dotnet-sdk-6.0.403-win-x64.exe" "$DownloadPath\dotnet6.0_Setup.exe" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"
        }

        if ($Rivatuner.Checked)
        {
            $name = "- Downloading RivaTuner Setup: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://delivery2.filecroco.com/kits_6/RTSSSetup733.exe"  "$DownloadPath\RivaTuner_Setup.exe" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"
        }

        if ($SteamDeckTools.Checked)
        {
            $name = "- Downloading ViGEmBus Setup: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://github.com/ViGEm/ViGEmBus/releases/download/v1.21.442.0/ViGEmBus_1.21.442_x64_x86_arm64.exe"  "$DownloadPath\ViGEmBus_Setup.exe" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"

            $name = "- Downloading SteamDeckTools: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://github.com/ayufan/steam-deck-tools/releases/download/0.6.7/SteamDeckTools-0.6.7-portable.zip"  "$DownloadPath\SteamDeckTools.zip" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"
        }

        if ($EqualizerApo.Checked)
        {
            $name = "- Downloading EqualizerAPO: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://netix.dl.sourceforge.net/project/equalizerapo/1.3/EqualizerAPO64-1.3.exe" "$DownloadPath\EqualizerAPO_Setup.exe" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"

            $name = "- Downloading EqualizerAPO Config: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://raw.githubusercontent.com/CelesteHeartsong/SteamDeckAutomatedInstall/main/EqualizerAPO_Config.txt" "$DownloadPath\EqualizerAPO_Config.txt" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"
        }

        if ($Cru.Checked)
        {
            $name = "- Downloading Custom Resolution Utility: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://www.monitortests.com/download/cru/cru-1.5.2.zip" "$DownloadPath\cru-1.5.2.zip" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"

            $name = "- Downloading Custom Resolution Utility Config: "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://github.com/baldsealion/Steamdeck-Ultimate-Windows11-Guide/blob/main/CRU%20Custom%20BIN/Ciphrays-steamdeck-30-35-40-45-50-60_ex_res.bin?raw=true" "$DownloadPath\cru-steamdeck.bin" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"
        }
        if ($ReplaceOSK.Checked)
        {
            $name = "- Downloading ReplaceOSK(Touch Keyboard): "
            Write-Host -NoNewline $name
            Start-BitsTransfer "https://github.com/Lulech23/ReplaceOSK/releases/download/v2.4-5/ReplaceOSK.bat" "$DownloadPath\ReplaceOSK.bat" -DisplayName $name -Description " "
            Write-Host -ForegroundColor Green "Done"
        }
    }

    function install
    {
        Write-Host
        Write-Host ">>> INSTALLING STUFF       " -BackgroundColor Green -ForegroundColor Black
        Write-Host

        if ($Drivers.Checked)
        {
            Write-Host -NoNewline "- Installing APU Chipset: "
            Expand-Archive "$DownloadPath\APU_Drivers.zip" -DestinationPath "$DownloadPath\APU_Drivers" -Force
            Start-Process "$DownloadPath\APU_Drivers\Aerith Windows Driver_2209130944\220913a-383120E-2209130944\Setup.exe" -ArgumentList "-install" -Wait | Out-Null
            setScale | Out-Null
            setOrientation | Out-Null

            Write-Host -ForegroundColor Green "Done"

            Write-Host -NoNewline "- Installing Audio Drivers 1/2: "
            Expand-Archive "$DownloadPath\Audio_Drivers_1.zip" "$DownloadPath\Audio_Drivers_1" -Force
            Start-Process -FilePath "PNPUtil.exe" -ArgumentList "/add-driver `"$DownloadPath\Audio_Drivers_1\cs35l41-V1.2.1.0\cs35l41.inf`" /install" -Wait
            Write-Host -ForegroundColor Green "Done"

            Write-Host -NoNewline "- Installing Audio Drivers 2/2: "
            Expand-Archive "$DownloadPath\Audio_Drivers_2.zip" "$DownloadPath\Audio_Drivers_2" -Force
            Start-Process -FilePath "PNPUtil.exe" -ArgumentList "/add-driver `"$DownloadPath\Audio_Drivers_2\NAU88L21_x64_1.0.6.0_WHQL - DUA_BIQ_WHQL\NAU88L21.inf`" /install" -Wait
            Write-Host -ForegroundColor Green "Done"

            Write-Host -NoNewline "- Installing WLAN Drivers: "
            New-Item $DownloadPath\WLAN_Drivers -ItemType Directory -ErrorAction SilentlyContinue >> $null
            Start-Process -FilePath "expand.exe" -ArgumentList "-F:* $DownloadPath\WLAN_Drivers.cab $DownloadPath\\WLAN_Drivers" -Wait
            Start-Process -FilePath "PNPUtil.exe" -ArgumentList "/add-driver `"$DownloadPath\WLAN_Drivers\netrtwlane.inf`" /install" -Wait
            Write-Host -ForegroundColor Green "Done"

            Write-Host -NoNewline "- Installing Bluetooth Drivers: "
            New-Item $DownloadPath\Bluetooth_Drivers -ItemType Directory -ErrorAction SilentlyContinue >> $null
            Start-Process -FilePath "expand.exe" -ArgumentList "-F:* $DownloadPath\Bluetooth_Drivers.cab $DownloadPath\Bluetooth_Drivers" -Wait
            Start-Process -FilePath "PNPUtil.exe" -ArgumentList "/add-driver `"$DownloadPath\Bluetooth_Drivers\Rtkfilter.inf`" /install" -Wait
            Write-Host -ForegroundColor Green "Done"

            Write-Host -NoNewline "- Installing MicroSD Drivers: "
            New-Item $DownloadPath\MicroSD_Drivers -ItemType Directory -ErrorAction SilentlyContinue >> $null
            Start-Process -FilePath "expand.exe" -ArgumentList "-F:* $DownloadPath\MicroSD_Drivers.cab $DownloadPath\MicroSD_Drivers" -Wait
            Start-Process -FilePath "PNPUtil.exe" -ArgumentList "/add-driver `"$DownloadPath\MicroSD_Drivers\bhtsddr.inf`" /install" -Wait
            Write-Host -ForegroundColor Green "Done"
        }

        if ($Adrenalin.Checked)
        {
            Write-Host -NoNewline "- Installing AMD Adrenalin: "
            Start-Process -FilePath "$DownloadPath\ccc2_install.exe" -ArgumentList "/S" -Wait
            Write-Host -ForegroundColor Green "Done"
        }

        if ($Vc.Checked)
        {
            Write-Host -NoNewline "- Installing VC++ All in One Redistributable: "
            Expand-Archive "$DownloadPath\VCpp.zip" -DestinationPath "$DownloadPath\Vcpp" -Force
            Start-Process $DownloadPath\Vcpp\VisualCppRedist_AIO_x86_x64.exe /ai -Wait
            Write-Host -ForegroundColor Green "Done"
        }
        if ($Directx.Checked)
        {
            Write-Host -NoNewline "- Installing DirectX Web Setup: "
            Start-Process -FilePath "$DownloadPath\DirectX.exe" -ArgumentList "/Q" -Wait
            Write-Host -ForegroundColor Green "Done"
        }

        if ($DotNet.Checked)
        {
            Write-Host -NoNewline "- Installing .NET 6.0: "
            Start-Process -FilePath "$DownloadPath\dotnet6.0_Setup.exe" -ArgumentList "/quiet /norestart" -Wait
            Write-Host -ForegroundColor Green "Done"
        }

        if ($Rivatuner.Checked)
        {
            Write-Host -NoNewline "- Installing RivaTuner: "
            Start-Process -FilePath "$DownloadPath\RivaTuner_Setup.exe" -ArgumentList "/S" -Wait
            Write-Host -ForegroundColor Green "Done"
        }

        if ($SteamDeckTools.Checked)
        {
            Write-Host -NoNewline "- Installing ViGEmBus: "
            Start-Process -FilePath "$DownloadPath\ViGEmBus_Setup.exe" -ArgumentList "/qn /norestart" -Wait
            Write-Host -ForegroundColor Green "Done"

            New-Item "$Env:Programfiles" -ItemType Directory -Name "SteamDeckTools" -ErrorAction SilentlyContinue >> $null

            Write-Host -NoNewline "- Installing SteamDeckTools: "
            Expand-Archive "$DownloadPath\SteamDeckTools.zip" "$Env:Programfiles\SteamDeckTools" -Force
            Write-Host -ForegroundColor Green "Done"
        }


        if ($EqualizerApo.Checked)
        {
            Write-Host -NoNewline "- Installing EqualizerAPO: "
            [System.Windows.MessageBox]::Show("Select 'Speakers' and click 'OK' in EqualizerAPO configuration popup ", "EqualizerAPO") | Out-Null
            Start-Process -FilePath "$DownloadPath\EqualizerAPO_Setup.exe" -ArgumentList "/S" -Wait
            Copy-Item "$DownloadPath\EqualizerAPO_Config.txt" -Destination "$Env:Programfiles\EqualizerAPO\config\config.txt" -Force
            Write-Host -ForegroundColor Green "Done"
        }

        if ($Cru.Checked)
        {
            $cruPath = "$Env:Programfiles\Custom Resolution Utility"
            Write-Host -NoNewline "- Installing Custom Resolution Utility: "
            Expand-Archive "$DownloadPath\cru-1.5.2.zip" $cruPath -Force
            Copy-Item "$DownloadPath\cru-steamdeck.bin" -Destination $cruPath -Force
            [System.Windows.MessageBox]::Show("Click on 'Import' button, select 'cru-steamdeck.bin' (in 'Downloads' folder) and click 'OK'", "Custom Resolution Utility") | Out-Null
            Start-Process -FilePath "$cruPath\CRU.exe" -Wait
            Write-Host -ForegroundColor Green "Done"
        }
        if ($ReplaceOSK.Checked)
        {
            Write-Host -NoNewline "- Installing ReplaceOSK(Touch Keyboard): "
            Start-Process -FilePath "$DownloadPath\ReplaceOSK.bat" -Wait
            Write-Host -ForegroundColor Green "Done"
        }

    }

    function config
    {
        Write-Host
        Write-Host ">>> CONFIGURING STUFF      " -BackgroundColor Green -ForegroundColor Black
        Write-Host

        if ($Rivatuner.Checked)
        {
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
            Write-Host -NoNewline "- Setting RivaTuner to run on login: "
            $action = New-ScheduledTaskAction -Execute "$Env:ProgramFiles (x86)\RivaTuner Statistics Server\RTSS.exe"
            $description = "Start RivaTuner at Login"
            Register-ScheduledTask -TaskName "RivaTuner" -Action $action -Trigger $trigger -RunLevel Highest -Description $description -Settings $settings >> $null
            Write-Host -ForegroundColor Green "Done"
        }

        if ($SteamDeckTools.Checked)
        {
            Write-Host -NoNewline "- Setting FanControl to run on login: "
            Start-Process -FilePath "$Env:Programfiles\SteamDeckTools\FanControl.exe" -ArgumentList "-run-on-startup"
            Write-Host -ForegroundColor Green "Done"

            Write-Host -NoNewline "- Setting PerformanceOverlay to run on login: "
            Start-Process -FilePath "$Env:Programfiles\SteamDeckTools\PerformanceOverlay.exe" -ArgumentList "-run-on-startup"
            Write-Host -ForegroundColor Green "Done"

            Write-Host -NoNewline "- Setting PowerControl to run on login: "
            Start-Process -FilePath "$Env:Programfiles\SteamDeckTools\PowerControl.exe" -ArgumentList "-run-on-startup"
            Write-Host -ForegroundColor Green "Done"

            Write-Host -NoNewline "- Setting SteamController to run on login: "
            Start-Process -FilePath "$Env:Programfiles\SteamDeckTools\SteamController.exe" -ArgumentList "-run-on-startup"
            Write-Host -ForegroundColor Green "Done"

            Write-Host -NoNewline "- Creating Desktop Shortcuts for SteamDeckTools: "
            $shell = New-Object -comObject WScript.Shell
            $shortcut = $shell.CreateShortcut("$Home\Desktop\FanControl.lnk")
            $shortcut.TargetPath = "$Env:Programfiles\SteamDeckTools\FanControl.exe"
            $shortcut.Save()

            $shell = New-Object -comObject WScript.Shell
            $shortcut = $shell.CreateShortcut("$Home\Desktop\PerformanceOverlay.lnk")
            $shortcut.TargetPath = "$Env:Programfiles\SteamDeckTools\PerformanceOverlay.exe"
            $shortcut.Save()

            $shell = New-Object -comObject WScript.Shell
            $shortcut = $shell.CreateShortcut("$Home\Desktop\PowerControl.lnk")
            $shortcut.TargetPath = "$Env:Programfiles\SteamDeckTools\PowerControl.exe"
            $shortcut.Save()

            $shell = New-Object -comObject WScript.Shell
            $shortcut = $shell.CreateShortcut("$Home\Desktop\SteamController.lnk")
            $shortcut.TargetPath = "$Env:Programfiles\SteamDeckTools\SteamController.exe"
            $shortcut.Save()
            Write-Host -ForegroundColor Green "Done"
        }
    }

    function tweaks
    {
        Write-Host
        Write-Host ">>> TWEAKING WINDOWS STUFF " -BackgroundColor Green -ForegroundColor Black
        Write-Host

        if ($Hibernation.Checked)
        {
            Write-Host -NoNewline "- Disabling Hibernation: "
            Start-Process -FilePath "PowerCfg" -ArgumentList " /h off"
            Write-Host -ForegroundColor Green "Done"
        }
        if ($Utcfix.Checked)
        {
            Write-Host -NoNewline "- Setting Internal Clock To UTC: "
            Start-Process -FilePath "reg" -ArgumentList "add `"HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation`" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f" -Wait
            Write-Host -ForegroundColor Green "Done"
        }

        if ($Gamebar.Checked)
        {
            Write-Host -NoNewline "- Disabling ms-gamebar Link Error: "

            ## AveYo: fix ms-gamebar annoyance after uninstalling Xbox
            reg add HKCR\ms-gamebar /f /ve /d URL:ms-gamebar 2>&1 >''
            reg add HKCR\ms-gamebar /f /v "URL Protocol" /d "" 2>&1 >''
            reg add HKCR\ms-gamebar /f /v "NoOpenWith" /d "" 2>&1 >''
            reg add HKCR\ms-gamebar\shell\open\command /f /ve /d "\`"$env:SystemRoot\System32\systray.exe\`"" 2>&1 >''
            reg add HKCR\ms-gamebarservices /f /ve /d URL:ms-gamebarservices 2>&1 >''
            reg add HKCR\ms-gamebarservices /f /v "URL Protocol" /d "" 2>&1 >''
            reg add HKCR\ms-gamebarservices /f /v "NoOpenWith" /d "" 2>&1 >''
            reg add HKCR\ms-gamebarservices\shell\open\command /f /ve /d "\`"$env:SystemRoot\System32\systray.exe\`"" 2>&1 >''

            Write-Host -ForegroundColor Green "Done"
        }
        if ($Sleeplogin.Checked)
        {
            Write-Host -NoNewline "- Disabling Login Afte Sleep: "
            Start-Process -FilePath "PowerCfg" -ArgumentList "/SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0"
            Start-Process -FilePath "PowerCfg" -ArgumentList "/SETDCVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0"
            Write-Host -ForegroundColor Green "Done"
        }
        if ($AutoKeyboard.Checked)
        {
            Write-Host -NoNewline "- Setting Auto Show Touch Keyboard:  "
            Start-Process -FilePath "reg" -ArgumentList "add `"HKEY_CURRENT_USER\SOFTWARE\Microsoft\TabletTip\1.7`" /t REG_DWORD /v EnableDesktopModeAutoInvoke /d 1 /f" -Wait
            Write-Host -ForegroundColor Green "Done"
        }
    }

    function selectAll
    {
        [System.Windows.Forms.checkbox[]]$checks = ($Drivers, $Vc, $Directx, $DotNet, $Rivatuner, $SteamDeckTools, $EqualizerApo, $Adrenalin, $Cru, $Hibernation, $Sleeplogin, $Utcfix, $AutoKeyboard, $ReplaceOSK, $Gamebar)
        if ($global:allChecked)
        {
            $global:allChecked = $false
            foreach ($checkBox in $checks)
            {
                $checkBox.Checked = $false
            }
        }
        else
        {
            $global:allChecked = $true
            foreach ($checkBox in $checks)
            {
                $checkBox.Checked = $true
            }
        }
    }

    # Form buttons actions
    $STARTButton.Add_Click({
        $Form.Hide()
        download
        install
        config
        tweaks
        reboot
    })

    $Orientation.Add_Click({
        setOrientation
    })

    $Osk.Add_Click({
        osk
    })

    # Adding buttons to the form
    $form.Controls.Add($STARTButton)
    $form.Controls.Add($SelectallButton)
    $form.Controls.Add($Orientation)
    $form.Controls.Add($Osk)

    # Activate the form
    $Form.Add_Shown({ $Form.Activate() })
    [void] $Form.ShowDialog()

}

function reboot
{
    if ([System.Windows.MessageBox]::Show('Do you want to reboot the system?', 'WinDeck Helper', 'YesNo') -eq 'Yes')
    {
        Restart-Computer
    }
}

#Call the form function
run_form
