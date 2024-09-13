# Uses the Enable-Mailbox cmdlet to create mailboxes for existing users who don't already have mailboxes
# In other words... it creates the user mailbox from existing user we just built in AD
#
#
# 1) Get User Distinguished Names
# 2) Enables Mailbox on Existing AD user
# 3) 
# 4) 


# Setup Exchange Session
$env:USERNAME
$mysecrets = Get-Credential "user@domain.com"
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://exchangehostname/PowerShell/ -Authentication Kerberos -Credential $mysecrets
Import-PSSession $Session -DisableNameChecking -AllowClobber

# Define database variables/values

$A_through_F = "exch-DB1"
$G_through_K = "exch-DB2"
$L_through_P = "exch-DB3"
$Q_through_U = "exch-DB4"
# $V_through_Z = "exch-DB5"   <--- this datatbase has been removed 11MAY2023 we were running into space issues. long story, we can re-create and re-add later...
$V_through_Z = "exch-DB6"

Write-Host "//////*//////////////////////////////////" -ForegroundColor Black -BackgroundColor Yellow
Write-Host "///////////////////*/////////////////////" -ForegroundColor Black -BackgroundColor Yellow
Write-Host "///////////////////////////////////*/////" -ForegroundColor Black -BackgroundColor Yellow
Write-Host "//////*//////////////////////////////////" -ForegroundColor Black -BackgroundColor Yellow
Write-Host "///////////////////*/////////////////////" -ForegroundColor Black -BackgroundColor Yellow
Write-Host "///////////////////////////////////*/////" -ForegroundColor Black -BackgroundColor Yellow

#####
# 1)
# This converts the full name to DistinguishedName, so it can be used later in other functions.
# Specifically in the Exchange Enable-Mailbox cmdlet

$Users = Get-Content C:\Users\kfranz\Desktop\Lists\Users.txt
foreach ($User in $Users) {

#Write-Host "Enter the user name in the format of first name space last name...e.g.    Keith Franz"
#Write-Host "Enclose the users name in quotation marks"
#$User = Read-Host "Please enter the user"

Write-host "Fetching $User properties..." -ForegroundColor red -BackgroundColor Black
Write-Host ""

$UserSurname = Get-ADUser $User | select-object -ExpandProperty Surname
#Gets Surname

$FirstCharacterSurName = $UserSurname.SubString(0,1)

Write-Host "The first character of the surname of the user you have entered is: $FirstCharacterSurName"

if ( $FirstCharacterSurName -eq "A" -or $FirstCharacterSurName -eq "B" -or $FirstCharacterSurName -eq "C" -or $FirstCharacterSurName -eq "D" -or $FirstCharacterSurName -eq "E" -or $FirstCharacterSurName -eq "F" )
{
    Write-Host "User belongs in $A_through_F database"
    Write-Host "Fetching DistinguishedName for:   " -ForegroundColor white -BackgroundColor DarkRed -NoNewline
    Write-Host $User -ForegroundColor White -BackgroundColor Green
    Get-ADUser $User | select-object -ExpandProperty DistinguishedName -OutVariable DistinguishedName
    Write-Host "The DistinguishedName for this user is: $DistinguishedName"
    Enable-Mailbox -Identity "$DistinguishedName" -Database $A_through_F -Verbose
}

elseif ( $FirstCharacterSurName -eq "G" -or $FirstCharacterSurName -eq "H" -or $FirstCharacterSurName -eq "I" -or $FirstCharacterSurName -eq "J" -or $FirstCharacterSurName -eq "K" )
{
    Write-Host "User belongs in $G_through_K database"
    Write-Host "Fetching DistinguishedName for:   " -ForegroundColor white -BackgroundColor DarkRed -NoNewline
    Write-Host $User -ForegroundColor White -BackgroundColor Green
    Get-ADUser $User | select-object -ExpandProperty DistinguishedName -OutVariable DistinguishedName
    Write-Host "The DistinguishedName for this user is: $DistinguishedName"
    Enable-Mailbox -Identity "$DistinguishedName" -Database $G_through_K -Verbose
}

elseif ( $FirstCharacterSurName -eq "L" -or $FirstCharacterSurName -eq "M" -or $FirstCharacterSurName -eq "N" -or $FirstCharacterSurName -eq "O" -or $FirstCharacterSurName -eq "P" )
{
    Write-Host "User belongs in $L_through_P database"
    Write-Host "Fetching DistinguishedName for:   " -ForegroundColor white -BackgroundColor DarkRed -NoNewline
    Write-Host $User -ForegroundColor White -BackgroundColor Green
    Get-ADUser $User | select-object -ExpandProperty DistinguishedName -OutVariable DistinguishedName
    Write-Host "The DistinguishedName for this user is: $DistinguishedName"
    Enable-Mailbox -Identity "$DistinguishedName" -Database $L_through_P -Verbose
}

elseif ( $FirstCharacterSurName -eq "Q" -or $FirstCharacterSurName -eq "R" -or $FirstCharacterSurName -eq "S" -or $FirstCharacterSurName -eq "T" -or $FirstCharacterSurName -eq "U" )
{
    Write-Host "User belongs in $Q_through_U database"
    Write-Host "Fetching DistinguishedName for:   " -ForegroundColor white -BackgroundColor DarkRed -NoNewline
    Write-Host $User -ForegroundColor White -BackgroundColor Green
    Get-ADUser $User | select-object -ExpandProperty DistinguishedName -OutVariable DistinguishedName
    Write-Host "The DistinguishedName for this user is: $DistinguishedName"
    Enable-Mailbox -Identity "$DistinguishedName" -Database $Q_through_U -Verbose
}

else 
{
    Write-Host "User belongs in $V_through_Z database"
    Write-Host "Fetching DistinguishedName for:   " -ForegroundColor white -BackgroundColor DarkRed -NoNewline
    Write-Host $User -ForegroundColor White -BackgroundColor Green
    Get-ADUser $User | select-object -ExpandProperty DistinguishedName -OutVariable DistinguishedName
    Write-Host "The DistinguishedName for this user is: $DistinguishedName"
    Enable-Mailbox -Identity "$DistinguishedName" -Database $V_through_Z -Verbose
}
Write-Host ""
Write-Host ""
}
