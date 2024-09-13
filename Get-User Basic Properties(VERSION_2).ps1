<#
.SYNOPSIS
    Script to gather user information and save to a shared UNC location.

.DESCRIPTION
    This script collects various user information and saves it to a centralized shared UNC location.

.NOTES
    File Name      : Get-User Basic Properties.ps1
    Author         : Keith Franz
    Prerequisite   : PowerShell v3 and above
    Copyright 2023 - All rights reserved.

.VERSION
    1.0
#>

#-----------------------------------------------------------------------Are you on the network or not?--------------------------------------------------------------------------------------------#

# Function to ping a DNS host
function Test-DNSConnection {
    param (
        [string]$dnsHost
    )
    $pingResult = Test-Connection -ComputerName $dnsHost -Count 1 -Quiet
    return $pingResult
}

# DNS host to ping
$dnsHost = "US-SEA-AD01"

# Check if the DNS host is reachable
if (-Not (Test-DNSConnection -dnsHost $dnsHost)) {
    $message = "You're not connected to the network.`nPlease check your network connection and try again.`nIf issue persists please call IT to let them know"
    $title = "Network Connection Issue"
    $icon = "Error" # "Error", "Warning", "Information"
    [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::$icon)
    exit 1
}

#-----------------------------------------------------------------------Now that we know this--------------------------------------------------------------------------------------------#

# Gather user information and save to a shared UNC location


# Function to get the current user's domain and username
function Get-UserFullName {
    $domain = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty Domain
    $username = $env:USERNAME
    return "$username@$domain"
}

# Function to get all IP addresses associated with the user's network adapters
function Get-UserIPAddresses {
    $ipAddresses = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | ForEach-Object { $_.IPAddress }
    return $ipAddresses
}


# Function to get the user's open applications
function Get-UserOpenApplications {
    $openApps = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object Name, MainWindowTitle
    return $openApps
}

# Function to get the user's open netstat connections
function Get-UserNetstatConnections {
    $netstatOutput = & netstat -ano
    return $netstatOutput
}

# Function to get the amount of time the users computer has been up
function Get-UsersComputerUptime {
    $UPTIME = (Get-Date) - (Get-CimInstance Win32_OperatingSystem -ComputerName $PC).LastBootupTime
    return $UPTIME
}

# Function to get the Operating System info from the users computer
function Get-UsersOperatingSystemInfo {
    $UsersOSInfo = Get-WmiObject Win32_OperatingSystem | Select PSComputerName, Caption, OSArchitecture, Version, BuildNumber
    return $UsersOSInfo
}

# Function to get the Operating System Update info from the users computer
function Get-PendingUpdates {
    $PendingUpdates = Get-WmiObject -Namespace "root\ccm\clientsdk" -Class CCM_SoftwareUpdate |format-list -Property Deadline,ErrorCode,Name
    return $PendingUpdates
}

#-----------------------------------------------------------------------Function Separation--------------------------------------------------------------------------------------------#

# Gather user information
$currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$userFullName = Get-UserFullName
$computerName = $env:COMPUTERNAME
$userIPAddresses = Get-UserIPAddresses
$openApplications = Get-UserOpenApplications
$netstatConnections = Get-UserNetstatConnections
$UPTIME = Get-UsersComputerUptime
$UserOSInfo = Get-UsersOperatingSystemInfo
$PendingUpdates = Get-PendingUpdates

# Combine all gathered information into a single object
$userInfo = [Ordered]@{
    "Time" = $currentTime
    "User Full Name" = $userFullName
    "Computer Name" = $computerName
    "IP Addresses" = $userIPAddresses
    "UPTIME" = @($UPTIME.Days, $UPTIME.Hours, $UPTIME.Minutes)
    "Open Applications" = $openApplications
    "Netstat Connections" = $netstatConnections
    "OS Information" = $UserOSInfo
    "Pending Updates" = $PendingUpdates
}

# Convert the object to JSON format
$userInfoJson = $userInfo | ConvertTo-Json

# Generate the filename with the format: %Username%_%Date%_Info.json
$filename = "{0}_{1}_Info.json" -f $userFullName, (Get-Date -Format "yyyyMMdd")

# Replace the UNC_PATH with the actual shared UNC path you want to save the information to
$UNC_PATH = "\\galileo\it\Logs\User_Issues\$filename"

# Save the information to the centralized shared UNC location
$userInfoJson | Out-File -FilePath $UNC_PATH

Write-Host "User information has been saved to: $UNC_PATH"

$ExitMessage = "A log of your system details has been copied to the network.`nPlease contact IT and let them know your name and the time it was sent"
    $ExitTitle = "System Details Successfully Sent"
    $ExitIcon = "Information" # "Error", "Warning", "Information"
    [System.Windows.Forms.MessageBox]::Show($ExitMessage, $ExitTitle, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::$ExitIcon)
