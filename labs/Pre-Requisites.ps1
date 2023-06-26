# Enable Hyper-V on host machine
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

# Install the AutomatedLab module
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Repository PSGallery -Name AutomatedLab -Scope AllUsers -Force -AllowClobber

# Download AutomatedLab resources from Github
New-LabSourcesFolder

# Copy desired ISO files to
Copy-Item "$($env:onedrive)\LabSources\ISOs" "C:\Labsources\ISOs"

# Check to see what is available
$OSOptions = (Get-LabAvailableOperatingSystem).OperatingSystemName
$OSOptions


