$Stopwatch = [System.Diagnostics.Stopwatch]::new()
$Stopwatch.Start()

if (Test-Path $logFile) { Remove-Item $logFile -Force }
Start-Transcript C:\LabSources\$labName.txt -Force

$labName = 'L3SRV22'
$domainName = "messlabs.com"
$adminUser = 'LabAdmin'
$adminPassword = 'P@ssword1'
$logFile = "C:\LabSources\$labName.txt"

# Create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -VmPath "C:\LabVMs" -DefaultVirtualizationEngine HyperV

# Create default user credential
Add-LabDomainDefinition -Name $domainName -AdminUser $adminUser -AdminPassword $adminPassword
Set-LabInstallationCredential -Username $adminUser -Password $adminPassword

Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 10.10.10.0/24
Add-LabVirtualNetworkDefinition -Name 'External' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Wi-Fi' }

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    "Add-LabMachineDefinition:DnsServer1"      = "10.10.10.1"
    "Add-LabMachineDefinition:Gateway"         = "10.10.10.1"
    "Add-LabMachineDefinition:DomainName"      = "$domainName"
    "Add-LabMachineDefinition:Memory"          = "8GB"
    "Add-LabMachineDefinition:OperatingSystem" = "Windows Server 2022 Standard Evaluation (Desktop Experience)"
    "Add-LabMachineDefinition:Network"         = "$labName"
    "Add-LabMachineDefinition:ToolsPath"       = "$labSources\Tools"
}

$routerNIC = @()
$routerNIC += New-LabNetworkAdapterDefinition -VirtualSwitch "$labName" -Ipv4Address "10.10.10.1"
$routerNIC += New-LabNetworkAdapterDefinition -VirtualSwitch 'External' -UseDhcp
Add-LabMachineDefinition -Name $labName -Roles RootDC, Routing -NetworkAdapter $routerNIC

Install-Lab
Write-Host "Base Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green

#region Install Windows PowerShell Core
Invoke-LabCommand -ComputerName $labName -ActivityName "Install Windows PowerShell Core" -ScriptBlock {
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
Stop-Transcript

#Show-LabDeploymentSummary -Detailed
#Location of lab definition files will be 'C:\ProgramData\AutomatedLab'
# Remove-Lab -Name $labName #-RemoveExternalSwitches