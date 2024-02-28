#The is almost the same like '07 Standalone Root CA, Sub Ca domain joined.ps1' but this adds a web server and requests
#a web sever certificate for SSL. This certificate is then used for the SSL binding.

[cmdletBinding()]
param(
    [pscredential]$credential = (Get-Secret -Vault MessLabs -Name LabAdmin),
    [string]$cidr = "10.10.9.0/24",
    [string]$domainName = "messlabs.com",
    [string]$labName = "Lab09",
    [string]$vmPath = "L:\LabVMs"
)

$labSources = Get-LabSourcesLocation

New-LabDefinition -VmPath $vmPath -Name $labName -DefaultVirtualizationEngine HyperV

#and the domain definition with the domain admin account
Add-LabDomainDefinition -Name $domainName -AdminUser $credential.GetNetworkCredential().UserName -AdminPassword $credential.GetNetworkCredential().Password

# define our default credentials
Set-LabInstallationCredential -Username $credential.GetNetworkCredential().UserName -Password $credential.GetNetworkCredential().Password


Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $cidr
Add-LabVirtualNetworkDefinition -Name "External" -HyperVProperties @{ SwitchType = "External"; AdapterName = "Ethernet" }

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:DomainName' = $domainName
    'Add-LabMachineDefinition:Memory'     = 4GB
    'Add-LabMachineDefinition:Network'    = $labName
    'Add-LabMachineDefinition:ToolsPath'  = "$labSources\Tools"
}

# define our domain controller
$dcParam = @{
    name            = "DC1"
    network         = $labName
    roles           = "RootDC"
    operatingsystem = "Windows Server 2016 Standard Evaluation (Desktop Experience)"
}
Add-LabMachineDefinition @dcParam


# Give Router internet access via NAT switch
$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "$labName"
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch "External" -UseDhcp
Add-LabMachineDefinition -Name "Router" -Memory 2GB -OperatingSystem "Windows Server 2016 Standard Evaluation (Desktop Experience)" -Roles Routing -NetworkAdapter $netAdapter -DomainName $domainName

# Create the CA
$CARole = Get-LabMachineRoleDefinition -Role CaRoot @{
    CACommonName        = "MessLabCA"
    KeyLength           = '4096'
    ValidityPeriod      = 'Years'
    ValidityPeriodUnits = '20'
}
Add-LabMachineDefinition -Name "CA1" -OperatingSystem "Windows Server 2016 Standard Evaluation (Desktop Experience)" -Roles $CARole

# Create Web Servers
Add-LabMachineDefinition -Name "WS12" -OperatingSystem "Windows Server 2012 R2 Standard Evaluation (Server with a GUI)" -Roles WebServer
Add-LabMachineDefinition -Name "WS16" -OperatingSystem "Windows Server 2016 Standard Evaluation (Desktop Experience)" -Roles WebServer
Add-LabMachineDefinition -Name "WS19" -OperatingSystem "Windows Server 2019 Standard Evaluation (Desktop Experience)" -Roles WebServer
Add-LabMachineDefinition -Name "WS22" -OperatingSystem "Windows Server 2022 Standard Evaluation (Desktop Experience)" -Roles WebServer

# Create Client Machines
Add-LabMachineDefinition -Name "PC10" -OperatingSystem "Windows 10 Enterprise Evaluation"
Add-LabMachineDefinition -Name "PC11" -OperatingSystem "Windows 11 Enterprise Evaluation"

Install-Lab

Enable-LabCertificateAutoenrollment -Computer -User -CodeSigning

$cert = Request-LabCertificate -Subject "CN=ws12.$($domainName)" -TemplateName WebServer -ComputerName "WS12" -PassThru

Invoke-LabCommand -ActivityName 'Setup SSL Binding' -ComputerName "WS12" -ScriptBlock {
    New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https
    Import-Module -Name WebAdministration
    Get-Item -Path "Cert:\LocalMachine\My\$($args[0].Thumbprint)" | New-Item -Path IIS:\SslBindings\0.0.0.0!443
} -ArgumentList $cert

Show-LabDeploymentSummary -Detailed
