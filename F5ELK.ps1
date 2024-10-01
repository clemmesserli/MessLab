[cmdletBinding()]
param(
	[pscredential]$Credential = (Get-Secret -Vault MessLabs -Name LabAdmin),

	[string]$LabName = "F5ELK",

	[string]$vmPath = "L:\LabVMs",

	[string]$LocalFolderPath = "$(Get-LabSourcesLocation)",

	[string]$RemoteFolderPath = "C:\LabSources"
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
			Write-Error "Unable to pre-set credentials.  Aborting lab creation!"
			break
		}
	}
	New-LabDefinition -VmPath $VmPath -Name $LabName -DefaultVirtualizationEngine HyperV

	# define our default user credential
	Set-LabInstallationCredential -Username $credential.UserName -Password $credential.GetNetworkCredential().Password

	if ( ((Get-NetAdapter -Name 'Wi-Fi').status) -eq 'UP') { $nic = "Wi-Fi" } else { $nic = "Ethernet" }
	Add-LabVirtualNetworkDefinition -Name "External" -HyperVProperties @{ SwitchType = "External"; AdapterName = "$nic" }

	$PSDefaultParameterValues = @{
		"Add-LabMachineDefinition:OperatingSystem" = "Windows Server 2022 Standard Evaluation (Desktop Experience)"
		"Add-LabMachineDefinition:Network"         = "External"
	}

	Add-LabMachineDefinition -Name F5ELK -Memory 8GB #-IpAddress 192.168.4.60
	Add-LabMachineDefinition -Name F5WEB -Memory 6GB -Roles WebServer #-IpAddress 192.168.4.61

	Install-Lab

	Copy-LabFileItem -ComputerName (Get-LabVM) -Path "$LocalFolderPath\SoftwarePackages" -DestinationFolderPath "$RemoteFolderPath"
	Invoke-LabCommand -ComputerName (Get-LabVM) -ActivityName 'Update Base AppxPackages' -ArgumentList "$RemoteFolderPath" -ScriptBlock {
		param($LabSources)
		powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.UI.Xaml.appx"
		powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.VCLibs.Desktop.appx"
		powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\winget.msixbundle"
		powershell -noprofile Add-AppxPackage "$LabSources\SoftwarePackages\Microsoft.WindowsTerminal.msixbundle"
	} -PassThru

	Invoke-LabCommand -ComputerName (Get-LabVM) -ActivityName 'NuGet/PSGet' -ScriptBlock {
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

		#Update-Help -Force -ErrorAction SilentlyContinue
	} -PassThru

	Copy-LabFileItem -ComputerName F5ELK -Path "$LocalFolderPath\CustomPackages\ELK\elasticsearch.zip" -DestinationFolderPath "$RemoteFolderPath\CustomPackages\ELK"
	Invoke-LabCommand -ComputerName F5ELK -ActivityName 'Setting up ElasticSearch' {
		Expand-Archive -Path "C:\LabSources\CustomPackages\ELK\elasticsearch.zip" -DestinationPath "C:\ELK\"
		$folder = Get-Item "C:\ELK\elasticsearch-*"
		Rename-Item -Path $folder.FullName -NewName "elasticsearch"
	} -PassThru

	Copy-LabFileItem -ComputerName (Get-LabVM) -Path "$LocalFolderPath\CustomPackages\ELK\elastic-agent.zip" -DestinationFolderPath "$RemoteFolderPath\CustomPackages\ELK"
	Invoke-LabCommand -ComputerName (Get-LabVM) -ActivityName 'Setting up Elastic-Agent' {
		Expand-Archive -Path "C:\LabSources\CustomPackages\ELK\elastic-agent.zip" -DestinationPath "C:\ELK\"
		$folder = Get-Item "C:\ELK\elastic-agent*"
		Rename-Item -Path $folder.FullName -NewName "elastic-agent"
	} -PassThru

	Copy-LabFileItem -ComputerName F5ELK -Path "$LocalFolderPath\CustomPackages\ELK\kibana.zip" -DestinationFolderPath "$RemoteFolderPath\CustomPackages\ELK"
	Invoke-LabCommand -ComputerName F5ELK -ActivityName 'Setting up Kibana' {
		Expand-Archive -Path "C:\LabSources\CustomPackages\ELK\kibana.zip" -DestinationPath "C:\ELK\"
		$folder = Get-Item "C:\ELK\kibana*"
		Rename-Item -Path $folder.FullName -NewName "kibana"
	} -PassThru


	Invoke-LabCommand -ComputerName F5ELK -ActivityName 'Installing Elastic Search' {
		Set-Location "C:\ELK\elasticsearch\bin"
		powershell .\elasticsearch-service.bat install
	} -PassThru


}

End {
	Write-Host "Base Lab installed in $($Stopwatch.Elapsed.Minutes) minutes" -ForegroundColor Green
	$Stopwatch.Stop()
}