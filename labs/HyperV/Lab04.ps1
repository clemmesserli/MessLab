<#
LAB04 - Small Mixed Lab
    (1) Windows 2k22 Domain Controller
    (1) Domain-Joined Windows 10 Client
    (3) Windows IIS Web Server
    (1) Linux Apache Web Server
    (1) Linux Ansible Controller
#>

$labName = 'Lab04'
$domainName = "messlabs.com"
$adminUser = 'LabAdmin'
$adminPassword = 'P@ssword1'
$vmPath = 'C:\LabVMs'
$cidr = '10.10.4.0/24'

# Create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -VmPath $vmPath -DefaultVirtualizationEngine HyperV

# Create default user credential
Add-LabDomainDefinition -Name $domainName -AdminUser $adminUser -AdminPassword $adminPassword
Set-LabInstallationCredential -Username $adminUser -Password $adminPassword

Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $cidr
Add-LabVirtualNetworkDefinition -Name 'External' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Wi-Fi' }

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    "Add-LabMachineDefinition:DnsServer1"      = "10.10.4.1"
    "Add-LabMachineDefinition:Gateway"         = "10.10.4.1"
    "Add-LabMachineDefinition:DomainName"      = "$domainName"
    "Add-LabMachineDefinition:Memory"          = "4GB"
    "Add-LabMachineDefinition:OperatingSystem" = "Windows Server 2022 Standard Evaluation (Desktop Experience)"
    "Add-LabMachineDefinition:Network"         = "$labName"
}

$routerNIC = @()
$routerNIC += New-LabNetworkAdapterDefinition -VirtualSwitch "$labName" -Ipv4Address "10.10.4.1"
$routerNIC += New-LabNetworkAdapterDefinition -VirtualSwitch "External" -UseDhcp

# define our domain controller
$dcParam = @{
    name = "L4DC1"
    memory = "6GB"
    networkadapter = $routerNIC
    roles = @("RootDC", "Routing")
}
Add-LabMachineDefinition @dcParam

# add some IIS Web Servers
Add-LabMachineDefinition -Name Web2k12 -DomainName $domainName -IsDomainJoined -IpAddress 10.10.4.112 -Roles WebServer -OperatingSystem 'Windows Server 2012 R2 Standard Evaluation (Server with a GUI)'
Add-LabMachineDefinition -Name Web2k16 -DomainName $domainName -IsDomainJoined -IpAddress 10.10.4.116 -Roles WebServer -OperatingSystem 'Windows Server 2016 Standard Evaluation (Desktop Experience)'
Add-LabMachineDefinition -Name Web2k19 -DomainName $domainName -IsDomainJoined -IpAddress 10.10.4.119 -Roles WebServer -OperatingSystem 'Windows Server 2019 Standard Evaluation (Desktop Experience)'
Add-LabMachineDefinition -Name Web2k22 -DomainName $domainName -IsDomainJoined -IpAddress 10.10.4.122 -Roles WebServer -OperatingSystem 'Windows Server 2022 Standard Evaluation (Desktop Experience)'

Add-LabMachineDefinition -Name Ubuntu22 -IpAddress 10.10.4.222 -OperatingSystem 'Ubuntu 22.04.2 LTS "Jammy Jellyfish"'

# define our client machine
$clientParam = @{
    name = "L4CLIENT1"
    network = "$labName"
    operatingsystem = "Windows 10 Enterprise Evaluation"
}
Add-LabMachineDefinition @clientParam

Install-Lab

Show-LabDeploymentSummary -Detailed