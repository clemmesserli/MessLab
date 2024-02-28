$Stopwatch = [System.Diagnostics.Stopwatch]::new()
$Stopwatch.Start()

# Create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name 'Lab04' -VmPath "C:\LabVMs" -DefaultVirtualizationEngine HyperV

# Create default user credential
Add-LabDomainDefinition -Name 'messlabs.com' -AdminUser 'LabAdmin' -AdminPassword 'P@ssword1'
Set-LabInstallationCredential -Username 'LabAdmin' -Password 'P@ssword1'

Add-LabVirtualNetworkDefinition -Name 'Lab04' -AddressSpace 10.10.10.0/24
Add-LabVirtualNetworkDefinition -Name 'External' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Wi-Fi' }

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    "Add-LabMachineDefinition:DnsServer1"      = '10.10.10.1'
    "Add-LabMachineDefinition:Gateway"         = '10.10.10.1'
    "Add-LabMachineDefinition:DomainName"      = 'messlabs.com'
    "Add-LabMachineDefinition:Memory"          = "4GB"
    "Add-LabMachineDefinition:OperatingSystem" = "Windows Server 2022 Standard Evaluation (Desktop Experience)"
    "Add-LabMachineDefinition:Network"         = 'Lab04'
    "Add-LabMachineDefinition:ToolsPath"       = "C:\LabSources\Tools"
}

$routerNIC = @()
$routerNIC += New-LabNetworkAdapterDefinition -VirtualSwitch 'Lab04' -Ipv4Address '10.10.10.1'
$routerNIC += New-LabNetworkAdapterDefinition -VirtualSwitch 'External' -UseDhcp

$rootDC = @{
    Name = 'L4DC01'
    Memory = '8GB'
    Roles = @(
        'RootDC',
        'Routing'
    )
    NetworkAdapter = $routerNIC
    OperatingSystem = 'Windows Server 2022 Standard Evaluation (Desktop Experience)'
}
Add-LabMachineDefinition @rootDC

$client = @{
    Name = 'L4WIN10'
    Network = 'Lab04'
    DomainName = 'messlabs.com'
    OperatingSystem = 'Windows 10 Enterprise Evaluation'
}
Add-LabMachineDefinition @client -IsDomainJoined

Install-Lab
Write-Host "Base Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green

#region Install Windows PowerShell Core to all machines
Invoke-LabCommand -ComputerName (Get-LabVM) -ActivityName "Install Windows PowerShell Core" -ScriptBlock {
    # download the installation code
    $code = Invoke-RestMethod -Uri https://aka.ms/install-powershell.ps1
    # turn it into a function
    $null = New-Item -Path function:Install-PowerShell -Value $code
    # run the function
    Install-PowerShell -UseMSI -Preview
} -PassThru
#endregion

Write-Host "Full Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
$Stopwatch.Stop()
# Stop-Transcript

#Show-LabDeploymentSummary -Detailed
#Location of lab definition files will be 'C:\ProgramData\AutomatedLab'
# Remove-Lab -Name $labName #-RemoveExternalSwitches