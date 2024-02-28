#This intro script is pretty almost the same like the previous one. But this lab is connected to the internet over the external virtual switch.
#The IP addresses are assigned automatically like in the previous samples but AL also assignes the gateway and the DNS servers to all machines
#that are part of the lab. AL does that if it finds a machine with the role 'Routing' in the lab.

[cmdletBinding()]
param(
	[pscredential]$credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
	[string]$cidr = "10.10.5.0/24",
	[string]$domainName = "messlabs.com",
	[string]$labName = "Lab05",
	[string]$vmPath = "L:\LabVMs"
)

New-LabDefinition -VmPath $vmPath -Name $labName -DefaultVirtualizationEngine HyperV

# define our default credentials
Set-LabInstallationCredential -Username $credential.GetNetworkCredential().UserName -Password $credential.GetNetworkCredential().Password

#and the domain definition with the domain admin account
Add-LabDomainDefinition -Name $domainName -AdminUser $credential.GetNetworkCredential().UserName -AdminPassword $credential.GetNetworkCredential().Password

Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $cidr
Add-LabVirtualNetworkDefinition -Name "External" -HyperVProperties @{ SwitchType = "External"; AdapterName = "Ethernet" }

Add-LabMachineDefinition -Name "L5DC1" -Memory 4GB -OperatingSystem "Windows Server 2019 Standard Evaluation (Desktop Experience)" -Roles RootDC -Network $labName -DomainName $domainName

$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "$labName"
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "External" -UseDhcp

Add-LabMachineDefinition -Name "L5Router" -Memory 2GB -OperatingSystem "Windows Server 2016 Standard Evaluation (Desktop Experience)" -Roles Routing -NetworkAdapter $netAdapter -DomainName $domainName

Add-LabMachineDefinition -Name "L5Win10" -Memory 2GB -Network "$labName" -OperatingSystem "Windows 10 Enterprise Evaluation" -DomainName $domainName

Install-Lab

Show-LabDeploymentSummary -Detailed
