[cmdletBinding()]
param(
	[pscredential]$credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
	[string]$labName = "Lab03",
	[string]$osEdition = "Windows Server 2012 R2 Standard Evaluation (Server with a GUI)",
	[string]$osMemory = "6GB",
	[string]$osName = "ALServer12",
	[string]$vmPath = "L:\LabVMs"
)

$labSources = Get-LabSourcesLocation

New-LabDefinition -VmPath $vmPath -Name $labName -DefaultVirtualizationEngine HyperV

# define our default user credential
Set-LabInstallationCredential -Username $credential.GetNetworkCredential().UserName -Password $credential.GetNetworkCredential().Password

#$adapterName = (Get-NetAdapter | Where-Object status -EQ 'UP').Name
Add-LabVirtualNetworkDefinition -Name "External" -HyperVProperties @{ SwitchType = "External"; AdapterName = "Ethernet" }

Add-LabMachineDefinition -Name $osName -Memory $osMemory -OperatingSystem $osEdition -Network "External" -ToolsPath $labSources\Tools

Install-Lab

Install-LabSoftwarePackage -Path "$labSources\SoftwarePackages\Notepad-8.6.4-x64.exe" -ComputerName $osName -CommandLine /S

Restart-LabVM -ComputerName $osName -Wait

Checkpoint-LabVM -All -SnapshotName 1

Show-LabDeploymentSummary -Detailed
