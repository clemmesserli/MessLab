<#
.SYNOPSIS
Creates and installs a lab environment using AutomatedLab.

.DESCRIPTION
This script sets up a lab definition, adds (1) single machine definition, and installs the lab using AutomatedLab for internal only traffic.

.PARAMETER Credential
Specifies the credentials for lab installation.

.PARAMETER LabName
Specifies the name of the lab definition.

.PARAMETER OperatingSystem
Specifies the operating system edition for the lab machine.

.PARAMETER Memory
Specifies the memory in GB for the lab machine.

.PARAMETER ComputerName
Specifies the name of the lab machine.

.PARAMETER VmPath
Specifies the path where VM will be stored.

.PARAMETER AllowInternet
Specifies whether to create a virtual switch nat to allow hyper-v machine to reach the internet

.EXAMPLE
.\Lab03.ps1 -Credential $MyLabCred
Creates a lab definition using all pre-defined param defaults
#>
[cmdletBinding()]
param(
  [pscredential]$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin),

  [string]$cidr = '10.10.3.0/24',

  [string]$LabName = 'Lab03',

  [Parameter(HelpMessage = "Enter an array of PSCustomObjects. Each object should have 'OperatingSystem', 'Memory', and 'ComputerName' properties.")]
  [ValidateCount(1, 3)]
  [PSCustomObject[]]$LabMachines = @(
    [PSCustomObject]@{
      OperatingSystem = 'Windows 10 Enterprise Evaluation'
      Memory          = 4
      ComputerName    = 'L3PC1001'
    },
    [PSCustomObject]@{
      OperatingSystem = 'Windows 11 Enterprise Evaluation'
      Memory          = 4
      ComputerName    = 'L3PC1101'
    },
    [PSCustomObject]@{
      OperatingSystem = 'Windows Server 2016 Standard Evaluation (Desktop Experience)'
      Memory          = 6
      ComputerName    = 'L3SRV1601'
    }
  ),

  [string]$VmPath = 'L:\LabVMs',

  [string]$LocalFolderPath = "$(Get-LabSourcesLocation)",

  [string]$RemoteFolderPath = 'C:\LabSources'
)

Begin {
  $Stopwatch = [System.Diagnostics.Stopwatch]::new()
  $Stopwatch.Start()
}

Process {
  if (-not($PSBoundParameters.ContainsKey('Credential'))) {
    # Attempt to fetch default cred from Microsoft.PowerShell.SecretStore if a custom credential was not provided
    try {
      $Credential = (Get-Secret -Vault MessLabs -Name LabAdmin -ErrorAction Stop)
    } catch {
      Write-Error 'Unable to pre-set credentials.  Aborting lab creation!'
      break
    }
  }
  New-LabDefinition -VmPath $VmPath -Name $LabName -DefaultVirtualizationEngine HyperV

  # define our default user credential
  Set-LabInstallationCredential -Username $credential.UserName -Password $credential.GetNetworkCredential().Password


  if ( ((Get-NetAdapter -Name 'Wi-Fi').status) -eq 'UP') { $nic = 'Wi-Fi' } else { $nic = 'Ethernet' }
  Add-LabVirtualNetworkDefinition -Name 'External' -HyperVProperties @{ SwitchType = 'External'; AdapterName = "$nic" }

  foreach ($Machine in $LabMachines) {
    Add-LabMachineDefinition -Name $Machine.ComputerName -Memory "$($Machine.Memory)GB" -OperatingSystem $Machine.OperatingSystem -Network 'External'
  }

  Install-Lab

  foreach ($Machine in $LabMachines) {
    if ($Machine.OperatingSystem -eq 'Windows 10 Enterprise Evaluation' -or $Machine.OperatingSystem -eq 'Windows 11 Enterprise Evaluation') {
      Copy-LabFileItem -ComputerName $Machine.ComputerName -Path "$LocalFolderPath\SoftwarePackages" -DestinationFolderPath "$RemoteFolderPath"
      Invoke-LabCommand -ComputerName $Machine.ComputerName -ActivityName 'Update Base AppxPackages' -ArgumentList "$RemoteFolderPath" -ScriptBlock {
        param($LabSources)
        powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.UI.Xaml.2.8.x64.appx"
        powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.WindowsTerminal_1.21.2361.0_8wekyb3d8bbwe.msixbundle"
      } -PassThru

      Invoke-LabCommand -ComputerName $Machine.ComputerName -ActivityName 'NuGet/PSGet' -ScriptBlock {
        # set TLS just in case
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        #Bootstrap Nuget provider update  to avoid interactive prompts
        [void](Install-PackageProvider -Name Nuget -ForceBootstrap -Force)

        # Remove the built-in PSReadline & Pester modules so it will be easier to update both the version and the help later
        Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\PSReadline' -Recurse -Force -Confirm:$false
        Remove-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Pester' -Recurse -Force -Confirm:$false

        # Get the latest versions from the PowerShell Gallery
        Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PowerShellGet
        Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Microsoft.PowerShell.PSResourceGet
        Install-Module -Repository PSGallery -Scope AllUsers -Force -Name Pester
        Install-Module -Repository PSGallery -Scope AllUsers -Force -Name PSReadLine

        # Install latest version of PowerShell Core
        Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"

        Update-Help -Force -ErrorAction SilentlyContinue
      } -PassThru
    }
  }
}

End {
  Write-Host "Base Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
  $Stopwatch.Stop()
}