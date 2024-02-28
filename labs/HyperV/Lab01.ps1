<#
LAB01 - Windows 10 Client (Internal Only)
#>

# define local variables
$labName = 'Lab01'
$adminUser = 'LabAdmin'
$adminPassword = 'P@ssword1'
$vmPath = 'L:\LabVMs'
$cidr = '10.10.1.0/24'

# create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -VmPath $vmPath -DefaultVirtualizationEngine HyperV

# make the network definition
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $cidr

# define our default user credential
Set-LabInstallationCredential -Username $adminUser -Password $adminPassword

# define our virtual machine
$machineParam = @{
    name            = 'L1WIN10'
    memory          = '4GB'
    network         = $labName
    ipaddress       = '10.10.1.10'
    operatingsystem = 'Windows 10 Enterprise Evaluation'
}
Add-LabMachineDefinition @machineParam

Install-Lab

Show-LabDeploymentSummary -Detailed