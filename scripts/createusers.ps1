New-ADUser EMAdmin -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true
$user = Get-ADUser -filter { name -like "EMAdmin" }
$group = Get-ADGroup -Filter { name -like "Domain Admins" }
$groupDA = Get-ADGroup -Filter { name -like "Domain Admins" }

Add-ADGroupMember -Identity $group -Members $user

$object = New-Object System.Security.Principal.NTAccount("EMAdmin")
$SID = $object.Translate([System.Security.Principal.SecurityIdentifier])

New-ADGroup -Name "pci" -SamAccountName PCI -GroupCategory Security -GroupScope Global -DisplayName "PCI" -Description "Members of PCI"
New-ADGroup -Name "secret" -SamAccountName Secret -GroupCategory Security -GroupScope Global -DisplayName "Secret" -Description "Members of Secret"
New-ADGroup -Name "topsecret" -SamAccountName TopSecret -GroupCategory Security -GroupScope Global -DisplayName "TopSecret" -Description "Members of TopSecret"
New-ADGroup -Name "sales" -SamAccountName Sales -GroupCategory Security -GroupScope Global -DisplayName "Sales" -Description "Members of Sales"

New-ADUser pciUser1 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true
New-ADUser pciUser2 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true
New-ADUser pciUser3 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true

$user = Get-ADUser -Filter { name -like "pciUser1" }
$group = Get-ADGroup -Filter { name -like "pci" }
Add-ADGroupMember -Identity $group -members $user

$user = Get-ADUser -Filter { name -like "pciUser2" }
Add-ADGroupMember -Identity $group -members $user

$user = Get-ADUser -Filter { name -like "pciUser3" }
Add-ADGroupMember -Identity $group -members $user

Add-ADGroupMember -Identity $groupDA -Members $group

New-ADUser secretUser1 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true
New-ADUser secretUser2 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true
New-ADUser secretUser3 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true

$user = Get-ADUser -Filter { name -like "secretUser1" }
$group = Get-ADGroup -Filter { name -like "secret" }
Add-ADGroupMember -Identity $group -members $user

$user = Get-ADUser -Filter { name -like "secretUser2" }
Add-ADGroupMember -Identity $group -members $user

$user = Get-ADUser -Filter { name -like "secretUser3" }
Add-ADGroupMember -Identity $group -members $user

New-ADUser topSecret1 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true
New-ADUser topSecret2 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true
New-ADUser topSecret3 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true

$user = Get-ADUser -Filter { name -like "topSecret1" }
$group = Get-ADGroup -Filter { name -like "topsecret" }
Add-ADGroupMember -Identity $group -members $user

$user = Get-ADUser -Filter { name -like "topSecret2" }
Add-ADGroupMember -Identity $group -members $user

$user = Get-ADUser -Filter { name -like "topSecret3" }
Add-ADGroupMember -Identity $group -members $user

New-ADUser sales1 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true
New-ADUser sales2 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true
New-ADUser sales3 -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssword1" -Force) -Enabled $true -PasswordNeverExpires $true

$user = Get-ADUser -Filter { name -like "sales1" }
$group = Get-ADGroup -Filter { name -like "sales" }
Add-ADGroupMember -Identity $group -members $user

$user = Get-ADUser -Filter { name -like "sales2" }
Add-ADGroupMember -Identity $group -members $user

$user = Get-ADUser -Filter { name -like "sales3" }
Add-ADGroupMember -Identity $group -members $user