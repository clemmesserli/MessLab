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
.\Lab02.ps1
Creates a lab definition using all pre-defined param defaults

.EXAMPLE
.\Lab02.ps1 -AllowInternet
Creates a lab definition using all pre-defined param and also allow direct outbound internet access.

.EXAMPLE
.\Lab02.ps1 -Credential $myCred -LabName "MyLab" -OperatingSystem "Windows 11 Enterprise Evaluation" -Memory 2 -ComputerName "Client1"
Creates a custom lab definition named "MyLab" with Client1 running Windows 11 Eval and using 2GB of memory.
#>
[cmdletBinding()]
param(
	[pscredential]$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin),

	[string]$LabName = "Lab02",

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
	[ValidateRange(2)]
	[string[]]$OperatingSystem = @("Windows 10 Enterprise Evaluation", "Windows Server 2016 Standard Evaluation (Desktop Experience)"),

	[ValidateRange(1, 6)]
	[Parameter(HelpMessage = "Enter memory size between 1-6 (in GB):")]
	[int]$Memory = 6,

	[ValidateRange(2)]
	[string[]]$ComputerName = @("L2PC10", "L2SRV16"),

	[string]$vmPath = "L:\LabVMs",

	[switch]$AllowInternet
)

Begin {
	$Stopwatch = [System.Diagnostics.Stopwatch]::new()
	$Stopwatch.Start()
}

Process {
	if (-not($PSBoundParameters.ContainsKey('Credential'))) {
		# Attempt to fetch default cred from Microsoft.PowerShell.SecretStore or prompt for user input if it needs unlocked
		$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin -ErrorAction Stop)
	} else {
		Write-Error "Unable to pre-set credentials.  Aborting lab creation!"
	}
	New-LabDefinition -VmPath $VmPath -Name $LabName -DefaultVirtualizationEngine HyperV

	# define our default user credential
	Set-LabInstallationCredential -Username $credential.UserName -Password $credential.GetNetworkCredential().Password

	if ($AllowInternet) {
		if ( ((Get-NetAdapter -Name 'Wi-Fi').status) -eq 'UP') { $nic = "Wi-Fi" } else { $nic = "Ethernet" }
		Add-LabVirtualNetworkDefinition -Name "External" -HyperVProperties @{ SwitchType = "External"; AdapterName = "$nic" }

		Add-LabMachineDefinition -Name $ComputerName[0] -Memory "$($Memory)GB" -OperatingSystem $OperatingSystem[0] -Network "External"
		Add-LabMachineDefinition -Name $ComputerName[1] -Memory "$($Memory)GB" -OperatingSystem $OperatingSystem[1] -Network "External"
	} else {
		Add-LabMachineDefinition -Name $ComputerName[0] -Memory "$($Memory)GB" -OperatingSystem $OperatingSystem[0]
		Add-LabMachineDefinition -Name $ComputerName[1] -Memory "$($Memory)GB" -OperatingSystem $OperatingSystem[1]
	}

	Install-Lab
}

End {
	Write-Host "Full Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
	$Stopwatch.Stop()
}