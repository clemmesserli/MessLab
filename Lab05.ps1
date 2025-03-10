<#
.EXAMPLE
.\Lab05.ps1 -Credential $MyLabCred
Creates a lab definition using all pre-defined param defaults
#>
[cmdletBinding()]
param(
  [pscredential]$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
  [string]$CIDR = '10.10.5.0/24',
  [string]$DomainName = 'messlabs.com',
  [string]$LabName = 'Lab05',
  [string]$VMPath = 'L:\LabVMs',
  [string]$LocalFolderPath = "$(Get-LabSourcesLocation)",
  [string]$RemoteFolderPath = 'C:\LabSources'
)

#Import dependencies
Import-Module C:\MyGitHub\MessKit\MessKit.psd1 -Force

if ( (Get-Service ShellHWDetection).Status -ne 'Running') {
  Start-Service ShellHWDetection
}
New-LabDefinition -VmPath $vmPath -Name $labName -ReferenceDiskSizeInGB 100 -DefaultVirtualizationEngine HyperV

# define our default credentials
$UserName = $credential.GetNetworkCredential().UserName
$Password = $credential.GetNetworkCredential().Password
Add-LabDomainDefinition -Name $domainName -AdminUser $UserName -AdminPassword $Password
Set-LabInstallationCredential -Username $UserName -Password $Password

Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $cidr
Add-LabVirtualNetworkDefinition -Name 'External' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }

#region defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
  'Add-LabMachineDefinition:DnsServer1' = '10.10.5.10'
  'Add-LabMachineDefinition:Gateway'    = '10.10.5.10'
  'Add-LabMachineDefinition:DomainName' = "$domainName"
  'Add-LabMachineDefinition:Memory'     = '6GB'
  'Add-LabMachineDefinition:Network'    = "$labName"
}

$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "$labName" -Ipv4Address '10.10.5.10'
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'External' -UseDhcp
#endregion

# define our domain controller
$dcParam = @{
  name            = 'L5DC2201'
  networkadapter  = $netAdapter
  roles           = @('RootDC', 'Routing')
  operatingsystem = 'Windows Server 2022 Standard Evaluation (Desktop Experience)'
}
Add-LabMachineDefinition @dcParam

# Define our Win10 Client
$pcParam = @{
  name            = 'L5PC1001'
  memory          = '8GB'
  network         = "$labName"
  operatingsystem = 'Windows 10 Enterprise Evaluation'
}
Add-LabMachineDefinition @pcParam

# Define our Win11 Client
$pcParam = @{
  name            = 'L5PC1101'
  memory          = '8GB'
  network         = "$labName"
  operatingsystem = 'Windows 11 Enterprise Evaluation'
}
Add-LabMachineDefinition @pcParam

# Define web servers for testing
$pcParam = @{
  name            = 'L5WS1201'
  network         = "$labName"
  operatingsystem = 'Windows Server 2012 R2 Standard Evaluation (Server with a GUI)'
  roles           = 'WebServer'
}
Add-LabMachineDefinition @pcParam

$pcParam = @{
  name            = 'L5WS1601'
  network         = "$labName"
  operatingsystem = 'Windows Server 2016 Standard Evaluation (Desktop Experience)'
  roles           = 'WebServer'
}
Add-LabMachineDefinition @pcParam

$pcParam = @{
  name            = 'L5WS1901'
  network         = "$labName"
  operatingsystem = 'Windows Server 2019 Standard Evaluation (Desktop Experience)'
  roles           = 'WebServer'
}
Add-LabMachineDefinition @pcParam

$pcParam = @{
  name            = 'L5WS2201'
  network         = "$labName"
  operatingsystem = 'Windows Server 2022 Standard Evaluation (Desktop Experience)'
  roles           = 'WebServer'
}
Add-LabMachineDefinition @pcParam

Install-Lab

$Clients = Get-LabVM *PC*
foreach ($Client in $Clients) {
  Copy-LabFileItem -ComputerName $Client.Name -Path "$LocalFolderPath\SoftwarePackages" -DestinationFolderPath "$RemoteFolderPath"
  Invoke-LabCommand -ComputerName $Client.Name -ActivityName 'Update Base AppxPackages' -ArgumentList "$RemoteFolderPath" -ScriptBlock {
    param($LabSources)
    powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.UI.Xaml.2.8.x64.appx"
    powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.VCLibs.x64.14.00.Desktop.appx"
    powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.WindowsTerminal_1.21.2361.0_8wekyb3d8bbwe.msixbundle"
  } -PassThru

  Invoke-LabCommand -ComputerName $Client.Name -ActivityName 'NuGet/PSGet' -ScriptBlock {
    #Bootstrap Nuget provider update  to avoid interactive prompts
    [void](Install-PackageProvider -Name Nuget -ForceBootstrap -Force)

    # Remove the built-in PSReadline & Pester modules so it will be easier to update both the version and the help later
    Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadline' -Recurse -Force -Confirm:$false
    Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Pester' -Recurse -Force -Confirm:$false

    # Get the latest versions from the PowerShell Gallery
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PowerShellGet
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Microsoft.PowerShell.PSResourceGet
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Pester
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PSReadLine
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PSReadlineHistory
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PSReadlineHelper -AllowClobber
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Microsoft.PowerShell.SecretManagement
    Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Microsoft.PowerShell.SecretStore

    # Install latest version of PowerShell Core
    Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"

    Update-Help -Force -ErrorAction SilentlyContinue
  }
}

#region Winget
## Need to review why it fails on first run if you do not remote to box and accept terms
foreach ($Client in $Clients) {
  Invoke-LabCommand -ComputerName $Client.Name -ActivityName 'Winget' -ScriptBlock {
    # Example: winget search vscode
    winget install --source winget --accept-source-agreements --accept-package-agreements --name 'Microsoft Visual Studio Code Insiders'

    #winget install --source msstore --accept-source-agreements --accept-package-agreements --name "AutoHotkey Store Edition"
    #winget install --source msstore --accept-source-agreements --accept-package-agreements --name "Power Automate"
  } -PassThru
}
#endregion Winget

#region Chocolately
foreach ($Client in $Clients) {
  Invoke-LabCommand -ComputerName $Client.Name -ActivityName 'Chocolately' -ScriptBlock {
    # First download and install the choco app
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Next grab some choco packages
    $packages = @(
      'git'
      'vscode'
    )

    for ($i = 0; $i -lt $packages.count; $i++) {
      Write-Progress -Activity 'Installing Choco Packages' -Status "$i% Complete:" -PercentComplete $i
      choco install $packages[$i] -y
      Start-Sleep -Milliseconds $(Get-Random -Minimum 50 -Maximum 150)
    }
  } -PassThru
}
#endregion Chocolatey

#region Custom Package Installs
Install-LabSoftwarePackage -Path "$labSources\CustomPackages\7z2409-x64.exe" -ComputerName 'L5PC1001' -CommandLine /S
Install-LabSoftwarePackage -Path "$labSources\CustomPackages\ChromeSetup.exe" -ComputerName (Get-LabVM) -CommandLine /S
#endregion

#region VSCode
foreach ($Client in $Clients) {
  Invoke-LabCommand -ComputerName $Client.Name -ActivityName 'VSCode' -ScriptBlock {
    $extensions = @(
      'esbenp.prettier-vscode'                           #Prettier – Code formatter
      'DavidAnson.vscode-markdownlint'                   #Markdown syntax checker
      'ms-vscode-remote.remote-wsl'                      #WSL Remote inside Windows VSCode
      'ms-vscode.PowerShell'                             #PowerShell Syntax Highlighting
      'vscode-icons-team.vscode-icons'                   #Folder icons
    )

    foreach ($extension in $extensions) {
      Write-Host "`nInstalling extension [$extension]" -ForegroundColor Yellow
      & pwsh -noprofile -Command "code --install-extension $extension"
    }

    $settingsPath = 'C:\Users\LabAdmin\AppData\Roaming\Code\User\settings.json'
    $data = Invoke-RestMethod 'https://raw.githubusercontent.com/clemmesserli/MessLab/main/data/vscode/settings.json'
    $data | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8
  } -PassThru
}
#endregion VSCode

#region GIT
Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'GIT Config' -ScriptBlock {
  git config --global user.email 'clemmesserli@messlabs.com'
  git config --global user.name 'Clem Messerli'
  git config --global user.username 'cmesserli'
  git config --global url.'https://github.com/'.insteadOf 'gh:'
  git config --global url.'https://gist.github.com/'.insteadOf 'gist:'
  git config --global url.'https://bitbucket.org/'.insteadOf 'bb:'

  New-Item -Path C:\MyGitHub -ItemType Directory -Force
  Set-Location 'C:\MyGitHub'
  git clone gh:clemmesserli/MessKit.git
} -PassThru
#endregion GIT

#region PSProfile
foreach ($Client in $Clients) {
  Invoke-LabCommand -ComputerName $Client.Name -ActivityName 'GIT' -ScriptBlock {
    #download pre-built sample from github
    $data = Invoke-RestMethod 'https://raw.githubusercontent.com/clemmesserli/MessLab/main/data/powershell/profile.ps1'
    $data | Out-File 'C:\MyGitHub\profile.ps1' -Encoding utf8

    #loop through common PSProfile paths and create a stub or shortcut linking back to our local file above
    $files = @(
      "$($env:onedrive)\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
      "$($env:onedrive)\Documents\PowerShell\Microsoft.PowerShellISE_profile.ps1"
      "$($env:onedrive)\Documents\PowerShell\profile.ps1"
      "$($env:onedrive)\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
      "$($env:onedrive)\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1"
      "$($env:onedrive)\Documents\WindowsPowerShell\profile.ps1"

      "$($env:OneDriveConsumer)\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
      "$($env:OneDriveConsumer)\Documents\PowerShell\Microsoft.PowerShellISE_profile.ps1"
      "$($env:OneDriveConsumer)\Documents\PowerShell\profile.ps1"
      "$($env:OneDriveConsumer)\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
      "$($env:OneDriveConsumer)\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1"
      "$($env:OneDriveConsumer)\Documents\WindowsPowerShell\profile.ps1"
    )
    foreach ($file in $files) {
      Set-Content -Value '. C:\MyGitHub\profile.ps1' -Path "$file" -Force -ErrorAction SilentlyContinue
    }
  }
}
#endregion PSProfile

#region SecretsMgmt
Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'SecretsMgmt' -Credential $Credential -ScriptBlock {
		#Ref: https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules
		## exported to an XML file and encrypted by Windows Data Protection (DPAPI)
		## (Protect-CmsMessage leveraging a certificate is what I prefer as it is more portable)
		$securePasswordPath = 'C:\LabSources\PSVault.xml'
		$using:Password |  Export-Clixml -Path $securePasswordPath

		Register-SecretVault -Name 'PSVault' -ModuleName 'Microsoft.PowerShell.SecretStore' -DefaultVault
		$password = Import-Clixml -Path $securePasswordPath

		$storeConfiguration = @{
    Authentication  = 'Password'
    PasswordTimeout = 3600 			# 1 hour
    Interaction     = 'None'
    Password        = $password
    Confirm         = $false
		}
		Set-SecretStoreConfiguration @storeConfiguration

		# Import the masterkey and unlock vault
		$password = Import-Clixml -Path $securePasswordPath
		Unlock-SecretStore -Password $password

		# Create a secret
		Import-Module C:\MyGitHub\MessKit\MessKit.psd1
		Set-Secret -Name 'MySecret' -Secret "$(New-MKPassword)" -Vault 'PSVault'

		# Get the secret value
		$MySecret = Get-Secret -Name 'MySecret' -AsPlainText
		Write-Output "Your Secret Is: [$MySecret]"
}
#endregion SecretsMgmt

# Restart-LabVM -ComputerName Get-LabVM -Wait
# Checkpoint-LabVM -All -SnapshotName 1
Show-LabDeploymentSummary -Detailed