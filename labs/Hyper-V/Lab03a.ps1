$labName = 'Lab03a'
$domainName = "messlabs.com"
$adminUser = 'LabAdmin'
$adminPassword = 'P@ssword1'
$vmPath = 'C:\LabVMs'
$cidr = '10.10.3.0/24'

# Create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -VmPath $vmPath -DefaultVirtualizationEngine HyperV

# Create default user credential
Add-LabDomainDefinition -Name $domainName -AdminUser $adminUser -AdminPassword $adminPassword
Set-LabInstallationCredential -Username $adminUser -Password $adminPassword

Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $cidr
Add-LabVirtualNetworkDefinition -Name 'External' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Wi-Fi' }

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    "Add-LabMachineDefinition:DnsServer1"      = "10.10.3.1"
    "Add-LabMachineDefinition:Gateway"         = "10.10.3.1"
    "Add-LabMachineDefinition:DomainName"      = "$domainName"
    "Add-LabMachineDefinition:Memory"          = "4GB"
    "Add-LabMachineDefinition:OperatingSystem" = "Windows Server 2022 Standard Evaluation (Desktop Experience)"
    "Add-LabMachineDefinition:Network"         = "$labName"
}

$routerNIC = @()
$routerNIC += New-LabNetworkAdapterDefinition -VirtualSwitch "$labName" -Ipv4Address "10.10.3.1"
$routerNIC += New-LabNetworkAdapterDefinition -VirtualSwitch "External" -UseDhcp

# define our domain controller
$dcParam = @{
    name = "L3DC1"
    memory = "6GB"
    networkadapter = $routerNIC
    roles = @("RootDC", "Routing")
}
Add-LabMachineDefinition @dcParam

# Make sure to download an ISO that contains the selected packages as well as SSSD,oddjob,oddjob-mkhomedir and adcli
# Or use an internet-connected lab so that the packages can be loaded on the fly
#Add-LabMachineDefinition -Name L3CN1 -OperatingSystem 'CentOS-7' -DomainName $domainName -RhelPackage gnome-desktop
#Add-LabMachineDefinition -Name L3SU1 -OperatingSystem 'openSUSE Leap 15.1' -DomainName $domainName -SusePackage gnome_basis
Add-LabMachineDefinition -Name L3UB22 -OperatingSystem 'Ubuntu 22.04.2 LTS "Jammy Jellyfish"' -DomainName $domainName
Add-LabMachineDefinition -Name L3WIN1 -OperatingSystem 'Windows 10 Enterprise Evaluation' -DomainName $domainName

Install-Lab

Show-LabDeploymentSummary -Detailed