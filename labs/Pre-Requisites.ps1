# Enable Hyper-V on host machine
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

# Install the AutomatedLab module
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Repository PSGallery -Name AutomatedLab -Scope AllUsers -Force -AllowClobber

# Download AutomatedLab LabResources from their Github
## I use on Laptop (C:) and NUC (L:) so needed to first check for
$LabDrive = Get-DriveInfo | Where-Object VolumeName -Match 'Lab Data'
if ($LabDrive) {
	New-LabSourcesFolder -DriveLetter $LabDrive.DeviceID
} else {
	New-LabSourcesFolder
}

# Copy desired ISO files to
Copy-Item "$($env:onedrive)\LabSources\ISOs" "$(Get-LabSourcesLocation)\ISOs"


#region Update SoftwarePackages
$progressPreference = 'silentlyContinue'
$latestWingetMsixBundleUri = $(Invoke-RestMethod https://api.github.com/repos/microsoft/winget-cli/releases/latest).assets.browser_download_url | Where-Object {$_.EndsWith(".msixbundle")}
$latestWingetMsixBundle = $latestWingetMsixBundleUri.Split("/")[-1]
Write-Information "Downloading winget to artifacts directory..."
Invoke-WebRequest -Uri $latestWingetMsixBundleUri -OutFile "$(Get-LabSourcesLocation)\SoftwarePackages\$latestWingetMsixBundle"
Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile "$(Get-LabSourcesLocation)\SoftwarePackages\Microsoft.VCLibs.x64.14.00.Desktop.appx"
#endregion

# Check to see what is available
$OSOptions = (Get-LabAvailableOperatingSystem).OperatingSystemName
$OSOptions

# Check to see what your Network Adapter Names are
# Get-NetAdapter


#region Available OS List
<#
Kali Linux 2023.4
Red Hat Enterprise Linux 8.9
Red Hat Enterprise Linux 9.3
Ubuntu 22.04.4 LTS "Jammy Jellyfish"
Ubuntu-Server 22.04.4 LTS "Jammy Jellyfish"
Windows 10 Enterprise Evaluation
Windows 11 Enterprise Evaluation
Windows Server 2012 R2 Standard Evaluation (Server Core Installation)
Windows Server 2012 R2 Standard Evaluation (Server with a GUI)
Windows Server 2012 R2 Datacenter Evaluation (Server Core Installation)
Windows Server 2012 R2 Datacenter Evaluation (Server with a GUI)
Windows Server 2016 Standard Evaluation
Windows Server 2016 Standard Evaluation (Desktop Experience)
Windows Server 2016 Datacenter Evaluation
Windows Server 2016 Datacenter Evaluation (Desktop Experience)
Windows Server 2019 Standard Evaluation
Windows Server 2019 Standard Evaluation (Desktop Experience)
Windows Server 2019 Datacenter Evaluation
Windows Server 2019 Datacenter Evaluation (Desktop Experience)
Windows Server 2022 Standard Evaluation
Windows Server 2022 Standard Evaluation (Desktop Experience)
Windows Server 2022 Datacenter Evaluation
Windows Server 2022 Datacenter Evaluation (Desktop Experience)
#>
#endregion