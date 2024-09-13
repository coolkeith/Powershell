########################################### Purpose: This scripts grabs basic infos about servers in a list
###################### Author: Keith Franz
##### Date: FEB2021
$ErrorActionPreference='SilentlyContinue'
$FormatEnumerationLimit=-1
Get-Date
Write-Host ""
Write-Host ""
Write-Host ""
$PCList = Get-Content -Path "C:\Users\kfranz\Desktop\Lists\BSOD.txt"
Foreach ($PC in $PCList)
{
Write-Host "///////////////////////////////////////////////////////////////////////////" -ForegroundColor Black -BackgroundColor White
Write-Host ""
   $UPTIME = (Get-Date) - (Get-CimInstance Win32_OperatingSystem -ComputerName $PC).LastBootupTime
  
   Write-Host " "
   Write-Host $PC -ForegroundColor Black -BackgroundColor Yellow -NoNewline
   Write-Host " has been up for " -NoNewline
   Write-Host $UPTIME.Days -NoNewline -ForegroundColor Black -BackgroundColor Green
   Write-Host " Days " -NoNewline
   Write-Host $UPTIME.Hours -NoNewline -ForegroundColor Black -BackgroundColor Green
   Write-Host " Hours " -NoNewline
   Write-Host $UPTIME.Minutes -NoNewline -ForegroundColor Black -BackgroundColor Green
   Write-Host " Minutes " -NoNewline
   Write-Host " "

$ServerBuildInfo = Get-WmiObject Win32_OperatingSystem -ComputerName $PC | Select PSComputerName, Caption, OSArchitecture, Version, BuildNumber
#$ServerHotfixInfo = get-hotfix -ComputerName $PC | sort installedon | Select-Object -Last 15 hotfixid, installedon | ft -Property hotfixid, installedon


$REGWUServer = REG QUERY "\\$PC\HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v WUServer
$REGWUStatusServer = REG QUERY "\\$PC\HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v WUStatusServer
$REGSusClientId = REG QUERY "\\$PC\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientId

#$REGCachedAUOptions = Get-ItemProperty -Path "\\$PC\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\" -Name "CachedAUOptions" -ErrorAction SilentlyContinue
#$REGForcedReboot = Get-ItemProperty -Path "\\$PC\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\" -Name "ForcedReboot" -ErrorAction SilentlyContinue
#Current Logged on Users# qwinsta.exe /server:$PC

$REGCachedAUOptions = REG QUERY "\\$PC\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v CachedAUOptions
$REGForcedReboot = REG QUERY "\\$PC\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v ForcedReboot

$WUService = get-service -computername $PC -Name wuauserv
write-host "The $($WUService.name) service on $PC is $($WUService.status)"
   
    If($WUService.Status -eq "Stopped")
    {
    get-service -Name $WUService.name -ComputerName $PC | start-service
    }
Else {Write-Host "The wuauserv service on $PC is Running"}
Write-Host ""
Copy-Item -LiteralPath \\$PC\C$\windows\WindowsUpdate.log -Destination "\\WOR7052\C$\Log Files\$PC`_WU.log" -Verbose

$HashTable = [Ordered]@{
Computername = $ServerBuildInfo.PSComputerName
OS =  $ServerBuildInfo.Caption
OSArchitecture = $ServerBuildInfo.OSArchitecture
Version = $ServerBuildInfo.Version
BuildNumber = $ServerBuildInfo.BuildNumber

WUServer = $REGWUServer
WUStatusServer = $REGWUStatusServer
SusClientId = $REGSusClientId 
CachedAUOptions = $REGCachedAUOptions
ForcedReboot = $REGForcedReboot 
WindowsUpdateService = $WUService.status
}

#$HotFixHashTable = [Ordered]@{
#Hotfixid = $ServerHotfixInfo.Hotfixid
#Installedon = $ServerHotfixInfo.Installedon
#}

New-Object -Property $HashTable -TypeName psobject
#New-Object -Property $HotFixHashTable -TypeName psobject
Invoke-Command -ComputerName $PC -ScriptBlock {get-computerinfo | select OsLastBootUpTime}
get-hotfix -ComputerName $PC | sort hotfixid | Select-Object -Last 15 hotfixid, installedon | ft -Property hotfixid, installedon
Write-Host -ForegroundColor White -BackgroundColor DarkMagenta "Updates Pending...."
Invoke-Command -ComputerName $PC -ScriptBlock {Get-WmiObject -Namespace "root\ccm\clientsdk" -Class CCM_SoftwareUpdate |format-list -Property Deadline,ErrorCode,Name}
}
