<#
LAB02 - Windows 10 Client w/ Internet
#>

# define local variables
$labName = 'Lab02'
$adminUser = 'LabAdmin'
$adminPassword = 'P@ssword1'
$vmPath = 'L:\LabVMs'

# create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -VmPath $vmPath -DefaultVirtualizationEngine HyperV

# define our default user credential
Set-LabInstallationCredential -Username $adminUser -Password $adminPassword

# Create network switch that allows for internet access
$netConfig = @{
    Name             = 'External'
    HyperVProperties = @{
        SwitchType  = 'External'
        AdapterName = 'Wi-Fi'
    }
}
Add-LabVirtualNetworkDefinition @netConfig

# define our virtual machine
$machineParam = @{
    name            = 'L2WIN10'
    memory          = '4GB'
    network         = 'External'
    operatingsystem = 'Windows 10 Enterprise Evaluation'
}
Add-LabMachineDefinition @machineParam

$machineParam = @{
    name            = 'L2WIN11'
    memory          = '4GB'
    network         = 'External'
    operatingsystem = 'Windows 11 Enterprise Evaluation'
}
Add-LabMachineDefinition @machineParam

Install-Lab

Show-LabDeploymentSummary -Detailed