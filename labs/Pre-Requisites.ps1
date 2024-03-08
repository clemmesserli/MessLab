# Enable Hyper-V on host machine
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

# Install the AutomatedLab module
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Don't be alarmed by the module below also installing a number of additional modules which is depends upon
Install-Module -Repository PSGallery -Name AutomatedLab -Scope AllUsers -Force -AllowClobber

# Download AutomatedLab LabResources from their Github
## C:\LabSources is the default location but I wanted to leverage an external SSD drive for greater storage
$LabDrive = Get-DriveInfo | Where-Object VolumeName -Match 'Lab Data'
if ($LabDrive) {
	New-LabSourcesFolder -DriveLetter $LabDrive.DeviceID
} else {
	New-LabSourcesFolder
}

#region Copy ISO files to LabSources\ISOs
## Due to size, I have copies stored on a fileshare, however, you can download fresh eval copies
## from : https://www.microsoft.com/en-us/evalcenter

$srcPath = "$($env:onedrive)\LabSources\ISOs"
$dstPath = "$(Get-LabSourcesLocation)\ISOs"

if (Test-Path -Path $dstPath) {
	# Compare the files
	$srcFile = Get-FileHash -Path $srcPath
	$dstFile = Get-FileHash -Path $dstPath

	if ($srcFile.Hash -ne $dstFile.Hash) {
		# If the files are not identical, copy the source file to the destination
		Copy-Item -Path $srcPath -Destination $dstPath
	}
} else {
	# If the destination file does not exist, copy the source file to the destination
	Copy-Item -Path $srcPath -Destination $dstPath
}
#endregion

#region Update LabSources\SoftwarePackages
$params = @{
	uri     = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
	outfile = "$(Get-LabSourcesLocation)\SoftwarePackages\Microsoft.VCLibs.Desktop.appx"
}
Invoke-WebRequest @params

$releases = Invoke-RestMethod "https://api.github.com/repos/microsoft/microsoft-ui-xaml/releases"
$asset = ($releases | Where-Object name -Match 'Microsoft.UI.Xaml')[0].assets | Where-Object name -Match 'x64.appx'
$params = @{
	uri     = "$($asset.browser_download_url)"
	outfile = "$(Get-LabSourcesLocation)\SoftwarePackages\Microsoft.UI.Xaml.appx"
}
Invoke-WebRequest @params

$releases = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-cli/releases"
$asset = ($releases | Where-Object name -Match 'Windows Package Manager')[0].assets | Where-Object name -Match ".msixbundle$"
$params = @{
	uri     = "$($asset.browser_download_url)"
	outfile = "$(Get-LabSourcesLocation)\SoftwarePackages\winget.msixbundle"
}
Invoke-WebRequest @params

$releases = Invoke-RestMethod "https://api.github.com/repos/microsoft/terminal/releases"
$asset = ($releases | Where-Object name -NotMatch 'preview')[0].assets | Where-Object name -Match ".msixbundle$"
$params = @{
	uri     = "$($asset.browser_download_url)"
	outfile = "$(Get-LabSourcesLocation)\SoftwarePackages\Microsoft.WindowsTerminal.msixbundle"
}
Invoke-WebRequest @params
#endregion

# Check to see what is available
# $OSOptions = (Get-LabAvailableOperatingSystem).OperatingSystemName
# $OSOptions

# Check to see what your Network Adapter Names are
# Get-NetAdapter