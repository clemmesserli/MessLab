[cmdletBinding()]
param(
	[pscredential]$credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
	[string]$cidr = "10.10.4.0/24",
	[string]$domainName = "messlabs.com",
	[string]$labName = "Lab04",
	[string]$vmPath = "L:\LabVMs"
)

$labSources = Get-LabSourcesLocation

New-LabDefinition -VmPath $vmPath -Name $labName -DefaultVirtualizationEngine HyperV

# define our default credentials
Add-LabDomainDefinition -Name $domainName -AdminUser $credential.GetNetworkCredential().UserName -AdminPassword $credential.GetNetworkCredential().Password
Set-LabInstallationCredential -Username $credential.GetNetworkCredential().UserName -Password $credential.GetNetworkCredential().Password

Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $cidr
Add-LabVirtualNetworkDefinition -Name "External" -HyperVProperties @{ SwitchType = "External"; AdapterName = "Ethernet" }

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
	"Add-LabMachineDefinition:DnsServer1" = "10.10.4.10"
	"Add-LabMachineDefinition:Gateway"    = "10.10.4.10"
	"Add-LabMachineDefinition:DomainName" = "$domainName"
	"Add-LabMachineDefinition:Memory"     = "4GB"
	"Add-LabMachineDefinition:Network"    = "$labName"
}

$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "$labName" -Ipv4Address "10.10.4.10"
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "External" -UseDhcp

# define our domain controller
$dcParam = @{
	name            = "L4DC1"
	networkadapter  = $netAdapter
	roles           = @("RootDC", "Routing")
	operatingsystem = "Windows Server 2016 Standard Evaluation (Desktop Experience)"
}
Add-LabMachineDefinition @dcParam

# define our client pc
$pcParam = @{
	name            = "L4CLIENT1"
	network         = "$labName"
	operatingsystem = "Windows 10 Enterprise Evaluation"
}
Add-LabMachineDefinition @pcParam

Install-Lab

Install-LabSoftwarePackage -Path "$labSources\SoftwarePackages\Notepad-8.6.4-x64.exe" -ComputerName "L4CLIENT1" -CommandLine /S
Install-LabSoftwarePackage -Path "$labSources\SoftwarePackages\7z-24.01-x64.exe" -ComputerName Get-LabVM -CommandLine /S

Restart-LabVM -ComputerName Get-LabVM -Wait

Checkpoint-LabVM -All -SnapshotName 1

Show-LabDeploymentSummary -Detailed
