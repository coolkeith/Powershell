# This program will perform termination steps for user on Exchange
# 1) Hide user from GAL
# 2) Remove users Phone and Devices (if applicable)
# 3) Disable OWA and ActiveSync
# 4) Add mailbox Delivery restriction to block email



#Setup Exchange Session
$env:USERNAME
$mysecrets = Get-Credential "workdomain\$env:USERNAME"
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://exhangehostname/PowerShell/ -Authentication Kerberos -Credential $mysecrets
Import-PSSession $Session -DisableNameChecking -AllowClobber

$Users = Get-Content -LiteralPath "C:\users\kfranz\Desktop\Lists\TermUser.txt"
foreach ($User in $Users) {
####
# 1) Hide the user from the GAL
Set-Mailbox -Identity $User -HiddenFromAddressListsEnabled $True



####
# 2) Get User Mailbox Properties
$MailboxInfo = Get-Mailbox -Identity "$User" -filter * | select *
$CASMailboxInfo = Get-CASMailbox -Identity $User -filter * | select *

#Filter allowed mobile devices associated with user
$UsersMobileDevices = Get-MobileDevice -Mailbox "$User" | Where-Object -FilterScript {$_.DeviceAccessState -eq "Allowed"}
#Not tested yet...
#Set-CASMailbox -Identity $MailboxInfo.Name -ActiveSyncAllowedDeviceIDs @{Remove="$UserMobileDevice.DeviceId"}
#Set-CASMailbox -Identity $MailboxInfo.Name -ActiveSyncAllowedDeviceIDs @{add='type DeviceID here'}    


####
# 3) Disables ActiveSync 
Set-CASMailbox -Identity $User -ActiveSyncEnabled $False

#### Disables OWA
Set-CASMailbox -Identity $User -OWAEnabled $false

    # How do you know this worked?
    # Get-CASMailbox -Identity <MailboxIdentity>
    # If Outlook on the web is enabled, the value for the OWAEnabled property is True.
    # If Outlook on the web is disabled, the value is False.


####
# 4) Add mailbox Delivery restriction to block email
Set-Mailbox -Identity $User -AcceptMessagesOnlyFrom "Keith Franz","team member1", "team member2"
#$A = Read-Host "Type the forwarding address"
#Set-Mailbox -Identity "$User" -ForwardingAddress @{add='$A'}

    # How do you know this worked?
    # Get-Mailbox $User | Format-List AcceptMessagesOnlyFrom,AcceptMessagesOnlyFromDLMembers,RejectMessagesFrom,RejectMessagesFromDLMembers,RequireSenderAuthenticationEnabled

# Start-Sleep -Seconds 20

        $HashTable = [Ordered]@{
        HiddenFromAddressListsEnabled = $MailboxInfo.HiddenFromAddressListsEnabled
        ActiveSyncEnabled = $CASMailboxInfo.ActiveSyncEnabled
        OWAEnabled = $CASMailboxInfo.OWAEnabled
        AcceptMessagesOnlyFrom = $MailboxInfo.AcceptMessagesOnlyFrom
        ForwardingAddress = $A
        }
        
        Write-Host $User
        Write-Host "-----"      
        New-Object -Property $HashTable -TypeName psobject
        Write-Host "-----"
        Write-Host "     "
        Write-Host "     "
}
