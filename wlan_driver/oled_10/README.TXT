Usage of PETool package

1. Pre-request

The PETool is supposed to run on a Windows PE system with Qualcomm Atheros 
Wi-Fi chip attached.

2. Install the Qualcomm Atheros Wi-Fi driver by drvload command.
   For example: drvload netahrx.inf

3. The usage of PEDiagUtility.exe
3.1 Register WlanMonHelper module:
regsvr32 "%PETool_DIR%\wlanmonhelper.dll"

3.2 Run PETool
PEDiagUtility Test <TestNo> [-SSID <ApName> ][-THREADHOLD <Number>] [-d <output-file path>]

Example: 
 PEDiagUtility Test 6 -SSID Hydra -THREADHOLD -55	- for antenna connectivity test.
 PEDiagUtility Test 1 -LED On -d C:\Test.txt		- for single tests
 PEDiagUtility Test 1 5 4 -LED Off -d C:\Test.txt	- for specific tests
 PEDiagUtility Test 1 To 10 -LED Off -d C:\Test.txt	- for range of tests

NOTE:
Currently only the Test 6 for antenna connectivity test is supported for QCA61x4.
Need writhe the correct BT_HWID to disable BT for Test 6 for Aphrodite.

---------------------------------------------------------

PE Test Cases :
	 1  : Module/mini Cards Detection.
	 2  : Device IO and IRG Assignments.
	 3  : Device & Vendor Information.
	 4  : WLAN MAC Address.
	 5  : System IRG number used.
	 6  : Antenna Connectivity Test.
	 7  : WLAN LED Status and On/Off Test.
	 8  : Wirless Switch Status and On/Off Test.
	 9 : COEX_ BT_ACTIVE Status Test.
	 10 : COEX_WLAN_ACTIVE On/Off Test.
	 -d  : <dump-file> : Redirect output to the file.