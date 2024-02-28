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
.\Lab01.ps1
Creates a lab definition using all pre-defined param defaults

.EXAMPLE
.\Lab01.ps1 -AllowInternet
Creates a lab definition using all pre-defined param and also allow direct outbound internet access.

.EXAMPLE
.\Lab01.ps1 -Credential $myCred -LabName "MyLab" -OperatingSystem "Windows 11 Enterprise Evaluation" -Memory 2 -ComputerName "Client1"
Creates a custom lab definition named "MyLab" with Client1 running Windows 11 Eval and using 2GB of memory.
#>
[cmdletBinding()]
param(
	[pscredential]$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
	[string]$LabName = "Lab01",
	[ValidateSet(
		"Windows 10 Enterprise Evaluation",
		"Windows 11 Enterprise Evaluation",
		"Windows Server 2012 R2 Standard Evaluation (Server Core Installation)",
		"Windows Server 2012 R2 Standard Evaluation (Server with a GUI)",
		"Windows Server 2016 Standard Evaluation",
		"Windows Server 2016 Standard Evaluation (Desktop Experience)",
		"Windows Server 2019 Standard Evaluation",
		"Windows Server 2019 Standard Evaluation (Desktop Experience)",
		"Windows Server 2022 Standard Evaluation",
		"Windows Server 2022 Standard Evaluation (Desktop Experience)"
	)]
	[string]$OperatingSystem = "Windows 10 Enterprise Evaluation",
	[int]
	[ValidateRange(1, 6)]
	[Parameter(HelpMessage = "Enter memory size between 1-6 (in GB):")]
	$Memory = 6,
	[string]$ComputerName = "L1PC10",
	[string]$VmPath = "L:\LabVMs",
	[switch]$AllowInternet
)

Begin {
	$Stopwatch = [System.Diagnostics.Stopwatch]::new()
	$Stopwatch.Start()
}

Process {
	if (-not($PSBoundParameters.ContainsKey('Credential'))) {
		# Attempt to fetch default cred from Microsoft.PowerShell.SecretStore or prompt for user input if it needs unlocked
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

	# Copy shared files to all VMs
	$LabFiles = @(
		"7z-24.01-x64.exe"
		"BraveBrowserSetup.exe"
		"Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
		"Microsoft.UI.Xaml.2.8.appx"
		"Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx"
		"Microsoft.WindowsTerminal_Win10_1.16.10261.0_8wekyb3d8bbwe.msixbundle"
		"Microsoft.WindowsTerminal_Win11_1.16.10262.0_8wekyb3d8bbwe.msixbundle"
		#"nmap-7.94-setup.exe"
		#"Notepad-8.6.4-x64.exe"
		#"npcap-1.79.exe"
		#"VisualStudioSetup.exe"
		#"WinRAR-6.24-x64.exe"
		#"Wireshark-4.2.3-x64.exe"
		"vscode.ps1"
		"powershell.ps1"
	)
	$LabFiles | ForEach-Object {
		Copy-LabFileItem -ComputerName $ComputerName -Path "$labSources\SoftwarePackages\$($_)" -DestinationFolderPath "C:\LabSources"
	}

	# Install pre-downloaded apps
	Install-LabSoftwarePackage -ComputerName $ComputerName -LocalPath "C:\LabSources\BraveBrowserSetup.exe" -CommandLine "/Silent /Install" -PassThru
}

End {
	Write-Host "Full Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
	$Stopwatch.Stop()
}