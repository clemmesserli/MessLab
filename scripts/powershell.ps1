if (-not(Test-Path C:\GitHub)) {
    New-Item -Path C:\GitHub -ItemType Directory
}

#region Initialize PSProfile
$data = Invoke-RestMethod 'https://raw.githubusercontent.com/clemmesserli/MessLab/main/data/powershell/profile.ps1'
$data | Out-File 'C:\github\profile.ps1' -Encoding utf8

$files = @(
    "C:\Program Files\PowerShell\7\profile.ps1"
    "C:\Program Files\PowerShell\7\Microsoft.PowerShell_profile.ps1"

    "C:\Windows\System32\WindowsPowerShell\v1.0\Microsoft.PowerShell_profile.ps1"
    "C:\Windows\System32\WindowsPowerShell\v1.0\Microsoft.PowerShellISE_profile.ps1"
    "C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1"

    "$($env:onedrive)\PowerShell\Microsoft.PowerShell_profile.ps1"
    "$($env:onedrive)\PowerShell\profile.ps1"
    "$($env:onedrive)\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    "$($env:onedrive)\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1"
    "$($env:onedrive)\WindowsPowerShell\profile.ps1"
)

foreach ($file in $files) {
    #$file = $files[2]
    try {
        Set-Content -Value '. C:\github\profile.ps1' -Path $file -Force -ErrorAction Stop
    } catch {
        Write-Error "$($file) does not exist"
    }
}
#endregion

#region Install Modules
#Write-Host "Updating PackageProvider" -ForegroundColor Green
#[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#Install-PackageProvider -Name NuGet -MinimumVersion 3.0.0.1 -Force
$modules = @(
    "AutoRuns"
    "CredentialManager"
    "Curl2PS"
    "Devolutions.PowerShell"
    "Devolutions.Server"
    "Microsoft.PowerShell.SecretManagement"
    "Microsoft.PowerShell.SecretStore"
    "Pester"
    "PowershellBGInfo"
    "PSKoans"
    "PSReadLine"
    "PSReadlineHistory"
    "PSWordle"
    "SysInfo"
    "SysInternals"
    "Systeminfo"
    "UniversalDashboard"
    "Wsl"
)
Foreach ($module in $modules) {
    Write-Host "Installing $module" -ForegroundColor Green
    Install-Module -Repository 'PSGallery' -Scope AllUsers -AllowClobber -AllowPrerelease -SkipPublisherCheck -Force -Name $module -Verbose
}
#endregion

#Ref: https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules
#Create a password as a SecureString and convert to PSCredential (Username not used)
$password = 'SecureStore' | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object pscredential("StoreUser", $password)

#exported to an XML file and encrypted by Windows Data Protection (DPAPI)
$securePasswordPath = "$($global:labSources)\PSVault.xml"
$credential.Password |  Export-Clixml -Path $securePasswordPath


Register-SecretVault -Name 'PSVault' -ModuleName 'Microsoft.PowerShell.SecretStore' -DefaultVault
$password = Import-Clixml -Path $securePasswordPath

$storeConfiguration = @{
    Authentication  = 'Password'
    PasswordTimeout = 3600 # 1 hour
    Interaction     = 'None'
    Password        = $password
    Confirm         = $false
}
Set-SecretStoreConfiguration @storeConfiguration


# Import the masterkey and unlock vault
$password = Import-Clixml -Path $securePasswordPath
Unlock-SecretStore -Password $password

# Create a secret
Set-Secret -Name "MyAuthToken" -Secret "AL+PS=Automation" -Vault "PSVault"

# Get the secret value
$myAuthToken = Get-Secret -Name "MyAuthToken" -AsPlainText
Write-Host "Your Secret Is: [$myAuthToken]" -ForegroundColor Green
#endregion


#Install PowerShell Universal Server (http://localhost:5000)
Install-PSUServer
Start-Process http://localhost:5000