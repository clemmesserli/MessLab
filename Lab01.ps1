<#
.SYNOPSIS
Creates and installs a lab environment using AutomatedLab.

.DESCRIPTION
This script sets up a lab definition, adds (1) single machine definition, and installs the lab using AutomatedLab for internal only traffic.

.PARAMETER Credential
Specifies the credentials for lab installation.

.PARAMETER LabName
Specifies the name of the lab definition.

.PARAMETER OperatingSystem
Specifies the operating system edition for the lab machine.

.PARAMETER Memory
Specifies the memory in GB for the lab machine.

.PARAMETER ComputerName
Specifies the name of the lab machine.

.PARAMETER VmPath
Specifies the path where VM will be stored.

.PARAMETER AllowInternet
Specifies whether to create a virtual switch nat to allow hyper-v machine to reach the internet

.EXAMPLE
.\Lab01.ps1 -Credential $MyLabCred -AllowInternet
Creates a lab definition using pre-defined param defaults + internet access

.EXAMPLE
.\Lab01.ps1 -OperatingSystem "Windows 11 Enterprise Evaluation" -ComputerName "L1PC1101" -AllowInternet
Creates a Win11 client in default lab and also allow direct outbound internet access.

.EXAMPLE
.\Lab01.ps1 -Credential $MyLabCred -LabName "MyLab" -OperatingSystem "Windows 11 Enterprise Evaluation" -Memory 2 -ComputerName "Client1"
Creates a custom lab definition named "MyLab" with Client1 running Windows 11 Eval and using 2GB of memory.
#>
[cmdletBinding()]
param(
	[pscredential]$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
	[string]$LabName = "Lab01",
	[ValidateSet(
		"Windows 10 Enterprise Evaluation",
		"Windows 11 Enterprise Evaluation",
		"Windows Server 2012 R2 Standard Evaluation (Server with a GUI)",
		"Windows Server 2016 Standard Evaluation (Desktop Experience)",
		"Windows Server 2019 Standard Evaluation (Desktop Experience)",
		"Windows Server 2022 Standard Evaluation (Desktop Experience)"
	)]
	[string]$OperatingSystem = "Windows 10 Enterprise Evaluation",

	[ValidateRange(1, 8)]
	[Parameter(HelpMessage = "Enter memory size between 1-8 (in GB):")]
	[int]$Memory = 6,
	[string]$ComputerName = "L1PC1001",

	[string]$VmPath = "C:\LabVMs",

	[string]$LocalFolderPath = "$(Get-LabSourcesLocation)",

	[string]$RemoteFolderPath = "C:\LabSources",

	[switch]$AllowInternet
)

Begin {
	$Stopwatch = [System.Diagnostics.Stopwatch]::new()
	$Stopwatch.Start()
}

Process {
	if (-not($PSBoundParameters.ContainsKey('Credential'))) {
		# Attempt to fetch default cred from Microsoft.PowerShell.SecretStore if a custom credential was not provided
		try {
			$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin -ErrorAction Stop)
		} catch {
			Write-Error "Unable to pre-set credentials.  Aborting lab creation!"
			break
		}
	}
	New-LabDefinition -VmPath $VmPath -Name $LabName -DefaultVirtualizationEngine HyperV

	# define our default user credential
	Set-LabInstallationCredential -Username $credential.UserName -Password $credential.GetNetworkCredential().Password

	if ($AllowInternet) {
		if ( ((Get-NetAdapter -Name 'Wi-Fi').status) -eq 'UP') { $nic = "Wi-Fi" } else { $nic = "Ethernet" }
		Add-LabVirtualNetworkDefinition -Name "External" -HyperVProperties @{ SwitchType = "External"; AdapterName = "$nic" }

		Add-LabMachineDefinition -Name $ComputerName -Memory "$($Memory)GB" -OperatingSystem $OperatingSystem -Network "External"
	} else {
		Add-LabMachineDefinition -Name $ComputerName -Memory "$($Memory)GB" -OperatingSystem $OperatingSystem
	}

	Install-Lab

	Copy-LabFileItem -ComputerName $ComputerName -Path "$LocalFolderPath\SoftwarePackages" -DestinationFolderPath "$RemoteFolderPath"
	Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'Update Base AppxPackages' -ArgumentList "$RemoteFolderPath" -ScriptBlock {
		param($LabSources)
		powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.UI.Xaml.2.8.x64.appx"
		powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.VCLibs.x64.14.00.Desktop.appx"
		powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
		powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.WindowsTerminal_1.21.2361.0_8wekyb3d8bbwe.msixbundle"
	} -PassThru

	Invoke-LabCommand -ComputerName $ComputerName -ActivityName 'NuGet/PSGet' -ScriptBlock {
		# set TLS just in case
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

		#Bootstrap Nuget provider update to avoid interactive prompts
		[void](Install-PackageProvider -Name Nuget -ForceBootstrap -Force)

		# Remove the built-in PSReadline & Pester modules so it will be easier to update both the version and the help later
		Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadline' -Recurse -Force -Confirm:$false
		Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Pester' -Recurse -Force -Confirm:$false

		# Get the latest versions from the PowerShell Gallery
		Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PowerShellGet
		Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Microsoft.PowerShell.PSResourceGet
		Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Pester
		Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PSReadLine

		# Install latest version of PowerShell Core
		Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"

		Update-Help -Force -ErrorAction SilentlyContinue
	} -PassThru
}

End {
	Write-Host "Base Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
	$Stopwatch.Stop()
}
