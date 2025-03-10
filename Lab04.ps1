<#
.EXAMPLE
.\Lab04.ps1 -Credential $MyLabCred
Creates a lab definition using all pre-defined param defaults

#>
[cmdletBinding()]
param(
  [pscredential]$credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
  [string]$cidr = '10.10.4.0/24',
  [string]$domainName = 'messlabs.com',
  [string]$labName = 'Lab04',
  [string]$vmPath = 'L:\LabVMs',
  [string]$LocalFolderPath = "$(Get-LabSourcesLocation)",
  [string]$RemoteFolderPath = 'C:\LabSources'
)

if ( (Get-Service ShellHWDetection).Status -ne 'Running') {
  Start-Service ShellHWDetection
}
New-LabDefinition -VmPath $vmPath -Name $labName -DefaultVirtualizationEngine HyperV

# define our default credentials
Add-LabDomainDefinition -Name $domainName -AdminUser $credential.GetNetworkCredential().UserName -AdminPassword $credential.GetNetworkCredential().Password
Set-LabInstallationCredential -Username $credential.GetNetworkCredential().UserName -Password $credential.GetNetworkCredential().Password

Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $cidr
Add-LabVirtualNetworkDefinition -Name 'External' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }

#region defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
  'Add-LabMachineDefinition:DnsServer1' = '10.10.4.10'
  'Add-LabMachineDefinition:Gateway'    = '10.10.4.10'
  'Add-LabMachineDefinition:DomainName' = "$domainName"
  'Add-LabMachineDefinition:Memory'     = '6GB'
  'Add-LabMachineDefinition:Network'    = "$labName"
}

$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "$labName" -Ipv4Address '10.10.4.10'
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'External' -UseDhcp
#endregion

#region define our domain controller
$ht = @{
  name            = 'L4DC2201'
  networkadapter  = $netAdapter
  roles           = @('RootDC', 'Routing')
  operatingsystem = 'Windows Server 2022 Standard Evaluation (Desktop Experience)'
}
Add-LabMachineDefinition @ht
#endregion

#region define our client pcs
$ht = @{
  name            = 'L4PC1001'
  network         = "$labName"
  operatingsystem = 'Windows 10 Enterprise Evaluation'
}
Add-LabMachineDefinition @ht

$ht = @{
  name            = 'L4PC1101'
  network         = "$labName"
  operatingsystem = 'Windows 11 Enterprise Evaluation'
}
Add-LabMachineDefinition @ht
#endregion

#region define our web servers
$ht = @{
  name            = 'L4WS1901'
  network         = "$labName"
  operatingsystem = 'Windows Server 2019 Standard Evaluation (Desktop Experience)'
  roles           = @('WebServer')
}
Add-LabMachineDefinition @ht
#endregion

Install-Lab

Checkpoint-LabVM -All -SnapshotName 1

#region Install Windows Features
Copy-LabFileItem -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Path "$LocalFolderPath\SoftwarePackages" -DestinationFolderPath "$RemoteFolderPath"
Copy-LabFileItem -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Path "$LocalFolderPath\SampleData" -DestinationFolderPath "$RemoteFolderPath"


Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'Install Default Features' -ScriptBlock {
  dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
  dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
}
#endregion WindowsFeatures

#region Enable Nested Virtualization + WSL on Client Hyper-V machines
Stop-LabVM -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Wait
Set-VMProcessor (Get-LabVM | Where-Object Name -Match 'PC').Name -ExposeVirtualizationExtensions $true
Start-LabVM -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Wait

Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'Install Default Features' -ArgumentList "$RemoteFolderPath" -ScriptBlock {
  param($LabSources)
  powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.UI.Xaml.2.8.x64.appx"
  powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.VCLibs.x64.14.00.Desktop.appx"
  powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"

  $os = (Get-ComputerInfo).OsName
  if ($os -match 'Windows 10') {
    powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.WindowsTerminal_1.21.2361.0_8wekyb3d8bbwe.msixbundle"

    powershell -noprofile wsl --set-default-version 1
  }
  if ($os -match 'Windows 11') {
    powershell -noprofile wsl --update
    powershell -noprofile wsl --set-default-version 2
  }
  powershell -noprofile wsl --install -d Ubuntu
} -PassThru

Invoke-LabCommand -ComputerName (Get-LabVM) -ActivityName 'Install PowerShell Core' -ArgumentList "$RemoteFolderPath" -ScriptBlock {
  # Install latest version of PowerShell Core
  Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
}
#endregion
Restart-LabVM -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Wait
Checkpoint-LabVM -All -SnapshotName 2

#region Winget
Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'WinGet' -ScriptBlock {
  # Example: winget search vscode
  winget source update
  winget source reset --force

  winget install --silent --source winget --accept-source-agreements --accept-package-agreements --name 'Microsoft Visual Studio Code Insiders'
  winget install --silent --source winget --accept-source-agreements --accept-package-agreements --name 'Postman'
  winget install --silent --source winget --accept-source-agreements --accept-package-agreements --name 'Microsoft .NET SDK 8.0'
  winget install --source msstore --accept-source-agreements --accept-package-agreements --name 'Power Automate'
  #winget install --source msstore --accept-source-agreements --accept-package-agreements --name "AutoHotkey Store Edition"
} -PassThru
#endregion Winget
Restart-LabVM -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Wait
Checkpoint-LabVM -All -SnapshotName 3

#region Install a pre-downloaded application
Copy-LabFileItem -ComputerName (Get-LabVM | Where-Object { $_.Name -Match 'PC' -or $_.Name -Match 'WS' }) -Path "$labSources\CustomPackages\BraveBrowserSetup.exe" -DestinationFolderPath "$RemoteFolderPath\CustomPackages"
Copy-LabFileItem -ComputerName (Get-LabVM | Where-Object { $_.Name -Match 'PC' -or $_.Name -Match 'WS' }) -Path "$labSources\CustomPackages\ChromeSetup.exe" -DestinationFolderPath "$RemoteFolderPath\CustomPackages"

Install-LabSoftwarePackage -ComputerName (Get-LabVM | Where-Object { $_.Name -Match 'PC' -or $_.Name -Match 'WS' }) -LocalPath "$RemoteFolderPath\CustomPackages\BraveBrowserSetup.exe" -CommandLine '/Silent /Install' -PassThru
Install-LabSoftwarePackage -ComputerName (Get-LabVM | Where-Object { $_.Name -Match 'PC' -or $_.Name -Match 'WS' }) -LocalPath "$RemoteFolderPath\CustomPackages\ChromeSetup.exe" -CommandLine '/Silent /Install' -PassThru
#endregion
Restart-LabVM -ComputerName (Get-LabVM | Where-Object { $_.Name -Match 'PC' -or $_.Name -Match 'WS' }) -Wait
Checkpoint-LabVM -All -SnapshotName 4

#region Chocolately
Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'Chocolatey' -ScriptBlock {
  # First download and install the choco app
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

  # Next grab some choco packages
  $packages = @(
    'git'
    'exiftool'
    'keepass'
    'notepadplusplus'
    'openssl'
    'vscode'
    '7zip'
  )

  for ($i = 0; $i -lt $packages.count; $i++) {
    Write-Progress -Activity 'Installing Choco Packages' -Status "$i% Complete:" -PercentComplete $i
    choco install $packages[$i] -y
    Start-Sleep -Milliseconds $(Get-Random -Minimum 50 -Maximum 150)
  }
} -PassThru
#endregion Chocolatey
Restart-LabVM -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Wait
Checkpoint-LabVM -All -SnapshotName 5

#region Install Default PowerShell Modules
Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'NuGet/PSGet' -ScriptBlock {
  ## Bootstrap Nuget provider update  to avoid interactive prompts
  [void](Install-PackageProvider -Name Nuget -ForceBootstrap -Force)

  ## Remove the built-in PSReadline & Pester modules so it will be easier to update both the version and the help later
  Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadline' -Recurse -Force -Confirm:$false
  Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Pester' -Recurse -Force -Confirm:$false

  # Get the latest versions from the PowerShell Gallery
  $modules = @(
    '7Zip4Powershell' #Creating and extracting 7-Zip archives
    'ImportExcel' #Save and Edit Excel data with PowerShell
    'Microsoft.Graph' #API Platform for Office 365
    'MicrosoftTeams' #API for MS Teams
    'Microsoft.PowerShell.PSResourceGet' #Manage PowerShell modules and scripts from registered repositories
    'Microsoft.PowerShell.SecretManagement' #Common interface for managing secrets across different vaults
    'Microsoft.PowerShell.SecretStore' #Vault specifically designed for local storage of secrets
    'MSOnline' #Manage Azure AD and Office 365 user accounts
    'Pester' #Testing framework for PowerShell
    'PoShKeePass' #KeePass api access
    'PowerShellGet' #Package manager for PowerShell
    'PSCredentialManager' #Manage credentials securely
    'PSReadLine' #Enhances command line editing and history
    'PSReadlineHelper' #Additional helper functions and customizations for the PSReadLine
    'PSReadlineHistory' #Manages command history across PowerShell sessions
    'PSScriptAnalyzer' #Static code checker for PowerShell scripts and modules
    'SecretManagement.Hashicorp.Vault.KV' #Integrate HashiCorp Vault with SecretManager
    'SecretManagement.JustinGrote.CredMan' #Integrate Windows CredManager with SecretManager
    'SecretManagement.KeePass' #cross-platform Keepass Secret Management vault extension
    'powershellYK' #unofficial powershell wrapper for Yubico .NET SDK
  )
  foreach ($module in $modules) {
    $psVersion = (Find-Module -Name $module).AdditionalMetaData.PowerShellVersion
    if ($psVersion -lt 7) {
      Write-Host "Installing $module into PSDesktop on $env:COMPUTERNAME"
      & powershell -noprofile -Command "Install-Module -Repository PSGallery -Scope AllUsers -AllowClobber -Force -Name $module"
    } else {
      Write-Host "Installing $module into PSCore on $env:COMPUTERNAME"
      & pwsh -noprofile -Command "Install-Module -Repository PSGallery -Scope AllUsers -AllowClobber -AllowPrerelease -Force -Name $module"
    }
  }
  Update-Help -Force -ErrorAction SilentlyContinue
} -PassThru
#endregion PowerShell Modules
Restart-LabVM -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Wait
Checkpoint-LabVM -All -SnapshotName 6

#region VSCode
Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'VSCode Extensions' -ScriptBlock {
  $extensions = @(
    'davidanson.vscode-markdownlint'                   #Markdown syntax checker
    'esbenp.prettier-vscode'                           #Prettier – Code formatter
    'hilleer.yaml-plus-json'                           #YAML to JSON conversion tool
    'ms-dotnettools.dotnet-interactive-vscode'         #Polygot Notebooks
    'ms-toolsai.jupyter'                               #Jupyter notebooks
    'ms-vscode-remote.remote-wsl'                      #WSL Remote inside Windows VSCode
    'ms-vscode.PowerShell'                             #PowerShell Syntax Highlighting
    'redhat.ansible'                                   #Ansible by Red Hat
    'redhat.vscode-yaml'                               #YAML by Red Hat
    'vscode-icons-team.vscode-icons'                   #Folder icons
    'ironmansoftware.powershell-universal'             #PowerShell Universal
    'louiswt.regexp-preview'                           #RegEx Explain
    'slevesque.vscode-zipexplorer'                     #ZipFile Explorer
  )

  foreach ($extension in $extensions) {
    Write-Host "`nInstalling extension [$extension]" -ForegroundColor Yellow
    & pwsh -noprofile -Command "code --install-extension $extension"
  }

  $settingsPath = "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json"
  $data = Invoke-RestMethod 'https://raw.githubusercontent.com/clemmesserli/MessLab/main/data/vscode/settings.json'
  $data | Out-File $settingsPath -Encoding utf8
} -PassThru
#endregion VSCode
Restart-LabVM -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Wait
Checkpoint-LabVM -All -SnapshotName 7

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
Restart-LabVM -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -Wait
Checkpoint-LabVM -All -SnapshotName 8

# completed Cert updates
Checkpoint-LabVM -All -SnapshotName 9


<#
#region PSProfile
Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'PSProfile' -ScriptBlock {
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
#endregion PSProfile
Checkpoint-LabVM -All -SnapshotName 9

#region SecretsMgmt
Invoke-LabCommand -ComputerName (Get-LabVM | Where-Object Name -Match 'PC') -ActivityName 'PSProfile' -ScriptBlock {
	#Ref: https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/how-to/using-secrets-in-automation?view=ps-modules
	## exported to an XML file and encrypted by Windows Data Protection (DPAPI)
	## (Protect-CmsMessage leveraging a certificate is what I prefer as it is more portable)
	$securePasswordPath = "C:\LabSources\PSVault.xml"
	$using:credential.Password | Export-Clixml -Path $securePasswordPath

	Register-SecretVault -Name 'PSVault' -ModuleName 'Microsoft.PowerShell.SecretStore' -DefaultVault
	$password = Import-Clixml -Path $securePasswordPath

	$storeConfiguration = @{
		Authentication  = 'Password'
		PasswordTimeout = 1800 # 30 min
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
	Write-Output "Your Secret Is: [$myAuthToken]"
} -PassThru
#endregion SecretsMgmt
Checkpoint-LabVM -All -SnapshotName 10
#>


<#
Remove-Lab -Name Lab04
#>