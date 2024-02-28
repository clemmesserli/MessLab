#region Base Info
$labName = 'SmallWinLab'
$domainName = "messlabs.com"

#create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -VmPath "C:\LabVMs" -DefaultVirtualizationEngine HyperV

#make the network definition
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 10.10.10.0/24 -HyperVProperties @{ SwitchType = "External"; AdapterName = "Wi-Fi" }

#and the domain definition with the domain admin account
Add-LabDomainDefinition -Name $domainName -AdminUser "admin" -AdminPassword "P@ssword1"
Set-LabInstallationCredential -Username "admin" -Password "P@ssword1"

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'    = "$labName"
    'Add-LabMachineDefinition:ToolsPath'  = "$labSources\Tools"
    'Add-LabMachineDefinition:Memory'     = 4GB
    'Add-LabMachineDefinition:DnsServer1' = '10.10.10.10'
    'Add-LabMachineDefinition:Gateway'    = '10.10.10.10'
}
#endregion

#region Machine Info
#the first machine is the root domain controller. Everything in $labSources\Tools get copied to the machine's Windows folder
Add-LabMachineDefinition -Name P1DC1 -DomainName $domainName -IpAddress 10.10.10.10 -Roles RootDC -OperatingSystem 'Windows Server 2019 Datacenter Evaluation (Desktop Experience)'

Add-LabMachineDefinition -Name Web2k12 -DomainName $domainName -IsDomainJoined -IpAddress 10.10.10.112 -Roles WebServer -OperatingSystem 'Windows Server 2012 R2 Standard Evaluation (Server with a GUI)'
Add-LabMachineDefinition -Name Web2k16 -DomainName $domainName -IsDomainJoined -IpAddress 10.10.10.116 -Roles WebServer -OperatingSystem 'Windows Server 2016 Standard Evaluation (Desktop Experience)'
Add-LabMachineDefinition -Name Web2k19 -DomainName $domainName -IsDomainJoined -IpAddress 10.10.10.119 -Roles WebServer -OperatingSystem 'Windows Server 2019 Standard Evaluation (Desktop Experience)'
Add-LabMachineDefinition -Name Web2k22 -DomainName $domainName -IsDomainJoined -IpAddress 10.10.10.122 -Roles WebServer -OperatingSystem 'Windows Server 2022 Standard Evaluation (Desktop Experience)'

Add-LabMachineDefinition -Name Win10 -DomainName $domainName -IsDomainJoined -IpAddress 10.10.10.210 -OperatingSystem 'Windows 10 Enterprise Evaluation'
#Add-LabMachineDefinition -Name Win11 -DomainName $domainName -IpAddress 10.10.10.211 -OperatingSystem 'Windows 11 Enterprise Evaluation'

# Non domain-joined
Add-LabMachineDefinition -Name Ubuntu22 -IpAddress 10.10.10.222 -OperatingSystem 'Ubuntu 22.04.2 LTS "Jammy Jellyfish"'
Add-LabMachineDefinition -Name LINCN2 -OperatingSystem 'CentOS-7' -RhelPackage gnome-desktop
Add-LabMachineDefinition -Name LINSU2 -OperatingSystem 'openSUSE Leap 15.4' -SusePackage gnome_basis

#member server configured as Root CA server. Everything in $labSources\Tools get copied to the machine's Windows folder
#Add-LabMachineDefinition -Name P1ROOTCA1 -DomainName $domainName -IpAddress 10.10.10.20 -Roles CaRoot

#member server configured as Subordinate CA server. Everything in $labSources\Tools get copied to the machine's Windows folder
#Add-LabMachineDefinition -Name P1SUBCA1 -DomainName $domainName -IpAddress 10.10.10.30 -Roles CaSubordinate
#endregion

#Now the actual work begins. First the virtual network adapter is created and then the base images per OS
#All VMs are diffs from the base.
#Install-Lab -NetworkSwitches -BaseImages -VMs

#This sets up all domains / domain controllers
#Install-Lab -Domains

#Install CA server(s)
#Install-Lab -CA

#Enable-LabCertificateAutoenrollment -Computer -User -CodeSigning

Install-Lab
Show-LabDeploymentSummary -Detailed

<#
ISSUES:
- Install-Lab -CA failed to create C:\Windows\System32\CertSrv\CertEnroll folder
- SubCA also fails as it can then not contact the RootCA as CertSvc is not running
#>