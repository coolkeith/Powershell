#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Finds disabled AD users (in specified OUs) whose mailboxes have no delegates,
    exports the results to CSV, and emails the report.

.NOTES
    - Run as a service account with read access to AD and Exchange Online.
    - Requires: ActiveDirectory module, ExchangeOnlineManagement module.
    - Uses a non-interactive app-based connection to Exchange Online (CBA).
      Swap the Connect-ExchangeOnline block if using Basic/credential auth in a lab.
#>

[CmdletBinding()]
param (
    # Optional: override recipient at runtime
    [string]$To = "<email address>",

    # DC used to resolve orphaned permission SIDs back to AD accounts
    [string]$ADServer = "<local AD>"
)

# --- 0. CONFIG -----------------------------------------------------------------------------------------------

$OUs = @(
    "OU=<ou>,DC=<domain>,DC=com"
    )

# Email settings
$SmtpServer   = "<your SMTP server>"
$SmtpPort     = 25
$FromAddress  = "<whatever you want>"
$ToAddress    = $To
$EmailSubject = "AD Audit: Terminated Employees without Mailbox Delegation - $(Get-Date -Format 'yyyy-MM-dd')"

# Exchange Online app-based (certificate) auth -- replace values as needed.
# If you use a managed identity or stored credential, swap this block.
$AppId        = "<Azure App ID>"           # Azure AD App Registration client ID
$TenantId     = "<tenant.onmicrosoft.com>"        # e.g. yourcompany.onmicrosoft.com or GUID
$CertThumb    = "<cert thumb>"  # Cert installed in LocalMachine\My

# Temp CSV path
$CsvPath = Join-Path $env:TEMP "TerminatedNoDelegation_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

# --- 1. CONNECT TO EXCHANGE ONLINE (non-interactive / service account) ---------------------------------------

try {
    Import-Module ExchangeOnlineManagement -ErrorAction Stop

    Connect-ExchangeOnline `
        -AppId $AppId `
        -Organization $TenantId `
        -CertificateThumbprint $CertThumb `
        -ShowBanner:$false `
        -ErrorAction Stop

    Write-Verbose "Connected to Exchange Online."
}
catch {
    Write-Error "Failed to connect to Exchange Online: $_"
    exit 1
}

# --- 2. GET DISABLED USERS FROM EACH OU ----------------------------------------------------------------------

$disabledUsers = foreach ($ou in $OUs) {
    try {
        Get-ADUser -SearchBase $ou `
                   -Filter { Enabled -eq $false } `
                   -Properties mail, DisplayName, SamAccountName, DistinguishedName `
                   -ErrorAction Stop |
            Where-Object { $_.mail }   # skip accounts with no mail attribute
    }
    catch {
        Write-Warning "Could not query OU '$ou': $_"
    }
}

Write-Verbose "Found $($disabledUsers.Count) disabled users with a mail attribute."

if (-not $disabledUsers) {
    Write-Output "No disabled users found. Exiting."
    Disconnect-ExchangeOnline -Confirm:$false
    exit 0
}

# --- 3. CHECK EACH MAILBOX FOR DELEGATION -------------------------------------------------------------------------------
# A mailbox has VALID delegation only if at least one delegate is a RESOLVED
# account (a real name/UPN). Entries that come back as a raw SID mean Exchange
# could not resolve the trustee to a current recipient -- the account was
# deleted, disabled/de-synced, or is otherwise orphaned. Those are broken/stale
# permissions and are NOT counted as delegation; instead they're flagged so
# they can be investigated.
#
# System-injected SIDs Exchange always adds (never real delegates):
#   S-1-5-10  = NT AUTHORITY\SELF
#   S-1-5-18  = NT AUTHORITY\SYSTEM
#   S-1-5-32-544 = BUILTIN\Administrators
$SystemSids = @("S-1-5-10", "S-1-5-18", "S-1-5-32-544")

# Matches any raw, unresolved SID (e.g. S-1-5-21-...-204392)
$SidPattern = '^S-1-\d+(-\d+)+$'

# Resolve an orphaned SID back to its AD account.
# In some hybrid environments, orphaned trustees may still resolve against
# on-prem AD and report Enabled state without needing Graph.
function Resolve-OrphanSid {
    param([string]$Sid, [string]$Server)
    try {
        $u = Get-ADUser -Identity $Sid -Server $Server -Properties Enabled -ErrorAction Stop
        $state = if ($u.Enabled) { 'Enabled' } else { 'Disabled' }
        return ('{0} ({1}) [{2}]' -f $u.Name, $u.SamAccountName, $state)
    }
    catch {
        # Not a user object, or no longer present in AD (likely deleted)
        try {
            $o = Get-ADObject -Filter "objectSid -eq '$Sid'" -Server $Server `
                              -Properties objectClass -ErrorAction Stop
            if ($o) { return ('{0} [{1}]' -f $o.Name, $o.objectClass) }
        }
        catch { }
        return 'UNRESOLVED - not found in AD (likely deleted)'
    }
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($user in $disabledUsers) {
    $smtp = $user.mail.Trim()

    try {
        # --- Full Access ---
        $faAll = @(
            Get-MailboxPermission -Identity $smtp -ErrorAction Stop |
                Where-Object {
                    $_.Deny -eq $false -and
                    $SystemSids -notcontains $_.UserSid -and
                    $_.User -notmatch "^NT AUTHORITY"
                }
        )
        $faResolved = @($faAll | Where-Object { $_.User -notmatch $SidPattern })
        $faOrphans  = @($faAll | Where-Object { $_.User -match  $SidPattern } |
                        Select-Object -ExpandProperty User)

        # --- Send As ---
        $saAll = @(
            Get-RecipientPermission -Identity $smtp -ErrorAction Stop |
                Where-Object {
                    $_.AccessControlType -eq 'Allow' -and
                    $_.Trustee -notmatch "^NT AUTHORITY"
                }
        )
        $saResolved = @($saAll | Where-Object { $_.Trustee -notmatch $SidPattern })
        $saOrphans  = @($saAll | Where-Object { $_.Trustee -match  $SidPattern } |
                        Select-Object -ExpandProperty Trustee)

        # --- Send On Behalf ---
        $mailbox = Get-Mailbox -Identity $smtp -ErrorAction Stop
        $sobAll  = @($mailbox.GrantSendOnBehalfTo | ForEach-Object { "$_" })
        $sobResolved = @($sobAll | Where-Object { $_ -notmatch $SidPattern -and $_ -ne '' })
        $sobOrphans  = @($sobAll | Where-Object { $_ -match  $SidPattern })

        # Counts reflect RESOLVED delegates only
        $faCount  = $faResolved.Count
        $saCount  = $saResolved.Count
        $sobCount = $sobResolved.Count

        # All orphaned SIDs found across permission types, de-duplicated
        $orphanSids = @($faOrphans + $saOrphans + $sobOrphans | Select-Object -Unique)

        Write-Verbose ("{0,-40} FA={1} SA={2} SOB={3} OrphanSIDs={4}" -f `
            $smtp, $faCount, $saCount, $sobCount, $orphanSids.Count)

        $hasValidDelegation = ($faCount -gt 0) -or ($saCount -gt 0) -or ($sobCount -gt 0)

        if (-not $hasValidDelegation) {
            # Resolve each orphaned SID against AD so the report says who it WAS
            $orphanDetail = foreach ($sid in $orphanSids) {
                '{0} => {1}' -f $sid, (Resolve-OrphanSid -Sid $sid -Server $ADServer)
            }

            $results.Add([PSCustomObject]@{
                DisplayName         = $user.DisplayName
                SamAccountName      = $user.SamAccountName
                EmailAddress        = $smtp
                OU                  = ($user.DistinguishedName -replace '^CN=[^,]+,','')
                FullAccessCount     = $faCount
                SendAsCount         = $saCount
                SendOnBehalfCount   = $sobCount
                OrphanedSidCount    = $orphanSids.Count
                OrphanedPermissions = ($orphanDetail -join ' ; ')
            })
        }
    }
    catch {
        Write-Warning "Could not check mailbox for '$smtp': $_"
    }
}

Write-Verbose "$($results.Count) disabled users have NO mailbox delegation."

# --- 4. EXPORT TO CSV ----------------------------------------------------------------------------------------------

if ($results.Count -eq 0) {
    $body = @"
Hello,

The automated AD audit completed on $(Get-Date -Format 'yyyy-MM-dd HH:mm') and found
no disabled users with unmanned mailboxes in the monitored OUs.

OUs checked:
$($OUs -join "`n")

-- Automation
"@
    Send-MailMessage -SmtpServer $SmtpServer -Port $SmtpPort `
                     -From $FromAddress -To $ToAddress `
                     -Subject $EmailSubject -Body $body
    Write-Output "No results --- notification email sent."
    Disconnect-ExchangeOnline -Confirm:$false
    exit 0
}

$results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
Write-Verbose "CSV saved to $CsvPath"

# --- 5. BUILD EMAIL BODY & SEND ------------------------------------------------------------------------------------

$ouList  = $OUs -join "`n  "
$summary = $results |
    Group-Object { $_.OU -replace 'OU=([^,]+),.*','$1' } |
    ForEach-Object { "  $($_.Name): $($_.Count) user(s)" }

$body = @"
Hello,

The automated AD audit completed on $(Get-Date -Format 'yyyy-MM-dd HH:mm').

SUMMARY
-------
Total disabled users with no mailbox delegation: $($results.Count)

Breakdown by OU:
$($summary -join "`n")

OUs audited:
  $ouList

Please see the attached CSV for the full list. Consider whether these mailboxes
should be delegated to a manager, converted to shared mailboxes, or deprovisioned.

-- Automation
"@

try {
    Send-MailMessage `
        -SmtpServer $SmtpServer `
        -Port       $SmtpPort   `
        -From       $FromAddress `
        -To         $ToAddress  `
        -Subject    $EmailSubject `
        -Body       $body `
        -Attachments $CsvPath `
        -ErrorAction Stop

    Write-Output "Report emailed to $ToAddress with $($results.Count) entries."
}
catch {
    Write-Error "Failed to send email: $_"
}
finally {
    # Clean up temp file
    Remove-Item $CsvPath -Force -ErrorAction SilentlyContinue
    Disconnect-ExchangeOnline -Confirm:$false
}
